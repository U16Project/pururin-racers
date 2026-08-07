# server/

Python（asyncio）ゲームサーバーのルート。

- 位置同期・判定・RaceManager など（設計案の役割分担どおり）
- さくら VPS 等へのデプロイ対象は主にここ
- クライアントとの同時進行方針は `docs/検討事項.md` を参照

## 仮想環境

開発・実行は **`server/.venv`** を使う（Git 除外済み）。初回だけ作成する。

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -U pip
.venv/bin/pip install -r requirements.txt
```

依存は `requirements.txt` に書く。現状（M0）は標準ライブラリのみなので、install は実質確認用。

## M0 起動確認

`server/` から:

```bash
cd server
.venv/bin/python main.py
```

リポジトリルートからでも可:

```bash
server/.venv/bin/python server/main.py
```

完了の見方: 直後に次の 1 行が出て、プロセスが生きたままになる（Ctrl+C で終了）。

`ぷるりんレーサーズ — サーバー起動しました（M0・まだ通信しません）`
