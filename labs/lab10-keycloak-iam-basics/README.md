# Lab 10 — IAM fundamentals with Keycloak (teaching environment)

## Introduction

In this lab you will deploy Keycloak and configure a basic realm/client.

## Getting started

    make platform-keycloak
    kubectl get pods -n identity

Port-forward:

    kubectl -n identity port-forward svc/keycloak 8083:80

Open http://localhost:8083 and login admin/admin.

## Part 1 — Configure Keycloak

In the UI:
1) Create realm: openchat
2) Create client: openchat-gateway
3) Note redirect URLs and token settings required for OIDC

## Exercises

1) Explain user identity vs workload identity.
2) Ethics prompt: identify two privacy risks from IAM misconfiguration.

## Extensions (optional) — Public cloud comparison

In your notes, map the lab concepts to cloud services (no implementation required):
- OIDC IdP: Keycloak vs (AWS Cognito / Azure Entra ID / Google Identity).
- Workload identity: Kubernetes service accounts vs cloud IAM roles/identities.
- Secrets and keys: Vault/K8s Secrets vs cloud KMS/Secrets services.

