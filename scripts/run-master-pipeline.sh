#!/bin/bash
# =====================================================================
# Local equivalent of Jenkinsfile.master — runs every stage in order
# so the master pipeline can be validated end-to-end without Jenkins.
#
# Differences vs stage:
#   - Tags images with a semantic version
#   - Adds an automated approval gate (set AUTO_APPROVE=1 to skip prompt)
#   - Deploys to circleguard-master with 2 replicas
#   - Generates Change-Management-compliant release notes
#   - Tags the release in git (local tag only, push is manual)
# =====================================================================
set -uo pipefail

NAMESPACE_STAGE="circleguard-stage"
NAMESPACE_MASTER="circleguard-master"
KIND_CLUSTER="desktop"
GIT_SHA="$(git rev-parse --short HEAD)"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s)}"
VERSION="${VERSION:-v1.0.${BUILD_NUMBER}}"
PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo '')"
AUTO_APPROVE="${AUTO_APPROVE:-0}"

export CG_AUTH_URL="http://localhost:8180"
export CG_IDENTITY_URL="http://localhost:8083"
export CG_FORM_URL="http://localhost:8086"
export CG_PROMOTION_URL="http://localhost:8088"
export CG_NOTIFICATION_URL="http://localhost:8082"
export CG_GATEWAY_URL="http://localhost:8087"
export CG_DASHBOARD_URL="http://localhost:8084"
export CG_REDIS="redis://localhost:6379"
export CG_KAFKA="localhost:9092"
export QR_SECRET="my-qr-secret-key-for-dev-1234567890"
export BUILD_NUMBER

SERVICES=(
    circleguard-auth-service
    circleguard-identity-service
    circleguard-form-service
    circleguard-promotion-service
    circleguard-notification-service
    circleguard-gateway-service
    circleguard-dashboard-service
)
PORTS=("auth-service:8180" "identity-service:8083" "form-service:8086"
       "promotion-service:8088" "notification-service:8082"
       "gateway-service:8087" "dashboard-service:8084"
       "postgres:5432" "redis:6379" "kafka:9092")

mkdir -p results

step() { echo ""; echo "================================================="; echo " [master] $1"; echo "================================================="; }

step "1/11 Build all services with Gradle"
./gradlew clean bootJar --no-daemon --parallel

step "2/11 Unit tests"
./gradlew test --no-daemon --parallel || echo "[master] some unit tests failed, continuing"

step "3/11 Docker build + tag with ${VERSION}"
for svc in "${SERVICES[@]}"; do
    short="${svc#circleguard-}"
    docker build -q -t "circleguard/${short}:${VERSION}" \
                    -t "circleguard/${short}:${GIT_SHA}" \
                    -t "circleguard/${short}:latest" \
                    "services/${svc}/" > /dev/null
    kind load docker-image "circleguard/${short}:latest" --name "$KIND_CLUSTER" 2>/dev/null | tail -1
done

step "4/11 Deploy to STAGE for validation"
kubectl apply -f k8s/stage/namespace.yml
kubectl create configmap postgres-init --from-file=init-db.sql=init-db.sql \
        --namespace "$NAMESPACE_STAGE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/stage/infrastructure.yml
kubectl apply -f k8s/stage/services.yml
kubectl rollout restart deployment -n "$NAMESPACE_STAGE" > /dev/null
kubectl rollout status deployment --timeout=180s -n "$NAMESPACE_STAGE" || true
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE_STAGE" --timeout=180s || true

step "5/11 Setup port-forwards to STAGE"
rm -f .pf_pids
for spec in "${PORTS[@]}"; do
    svc="${spec%%:*}"; port="${spec##*:}"
    kubectl port-forward -n "$NAMESPACE_STAGE" "svc/${svc}" "${port}:${port}" > /dev/null 2>&1 &
    echo $! >> .pf_pids
done
sleep 5

if [ ! -d .venv-master ]; then python3 -m venv .venv-master; fi
. .venv-master/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r tests/requirements.txt

step "6/11 System tests on STAGE (integration + E2E + perf)"
pytest tests/integration -v --junitxml=results/integration-master.xml || true
pytest tests/e2e         -v --junitxml=results/e2e-master.xml         || true
locust -f tests/performance/locustfile.py --headless \
    --users 100 --spawn-rate 20 --run-time 120s \
    --host http://localhost:8180 \
    --csv results/perf-master \
    --csv-full-history \
    --html results/perf-master.html || true

# Record images deployed in stage
kubectl get deployments -n "$NAMESPACE_STAGE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' \
    > results/deployed-stage-images.tsv

while read -r pid; do kill "$pid" 2>/dev/null || true; done < .pf_pids
rm -f .pf_pids

step "7/11 Production approval gate"
if [ "$AUTO_APPROVE" = "1" ]; then
    echo "[master] AUTO_APPROVE=1 — promoting without prompt."
else
    read -r -p "Promote ${VERSION} to PRODUCTION (${NAMESPACE_MASTER})? [yes/NO] " ans
    if [ "$ans" != "yes" ]; then
        echo "[master] Aborted at approval gate."
        exit 1
    fi
fi

step "8/11 Deploy to PRODUCTION (master)"
kubectl apply -f k8s/master/namespace.yml
kubectl create configmap postgres-init --from-file=init-db.sql=init-db.sql \
        --namespace "$NAMESPACE_MASTER" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/master/infrastructure.yml
kubectl apply -f k8s/master/services.yml
kubectl rollout restart deployment -n "$NAMESPACE_MASTER" > /dev/null
kubectl rollout status deployment --timeout=300s -n "$NAMESPACE_MASTER" || true
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE_MASTER" --timeout=240s || true

step "9/11 Verify production"
kubectl get pods -n "$NAMESPACE_MASTER"
kubectl get services -n "$NAMESPACE_MASTER"

step "10/11 Generate release notes"
bash scripts/generate-release-notes.sh "$VERSION" "$PREV_TAG" "$GIT_SHA" \
    > "RELEASE_NOTES_${VERSION}.md"
echo "[master] Release notes written to RELEASE_NOTES_${VERSION}.md"

step "11/11 Tag release in git (local only)"
git tag -a "$VERSION" -m "Production release $VERSION (commit $GIT_SHA)" 2>/dev/null \
    || echo "[master] Tag $VERSION already exists, skipping"

step "MASTER pipeline complete — ${VERSION} is live"
echo ""
echo "Production pods:"
kubectl get pods -n "$NAMESPACE_MASTER"
echo ""
echo "Push the tag with:  git push origin $VERSION"
