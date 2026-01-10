#!/usr/bin/env bash
set -euo pipefail

# scripts/nuke_and_rebuild.sh
#
# Fully resets the VM environment and redeploys from a fresh clone.
# Intended to be run INSIDE the Ubuntu VM.
#
# What it does:
# 1) Deletes k3d cluster (ea-k3d)
# 2) Optionally prunes Docker (images/containers/build cache)
# 3) Deletes the repo folder
# 4) Clones the repo fresh
# 5) Bootstraps: cluster, resolve versions, obs, apps-force, rabbitmq, messaging, keda, scaling
#
# Usage:
#   export EA_REPO_URL="https://github.com/<org>/<repo>.git"
#   export EA_REPO_DIR="$HOME/ea-arch-module"        # optional
#   export EA_CLUSTER_NAME="ea-k3d"                  # optional
#   export EA_DOCKER_PRUNE="yes"                     # optional ("yes" or "no")
#   bash scripts/nuke_and_rebuild.sh
#
# Notes:
# - Requires: git, docker, k3d, kubectl, make
# - If EA_DOCKER_PRUNE=yes, it will remove ALL unused images and build cache.

: "${EA_REPO_URL:?EA_REPO_URL is required (export it first)}"
EA_REPO_DIR="${EA_REPO_DIR:-$HOME/ea-arch-module}"
EA_CLUSTER_NAME="${EA_CLUSTER_NAME:-ea-k3d}"
EA_DOCKER_PRUNE="${EA_DOCKER_PRUNE:-no}"

echo "== 0) Sanity checks =="
command -v git >/dev/null 2>&1
command -v docker >/dev/null 2>&1
command -v k3d >/dev/null 2>&1
command -v kubectl >/dev/null 2>&1
command -v make >/dev/null 2>&1

echo "Repo URL:     ${EA_REPO_URL}"
echo "Repo dir:     ${EA_REPO_DIR}"
echo "Cluster name: ${EA_CLUSTER_NAME}"
echo "Docker prune: ${EA_DOCKER_PRUNE}"
echo

echo "== 1) Delete k3d cluster =="
k3d cluster delete "${EA_CLUSTER_NAME}" || true

echo "== 2) Optional Docker prune =="
if [[ "${EA_DOCKER_PRUNE}" == "yes" ]]; then
  echo "Stopping/removing containers (if any)..."
  docker ps -aq | xargs -r docker rm -f || true
  echo "Pruning build cache, images, networks, volumes..."
  docker volume prune -f || true
  docker network prune -f || true
  docker system prune -af || true
else
  echo "Skipping Docker prune."
fi

echo "== 3) Remove repo directory =="
rm -rf "${EA_REPO_DIR}"

echo "== 4) Fresh clone =="
git clone "${EA_REPO_URL}" "${EA_REPO_DIR}"
cd "${EA_REPO_DIR}"

echo "== 5) Create cluster =="
make cluster

echo "== 6) (Optional) import cache if dist/cache exists =="
if [[ -f dist/cache/images.txt ]]; then
  ./scripts/load_cache.sh || true
  ./scripts/k3d_import_cached_images.sh || true
fi

echo "== 7) Resolve versions + install observability =="
./scripts/resolve_versions.sh
make obs

echo "== 8) Build and deploy apps (force) =="
make apps-force

echo "== 9) Install RabbitMQ (manifest) + enable messaging overlay =="
make platform-rabbitmq
make messaging

echo "== 10) Install KEDA + apply scaling overlay =="
make platform-keda
make scaling

echo
echo "== 11) Summary =="
kubectl get nodes
kubectl get pods -A | sed -n '1,120p'
echo
echo "Nuke-and-rebuild complete."
echo "Next optional installs:"
echo "  make platform-openfaas"
echo "  make platform-kyverno"
echo "  make platform-keycloak"
echo "  make platform-velero   (if configured in this repo)"