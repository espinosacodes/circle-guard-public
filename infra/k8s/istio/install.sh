#!/usr/bin/env bash
# =============================================================================
# Istio installer for CircleGuard
#
# Idempotent: re-running this script is safe — every step checks state first.
#
# Usage:
#   ./install.sh                 # full install
#   ISTIO_VERSION=1.22.3 ./install.sh
#   SKIP_KIALI=1     ./install.sh
#
# Prereqs: kubectl is authenticated against the target GKE cluster.
# =============================================================================
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.22.3}"
ISTIO_HOME="${HOME}/.istioctl"
ISTIO_BIN="${ISTIO_HOME}/istio-${ISTIO_VERSION}/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACES=("circleguard-dev" "circleguard-stage" "circleguard-master")
SKIP_KIALI="${SKIP_KIALI:-0}"

log()  { printf "\033[1;34m[istio]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[istio][warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[istio][err]\033[0m %s\n" "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# 0. Sanity checks
# -----------------------------------------------------------------------------
command -v kubectl >/dev/null 2>&1 || die "kubectl is required"
kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"

CLUSTER_NAME="$(kubectl config current-context)"
log "Target cluster context: ${CLUSTER_NAME}"

# -----------------------------------------------------------------------------
# 1. istioctl
# -----------------------------------------------------------------------------
if ! command -v istioctl >/dev/null 2>&1; then
  if [[ -x "${ISTIO_BIN}/istioctl" ]]; then
    log "Reusing istioctl at ${ISTIO_BIN}"
  else
    log "Downloading istioctl ${ISTIO_VERSION} to ${ISTIO_HOME}"
    mkdir -p "${ISTIO_HOME}"
    (
      cd "${ISTIO_HOME}"
      curl -fsSL "https://istio.io/downloadIstio" | ISTIO_VERSION="${ISTIO_VERSION}" sh -
    )
  fi
  export PATH="${ISTIO_BIN}:${PATH}"
fi

ACTUAL_VERSION="$(istioctl version --remote=false 2>/dev/null || true)"
log "istioctl client version: ${ACTUAL_VERSION:-unknown}"

# -----------------------------------------------------------------------------
# 2. Install the control plane (default profile)
# -----------------------------------------------------------------------------
if kubectl get ns istio-system >/dev/null 2>&1 \
   && kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  log "istiod already installed — running 'istioctl install' in upgrade mode"
fi

istioctl install --set profile=default -y

# -----------------------------------------------------------------------------
# 3. Label namespaces for sidecar injection
# -----------------------------------------------------------------------------
for ns in "${NAMESPACES[@]}"; do
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    log "Labelling ${ns} with istio-injection=enabled"
    kubectl label namespace "${ns}" istio-injection=enabled --overwrite
  else
    warn "Namespace ${ns} not found — skipping (create it first if you want injection there)"
  fi
done

# -----------------------------------------------------------------------------
# 4. Apply mesh-wide STRICT mTLS
# -----------------------------------------------------------------------------
log "Applying mesh-wide STRICT PeerAuthentication"
kubectl apply -f "${SCRIPT_DIR}/peer-authentication-strict.yaml"

# -----------------------------------------------------------------------------
# 5. Kiali (optional)
# -----------------------------------------------------------------------------
if [[ "${SKIP_KIALI}" != "1" ]]; then
  log "Installing Kiali addon"
  kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-1.22/samples/addons/kiali.yaml"
else
  log "SKIP_KIALI=1 set — skipping Kiali"
fi

# Note: Jaeger is intentionally NOT installed here.
# The observability stack (infra/k8s/observability/jaeger/) owns Jaeger.
# Istio sidecars will ship OTLP traces to jaeger-collector.observability:4317.
log "Skipping Jaeger install — see infra/k8s/observability/jaeger/ (single source of truth)"

# -----------------------------------------------------------------------------
# 6. Verify
# -----------------------------------------------------------------------------
log "Waiting for istio-system pods to become Ready (max 5 min)"
kubectl -n istio-system wait --for=condition=Ready pods --all --timeout=300s || \
  warn "Some pods are still not Ready — inspect with: kubectl -n istio-system get pods"

log "Done. Next steps:"
log "  - kubectl -n istio-system port-forward svc/kiali 20001:20001"
log "  - kubectl rollout restart deployment -n circleguard-dev   # re-inject sidecars"
log "  - kubectl apply -f ${SCRIPT_DIR}/authorization-policies/"
log "  - kubectl apply -f ${SCRIPT_DIR}/virtual-services/"
log "  - kubectl apply -f ${SCRIPT_DIR}/gateway/"
log "  - kubectl apply -f ${SCRIPT_DIR}/circuit-breaker-destination-rule.yaml"
