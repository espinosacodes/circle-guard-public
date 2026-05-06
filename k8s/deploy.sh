#!/bin/bash
# Deploy CircleGuard to Kubernetes
# Usage: ./deploy.sh <environment>
# Environments: dev, stage, master

set -e

ENV=${1:-dev}

if [[ ! "$ENV" =~ ^(dev|stage|master)$ ]]; then
    echo "Usage: $0 <dev|stage|master>"
    exit 1
fi

echo "========================================="
echo " Deploying CircleGuard to: $ENV"
echo "========================================="

echo "[1/3] Creating namespace..."
kubectl apply -f "k8s/${ENV}/namespace.yml"

echo "[2/3] Deploying infrastructure..."
kubectl apply -f "k8s/${ENV}/infrastructure.yml"

echo "[3/3] Deploying services..."
kubectl apply -f "k8s/${ENV}/services.yml"

echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all -n "circleguard-${ENV}" --timeout=120s || true

echo ""
echo "========================================="
echo " Deployment Status"
echo "========================================="
kubectl get pods -n "circleguard-${ENV}"
echo ""
kubectl get services -n "circleguard-${ENV}"
