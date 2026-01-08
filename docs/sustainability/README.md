# Sustainability in these labs

Treat sustainability as an architecture driver, not a bolt-on.

Practical signals you can discuss/measure:
- Idle waste: replicas running with low request rate; oversized CPU/memory
- Autoscaling policy: scale-to-zero vs always-on; cooldown to prevent thrash
- Queue buffering: smoothing bursts can reduce peak capacity needs
- DR sizing: right-size DR to RTO/RPO rather than defaulting to expensive patterns
- Observability overhead: avoid high-cardinality metrics without purpose

Prompts to include in reports/ADRs:
- What is the minimum capacity needed to meet SLOs?
- What is the impact of adding components (brokers, serverless, policy engines)?
- Where do managed cloud services reduce lifecycle cost (ops) vs increase lock-in?
