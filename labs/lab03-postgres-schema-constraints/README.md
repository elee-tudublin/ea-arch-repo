# Lab 3 — PostgreSQL inspection: schema, constraints, and query behaviour

## Introduction

In this lab you will:
1. Inspect the OpenChat database schema (country/thread/post).
2. Demonstrate referential integrity and constraints.
3. Connect system behaviour to architectural concerns (data ownership and coupling).

## Getting started

Ensure apps are deployed:

    make apps

## Part 1 — Inspect schema

1) Open a shell into PostgreSQL:

    kubectl -n openchat-dev exec -it sts/postgres -- psql -U openchat -d openchat

2) In psql, inspect tables:

    \dt
    \d country
    \d thread
    \d post

3) Inspect foreign keys:

    SELECT
      tc.table_name,
      kcu.column_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY';

4) Exit:

    \q

## Exercises

1) Explain why post.thread_id is a coupling point between components.
2) Describe one microservice migration strategy that reduces this coupling.
3) Ethics prompt: identify one data minimization improvement for an anonymous system.

