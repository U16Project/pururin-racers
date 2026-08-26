# shared/

クライアント（Godot）とサーバー（Python）が同じ意味で参照する **契約・定義** の置き場。

## 置く想定

- 通信メッセージの形・フィールド名・ID
- 両側で揃えたい定数（例: 最大出走数、同期間隔の定義名）
- 将来のスキーマ（JSON 等）

## 現状

| ファイル | 内容 |
|----------|------|
| [`protocol_m1.md`](protocol_m1.md) | M1: WebSocket + JSON の ping／pong（`127.0.0.1:18765`） |
| [`protocol_m2.md`](protocol_m2.md) | M2: 同ポートの控室 `join_room`／`room_welcome`／`room_full`（定員 8） |

## 置かない

- Godot のシーン・メッシュ・UI
- RaceManager 本体などのサーバー実装
- カメラ等のクライアント専有設定

## 注意

バランス数値の **権威（正本）** はオンライン後はサーバー側を基本とする方針（MAGI 審議）。  
`shared/` は主に「両側が先に揃えておく契約」用。
