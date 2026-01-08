# Lab 12 — Consolidation lab: architecture evidence pack (exam preparation)

## Introduction

In this lab you will produce a structured evidence pack supporting exam-style answers and your applied assessment.

## Getting started

Minimum:

    make cluster
    make obs
    make apps

Optional (if covered):

    make platform-rabbitmq && make messaging
    make platform-keda && make scaling
    make platform-kyverno

## Part 1 — Evidence pack

Create a folder called ArchitectureEvidence/ and include:
- Grafana screenshots/exports showing request rate and latency
- kubectl outputs (pods/services)
- DB queries:
  - select count(*) from processed_event;
  - select * from moderation order by moderated_at desc limit 10;
- (If Kyverno) policy YAML and one blocked deployment/pod error

## Part 2 — Exam-style prompts (short answers)

Answer in your notes:
1) How does the queue decrease coupling and increase stability here?
2) Where is idempotency implemented and why?
3) Which CAP trade-off would you choose for listing posts vs creating posts?
4) Two security risks and mitigations (controls + evidence).

## Extensions (optional) — Service mesh (Linkerd) evidence

If your instructor has Linkerd installed for the module, add evidence that you can explain:
- mTLS enabled between thread-svc and post-svc (how you verified it)
- one traffic policy or resilience behaviour you configured (retries/timeouts/canary)
- which SLOs the mesh helps (and where it does not)

Conceptual mapping to public cloud:
- self-managed Linkerd on EKS/AKS/GKE vs managed service mesh offerings
- why governance and skills often dominate the decision

## Extensions (optional) — Blockchain practical benefit narrative

Write a short evaluation (200–300 words) answering:
- What benefit does blockchain provide that a signed append-only log does not (if any) for your chosen scenario?
- What are the constraints (privacy, throughput, key custody, operational risk)?
- Sustainability: what consensus/operating choices affect footprint most?

If you ran a local chain demo in class, include:
- a screenshot or output showing a notarization transaction
- how verification works (what is hashed, what is stored)

