import os
from typing import Any

import aio_pika


def messaging_enabled() -> bool:
    return os.getenv("ENABLE_MESSAGING", "false").lower() == "true"


def _amqp_url() -> str:
    return os.getenv("RABBITMQ_URL", "")


async def connect(app) -> None:
    if not messaging_enabled():
        app.state.amqp = None
        return

    url = _amqp_url()
    if not url:
        raise RuntimeError("ENABLE_MESSAGING=true but RABBITMQ_URL is not set")

    conn = await aio_pika.connect_robust(url)
    ch = await conn.channel()
    exchange = await ch.declare_exchange(
        "openchat.events",
        aio_pika.ExchangeType.TOPIC,
        durable=False,
    )
    app.state.amqp = {"conn": conn, "ch": ch, "exchange": exchange}


async def close(app) -> None:
    amqp: Any = getattr(app.state, "amqp", None)
    if not amqp:
        return
    await amqp["ch"].close()
    await amqp["conn"].close()


async def publish_json(app, routing_key: str, payload: bytes, message_id: str) -> None:
    amqp = getattr(app.state, "amqp", None)
    if not amqp:
        return

    msg = aio_pika.Message(
        body=payload,
        message_id=message_id,
        content_type="application/json",
        delivery_mode=aio_pika.DeliveryMode.NOT_PERSISTENT,
    )
    await amqp["exchange"].publish(msg, routing_key=routing_key)
