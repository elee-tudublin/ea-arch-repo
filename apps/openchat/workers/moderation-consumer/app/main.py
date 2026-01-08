import json
import os
import time
import uuid

import aio_pika
import asyncpg
import httpx
from opentelemetry import metrics

from openchat_common.logging import setup_logging
from openchat_common.telemetry import setup_worker_otel

CONSUMER_NAME = "moderation-consumer"


def _db_dsn() -> str:
    return os.getenv(
        "DATABASE_URL",
        "postgresql://openchat:openchat@postgres.openchat-dev:5432/openchat",
    )


def _amqp_url() -> str:
    return os.getenv("RABBITMQ_URL", "amqp://user:password@rabbitmq.messaging:5672/")


def _mode() -> str:
    return os.getenv("MODERATION_MODE", "local").lower()


def _openfaas_url() -> str:
    return os.getenv(
        "OPENFAAS_MODERATION_URL",
        "http://gateway.openfaas:8080/function/moderation-fn",
    )


def moderate_locally(text: str) -> tuple[str, str, float]:
    lowered = text.lower()
    banned = ["spam", "hate", "illegal"]
    for w in banned:
        if w in lowered:
            return ("block", "keyword_match", 0.9)
    return ("allow", "clean", 0.6)


async def moderate_openfaas(text: str) -> tuple[str, str, float]:
    async with httpx.AsyncClient(timeout=3.0) as client:
        resp = await client.post(_openfaas_url(), json={"text": text})
        resp.raise_for_status()
        data = resp.json()
        return (
            data.get("decision", "allow"),
            data.get("reason_code", "unknown"),
            float(data.get("confidence", 0.5)),
        )


async def ensure_topology(ch: aio_pika.Channel) -> None:
    exchange = await ch.declare_exchange(
        "openchat.events",
        aio_pika.ExchangeType.TOPIC,
        durable=False,
    )
    queue = await ch.declare_queue("moderation_queue", durable=False)
    await queue.bind(exchange, routing_key="post.created")


async def handle_message(db: asyncpg.Pool, message: aio_pika.IncomingMessage, c, h):
    start = time.perf_counter()

    async with message.process(requeue=True):
        payload = json.loads(message.body.decode("utf-8"))
        event_id = payload.get("event_id") or message.message_id
        if not event_id:
            raise RuntimeError("Missing event_id/message_id")

        event_uuid = uuid.UUID(str(event_id))
        post = payload["post"]
        post_id = int(post["id"])
        text = str(post.get("text", ""))

        async with db.acquire() as conn:
            async with conn.transaction():
                inserted = await conn.fetchrow(
                    """
                    INSERT INTO processed_event(consumer_name, event_id)
                    VALUES($1, $2)
                    ON CONFLICT DO NOTHING
                    RETURNING consumer_name, event_id
                    """,
                    CONSUMER_NAME,
                    event_uuid,
                )
                if inserted is None:
                    return

                if _mode() == "openfaas":
                    decision, reason_code, conf = await moderate_openfaas(text)
                else:
                    decision, reason_code, conf = moderate_locally(text)

                await conn.execute(
                    """
                    INSERT INTO moderation(post_id, decision, reason_code, confidence)
                    VALUES($1, $2, $3, $4)
                    ON CONFLICT (post_id) DO UPDATE SET
                      decision=EXCLUDED.decision,
                      reason_code=EXCLUDED.reason_code,
                      confidence=EXCLUDED.confidence,
                      moderated_at=NOW()
                    """,
                    post_id,
                    decision,
                    reason_code,
                    conf,
                )

    dur_ms = (time.perf_counter() - start) * 1000.0
    c.add(1, {"consumer": CONSUMER_NAME})
    h.record(dur_ms, {"consumer": CONSUMER_NAME})


async def main() -> None:
    setup_logging()
    setup_worker_otel(service_name=CONSUMER_NAME)

    meter = metrics.get_meter(CONSUMER_NAME)
    msg_counter = meter.create_counter(
        name="moderation_messages_total",
        description="Moderation messages processed",
    )
    msg_latency = meter.create_histogram(
        name="moderation_process_duration_ms",
        unit="ms",
        description="Moderation processing duration",
    )

    db = await asyncpg.create_pool(dsn=_db_dsn(), min_size=1, max_size=5)

    conn = await aio_pika.connect_robust(_amqp_url())
    ch = await conn.channel()
    await ch.set_qos(prefetch_count=10)

    await ensure_topology(ch)
    queue = await ch.declare_queue("moderation_queue", durable=False)

    async with queue.iterator() as q:
        async for msg in q:
            try:
                await handle_message(db, msg, msg_counter, msg_latency)
            except Exception:
                continue


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
