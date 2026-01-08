#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

k3d cluster create --config "${ROOT_DIR}/platform/k3d/k3d-config.yaml"

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl create namespace openchat-dev >/dev/null 2>&1 || true
kubectl create namespace observability >/dev/null 2>&1 || true

echo "Cluster created: ea-k3d"
