cat > scripts/student_bootstrap.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "== Creating cluster =="
make cluster

echo "== (Optional) importing cache into k3d if present =="
if [[ -f dist/cache/images.txt ]]; then
  ./scripts/load_cache.sh || true
  ./scripts/k3d_import_cached_images.sh || true
fi

echo "== Resolving chart versions =="
./scripts/resolve_versions.sh

echo "== Installing observability =="
make obs

echo "== Building and deploying apps (force) =="
make apps-force

echo "== Installing RabbitMQ (manifest) =="
make platform-rabbitmq

echo "== Enabling messaging overlay =="
make messaging

echo "== Installing KEDA and scaling overlay =="
make platform-keda
make scaling

echo
echo "Bootstrap complete. Run:"
echo "  make status"
EOF

chmod +x scripts/student_bootstrap.sh