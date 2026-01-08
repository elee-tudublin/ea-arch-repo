# Lab 1 — Course setup, containers, and first Kubernetes deployment

## Introduction

In this lab you will:
1. Clone the course repository and verify tooling inside the Ubuntu VM.
2. Create a local Kubernetes cluster using k3d.
3. Deploy the first service to Kubernetes and verify it is reachable.

## Getting started

Open a terminal in your Ubuntu VM.

1) Clone the repository:

    git clone <REPO_URL> ea-arch-module
    cd ea-arch-module

2) Confirm required tools are available:

    docker --version
    k3d version
    kubectl version --client=true
    helm version
    make --version
    python3 --version

If any command is missing, report it to the lecturer/lab tutor (the VM image is incomplete).

## Part 1 — Create the local Kubernetes cluster

1) Create the cluster:

    make cluster

2) Inspect cluster state:

    kubectl get nodes
    kubectl get pods -A

## Part 2 — Build and deploy the application services

1) Build images and deploy the base application stack:

    make apps

2) Check pods and services:

    kubectl get pods -n openchat-dev
    kubectl get svc -n openchat-dev

3) Port-forward the thread service:

    kubectl -n openchat-dev port-forward svc/thread-svc 8080:80

4) In a second terminal, test:

    curl -s http://localhost:8080/health
    curl -s http://localhost:8080/ready

## Exercises

1) Create a thread:

    curl -s -X POST http://localhost:8080/threads \
      -H "content-type: application/json" \
      -d '{"topic":"Enterprise Architecture","country_code":"IE"}'

2) List threads:

    curl -s http://localhost:8080/threads

3) Reflection (5–8 lines):
- Why use containers + Kubernetes even for local labs?
- Why keep code, manifests, and scripts in one repo?

