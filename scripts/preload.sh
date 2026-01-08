#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="${ROOT_DIR}/versions.lock"

if [[ ! -f "${LOCK}" ]]; then
  echo "Missing versions.lock. Run ./scripts/resolve_versions.sh first." >&2
  exit 1
fi

source "${LOCK}"

CACHE_DIR="${ROOT_DIR}/dist/cache"
CHART_DIR="${CACHE_DIR}/vendor/charts"
IMG_TAR="${CACHE_DIR}/images.tar"
IMG_LIST="${CACHE_DIR}/images.txt"

mkdir -p "${CHART_DIR}"

helm repo add prometheus-community "${PROM_REPO}" >/dev/null 2>&1 || true
helm repo add grafana "${GRAFANA_REPO}" >/dev/null 2>&1 || true
helm repo add argo "${ARGO_REPO}" >/dev/null 2>&1 || true
helm repo add bitnami "${BITNAMI_REPO}" >/dev/null 2>&1 || true
helm repo add kedacore "${KEDA_REPO}" >/dev/null 2>&1 || true
helm repo add openfaas "${OPENFAAS_REPO}" >/dev/null 2>&1 || true
helm repo add kyverno "${KYVERNO_REPO}" >/dev/null 2>&1 || true
helm repo add vmware-tanzu "${VELERO_REPO}" >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Vendoring Helm charts into ${CHART_DIR}"
helm pull "${PROM_CHART}" --version "${PROM_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${GRAFANA_CHART}" --version "${GRAFANA_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${ARGOCD_CHART}" --version "${ARGOCD_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${RABBITMQ_CHART}" --version "${RABBITMQ_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${KEDA_CHART}" --version "${KEDA_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${OPENFAAS_CHART}" --version "${OPENFAAS_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${KYVERNO_CHART}" --version "${KYVERNO_VERSION}" --untar --untardir "${CHART_DIR}"
helm pull "${VELERO_CHART}" --version "${VELERO_VERSION}" --untar --untardir "${CHART_DIR}"

echo "Building app images"
docker build -t "${THREAD_IMAGE}" "${ROOT_DIR}/apps/openchat/services/thread-svc"
docker build -t "${POST_IMAGE}" "${ROOT_DIR}/apps/openchat/services/post-svc"
docker build -t "${MOD_CONSUMER_IMAGE}" "${ROOT_DIR}/apps/openchat/workers/moderation-consumer"
docker build -t "${BURST_PUBLISHER_IMAGE}" "${ROOT_DIR}/apps/openchat/tools/burst-publisher"

echo "Pulling pinned base images"
docker pull "${OTEL_COLLECTOR_IMAGE}"
docker pull "${POSTGRES_IMAGE}"
docker pull "${KEYCLOAK_IMAGE}"
docker pull "${MINIO_IMAGE}"
docker pull "${K3S_IMAGE}"

# Best-effort extraction of images from rendered YAML (not perfect, but good enough).
render_chart() {
  local rel="$1"
  local ns="$2"
  local chart_dir="$3"
  local values="$4"

  if [[ "$values" == "-" ]]; then
    helm template "$rel" "$chart_dir" -n "$ns"
  else
    helm template "$rel" "$chart_dir" -n "$ns" -f "$values"
  fi
}

tmp="$(mktemp)"
{
  render_chart prom observability "${CHART_DIR}/prometheus" "${ROOT_DIR}/platform/observability/prometheus-values.yaml"
  render_chart grafana observability "${CHART_DIR}/grafana" "${ROOT_DIR}/platform/observability/grafana-values.yaml"
  render_chart rabbitmq messaging "${CHART_DIR}/rabbitmq" "${ROOT_DIR}/platform/messaging/rabbitmq-values.yaml"
  render_chart keda keda "${CHART_DIR}/keda" "${ROOT_DIR}/platform/keda/values.yaml"
  render_chart openfaas openfaas "${CHART_DIR}/openfaas" "${ROOT_DIR}/platform/openfaas/values.yaml"
  render_chart kyverno kyverno "${CHART_DIR}/kyverno" "${ROOT_DIR}/platform/kyverno/values.yaml"
  render_chart velero velero "${CHART_DIR}/velero" "${ROOT_DIR}/platform/velero/values.yaml"
} >"$tmp"

mapfile -t chart_images < <(
  awk '/image:/ {print $2}' "$tmp" \
    | tr -d '"' \
    | awk 'NF' \
    | sort -u
)
rm -f "$tmp"

echo "Pulling chart images (best-effort)"
for img in "${chart_images[@]}"; do
  docker pull "$img" || true
done

{
  echo "${THREAD_IMAGE}"
  echo "${POST_IMAGE}"
  echo "${MOD_CONSUMER_IMAGE}"
  echo "${BURST_PUBLISHER_IMAGE}"
  echo "${OTEL_COLLECTOR_IMAGE}"
  echo "${POSTGRES_IMAGE}"
  echo "${KEYCLOAK_IMAGE}"
  echo "${MINIO_IMAGE}"
  echo "${K3S_IMAGE}"
  printf "%s\n" "${chart_images[@]}"
} | awk 'NF' | sort -u >"${IMG_LIST}"

echo "Saving images to ${IMG_TAR}"
docker save $(cat "${IMG_LIST}") -o "${IMG_TAR}"

mkdir -p "${CACHE_DIR}"
cat >"${CACHE_DIR}/README.txt" <<EOF2
Course cache bundle

Contains:
- images.tar: pre-pulled images
- images.txt: list of images in images.tar
- vendor/charts: vendored Helm charts

Student usage:
  ./scripts/load_cache.sh
  ./scripts/k3d_import_cached_images.sh
EOF2

echo "Done. Cache written to ${CACHE_DIR}"
