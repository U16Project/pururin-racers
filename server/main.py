"""ぷるりんレーサーズ — M2 サーバー（WebSocket ping＋控室 join）。"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from typing import Any

from websockets.asyncio.server import serve

HOST = "127.0.0.1"
PORT = 18765
PROTOCOL_VERSION = 1
ROOM_ID = "waiting_room"
ROOM_CAPACITY = 8
DEFAULT_DISPLAY_NAME = "guest"


class WaitingRoom:
    """常時1つの控室。定員 ROOM_CAPACITY。"""

    def __init__(self, capacity: int = ROOM_CAPACITY) -> None:
        self.capacity = capacity
        self._seats: dict[Any, str] = {}  # websocket -> seat_id
        self._names: dict[Any, str] = {}  # websocket -> display_name

    @property
    def member_count(self) -> int:
        return len(self._seats)

    def join(
        self, websocket: Any, display_name: str | None
    ) -> tuple[bool, dict[str, Any]]:
        """入室。成功なら (True, room_welcome)、満員なら (False, error)。"""
        if websocket in self._seats:
            return True, self._welcome_payload(self._seats[websocket])

        if self.member_count >= self.capacity:
            return False, {
                "v": PROTOCOL_VERSION,
                "t": "error",
                "code": "room_full",
                "message": "控室が満員です（定員8人）",
            }

        name = DEFAULT_DISPLAY_NAME
        if isinstance(display_name, str):
            stripped = display_name.strip()
            if stripped:
                name = stripped

        seat_id = str(uuid.uuid4())
        self._seats[websocket] = seat_id
        self._names[websocket] = name
        return True, self._welcome_payload(seat_id)

    def leave(self, websocket: Any) -> None:
        self._seats.pop(websocket, None)
        self._names.pop(websocket, None)

    def _welcome_payload(self, seat_id: str) -> dict[str, Any]:
        return {
            "v": PROTOCOL_VERSION,
            "t": "room_welcome",
            "room_id": ROOM_ID,
            "seat_id": seat_id,
            "member_count": self.member_count,
        }


def make_handler(room: WaitingRoom):
    async def handle_connection(websocket) -> None:
        try:
            async for raw in websocket:
                try:
                    data = json.loads(raw)
                except (json.JSONDecodeError, TypeError):
                    continue
                if not isinstance(data, dict):
                    continue
                if data.get("v") != PROTOCOL_VERSION:
                    continue
                msg_t = data.get("t")
                if msg_t == "ping":
                    await websocket.send(
                        json.dumps(
                            {
                                "v": PROTOCOL_VERSION,
                                "t": "pong",
                                "server_time": time.time(),
                            }
                        )
                    )
                elif msg_t == "join_room":
                    _ok, payload = room.join(websocket, data.get("display_name"))
                    await websocket.send(json.dumps(payload))
                # 未知の t は無視（接続維持）
        finally:
            room.leave(websocket)

    return handle_connection


async def _run(room: WaitingRoom | None = None) -> None:
    if room is None:
        room = WaitingRoom()
    handler = make_handler(room)
    async with serve(handler, HOST, PORT):
        print(
            "ぷるりんレーサーズ — サーバー待機中（M2・ping＋控室join :18765）",
            flush=True,
        )
        await asyncio.Future()


def main() -> None:
    try:
        asyncio.run(_run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
