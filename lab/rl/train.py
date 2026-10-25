"""強化学習：画面なしのゴドーを何本か同時に動かして、育てるCPUを育てる（PPO。使えない操作を外せる版）。

1レース8席すべてを、育てるCPUが走らせる（自分どうしの対戦）。出る8体は、レースごとに10体からくじで選ぶ。
どの子をどの育てるCPUが受け持つかは rl_settings.json の brains に書く（今は「共通」1つが10体全部）。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/train.py --name 育成1
  止めるときは Ctrl+C（それまでのCPUは保存される）。続きから：--resume lab/rl/runs/育成1/latest.zip
  あなたの記録（お手本）を使わずに育てる：--no-demos
  育成ごとに設定の一部を変える：--override lab/rl/override_脚質.json（初回だけ書けばよい。runs/<名前>/override.json に写し、次からは自動で使う）
  ほかの育成のCPUから始める：--resume lab/rl/runs/育成1/latest.zip --name 脚質1
  同時に動かすゲームの数：--games 4（書かなければ rl_settings.json の workers。少ないほどPCは軽く、育つのは遅い）

記録は lab/rl/runs/<名前>/ に書く：
  progress.csv＝進み具合（決めた本数ごとに1行）
  latest.zip＝今のCPU（決めた分ごとに上書き。人と走る play.py は、これを相手にする）
  versions/<日時>.zip＝決めた時間ごとに保存した版。同じものを相手の控え室（runs/控え室/）にも入れる
1レースのうち rl_settings.json の pool.seats 席は、控え室のCPUが走らせる（成績の表：python lab/rl/pool.py）。
"""

import argparse
import csv
import json
import time
from collections import deque
from pathlib import Path
from datetime import datetime

from sb3_contrib import MaskablePPO
from stable_baselines3.common.callbacks import BaseCallback

import demos
from godot_env import RL_DIR, GodotVecEnv, load_settings
from pool import Pool


class Progress(BaseCallback):
    """レースが終わるたびに結果を集めて、決めた本数ごとに progress.csv へ書く。決めた時間ごとに版を保存する。"""

    def __init__(self, run_dir, settings, bank=None, pool=None, name=""):
        super().__init__()
        self.run_dir = run_dir
        self.pool = pool
        self.name = name
        self.settings = settings
        self.bank = bank
        self.every = settings["train"]["report_every_races"]
        self.save_every_s = settings["train"]["save_version_every_min"] * 60
        self.latest_every_s = settings["train"]["save_latest_every_min"] * 60
        self.next_reload = settings["demo"]["reload_every_steps"]
        self.recent = deque(maxlen=self.every)
        self.seen = 0
        self.imitation = 0.0
        self.started = self.last_save = self.last_latest = time.time()
        (run_dir / "versions").mkdir(exist_ok=True)
        self.csv_path = run_dir / "progress.csv"
        # 前の形の progress.csv（項目が少ない）なら、見出しの行だけ、今の形に書き直す。
        if self.csv_path.exists():
            lines = self.csv_path.read_text(encoding="utf-8").splitlines()
            if lines and "風よけをもらっていた割合" not in lines[0]:
                lines[0] += ",ブーストの残り距離の平均,スパートの範囲で押したブースト,風よけをもらっていた割合"
                self.csv_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        if not self.csv_path.exists():
            with open(self.csv_path, "w", newline="", encoding="utf-8") as f:
                csv.writer(f).writerow(["日時", "判断の数", "レース数", "分", "1位のタイム", "ゴールしなかった割合", "ダッシュ", "ブースト",
                                        "残り体力", "性格の順位に合った割合", "風よけが性格に合った割合", "お手本の本数", "お手本に寄せる力", "お手本と合う見込み",
                                        "ブーストの残り距離の平均", "スパートの範囲で押したブースト", "風よけをもらっていた割合"])

    def _on_rollout_end(self) -> None:
        """CPUを直す前に、お手本にも少し寄せる。決めた判断の数ごとに、新しい記録を読み直す。"""
        if self.bank is None:
            return
        if self.num_timesteps >= self.next_reload:
            # 続きから始めたときも、今の判断の数から数える（取り戻そうとして、続けて読み直さないように）。
            self.next_reload = self.num_timesteps + self.settings["demo"]["reload_every_steps"]
            print(demos.refresh(self.settings), flush=True)
            self.bank.load()
        self.imitation = self.bank.imitate(self.model.policy, self.settings["demo"]["keep_batches"], self.bank.keep_weight(self.num_timesteps))

    def _on_step(self) -> bool:
        races = self.training_env.races
        while self.seen < len(races):
            self.recent.append(races[self.seen])
            self.seen += 1
            if self.seen % self.every == 0:
                self._write()
        if time.time() - self.last_latest >= self.latest_every_s:
            self.last_latest = time.time()
            self.model.save(self.run_dir / "latest.zip")
        if time.time() - self.last_save >= self.save_every_s:
            self.last_save = time.time()
            stamp = datetime.now().strftime("%Y%m%d_%H%M")
            self.model.save(self.run_dir / "versions" / stamp)
            if self.pool is not None:
                self.pool.add(self.model, f"{self.name}_{stamp}")
        return True

    def _write(self):
        if self.pool is not None:
            # 成績を書き出し、手で足した・消した相手役を反映する。
            self.pool.save()
            self.pool.reload()
        races = list(self.recent)
        seats = [r for race in races for r in race["results"] if r["seat"]]
        mean = lambda rows, key: sum(float(r[key]) for r in rows) / max(len(rows), 1)
        winners = [race["results"][0]["winner_time"] for race in races if race["results"][0]["winner_time"] > 0]
        line = [datetime.now().strftime("%m/%d %H:%M"), self.num_timesteps, self.seen, round((time.time() - self.started) / 60, 1),
                round(sum(winners) / max(len(winners), 1), 2), round(sum(1 for r in seats if r["time"] < 0) / max(len(seats), 1), 3),
                round(mean(seats, "dash_uses"), 1), round(mean(seats, "boost_uses"), 2), round(mean(seats, "stamina_left"), 2),
                round(mean(seats, "place_fit"), 2), round(mean(seats, "draft_fit"), 2),
                self.bank.races if self.bank else 0, round(self.bank.keep_weight(self.num_timesteps), 4) if self.bank else 0.0, round(self.imitation, 3),
                round(sum(sum(r["boost_remaining_m"]) for r in seats) / max(sum(len(r["boost_remaining_m"]) for r in seats), 1)),
                round(mean(seats, "spurt_hits"), 2), round(mean(seats, "draft_share"), 2)]
        with open(self.csv_path, "a", newline="", encoding="utf-8") as f:
            csv.writer(f).writerow(line)
        print(" | ".join(f"{k} {v}" for k, v in zip(["", "判断", "レース", "分", "1位のタイム", "ゴールしない", "ダッシュ", "ブースト", "残り体力",
                                                      "性格の順位", "性格の風よけ", "お手本", "寄せる力", "合う見込み",
                                                      "ブーストの残り距離", "スパートで押した", "風よけ割合"], line)), flush=True)


def merge(base: dict, extra: dict) -> dict:
    """設定 base に、extra の値を上書きする（入れ子の中も）。"""
    out = dict(base)
    for key, value in extra.items():
        out[key] = merge(out[key], value) if isinstance(value, dict) and isinstance(out.get(key), dict) else value
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--steps", type=int, default=1_000_000_000, help="判断の数の上限（ふつうは Ctrl+C で止める）")
    parser.add_argument("--resume", default="")
    parser.add_argument("--no-demos", action="store_true")
    parser.add_argument("--games", type=int, default=0, help="同時に動かすゲームの数（0なら rl_settings.json の workers）")
    parser.add_argument("--override", default="", help="この育成だけ上書きする設定のファイル（初回だけ）")
    args = parser.parse_args()

    settings = load_settings()
    run_dir = RL_DIR / "runs" / args.name
    run_dir.mkdir(parents=True, exist_ok=True)
    # この育成だけの上書き：初回に渡されたものを写しておき、次からは自動で使う。
    override_path = run_dir / "override.json"
    if args.override:
        override_path.write_text(Path(args.override).read_text(encoding="utf-8"), encoding="utf-8")
    if override_path.exists():
        settings = merge(settings, json.loads(override_path.read_text(encoding="utf-8")))
        print(f"この育成だけの設定の上書き：{override_path}", flush=True)
    if len([k for k in settings["brains"] if not k.startswith("_")]) != 1:
        raise SystemExit("今は、育てるCPUを1つ（brains に1つ）だけ育てられます。分けて育てる仕組みは、まだ作っていません。")
    with open(run_dir / "settings.json", "w", encoding="utf-8") as f:
        json.dump(settings, f, ensure_ascii=False, indent=2)
    pool = Pool(settings, args.name)
    env = GodotVecEnv(settings, workers=args.games or settings["workers"], log_dir=run_dir / "logs", pool=pool)
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
    env.main_model = model
    bank = None
    if not args.no_demos:
        print(demos.refresh(settings), flush=True)
        bank = demos.DemoBank(settings).load()
        print(f"お手本：{bank.races}本（{len(bank.obs)}場面）、寄せる強さ {bank.strength():.2f}", flush=True)
        if not args.resume:
            batches = int(settings["demo"]["pretrain_batches"] * bank.strength())
            match = bank.imitate(model.policy, batches, 1.0)
            print(f"育て始めのまね：{batches}回、お手本と同じ操作を選ぶ見込み {match:.3f}", flush=True)
    try:
        model.learn(total_timesteps=args.steps, callback=Progress(run_dir, settings, bank, pool, args.name), reset_num_timesteps=not args.resume)
    except KeyboardInterrupt:
        print("止めました", flush=True)
    finally:
        model.save(run_dir / "latest.zip")
        pool.save()
        env.close()


if __name__ == "__main__":
    main()
