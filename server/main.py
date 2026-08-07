"""ぷるりんレーサーズ — M0 サーバー起動（通信なし）。"""

from __future__ import annotations

import asyncio


async def _run() -> None:
    print(
        "ぷるりんレーサーズ — サーバー起動しました（M0・まだ通信しません）",
        flush=True,
    )
    await asyncio.Event().wait()


def main() -> None:
    try:
        asyncio.run(_run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
