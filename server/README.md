# server/

Python（asyncio）ゲームサーバーのルート。

- 位置同期・判定・RaceManager など（設計案の役割分担どおり）
- さくら VPS 等へのデプロイ対象は主にここ
- クライアントとの同時進行方針は `docs/検討事項.md` を参照
- M1 通信契約: [`shared/protocol_m1.md`](../shared/protocol_m1.md)
- M2 通信契約: [`shared/protocol_m2.md`](../shared/protocol_m2.md)（控室 join・定員 8）

## 仮想環境

開発・実行は **`server/.venv`** を使う（Git 除外済み）。初回だけ作成する。

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -U pip
.venv/bin/pip install -r requirements.txt
```

テスト用（pytest）:

```bash
.venv/bin/pip install -r requirements-dev.txt
```

依存は `requirements.txt`（`websockets`）。開発用は `requirements-dev.txt`。

Windows では `tools/windows/ensure-server-venv.ps1` も利用可。venv 内は `.venv\Scripts\` を使う。

## M2 起動確認

`server/` から:

```bash
cd server
.venv/bin/python main.py
```

リポジトリルートからでも可:

```bash
server/.venv/bin/python server/main.py
```

完了の見方: 直後に次の 1 行が出て、`127.0.0.1:18765` で WebSocket 待ち受けになる（Ctrl+C で終了）。

`ぷるりんレーサーズ — サーバー待機中（M2・ping＋控室join :18765）`

- `{"v":1,"t":"ping"}` → `pong`（`server_time` 付き）
- `{"v":1,"t":"join_room"}` → `room_welcome`（満員時は `error` / `room_full`）

## テスト

`server/` から（先に `requirements-dev.txt` を入れる）:

```bash
cd server
.venv/bin/python -m pytest -q
```
