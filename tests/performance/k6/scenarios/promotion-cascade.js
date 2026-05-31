// =====================================================================
// CircleGuard k6 - promotion cascade end-to-end timing
// =====================================================================
// Measures: time from "POST /api/v1/health/confirmed" until the
// downstream notification-service has emitted a notification for the
// corresponding correlation id.
//
// The project SLO is < 60 s (Story NFR-2). We track this via a custom
// Trend metric "cascade_duration" and enforce it through cascadeThresholds.
//
// Lighter profile than the gateway scenarios (5 VUs steady) because
// each iteration writes Neo4j + Kafka + Postgres and we don't want to
// saturate the cluster purely to "test the test".
// =====================================================================
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { authHeaders } from '../lib/auth.js';
import { cascadeThresholds } from '../thresholds.js';

const PROMOTION_URL    = __ENV.CG_PROMOTION_URL    || 'http://localhost:8088';
const NOTIFICATION_URL = __ENV.CG_NOTIFICATION_URL || 'http://localhost:8082';

// Custom metrics — these names show up in the JSON output and the CI
// summary, which is what the comparison-with-locust.md diff hooks into.
const cascadeDuration = new Trend('cascade_duration', true);   // true => time
const cascadeFailures = new Counter('cascade_failures');

export const options = {
    scenarios: {
        cascade: {
            executor: 'constant-vus',
            vus: 5,
            duration: '3m',
            tags: { scenario: 'cascade' },
        },
    },
    thresholds: cascadeThresholds,
};

const POLL_INTERVAL_S = 1;
const POLL_BUDGET_S   = 60;          // hard SLO ceiling

export default function () {
    const anonymousId   = `k6-${__VU}-${__ITER}-${Date.now()}`;
    const correlationId = `corr-${anonymousId}`;
    const start         = Date.now();

    // ---- 1. Confirm a positive case ---------------------------------
    const confirmRes = http.post(
        `${PROMOTION_URL}/api/v1/health/confirmed`,
        JSON.stringify({ anonymousId, correlationId }),
        { headers: authHeaders(), tags: { name: 'cascade_confirm' } }
    );
    const confirmed = check(confirmRes, {
        'confirm 2xx': (r) => r.status >= 200 && r.status < 300,
    });
    if (!confirmed) {
        cascadeFailures.add(1);
        return;
    }

    // ---- 2. Poll the notification side until it lands ---------------
    let elapsed = 0;
    let landed  = false;
    while (elapsed < POLL_BUDGET_S) {
        sleep(POLL_INTERVAL_S);
        elapsed = (Date.now() - start) / 1000;
        const lookup = http.get(
            `${NOTIFICATION_URL}/api/v1/notifications/by-correlation/${correlationId}`,
            { headers: authHeaders(), tags: { name: 'cascade_poll' } }
        );
        if (lookup.status === 200) {
            try {
                const body = lookup.json();
                if (body && (body.count || body.length || (body.items && body.items.length))) {
                    landed = true;
                    break;
                }
            } catch (_e) { /* not JSON yet — keep polling */ }
        }
    }

    const totalMs = Date.now() - start;
    cascadeDuration.add(totalMs);

    if (!landed) {
        cascadeFailures.add(1);
    }

    check(null, {
        'cascade landed before 60 s': () => landed,
        'cascade duration < 60000 ms': () => totalMs < 60000,
    });

    // Small inter-iteration pause so we don't synthetically inflate
    // cascade contention on the notification service.
    sleep(2);
}
