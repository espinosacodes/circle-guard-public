#!/usr/bin/env bash
# =====================================================================
# CircleGuard - SonarQube install/upgrade
# =====================================================================
# Idempotent: re-running this script either installs SonarQube fresh or
# upgrades the existing release in-place. Safe to run from CI or laptop.
#
# Prereqs:
#   - kubectl context pointed at the right cluster
#   - helm >= 3.12 in $PATH
#   - sonarqube-db / sonarqube-admin / sonarqube-monitoring Secrets
#     already applied (see db-secret-example.yaml)
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-sonarqube}"
RELEASE="${RELEASE:-sonarqube}"
CHART_VERSION="${CHART_VERSION:-10.6.1}"   # chart version, NOT Sonar version
VALUES_FILE="${VALUES_FILE:-${SCRIPT_DIR}/values.yaml}"

echo "==> Using namespace=${NAMESPACE} release=${RELEASE} chart=${CHART_VERSION}"

# ---------------------------------------------------------------------
# 1. Ensure the repo is registered + up to date.
# ---------------------------------------------------------------------
if ! helm repo list | awk '{print $1}' | grep -qx "sonarqube"; then
    echo "==> Adding sonarqube helm repo"
    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
fi
helm repo update sonarqube >/dev/null

# ---------------------------------------------------------------------
# 2. Create the namespace if missing.
# ---------------------------------------------------------------------
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------
# 3. Verify the required Secrets exist BEFORE the chart tries to mount
#    them — otherwise the pod CrashLoopBackOff with a confusing error.
# ---------------------------------------------------------------------
required_secrets=(sonarqube-db sonarqube-admin sonarqube-monitoring)
for s in "${required_secrets[@]}"; do
    if ! kubectl get secret "${s}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "ERROR: Secret '${s}' missing in namespace '${NAMESPACE}'." >&2
        echo "       Apply infra/k8s/sonarqube/db-secret-example.yaml (filled in) first." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------
# 4. helm upgrade --install (idempotent).
# ---------------------------------------------------------------------
echo "==> helm upgrade --install (may take ~3 min on first run)"
helm upgrade --install "${RELEASE}" sonarqube/sonarqube \
    --namespace "${NAMESPACE}" \
    --version "${CHART_VERSION}" \
    --values "${VALUES_FILE}" \
    --wait \
    --timeout 10m

# ---------------------------------------------------------------------
# 5. Print connection info for the operator.
# ---------------------------------------------------------------------
echo
echo "==> SonarQube installed. Connection info:"
echo "    Ingress URL  : https://sonarqube.circleguard.local"
echo "    Port-forward : kubectl port-forward -n ${NAMESPACE} svc/${RELEASE}-sonarqube 9000:9000"
echo "    Admin user   : admin"
echo "    Admin pass   : kubectl get secret sonarqube-admin -n ${NAMESPACE} -o jsonpath='{.data.password}' | base64 -d"
echo
echo "==> Next steps:"
echo "    1. Log in and rotate the admin password."
echo "    2. Create the 'gitlab-ci' user + Global Analysis Token (see README.md)."
echo "    3. Set SONAR_HOST_URL + SONAR_TOKEN in GitLab CI/CD variables."
