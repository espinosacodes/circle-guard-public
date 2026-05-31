# Chaos Experiments — Runbook

Sister document to [`infra/k8s/chaos-mesh/`](../infra/k8s/chaos-mesh/). This
file is the **execution playbook** the engineer follows when running each
experiment, plus the results template that the student fills in after each
run for the Bonus 3 deliverable.

Contributes evidence to **Req 8 — Seguridad** (controlled fault injection
proves blast radii are bounded) and is the deliverable for **Bonus 3 —
Chaos Engineering (5 %)**.

> All experiments run **only** in `circleguard-dev`. Never re-label to
> `stage`/`prod` without explicit approval and a rollback plan.

---

## Common observation panels

| Stack                      | URL (after port-forward)               |
|----------------------------|----------------------------------------|
| Grafana                    | `http://localhost:3000`                |
| Jaeger UI                  | `http://localhost:16686`               |
| Kiali (Istio topology)     | `http://localhost:20001`               |
| Chaos Mesh dashboard       | `http://localhost:2333`                |
| Prometheus (raw)           | `http://localhost:9090`                |

Dashboards referenced below live under
`infra/k8s/observability/grafana-dashboards/`.

---

## Rollback (kill switch)

If a chaos run misbehaves:

```bash
# 1. Suspend the controller
kubectl -n chaos-mesh scale deploy chaos-controller-manager --replicas=0

# 2. Delete any running experiments
kubectl delete podchaos,networkchaos,stresschaos,httpchaos,workflow -n circleguard-dev --all

# 3. Re-enable the controller once safe
kubectl -n chaos-mesh scale deploy chaos-controller-manager --replicas=1
```

---

## Experiment 1 — Pod kill on `promotion-service`

| Field                     | Value                                                    |
|---------------------------|----------------------------------------------------------|
| Manifest                  | `infra/k8s/chaos-mesh/experiments/pod-kill-promotion.yaml` |
| Hypothesis                | Saga compensation survives pod loss; no partial promotions. |
| Steady-state metric       | `saga_completed_total` grows; `saga_failed_total` flat.  |
| Blast radius              | 1 pod / 10 min for 60 min in `circleguard-dev`.          |
| Observation               | Grafana → *Saga & Workflow* dashboard. Jaeger → trace ID. |
| Success criteria          | Zero `saga_failed_total` increments; Kafka lag returns to 0 within 60 s. |
| Rollback                  | `kubectl delete podchaos pod-kill-promotion -n circleguard-dev` |

---

## Experiment 2 — Network delay on `identity-service`

| Field                     | Value                                                    |
|---------------------------|----------------------------------------------------------|
| Manifest                  | `infra/k8s/chaos-mesh/experiments/network-delay-identity.yaml` |
| Hypothesis                | Resilience4j circuit breaker OPENs; fallback served.     |
| Steady-state metric       | `resilience4j_circuitbreaker_state{name="identityClient"}` becomes OPEN within 60 s. |
| Blast radius              | 200 ms ± 50 ms egress delay on all identity-service pods for 5 min in `circleguard-dev`. |
| Observation               | Grafana → *Resilience4j* dashboard; Jaeger → operation latency histogram. |
| Success criteria          | Breaker OPEN within 60 s; edge p95 < 1.5 s; no 5xx surge at the gateway. |
| Rollback                  | Experiment is self-terminating after 5 min. To stop early: `kubectl delete networkchaos network-delay-identity -n circleguard-dev` |

---

## Experiment 3 — CPU stress on `dashboard-service`

| Field                     | Value                                                    |
|---------------------------|----------------------------------------------------------|
| Manifest                  | `infra/k8s/chaos-mesh/experiments/cpu-stress-dashboard.yaml` |
| Hypothesis                | HPA scales replicas up within 60 s, p95 stays under SLO. |
| Steady-state metric       | `kube_horizontalpodautoscaler_status_current_replicas{name="dashboard-service"}` increases. |
| Blast radius              | 4 workers @ 80 % CPU on every dashboard-service pod, 10 min, `circleguard-dev`. |
| Observation               | Grafana → *Kubernetes / HPA* dashboard.                  |
| Success criteria          | Replica count grows from N to ceil(N\*1.6) within 60 s; p95 latency < 800 ms; no OOMKill events. |
| Rollback                  | Self-terminating after 10 min; manual: `kubectl delete stresschaos cpu-stress-dashboard -n circleguard-dev`. |

---

## Experiment 4 — HTTP abort on `notification-service`

| Field                     | Value                                                    |
|---------------------------|----------------------------------------------------------|
| Manifest                  | `infra/k8s/chaos-mesh/experiments/http-abort-notification.yaml` |
| Hypothesis                | Aborted responses are dead-lettered and retried; no user-visible message loss. |
| Steady-state metric       | `notification_dlq_depth_total` rises during the run, drains within 5 min after. |
| Blast radius              | ~30 % of responses on port 8080 of every notification-service pod, 5 min, `circleguard-dev`. |
| Observation               | Grafana → *Notifications & DLQ* dashboard.               |
| Success criteria          | DLQ drains to 0 within 5 min post-run; zero un-retried notifications in the audit log. |
| Rollback                  | Self-terminating after 5 min.                            |

---

## Experiment 5 — DNS/Network partition between consumers and Kafka

| Field                     | Value                                                    |
|---------------------------|----------------------------------------------------------|
| Manifest                  | `infra/k8s/chaos-mesh/experiments/dns-fail-kafka.yaml`   |
| Hypothesis                | Kafka consumers reconnect transparently; lag drains within 30 s after partition heals. |
| Steady-state metric       | `kafka_consumergroup_lag` returns to 0 within 30 s.      |
| Blast radius              | Bidirectional partition between every consumer pod and all Kafka brokers, 2 min, `circleguard-dev`. |
| Observation               | Grafana → *Kafka* dashboard; consumer logs.              |
| Success criteria          | Lag returns to 0 ≤ 30 s; zero entries in consumer DLQ logger. |
| Rollback                  | Self-terminating after 2 min.                            |

---

## Results table (fill after each run)

| #  | Experiment              | Date run (UTC)  | Replicas before | Blast radius observed                | Mitigation triggered                       | p95 latency peak | Outcome   | Notes |
|----|-------------------------|-----------------|-----------------|--------------------------------------|--------------------------------------------|------------------|-----------|-------|
| 1  | pod-kill-promotion      |                 |                 |                                      | Saga compensation                          |                  | PASS/FAIL |       |
| 2  | network-delay-identity  |                 |                 |                                      | Resilience4j breaker OPEN                  |                  | PASS/FAIL |       |
| 3  | cpu-stress-dashboard    |                 |                 |                                      | HPA scale-out                              |                  | PASS/FAIL |       |
| 4  | http-abort-notification |                 |                 |                                      | DLQ + retry worker                         |                  | PASS/FAIL |       |
| 5  | dns-fail-kafka          |                 |                 |                                      | Kafka consumer reconnect                   |                  | PASS/FAIL |       |

> Tip: append a row to this table for every chaos run, including the
> Workflow runs in CI. The pipeline can scrape this section to populate
> the release notes.
