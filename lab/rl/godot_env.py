"""強化学習：画面なしのゴドーを何本か同時に動かし、その中の育てるCPUの席を全部まとめて、学習の場として扱う。

ゴドー1本（rl_worker.gd）＝レース1本。8席全部が育てるCPUなら、ゴドー8本で 8×8＝64 席を同時に動かす。
ゴドーとは、このPCの中の通信で、1行に1つの JSON を送り合う。
1席＝学習の場の1つ。レースが終わると、その8席はそろって終わり、すぐ次のレースが始まる。
"""

import json
import os
import random
import socket
import subprocess
from pathlib import Path

import gymnasium as gym
import numpy as np
from stable_baselines3.common.vec_env.base_vec_env import VecEnv

RL_DIR = Path(__file__).resolve().parent
REPO = RL_DIR.parent.parent
CLIENT = REPO / "client"
GODOT = REPO / "tools" / "godot" / "Godot_v4.7-stable_linux.x86_64"


def load_settings() -> dict:
    with open(RL_DIR / "rl_settings.json", encoding="utf-8") as f:
        return json.load(f)


def roster_ids() -> list:
    with open(CLIENT / "data" / "config" / "pururin_roster.json", encoding="utf-8") as f:
        return [p["id"] for p in json.load(f)["roster"]]


def make_spec(race_seed: int, settings: dict, roster: list) -> dict:
    """くじの番号から、1レース（距離・出る8体・枠順）を決める。同じ番号なら、いつも同じレース。8席全部が育てるCPU。"""
    rng = random.Random(race_seed)
    lineup = list(roster)
    rng.shuffle(lineup)
    lineup = lineup[: settings["field"]]
    return {
        "seed": race_seed,
        "distance_m": float(rng.choice(settings["distances_m"])),
        "lineup": lineup,
        "seats": list(range(len(lineup))),
    }


class Godot:
    """画面なしのゴドー1本。"""

    def __init__(self, settings: dict, index: int, log_dir):
        self._server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server.bind(("127.0.0.1", 0))
        self._server.listen(1)
        port = self._server.getsockname()[1]
        log_path = Path(log_dir) / f"godot_{index}_{os.getpid()}.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        self._log = open(log_path, "w", encoding="utf-8")
        self._proc = subprocess.Popen(
            [str(GODOT), "--headless", "--fixed-fps", str(int(settings["fixed_fps"])), "--path", str(CLIENT),
             "-s", str(RL_DIR / "rl_worker.gd"), "--", f"port={port}", f"field={int(settings['field'])}"],
            stdout=self._log, stderr=subprocess.STDOUT,
        )
        self._server.settimeout(120)
        self._conn, _ = self._server.accept()
        self._conn.settimeout(600)
        self._file = self._conn.makefile("rwb")
        self.hello = self.read()

    def send(self, message: dict) -> None:
        self._file.write((json.dumps(message) + "\n").encode("utf-8"))
        self._file.flush()

    def read(self) -> dict:
        line = self._file.readline()
        if not line:
            raise RuntimeError("ゴドーとのつながりが切れました（runs のログを見る）")
        return json.loads(line)

    def close(self):
        try:
            self.send({"cmd": "close"})
            self._proc.wait(timeout=20)
        except Exception:
            self._proc.kill()
        self._log.close()
        self._conn.close()
        self._server.close()


class GodotVecEnv(VecEnv):
    """ゴドー workers 本 × 8席 を、学習の場 workers×8 個として扱う（席の並びは、ゴドーの順、枠の順）。

    seeds を渡すと、その番号のレースを順に走らせる。渡さなければ、学ぶ用の番号からくじで選ぶ。
    レースが1本終わるたびに、その結果を self.races に足す。
    """

    def __init__(self, settings: dict, workers: int, log_dir=None, seeds=None, rng_seed=0):
        self.settings = settings
        self.roster = roster_ids()
        self.field = settings["field"]
        self.seeds = list(seeds) if seeds is not None else None
        self._cursor = 0
        self._rng = random.Random(settings["seeds"]["train_from"] + rng_seed)
        log_dir = log_dir or RL_DIR / "runs" / "logs"
        self.godots = [Godot(settings, i, log_dir) for i in range(workers)]
        hello = self.godots[0].hello
        self.obs_size = int(hello["obs_size"])
        self.action_sizes = [int(n) for n in hello["action_sizes"]]
        super().__init__(workers * self.field,
                         gym.spaces.Box(-5.0, 5.0, shape=(self.obs_size,), dtype=np.float32),
                         gym.spaces.MultiDiscrete(self.action_sizes))
        self._obs = np.zeros((self.num_envs, self.obs_size), dtype=np.float32)
        self._masks = np.ones((self.num_envs, sum(self.action_sizes)), dtype=bool)
        self._actions = None
        self.races = []

    # ------------------------------------------------------------ レース
    def _next_seed(self) -> int:
        if self.seeds is not None:
            race_seed = self.seeds[self._cursor % len(self.seeds)]
            self._cursor += 1
            return race_seed
        return self.settings["seeds"]["train_from"] + self._rng.randrange(1_000_000_000)

    def _start(self, w: int) -> None:
        g = self.godots[w]
        g.send({"cmd": "reset", "spec": make_spec(self._next_seed(), self.settings, self.roster), "settings": self.settings})
        message = g.read()
        if message["over"]:
            raise RuntimeError("レースが、最初の判断の前に終わりました")
        self._take(w, message)

    def _take(self, w: int, message: dict) -> np.ndarray:
        rewards = np.zeros(self.field, dtype=np.float32)
        for seat in message["seats"]:
            k = w * self.field + int(seat["gate"])
            self._obs[k] = np.asarray(seat["obs"], dtype=np.float32)
            self._masks[k] = np.asarray(seat["mask"], dtype=bool)
            rewards[int(seat["gate"])] = float(seat["reward"])
        return rewards

    # ------------------------------------------------------------ 学習の場
    def reset(self):
        for w in range(len(self.godots)):
            self._start(w)
        return self._obs.copy()

    def step_async(self, actions):
        self._actions = np.asarray(actions)

    def step_wait(self):
        for w, g in enumerate(self.godots):
            part = self._actions[w * self.field:(w + 1) * self.field]
            g.send({"cmd": "step", "actions": {str(i): [int(a) for a in part[i]] for i in range(self.field)}})
        rewards = np.zeros(self.num_envs, dtype=np.float32)
        dones = np.zeros(self.num_envs, dtype=bool)
        infos = [{} for _ in range(self.num_envs)]
        for w, g in enumerate(self.godots):
            message = g.read()
            rewards[w * self.field:(w + 1) * self.field] = self._take(w, message)
            if message["over"]:
                race = message["race"]
                self.races.append(race)
                for result in race["results"]:
                    k = w * self.field + int(result["gate"])
                    dones[k] = True
                    infos[k] = {**result, "terminal_observation": self._obs[k].copy()}
                self._start(w)
        return self._obs.copy(), rewards, dones, infos

    def action_masks(self) -> np.ndarray:
        return self._masks.copy()

    def env_method(self, method_name, *args, indices=None, **kwargs):
        if method_name == "action_masks":
            idx = range(self.num_envs) if indices is None else indices
            return [self._masks[i].copy() for i in idx]
        raise NotImplementedError(method_name)

    def get_attr(self, attr_name, indices=None):
        idx = range(self.num_envs) if indices is None else indices
        return [getattr(self, attr_name, None) for _ in idx]

    def set_attr(self, attr_name, value, indices=None):
        setattr(self, attr_name, value)

    def env_is_wrapped(self, wrapper_class, indices=None):
        idx = range(self.num_envs) if indices is None else indices
        return [False for _ in idx]

    def seed(self, seed=None):
        return [None] * self.num_envs

    def close(self):
        for g in self.godots:
            g.close()
