#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/dist/cache"
IMG_TAR="${CACHE_DIR}/images.tar"

if [[ ! -f "${IMG_TAR}" ]]; then
  echo "Missing ${IMG_TAR}. Ask instructor for dist/cache bundle." >&2
  exit 1
fi

docker load -i "${IMG_TAR}"
echo "Loaded images from ${IMG_TAR}"
