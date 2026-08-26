# M2 通信契約（WebSocket + JSON）— 控室 join

クライアントとサーバーが同じ意味で使う **M2 用** の最小契約（空部屋 join）。  
輸送: WebSocket（テキストフレーム）+ JSON。UDP は使わない。

M1 の ping／pong（[`protocol_m1.md`](protocol_m1.md)）は同じ接続・同じポートで継続する。

## 接続

| 項目 | 値 |
|------|-----|
| 待ち受け | `127.0.0.1:18765` |
| URL（クライアント） | `ws://127.0.0.1:18765` |

※ ポート **8765 は使わない**（18765 固定）。M1 と同じ。

## 共通フィールド

| キー | 型 | 説明 |
|------|-----|------|
| `v` | number | 契約バージョン。M2 は **1** |
| `t` | string | メッセージ種別（wire 上の type） |

## 控室

| 項目 | 値 |
|------|-----|
| 部屋 | 常時 1 つ。`room_id` は `"waiting_room"` |
| 定員 | **8**（人間席） |
| 退室 | 切断で退室。`member_count` が減る |

## Client → Server: `join_room`

```json
{"v": 1, "t": "join_room", "display_name": "任意文字列（省略可）"}
```

| キー | 型 | 説明 |
|------|-----|------|
| `display_name` | string（省略可） | 表示名。無い／空ならサーバーが短い既定名（例: `guest`）を使う。wire に返す必要はない |

## Server → Client: `room_welcome`（成功）

```json
{"v": 1, "t": "room_welcome", "room_id": "waiting_room", "seat_id": "<uuid文字列>", "member_count": 1}
```

| キー | 型 | 説明 |
|------|-----|------|
| `room_id` | string | 常に `"waiting_room"` |
| `seat_id` | string | その接続に割り当てた座席 ID（UUID 文字列） |
| `member_count` | number | 入室後の人数（1〜8） |

## Server → Client: `error`（失敗）

```json
{"v": 1, "t": "error", "code": "room_full", "message": "人間向け短い説明"}
```

| キー | 型 | 説明 |
|------|-----|------|
| `code` | string | M2 では満員時 `"room_full"` |
| `message` | string | 人間向けの短い説明 |

- 定員 8 のとき、9 人目の `join_room` は `room_full`。接続は維持してよい。

## 既存: `ping` / `pong`

M1 と同じ。`{"v":1,"t":"ping"}` → `pong`（`server_time` 付き）。

## 不正・未知メッセージ

- 不正な JSON、未知の `t`、`v` 不一致などは **無視**（接続維持）。
- `ping` は従来どおり応答する。

## 体験の完了条件（M2・本契約範囲）

- 接続後に控室へ入れ、画面で分かること
- 定員超過時に `room_full` が返ること
