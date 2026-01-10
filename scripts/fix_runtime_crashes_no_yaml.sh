#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== 1) Fix telemetry.py (was truncated and causing SyntaxError) =="

cat > apps/openchat/services/common/openchat_common/telemetry.py <<'PY'
import os

from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def _endpoint() -> str:
    return os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://otel-collector.observability:4318",
    )


def _resource(service_name: str) -> Resource:
    return Resource.create(
        {
            "service.name": service_name,
            "service.version": os.getenv("SERVICE_VERSION", "1.0.0"),
            "deployment.environment": os.getenv("ENV", "dev"),
        }
    )


def _configure_tracing(service_name: str) -> None:
    endpoint = _endpoint()
    resource = _resource(service_name)

    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint))
    )
    trace.set_tracer_provider(tracer_provider)


def _configure_metrics(service_name: str) -> None:
    endpoint = _endpoint()
    resource = _resource(service_name)

    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=endpoint),
        export_interval_millis=5000,
    )
    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)


def setup_otel(app, service_name: str) -> None:
    _configure_tracing(service_name)
    _configure_metrics(service_name)
    FastAPIInstrumentor.instrument_app(app)


def setup_worker_otel(service_name: str) -> None:
    _configure_tracing(service_name)
    _configure_metrics(service_name)
PY

echo "== 2) Fix OTel Collector config (logging exporter deprecated -> debug exporter) =="

OTEL_FILE="apps/openchat/k8s/base/otel-collector.yaml"

# Replace exporter block name "logging" -> "debug"
# and pipeline exporter reference [logging] -> [debug]
# (best-effort, safe to run multiple times)
perl -0777 -i -pe 's/\n(\s*)logging:\n/\n$1debug:\n/g; s/exporters:\s*\[logging\]/exporters: [debug]/g' "$OTEL_FILE" || true

echo "== 3) Add explicit non-privileged securityContext to OpenChat workloads =="

add_security_context() {
  local file="$1"
  # Only add if there is no securityContext already in the first container.
  if grep -q "securityContext:" "$file"; then
    return 0
  fi

  # Insert under the first container entry after "imagePullPolicy" if present,
  # otherwise after "image:" line.
  # This is a targeted YAML insertion for this course repo structure.
  perl -i -pe '
    if (!$done && /^\s*imagePullPolicy:\s*\S+/) {
      print "          securityContext:\n";
      print "            privileged: false\n";
      print "            allowPrivilegeEscalation: false\n";
      print "            runAsNonRoot: true\n";
      print "            capabilities:\n";
      print "              drop: [\"ALL\"]\n";
      $done=1;
    }
  ' "$file"

  if ! grep -q "securityContext:" "$file"; then
    perl -i -pe '
      if (!$done && /^\s*image:\s*\S+/) {
        print "          securityContext:\n";
        print "            privileged: false\n";
        print "            allowPrivilegeEscalation: false\n";
        print "            runAsNonRoot: true\n";
        print "            capabilities:\n";
        print "              drop: [\"ALL\"]\n";
        $done=1;
      }
    ' "$file"
  fi
}

add_security_context "apps/openchat/k8s/base/thread-svc.yaml"
add_security_context "apps/openchat/k8s/base/post-svc.yaml"
add_security_context "apps/openchat/k8s/overlays/dev-messaging/moderation-consumer.yaml"
add_security_context "apps/openchat/k8s/overlays/dev-messaging-scaling/burst-job.yaml"

echo "== 4) Rebuild images and redeploy =="

# Always rebuild (avoids 'up to date' when images are missing)
make apps-force

echo "== 5) Restart relevant deployments =="

kubectl -n observability rollout restart deploy/otel-collector >/dev/null 2>&1 || true
kubectl -n openchat-dev rollout restart deploy/thread-svc >/dev/null 2>&1 || true
kubectl -n openchat-dev rollout restart deploy/post-svc >/dev/null 2>&1 || true
kubectl -n openchat-dev rollout restart deploy/moderation-consumer >/dev/null 2>&1 || true

echo "== 6) Clean up old burst jobs (optional) =="
kubectl -n openchat-dev delete job burst-publisher --ignore-not-found=true >/dev/null 2>&1 || true

echo "== Done. Next checks =="
echo "  kubectl -n observability get pods"
echo "  kubectl -n openchat-dev get pods"
