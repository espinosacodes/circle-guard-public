# CircleGuard k6 performance suite

A second, parallel performance suite to the existing Locust harness
(`tests/performance/locustfile.py`). Both run the same scenarios with
the same SLOs; the comparison methodology lives in
[`comparison-with-locust.md`](./comparison-with-locust.md).

## Layout

```
tests/performance/k6/
├── README.md                                   <- this file
├── thresholds.js                               <- shared SLO thresholds
├── lib/
│   └── auth.js                                 <- JWT helper
├── scenarios/
│   ├── gateway-validate.js                     <- smoke / load / stress
│   ├── promotion-cascade.js                    <- end-to-end cascade timing
│   └── dashboard-queries.js                    <- read-heavy load
└── comparison-with-locust.md
```

## Local run

Prereqs: [`k6`](https://grafana.com/docs/k6/latest/set-up/install-k6/)
in `$PATH`, and the stack reachable via port-forward (same commands as
the Locust README).

```bash
# Smoke (1 VU, 30 s) — proves the script + thresholds work
K6_SCENARIO=smoke \
  k6 run tests/performance/k6/scenarios/gateway-validate.js

# Load (50 VUs, 5 min) — main SLO check
K6_SCENARIO=load \
  CG_GATEWAY_URL=http://localhost:8087 \
  CG_AUTH_URL=http://localhost:8180 \
  CG_USERNAME=perf-test@circleguard.edu \
  CG_PASSWORD=perf-test-pass \
  k6 run --out json=results/perf/k6-gateway-load.json \
    tests/performance/k6/scenarios/gateway-validate.js

# Stress (ramp to 200 VUs) — find the knee of the curve
K6_SCENARIO=stress \
  k6 run --out json=results/perf/k6-gateway-stress.json \
    tests/performance/k6/scenarios/gateway-validate.js

# End-to-end cascade timing (60 s SLO per "promote a user" event)
k6 run --out json=results/perf/k6-cascade.json \
  tests/performance/k6/scenarios/promotion-cascade.js

# Dashboard read load (admin polling pattern)
k6 run --out json=results/perf/k6-dashboard.json \
  tests/performance/k6/scenarios/dashboard-queries.js
```

## CI run

`.gitlab/ci/perf.yml` runs k6 in parallel with Locust in the stage
pipeline. The job fails if any threshold in `thresholds.js` is violated:

- `http_req_duration{p(95)}<200`  (ms, gateway validate)
- `http_req_failed<0.01`          (1% error budget)
- `cascade_duration{p(95)}<60000` (ms, promotion cascade SLO)

Both Locust and k6 results land in `results/perf/`. See
`comparison-with-locust.md` for the diff procedure.

## Environment variables (consumed by all scenarios)

| Var | Default | Purpose |
| --- | --- | --- |
| `CG_GATEWAY_URL`     | `http://localhost:8087` | Gateway base URL |
| `CG_AUTH_URL`        | `http://localhost:8180` | Auth-service base URL |
| `CG_PROMOTION_URL`   | `http://localhost:8088` | Promotion-service base URL |
| `CG_NOTIFICATION_URL`| `http://localhost:8082` | Notification-service base URL |
| `CG_DASHBOARD_URL`   | `http://localhost:8084` | Dashboard-service base URL |
| `CG_USERNAME`        | `perf-test@circleguard.edu` | Test login |
| `CG_PASSWORD`        | `perf-test-pass`        | Test password (do not commit prod creds) |
| `K6_SCENARIO`        | `load`                  | One of `smoke` / `load` / `stress` |
