# server/

Python（asyncio）ゲームサーバーのルート。

- 位置同期・判定・RaceManager など（設計案の役割分担どおり）
- さくら VPS 等へのデプロイ対象は主にここ
- クライアントとの同時進行方針は `docs/検討事項.md` を参照
- M1 通信契約: [`shared/protocol_m1.md`](../shared/protocol_m1.md)

## 仮想環境

開発・実行は **`server/.venv`** を使う（Git 除外済み）。初回だけ作成する。

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -U pip
.venv/bin/pip install -r requirements.txt
```

依存は `requirements.txt` に書く（M1: `websockets`）。

## M1 起動確認

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

`ぷるりんレーサーズ — サーバー待機中（M1・ping受付 :18765）`

クライアントからの `{"v":1,"t":"ping"}` に `pong`（`server_time` 付き）で返す。
