# M5 サーバー権威レース契約

共通フィールドは `v: 1` と `t`。接続先は既存の `ws://127.0.0.1:18765`。
`ping` / `join_room` は M1/M2 契約のまま利用できる。

## コース wire 定義

M5 のコース正本は [`course_layout_m5.json`](course_layout_m5.json)。
`course_id` は `"m5_standard_oval"`、`route_id` は距離別に
`m5_1200` / `m5_1600` / `m5_2000` / `m5_2400` / `m5_3000` を使う。
`distance_m` はレースの route distance であり、ゴール判定は
`race_progress >= distance_m` とする。`distance` は描画・幾何用の
mainline distance で、レース進行の代用にはしない。

共通オーバルは周長 2083.1m、直線 680m×2、半円ターン半径 115.085m×2。
`goal_path_m: 400.0` はホーム直線上のゴール意味位置であり、1600m の
`straight(160m) + mainline(1440m)` を含む専用 route も一つの連続 route
として扱う。`start_mainline_m` は route 開始時の描画用基準位置である。

## race_join

クライアントが送信する開始要求。M5 v0.1 は最初の接続をプレイヤー1人として、
不足分をサーバーが CPU 7頭で補充する。

```json
{"v": 1, "t": "race_join", "display_name": "あなた"}
```

## race_start

サーバーが返す初期状態。`racers` は8頭。`elapsed_seconds` は `0.0`。
トップレベルに `course_id`、`route_id`、`distance_m`、`goal_path_m` を含む。

## race_input

クライアントが送信できるのは目標値だけ。位置・速度・順位・P値は送信しない。

```json
{"v": 1, "t": "race_input", "target_speed": 60.0, "target_offset": -1.0}
```

## race_tick

サーバーが20Hz程度で配信する。各 racer に `distance`、`race_progress`、
`offset`、`speed`、`actual_speed_kmh`、`own_wake_p`、`received_draft_p`、
`contact` を含む。`speed` は接触解決前の計画／追従速度、
`actual_speed_kmh` は接触解決・進行確定後の進行deltaから算出した実測速度
（m/sからkm/hへ換算）であり、別の値として扱う。
サーバーの物理単位は、コース距離・進行・gapが m、速度が km/h である。
tick の確定中心線進行は
`speed_kmh / 3.6 * delta / distance_multiplier(offset, curvature)`。
`curvature` は直線で `0`、解析的な半円ターンで `1 / 115.085`。
距離倍率は `max(0.05, lerp(1.0, 1.0 + offset * curvature, 0.85))` とし、
offset は負が内側、正が外側である。直線の倍率は常に `1.0`。
トップレベルに `course_id`、`route_id`、`distance_m`、`tick` と決定的な
`elapsed_seconds`（`tick / tick_rate`）を含む。

ドラフトは移動確定後の同一post-moveスナップショットから決定し、複数の前方相手を合算する。
`direct_draft_p` は前方progress gapと横差に連続減衰する直接寄与の合計、
`chain_draft_p` は前tickの相手の直接＋連鎖値を弱く減衰した連鎖寄与、
`received_draft_p` は両者の合計である。単独走行時は直接・連鎖・総合とも0%。
`direct_source_details` は直接対象ごとの `{id, gap, line, contribution_p}`（gap/lineはm）。
各 `contribution_p` の合計は `direct_draft_p`（上限適用後）と一致し、
`primary_source_id`、`primary_gap_m`、`primary_line_gap_m` は先頭対象の同じ値を示す。
受取率・距離・ライン差・個体数・合計値をサーバー側で制限する。

## race_result

全8頭のゴール後にサーバーが配信する順位。トップレベルに
`course_id`、`route_id`、`distance_m`、`elapsed_seconds`、各結果に
`finish_time` と互換用の `time` を含む。

## error

`race_not_started` などのコードと人間向け `message` を含む。
