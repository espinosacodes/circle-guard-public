#!/usr/bin/env bash
# =============================================================================
# Chaos Mesh installer for CircleGuard
#
# Idempotent: safe to re-run; the chart is upgraded in place.
#
# Usage:
#   ./install.sh
#   CHAOS_MESH_VERSION=2.7.0 ./install.sh
#
# Prereqs: kubectl + helm authenticated against the target GKE cluster.
# =============================================================================
set -euo pipefail

CHAOS_MESH_VERSION="${CHAOS_MESH_VERSION:-2.7.0}"
NAMESPACE="${NAMESPACE:-chaos-mesh}"
# GKE uses containerd; the socket path differs from Docker.
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-containerd}"
CONTAINERD_SOCKET="${CONTAINERD_SOCKET:-/run/containerd/containerd.sock}"

log()  { printf "\033[1;34m[chaos-mesh]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[chaos-mesh][warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[chaos-mesh][err]\033[0m %s\n" "$*" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl is required"
command -v helm    >/dev/null 2>&1 || die "helm is required"
kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"

# -----------------------------------------------------------------------------
# 1. Helm repo
# -----------------------------------------------------------------------------
if ! helm repo list 2>/dev/null | grep -q '^chaos-mesh\s'; then
  log "Adding chaos-mesh helm repo"
  helm repo add chaos-mesh https://charts.chaos-mesh.org
fi
helm repo update chaos-mesh >/dev/null

# -----------------------------------------------------------------------------
# 2. Namespace
# -----------------------------------------------------------------------------
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  log "Creating namespace ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}"
else
  log "Namespace ${NAMESPACE} already exists"
fi

# -----------------------------------------------------------------------------
# 3. Install / upgrade
# -----------------------------------------------------------------------------
log "Installing Chaos Mesh ${CHAOS_MESH_VERSION} (runtime=${CONTAINER_RUNTIME})"
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace "${NAMESPACE}" \
  --version "${CHAOS_MESH_VERSION}" \
  --set chaosDaemon.runtime="${CONTAINER_RUNTIME}" \
  --set chaosDaemon.socketPath="${CONTAINERD_SOCKET}" \
  --set dashboard.create=true \
  --set dashboard.securityMode=true \
  --wait --timeout 5m

# -----------------------------------------------------------------------------
# 4. Verify
# -----------------------------------------------------------------------------
log "Waiting for Chaos Mesh pods to be Ready"
kubectl -n "${NAMESPACE}" wait --for=condition=Ready pods --all --timeout=180s || \
  warn "Some Chaos Mesh pods are still not Ready — kubectl -n ${NAMESPACE} get pods"

log "Done. Next steps:"
log "  - kubectl -n ${NAMESPACE} port-forward svc/chaos-dashboard 2333:2333"
log "  - open http://localhost:2333 (security mode is ON; create a token via the dashboard)"
log "  - kubectl apply -f $(dirname "$0")/experiments/pod-kill-promotion.yaml"
log "  - kubectl apply -f $(dirname "$0")/workflows/full-resilience-suite.yaml"
