// =====================================================================
// CircleGuard k6 - gateway validate (smoke / load / stress)
// =====================================================================
// Mirrors the Locust `gate_validate` task. Selected via K6_SCENARIO:
//
//   K6_SCENARIO=smoke   k6 run scenarios/gateway-validate.js   # 1 VU, 30 s
//   K6_SCENARIO=load    k6 run scenarios/gateway-validate.js   # 50 VUs, 5 m
//   K6_SCENARIO=stress  k6 run scenarios/gateway-validate.js   # ramp to 200
//
// SLOs enforced from thresholds.js. Stress profile uses the relaxed
// thresholds (we expect degradation past the knee).
// =====================================================================
import http from 'k6/http';
import { check, sleep } from 'k6';
import { authHeaders } from '../lib/auth.js';
import { baseHttpThresholds, stressHttpThresholds } from '../thresholds.js';

const GATEWAY_URL = __ENV.CG_GATEWAY_URL || 'http://localhost:8087';
const SCENARIO    = (__ENV.K6_SCENARIO || 'load').toLowerCase();

// ---------------------------------------------------------------------
// Scenario profiles. Each one returns the chunk of `options` that k6
// merges into its config (executor + thresholds).
// ---------------------------------------------------------------------
const PROFILES = {
    smoke: {
        scenarios: {
            smoke: {
                executor: 'constant-vus',
                vus: 1,
                duration: '30s',
                tags: { profile: 'smoke' },
            },
        },
        thresholds: baseHttpThresholds,
    },
    load: {
        scenarios: {
            load: {
                executor: 'ramping-vus',
                startVUs: 0,
                stages: [
                    { duration: '30s', target: 50 },     // warm up
                    { duration: '4m',  target: 50 },     // hold
                    { duration: '30s', target: 0 },      // ramp down
                ],
                tags: { profile: 'load' },
            },
        },
        thresholds: baseHttpThresholds,
    },
    stress: {
        scenarios: {
            stress: {
                executor: 'ramping-vus',
                startVUs: 10,
                stages: [
                    { duration: '1m', target: 50 },
                    { duration: '2m', target: 100 },
                    { duration: '2m', target: 200 },
                    { duration: '1m', target: 0 },
                ],
                tags: { profile: 'stress' },
            },
        },
        thresholds: stressHttpThresholds,
    },
};

if (!(SCENARIO in PROFILES)) {
    throw new Error(`Unknown K6_SCENARIO='${SCENARIO}'. Use smoke|load|stress.`);
}

export const options = PROFILES[SCENARIO];

// ---------------------------------------------------------------------
// One iteration = one QR scan against the gateway.
// We re-use the same JWT as the QR payload (gateway accepts the same
// HS256 token format — see Locust file for the production-equivalent).
// ---------------------------------------------------------------------
export default function () {
    const url = `${GATEWAY_URL}/api/v1/gate/validate`;
    const payload = JSON.stringify({
        // The Locust helper builds a real QR JWT; here we delegate to the
        // gateway's dev-mode validation which accepts the user JWT directly.
        token: 'k6-perf-' + __VU + '-' + __ITER,
    });

    const res = http.post(url, payload, {
        headers: authHeaders(),
        tags: { name: 'gateway_validate' },
    });

    check(res, {
        'gateway 2xx or 4xx (no 5xx)': (r) => r.status < 500,
    });

    // Realistic think time between scans (people don't badge in faster
    // than once per ~2 seconds). Stress profile pushes harder.
    sleep(SCENARIO === 'stress' ? 0.2 : 1.5);
}
