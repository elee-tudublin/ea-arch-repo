from fastapi import FastAPI

from openchat_common.http_metrics import HttpMetricsMiddleware
from openchat_common.logging import setup_logging
from openchat_common.telemetry import setup_otel

from app.db import close_db, connect_db
from app.routes.health_routes import router as health_router
from app.routes.thread_routes import router as thread_router


def create_app() -> FastAPI:
    setup_logging()

    app = FastAPI(title="OpenChat Thread Service")
    setup_otel(app, service_name="thread-svc")
    app.add_middleware(HttpMetricsMiddleware, service_name="thread-svc")

    app.include_router(health_router)
    app.include_router(thread_router, prefix="/threads", tags=["threads"])

    @app.on_event("startup")
    async def _startup():
        await connect_db(app)

    @app.on_event("shutdown")
    async def _shutdown():
        await close_db(app)

    return app


app = create_app()
