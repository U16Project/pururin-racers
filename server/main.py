"""ぷるりんレーサーズ — M1 サーバー（WebSocket ping→pong）。"""

from __future__ import annotations

import asyncio
import json
import time

from websockets.asyncio.server import serve

HOST = "127.0.0.1"
PORT = 18765
PROTOCOL_VERSION = 1


async def handle_connection(websocket) -> None:
    async for raw in websocket:
        try:
            data = json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(data, dict):
            continue
        if data.get("v") != PROTOCOL_VERSION or data.get("t") != "ping":
            continue
        await websocket.send(
            json.dumps(
                {
                    "v": PROTOCOL_VERSION,
                    "t": "pong",
                    "server_time": time.time(),
                }
            )
        )


async def _run() -> None:
    async with serve(handle_connection, HOST, PORT):
        print(
            "ぷるりんレーサーズ — サーバー待機中（M1・ping受付 :18765）",
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
