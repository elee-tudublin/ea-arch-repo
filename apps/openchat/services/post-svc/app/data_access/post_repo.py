import asyncpg

from app.models.post import Post, PostCreate


async def list_posts(conn: asyncpg.Connection) -> list[Post]:
    rows = await conn.fetch(
        "SELECT id, thread_id, text, country_code, created_at FROM post ORDER BY id"
    )
    return [Post(**dict(r)) for r in rows]


async def create_post(conn: asyncpg.Connection, data: PostCreate) -> Post:
    row = await conn.fetchrow(
        "INSERT INTO post(thread_id, text, country_code) VALUES($1, $2, $3) "
        "RETURNING id, thread_id, text, country_code, created_at",
        data.thread_id,
        data.text,
        data.country_code,
    )
    return Post(**dict(row))
