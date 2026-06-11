# OpenTelemetry Java Agent — sidecar/init injection

This directory delivers the **distributed tracing** capability called out in
**Requirement 7** of the final-project rubric (rubric Req 7 / "tracing
distribuido"). It hooks all eight CircleGuard Spring Boot services into
the existing Jaeger collector without touching any service source code.

The pattern is a **shared-volume init container**:

```
+--------------------- Pod ----------------------+
|                                                |
|  initContainer: otel-agent-init                |
|    image: autoinstrumentation-java:2.5.0       |
|    cmd  : cp /javaagent.jar /otel/javaagent.jar|
|             |                                  |
|             v emptyDir: otel-agent             |
|                                                |
|  container: <service-name>                     |
|    JAVA_TOOL_OPTIONS=-javaagent:/otel/...jar   |
|    OTEL_EXPORTER_OTLP_ENDPOINT=...:4318        |
|                                                |
+------------------------------------------------+
```

Once the JVM starts with `-javaagent`, the agent silently instruments
HTTP servers (Tomcat/Netty), HTTP clients (RestTemplate/WebClient),
JDBC, Kafka producers/consumers and a few dozen other libraries. Spans
are pushed via OTLP/HTTP on port `4318` to
`jaeger-collector.observability.svc.cluster.local`.

---

## Files

| File                                                                            | Purpose                                                                                   |
|---------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `otel-agent-patch.yaml`                                                         | Canonical 8-document strategic-merge patch. Directly applyable with `kubectl apply -f`.   |
| `../../../k8s/dev/kustomization.yaml`                                           | Kustomize entry point that bundles `k8s/dev/*` + an inline copy of the same patch.        |
| `otel-agent-README.md` (this file)                                              | Operator handbook.                                                                        |

The two patch sources MUST stay in sync; see the *Why two copies?* note
at the bottom of this README.

---

## What the patch does, per Deployment

For each of the 8 services
(`auth-service`, `identity-service`, `form-service`, `file-service`,
`promotion-service`, `notification-service`, `gateway-service`,
`dashboard-service`) the patch adds:

1. An `initContainers` entry named `otel-agent-init` running
   `ghcr.io/open-telemetry/opentelemetry-java-instrumentation/autoinstrumentation-java:2.5.0`,
   which copies `/javaagent.jar` into a shared `emptyDir` volume.
2. A pod-level `volumes:` entry called `otel-agent`.
3. A `volumeMounts` entry on the main container mounting
   `/otel/javaagent.jar` (read-only).
4. The following env vars on the main container:

   | Variable                          | Value                                                                                |
   |-----------------------------------|--------------------------------------------------------------------------------------|
   | `JAVA_TOOL_OPTIONS`               | `-javaagent:/otel/javaagent.jar`                                                     |
   | `OTEL_EXPORTER_OTLP_ENDPOINT`     | `http://jaeger-collector.observability.svc.cluster.local:4318`                       |
   | `OTEL_EXPORTER_OTLP_PROTOCOL`     | `http/protobuf`                                                                      |
   | `OTEL_SERVICE_NAME`               | (downward API) `metadata.labels['app']` — e.g. `auth-service`                        |
   | `OTEL_RESOURCE_ATTRIBUTES`        | `deployment.environment=dev,service.namespace=circleguard`                           |
   | `OTEL_TRACES_SAMPLER`             | `parentbased_traceidratio`                                                           |
   | `OTEL_TRACES_SAMPLER_ARG`         | `0.1`  (10% head-based sampling — matches `jaeger/values.yaml`)                      |
   | `OTEL_METRICS_EXPORTER`           | `none` (Prometheus already scrapes `/actuator/prometheus`)                           |
   | `OTEL_LOGS_EXPORTER`              | `none` (Promtail already ships stdout to Loki)                                       |

The patch is purely *additive* — it never replaces or removes existing
fields on the Deployment, so services continue to receive their
`envFrom: configMapRef`, port, image, etc. exactly as before.

---

## How to apply

### Option A — Kustomize (recommended)

```bash
kubectl apply -k k8s/dev/
```

`k8s/dev/kustomization.yaml` lists the four existing dev manifests plus
the inline OTel patches, so a single command produces the same K8s
objects as before, instrumented.

### Option B — Plain `kubectl apply -f` on the canonical patch

If you only want to bolt the agent onto an already-deployed cluster
without going through Kustomize:

```bash
# Existing manifests must already be applied.
kubectl apply -f k8s/dev/

# Layer the OTel patch on top.
kubectl apply -f infra/k8s/observability/otel-agent-patch.yaml
```

Each of the 8 documents in `otel-agent-patch.yaml` is a strategic-merge
patch keyed by `(apiVersion, kind, name)`, so it merges into the
running Deployment instead of replacing it.

### Option C — One-off `kubectl patch` per service

```bash
for svc in auth-service identity-service form-service file-service \
           promotion-service notification-service gateway-service \
           dashboard-service; do
  kubectl -n circleguard-dev patch deployment "${svc}" --patch-file \
    <(yq "select(.metadata.name == \"${svc}\")" \
        infra/k8s/observability/otel-agent-patch.yaml)
done
```

(Useful in CI when you cannot run `kubectl apply` over the whole
namespace.)

---

## How to verify

### 1. Env vars made it into the pod

```bash
POD=$(kubectl -n circleguard-dev get pod -l app=gateway-service \
        -o jsonpath='{.items[0].metadata.name}')
kubectl -n circleguard-dev exec "${POD}" -c gateway-service -- env | grep OTEL
```

Expected output includes `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector...:4318`.

### 2. The agent JAR is in the volume

```bash
kubectl -n circleguard-dev exec "${POD}" -c gateway-service -- \
  ls -lh /otel/javaagent.jar
# -r--r--r-- ... ~22M ... /otel/javaagent.jar
```

### 3. A trace lands in Jaeger (the smoke test)

```bash
# Terminal A — port-forward Jaeger UI:
kubectl -n observability port-forward svc/jaeger-query 16686:16686 &

# Terminal B — generate a request that traverses gateway -> auth:
kubectl -n circleguard-dev port-forward svc/gateway-service 8087:8087 &
curl -s http://localhost:8087/actuator/health >/dev/null

# Then open http://localhost:16686 in a browser, pick
#   Service = "gateway-service"
# and click "Find Traces". The latest trace should show
# spans for gateway-service (and, depending on the request,
# downstream auth-service / identity-service).
```

One-liner that confirms the same thing via the Jaeger HTTP API:

```bash
kubectl -n observability port-forward svc/jaeger-query 16686:16686 \
  >/dev/null 2>&1 & sleep 2 && \
  curl -s "http://localhost:16686/api/services" | \
  grep -q gateway-service && echo "OK: gateway-service is reporting traces"
```

### 4. (Optional) Tail the agent's own logs

The agent prints a one-line banner on startup:

```bash
kubectl -n circleguard-dev logs "${POD}" -c gateway-service | grep -i otel | head
# [otel.javaagent ...] - OpenTelemetry Javaagent: 2.5.0
```

---

## How to roll back

### From the Kustomize path

Remove the `patches:` block in `k8s/dev/kustomization.yaml` (or revert
the file), then re-apply:

```bash
kubectl apply -k k8s/dev/
```

Kustomize will re-render every Deployment without the init container
and without the OTel env vars, and `kubectl apply` will perform the
rolling restart for you.

### From the plain-`kubectl apply -f` path

Strategic-merge cannot remove array entries it added (that's a known
JSON-merge limitation), so the cleanest rollback is to re-apply the
original `k8s/dev/services.yml`. Because `kubectl apply` uses
three-way merge with the *last applied* annotation, the OTel-added
init containers, volumes and env vars will be diffed out:

```bash
kubectl apply -f k8s/dev/services.yml
kubectl -n circleguard-dev rollout restart deployment   # pick up the new spec
```

### Emergency disable without a redeploy

Set `JAVA_TOOL_OPTIONS=""` on a single pod:

```bash
kubectl -n circleguard-dev set env deployment/gateway-service \
  JAVA_TOOL_OPTIONS=""
```

The agent will no longer be wired into the JVM on the next pod start,
but everything else (init container, volume) stays in place — a
zero-risk way to silence tracing while you investigate.

---

## Alternative: download the JAR at boot (no ghcr.io required)

If `ghcr.io` is blocked by an air-gapped network policy, replace the
`otel-agent-init` block with:

```yaml
initContainers:
  - name: otel-agent-init
    image: alpine:3.19
    command:
      - /bin/sh
      - -c
      - >
        wget -qO /otel/javaagent.jar
        https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.5.0/opentelemetry-javaagent.jar
    volumeMounts:
      - { name: otel-agent, mountPath: /otel }
```

Trade-off: `alpine:3.19` is ~8MB but the JAR download (`~22MB`) happens
on every pod start, against `github.com` egress. The ghcr.io variant
keeps the JAR inside the container image, which is the more reliable
default — only switch if you can prove ghcr.io is unreachable.

---

## Why two copies of the patch?

The brief mandates the canonical patch file at
`infra/k8s/observability/otel-agent-patch.yaml`. That file is a
standalone 8-document strategic-merge patch usable via plain
`kubectl apply -f`.

Kustomize's default `LoadRestrictionsRootOnly` policy refuses to load
patches from outside the kustomization directory (`k8s/dev/`).
`kubectl apply -k` does **not** accept the `--load-restrictor=...`
override flag (only `kubectl kustomize` does), so a `path:` reference
would force every operator to remember an extra flag.

We chose the lesser evil: keep the canonical file and embed an inline
copy in `k8s/dev/kustomization.yaml` so that `kubectl apply -k k8s/dev/`
works with zero flags. The two copies are short, mechanical, and
should be kept in sync whenever the agent version or OTLP endpoint
changes.

---

## Upgrade path to a production-grade pipeline

* Replace `OTEL_EXPORTER_OTLP_ENDPOINT=...:4318` with the address of
  an OpenTelemetry Collector running as a DaemonSet — that lets you
  apply tail-based sampling, redaction, multi-backend fan-out and
  retries close to the workload.
* Drop sampling to `0.01` once trace volume reaches steady state, and
  consider switching to tail-based sampling at the collector so you
  keep 100% of errors and slow traces.
* In `stage`/`prod`, flip the commented Elasticsearch block in
  `jaeger/values.yaml` so traces survive a Jaeger pod restart.
