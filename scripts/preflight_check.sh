#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FAIL=0

echo "== Preflight: repo root = $ROOT =="

say_ok() { printf "OK: %s\n" "$1"; }
say_warn() { printf "WARN: %s\n" "$1"; }
say_fail() { printf "FAIL: %s\n" "$1"; FAIL=1; }

# ----------------------------
# 1) Detect dangerous COPY/ADD
# ----------------------------
echo
echo "== Check 1: Dockerfile COPY/ADD path safety =="

mapfile -t DOCKERFILES < <(find apps -name Dockerfile -type f | sort)
if [[ "${#DOCKERFILES[@]}" -eq 0 ]]; then
  say_fail "No Dockerfiles found under apps/"
else
  say_ok "Found ${#DOCKERFILES[@]} Dockerfiles"
fi

# Heuristic: flag any COPY/ADD that starts with ../ or ../../ etc.
for df in "${DOCKERFILES[@]}"; do
  if grep -nE '^(ADD|COPY)\s+\.\./' "$df" >/dev/null 2>&1; then
    say_fail "$df contains COPY/ADD with ../ (will break unless build context is widened)"
    grep -nE '^(ADD|COPY)\s+\.\./' "$df" || true
  fi
done

# ----------------------------
# 2) Ensure Makefile builds use consistent context
# ----------------------------
echo
echo "== Check 2: Makefile docker build contexts =="

if [[ ! -f Makefile ]]; then
  say_fail "Makefile not found"
else
  say_ok "Makefile found"
fi

# Extract docker build lines
mapfile -t DOCKER_BUILD_LINES < <(grep -nE '^\s*docker build ' Makefile || true)
if [[ "${#DOCKER_BUILD_LINES[@]}" -eq 0 ]]; then
  say_warn "No 'docker build' lines found in Makefile (maybe using another build system)"
else
  say_ok "Found ${#DOCKER_BUILD_LINES[@]} docker build lines in Makefile"
fi

# Recommend one invariant build context for OpenChat: apps/openchat
# Flag any build context that is a service subdir (common source of COPY failures)
for line in "${DOCKER_BUILD_LINES[@]}"; do
  # last token is usually the context (may be line-continued; this is best-effort)
  if echo "$line" | grep -qE 'apps/openchat/services/(thread-svc|post-svc)\s*$'; then
    say_fail "Makefile builds with a narrow context (service folder) -> likely COPY failures: $line"
  fi
  if echo "$line" | grep -qE 'apps/openchat/workers/(moderation-consumer)\s*$'; then
    say_fail "Makefile builds with a narrow context (worker folder) -> likely COPY failures: $line"
  fi
done

# ----------------------------
# 3) Validate expected shared common path exists
# ----------------------------
echo
echo "== Check 3: Shared common package exists =="

if [[ -d apps/openchat/services/common ]]; then
  say_ok "apps/openchat/services/common exists"
else
  say_fail "apps/openchat/services/common missing (shared code expected by Dockerfiles)"
fi

# ----------------------------
# 4) K8s manifests: local image pull policy
# ----------------------------
echo
echo "== Check 4: imagePullPolicy for local images =="

# Look for openchat/* images and ensure imagePullPolicy IfNotPresent is present in same manifest file
mapfile -t OPENCHAT_IMAGE_FILES < <(grep -RIl 'image:\s*openchat/' apps/openchat/k8s | sort || true)
for f in "${OPENCHAT_IMAGE_FILES[@]}"; do
  if ! grep -q 'imagePullPolicy:\s*IfNotPresent' "$f"; then
    say_warn "$f uses openchat/* image but does not set imagePullPolicy: IfNotPresent"
  fi
done
if [[ "${#OPENCHAT_IMAGE_FILES[@]}" -gt 0 ]]; then
  say_ok "Scanned ${#OPENCHAT_IMAGE_FILES[@]} K8s files referencing openchat/* images"
fi

# ----------------------------
# 5) Helm repo brittleness checks (baltocdn)
# ----------------------------
echo
echo "== Check 5: helm/baltocdn references =="

if grep -RIn 'baltocdn\.com' . >/dev/null 2>&1; then
  say_fail "Found baltocdn.com reference(s) in repo (Helm apt repo is unreliable). Remove/replace."
  grep -RIn 'baltocdn\.com' . || true
else
  say_ok "No baltocdn.com references found"
fi

# ----------------------------
# 6) Optional cluster check (only if cluster exists)
# ----------------------------
echo
echo "== Check 6 (optional): cluster image pull failures =="

if command -v kubectl >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1; then
  say_ok "Kubernetes reachable"

  if kubectl get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' >/dev/null 2>&1; then
    say_warn "Some pods are failing image pulls:"
    kubectl get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || true
  else
    say_ok "No ImagePullBackOff/ErrImagePull detected"
  fi
else
  say_warn "kubectl not connected to a cluster (skipping cluster checks)"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "Preflight result: OK (no hard failures detected)"
else
  echo "Preflight result: FAIL (fix items above before rebuilding)"
fi

exit "$FAIL"