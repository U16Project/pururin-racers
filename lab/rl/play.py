"""強化学習：育てているCPUと、人がいっしょに走る・CPUだけのレースを観戦する（画面あり・景色あり。ふつうのオフラインと同じ見た目）。

起動すると、まず「CPUを選ぶ画面」が出る。
  いちばん上の行は、あなたの枠（レース選択で自分にした枠）。最初は「あなた」。CPUにすると観戦。
  その下の相手1〜7の行は、レース選択で決まった相手の枠に、枠の順に当てはめる。最初は7枠とも本採用。
  選べるCPU：runs/保存/ の本採用（本採用_名前.zip。ゲームのCPUと同じ）と、控え（控え_名前.zip）だけ。
決定すると、ゲームのレース選択の画面（ふつうのオフラインと同じ）→ 出走表の「レース開始」でレース。
レース中・結果の板のトレーナー欄には、その枠を走らせているCPUの名前が出る。
結果の板の「もう1回」で同じ内容の次のレース、「戻る」でCPUを選ぶ画面へ。画面を閉じると終わる。
あなたのレースは、ふつうのオフラインと同じく記録が残り、育成のお手本に自動で足される。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/play.py
"""

import argparse
import json

from sb3_contrib import MaskablePPO

from godot_env import CLIENT, RL_DIR, Godot, load_settings

RUNS = RL_DIR / "runs"


def display_names() -> dict:
    """子の番号 → 名前（ヒカリ など）。"""
    with open(CLIENT / "data" / "config" / "pururin_roster.json", encoding="utf-8") as f:
        return {p["id"]: p["display_name"] for p in json.load(f)["roster"]}


SAVED = RUNS / "保存"
OPPONENTS = 7


def choices() -> list:
    """選べるCPUの一覧：本採用（いちばん上）と、控え（名前の順）。id は「saved:名前」、ファイルは runs/保存/本採用_名前.zip・控え_名前.zip。"""
    items = []
    for kind in ("本採用", "控え"):
        for p in sorted(SAVED.glob(f"{kind}_*.zip")):
            name = p.stem.split("_", 1)[1]
            items.append({"id": f"saved:{name}", "label": f"{name}（{kind}）", "path": str(p)})
    return items


class Drivers:
    """CPUの id → 読み込んだCPU（1度読んだら使い回す）。"""

    def __init__(self, items: list):
        self._paths = {item["id"]: item["path"] for item in items}
        self._loaded = {}

    def get(self, driver_id: str):
        if driver_id not in self._loaded:
            self._loaded[driver_id] = MaskablePPO.load(self._paths[driver_id], device="cpu")
        return self._loaded[driver_id]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shot", default="", help="確かめ用：この秒数で画面を撮って閉じる（秒,ファイル）")
    args = parser.parse_args()
    settings = load_settings()
    items = choices()
    if not items:
        raise SystemExit("runs/保存/ に、本採用・控えのCPUがありません")
    defaults = [items[0]["id"]] * OPPONENTS
    extra = []
    if args.shot:
        seconds, path = args.shot.split(",", 1)
        extra = [f"shot_after_s={seconds}", f"shot={path}"]
    godot = Godot(settings, 0, RL_DIR / "runs" / "play_logs", window=True, extra_args=["select=1", *extra])
    godot.send({"cmd": "choices", "items": [{"id": i["id"], "label": i["label"]} for i in items], "defaults": defaults})
    names = display_names()
    drivers = Drivers(items)
    race_no = 0
    by_gate = {}
    labels = {}
    try:
        while True:
            message = godot.read()
            if "start" in message:
                spec = message["start"]
                by_gate = {int(g): d for g, d in spec.get("drivers", {}).items()}
                labels = {int(g): l for g, l in spec.get("labels", {}).items()}
                for d in set(by_gate.values()):
                    drivers.get(d)
                race_no += 1
                who = "あなたは %d 枠" % (spec["human_gate"] + 1) if spec["human_gate"] >= 0 else "観戦（%d 枠を追う）" % (spec["watch_gate"] + 1)
                print(f"レース {race_no}：{int(spec['distance_m'])}m、{who}", flush=True)
                for gate in sorted(by_gate):
                    print(f"  {gate + 1}枠 {names.get(spec['lineup'][gate], spec['lineup'][gate])}：{labels[gate]}", flush=True)
                godot.send({"cmd": "reset", "spec": spec, "settings": settings})
            elif message.get("over"):
                for r in sorted(message["race"]["results"], key=lambda r: r["place"]):
                    who = "あなた" if r["human"] else labels.get(r["gate"], "CPU")
                    print(f"  {r['place']}位 {names.get(r['pururin'], r['pururin'])}（{who}）{r['time']:.2f} 秒", flush=True)
            elif "seats" in message:
                actions = {}
                for seat in message["seats"]:
                    gate = int(seat["gate"])
                    model = drivers.get(by_gate.get(gate, items[0]["id"]))
                    action, _ = model.predict(seat["obs"], action_masks=seat["mask"], deterministic=True)
                    actions[str(gate)] = [int(a) for a in action]
                godot.send({"cmd": "step", "actions": actions})
    except RuntimeError:
        # 画面を閉じた（つながりが切れた）。
        print(f"ゲームの画面が閉じたので、終わりました（ゲームの出力：{godot.log_path}）", flush=True)
    finally:
        godot.close()


if __name__ == "__main__":
    main()
