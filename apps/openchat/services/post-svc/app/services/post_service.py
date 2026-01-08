import json
import uuid
from datetime import datetime, timezone

import asyncpg
from fastapi import HTTPException

from app.data_access.country_repo import country_exists
from app.data_access.post_repo import create_post, list_posts
from app.messaging.amqp import publish_json
from app.models.post import Post, PostCreate


async def list_all(conn) -> list[Post]:
    return await list_posts(conn)


async def create(conn, app, data: PostCreate) -> Post:
    if len(data.text.strip()) < 1:
        raise HTTPException(status_code=400, detail="Text required")

    ok = await country_exists(conn, data.country_code)
    if not ok:
        raise HTTPException(status_code=400, detail="Invalid country_code")

    try:
        post = await create_post(conn, data)
    except asyncpg.exceptions.ForeignKeyViolationError:
        raise HTTPException(status_code=400, detail="Invalid thread_id")

    # Publish event (teaching: do not fail request if publish fails)
    try:
        event_id = str(uuid.uuid4())
        payload = {
            "event_id": event_id,
            "event_type": "post.created",
            "occurred_at": datetime.now(timezone.utc).isoformat(),
            "post": {
                "id": post.id,
                "thread_id": post.thread_id,
                "country_code": post.country_code,
                "text": post.text,
            },
        }
        await publish_json(
            app=app,
            routing_key="post.created",
            payload=json.dumps(payload).encode("utf-8"),
            message_id=event_id,
        )
    except Exception:
        pass

    return post
