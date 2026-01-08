# Lab 9 — Policy-as-code with Kyverno (secure defaults)

## Introduction

In this lab you will install Kyverno and observe policy enforcement.

## Getting started

    make platform-kyverno
    kubectl get pods -n kyverno

## Part 1 — Observe enforcement

Try creating a pod without limits:

    kubectl -n openchat-dev run no-limits --image=nginx:alpine

Cleanup:

    kubectl -n openchat-dev delete pod no-limits --ignore-not-found=true

## Exercises

1) Explain how policy-as-code supports audit readiness.
2) Sustainability prompt: how do requests/limits reduce waste and improve stability?

## Extensions (optional) — Audit evidence pack

Create a folder called AuditEvidence/ and capture:
- The Kyverno policy YAML you applied (from your repo).
- A screenshot or copied error message from a blocked pod attempt.
- A short paragraph explaining which control objective the policy supports (least privilege / safe configuration).

