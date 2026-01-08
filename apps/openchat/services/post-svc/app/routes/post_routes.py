from fastapi import APIRouter, Request

from app.models.post import Post, PostCreate
from app.services.post_service import create, list_all

router = APIRouter()


@router.get("", response_model=list[Post])
async def posts(request: Request):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        return await list_all(conn)


@router.post("", response_model=Post, status_code=201)
async def new_post(request: Request, payload: PostCreate):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        return await create(conn, request.app, payload)
