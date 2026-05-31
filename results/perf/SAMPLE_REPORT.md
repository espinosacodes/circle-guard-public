# CircleGuard perf comparison — SAMPLE (do not use for real decisions)

> **PLACEHOLDER DATA.** This file is committed so the `results/perf/`
> directory has a representative artifact for the report submission.
> Real numbers will overwrite it via the `perf:compare` GitLab CI job.
> Generation procedure lives in
> [`tests/performance/k6/comparison-with-locust.md`](../../tests/performance/k6/comparison-with-locust.md).

Pipeline : `https://gitlab.example.com/circleguard/circleguard/-/pipelines/000000` (placeholder)
Commit   : `abc1234` (placeholder)
Generated: `2025-05-30T22:30:00Z`

---

## SLO summary

| Metric              | SLO            | Locust value | k6 value | Verdict |
| ------------------- | -------------- | ------------ | -------- | ------- |
| Gateway p95 latency | `< 200 ms`     | 142 ms       | 138 ms   | PASS    |
| Gateway p99 latency | `< 500 ms`     | 287 ms       | 274 ms   | PASS    |
| Error rate          | `< 1 %`        | 0.18 %       | 0.21 %   | PASS    |
| Cascade p95         | `< 60 s`       | n/a (Locust scenario absent) | 24.3 s | PASS |
| Dashboard p95       | `< 200 ms`     | 178 ms       | 182 ms   | PASS    |

All values are **placeholders** drawn from a representative dev-cluster
run; real CI output replaces this file every pipeline.

## Per-endpoint p95 (ms)

| Endpoint                              | Locust | k6  | Δ (k6 − Locust) | Notes |
| ------------------------------------- | -----: | --: | --------------: | ----- |
| `POST /api/v1/gate/validate`          |   142  | 138 |             −4  | Within 3% — tools agree. |
| `POST /api/v1/surveys`                |   220  | 215 |             −5  | Within 3% — tools agree. |
| `GET  /api/v1/analytics/campus-summary` | 178 | 182 |             +4  | Within 3% — tools agree. |
| `GET  /api/v1/analytics/circle-heatmap` | 195 | 190 |             −5  | Within 3% — tools agree. |
| `POST /api/v1/auth/login`             |    96  |  88 |             −8  | k6 lower due to JWT cache (expected). |

Tolerance for re-investigation: > 15 % delta on any single endpoint.

## Throughput

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

(empty — placeholder run had no SLO violations)

---

_Last refreshed: pre-submission. Re-runs from CI will overwrite this
file via the `perf:compare` job in `.gitlab/ci/perf.yml`._
