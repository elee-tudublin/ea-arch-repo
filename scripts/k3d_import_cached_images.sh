#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:-ea-k3d}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_LIST="${ROOT_DIR}/dist/cache/images.txt"

if [[ ! -f "$IMG_LIST" ]]; then
  echo "Missing $IMG_LIST. Run ./scripts/load_cache.sh first." >&2
  exit 1
fi

mapfile -t imgs <"$IMG_LIST"
k3d image import -c "$CLUSTER" "${imgs[@]}"

echo "Imported cached images into k3d cluster: ${CLUSTER}"
