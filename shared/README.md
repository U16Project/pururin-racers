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
| [`protocol_m3.md`](protocol_m3.md) | M3: 導入画面と控室への遷移。新しい wire は追加しない |
| [`protocol_local_race.md`](protocol_local_race.md) | ローカル簡易レースの画面遷移と仮ルール |
| [`protocol_m5.md`](protocol_m5.md) | M5: サーバー権威の 1 レース |
| [`course_layout_m5.json`](course_layout_m5.json) | 標準コースの正本。クライアント写しは `client/data/course_layout_m5.json` |
| [`m5_draft_rules.json`](m5_draft_rules.json) | M5 共通ドラフト規則の正本。クライアント写しは `client/data/config/m5_draft_rules.json` |

## 置かない

- Godot のシーン・メッシュ・UI
- RaceManager 本体などのサーバー実装
- カメラ等のクライアント専有設定

## 注意

バランス数値の **権威（正本）** はオンライン後はサーバー側を基本とする方針（MAGI 審議）。ただし `m5_draft_rules.json` は、サーバー判定とクライアントのローカル再現／HUD が同じ意味で読む共通規則としてここに置く。サーバーは正本を直接読み、クライアントは同一内容の同梱写しを読む。
`shared/` は主に「両側が先に揃えておく契約」用。
