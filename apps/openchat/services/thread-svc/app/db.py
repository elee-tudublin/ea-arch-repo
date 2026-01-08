import os

import asyncpg
from fastapi import FastAPI


def _db_dsn() -> str:
    return os.getenv(
        "DATABASE_URL",
        "postgresql://openchat:openchat@postgres.openchat-dev:5432/openchat",
    )


async def connect_db(app: FastAPI) -> None:
    app.state.db = await asyncpg.create_pool(dsn=_db_dsn(), min_size=1, max_size=5)


async def close_db(app: FastAPI) -> None:
    pool = getattr(app.state, "db", None)
    if pool:
        await pool.close()
