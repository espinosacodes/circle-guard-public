# Comparing k6 and Locust results

We deliberately run **both** k6 and Locust in CI so we can:

1. Catch tool-specific blind spots (each load generator has different
   networking quirks and JS-vs-Python timing precision).
2. Have a second opinion on SLO violations before we block a release.
3. Compare per-percentile numbers side-by-side so the team can decide
   which tool to invest in long-term.

## Methodology (apples-to-apples)

| Dimension | Locust | k6 |
| --- | --- | --- |
| Scenario       | `locustfile.py`           | `tests/performance/k6/scenarios/` |
| Auth           | PyJWT or static token     | `lib/auth.js` (live login + cache) |
| Profiles       | `--users 50 --run-time 5m`| `K6_SCENARIO=load` (50 VUs, 5 min) |
| SLO source     | Hard-coded in `_final_report` | `thresholds.js` |
| Output         | `results/perf/perf-*.csv`,`perf-*.html` | `results/perf/k6-*.json` |
| Failure mode   | `events.quitting` log only| Non-zero exit on threshold breach |

The CI runner (`.gitlab/ci/perf.yml`) sets identical:

- Target URLs (`CG_GATEWAY_URL`, ...)
- Test credentials (`CG_USERNAME`, `CG_PASSWORD`)
- Duration (5 min steady state)
- VU/user count (50)
- Endpoint mix (70 % gateway, 15 % survey, 10 % dashboard, 5 % login)

## Diff procedure

### 1. Extract p95 latency per endpoint

Locust (CSV, "Aggregated" row is the totals; per-endpoint rows above):

```bash
# Each Locust stats CSV has a header row + one row per endpoint + one "Aggregated" row.
# Column "95%" is the p95 in milliseconds.
awk -F',' 'NR==1{for(i=1;i<=NF;i++) if ($i ~ /95%/) col=i; print "endpoint,locust_p95_ms"; next}
           {gsub(/"/,""); print $2 "," $col}' \
  results/perf/perf-stage_stats.csv \
  > /tmp/locust_p95.csv
```

k6 (line-delimited JSON, one event per row). `http_req_duration` rows
have a `metric` field and a `data.tags.name` field that matches the
tag we set in each scenario (`gateway_validate`, `dashboard_summary`,
etc.). We aggregate them with `jq`:

```bash
jq -r '
  select(.type=="Point" and .metric=="http_req_duration")
  | [.data.tags.name, .data.value] | @csv
' results/perf/k6-gateway-load.json \
| awk -F',' '
    {
      gsub(/"/,"",$1);
      bucket[$1] = bucket[$1] " " $2;
      count[$1]++;
    }
    END {
      print "endpoint,k6_p95_ms";
      for (e in bucket) {
        n = split(bucket[e], arr, " ");
        # asort is gawk-only; use a tiny sort-then-pick for portability
        cmd = "printf \"%s\\n\" " bucket[e] " | sort -n | awk \"NR==int(\" n " * 0.95 + 0.5 \")\"";
        cmd | getline p95;
        close(cmd);
        print e "," p95;
      }
    }
' > /tmp/k6_p95.csv
```

### 2. Join the two on the endpoint name

```bash
join -t',' -1 1 -2 1 \
  <(sort /tmp/locust_p95.csv) \
  <(sort /tmp/k6_p95.csv) \
  > /tmp/p95_compare.csv

cat /tmp/p95_compare.csv
# endpoint, locust_p95_ms, k6_p95_ms
# /api/v1/gate/validate, 142, 138
# /api/v1/surveys, 220, 215
# ...
```

A delta > **15 %** is the threshold at which we file an investigation
ticket (typically caused by a connection-pool sizing mismatch between
the two clients).

### 3. Compare error rates

```bash
# Locust failure ratio:
awk -F',' '$2=="Aggregated"{print "locust_err=" $5/$3}' results/perf/perf-stage_stats.csv

# k6 failure ratio:
jq -r '
  select(.type=="Point" and .metric=="http_req_failed")
  | .data.value
' results/perf/k6-gateway-load.json \
| awk '{s+=$1; n++} END {print "k6_err=" s/n}'
```

Both numbers must be `< 0.01` per the shared SLO.

## When the two tools disagree

In order of likelihood:

1. **Connection pooling.** Locust's `requests` defaults to 10 pooled
   conns/host; k6 opens a fresh TCP per VU. Pin both with HTTP/2 (k6 is
   already HTTP/2 by default; pass `pool_connections=100` in Locust).
2. **Auth caching.** k6's `lib/auth.js` caches JWTs for 50 min; if Locust
   re-authenticates per task you'll see lower Locust throughput.
3. **DNS / target.** Confirm both tools resolved the same IP — k6 caches
   DNS per VU, Locust does not. Re-run with the gateway IP hard-coded
   to remove DNS as a variable.

## Where the canonical reports live

- Locust HTML: `results/perf/perf-stage.html`
- Locust CSV : `results/perf/perf-stage_stats.csv` (+ `_failures` / `_history` / `_exceptions`)
- k6 JSON   : `results/perf/k6-gateway-load.json`, `k6-cascade.json`, `k6-dashboard.json`
- Side-by-side: `results/perf/SAMPLE_REPORT.md` (template)
