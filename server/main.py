"""ぷるりんレーサーズ — M2 控室を維持した M5 サーバー。"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from typing import Any

from websockets.asyncio.server import serve
from race_m5 import M5Race, TICK_RATE

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
        race: M5Race | None = None
        player_id: str | None = None
        race_task: asyncio.Task | None = None

        async def race_loop() -> None:
            while race is not None and not race.finished:
                await asyncio.sleep(1.0 / TICK_RATE)
                if race is None:
                    return
                await websocket.send(json.dumps(race.tick()))
            if race is not None:
                await websocket.send(json.dumps(race.result_payload()))

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
                elif msg_t == "race_join":
                    if race is not None:
                        await websocket.send(json.dumps(race.start_payload(player_id or "player-1")))
                        continue
                    player_id = "player-1"
                    race = M5Race(race_id=str(uuid.uuid4()))
                    await websocket.send(json.dumps(race.start(player_id)))
                    race_task = asyncio.create_task(race_loop())
                elif msg_t == "race_input":
                    if race is None or player_id is None:
                        await websocket.send(json.dumps({
                            "v": PROTOCOL_VERSION, "t": "error",
                            "code": "race_not_started", "message": "レースが開始されていません",
                        }))
                    else:
                        race.receive_input(player_id, data)
                # 未知の t は無視（接続維持）
        finally:
            if race_task is not None:
                race_task.cancel()
                await asyncio.gather(race_task, return_exceptions=True)
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
