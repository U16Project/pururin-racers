# CPUの強化学習（作りかけ・すべて仮）

Gran Turismo の Sophy と同じ考え方。人が決めるのは「何を見るか」と「何が良いか（点）」だけで、走り方は頭が自分で見つける。
ゲーム本体（`client/`）のファイルは変えていない。ゴドーに `client/` を開かせて、ここの台本を外から渡す。

## 入れたもの（リポジトリの外）

- Python の仮の箱：`/media/u16/Backup/pururin-rl-venv/`（PyTorch・stable-baselines3・sb3-contrib・gymnasium・numpy）
- ダウンロードの一時置き場：`/media/u16/Backup/pururin-rl-cache/`（消してよい）
- 入れ直すとき：`PIP_CACHE_DIR` と `TMPDIR` を上の一時置き場にしてから `pip install`（「/」の空きが少ないため）

## しくみ

- 頭の席は、オンラインで「通信ごしの人」が使うのと同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で走る。ほかの7席は今のゲームのCPU。
- 0.5秒ごとに、ゴドーが「見たもの（数字の並び）・点・終わったか・選べる操作」を Python に送り、Python が操作を返す。返事を待つあいだ、ゲームの時間は止まる。
- 選べない操作（ブーストの残り0、ノッチ0やブレーキ中のダッシュ・ブーストなど、ゲームが受け付けないもの）は外す。場面ごとの決めごとは入れない。
- 点：ゴールの着順の点＋前へ進んだ分の小さな点。重さは `rl_settings.json` の `reward`。
- 育て方：PPO（使えない操作を外せる版。sb3-contrib の MaskablePPO）。
- 学ぶレースと比べるレースは、くじの番号を分けている（`rl_settings.json` の `seeds`）。

## ファイル

| ファイル | 役目 |
|---|---|
| `rl_settings.json` | 設定（点の重さ・学ぶぷるりん・距離・くじの番号・育て方の数字） |
| `rl_observe.gd` | 見るもの（数字の並び）と、選べる操作 |
| `rl_race.gd` | レースを1本走らせて、Python とやりとりする |
| `rl_link.gd` | Python とのつなぎ（このPCの中の通信） |
| `rl_worker.gd` | 画面なしのゴドー1つぶん |
| `godot_env.py` | ゴドー1つを、学習の場1つとして扱う。レースの決め方（くじの番号 → 距離・出走・枠順） |
| `check.py` | つなぎの確かめ（並びの長さ・選べない操作・同じ番号で同じ結果） |
| `train.py` | 育てる（8つ同時） |
| `evaluate.py` | 比べる（学ぶのに使っていない200レース） |
| `runs/` | 育てた頭・記録（git に入れない） |

## 動かし方（リポジトリのいちばん上で）

```bash
# つなぎの確かめ
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/check.py
# 育てる
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 試し1 --steps 2000000
# 比べる（今のゲームのCPU／学ぶ前／育てた頭）
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/evaluate.py --who cpu
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/evaluate.py --who untrained
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/evaluate.py --who lab/rl/runs/試し1/latest.zip
```
