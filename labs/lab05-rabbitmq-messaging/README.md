# Lab 5 — Asynchronous middleware (RabbitMQ): decoupling and event publishing

## Introduction

In this lab you will:
1. Install RabbitMQ into your cluster.
2. Enable event publishing in post-svc.
3. Deploy an asynchronous consumer (moderation-consumer) that processes messages.

## Getting started

From repo root:

    cd ea-arch-module

## Part 1 — Install RabbitMQ

    make platform-rabbitmq
    kubectl get pods -n messaging
    kubectl get svc -n messaging

Optional: open RabbitMQ management UI:

    kubectl -n messaging port-forward svc/rabbitmq 15672:15672

Login: user / password

## Part 2 — Enable publishing and deploy the consumer

    make apps
    make messaging
    kubectl get pods -n openchat-dev

## Part 3 — Produce messages and verify moderation writes

    kubectl -n openchat-dev port-forward svc/thread-svc 8080:80 &
    kubectl -n openchat-dev port-forward svc/post-svc 8081:80 &
    sleep 1

Create a thread:

    curl -s -X POST http://localhost:8080/threads \
      -H "content-type: application/json" \
      -d '{"topic":"Messaging","country_code":"IE"}'

Create a post:

    curl -s -X POST http://localhost:8081/posts \
      -H "content-type: application/json" \
      -d '{"thread_id":1,"text":"hello from async","country_code":"IE"}'

Verify moderation results were written:

    kubectl -n openchat-dev exec -it sts/postgres -- \
      psql -U openchat -d openchat -c "select * from moderation order by moderated_at desc limit 5;"

## Exercises

1) Explain how messaging decreases coupling and increases stability in this system.
2) Identify two failure modes messaging helps with (give concrete examples).
3) Ethics prompt: discuss privacy implications of publishing post text in events; propose a safer alternative.

