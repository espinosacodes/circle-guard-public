# CircleGuard - Test Suite

This directory contains integration, E2E and performance tests for the
seven CircleGuard microservices.

## Layout

```
tests/
  integration/   pytest tests for service-to-service communication
  e2e/           pytest tests for full user journeys
  performance/   locust file simulating realistic load
  requirements.txt
```

Unit tests live alongside each service's source under
`services/circleguard-*-service/src/test/java/...` and run with `./gradlew test`.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tests/requirements.txt
```

## Required port-forwards

Integration & E2E tests target services via `localhost`. With the dev cluster
deployed, set up forwards in one shell:

```bash
kubectl port-forward -n circleguard-dev svc/auth-service         8180:8180 &
kubectl port-forward -n circleguard-dev svc/identity-service     8083:8083 &
kubectl port-forward -n circleguard-dev svc/form-service         8086:8086 &
kubectl port-forward -n circleguard-dev svc/promotion-service    8088:8088 &
kubectl port-forward -n circleguard-dev svc/notification-service 8082:8082 &
kubectl port-forward -n circleguard-dev svc/gateway-service      8087:8087 &
kubectl port-forward -n circleguard-dev svc/dashboard-service    8084:8084 &
kubectl port-forward -n circleguard-dev svc/postgres             5432:5432 &
kubectl port-forward -n circleguard-dev svc/redis                6379:6379 &
kubectl port-forward -n circleguard-dev svc/kafka                9092:9092 &
```

## Running

```bash
# Unit tests (Gradle)
./gradlew test

# Integration tests
pytest tests/integration -v

# E2E tests
pytest tests/e2e -v

# Performance — headless 60s smoke
locust -f tests/performance/locustfile.py --headless \
       -u 50 -r 10 -t 60s --host http://localhost:8180 \
       --csv results/perf

# Performance — stress (peak gate hours)
locust -f tests/performance/locustfile.py --headless \
       -u 200 -r 50 -t 120s --host http://localhost:8087 \
       StressGateUser --csv results/perf-stress
```
