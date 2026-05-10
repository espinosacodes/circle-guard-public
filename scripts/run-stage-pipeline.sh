#!/bin/bash
# =====================================================================
# Local equivalent of Jenkinsfile.stage — runs every stage in order so
# the stage pipeline can be validated end-to-end without Jenkins.
# =====================================================================
set -uo pipefail

NAMESPACE="circleguard-stage"
KIND_CLUSTER="desktop"
GIT_SHA="$(git rev-parse --short HEAD)"

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

step() { echo ""; echo "================================================="; echo " [stage] $1"; echo "================================================="; }

step "1/9 Build all services with Gradle"
./gradlew clean bootJar --no-daemon --parallel

step "2/9 Unit tests"
./gradlew test --no-daemon --parallel || echo "[stage] some unit tests failed, continuing"

step "3/9 Docker build + load into kind"
for svc in "${SERVICES[@]}"; do
    short="${svc#circleguard-}"
    docker build -q -t "circleguard/${short}:${GIT_SHA}" \
                    -t "circleguard/${short}:stage" \
                    -t "circleguard/${short}:latest" \
                    "services/${svc}/" > /dev/null
    kind load docker-image "circleguard/${short}:latest" --name "$KIND_CLUSTER" 2>/dev/null \
        | tail -1
done

step "4/9 Deploy to K8s stage namespace"
kubectl apply -f k8s/stage/namespace.yml
kubectl create configmap postgres-init --from-file=init-db.sql=init-db.sql \
        --namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/stage/infrastructure.yml
kubectl apply -f k8s/stage/services.yml
kubectl rollout restart deployment -n "$NAMESPACE" > /dev/null
kubectl rollout status deployment --timeout=180s -n "$NAMESPACE" || true

step "5/9 Wait for pods Ready"
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=180s || true
kubectl get pods -n "$NAMESPACE"

step "6/9 Setup port-forwards"
rm -f .pf_pids
for spec in "${PORTS[@]}"; do
    svc="${spec%%:*}"; port="${spec##*:}"
    kubectl port-forward -n "$NAMESPACE" "svc/${svc}" "${port}:${port}" > /dev/null 2>&1 &
    echo $! >> .pf_pids
done
sleep 5

# Python venv reused across runs
if [ ! -d .venv-stage ]; then
    python3 -m venv .venv-stage
fi
# shellcheck disable=SC1091
. .venv-stage/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r tests/requirements.txt

step "7/9 Integration tests against stage K8s"
pytest tests/integration -v --junitxml=results/integration-stage.xml || true

step "8/9 E2E tests against stage K8s"
pytest tests/e2e -v --junitxml=results/e2e-stage.xml || true

step "9/9 Performance tests (Locust) against stage K8s"
locust -f tests/performance/locustfile.py --headless \
    --users 50 --spawn-rate 10 --run-time 60s \
    --host http://localhost:8180 \
    --csv results/perf-stage \
    --csv-full-history \
    --html results/perf-stage.html || true

step "Teardown port-forwards"
while read -r pid; do kill "$pid" 2>/dev/null || true; done < .pf_pids
rm -f .pf_pids

step "STAGE pipeline complete"
kubectl get pods -n "$NAMESPACE"
echo ""
echo "Results stored under results/"
ls -la results/ | head -30
