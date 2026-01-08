#!/usr/bin/env bash
set -euo pipefail

# ./scripts/helm_install_component.sh \
#   <release> <namespace> <vendored_chart_dirname> \
#   <chart_ref> <chart_version> <values_file_or_dash>

REL="$1"
NS="$2"
VENDOR_DIRNAME="$3"
CHART_REF="$4"
CHART_VERSION="$5"
VALUES="$6"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDORED="${ROOT_DIR}/dist/cache/vendor/charts/${VENDOR_DIRNAME}"

CHART="$CHART_REF"
EXTRA_ARGS=(--version "$CHART_VERSION")

kubectl create namespace "$NS" >/dev/null 2>&1 || true

if [[ -d "$VENDORED" ]]; then
  CHART="$VENDORED"
fi

if [[ "$VALUES" == "-" ]]; then
  helm upgrade --install "$REL" "$CHART" -n "$NS" "${EXTRA_ARGS[@]}"
else
  helm upgrade --install "$REL" "$CHART" -n "$NS" "${EXTRA_ARGS[@]}" -f "$VALUES"
fi
