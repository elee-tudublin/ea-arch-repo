#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/versions.env"

OUT="${ROOT_DIR}/versions.lock"

helm repo add prometheus-community "${REPO_PROM}" >/dev/null 2>&1 || true
helm repo add grafana "${REPO_GRAFANA}" >/dev/null 2>&1 || true
helm repo add argo "${REPO_ARGO}" >/dev/null 2>&1 || true
helm repo add bitnami "${REPO_BITNAMI}" >/dev/null 2>&1 || true
helm repo add kedacore "${REPO_KEDA}" >/dev/null 2>&1 || true
helm repo add openfaas "${REPO_OPENFAAS}" >/dev/null 2>&1 || true
helm repo add kyverno "${REPO_KYVERNO}" >/dev/null 2>&1 || true
helm repo add vmware-tanzu "${REPO_VELERO}" >/dev/null 2>&1 || true
helm repo update >/dev/null

get_ver() {
  local chart="$1"
  helm search repo "${chart}" -o json \
    | python3 -c "import json,sys;print(json.load(sys.stdin)[0]['version'])"
}

PROM_VERSION="$(get_ver "${CHART_PROM}")"
GRAFANA_VERSION="$(get_ver "${CHART_GRAFANA}")"
ARGOCD_VERSION="$(get_ver "${CHART_ARGOCD}")"
RABBITMQ_VERSION="$(get_ver "${CHART_RABBITMQ}")"
KEDA_VERSION="$(get_ver "${CHART_KEDA}")"
OPENFAAS_VERSION="$(get_ver "${CHART_OPENFAAS}")"
KYVERNO_VERSION="$(get_ver "${CHART_KYVERNO}")"
VELERO_VERSION="$(get_ver "${CHART_VELERO}")"

cat >"${OUT}" <<EOF2
PROM_REPO=${REPO_PROM}
GRAFANA_REPO=${REPO_GRAFANA}
ARGO_REPO=${REPO_ARGO}
BITNAMI_REPO=${REPO_BITNAMI}
KEDA_REPO=${REPO_KEDA}
OPENFAAS_REPO=${REPO_OPENFAAS}
KYVERNO_REPO=${REPO_KYVERNO}
VELERO_REPO=${REPO_VELERO}

PROM_CHART=${CHART_PROM}
GRAFANA_CHART=${CHART_GRAFANA}
ARGOCD_CHART=${CHART_ARGOCD}
RABBITMQ_CHART=${CHART_RABBITMQ}
KEDA_CHART=${CHART_KEDA}
OPENFAAS_CHART=${CHART_OPENFAAS}
KYVERNO_CHART=${CHART_KYVERNO}
VELERO_CHART=${CHART_VELERO}

PROM_VERSION=${PROM_VERSION}
GRAFANA_VERSION=${GRAFANA_VERSION}
ARGOCD_VERSION=${ARGOCD_VERSION}
RABBITMQ_VERSION=${RABBITMQ_VERSION}
KEDA_VERSION=${KEDA_VERSION}
OPENFAAS_VERSION=${OPENFAAS_VERSION}
KYVERNO_VERSION=${KYVERNO_VERSION}
VELERO_VERSION=${VELERO_VERSION}

K3S_IMAGE=${K3S_IMAGE}

OTEL_COLLECTOR_IMAGE=${OTEL_COLLECTOR_IMAGE}
POSTGRES_IMAGE=${POSTGRES_IMAGE}
KEYCLOAK_IMAGE=${KEYCLOAK_IMAGE}
MINIO_IMAGE=${MINIO_IMAGE}

THREAD_IMAGE=${THREAD_IMAGE}
POST_IMAGE=${POST_IMAGE}
MOD_CONSUMER_IMAGE=${MOD_CONSUMER_IMAGE}
BURST_PUBLISHER_IMAGE=${BURST_PUBLISHER_IMAGE}
EOF2

echo "Wrote ${OUT}"
