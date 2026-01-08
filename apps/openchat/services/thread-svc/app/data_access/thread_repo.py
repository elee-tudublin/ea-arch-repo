import asyncpg

from app.models.thread import Thread, ThreadCreate


async def list_threads(conn: asyncpg.Connection) -> list[Thread]:
    rows = await conn.fetch("SELECT id, topic, country_code FROM thread ORDER BY id")
    return [Thread(**dict(r)) for r in rows]


async def get_thread(conn: asyncpg.Connection, thread_id: int) -> Thread | None:
    row = await conn.fetchrow(
        "SELECT id, topic, country_code FROM thread WHERE id=$1",
        thread_id,
    )
    return Thread(**dict(row)) if row else None


async def create_thread(conn: asyncpg.Connection, data: ThreadCreate) -> Thread:
    row = await conn.fetchrow(
        "INSERT INTO thread(topic, country_code) VALUES($1, $2) "
        "RETURNING id, topic, country_code",
        data.topic,
        data.country_code,
    )
    return Thread(**dict(row))
