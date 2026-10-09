# ゲームの見た目に合わせた絵 v01

ゲームの中の本物のぷるりん（`client/data/config/pururin_looks.json` の8プル）を、仮に組み立てたレース場に置いて撮った絵。
レース場は、世界観設定（城下町・お祭りのレース場）に合わせてある。コースの幅（15m）はゲームと同じ。

注意：この絵のコースの形（直線526m・コーナー半径164m）と、固定のスタートの門は、ゲームと違う。ゲームのコースは直線680m・コーナー半径約115mで、スタートは距離ごとに場所が変わる。ゲームに入れた景色は `client/scripts/presentation/race_venue.gd`（スタートは `start_gate.gd`）。

一覧は `index_v01.jpg`。大きい版（3840x2160、JPEG）は `4k/`。

| ファイル | 中身 |
|---|---|
| `title_background_v01.png` | 現行タイトル画面案。レース場背景、タイトルロゴ、レース場のSTART看板を含む。アプリの操作ボタン・メニューUIは含めない |
| `title_background_nologo_v01.png` | 同じ絵の、ロゴなし |
| `title_background_sunset_v01.png` / `..._sunset_nologo_v01.png` | 夕方の版 |
| `kv_start_gate_v01.png` / `kv_start_front_v01.png` | スタート前。枠の番号の札は、ゲームの枠の色 |
| `kv_race_pack_v01.png` | レース中の集団（押し合い） |
| `kv_goal_v01.png` | 1位でゴール |
| `kv_banner_3x1_v01.png` | 横長（3:1） |
| `ref_race_view_v01.png` | レース画面の見え方。カメラはゲームと同じ（後ろ6m・高さ3m） |
| `ref_curve_view_v01.png` | コーナーの入口（ぷるりん無し） |
| `ref_home_straight_v01.png` / `ref_stands_v01.png` | 直線と観客席（ぷるりん無し） |
| `ref_venue_wide_v01.png` / `..._sunset_v01.png` | レース場と城下町の全体 |
| `cast_lineup_v01.png` / `cast_group_v01.png` | 8プルの立ち絵（背景は透明） |
| `icon_v01.png` | アイコン（1024x1024） |
| `logo_draft_v01.png` / `logo_draft_text_only_v01.png` | ロゴの下書き（背景は透明）。書体は「源暎ぽっぷる Black」 |

## 作り直し方

`src/kv.gd` が撮影用の場面（Godot）。ぷるりんの見た目を変えたあとに撮り直せる。

```bash
src/shoot.sh title      # src/out/title.png ができる
python3 src/logo.py     # 先に src/shoot.sh logo_pururin を撮っておく
```

レース場の部品（柵・観客席・王さまの席・旗・門・テント・城）は、`kv.gd` の `_build_*` に、部品ごとに分けて書いてある。
