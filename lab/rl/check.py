"""強化学習：つなぎの確かめ（育てる前のCPUで、8席全部を走らせる）。

- 同じくじの番号で2本走らせる。操作はくじ（番号を固定）で選ぶ。
- 8席とも走り切るか、見たものの並びの長さが毎回同じか、ブーストの残り0のとき選べなくなっているか、2本が同じ結果か。

使い方：/media/u16/Backup/pururin-rl-venv/bin/python lab/rl/check.py
"""

import time

import numpy as np

from godot_env import GodotVecEnv, load_settings

## 見るものの並びで、ブーストの残りがある場所（rl_observe.gd の順：レースと流れの24個のあと、自分の値の7番目）。
BOOST_LEFT = 24 + 6


def run_one(env, action_seed):
    rng = np.random.default_rng(action_seed)
    obs = env.reset()
    sizes = env.action_sizes
    lengths = {obs.shape[1]}
    boost_zero = boost_zero_allowed = steps = 0
    total = np.zeros(env.num_envs)
    while True:
        masks = env.action_masks()
        actions = []
        for k in range(env.num_envs):
            row, offset = [], 0
            for n in sizes:
                allowed = np.flatnonzero(masks[k][offset:offset + n])
                row.append(int(rng.choice(allowed)))
                offset += n
            actions.append(row)
        obs, rewards, dones, infos = env.step(np.array(actions))
        total += rewards
        steps += 1
        lengths.add(obs.shape[1])
        if dones.any():
            return env.races[-1], lengths, total, steps, (boost_zero, boost_zero_allowed)
        zero = obs[:, BOOST_LEFT] == 0.0
        boost_zero += int(zero.sum())
        boost_zero_allowed += int((env.action_masks()[:, -1] & zero).sum())


def main():
    settings = load_settings()
    env = GodotVecEnv(settings, workers=1, seeds=[42, 42, 42])
    print("席の数:", env.num_envs, " 見るものの長さ:", env.obs_size, " 操作:", env.action_sizes)
    results = []
    for n in range(2):
        t = time.time()
        race, lengths, total, steps, boost = run_one(env, 7)
        results.append(race)
        print(f"{n + 1}本目（{time.time() - t:.1f}秒、判断 {steps}回、レース {race['race_s']:.1f}秒、打ち切り {race['cut']}）")
        print("  並びの長さの種類:", lengths, " ブースト残り0の判断:", boost[0], "回 / そのうち選べた:", boost[1], "回")
        print("  枠 | ぷるりん | 着順 | タイム | ダッシュ | ブースト | 点の合計")
        for r in sorted(race["results"], key=lambda r: r["place"]):
            print(f"  {r['gate']} | {r['pururin']} | {r['place']} | {r['time']:.2f} | {r['dash_uses']} | {r['boost_uses']} | {total[r['gate']]:.3f}")
    same = [(a["place"], a["time"]) for a in results[0]["results"]] == [(b["place"], b["time"]) for b in results[1]["results"]]
    print("2本が同じ結果か:", same)
    env.close()


if __name__ == "__main__":
    main()
