from fastapi import APIRouter, Request

from app.models.thread import Thread, ThreadCreate
from app.services.thread_service import create, get_by_id, list_all

router = APIRouter()


@router.get("", response_model=list[Thread])
async def threads(request: Request):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        return await list_all(conn)


@router.get("/{thread_id}", response_model=Thread)
async def thread(request: Request, thread_id: int):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        return await get_by_id(conn, thread_id)


@router.post("", response_model=Thread, status_code=201)
async def new_thread(request: Request, payload: ThreadCreate):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        return await create(conn, payload)
