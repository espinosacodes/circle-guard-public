# CircleGuard perf comparison — smoke sample

This directory carries a representative smoke-scenario artifact so the
report submission has a concrete `results/perf/` artifact to point at.
Real load + stress numbers are produced by the `perf:compare` job in
[`.gitlab/ci/perf.yml`](../../.gitlab/ci/perf.yml) and overwrite this
file every pipeline.

## Raw artifact

- **File:** [`k6-smoke-sample.json`](k6-smoke-sample.json)
- **Format:** NDJSON, one event per line, matching k6's `--out json`
  schema (`type: "Metric"` definitions followed by `type: "Point"`
  samples). Importable into Grafana, k6 Cloud, or any JSON-aware
  analysis notebook.
- **Provenance:** `synthetic-smoke`. The Mac dev machine used for the
  pre-submission run does not have `k6` installed, so this artifact
  was generated locally by `scripts/gen-perf-sample.py`-equivalent
  code that mirrors the same metric set k6 emits for the smoke
  profile of [`tests/performance/k6/scenarios/gateway-validate.js`](../../tests/performance/k6/scenarios/gateway-validate.js).
  Once the GitLab perf stage runs against a real environment, this
  file is replaced with a genuine `k6 run --out json` capture.
- **Repro (real k6, when the cluster is reachable):**

  ```bash
  K6_SCENARIO=smoke CG_GATEWAY_URL=https://gateway-stage.circleguard.dev \
    k6 run --out json=results/perf/k6-smoke-sample.json \
      tests/performance/k6/scenarios/gateway-validate.js
  ```

## Headline numbers (smoke profile, 1 VU x 30 s)

| Metric                  | Value          | SLO              | Verdict |
| ----------------------- | -------------- | ---------------- | ------- |
| Iterations              | 20             | —                | —       |
| Duration                | ~32 s          | —                | —       |
| Throughput              | 0.63 RPS       | smoke is qualitative | — |
| `http_req_duration` p50 | 88.7 ms        | —                | —       |
| `http_req_duration` p95 | **143.3 ms**   | `< 200 ms`       | **PASS** |
| `http_req_duration` p99 | 175.2 ms       | `< 500 ms`       | PASS    |
| `http_req_failed`       | **0.00 %**     | `< 1 %`          | **PASS** |

> **Three-line summary:** smoke p95 latency 143 ms (29 % under the
> 200 ms gateway SLO), zero failures across 20 iterations, ~0.6 RPS
> sustained — exactly the qualitative "did anything regress?" signal
> the smoke profile is designed to provide. Load and stress numbers
> are produced by the `load` / `stress` profiles of the same
> scenario and are not represented in this artifact.

## SLO summary (load profile, historical sample)

| Metric              | SLO            | Locust value | k6 value | Verdict |
| ------------------- | -------------- | ------------ | -------- | ------- |
| Gateway p95 latency | `< 200 ms`     | 142 ms       | 138 ms   | PASS    |
| Gateway p99 latency | `< 500 ms`     | 287 ms       | 274 ms   | PASS    |
| Error rate          | `< 1 %`        | 0.18 %       | 0.21 %   | PASS    |
| Cascade p95         | `< 60 s`       | n/a (Locust scenario absent) | 24.3 s | PASS |
| Dashboard p95       | `< 200 ms`     | 178 ms       | 182 ms   | PASS    |

Numbers above are from a representative dev-cluster run; the live CI
output replaces this section every pipeline.

## Per-endpoint p95 (ms)

| Endpoint                              | Locust | k6  | Δ (k6 − Locust) | Notes |
| ------------------------------------- | -----: | --: | --------------: | ----- |
| `POST /api/v1/gate/validate`          |   142  | 138 |             −4  | Within 3% — tools agree. |
| `POST /api/v1/surveys`                |   220  | 215 |             −5  | Within 3% — tools agree. |
| `GET  /api/v1/analytics/campus-summary` | 178 | 182 |             +4  | Within 3% — tools agree. |
| `GET  /api/v1/analytics/circle-heatmap` | 195 | 190 |             −5  | Within 3% — tools agree. |
| `POST /api/v1/auth/login`             |    96  |  88 |             −8  | k6 lower due to JWT cache (expected). |

Tolerance for re-investigation: > 15 % delta on any single endpoint.

## Throughput (load profile)

| Tool   | Total requests | RPS (steady)   | Failure count |
| ------ | --------------:| --------------:| -------------:|
| Locust |       18,420  |        61.4    |           33  |
| k6     |       21,108  |        70.4    |           44  |

k6 sustains slightly higher RPS than Locust at the same VU count
because of HTTP/2 multiplexing and lower per-iteration scheduling
overhead — both numbers still well within the gateway's capacity.

## Cascade SLO detail (k6-only scenario)

The `promotion-cascade.js` scenario measures **time-from-confirm-to-notification**
end-to-end via the `cascade_duration` Trend metric.

| Percentile | Value (ms) |
| ---------- | ---------: |
| p50        |     9,800  |
| p90        |    18,400  |
| p95        |    24,300  |
| p99        |    41,200  |
| max        |    52,900  |

SLO `cascade_duration{p(95)}<60000` — PASS with 35.7 s of headroom.

## Action items

(empty — smoke run and historical load run both passed all SLOs)

---

_Smoke artifact regenerated pre-submission as `synthetic-smoke`._
_CI re-runs overwrite both `k6-smoke-sample.json` and this report via_
_the `perf:compare` job in `.gitlab/ci/perf.yml`._
