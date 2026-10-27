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
    """rl_settings.json に、ゲーム本体の育てたCPUの設定（cpu_brain.json）の field・decide_every_s を足したもの。"""
    with open(RL_DIR / "rl_settings.json", encoding="utf-8") as f:
        settings = json.load(f)
    with open(CLIENT / "data" / "config" / "cpu_brain.json", encoding="utf-8") as f:
        brain = json.load(f)
    settings["field"] = brain["field"]
    settings["decide_every_s"] = brain["decide_every_s"]
    return settings


def roster_ids() -> list:
    with open(CLIENT / "data" / "config" / "pururin_roster.json", encoding="utf-8") as f:
        return [p["id"] for p in json.load(f)["roster"]]


def trainer_ids() -> list:
    with open(CLIENT / "data" / "config" / "cpu_trainers.json", encoding="utf-8") as f:
        return [t["id"] for t in json.load(f)["trainers"]]


def make_spec(race_seed: int, settings: dict, roster: list) -> dict:
    """くじの番号から、1レース（距離・出る8体・枠順）を決める。同じ番号なら、いつも同じレース。8席全部が育てるCPU。
    出る子は、育てるCPU（brains の1つ目）が受け持つ子から選ぶ。"""
    rng = random.Random(race_seed)
    members = [v for k, v in settings["brains"].items() if not k.startswith("_")][0]
    lineup = list(roster) if members == "all" else list(members)
    rng.shuffle(lineup)
    lineup = lineup[: settings["field"]]
    # 席ごとに、決めた割合で、トレーナーを15人からくじで選び直す（いつものトレーナーでない性格にも慣れるように）。
    trainers = {}
    swap = settings.get("trainer_swap", {})
    if swap:
        everyone = trainer_ids()
        for gate in range(len(lineup)):
            if rng.random() < float(swap["rate"]):
                trainers[str(gate)] = rng.choice(everyone)
    return {
        "seed": race_seed,
        "distance_m": float(rng.choice(settings["distances_m"])),
        "lineup": lineup,
        "seats": list(range(len(lineup))),
        "trainers": trainers,
    }


class Godot:
    """画面なしのゴドー1本。"""

    def __init__(self, settings: dict, index: int, log_dir, window: bool = False, extra_args=()):
        self._server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server.bind(("127.0.0.1", 0))
        self._server.listen(1)
        port = self._server.getsockname()[1]
        log_path = Path(log_dir) / f"godot_{index}_{os.getpid()}.log"
        self.log_path = log_path
        log_path.parent.mkdir(parents=True, exist_ok=True)
        self._log = open(log_path, "w", encoding="utf-8")
        # 画面なしは早回し。画面あり（人と走る）は、ふつうの速さ。
        speed = [] if window else ["--headless", "--fixed-fps", str(int(settings["fixed_fps"]))]
        self._proc = subprocess.Popen(
            [str(GODOT), *speed, "--path", str(CLIENT), "-s", str(RL_DIR / "rl_worker.gd"), "--",
             f"port={port}", f"field={int(settings['field'])}", *extra_args],
            stdout=self._log, stderr=subprocess.STDOUT,
        )
        self._server.settimeout(120)
        self._conn, _ = self._server.accept()
        # 画面なしの育成では、10分返事がなければ止まったとみなす。人と走るときは、選ぶ画面で待つことがあるので、待ち時間の制限をなくす。
        self._conn.settimeout(None if window else 600)
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

    def is_running(self) -> bool:
        return self._proc.poll() is None

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
    """ゴドー workers 本の、育てるCPUの席を、学習の場として扱う。

    pool（相手の控え室）を渡すと、1レースのうち pool.seats 席を、控え室からくじで選んだCPUが走らせる（学ばない）。
    さらに pool.always_run があれば、1席をその育成のいちばん新しいCPUが走らせる（学ばない）。
    のこりの席（learn 席）が学習の場になる：学習の場の数＝ workers × learn。どの枠が学ぶ席かは、レースごとにくじで変える。
    控え室が空のときは、その席も本命（main_model）が走らせる（学ばない）。
    seeds を渡すと、その番号のレースを順に走らせる。渡さなければ、学ぶ用の番号からくじで選ぶ。
    レースが1本終わるたびに、その結果を self.races に足す（"pool"：枠 → 相手役の名前）。
    """

    def __init__(self, settings: dict, workers: int, log_dir=None, seeds=None, rng_seed=0, pool=None):
        self.settings = settings
        self.roster = roster_ids()
        self.field = settings["field"]
        self.pool = pool
        self.pool_seats = pool.seat_count() if pool is not None else 0
        # どのレースにも必ず入れる育成のいちばん新しいCPUの席（pool.always_run。その育成自身のレースでは無し）。
        self.always_seats = 1 if pool is not None and pool.always_run else 0
        self.learn = self.field - self.pool_seats - self.always_seats
        self.main_model = None
        self.seeds = list(seeds) if seeds is not None else None
        self._cursor = 0
        self._rng = random.Random(settings["seeds"]["train_from"] + rng_seed)
        log_dir = log_dir or RL_DIR / "runs" / "logs"
        self.godots = [Godot(settings, i, log_dir) for i in range(workers)]
        hello = self.godots[0].hello
        self.obs_size = int(hello["obs_size"])
        self.action_sizes = [int(n) for n in hello["action_sizes"]]
        super().__init__(workers * self.learn,
                         gym.spaces.Box(-5.0, 5.0, shape=(self.obs_size,), dtype=np.float32),
                         gym.spaces.MultiDiscrete(self.action_sizes))
        self._obs = np.zeros((self.num_envs, self.obs_size), dtype=np.float32)
        self._masks = np.ones((self.num_envs, sum(self.action_sizes)), dtype=bool)
        self._actions = None
        self.races = []
        # ゴドーごとの、学ぶ席の枠（学習の場の順）と、控え室の席（枠 → 相手役の名前。本命が代わりに走るときは None）。
        self._learn_gates = [list(range(self.learn)) for _ in range(workers)]
        self._pool_gates = [{} for _ in range(workers)]
        self._pool_obs = [{} for _ in range(workers)]

    # ------------------------------------------------------------ レース
    def _next_seed(self) -> int:
        if self.seeds is not None:
            race_seed = self.seeds[self._cursor % len(self.seeds)]
            self._cursor += 1
            return race_seed
        return self.settings["seeds"]["train_from"] + self._rng.randrange(1_000_000_000)

    def _start(self, w: int) -> None:
        g = self.godots[w]
        gates = list(range(self.field))
        self._rng.shuffle(gates)
        self._pool_gates[w] = dict(zip(gates[:self.pool_seats], self.pool.picks(self._rng))) if self.pool is not None else {}
        for gate in gates[self.pool_seats:self.pool_seats + self.always_seats]:
            self._pool_gates[w][gate] = self.pool.always_name
        self._learn_gates[w] = sorted(gates[self.pool_seats + self.always_seats:])
        g.send({"cmd": "reset", "spec": make_spec(self._next_seed(), self.settings, self.roster), "settings": self.settings})
        message = g.read()
        if message["over"]:
            raise RuntimeError("レースが、最初の判断の前に終わりました")
        self._take(w, message)

    def _slot(self, w: int, gate: int) -> int:
        """学ぶ席の枠 → 学習の場の番号（学ぶ席でなければ -1）。"""
        learn = self._learn_gates[w]
        return w * self.learn + learn.index(gate) if gate in learn else -1

    def _take(self, w: int, message: dict) -> np.ndarray:
        rewards = np.zeros(self.learn, dtype=np.float32)
        self._pool_obs[w] = {}
        for seat in message["seats"]:
            gate = int(seat["gate"])
            k = self._slot(w, gate)
            if k < 0:
                self._pool_obs[w][gate] = (np.asarray(seat["obs"], dtype=np.float32), np.asarray(seat["mask"], dtype=bool))
                continue
            self._obs[k] = np.asarray(seat["obs"], dtype=np.float32)
            self._masks[k] = np.asarray(seat["mask"], dtype=bool)
            rewards[k - w * self.learn] = float(seat["reward"])
        return rewards

    def _pool_actions(self, w: int) -> dict:
        """控え室の席の操作（相手役のCPU、控え室が空なら本命が決める）。"""
        out = {}
        for gate, (obs, mask) in self._pool_obs[w].items():
            name = self._pool_gates[w].get(gate)
            model = (self.pool.model(name) if name else None) or self.main_model
            action, _ = model.predict(obs, action_masks=mask, deterministic=True)
            out[str(gate)] = [int(a) for a in action]
        return out

    # ------------------------------------------------------------ 学習の場
    def reset(self):
        for w in range(len(self.godots)):
            self._start(w)
        return self._obs.copy()

    def step_async(self, actions):
        self._actions = np.asarray(actions)

    def step_wait(self):
        for w, g in enumerate(self.godots):
            part = self._actions[w * self.learn:(w + 1) * self.learn]
            actions = {str(gate): [int(a) for a in part[i]] for i, gate in enumerate(self._learn_gates[w])}
            actions.update(self._pool_actions(w))
            g.send({"cmd": "step", "actions": actions})
        rewards = np.zeros(self.num_envs, dtype=np.float32)
        dones = np.zeros(self.num_envs, dtype=bool)
        infos = [{} for _ in range(self.num_envs)]
        for w, g in enumerate(self.godots):
            message = g.read()
            rewards[w * self.learn:(w + 1) * self.learn] = self._take(w, message)
            if message["over"]:
                race = message["race"]
                # 相手役の成績に数えるのは、実際にその相手役が走った席だけ（読めずに本命が代わりに走った席は数えない）。
                named = {gate: name for gate, name in self._pool_gates[w].items() if name and self.pool.model(name) is not None}
                race["pool"] = {str(gate): name for gate, name in named.items()}
                self.races.append(race)
                if self.pool is not None:
                    self.pool.record(race["results"], named)
                for result in race["results"]:
                    k = self._slot(w, int(result["gate"]))
                    if k >= 0:
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
