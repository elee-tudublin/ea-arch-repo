# Lab 6 — Delivery semantics and idempotency (at-least-once reality)

## Introduction

In this lab you will:
1. Observe at-least-once delivery behaviour.
2. Confirm idempotency using the processed_event table.
3. Relate this to “exactly once” semantics in real systems.

## Getting started

    make platform-rabbitmq
    make apps
    make messaging

## Part 1 — Inspect idempotency store

    kubectl -n openchat-dev exec -it sts/postgres -- \
      psql -U openchat -d openchat -c "select consumer_name, count(*) from processed_event group by consumer_name;"

## Part 2 — Create load and restart the consumer

1) Tail consumer logs:

    kubectl -n openchat-dev logs deploy/moderation-consumer -f

2) Generate posts quickly (run in another terminal):

    for i in $(seq 1 50); do
      curl -s -X POST http://localhost:8081/posts \
        -H "content-type: application/json" \
        -d "{\"thread_id\":1,\"text\":\"msg $i\",\"country_code\":\"IE\"}" >/dev/null
    done

3) Restart consumer:

    kubectl -n openchat-dev rollout restart deploy/moderation-consumer

## Exercises

1) Provide two message designs (field lists): a non-idempotent message and an idempotent version.
2) Explain how idempotency is affected by the chosen fields.
3) Explain why idempotency is required even when systems claim strong delivery guarantees.

