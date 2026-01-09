SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

help:
	@printf "%s\n" \
	  "Targets:" \
	  "  make cluster              Create k3d cluster" \
	  "  make obs                  Install OTel Collector + Prometheus + Grafana" \
	  "  make apps                 Build/import images + deploy Postgres + services" \
	  "  make messaging            Enable RabbitMQ publishing + deploy moderation-consumer" \
	  "  make scaling              Apply KEDA ScaledObject + burst job" \
	  "  make status               Show pods/services" \
	  "  make pf                   Print port-forward commands" \
	  "" \
	  "Platform installs (Helm):" \
	  "  make platform-rabbitmq" \
	  "  make platform-keda" \
	  "  make platform-openfaas" \
	  "  make platform-kyverno" \
	  "  make platform-velero" \
	  "  make platform-argocd      (optional)" \
	  "" \
	  "Manifests:" \
	  "  make platform-keycloak" \
	  "" \
	  "Other:" \
	  "  make clean"

cluster:
	./scripts/k3d_create.sh

obs:
	kubectl apply -f apps/openchat/k8s/base/otel-collector.yaml
	./scripts/resolve_versions.sh
	helm repo add prometheus-community $$(grep PROM_REPO versions.lock | cut -d= -f2)
	helm repo add grafana $$(grep GRAFANA_REPO versions.lock | cut -d= -f2)
	helm repo update
	helm upgrade --install prom $$(grep PROM_CHART versions.lock | cut -d= -f2) \
	  -n observability --create-namespace \
	  --version $$(grep PROM_VERSION versions.lock | cut -d= -f2) \
	  -f platform/observability/prometheus-values.yaml
	helm upgrade --install grafana $$(grep GRAFANA_CHART versions.lock | cut -d= -f2) \
	  -n observability \
	  --version $$(grep GRAFANA_VERSION versions.lock | cut -d= -f2) \
	  -f platform/observability/grafana-values.yaml

apps:
	docker build -t openchat/thread-svc:1.0.0 \
	  -f apps/openchat/services/thread-svc/Dockerfile \
	  apps/openchat
	docker build -t openchat/post-svc:1.0.0 \
	  -f apps/openchat/services/post-svc/Dockerfile \
	  apps/openchat
	docker build -t openchat/moderation-consumer:1.0.0 \
	  -f apps/openchat/workers/moderation-consumer/Dockerfile \
	  apps/openchat
	docker build -t openchat/burst-publisher:1.0.0 \
	  -f apps/openchat/tools/burst-publisher/Dockerfile \
	  apps/openchat
	k3d image import -c ea-k3d \
	  openchat/thread-svc:1.0.0 \
	  openchat/post-svc:1.0.0 \
	  openchat/moderation-consumer:1.0.0 \
	  openchat/burst-publisher:1.0.0
	kubectl apply -k apps/openchat/k8s/overlays/dev

messaging:
	kubectl apply -k apps/openchat/k8s/overlays/dev-messaging

scaling:
	kubectl apply -k apps/openchat/k8s/overlays/dev-messaging-scaling

platform-rabbitmq:
	kubectl apply -f platform/messaging/rabbitmq.yaml

platform-keda:
	./scripts/resolve_versions.sh
	@source versions.lock && \
	./scripts/helm_install_component.sh keda keda keda \
	  "$$KEDA_CHART" "$$KEDA_VERSION" platform/keda/values.yaml

platform-openfaas:
	kubectl create namespace openfaas >/dev/null 2>&1 || true
	kubectl create namespace openfaas-fn >/dev/null 2>&1 || true
	./scripts/resolve_versions.sh
	@source versions.lock && \
	./scripts/helm_install_component.sh openfaas openfaas openfaas \
	  "$$OPENFAAS_CHART" "$$OPENFAAS_VERSION" platform/openfaas/values.yaml

platform-kyverno:
	./scripts/resolve_versions.sh
	@source versions.lock && \
	./scripts/helm_install_component.sh kyverno kyverno kyverno \
	  "$$KYVERNO_CHART" "$$KYVERNO_VERSION" platform/kyverno/values.yaml
	@echo "Waiting for Kyverno CRDs to be registered..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \
	  kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1 && break; \
	  sleep 5; \
	done
	kubectl apply -f platform/kyverno/policies/require-requests-limits.yaml
	kubectl apply -f platform/kyverno/policies/disallow-privileged.yaml

platform-velero:
	kubectl apply -f platform/velero/minio.yaml
	./scripts/resolve_versions.sh
	@source versions.lock && \
	./scripts/helm_install_component.sh velero velero velero \
	  "$$VELERO_CHART" "$$VELERO_VERSION" platform/velero/values.yaml

platform-keycloak:
	kubectl apply -f platform/identity/keycloak.yaml

platform-argocd:
	./scripts/resolve_versions.sh
	@source versions.lock && \
	./scripts/helm_install_component.sh argocd argocd argo-cd \
	  "$$ARGOCD_CHART" "$$ARGOCD_VERSION" platform/argocd/values.yaml

status:
	kubectl get pods -A
	kubectl get svc -A

pf:
	@printf "%s\n" \
	  "Run these in separate terminals:" \
	  "  kubectl -n observability port-forward svc/grafana 3000:80" \
	  "  kubectl -n openchat-dev port-forward svc/thread-svc 8080:80" \
	  "  kubectl -n openchat-dev port-forward svc/post-svc 8081:80" \
	  "  kubectl -n messaging port-forward svc/rabbitmq 15672:15672"

clean:
	kubectl delete ns openchat-dev --ignore-not-found=true

apps-force:
	make -B apps

