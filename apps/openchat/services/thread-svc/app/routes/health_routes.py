from fastapi import APIRouter, Request

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/ready")
async def ready(request: Request):
    pool = request.app.state.db
    async with pool.acquire() as conn:
        await conn.execute("SELECT 1")
    return {"status": "ready"}
