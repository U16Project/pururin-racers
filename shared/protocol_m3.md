# M3 通信・画面ライフサイクル

M3 は新しい wire message を追加しない。M1 の `ping` / `pong` と、M2 の
`join_room` / `room_welcome` / `error` をそのまま使う。

## 画面と回線

1. `res://scenes/m3_intro.tscn` を起動する。
2. 導入画面はオフラインで成立する。左右移動とカメラ切替、控室への進み方を案内する。
3. 「控室へ進む」ボタンまたは決定操作で `res://scenes/m2_run.tscn` へ遷移する。
4. M2 の既存 `net_room_m2.gd` が WebSocket 接続と `join_room` を行う。
5. M2 の status label に接続状態と控室入室結果を表示する。

## 接続状態

| 状態 | 表示 |
|------|------|
| 接続中 | `接続しています…` |
| 接続成功 | `接続できました`（控室情報を続けて表示する場合がある） |
| 接続失敗 | `接続できませんでした。サーバーを起動してください` |

## 既存契約

- 接続先、共通フィールド、`ping` / `pong` は [`protocol_m1.md`](protocol_m1.md) を参照。
- 控室の join、定員、切断時の退室、`room_welcome` / `error` は [`protocol_m2.md`](protocol_m2.md) を参照。
- M3 では接続維持と画面遷移の対応だけを追加し、レース判定・位置同期・マッチングは追加しない。
