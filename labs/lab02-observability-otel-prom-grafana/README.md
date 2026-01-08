# Lab 2 — Observability baseline: OpenTelemetry → Prometheus → Grafana

## Introduction

In this lab you will:
1. Deploy the OpenTelemetry Collector (OTLP receiver, Prometheus exporter).
2. Install Prometheus and Grafana.
3. Confirm that application metrics are being exported and visible.

## Getting started

From the repo root:

    cd ea-arch-module

If you were given a cache bundle (dist/cache):

    ./scripts/load_cache.sh
    ./scripts/k3d_import_cached_images.sh

## Part 1 — Install observability

1) Lock chart versions:

    ./scripts/resolve_versions.sh

2) Install the observability stack:

    make obs

3) Confirm components:

    kubectl get pods -n observability
    kubectl get svc -n observability

## Part 2 — Generate traffic and view metrics

1) Deploy apps:

    make apps

2) Generate traffic:

    kubectl -n openchat-dev port-forward svc/thread-svc 8080:80 &
    sleep 1
    curl -s http://localhost:8080/health
    curl -s http://localhost:8080/threads

3) Open Grafana:

    kubectl -n observability port-forward svc/grafana 3000:80

Navigate to http://localhost:3000
Login: admin / admin

In Grafana Explore, query:
- http_server_requests_total
- http_server_request_duration_ms

## Exercises

1) Identify at least two labels/dimensions on http_server_requests_total and explain them.
2) Propose one SLI and one SLO for “Create Thread”.
3) Sustainability prompt: what would “wasted capacity” look like in metrics?

## Extensions (optional) — GitOps with Argo CD

This extension introduces GitOps as an operating model (auditability, repeatability).
If your repo includes an Argo CD install target, follow your instructor’s guidance. Typical steps:

    make platform-argocd
    kubectl -n argocd port-forward svc/argocd-server 8084:80
    # Open http://localhost:8084 and create an Application pointing at your kustomize overlay

Discussion prompt: What audit evidence does GitOps provide compared with imperative kubectl apply?

