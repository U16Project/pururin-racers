# CPUの強化学習（作りかけ・すべて仮）

Gran Turismo の Sophy と同じ考え方。人が決めるのは「何を見るか」と「何が良いか（点）」だけで、走り方は頭が自分で見つける。
ゲーム本体（`client/`）のファイルは変えていない。ゴドーに `client/` を開かせて、ここの台本を外から渡す。

## 入れたもの（リポジトリの外）

- Python の仮の箱：`/media/u16/Backup/pururin-rl-venv/`（PyTorch・stable-baselines3・sb3-contrib・gymnasium・numpy）
- ダウンロードの一時置き場：`/media/u16/Backup/pururin-rl-cache/`（消してよい）
- 入れ直すとき：`PIP_CACHE_DIR` と `TMPDIR` を上の一時置き場にしてから `pip install`（「/」の空きが少ないため）

## しくみ

- 1レース8席すべてを育てるCPUが走らせる（自分どうしの対戦）。出る8体は、レースごとに10体からくじで選ぶ。受け持ちは `rl_settings.json` の `brains`。
- 席は、オンラインで「通信ごしの人」が使うのと同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で走る。
- 0.5秒ごとに、ゴドーが「見たもの（数字の並び）・点・終わったか・選べる操作」を Python に送り、Python が操作を返す。返事を待つあいだ、ゲームの時間は止まる。
- 選べない操作（ブーストの残り0、ノッチ0やブレーキ中のダッシュ・ブーストなど、ゲームが受け付けないもの）は外す。場面ごとの決めごとは入れない。
- 点：ゴールの着順の点＋前へ進んだ分の小さな点。重さは `rl_settings.json` の `reward`。
- 育て方：PPO（使えない操作を外せる版。sb3-contrib の MaskablePPO）。
- 1レースのうち2席（`pool.seats`）は、相手の控え室（`runs/控え室/`）からくじで選んだCPUが走らせる（学ばない）。1時間ごとの版は自動で入る。上限10体（`pool.max`）、名前の頭が「固定_」のものは外さない。
- 育てるCPUの操作は、ゲームの設定 `cpu_reaction_delay_s`（0.3秒）だけ遅れて届く。

## ファイル

| ファイル | 役目 |
|---|---|
| `override_脚質.json` | 脚質優先の版（脚質1）だけの、設定の上書き（性格の点を重く） |
| `rl_settings.json` | 設定（点の重さ・学ぶぷるりん・距離・くじの番号・育て方の数字） |
| `rl_observe.gd` | 見るもの（数字の並び）と、選べる操作 |
| `rl_race.gd` | レースを1本走らせて、Python とやりとりする |
| `rl_link.gd` | Python とのつなぎ（このPCの中の通信） |
| `rl_worker.gd` | 画面なしのゴドー1つぶん |
| `godot_env.py` | ゴドー1つを、学習の場1つとして扱う。レースの決め方（くじの番号 → 距離・出走・枠順） |
| `check.py` | つなぎの確かめ（並びの長さ・選べない操作・同じ番号で同じ結果） |
| `train.py` | 育てる（8つ同時） |
| `pool.py` | 相手の控え室（保存したCPUに、レースの一部の席を走らせる）。成績の表と、管理のアドバイス |
| `play.py` | 育てているCPUと、人がいっしょに走る（ゲームのレース選択の画面を借りる） |
| `runs/` | 育てた頭・記録（git に入れない） |

## 動かし方（リポジトリのいちばん上で）

```bash
# 育成を始める（止めるときは Ctrl+C。それまでのCPUは保存される）
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 育成1
# PCを軽くして育てる（同時に動かすゲームを4つにして、ほかの作業を先に動かす）
nice -n 19 /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 育成1 --games 4
# 続きから
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 育成1 --resume lab/rl/runs/育成1/latest.zip
# 育てているCPUと走る（画面あり。ゲームのレース選択→出走表の「レース開始」で始まる。あなた以外の席は育てるCPU）
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/play.py
# つなぎの確かめ（8席で2本）
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/check.py
# 脚質優先の版（脚質1）：初回は本命のCPUから始めて、上書きの設定を渡す。次からは --resume lab/rl/runs/脚質1/latest.zip だけでよい
nice -n 19 /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 脚質1 --games 2 --resume lab/rl/runs/育成1/latest.zip --override lab/rl/override_脚質.json
# 控え室の成績の表と、管理のアドバイス
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/pool.py
# 使った・外したお手本の記録の表
/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/demos.py
```

- 進み具合は `lab/rl/runs/育成1/progress.csv`（100レースごとに1行）。1時間ごとの版は `versions/`。
- 控え室の成績（相手役ごとに、本命より前を走った割合）と、管理のアドバイス：`python lab/rl/pool.py`。本命が古い版に勝ち越していけば、強くなっている。
