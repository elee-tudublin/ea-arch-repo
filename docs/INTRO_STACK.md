# Lab Stack Overview (Local-first, Cloud-ready)

This document describes the applications and technologies used in the labs,
how they fit together, and how each maps to public cloud services.

Design goals:
- Platform-agnostic and open-source first (avoid lock-in).
- All labs run locally inside an Ubuntu VM using containers and Kubernetes.
- Cloud services are referenced and compared; manifests remain portable.

## 1) High-level architecture used in the labs

The labs implement a small system called OpenChat:
- thread-svc (FastAPI): manages threads
- post-svc (FastAPI): manages posts
- PostgreSQL: stores thread/post/country and lab tables for idempotency and moderation
- RabbitMQ: asynchronous message broker (publish post.created events)
- moderation-consumer: async worker that consumes messages and writes moderation results
- KEDA: scales moderation-consumer based on queue depth
- OpenTelemetry Collector: receives OTLP metrics and exposes Prometheus scrape endpoint
- Prometheus + Grafana: monitoring and dashboards
- OpenFaaS (optional): hosts a moderation function; consumer can call it
- Kyverno (optional): policy-as-code guardrails for Kubernetes
- Keycloak (optional): OIDC identity provider for IAM concepts
- Velero + MinIO (optional): backup/restore for DR exercises

## 2) Local runtime environment

### VirtualBox Ubuntu VM
- The VM is the controlled environment where students have admin rights.
- All tools are installed in the VM (Docker, kubectl, Helm, k3d).

### Docker Engine
- Builds and runs container images for services and workers.
- Also provides the container runtime used by k3d.

### k3d (Kubernetes in Docker using k3s)
- Runs a lightweight Kubernetes cluster inside Docker containers.
- Enables Kubernetes-native labs without needing a public cloud account.

Important note about images:
- k3d uses containerd inside its nodes; images built in Docker may need importing to the cluster.
- The repo uses k3d image import for student-built images and provides cache tooling for consistency.

## 3) Application layer (OpenChat services)

### FastAPI microservices (thread-svc and post-svc)
How used in labs:
- Demonstrate basic microservice structure and separation of concerns.
- Provide endpoints for generating traffic and creating realistic observability and reliability signals.
- Provide a concrete basis for database splitting, CAP theorem discussion, and idempotency design.

Key design choices:
- Layered structure: routes/controllers → services → data_access → models.
- Readiness endpoint checks DB connectivity.

Cloud mapping:
- Containers run similarly on any managed Kubernetes (EKS/AKS/GKE).
- Alternatively, could run on container platforms such as ECS/Fargate (AWS) or Azure Container Apps.

## 4) Data layer

### PostgreSQL
How used in labs:
- Implements the OpenChat schema (country/thread/post).
- Demonstrates referential integrity and coupling via foreign keys.
- Adds two additional tables for distributed systems concepts:
  - processed_event: idempotency store (consumer_name + event_id)
  - moderation: stores moderation decisions (minimize stored content in outputs)

Cloud mapping:
- AWS: RDS for PostgreSQL / Aurora PostgreSQL
- Azure: Azure Database for PostgreSQL
- GCP: Cloud SQL for PostgreSQL

Discussion points:
- Managed databases reduce operational work (backups, patching, HA options) but do not remove CAP trade-offs.

## 5) Asynchronous middleware

### RabbitMQ (AMQP broker)
How used in labs:
- post-svc publishes events (post.created) to an exchange.
- moderation-consumer consumes from a queue bound to the routing key.
- Demonstrates decoupling and stability through buffering and retries.

Delivery semantics in labs:
- The system should be treated as at-least-once: duplicates can happen.
- Consumers must be idempotent (using processed_event table).

Cloud mapping (conceptual equivalents):
- AWS: SQS/SNS (queue + pub/sub) or Amazon MQ (RabbitMQ-managed) or EventBridge
- Azure: Service Bus (queues/topics) or Event Grid
- GCP: Pub/Sub

Discussion points:
- Managed services reduce operational overhead but change integration details and observability surfaces.

## 6) Event-based scaling

### KEDA (Kubernetes Event-driven Autoscaling)
How used in labs:
- Scales moderation-consumer based on queue length in RabbitMQ.
- Demonstrates continuity under unpredictable demand and scale-to-zero behaviour.

Sustainability angle:
- Scale-to-zero reduces idle resource waste.
- Poorly tuned autoscaling can cause thrash and overload downstream dependencies.

Cloud mapping:
- KEDA runs on EKS/AKS/GKE the same way.
- Cloud-native autoscaling triggers exist, but KEDA keeps the pattern portable.

## 7) Observability

### OpenTelemetry (in-app instrumentation)
How used in labs:
- Services and workers export metrics via OTLP (HTTP) to the OTel Collector.
- HTTP request counters and latency histograms provide SLI candidates.

### OpenTelemetry Collector
How used in labs:
- Receives OTLP and exposes a Prometheus scrape endpoint.
- Provides a clean separation between app instrumentation and backend choice.

### Prometheus + Grafana
How used in labs:
- Prometheus scrapes the Collector endpoint.
- Grafana visualizes metrics and supports SLO discussions.

Cloud mapping:
- AWS: CloudWatch and/or managed Prometheus/Grafana offerings; ADOT for OTel
- Azure: Azure Monitor + OTel integration; managed Grafana options
- GCP: Cloud Monitoring/Logging; managed Prometheus; OTel support

Discussion points:
- OpenTelemetry helps keep observability portable even if the backend changes.

## 8) Serverless on Kubernetes (optional)

### OpenFaaS
How used in labs:
- Deploy a moderation function and call it from moderation-consumer.
- Demonstrates serverless trade-offs: scaling characteristics, latency, operational model.

Cloud mapping:
- AWS Lambda, Azure Functions, Google Cloud Functions
- Knative is another Kubernetes-based serverless alternative; not used here for VM simplicity.

## 9) Security and governance (optional)

### Kyverno (policy-as-code)
How used in labs:
- Enforces secure defaults (resource requests/limits; disallow privileged pods).
- Demonstrates governance and audit evidence via codified policies.

Cloud mapping:
- Admission controls work similarly on managed Kubernetes.
- Cloud-native policy layers exist (AWS Config, Azure Policy, GCP Org Policy) but do not replace in-cluster guardrails.

### Keycloak (OIDC identity provider) — teaching deployment
How used in labs:
- Demonstrates core IAM concepts: realms, clients, OIDC flows.
- Provides a practical anchor for “identity-centric security” and zero trust discussions.

Cloud mapping:
- AWS Cognito, Azure Entra ID, Google Identity / Identity Platform

## 10) DR and continuity (optional)

### Velero + MinIO
How used in labs:
- Velero performs backup and restore of Kubernetes resources (and optionally volumes).
- MinIO provides S3-compatible object storage for local backups.

Cloud mapping:
- Velero can target cloud object storage (S3/Blob/GCS) and snapshot services depending on configuration.
- Managed cloud backup services exist, but recovery testing and evidence remain your responsibility.

## 11) Where each lab uses the stack

- Lab 1: k3d + apps baseline
- Lab 2: OTel Collector + Prometheus + Grafana
- Lab 3: PostgreSQL schema inspection and coupling
- Lab 4: probes and failure behaviour (operability)
- Lab 5: RabbitMQ messaging + async consumer
- Lab 6: delivery semantics and idempotency (processed_event)
- Lab 7: KEDA scaling under demand
- Lab 8 (optional): OpenFaaS moderation function
- Lab 9 (optional): Kyverno policy-as-code
- Lab 10 (optional): Keycloak IAM concepts
- Lab 11 (optional): Velero backup/restore (DR)
- Lab 12: evidence pack and exam-style narrative practice

## 12) Cloud deployment note (portability)

The manifests and patterns used here are designed to be portable to public cloud Kubernetes.
When moving to cloud you typically change:
- storage classes and persistent volume configuration
- load balancers / ingress setup
- identity integration (cloud IAM, workload identity)
- managed services substitutions (managed DB, managed messaging, managed monitoring)

The architectural concepts remain the same:
- reliability targets and SLOs
- asynchronous decoupling and idempotency
- scaling policies and continuity planning
- security guardrails and audit evidence



Passwords:

Openfass: 6tULaH1RMGFU

