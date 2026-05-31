// =====================================================================
// CircleGuard k6 - dashboard read-heavy load
// =====================================================================
// Mirrors the Locust `dashboard_summary` task at higher concurrency to
// stress the dashboard-service's analytics queries (the heaviest read
// path in the stack — joins user-state + circle membership + activity).
//
// Profile: 30 VUs steady for 3 min, with two endpoint mix:
//   - 60 % campus-summary           (the big aggregation)
//   - 40 % circle-heatmap           (heat-mapped activity per circle)
// =====================================================================
import http from 'k6/http';
import { check, sleep } from 'k6';
import { authHeaders } from '../lib/auth.js';
import { baseHttpThresholds } from '../thresholds.js';

const DASHBOARD_URL = __ENV.CG_DASHBOARD_URL || 'http://localhost:8084';

export const options = {
    scenarios: {
        dashboard_read: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '20s', target: 30 },
                { duration: '3m',  target: 30 },
                { duration: '20s', target: 0 },
            ],
            tags: { scenario: 'dashboard' },
        },
    },
    // Reuse the base p95<200 / error<1% SLOs — these are the same as
    // the gateway because the dashboard is on the user-facing critical
    // path for the campus health team.
    thresholds: baseHttpThresholds,
};

export default function () {
    const headers = authHeaders();

    // 60% summary, 40% heatmap — same weighting as the production
    // admin-polling pattern observed in dashboards.
    if (Math.random() < 0.6) {
        const r = http.get(
            `${DASHBOARD_URL}/api/v1/analytics/campus-summary`,
            { headers, tags: { name: 'dashboard_summary' } }
        );
        check(r, { 'summary <500': (res) => res.status < 500 });
    } else {
        const r = http.get(
            `${DASHBOARD_URL}/api/v1/analytics/circle-heatmap`,
            { headers, tags: { name: 'dashboard_heatmap' } }
        );
        check(r, { 'heatmap <500': (res) => res.status < 500 });
    }

    // Realistic admin polling cadence
    sleep(1);
}
