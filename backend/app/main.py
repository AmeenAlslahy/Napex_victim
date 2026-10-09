"""نقطة تجميع خادم NAP-EX — National Anti-Extortion Platform

التشغيل: uvicorn app.main:app --reload --port 8000
التوثيق التفاعلي: http://localhost:8000/docs
"""
import logging
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api import (
    admin,
    analysis,
    auth,
    blocklist,
    cases,
    cloud,
    evidence,
    forensic,
    international,
    legal,
    me,
    media,
    reports,
    stats,
    victim,
    ws,
)
from app.core.config import get_settings
from app.core.limits import limiter
from app.db.base import SessionLocal, init_db
from app.db.seed import seed_dashboard_users
from app.models.system_config import SystemConfig
from app.services.notify import manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)

settings = get_settings()

# ============ Observability — Sentry (اختياري عبر SENTRY_DSN) ============
if settings.sentry_dsn:
    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        traces_sample_rate=0.1,
        integrations=[FastApiIntegration()],
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    db = SessionLocal()
    try:
        seed_dashboard_users(db)
        # تحميل أوزان التغذية الراجعة المحفوظة إلى المصنّف (Feedback Loop)
        from app.services.classifier import classifier
        from app.services.feedback_learner import load_persisted_overrides

        classifier.apply_overrides(load_persisted_overrides(db))
    finally:
        db.close()
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

    # WS Pub/Sub عبر Redis (تعدد workers)
    if settings.redis_url:
        await manager.start_redis(settings.redis_url)

    # مجدول الاحتفاظ التلقائي (يومياً 02:00)
    scheduler = None
    if settings.scheduler_enabled:
        from apscheduler.schedulers.background import BackgroundScheduler

        from app.services.retention import run_all

        def retention_job() -> None:
            session = SessionLocal()
            try:
                result = run_all(session)
                logging.getLogger("napex").info("Retention: %s", result)
            finally:
                session.close()

        scheduler = BackgroundScheduler()
        scheduler.add_job(retention_job, "cron", hour=2, minute=0, id="napex_retention")
        scheduler.start()

    logging.getLogger("napex").info("NAP-EX backend ready")
    yield

    if scheduler is not None:
        scheduler.shutdown()
    await manager.stop_redis()


app = FastAPI(
    title=settings.app_name,
    description="المنصة الوطنية لمكافحة الابتزاز الإلكتروني — الخادم المركزي",
    version="1.0.0",
    lifespan=lifespan,
)

# ============ Rate Limiting ============
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


class RequestIDMiddleware:
    """معرّف فريد لكل طلب — يُعاد في الترويسة ويُسجل مع الزمن"""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request = Request(scope)
        request_id = request.headers.get("X-Request-Id") or uuid.uuid4().hex
        started = time.perf_counter()

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                headers = message.setdefault("headers", [])
                headers.append(
                    (b"x-request-id", request_id.encode())
                )
                duration_ms = (time.perf_counter() - started) * 1000
                headers.append(
                    (b"x-response-time-ms", f"{duration_ms:.1f}".encode())
                )
            await send(message)

        await self.app(scope, receive, send_with_headers)


app.add_middleware(RequestIDMiddleware)

# ============ Observability — Prometheus ============
if settings.metrics_enabled:
    from prometheus_fastapi_instrumentator import Instrumentator

    Instrumentator(excluded_handlers=["/metrics", "/health"]).instrument(
        app
    ).expose(app)


class KillswitchMiddleware:
    """مفتاح الإيقاف الطارئ — يرفض كل الطلبات عدا /health و /metrics و /admin

    (Incident Response: الاحتواء الفوري عند اختراق أو تسرّب)
    ملاحظة: بلا تخزين مؤقت عمداً — التفعيل يجب أن يسري في الطلب التالي مباشرة.
    """

    def __init__(self, app):
        self.app = app

    def _is_active(self) -> bool:
        try:
            db = SessionLocal()
            try:
                row = db.get(SystemConfig, "killswitch")
                return bool(
                    row
                    and isinstance(row.value, dict)
                    and row.value.get("enabled")
                )
            finally:
                db.close()
        except Exception:
            return False

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            path = scope["path"]
            segments = path.strip("/").split("/")
            allowed = (
                path == "/health"
                or path == "/metrics"
                or (path.endswith("/health") and "v1" in segments)
                or "admin" in segments
            )
            if not allowed and self._is_active():
                response = JSONResponse(
                    status_code=503,
                    content={
                        "detail": "النظام في وضع الصيانة الطارئة — تواصل مع الإدارة",
                        "code": "KILLSWITCH_ACTIVE",
                    },
                )
                await response(scope, receive, send)
                return
        await self.app(scope, receive, send)


app.add_middleware(KillswitchMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        origin.strip()
        for origin in settings.cors_origins.split(",")
        if origin.strip()
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_PREFIX = "/api/v1"
app.include_router(auth.router, prefix=API_PREFIX)
app.include_router(reports.router, prefix=API_PREFIX)
app.include_router(cases.router, prefix=API_PREFIX)
app.include_router(evidence.router, prefix=API_PREFIX)
app.include_router(analysis.router, prefix=API_PREFIX)
app.include_router(stats.router, prefix=API_PREFIX)
app.include_router(forensic.router, prefix=API_PREFIX)
app.include_router(legal.router, prefix=API_PREFIX)
app.include_router(cloud.router, prefix=API_PREFIX)
app.include_router(victim.router, prefix=API_PREFIX)
app.include_router(blocklist.router, prefix=API_PREFIX)
app.include_router(admin.router, prefix=API_PREFIX)
app.include_router(me.router, prefix=API_PREFIX)
app.include_router(international.router, prefix=API_PREFIX)
app.include_router(media.router, prefix=API_PREFIX)
app.include_router(ws.router, prefix=API_PREFIX)


@app.get("/health", tags=["health"])
def health() -> dict:
    return {"status": "ok", "service": "napex-backend", "version": "1.0.0"}


@app.get(API_PREFIX + "/health", tags=["health"])
def health_v1() -> dict:
    return {"status": "ok", "service": "napex-backend", "version": "1.0.0"}
