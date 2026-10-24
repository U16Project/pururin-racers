"""強化学習：育てているCPUと、人がいっしょに走る（画面あり・景色あり。ふつうのオフラインと同じ見た目）。

ゲームのレース選択の画面（ふつうのオフラインと同じ）で、子・枠・距離・相手のトレーナーを選んで「スタート」。
あなたの席はあなた。ほかの選んだ席は、育てているCPU（本命）が走らせる（席ごとに選んだトレーナーの性格を、CPUに伝える）。
そのうち rl_settings.json の pool.seats 席（--pool で変えられる）は、相手の控え室からくじで選んだCPUが走らせる。
本命は、レースを始めるたびに、その育成のいちばん新しいCPU（lab/rl/runs/<育成の名前>/latest.zip）を読み直す。
結果の板の「もう1回」で同じ内容の次のレース、「戻る」でレース選択の画面へ。画面を閉じると終わる。
あなたのレースは、ふつうのオフラインと同じく記録が残り、育成のお手本に自動で足される。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/play.py
  本命にする育成：--run 脚質1（書かなければ 育成1）
  控え室から走らせる席の数：--pool 0（書かなければ rl_settings.json の pool.seats）
"""

import argparse
import json
import random
import time

from sb3_contrib import MaskablePPO

from godot_env import CLIENT, RL_DIR, Godot, load_settings
from pool import Pool


def display_names() -> dict:
    """子の番号 → 名前（ヒカリ など）。"""
    with open(CLIENT / "data" / "config" / "pururin_roster.json", encoding="utf-8") as f:
        return {p["id"]: p["display_name"] for p in json.load(f)["roster"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", default="育成1")
    parser.add_argument("--pool", type=int, default=-1, help="控え室から走らせる席の数（-1なら rl_settings.json の pool.seats）")
    parser.add_argument("--shot", default="", help="確かめ用：この秒数で画面を撮って閉じる（秒,ファイル）")
    args = parser.parse_args()
    settings = load_settings()
    pool_seats = args.pool if args.pool >= 0 else int(settings["pool"]["seats"])
    model_path = RL_DIR / "runs" / args.run / "latest.zip"
    if not model_path.exists():
        raise SystemExit(f"育てたCPUがまだありません：{model_path}（train.py で育成を始めて、10分ほど待つ）")
    extra = []
    if args.shot:
        seconds, path = args.shot.split(",", 1)
        extra = [f"shot_after_s={seconds}", f"shot={path}"]
    godot = Godot(settings, 0, RL_DIR / "runs" / "play_logs", window=True, extra_args=["select=1", *extra])
    names = display_names()
    pool = Pool(settings)
    rng = random.Random()
    race_no = 0
    model = None
    by_gate = {}
    try:
        while True:
            message = godot.read()
            if "start" in message:
                # レースを始める：本命のいちばん新しいCPUを読み直し、控え室から走らせる席を、くじで決める。
                model = MaskablePPO.load(model_path, device="cpu")
                saved = time.strftime("%m/%d %H:%M", time.localtime(model_path.stat().st_mtime))
                spec = message["start"]
                pool.reload()
                seats = list(spec["seats"])
                rng.shuffle(seats)
                by_gate = {gate: pool.pick(rng) for gate in seats[:pool_seats]} if pool.names else {}
                race_no += 1
                print(f"レース {race_no}：{int(spec['distance_m'])}m、あなたは {spec['human_gate'] + 1} 枠。"
                      f"本命：{args.run} の {saved} 保存のCPU。控え室から {len(by_gate)} 席", flush=True)
                godot.send({"cmd": "reset", "spec": spec, "settings": settings})
            elif message.get("over"):
                for r in sorted(message["race"]["results"], key=lambda r: r["place"]):
                    who = "あなた" if r["human"] else (f"控え室：{by_gate[r['gate']]}" if r["gate"] in by_gate else "本命")
                    print(f"  {r['place']}位 {who}（{names.get(r['pururin'], r['pururin'])}）{r['time']:.2f} 秒", flush=True)
            elif "seats" in message:
                actions = {}
                for seat in message["seats"]:
                    gate = int(seat["gate"])
                    driver = pool.model(by_gate[gate]) if gate in by_gate else model
                    action, _ = driver.predict(seat["obs"], action_masks=seat["mask"], deterministic=True)
                    actions[str(gate)] = [int(a) for a in action]
                godot.send({"cmd": "step", "actions": actions})
    except RuntimeError:
        # 画面を閉じた（つながりが切れた）。
        print(f"ゲームの画面が閉じたので、終わりました（ゲームの出力：{godot.log_path}）", flush=True)
    finally:
        godot.close()


if __name__ == "__main__":
    main()
