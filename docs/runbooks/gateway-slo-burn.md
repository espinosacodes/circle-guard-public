# Runbook: Gateway SLO burn

Applies to alerts:
* `GatewayLatencyBurnRateFast` (Sev-1)
* `GatewayLatencyBurnRateSlow` (Sev-2)
* `AuthErrorBudgetBurnFast` (Sev-1)
* `AuthErrorBudgetBurnSlow` (Sev-2)
* `CircuitBreakerOpen` (Sev-2)

---

## 1. Symptoms

* Alert in `#circleguard-ops` (Sev-1) or `#circleguard-warnings` (Sev-2).
* Users report slow page loads or 5xx responses on the web/mobile app.
* Gateway dashboard ("CircleGuard / Gateway Service") shows p95 above 500ms
  or 5xx > 0.5% sustained.

## 2. Dashboards to open first

1. [CircleGuard / Gateway Service](http://grafana.circleguard.example.com/d/cg-gateway)
   — top RED panel and Circuit Breaker panel.
2. [CircleGuard / Auth Service](http://grafana.circleguard.example.com/d/cg-auth)
   — most gateway 5xxs are auth failures.
3. Kubernetes / Compute Resources / Namespace (Pods) — CPU throttling /
   memory pressure?
4. Grafana Explore -> Loki ->
   `{namespace="circleguard-prod", app="circleguard-gateway-service"} |= "ERROR"`.
5. Jaeger -> search for service `circleguard-gateway-service` -> sort by
   duration to find the slow traces.

## 3. Mitigation steps

### A. If a single downstream service is failing (CB open on one name)

1. Confirm with `resilience4j_circuitbreaker_state{state="open"}` panel
   which downstream is open (e.g. `circleguard-form-service`).
2. Check that downstream's dashboard and Loki logs.
3. If the downstream is unhealthy, follow that service's runbook
   (usually [pod-crashloop](pod-crashloop.md) or
   [kafka-consumer-lag](kafka-consumer-lag.md)).
4. **Do not** disable the circuit breaker — it is protecting the gateway.

### B. If multiple services are slow (cluster-wide)

1. Check node CPU and memory:

   ```
   kubectl top nodes
   kubectl get events -A --sort-by=.lastTimestamp | tail -50
   ```

2. If a node is saturated, cordon it and let GKE autoscaler add capacity:

   ```
   kubectl cordon <node>
   ```

3. Inspect Prometheus -> Status -> Targets to confirm no scrape failures
   masking the real situation.

### C. If the gateway pod itself is the bottleneck (high CPU on its panel)

1. Scale up the Deployment temporarily:

   ```
   kubectl -n circleguard-prod scale deploy/circleguard-gateway-service --replicas=6
   ```

2. Verify p95 drops within 5 minutes. If not, roll back the latest
   gateway release (see Change Management doc).

### D. Roll back the latest deploy

```
helm rollback circleguard-gateway-service -n circleguard-prod
# or:
kubectl -n circleguard-prod rollout undo deploy/circleguard-gateway-service
```

## 4. Verification

* Sev-1 alert auto-resolves within 10 minutes (Alertmanager `send_resolved: true`).
* p95 returns under 500ms on the gateway dashboard.
* Error rate panel drops below 0.5%.

## 5. Escalation

| Step                 | Owner                              | Contact                               |
|----------------------|------------------------------------|---------------------------------------|
| First responder      | on-call SRE                        | PagerDuty rotation `circleguard-sre`  |
| 15 minutes unresolved| service engineering lead           | `@gateway-lead` in Slack              |
| 30 minutes unresolved| Engineering Manager + incident chan| `#circleguard-incident-channel`       |
| Customer impact      | comms lead -> status page update   | status.circleguard.example.com        |

## 6. Postmortem

Open a postmortem ticket within 24h for every Sev-1. Template:
`docs/postmortems/TEMPLATE.md` (TBD).
