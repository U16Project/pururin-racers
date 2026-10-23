"""強化学習：比べる（合格の目安）。学ぶのに使っていないくじの番号のレースを、同じ番号どうしで走らせて比べる。

使い方（リポジトリのいちばん上で）：
  今のゲームのCPU：   python lab/rl/evaluate.py --who cpu
  学ぶ前（育てる前）： python lab/rl/evaluate.py --who untrained
  育てた頭：          python lab/rl/evaluate.py --who lab/rl/runs/試し1/latest.zip
結果は lab/rl/runs/eval/<名前>.json に書き、表を出す。
"""

import argparse
import json
from multiprocessing import Pool
from pathlib import Path

from godot_env import RL_DIR, GodotRaceEnv, load_settings


def _run_part(job):
    who, seeds, index, overrides = job
    settings = {**load_settings(), **overrides}
    env = GodotRaceEnv(settings, index=100 + index, seeds=seeds, log_dir=RL_DIR / "runs" / "eval" / "logs")
    rows = []
    try:
        if who == "cpu":
            rows = [env.run_baseline(s) for s in seeds]
        else:
            from sb3_contrib import MaskablePPO
            if who == "untrained":
                ppo = settings["ppo"]
                model = MaskablePPO("MlpPolicy", env, device="cpu", seed=0, policy_kwargs={"net_arch": {"pi": ppo["net"], "vf": ppo["net"]}})
            else:
                model = MaskablePPO.load(who, device="cpu")
            for s in seeds:
                obs, _ = env.reset(options={"race_seed": s})
                while True:
                    action, _ = model.predict(obs, action_masks=env.action_masks(), deterministic=True)
                    obs, _, done, _, info = env.step(action)
                    if done:
                        rows.append(info)
                        break
    finally:
        env.close()
    return rows


def summarize(rows):
    n = len(rows)
    mean = lambda key: sum(float(r[key]) for r in rows) / n
    mid = [sum(1 for r in rows if r["mid_place"] == p) for p in range(1, 9)]
    return {
        "races": n, "win_rate": sum(1 for r in rows if r["place"] == 1) / n, "avg_place": mean("place"),
        "top3_rate": sum(1 for r in rows if r["place"] <= 3) / n, "mid_place_counts": mid,
        "dash": mean("dash_uses"), "boost": mean("boost_uses"), "stamina_left": mean("stamina_left"),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--who", required=True, help="cpu / untrained / 頭のファイル")
    parser.add_argument("--label", default="")
    parser.add_argument("--trainee", default="", help="rl_settings の trainee を、この時だけ変える")
    parser.add_argument("--distances", default="", help="rl_settings の distances_m を、この時だけ変える（例：1200,3000）")
    args = parser.parse_args()
    overrides = {}
    if args.trainee:
        overrides["trainee"] = args.trainee
    if args.distances:
        overrides["distances_m"] = [int(x) for x in args.distances.split(",")]
    settings = {**load_settings(), **overrides}
    first = settings["seeds"]["eval_from"]
    seeds = list(range(first, first + settings["seeds"]["eval_races"]))
    workers = settings["workers"]
    who = args.who if args.who in ("cpu", "untrained") else str(Path(args.who).resolve())
    with Pool(workers) as pool:
        parts = pool.map(_run_part, [(who, seeds[i::workers], i, overrides) for i in range(workers)])
    rows = sorted([r for part in parts for r in part], key=lambda r: r["seed"])
    summary = summarize(rows)
    label = args.label or (args.who if args.who in ("cpu", "untrained") else Path(args.who).parent.name + "_" + Path(args.who).stem)
    out = RL_DIR / "runs" / "eval" / f"{label}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"who": args.who, "summary": summary, "rows": rows}, f, ensure_ascii=False, indent=1)
    s = summary
    print(f"{label}: {s['races']}本 | 1位 {s['win_rate']:.3f} | 3位以内 {s['top3_rate']:.3f} | 平均の着順 {s['avg_place']:.2f} | "
          f"ダッシュ {s['dash']:.1f} ブースト {s['boost']:.2f} 残り体力 {s['stamina_left']:.2f}")
    print("中ほどの順位（1〜8位の本数）:", s["mid_place_counts"])
    winners = {}
    for r in rows:
        if r.get("winner_time", -1.0) > 0.0:
            winners.setdefault(int(r["distance_m"]), []).append(r["winner_time"])
    if winners:
        print("1位のタイムの平均（距離ごと）:", {d: round(sum(v) / len(v), 2) for d, v in sorted(winners.items())})


if __name__ == "__main__":
    main()
