from fastapi import HTTPException

from app.data_access.country_repo import country_exists
from app.data_access.thread_repo import create_thread, get_thread, list_threads
from app.models.thread import Thread, ThreadCreate


async def list_all(conn) -> list[Thread]:
    return await list_threads(conn)


async def get_by_id(conn, thread_id: int) -> Thread:
    t = await get_thread(conn, thread_id)
    if not t:
        raise HTTPException(status_code=404, detail="Thread not found")
    return t


async def create(conn, data: ThreadCreate) -> Thread:
    if len(data.topic.strip()) < 3:
        raise HTTPException(status_code=400, detail="Topic too short")

    ok = await country_exists(conn, data.country_code)
    if not ok:
        raise HTTPException(status_code=400, detail="Invalid country_code")

    return await create_thread(conn, data)
