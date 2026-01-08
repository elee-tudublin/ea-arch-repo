# Lab 7 — Event-based scaling with KEDA (continuity under demand)

## Introduction

In this lab you will:
1. Install KEDA.
2. Configure scaling of moderation-consumer based on queue length.
3. Generate load and observe scaling behaviour.

## Getting started

    make platform-rabbitmq
    make apps
    make messaging

## Part 1 — Install KEDA

    make platform-keda
    kubectl get pods -n keda

## Part 2 — Apply scaling configuration and observe

    make scaling
    kubectl -n openchat-dev get deploy moderation-consumer -w

Inspect KEDA objects:

    kubectl -n openchat-dev get scaledobject
    kubectl -n openchat-dev describe scaledobject moderation-consumer-scale

## Exercises

1) Identify the scaling trigger, threshold, cooldown, and min/max replicas.
2) Sustainability prompt: explain scale-to-zero benefits and one risk (cold start / backlog).

## Extensions (optional) — Tuning and guardrails

1) Tune scaling to avoid thrash:
- Increase cooldownPeriod to reduce oscillation.
- Add a maxReplicaCount that protects downstream dependencies.

2) Evidence:
- Capture before/after graphs in Grafana (queue depth proxies, request latency).

3) Sustainability:
- Explain how tuning reduces wasted compute and reduces failure cascades.

