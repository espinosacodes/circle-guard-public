# Runbook: Pod crash-looping / Service down

Applies to alerts:
* `PodCrashLooping` (Sev-1)
* `PodHighMemory` (Sev-2)
* `ServiceDown` (Sev-1)

---

## 1. Symptoms

* Slack alert with `pod` and `namespace` labels.
* `kubectl get pods -n <ns>` shows STATUS = `CrashLoopBackOff` or
  `OOMKilled`.
* Service unreachable from the gateway dashboard (downstream traffic to 0).

## 2. Dashboards to open first

1. The service's own dashboard (`CircleGuard / <Service>`) — sudden JVM
   heap spike just before crash points at OOM.
2. Kubernetes / Compute Resources / Pod — RSS and CPU throttling.
3. Grafana Explore -> Loki -> filter by pod:

   ```
   {namespace="circleguard-prod", pod="<pod-name>"} |= "ERROR" or "Exception"
   ```

4. `kubectl -n <ns> describe pod <pod>` — Events tab is usually
   the fastest answer (image pull, probe failure, OOMKilled).

## 3. Mitigation steps

### A. Container repeatedly OOMKilled

1. Confirm via `kubectl describe pod` -> `Last State: Terminated -> Reason: OOMKilled`.
2. Short-term: bump the limit and roll the deployment:

   ```
   kubectl -n circleguard-prod set resources deploy/<svc> \
     --limits=memory=1Gi --requests=memory=512Mi
   ```

3. Medium-term: capture a heap dump before the next OOM
   (`-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp`) and
   inspect with VisualVM — root-cause the leak.

### B. Readiness probe failing on startup

1. `kubectl logs -n <ns> <pod> --previous` to see why startup failed.
2. Common causes:
   * DB credentials wrong / Secret rotated -> check
     `kubectl get secret -n <ns>` and `kubectl rollout restart`.
   * Kafka broker unreachable -> check `KafkaConsumerLag` alert and the
     Kafka platform dashboard.
3. If the readiness check is broken (false negative), bump
   `failureThreshold` temporarily — but treat as a code bug.

### C. ImagePullBackOff

1. `kubectl describe pod` -> Events shows pull error.
2. Confirm the image tag exists in the registry:

   ```
   gcloud container images describe \
     us-central1-docker.pkg.dev/circleguard-final-92308/cg/circleguard-<svc>:<tag>
   ```

3. Check `imagePullSecrets` and the Workload Identity binding for the
   ServiceAccount.

### D. Crash on first request after deploy

1. Roll back the last release:

   ```
   kubectl -n circleguard-prod rollout undo deploy/<svc>
   ```

2. File a bug with the diff between the failing tag and the previous tag.

## 4. Verification

* `kubectl get pods -n <ns>` shows STATUS = `Running`, RESTARTS stable.
* The service's dashboard shows traffic restored.
* Alert auto-resolves in Slack.

## 5. Escalation

| Step                | Owner                             | Contact                                |
|---------------------|-----------------------------------|----------------------------------------|
| First responder     | on-call SRE                       | PagerDuty rotation `circleguard-sre`   |
| 10 minutes unresolved (Sev-1) | service team-lead       | `@<svc>-lead` in Slack                 |
| 30 minutes unresolved         | Engineering Manager     | `#circleguard-incident-channel`        |
