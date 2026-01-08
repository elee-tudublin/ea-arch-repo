# Enterprise Architecture Design - Local-first Lab Repo (VM + k3d)

This repository provides a complete, local-first (VirtualBox Ubuntu VM) set of
labs that are also easy to deploy to public cloud Kubernetes.

Stack (open-source, platform-agnostic):
- Kubernetes: k3d (k3s in Docker)
- DB: PostgreSQL
- Messaging: RabbitMQ (AMQP, queues)
- Event scaling: KEDA
- Serverless: OpenFaaS
- Observability: OpenTelemetry (OTLP) -> OTel Collector -> Prometheus -> Grafana
- Policy-as-code: Kyverno
- IAM (teaching): Keycloak (dev mode)
- Backup/DR: Velero + MinIO (S3-compatible)

## Student quick start (inside the Ubuntu VM)
1) Create cluster:
   make cluster

2) If you received a cache bundle (dist/cache):
   ./scripts/load_cache.sh
   ./scripts/k3d_import_cached_images.sh

3) Lock versions (writes versions.lock):
   ./scripts/resolve_versions.sh

4) Install observability (OTel Collector + Prometheus + Grafana):
   make obs

5) Build and deploy apps (Postgres + services):
   make apps

6) Install week-specific platform components when needed:
   make platform-rabbitmq
   make messaging
   make platform-keda
   make scaling
   make platform-openfaas
   make platform-kyverno
   make platform-keycloak
   make platform-velero

7) Port-forward (run each command in a separate terminal):
   make pf

## Instructor: build offline-ish consistency bundle
1) ./scripts/resolve_versions.sh
2) ./scripts/preload.sh

This creates:
- dist/cache/vendor/charts/   (vendored Helm charts)
- dist/cache/images.tar       (pre-pulled images)
- dist/cache/images.txt       (list of images in images.tar)

Distribute dist/cache/ with your VM OVA or as a separate download.

## Sustainability and ethics
See:
- docs/sustainability/README.md
- docs/ethics/README.md

These are referenced by lab prompts and should appear in student architecture
narratives (drivers/NFRs, governance, audit readiness).
