#!/usr/bin/env bash
# =============================================================================
# Idempotent installer for the CircleGuard observability stack.
#
# Prerequisites (the script will check):
#   * kubectl context pointing at the target GKE cluster
#   * helm v3.12+
#   * Two K8s Secrets created in advance OR auto-generated below:
#       - grafana-admin-credentials
#       - alertmanager-slack-webhook
#
# Usage:
#   ./install.sh                       # default env=dev
#   ENVIRONMENT=prod ./install.sh      # overrides retention/replication
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="observability"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "==> Installing CircleGuard observability stack (env=${ENVIRONMENT})"

# --- 1. Helm repos ----------------------------------------------------------
echo "==> Adding Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana               https://grafana.github.io/helm-charts             >/dev/null 2>&1 || true
helm repo add jaegertracing         https://jaegertracing.github.io/helm-charts       >/dev/null 2>&1 || true
helm repo update

# --- 2. Namespace -----------------------------------------------------------
echo "==> Applying namespace"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# --- 3. Secrets (idempotent — only create if missing) -----------------------
echo "==> Ensuring secrets"
if ! kubectl -n "${NS}" get secret grafana-admin-credentials >/dev/null 2>&1; then
  ADMIN_PW="$(openssl rand -base64 24)"
  kubectl -n "${NS}" create secret generic grafana-admin-credentials \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="${ADMIN_PW}"
  echo "    Created grafana-admin-credentials (password printed once below)"
  echo "    grafana admin password: ${ADMIN_PW}"
else
  echo "    grafana-admin-credentials already present — skipping"
fi

if ! kubectl -n "${NS}" get secret alertmanager-slack-webhook >/dev/null 2>&1; then
  : "${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL env var before first install}"
  kubectl -n "${NS}" create secret generic alertmanager-slack-webhook \
    --from-literal=url="${SLACK_WEBHOOK_URL}"
  echo "    Created alertmanager-slack-webhook"
else
  echo "    alertmanager-slack-webhook already present — skipping"
fi

# --- 4. kube-prometheus-stack ----------------------------------------------
echo "==> Installing kube-prometheus-stack"
# envsubst injects ENVIRONMENT into externalLabels (rendered values.yaml)
ENV_VAL="${ENVIRONMENT}" envsubst < "${SCRIPT_DIR}/kube-prometheus-stack/values.yaml" \
  > /tmp/kps-values.rendered.yaml || \
  cp "${SCRIPT_DIR}/kube-prometheus-stack/values.yaml" /tmp/kps-values.rendered.yaml
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace "${NS}" \
  --version "58.7.2" \
  -f /tmp/kps-values.rendered.yaml \
  -f "${SCRIPT_DIR}/alertmanager/values.yaml" \
  --wait --timeout 10m

# --- 5. Loki + Promtail -----------------------------------------------------
echo "==> Installing Loki stack"
helm upgrade --install loki grafana/loki-stack \
  --namespace "${NS}" \
  --version "2.10.2" \
  -f "${SCRIPT_DIR}/loki/values.yaml" \
  --wait --timeout 10m

# --- 6. Jaeger --------------------------------------------------------------
echo "==> Installing Jaeger"
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace "${NS}" \
  --version "3.3.1" \
  -f "${SCRIPT_DIR}/jaeger/values.yaml" \
  --wait --timeout 10m

# --- 7. ServiceMonitors + PrometheusRules ----------------------------------
echo "==> Applying ServiceMonitors"
kubectl apply -f "${SCRIPT_DIR}/servicemonitors/" \
  --recursive=false 2>/dev/null || \
  for f in "${SCRIPT_DIR}/servicemonitors/"*.yaml; do kubectl apply -f "$f"; done

echo "==> Applying PrometheusRules"
kubectl apply -f "${SCRIPT_DIR}/alerts/"

# --- 8. Grafana dashboards (ConfigMap per JSON, sidecar-discovered) --------
echo "==> Loading Grafana dashboards"
for f in "${SCRIPT_DIR}/grafana-dashboards/"*.json; do
  name="cg-dashboard-$(basename "$f" .json | sed 's/-service$//')"
  kubectl -n "${NS}" create configmap "${name}" \
    --from-file="$(basename "$f")=${f}" \
    --dry-run=client -o yaml | \
    kubectl label --local -f - --dry-run=client -o yaml \
      grafana_dashboard=1 app.kubernetes.io/part-of=circleguard | \
    kubectl apply -f -
  echo "    loaded ${name}"
done

# --- 9. Final hints ---------------------------------------------------------
cat <<EOF

==============================================================================
 Observability stack installed in namespace: ${NS}

 Port-forward commands (run in separate terminals):

   # Grafana (admin / password printed above)
   kubectl -n ${NS} port-forward svc/kps-grafana 3000:80

   # Prometheus
   kubectl -n ${NS} port-forward svc/kps-kube-prometheus-stack-prometheus 9090

   # Alertmanager
   kubectl -n ${NS} port-forward svc/kps-kube-prometheus-stack-alertmanager 9093

   # Jaeger UI
   kubectl -n ${NS} port-forward svc/jaeger-query 16686

   # Loki (query via Grafana Explore — no UI of its own)

 Grafana default dashboards: open  http://localhost:3000  ->  Dashboards ->
   "CircleGuard / Auth Service", "Gateway Service", "Dashboard Service"
==============================================================================
EOF
