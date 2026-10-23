"""強化学習：画面なしのゴドーを何本か同時に動かして、頭を育てる（PPO。使えない操作を外せる版）。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 試し1 --steps 2000000
  続きから：--resume lab/rl/runs/試し1/latest.zip
  お手本（あなたの走りの記録）なしで育てる：--no-demos

記録は lab/rl/runs/<名前>/ に書く（progress.csv＝進み具合、latest.zip＝今の頭、step_<数>.zip＝途中の頭）。
"""

import argparse
import csv
import functools
import json
import time
from collections import deque

from sb3_contrib import MaskablePPO
from stable_baselines3.common.callbacks import BaseCallback
from stable_baselines3.common.vec_env import SubprocVecEnv, VecMonitor

import demos
from godot_env import RL_DIR, GodotRaceEnv, load_settings


def make_env(settings, index, log_dir):
    return GodotRaceEnv(settings, index=index, log_dir=log_dir)


class Progress(BaseCallback):
    """レースが終わるたびに着順を集めて、決めた本数ごとに progress.csv へ書く。途中の頭も残す。"""

    def __init__(self, run_dir, bank=None, settings=None, every_races=200, save_every_steps=250_000):
        super().__init__()
        self.bank = bank
        self.settings = settings
        self.next_reload = settings["demo"]["reload_every_steps"] if settings else 0
        self.imitation = 0.0
        self.run_dir = run_dir
        self.every_races = every_races
        self.save_every_steps = save_every_steps
        self.recent = deque(maxlen=every_races)
        self.races = 0
        self.next_save = save_every_steps
        self.started = time.time()
        self.csv_path = run_dir / "progress.csv"
        if not self.csv_path.exists():
            with open(self.csv_path, "w", newline="", encoding="utf-8") as f:
                csv.writer(f).writerow(["steps", "races", "minutes", "win_rate", "avg_place", "mid_place", "dash", "boost", "stamina_left", "demo_races", "demo_weight", "demo_match"])

    def _on_rollout_end(self) -> None:
        """頭を直す前に、お手本にも少し寄せる。決めた判断の数ごとに、新しい記録を読み直す。"""
        if self.bank is None:
            return
        if self.num_timesteps >= self.next_reload:
            self.next_reload += self.settings["demo"]["reload_every_steps"]
            print(demos.refresh(self.settings), flush=True)
            self.bank.load()
        weight = self.bank.keep_weight(self.num_timesteps)
        self.imitation = self.bank.imitate(self.model.policy, self.settings["demo"]["keep_batches"], weight)

    def _on_step(self) -> bool:
        for info, done in zip(self.locals["infos"], self.locals["dones"]):
            if done and "place" in info:
                self.recent.append(info)
                self.races += 1
                if self.races % self.every_races == 0:
                    self._write()
        if self.num_timesteps >= self.next_save:
            self.next_save += self.save_every_steps
            self.model.save(self.run_dir / f"step_{self.num_timesteps}.zip")
            self.model.save(self.run_dir / "latest.zip")
        return True

    def _write(self):
        rows = list(self.recent)
        n = len(rows)
        mean = lambda key: sum(float(r[key]) for r in rows) / n
        line = [self.num_timesteps, self.races, round((time.time() - self.started) / 60, 1),
                round(sum(1 for r in rows if r["place"] == 1) / n, 3), round(mean("place"), 2), round(mean("mid_place"), 2),
                round(mean("dash_uses"), 1), round(mean("boost_uses"), 2), round(mean("stamina_left"), 2),
                self.bank.races if self.bank else 0, round(self.bank.keep_weight(self.num_timesteps), 4) if self.bank else 0.0, round(self.imitation, 3)]
        with open(self.csv_path, "a", newline="", encoding="utf-8") as f:
            csv.writer(f).writerow(line)
        print("steps {} races {} min {} | 1位 {} 平均着順 {} 中ほど {} | ダッシュ {} ブースト {} 残り体力 {} | お手本 {}本 寄せる力 {} 合う見込み {}".format(*line), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--steps", type=int, default=2_000_000)
    parser.add_argument("--resume", default="")
    parser.add_argument("--no-demos", action="store_true")
    args = parser.parse_args()

    settings = load_settings()
    run_dir = RL_DIR / "runs" / args.name
    run_dir.mkdir(parents=True, exist_ok=True)
    with open(run_dir / "settings.json", "w", encoding="utf-8") as f:
        json.dump(settings, f, ensure_ascii=False, indent=2)
    log_dir = run_dir / "logs"
    env = VecMonitor(SubprocVecEnv([functools.partial(make_env, settings, i, log_dir) for i in range(settings["workers"])]))
    ppo = settings["ppo"]
    if args.resume:
        model = MaskablePPO.load(args.resume, env=env, device="cuda")
    else:
        model = MaskablePPO(
            "MlpPolicy", env, device="cuda", verbose=0, seed=0,
            learning_rate=ppo["learning_rate"], n_steps=ppo["n_steps"], batch_size=ppo["batch_size"], n_epochs=ppo["n_epochs"],
            gamma=ppo["gamma"], gae_lambda=ppo["gae_lambda"], ent_coef=ppo["ent_coef"],
            policy_kwargs={"net_arch": {"pi": ppo["net"], "vf": ppo["net"]}},
        )
    bank = None
    if not args.no_demos:
        print(demos.refresh(settings), flush=True)
        bank = demos.DemoBank(settings).load()
        print(f"お手本：{bank.races}本（{len(bank.obs)}場面）、寄せる強さ {bank.strength():.2f}", flush=True)
        if not args.resume:
            batches = int(settings["demo"]["pretrain_batches"] * bank.strength())
            match = bank.imitate(model.policy, batches, 1.0)
            print(f"学び始めのまね：{batches}回、お手本と同じ操作を選ぶ見込み {match:.3f}", flush=True)
    try:
        model.learn(total_timesteps=args.steps, callback=Progress(run_dir, bank, settings), reset_num_timesteps=not args.resume)
    finally:
        model.save(run_dir / "latest.zip")
        env.close()


if __name__ == "__main__":
    main()
