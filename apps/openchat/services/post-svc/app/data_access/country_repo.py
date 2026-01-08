import asyncpg


async def country_exists(conn: asyncpg.Connection, code: str) -> bool:
    row = await conn.fetchrow("SELECT 1 FROM country WHERE code=$1", code)
    return row is not None
