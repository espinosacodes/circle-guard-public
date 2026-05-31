// =====================================================================
// CircleGuard k6 - shared SLO thresholds
// =====================================================================
// Imported by every scenario so all reports use the same SLOs and the
// Locust + k6 comparison stays apples-to-apples.
//
// SLOs (mirrored in docs/OBSERVABILITY.md "Performance SLOs"):
//   - p95 HTTP latency < 200 ms for gateway validate
//   - Error rate       < 1 %   across all endpoints
//   - p99              < 500 ms (informational, doesn't block)
//   - Cascade end-to-end p95 < 60 s (project SLO)
// =====================================================================

export const baseHttpThresholds = {
    // p95 latency budget — fails the run if exceeded
    'http_req_duration': [
        'p(95)<200',
        'p(99)<500',
    ],
    // 1% error budget (5xx + network errors)
    'http_req_failed': ['rate<0.01'],
};

// Stress profile: relaxed thresholds — we *expect* degradation past the
// knee, the point is to find where it happens, not to enforce SLOs.
export const stressHttpThresholds = {
    'http_req_duration': ['p(95)<1000'],
    'http_req_failed':   ['rate<0.10'],
};

// Cascade-specific SLO (custom metric — see promotion-cascade.js)
export const cascadeThresholds = {
    'cascade_duration': ['p(95)<60000'],   // 60-second cascade SLO
    'cascade_failures': ['count<1'],       // zero tolerance for hard failures
};
