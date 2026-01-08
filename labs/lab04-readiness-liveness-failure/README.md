# Lab 4 — Reliability and readiness: probes and failure behaviour

## Introduction

In this lab you will:
1. Review readiness vs liveness probes in the service deployments.
2. Simulate a dependency failure (database unavailable) and observe readiness.
3. Relate behaviour to SRE concepts (operability and safe failure).

## Getting started

Make sure services and DB are running:

    make apps
    kubectl get pods -n openchat-dev

## Part 1 — Inspect probes

Inspect these files (read-only):
- apps/openchat/k8s/base/thread-svc.yaml
- apps/openchat/k8s/base/post-svc.yaml

Confirm probe endpoints:
- /health (liveness)
- /ready (readiness; checks DB connectivity)

## Part 2 — Simulate failure and observe readiness changes

1) Watch pods:

    kubectl get pods -n openchat-dev -w

2) In another terminal, scale Postgres to zero:

    kubectl -n openchat-dev scale statefulset/postgres --replicas=0

3) Restore DB:

    kubectl -n openchat-dev scale statefulset/postgres --replicas=1

## Exercises

1) Explain readiness vs liveness in terms of user impact.
2) Sustainability prompt: what is the cost of restarting services unnecessarily, and how do probes reduce wasted work?

