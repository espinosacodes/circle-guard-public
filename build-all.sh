#!/bin/bash
set -e

echo "========================================="
echo " CircleGuard - Build All Microservices"
echo "========================================="

SERVICES=(
  "circleguard-auth-service"
  "circleguard-identity-service"
  "circleguard-form-service"
  "circleguard-promotion-service"
  "circleguard-notification-service"
  "circleguard-gateway-service"
  "circleguard-dashboard-service"
  "circleguard-file-service"
)

# Step 1: Build all JARs with Gradle
echo ""
echo "[1/2] Building JARs with Gradle..."
./gradlew bootJar --no-daemon

# Step 2: Build Docker images
echo ""
echo "[2/2] Building Docker images..."
for SERVICE in "${SERVICES[@]}"; do
  SHORT_NAME="${SERVICE#circleguard-}"
  echo "  Building circleguard/${SHORT_NAME}..."
  docker build -t "circleguard/${SHORT_NAME}:latest" "services/${SERVICE}/"
done

echo ""
echo "========================================="
echo " All images built successfully!"
echo "========================================="
docker images | grep circleguard
