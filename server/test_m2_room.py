"""M2 控室 join の契約テスト（shared/protocol_m2.md）。"""

from __future__ import annotations

import asyncio
import json

import pytest
import pytest_asyncio
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve

from main import HOST, PROTOCOL_VERSION, ROOM_ID, WaitingRoom, make_handler


@pytest_asyncio.fixture
async def room_server():
    """短時間の控室付き WebSocket サーバー（空きポート）。"""
    room = WaitingRoom()
    handler = make_handler(room)
    async with serve(handler, HOST, 0) as server:
        sock = server.sockets[0]
        port = sock.getsockname()[1]
        yield room, port


async def _join(ws, display_name: str | None = None) -> dict:
    payload: dict = {"v": PROTOCOL_VERSION, "t": "join_room"}
    if display_name is not None:
        payload["display_name"] = display_name
    await ws.send(json.dumps(payload))
    raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
    data = json.loads(raw)
    assert isinstance(data, dict)
    return data


@pytest.mark.asyncio
async def test_join_room_success(room_server) -> None:
    room, port = room_server
    uri = f"ws://{HOST}:{port}"
    async with connect(uri) as ws:
        msg = await _join(ws, "テスト太郎")
    assert msg["v"] == PROTOCOL_VERSION
    assert msg["t"] == "room_welcome"
    assert msg["room_id"] == ROOM_ID
    assert isinstance(msg["seat_id"], str) and len(msg["seat_id"]) > 0
    assert msg["member_count"] == 1
    # 切断後は退室（ハンドラ finally が走るまで短く待つ）
    await asyncio.sleep(0.05)
    assert room.member_count == 0


@pytest.mark.asyncio
async def test_eight_join_ninth_room_full(room_server) -> None:
    room, port = room_server
    uri = f"ws://{HOST}:{port}"
    holders = []
    try:
        for i in range(8):
            ws = await connect(uri)
            holders.append(ws)
            msg = await _join(ws, f"guest{i}")
            assert msg["t"] == "room_welcome"
            assert msg["member_count"] == i + 1

        assert room.member_count == 8

        async with connect(uri) as ninth:
            err = await _join(ninth)
            assert err["v"] == PROTOCOL_VERSION
            assert err["t"] == "error"
            assert err["code"] == "room_full"
            assert isinstance(err.get("message"), str) and err["message"]
            assert room.member_count == 8
    finally:
        for ws in holders:
            await ws.close()


@pytest.mark.asyncio
async def test_ping_still_works(room_server) -> None:
    _room, port = room_server
    uri = f"ws://{HOST}:{port}"
    async with connect(uri) as ws:
        await ws.send(json.dumps({"v": PROTOCOL_VERSION, "t": "ping"}))
        raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
        msg = json.loads(raw)
    assert msg["t"] == "pong"
    assert "server_time" in msg


def test_waiting_room_unit_capacity() -> None:
    """ネットワークなしで定員ロジックを確認。"""
    room = WaitingRoom(capacity=2)
    ws1, ws2, ws3 = object(), object(), object()
    ok1, p1 = room.join(ws1, None)
    ok2, p2 = room.join(ws2, "  ")
    ok3, p3 = room.join(ws3, "x")
    assert ok1 and p1["t"] == "room_welcome" and p1["member_count"] == 1
    assert ok2 and p2["member_count"] == 2
    assert not ok3 and p3["code"] == "room_full"
    room.leave(ws1)
    assert room.member_count == 1
    ok4, p4 = room.join(ws3, "y")
    assert ok4 and p4["member_count"] == 2
