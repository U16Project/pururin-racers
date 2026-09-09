# M5 サーバー権威レース契約

共通フィールドは `v: 1` と `t`。接続先は既存の `ws://127.0.0.1:18765`。
`ping` / `join_room` は M1/M2 契約のまま利用できる。

## race_join

クライアントが送信する開始要求。M5 v0.1 は最初の接続をプレイヤー1人として、
不足分をサーバーが CPU 7頭で補充する。

```json
{"v": 1, "t": "race_join", "display_name": "あなた"}
```

## race_start

サーバーが返す初期状態。`racers` は8頭。`elapsed_seconds` は `0.0`。

## race_input

クライアントが送信できるのは目標値だけ。位置・速度・順位・P値は送信しない。

```json
{"v": 1, "t": "race_input", "target_speed": 60.0, "target_offset": -1.0}
```

## race_tick

サーバーが20Hz程度で配信する。各 racer に `distance`、`race_progress`、
`offset`、`speed`、`own_wake_p`、`received_draft_p`、`contact` を含む。
トップレベルに `tick` と決定的な `elapsed_seconds`（`tick / tick_rate`）を含む。

ドラフトはtick開始時のスナップショットからのみ決定し、複数の前方相手を合算する。
受取率・距離・ライン差・個体数・合計値をサーバー側で制限する。

## race_result

全8頭のゴール後にサーバーが配信する順位。トップレベルに
`elapsed_seconds`、各結果に `finish_time` と互換用の `time` を含む。

## error

`race_not_started` などのコードと人間向け `message` を含む。
