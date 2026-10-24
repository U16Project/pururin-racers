# CPU育成ラボ（作りかけ・すべて仮）

> **2026-10-24：このやり方（つまみの頭を CMA-ES で育てる）での育成は止めた。** CPUの育成は、強化学習（`lab/rl/`。説明は `lab/rl/README.md`）に切り替えた。
> ここのファイルは消さずに残す。つまみの頭は、比べる相手には使える。

考え方は `docs/CPU育成ラボ_引き継ぎ.md`。ゲーム本体のファイルは変えていない。
ラボは、ゲーム（`client/`）の外に置いてある（書き出しに入らない）。動かすときは、ゴドーに `client/` を開かせて、ラボの台本を外から渡す。

## しくみ

- 頭は「つまみ」（`knobs.json`）の数字のひと組。ぷるりん1体ごとに育てる。性格（`trainer_styles.json` の frame）はトレーナーごとに固定で、つまみはその枠の中だけで動く。
- ノッチは、順位・体力・心拍・抜かれた／詰められた・温存の「上げたい／下げたい」の気持ちを、重さで足して決める。
- **先生役**：あなたがオフラインで走った記録（`lab_settings.json` の `teacher_since` より後）を、`lab_teacher.gd` がそのぷるりんの頭に写す（`brains/<ぷるりん>.json`）。育成は、写した頭から始める。
- 頭の席は、オンラインで「通信ごしの人」が使うのと同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で走る。人と同じボタンしか使えない。
- 育て方は CMA-ES（前例のある定番のやり方。`cma.gd`）。候補を作り、同じレースの一覧を走らせ、点の良い候補の向きへ寄せる。
- レースの作り方は、オンラインのサーバーと同じ（記録ファイルは書かない）。

## ファイル

| ファイル | 役目 |
|---|---|
| `knobs.json` | つまみの一覧（名前・説明・範囲・距離で2つの数字を持つか）。**つまみを足すときは、ここに足して、`knob_brain.gd` に使い方を足す** |
| `knob_brain.gd` | 性格の枠とつまみと今の状況から、操作を決める |
| `trainer_styles.json` | トレーナーの性格（言葉と、頭が使う枠の数字） |
| `lab_teacher.gd` | あなたの走りの記録を、そのぷるりんの頭に写す |
| `brains/` | 写した頭・育った頭（git に入れる） |
| `lab_situation.gd` | 頭が見る、今の状況（残り距離・心拍・体力・順位・前の走者など） |
| `cma.gd` | 育て方（CMA-ES） |
| `lab_race.gd` | レースを1本走らせて、結果を返す |
| `lab_worker.gd` | 画面なしで、仕事のファイルのレースを順に走らせる |
| `lab_batch.gd` | 何本かを同時に走らせて、集めて、点を付ける。レースの一覧を作る |
| `lab_score.gd` | 点の付け方（成績の項目 × 重さ） |
| `lab_settings.json` | ラボの設定（点の重さ・候補の数・レースの数など） |
| `lab_evolve.gd` | 育成（ぷるりんごと） |
| `lab_trial.gd` | 試し走り（頭を、今までのCPUと比べる目安） |
| `lab_noise.gd` | 確かめ方の確かめ（同じ頭8体で、運の差を測る） |
| `lab_play.gd` | 人と走る（画面あり） |
| `runs/` | 走らせた結果（git に入れない） |

## 動かし方（client/ で）

```bash
# 先生役：ヒカリの記録を写す（1分ほど）
../tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . -s ../lab/lab_teacher.gd -- pururin=player-1
# 育成：3代
../tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . -s ../lab/lab_evolve.gd -- generations=3 out=育成1
# 人と走る（育成の最後の代の頭と）
../tools/godot/Godot_v4.7-stable_linux.x86_64 --path . -s ../lab/lab_play.gd -- run=育成1 me=player-1
```

## 点

点 ＝ Σ（成績の項目 × 重さ）。重さは `lab_settings.json` の `score`。項目は `lab_score.gd` の `METRICS`。重さを書いた項目だけが点に入る。
