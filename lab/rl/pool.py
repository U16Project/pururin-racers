"""強化学習：相手の控え室。保存したCPU（どの育成のものでも）を置いておき、レースの席の一部を走らせる。

- 置き場所：lab/rl/runs/控え室/（rl_settings.json の pool.dir）。.zip のCPUファイルを置けば相手役になる。消せば外れる。
- 育成中に1時間ごとに保存する版は、ここにも自動で入る（train.py）。
- 置くのは pool.max 体まで。超えたら、自動で入れた古いものから外す。名前の頭が「固定_」のものは外さない。
- 1レースのうち pool.seats 席を、ここからくじで選んだCPUが走らせる（走らせるだけで、学ばない）。
- 相手役ごとに、本命（育てているCPU）と走ったときの着順を記録する。育成ごとに別のファイル（_成績_<育成の名前>.json）。

成績の表と、管理のアドバイス：/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/pool.py
"""

import json
import random
from pathlib import Path

from godot_env import RL_DIR, load_settings

FIXED = "固定_"


class Pool:
    def __init__(self, settings: dict, run: str = ""):
        self.settings = settings["pool"]
        self.dir = RL_DIR / "runs" / self.settings["dir"]
        self.dir.mkdir(parents=True, exist_ok=True)
        self.stats_path = self.dir / f"_成績_{run}.json"
        self.stats = json.loads(self.stats_path.read_text(encoding="utf-8")) if self.stats_path.exists() else {}
        self._models = {}
        self.names = []
        self.reload()

    # ------------------------------------------------------------ 置き場所
    def reload(self) -> None:
        """フォルダを見直す（手で足した・消したファイルを反映する）。"""
        self.names = sorted(p.stem for p in self.dir.glob("*.zip"))
        # 読み込み済みのCPUは、今のレースで使っているかもしれないので、外されたものも少しだけ残す（数が増えすぎたら捨てる）。
        if len(self._models) > 2 * self.settings["max"]:
            self._models = {n: m for n, m in self._models.items() if n in self.names}

    def add(self, model, name: str) -> None:
        """育成の版を入れる。上限を超えたら、自動で入れた古いものから外す（固定_は外さない）。"""
        model.save(self.dir / f"{name}.zip")
        loose = sorted((p for p in self.dir.glob("*.zip") if not p.stem.startswith(FIXED)), key=lambda p: p.stat().st_mtime)
        total = len(list(self.dir.glob("*.zip")))
        while total > self.settings["max"] and loose:
            loose.pop(0).unlink()
            total -= 1
        self.reload()

    def pick(self, rng: random.Random):
        """相手役を1体くじで選び、その場で読み込んでおく（レースの途中でファイルが外されても困らないように）。
        控え室が空、または読み込めなかったら None（その席は本命が走る）。"""
        while self.names:
            name = rng.choice(self.names)
            if self.model(name) is not None:
                return name
            # ほかの育成が上限で外したなど、もうファイルがない。見直して、選び直す。
            self.reload()
        return None

    def model(self, name: str):
        """相手役のCPU（読み込めなければ None）。一度読んだものは、ファイルが外されても使える。"""
        if name not in self._models:
            from sb3_contrib import MaskablePPO
            path = self.dir / f"{name}.zip"
            try:
                self._models[name] = MaskablePPO.load(path, device="cpu")
            except (FileNotFoundError, OSError, ValueError):
                return None
        return self._models[name]

    # ------------------------------------------------------------ 成績
    def record(self, results: list, pool_gates: dict) -> None:
        """1レースの結果を記録する。pool_gates：枠 → 相手役の名前（本命が代わりに走った席は入れない）。"""
        mains = [r["place"] for r in results if r["gate"] not in pool_gates]
        for r in results:
            name = pool_gates.get(r["gate"])
            if name is None:
                continue
            s = self.stats.setdefault(name, {"races": 0, "place_sum": 0, "main_place_sum": 0, "main_count": 0, "beat": 0, "pairs": 0})
            s["races"] += 1
            s["place_sum"] += r["place"]
            s["main_place_sum"] += sum(mains)
            s["main_count"] += len(mains)
            s["beat"] += sum(1 for m in mains if r["place"] < m)
            s["pairs"] += len(mains)

    def save(self) -> None:
        self.stats_path.write_text(json.dumps(self.stats, ensure_ascii=False, indent=1), encoding="utf-8")


def report():
    settings = load_settings()
    pool = Pool(settings)
    print(f"控え室：{pool.dir}（{len(pool.names)}体／上限 {pool.settings['max']}）")
    files = sorted(pool.dir.glob("_成績_*.json"))
    if not files:
        print("まだ成績がありません。")
    for path in files:
        run = path.stem.removeprefix("_成績_")
        stats = json.loads(path.read_text(encoding="utf-8"))
        print()
        print(f"■ 本命＝{run}")
        print("相手役 | 固定 | レース数 | 相手役の平均着順 | 本命の平均着順 | 相手役が本命より前だった割合")
        rows = []
        for name in pool.names:
            s = stats.get(name)
            if not s or s["races"] == 0 or name.startswith(run + "_"):
                continue
            beat = s["beat"] / max(s["pairs"], 1)
            rows.append((name, s["races"], beat))
            print(f"{name} | {'○' if name.startswith(FIXED) else ''} | {s['races']} | {s['place_sum'] / s['races']:.2f} | "
                  f"{s['main_place_sum'] / max(s['main_count'], 1):.2f} | {beat:.2f}")
        own = [(n, stats[n]["races"], stats[n]["beat"] / max(stats[n]["pairs"], 1)) for n in pool.names
               if n.startswith(run + "_") and n in stats and stats[n]["races"] > 0]
        if own:
            print("（自分の古い版）")
            for name, races, beat in own:
                print(f"{name} | {'○' if name.startswith(FIXED) else ''} | {races} | - | - | {beat:.2f}")
        print("アドバイス：")
        for line in advice(pool, own, rows):
            print(" ・" + line)


def advice(pool: Pool, own: list, others: list) -> list:
    """表から読める、今の管理のおすすめ。own＝自分の古い版、others＝ほかの育成の版。"""
    out = []
    if len(pool.names) < 3:
        out.append("控え室がまだ少ない。育成を続ければ、1時間ごとに版が増える。")
    for name, races, beat in own + others:
        if races >= 30 and beat > 0.5 and not name.startswith(FIXED):
            out.append(f"{name} は本命より前を走ることが多い（{beat:.0%}）。手ごわい相手なので、名前の頭に「固定_」を付けて残すとよい。")
    enough = [r for r in own if r[1] >= 30]
    if len(enough) >= 3:
        oldest, newest = enough[0], enough[-1]
        if oldest[2] > 0.4:
            out.append(f"本命が、自分のいちばん古い版（{oldest[0]}）にも、あまり勝ち越せていない（相手役が前の割合 {oldest[2]:.0%}）。伸びが止まっているかもしれない。")
        elif newest[2] < 0.3:
            out.append("本命は、自分の新しい版にも勝ち越している。順調に強くなっている。")
    runs = {n.removeprefix(FIXED).split("_")[0] for n in pool.names}
    if len(runs) == 1 and len(pool.names) >= 3:
        out.append("控え室が1つの育成の版だけ。脚質を重く見た版など、違う育て方の版を足すと、相手の走りの幅が広がる。")
    if not out:
        out.append("今は特に手を入れなくてよい。")
    return out


if __name__ == "__main__":
    report()
