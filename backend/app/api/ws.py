"""WebSocket — بث فوري لأحداث البلاغات إلى لوحة التحكم

الاستخدام: ws://host/api/v1/ws?token=<access_token>
الرسائل: {"type": "new_report", "report": {...}} أو {"type": "status_change", ...}
العميل يرسل "ping" دورياً للحفاظ على الاتصال.
"""
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.core.security import decode_token
from app.services.notify import manager

router = APIRouter(tags=["ws"])


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(default=""),
) -> None:
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise ValueError("wrong token type")
    except Exception:
        await websocket.close(code=4401)
        return

    await manager.connect(websocket)
    try:
        while True:
            # استقبال pings من العميل للحفاظ على الاتصال
            message = await websocket.receive_text()
            if message == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception:
        manager.disconnect(websocket)
