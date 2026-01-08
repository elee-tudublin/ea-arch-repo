from fastapi import FastAPI

from openchat_common.http_metrics import HttpMetricsMiddleware
from openchat_common.logging import setup_logging
from openchat_common.telemetry import setup_otel

from app.db import close_db, connect_db
from app.messaging.amqp import close as close_amqp
from app.messaging.amqp import connect as connect_amqp
from app.routes.health_routes import router as health_router
from app.routes.post_routes import router as post_router


def create_app() -> FastAPI:
    setup_logging()

    app = FastAPI(title="OpenChat Post Service")
    setup_otel(app, service_name="post-svc")
    app.add_middleware(HttpMetricsMiddleware, service_name="post-svc")

    app.include_router(health_router)
    app.include_router(post_router, prefix="/posts", tags=["posts"])

    @app.on_event("startup")
    async def _startup():
        await connect_db(app)
        await connect_amqp(app)

    @app.on_event("shutdown")
    async def _shutdown():
        await close_amqp(app)
        await close_db(app)

    return app


app = create_app()
