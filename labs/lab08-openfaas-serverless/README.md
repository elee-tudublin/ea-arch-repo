# Lab 8 — Serverless on Kubernetes with OpenFaaS (runnable)

## Introduction

In this lab you will:
1. Install OpenFaaS on the cluster.
2. Deploy a moderation function.
3. Switch moderation-consumer to call the function.
4. Compare serverless vs always-on worker trade-offs.

## Getting started

    make apps
    make platform-rabbitmq
    make messaging

## Part 1 — Install OpenFaaS

    make platform-openfaas
    kubectl get pods -n openfaas
    kubectl get svc -n openfaas

Optional port-forward:

    kubectl -n openfaas port-forward svc/gateway 8082:8080


Note on this lab’s OpenFaaS usage:
- The OpenFaaS gateway is installed with basic auth enabled.
- For simplicity, this lab deploys the moderation function as a plain Kubernetes Deployment in the openfaas-fn namespace.
- The consumer calls the function via the in-cluster service name (gateway.openfaas).
- This demonstrates serverless-style packaging and invocation, but it is not the full faas-cli deployment workflow.

## Part 2 — Copy the function into your repo and deploy it

This lab folder includes a function implementation under:
    labs/lab08-openfaas-serverless/function/

Copy it into your repo (once):
    mkdir -p apps/openchat/functions
    cp -r labs/lab08-openfaas-serverless/function apps/openchat/functions/moderation-fn

Build and import image:

    docker build -t openchat/moderation-fn:1.0.0 apps/openchat/functions/moderation-fn
    k3d image import -c ea-k3d openchat/moderation-fn:1.0.0

Deploy function as a simple Kubernetes deployment (teaching simplification):

    kubectl -n openfaas-fn create deploy moderation-fn \
      --image=openchat/moderation-fn:1.0.0 \
      --port=8080 \
      --env BANNED_WORDS="spam,hate,illegal"

Verify:

    kubectl get pods -n openfaas-fn

## Part 3 — Switch moderation-consumer to call OpenFaaS

This lab folder includes a Kustomize overlay under:
    labs/lab08-openfaas-serverless/kustomize-overlay/

Copy it into the repo (once):
    mkdir -p apps/openchat/k8s/overlays
    cp -r labs/lab08-openfaas-serverless/kustomize-overlay \
      apps/openchat/k8s/overlays/dev-openfaas-moderation

Apply overlay:

    kubectl apply -k apps/openchat/k8s/overlays/dev-openfaas-moderation

## Part 4 — Test moderation results

    kubectl -n openchat-dev port-forward svc/post-svc 8081:80 &
    sleep 1

Create a post that should be blocked:

    curl -s -X POST http://localhost:8081/posts \
      -H "content-type: application/json" \
      -d '{"thread_id":1,"text":"this looks like spam","country_code":"IE"}'

Verify in DB:

    kubectl -n openchat-dev exec -it sts/postgres -- \
      psql -U openchat -d openchat -c "select * from moderation order by moderated_at desc limit 10;"

## Exercises

1) Compare operability trade-offs: function calls vs local moderation.
2) Describe cold start risk and where it matters.
3) Ethics prompt: keyword moderation is simplistic; list two harms and one mitigation.

