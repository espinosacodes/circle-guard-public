#!/bin/bash
set -e

echo "========================================="
echo " CircleGuard - Build All Microservices"
echo "========================================="

SERVICES=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-form-service"
  "circleguard-file-service"
  "circleguard-promotion-service"
  "circleguard-notification-service"
  "circleguard-gateway-service"
  "circleguard-dashboard-service"
)

REGISTRY="${REGISTRY:-circleguard}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORM="${PLATFORM:-linux/amd64}"

# Step 1: Build all JARs with Gradle
echo ""
echo "[1/2] Building JARs with Gradle..."
./gradlew bootJar --no-daemon

# Step 2: Build Docker images
echo ""
echo "[2/2] Building Docker images..."
for SERVICE in "${SERVICES[@]}"; do
  SHORT_NAME="${SERVICE#circleguard-}"
  echo "  Building ${REGISTRY}/${SHORT_NAME}:${IMAGE_TAG}..."
  docker build \
    --platform "${PLATFORM}" \
    -t "${REGISTRY}/${SHORT_NAME}:${IMAGE_TAG}" \
    "services/${SERVICE}/"
done

echo ""
echo "========================================="
echo " All images built successfully!"
echo "========================================="
docker images | grep "$(basename "${REGISTRY}")"
