# CircleGuard Observability Stack

Kubernetes-native observability for the CircleGuard microservices platform
running on GKE.

| Concern           | Tool                 | Chart                                  |
|-------------------|----------------------|----------------------------------------|
| Metrics + alerts  | Prometheus + Alertmanager + Grafana | `prometheus-community/kube-prometheus-stack` |
| Logs              | Loki + Promtail      | `grafana/loki-stack`                   |
| Traces            | Jaeger (OTLP gRPC/HTTP) | `jaegertracing/jaeger`              |
| Dashboards        | Grafana (sidecar auto-loads ConfigMaps) | bundled with kube-prometheus-stack |

Everything lives in the `observability` namespace, enforced with the
**restricted** Pod Security Admission profile.

---

## Layout

```
infra/k8s/observability/
├── README.md                          <- you are here
├── install.sh                         <- idempotent installer
├── namespace.yaml                     <- namespace + PSA labels
├── kube-prometheus-stack/values.yaml  <- Prometheus + Grafana + Alertmanager
├── loki/values.yaml                   <- Loki single-binary + Promtail DS
├── jaeger/values.yaml                 <- Jaeger all-in-one (dev) / prod block
├── alertmanager/values.yaml           <- routing, Slack receivers, inhibitions
├── alerts/circleguard-slo-rules.yaml  <- SLO recording rules + burn alerts
├── grafana-dashboards/
│   ├── auth-service.json
│   ├── gateway-service.json
│   ├── dashboard-service.json
│   └── configmap-loader.yaml
├── servicemonitors/
│   ├── gen.sh                         <- regenerates the eight YAMLs
│   └── <svc>-servicemonitor.yaml      <- 8 files (auth, dashboard, file, ...)
└── health-probes-patch.yaml           <- liveness/readiness Kustomize patch
```

---

## Ports

| Component            | In-cluster service                                 | Port |
|----------------------|----------------------------------------------------|------|
| Grafana              | `kps-grafana`                                      | 80   |
| Prometheus           | `kps-kube-prometheus-stack-prometheus`             | 9090 |
| Alertmanager         | `kps-kube-prometheus-stack-alertmanager`           | 9093 |
| Loki                 | `loki`                                             | 3100 |
| Jaeger UI (Query)    | `jaeger-query`                                     | 16686|
| Jaeger OTLP gRPC     | `jaeger-collector` (or `jaeger` all-in-one)        | 4317 |
| Jaeger OTLP HTTP     | `jaeger-collector`                                 | 4318 |

---

## Install (10 minutes on a fresh dev cluster)

### 1. Pre-create the two required secrets

```bash
# Grafana admin login (install.sh will auto-generate one if missing)
kubectl create namespace observability
kubectl -n observability create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"

# Slack webhook (Sev-1 / Sev-2 channels)
kubectl -n observability create secret generic alertmanager-slack-webhook \
  --from-literal=url='https://hooks.slack.com/services/XXX/YYY/ZZZ'
```

### 2. Run the installer

```bash
cd infra/k8s/observability
./install.sh                  # ENVIRONMENT=dev by default
ENVIRONMENT=prod ./install.sh # bumps retention etc.
```

The script is idempotent — re-run it after editing any values file.

### 3. Equivalent manual `helm` commands

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana               https://grafana.github.io/helm-charts
helm repo add jaegertracing         https://jaegertracing.github.io/helm-charts
helm repo update

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n observability --create-namespace \
  -f kube-prometheus-stack/values.yaml \
  -f alertmanager/values.yaml

helm upgrade --install loki grafana/loki-stack \
  -n observability -f loki/values.yaml

helm upgrade --install jaeger jaegertracing/jaeger \
  -n observability -f jaeger/values.yaml

kubectl apply -f servicemonitors/
kubectl apply -f alerts/
```

---

## Accessing the UIs

### Port-forward (development)

```bash
kubectl -n observability port-forward svc/kps-grafana 3000:80
kubectl -n observability port-forward svc/kps-kube-prometheus-stack-prometheus 9090
kubectl -n observability port-forward svc/kps-kube-prometheus-stack-alertmanager 9093
kubectl -n observability port-forward svc/jaeger-query 16686
```

### Ingress (stage/prod)

Enable `grafana.ingress` in `kube-prometheus-stack/values.yaml` and point
your DNS at the ingress controller's LB. Suggested hostnames:

* `grafana.circleguard.example.com`
* `prometheus.circleguard.example.com` (basic-auth)
* `alertmanager.circleguard.example.com` (basic-auth)
* `jaeger.circleguard.example.com` (basic-auth)

---

## Where to look next

* Architecture, dashboards, business metrics ->  [`docs/OBSERVABILITY.md`](../../../docs/OBSERVABILITY.md)
* Runbooks                                   ->  [`docs/runbooks/`](../../../docs/runbooks/)
* Alert rules                                ->  [`alerts/circleguard-slo-rules.yaml`](alerts/circleguard-slo-rules.yaml)
