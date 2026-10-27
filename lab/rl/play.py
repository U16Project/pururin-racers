"""強化学習：育てているCPUと、人がいっしょに走る・CPUだけのレースを観戦する（画面あり・景色あり。ふつうのオフラインと同じ見た目）。

起動すると、まず「CPUを選ぶ画面」が出る。
  いちばん上の行は、あなたの枠（レース選択で自分にした枠）。最初は「あなた」。CPUにすると観戦。
  その下の相手1〜7の行は、レース選択で決まった相手の枠に、枠の順に当てはめる。最初は --seats の並び（書かなければ 本番4 の最新が7枠）。
  選べるCPU：--seats に書いた育成の最新と、その育成の過去の版（runs/<育成>/versions/。30分ごとに保存されたもの。新しい順）だけ。
  --seats の育成にまだ最新が無いときは、一覧の最初のCPUが相手になる。
決定すると、ゲームのレース選択の画面（ふつうのオフラインと同じ）→ 出走表の「レース開始」でレース。
レース中・結果の板のトレーナー欄には、その枠を走らせているCPUの名前が出る。
「最新」を選んだ枠は、レースを始めるたびに、その育成のいちばん新しいCPUを読み直す。
結果の板の「もう1回」で同じ内容の次のレース、「戻る」でCPUを選ぶ画面へ。画面を閉じると終わる。
あなたのレースは、ふつうのオフラインと同じく記録が残り、育成のお手本に自動で足される。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/play.py
  相手の最初の選び方：--seats 本番4:5,本番3:2（育成の名前:枠の数、を上から順に。合わせて7枠。足りない枠と、まだ最新が無い育成の枠は、一覧の最初のCPU）
"""

import argparse
import json
import time

from sb3_contrib import MaskablePPO

from godot_env import CLIENT, RL_DIR, Godot, load_settings

RUNS = RL_DIR / "runs"


def display_names() -> dict:
    """子の番号 → 名前（ヒカリ など）。"""
    with open(CLIENT / "data" / "config" / "pururin_roster.json", encoding="utf-8") as f:
        return {p["id"]: p["display_name"] for p in json.load(f)["roster"]}


def choices(runs: list) -> list:
    """選べるCPUの一覧：runs の育成の最新（latest.zip があるもの）と、その育成の過去の版（新しい順）。
    id は「run:育成の名前」か「ver:育成の名前/版の名前（20261027_2240 など）」。"""
    items = [{"id": f"run:{r}", "label": f"{r}・最新"} for r in runs if (RUNS / r / "latest.zip").exists()]
    for r in runs:
        for p in sorted((RUNS / r / "versions").glob("*.zip"), reverse=True):
            items.append({"id": f"ver:{r}/{p.stem}", "label": f"{r} {p.stem[4:6]}/{p.stem[6:8]} {p.stem[9:11]}:{p.stem[11:13]}"})
    return items


class Drivers:
    """CPUの id → 読み込んだCPU。育成の最新は、ファイルが新しくなっていたら読み直す。"""

    def __init__(self):
        self._latest = {}
        self._versions = {}

    def get(self, driver_id: str):
        kind, _, name = driver_id.partition(":")
        if kind == "ver":
            if name not in self._versions:
                run, _, stamp = name.partition("/")
                self._versions[name] = MaskablePPO.load(RUNS / run / "versions" / f"{stamp}.zip", device="cpu")
            return self._versions[name]
        path = RUNS / name / "latest.zip"
        mtime = path.stat().st_mtime if path.exists() else 0.0
        cached = self._latest.get(name)
        if cached is None or cached[0] != mtime:
            try:
                self._latest[name] = (mtime, MaskablePPO.load(path, device="cpu"))
            except Exception:
                # 書き込みの途中など。前に読んだものを使い続ける。
                if cached is None:
                    return None
        return self._latest[name][1]

    def saved_at(self, driver_id: str) -> str:
        kind, _, name = driver_id.partition(":")
        if kind != "run" or name not in self._latest:
            return ""
        return time.strftime("%m/%d %H:%M", time.localtime(self._latest[name][0]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seats", default="本番4:7")
    parser.add_argument("--shot", default="", help="確かめ用：この秒数で画面を撮って閉じる（秒,ファイル）")
    args = parser.parse_args()
    settings = load_settings()
    seats = [(run, int(count)) for run, count in (part.split(":") for part in args.seats.split(","))]
    defaults = [f"run:{run}" for run, count in seats for _ in range(count)]
    items = choices(list(dict.fromkeys(run for run, _ in seats)))
    if not items:
        raise SystemExit("育てたCPUがまだありません（train.py で育成を始めて、10分ほど待つ）")
    extra = []
    if args.shot:
        seconds, path = args.shot.split(",", 1)
        extra = [f"shot_after_s={seconds}", f"shot={path}"]
    godot = Godot(settings, 0, RL_DIR / "runs" / "play_logs", window=True, extra_args=["select=1", *extra])
    godot.send({"cmd": "choices", "items": items, "defaults": defaults})
    names = display_names()
    drivers = Drivers()
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
                    saved = drivers.saved_at(by_gate[gate])
                    print(f"  {gate + 1}枠 {names.get(spec['lineup'][gate], spec['lineup'][gate])}：{labels[gate]}" + (f"（{saved} 保存）" if saved else ""), flush=True)
                godot.send({"cmd": "reset", "spec": spec, "settings": settings})
            elif message.get("over"):
                for r in sorted(message["race"]["results"], key=lambda r: r["place"]):
                    who = "あなた" if r["human"] else labels.get(r["gate"], "CPU")
                    print(f"  {r['place']}位 {names.get(r['pururin'], r['pururin'])}（{who}）{r['time']:.2f} 秒", flush=True)
            elif "seats" in message:
                actions = {}
                for seat in message["seats"]:
                    gate = int(seat["gate"])
                    model = drivers.get(by_gate.get(gate, items[0]["id"])) or drivers.get(items[0]["id"])
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
