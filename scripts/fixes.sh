#!/usr/bin/env bash
set -euo pipefail

# scripts/apply_all_fixes.sh
#
# Applies the core fixes needed to make the repo build/run reliably on BOTH arm64 and amd64:
# - Standardize Docker build context to apps/openchat (fixes COPY-outside-context failures)
# - Overwrite OpenChat Dockerfiles to use context-relative COPY paths
# - Patch Makefile to build with -f <Dockerfile> apps/openchat and add apps-force
# - Fix kustomize overlay dev (ConfigMap should be a resource, not a patch)
# - Fix Postgres StatefulSet volumeMount (mount the PVC correctly)
# - Replace Bitnami RabbitMQ dependency with an official RabbitMQ manifest (multi-arch)
# - Ensure OpenFaaS namespaces exist BEFORE helm install
# - Update Velero values to new schema (removes removed configuration.provider)
#
# Run from repo root:
#   bash scripts/apply_all_fixes.sh

python3 - <<'PY'
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path.cwd()

def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip() + "\n", encoding="utf-8")

def must_exist(path: Path, desc: str) -> None:
    if not path.exists():
        raise SystemExit(f"Missing {desc}: {path}")

# ------------------------------------------------------------------------------
# 1) Standardize Dockerfiles (context = apps/openchat)
# ------------------------------------------------------------------------------
must_exist(ROOT / "apps" / "openchat", "apps/openchat folder")

write(
    ROOT / "apps/openchat/services/thread-svc/Dockerfile",
    """
FROM python:3.11-slim
WORKDIR /app

COPY services/thread-svc/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/common /app/common
RUN pip install -e /app/common

COPY services/thread-svc/app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8080"]
""",
)

write(
    ROOT / "apps/openchat/services/post-svc/Dockerfile",
    """
FROM python:3.11-slim
WORKDIR /app

COPY services/post-svc/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/common /app/common
RUN pip install -e /app/common

COPY services/post-svc/app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8081
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8081"]
""",
)

write(
    ROOT / "apps/openchat/workers/moderation-consumer/Dockerfile",
    """
FROM python:3.11-slim
WORKDIR /app

COPY workers/moderation-consumer/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/common /app/common
RUN pip install -e /app/common

COPY workers/moderation-consumer/app /app/app

ENV PYTHONUNBUFFERED=1
CMD ["python", "-m", "app.main"]
""",
)

write(
    ROOT / "apps/openchat/tools/burst-publisher/Dockerfile",
    """
FROM python:3.11-slim
WORKDIR /app

COPY tools/burst-publisher/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY tools/burst-publisher/app /app/app
CMD ["python", "-m", "app.main"]
""",
)

# ------------------------------------------------------------------------------
# 2) Fix kustomize overlay dev (ConfigMap must be a resource)
# ------------------------------------------------------------------------------
dev_kustom = ROOT / "apps/openchat/k8s/overlays/dev/kustomization.yaml"
must_exist(dev_kustom, "apps/openchat/k8s/overlays/dev/kustomization.yaml")

write(
    dev_kustom,
    """
resources:
  - ../../base
  - configmap.yaml
""",
)

# ------------------------------------------------------------------------------
# 3) Fix Postgres StatefulSet volume mount (PVC name must match volumeMount)
# ------------------------------------------------------------------------------
postgres_yaml = ROOT / "apps/openchat/k8s/base/postgres.yaml"
must_exist(postgres_yaml, "apps/openchat/k8s/base/postgres.yaml")

# Preserve the init.sql content approach but fix the data volume mount properly.
# Overwrite with a known-good manifest.
write(
    postgres_yaml,
    """
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: openchat-dev
type: Opaque
stringData:
  POSTGRES_PASSWORD: openchat
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-initdb
  namespace: openchat-dev
data:
  init.sql: |
    CREATE TABLE IF NOT EXISTS country (
      code TEXT PRIMARY KEY,
      name TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS thread (
      id SERIAL PRIMARY KEY,
      topic TEXT NOT NULL,
      country_code TEXT NOT NULL REFERENCES country(code)
    );

    CREATE TABLE IF NOT EXISTS post (
      id SERIAL PRIMARY KEY,
      thread_id INT NOT NULL REFERENCES thread(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      country_code TEXT NOT NULL REFERENCES country(code),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_post_thread_id ON post(thread_id);

    CREATE TABLE IF NOT EXISTS processed_event (
      consumer_name TEXT NOT NULL,
      event_id UUID NOT NULL,
      processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (consumer_name, event_id)
    );

    CREATE TABLE IF NOT EXISTS moderation (
      post_id INT PRIMARY KEY REFERENCES post(id) ON DELETE CASCADE,
      decision TEXT NOT NULL,
      reason_code TEXT NOT NULL,
      confidence REAL NOT NULL DEFAULT 0,
      moderated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    INSERT INTO country(code, name) VALUES
      ('IE', 'Ireland'),
      ('GB', 'United Kingdom'),
      ('US', 'United States')
    ON CONFLICT (code) DO NOTHING;
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: openchat-dev
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: openchat-dev
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
              name: pg
          env:
            - name: POSTGRES_DB
              value: openchat
            - name: POSTGRES_USER
              value: openchat
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_PASSWORD
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
            - name: initdb
              mountPath: /docker-entrypoint-initdb.d
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: postgres-data
          persistentVolumeClaim:
            claimName: postgres-data
        - name: initdb
          configMap:
            name: postgres-initdb
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: openchat-dev
spec:
  selector:
    app: postgres
  ports:
    - name: pg
      port: 5432
      targetPort: 5432
""",
)

# ------------------------------------------------------------------------------
# 4) Add official RabbitMQ manifest (multi-arch) and patch Makefile target
# ------------------------------------------------------------------------------
write(
    ROOT / "platform/messaging/rabbitmq.yaml",
    """
apiVersion: v1
kind: Namespace
metadata:
  name: messaging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: rabbitmq-config
  namespace: messaging
data:
  enabled_plugins: |
    [rabbitmq_management,rabbitmq_prometheus].
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: messaging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
        - name: rabbitmq
          image: rabbitmq:4.1-management
          imagePullPolicy: IfNotPresent
          env:
            - name: RABBITMQ_DEFAULT_USER
              value: user
            - name: RABBITMQ_DEFAULT_PASS
              value: password
          ports:
            - name: amqp
              containerPort: 5672
            - name: mgmt
              containerPort: 15672
            - name: prom
              containerPort: 9419
          volumeMounts:
            - name: rabbitmq-config
              mountPath: /etc/rabbitmq/enabled_plugins
              subPath: enabled_plugins
          resources:
            requests:
              cpu: 50m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: rabbitmq-config
          configMap:
            name: rabbitmq-config
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: messaging
spec:
  selector:
    app: rabbitmq
  ports:
    - name: amqp
      port: 5672
      targetPort: 5672
    - name: mgmt
      port: 15672
      targetPort: 15672
    - name: prom
      port: 9419
      targetPort: 9419
""",
)

# ------------------------------------------------------------------------------
# 5) Patch Makefile: apps builds use context apps/openchat; platform-rabbitmq uses kubectl apply;
#    platform-openfaas creates namespaces before helm; add apps-force target if missing
# ------------------------------------------------------------------------------
makefile = ROOT / "Makefile"
must_exist(makefile, "Makefile")
mf = makefile.read_text(encoding="utf-8").splitlines()

header_re = re.compile(r"^[A-Za-z0-9_.-]+\s*:\s*$")

def find_block(name: str) -> tuple[int, int] | None:
    t = re.compile(rf"^{re.escape(name)}\s*:\s*$")
    start = None
    for idx, line in enumerate(mf):
        if t.match(line):
            start = idx
            break
    if start is None:
        return None
    end = start + 1
    while end < len(mf) and not header_re.match(mf[end]):
        end += 1
    return start, end

def replace_or_insert(name: str, new_block: list[str]) -> None:
    global mf
    blk = find_block(name)
    if blk:
        s, e = blk
        mf = mf[:s] + new_block + mf[e:]
    else:
        if mf and mf[-1].strip():
            mf.append("")
        mf += new_block

apps_block = [
    "apps:",
    "\tdocker build -t openchat/thread-svc:1.0.0 \\",
    "\t  -f apps/openchat/services/thread-svc/Dockerfile \\",
    "\t  apps/openchat",
    "\tdocker build -t openchat/post-svc:1.0.0 \\",
    "\t  -f apps/openchat/services/post-svc/Dockerfile \\",
    "\t  apps/openchat",
    "\tdocker build -t openchat/moderation-consumer:1.0.0 \\",
    "\t  -f apps/openchat/workers/moderation-consumer/Dockerfile \\",
    "\t  apps/openchat",
    "\tdocker build -t openchat/burst-publisher:1.0.0 \\",
    "\t  -f apps/openchat/tools/burst-publisher/Dockerfile \\",
    "\t  apps/openchat",
    "\tk3d image import -c ea-k3d \\",
    "\t  openchat/thread-svc:1.0.0 \\",
    "\t  openchat/post-svc:1.0.0 \\",
    "\t  openchat/moderation-consumer:1.0.0 \\",
    "\t  openchat/burst-publisher:1.0.0",
    "\tkubectl apply -k apps/openchat/k8s/overlays/dev",
    "",
]
replace_or_insert("apps", apps_block)

replace_or_insert(
    "apps-force",
    [
        "apps-force:",
        "\tmake -B apps",
        "",
    ],
)

replace_or_insert(
    "platform-rabbitmq",
    [
        "platform-rabbitmq:",
        "\tkubectl apply -f platform/messaging/rabbitmq.yaml",
        "",
    ],
)

# Ensure openfaas namespaces exist before helm install
openfaas_block = [
    "platform-openfaas:",
    "\tkubectl create namespace openfaas >/dev/null 2>&1 || true",
    "\tkubectl create namespace openfaas-fn >/dev/null 2>&1 || true",
    "\t./scripts/resolve_versions.sh",
    "\t@source versions.lock && \\",
    "\t./scripts/helm_install_component.sh openfaas openfaas openfaas \\",
    "\t  \"$$OPENFAAS_CHART\" \"$$OPENFAAS_VERSION\" platform/openfaas/values.yaml",
    "",
]
replace_or_insert("platform-openfaas", openfaas_block)

makefile.write_text("\n".join(mf) + "\n", encoding="utf-8")

# ------------------------------------------------------------------------------
# 6) Update Velero values to new schema baseline (removes removed configuration.provider)
# ------------------------------------------------------------------------------
velero_vals = ROOT / "platform/velero/values.yaml"
if velero_vals.exists():
    write(
        velero_vals,
        """
configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero
      config:
        region: minio
        s3ForcePathStyle: "true"
        s3Url: http://minio.velero:9000

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: minio

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=minio
      aws_secret_access_key=minio12345

resources:
  requests:
    cpu: 50m
    memory: 256Mi
  limits:
    cpu: 300m
    memory: 512Mi

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.11.0
    volumeMounts:
      - mountPath: /target
        name: plugins
""",
    )

print("Applied all core fixes.")
print("- Dockerfiles standardized to context apps/openchat")
print("- Makefile apps target builds with context apps/openchat and imports images to k3d")
print("- dev overlay kustomization fixed (ConfigMap is a resource)")
print("- Postgres StatefulSet PVC mount fixed")
print("- RabbitMQ now uses official multi-arch manifest (no Bitnami)")
print("- platform-openfaas creates namespaces before helm")
print("- Velero values updated to new schema baseline")
PY