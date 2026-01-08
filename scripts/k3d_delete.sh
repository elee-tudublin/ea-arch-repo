#!/usr/bin/env bash
set -euo pipefail

k3d cluster delete ea-k3d || true
