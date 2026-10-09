"""مدير اتصالات WebSocket — بث فوري لأحداث البلاغات إلى لوحة التحكم

وضعان:
- **بدون Redis**: بث داخل العملية الواحدة (تطوير).
- **مع Redis (Pub/Sub)**: يدعم تعدد workers/نسخ الخادم — كل عملية تستمع
  للقناة وتوجه الأحداث لاتصالاتها المحلية.
"""
import asyncio
import json
import logging

from fastapi import WebSocket

logger = logging.getLogger("napex.ws")

EVENTS_CHANNEL = "napex_events"

# مقياس الاتصالات النشطة (Prometheus)
try:
    from prometheus_client import Gauge

    WS_CONNECTIONS = Gauge(
        "napex_ws_connections_active",
        "عدد اتصالات لوحة التحكم النشطة",
    )
except Exception:  # pragma: no cover

    class _NoopGauge:
        def inc(self, *a, **k):
            return None

        def dec(self, *a, **k):
            return None

    WS_CONNECTIONS = _NoopGauge()


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: list[WebSocket] = []
        self._redis = None
        self._listener_task: asyncio.Task | None = None

    @property
    def active_count(self) -> int:
        return len(self._connections)

    # ============ دورة حياة Redis (Pub/Sub) ============

    async def start_redis(self, redis_url: str) -> None:
        """تفعيل Pub/Sub عند ضبط REDIS_URL — يدعم تعدد نسخ الخادم"""
        try:
            import redis.asyncio as aioredis

            self._redis = aioredis.from_url(redis_url, decode_responses=True)
            self._pubsub = self._redis.pubsub()
            await self._pubsub.subscribe(EVENTS_CHANNEL)
            self._listener_task = asyncio.create_task(self._listen())
            logger.info("WS Redis pub/sub enabled")
        except Exception as exc:
            logger.warning("WS Redis pub/sub unavailable (%s) — in-process mode", exc)
            self._redis = None

    async def stop_redis(self) -> None:
        if self._listener_task is not None:
            self._listener_task.cancel()
            self._listener_task = None
        if self._redis is not None:
            await self._redis.close()
            self._redis = None

    async def _listen(self) -> None:
        async for message in self._pubsub.listen():
            try:
                if message.get("type") != "message":
                    continue
                payload = json.loads(message["data"])
                await self._deliver_local(payload)
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("WS listener error")

    # ============ الاتصالات والبث ============

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.append(websocket)
        WS_CONNECTIONS.inc()

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self._connections:
            self._connections.remove(websocket)
            WS_CONNECTIONS.dec()

    async def broadcast(self, payload: dict) -> None:
        if self._redis is not None:
            try:
                await self._redis.publish(EVENTS_CHANNEL, json.dumps(payload))
                return
            except Exception:
                logger.warning("Redis publish failed — local fallback")
        await self._deliver_local(payload)

    async def _deliver_local(self, payload: dict) -> None:
        dead: list[WebSocket] = []
        for connection in list(self._connections):
            try:
                await connection.send_json(payload)
            except Exception:
                dead.append(connection)
        for connection in dead:
            self.disconnect(connection)


manager = ConnectionManager()
