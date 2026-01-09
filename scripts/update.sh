#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path.cwd()

def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip() + "\n", encoding="utf-8")

# ---------------------------------------------------------------------
# 1) Add RabbitMQ manifest (official image, multi-arch)
# ---------------------------------------------------------------------
rabbitmq_yaml = ROOT / "platform" / "messaging" / "rabbitmq.yaml"
write(
    rabbitmq_yaml,
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

# ---------------------------------------------------------------------
# 2) Patch Makefile: replace platform-rabbitmq target; add apps-force
# ---------------------------------------------------------------------
makefile = ROOT / "Makefile"
if not makefile.exists():
    raise SystemExit("Makefile not found")

lines = makefile.read_text(encoding="utf-8").splitlines()

def find_target_block(name: str) -> tuple[int, int] | None:
    # returns (start_index, end_index_exclusive) for the target block
    target_re = re.compile(rf"^{re.escape(name)}\s*:\s*$")
    header_re = re.compile(r"^[A-Za-z0-9_.-]+\s*:\s*$")

    start = None
    for idx, line in enumerate(lines):
        if target_re.match(line):
            start = idx
            break
    if start is None:
        return None

    end = start + 1
    while end < len(lines) and not header_re.match(lines[end]):
        end += 1
    return (start, end)

def replace_or_insert_target(name: str, block: list[str]) -> None:
    global lines
    found = find_target_block(name)
    if found:
        s, e = found
        lines = lines[:s] + block + lines[e:]
    else:
        # append at end with a blank line separation
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.extend(block)

platform_rabbitmq_block = [
    "platform-rabbitmq:",
    "\tkubectl apply -f platform/messaging/rabbitmq.yaml",
    "",
]

replace_or_insert_target("platform-rabbitmq", platform_rabbitmq_block)

# add apps-force if missing
if find_target_block("apps-force") is None:
    apps_force_block = [
        "apps-force:",
        "\tmake -B apps",
        "",
    ]
    replace_or_insert_target("apps-force", apps_force_block)

makefile.write_text("\n".join(lines) + "\n", encoding="utf-8")

# ---------------------------------------------------------------------
# 3) Replace platform/velero/values.yaml with safe baseline (new schema)
# ---------------------------------------------------------------------
velero_vals = ROOT / "platform" / "velero" / "values.yaml"
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

# Some charts/hooks use a kubectl image. Avoid broken or unavailable tags.
# If your chart ignores this key, you must pin a chart version that works.
kubectl:
  image:
    repository: registry.k8s.io/kubectl
    tag: v1.34.2

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

print("Applied definitive fixes:")
print("- platform/messaging/rabbitmq.yaml (official RabbitMQ image)")
print("- Makefile: platform-rabbitmq now uses kubectl apply (no Bitnami Helm chart)")
print("- Makefile: added apps-force target (make -B apps)")
print("- platform/velero/values.yaml updated to new schema baseline + kubectl override")
PY