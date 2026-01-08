import time

from opentelemetry import metrics
from starlette.types import ASGIApp, Receive, Scope, Send


class HttpMetricsMiddleware:
    def __init__(self, app: ASGIApp, service_name: str):
        self.app = app
        meter = metrics.get_meter(service_name)

        self.req_count = meter.create_counter(
            name="http_server_requests_total",
            description="Total HTTP requests",
        )
        self.req_latency = meter.create_histogram(
            name="http_server_request_duration_ms",
            description="HTTP request duration in ms",
            unit="ms",
        )

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        method = scope.get("method", "UNKNOWN")
        path = scope.get("path", "UNKNOWN")
        status_holder = {"code": 500}

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                status_holder["code"] = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            dur_ms = (time.perf_counter() - start) * 1000.0
            attrs = {
                "method": method,
                "path": path,
                "status": str(status_holder["code"]),
            }
            self.req_count.add(1, attrs)
            self.req_latency.record(dur_ms, attrs)
