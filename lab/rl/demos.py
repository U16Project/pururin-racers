"""強化学習：お手本（あなたの走りの記録）を使って、頭をあなたの操作に寄せる。

- 記録 → お手本の束：rl_demos.gd（ゴドー）が、記録1本ごとに runs/demos/<記録の名前>.json を書く。新しい記録だけ足す。
- 寄せる強さは、お手本の本数で決める（rl_settings.json の demo.strength_by_races）。少ないうちは軽く寄せるだけ。
- 学び始め：お手本の操作を、そのまま、まねさせる（pretrain_batches × 強さ 回）。
- 学びの途中：頭を直すたびに、まねの分を少し足す。はじめは強め、だんだん弱める（keep_start・keep_half_life_steps）。
- 結果の良かったレースほど、少し重く見る（demo.place_weight：着順ごとの重さ。まねの場面を選ぶ見込みに掛ける）。
- こわれた記録・古い形・途中でやめたレースは、rl_demos.gd が外す。使った・外した記録は report() で表にする。
お手本の束は使い捨てにせず、取っておいて、頭を直すたびに見直す。
ユーザーは、ふつうにオフラインで遊ぶだけでよい（記録はゲームが自動で残し、ここが自分で見つけて足す）。

使った・外した記録の表：python lab/rl/demos.py
"""

import glob
import json
import subprocess

import numpy as np
import torch

from godot_env import CLIENT, GODOT, RL_DIR

DEMO_DIR = RL_DIR / "runs" / "demos"


def refresh(settings: dict) -> str:
    """新しい記録を、お手本の束に足す（ゴドーを画面なしで1回動かす）。"""
    done = subprocess.run(
        [str(GODOT), "--headless", "--path", str(CLIENT), "-s", str(RL_DIR / "rl_demos.gd"), "--",
         f"out={DEMO_DIR}", f"since={settings['demo']['since']}"],
        capture_output=True, text=True, timeout=1800,
    )
    lines = [line for line in done.stdout.splitlines() if line.startswith("お手本")]
    return lines[-1] if lines else done.stdout[-500:]


class DemoBank:
    """お手本の束。obs・選べる操作・あなたの操作を、まとめて持つ。"""

    def __init__(self, settings: dict):
        self.settings = settings["demo"]
        self.obs = np.zeros((0, 0), dtype=np.float32)
        self.masks = np.zeros((0, 0), dtype=bool)
        self.actions = np.zeros((0, 0), dtype=np.int64)
        self.races = 0
        self._rng = np.random.default_rng(0)

    def load(self):
        obs, masks, actions, weights = [], [], [], []
        files = [p for p in sorted(glob.glob(str(DEMO_DIR / "*.json"))) if not p.endswith("_index.json")]
        table = self.settings["place_weight"]
        for path in files:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
            obs.append(np.asarray(d["obs"], dtype=np.float32))
            masks.append(np.asarray(d["mask"], dtype=bool))
            actions.append(np.asarray(d["action"], dtype=np.int64))
            place = max(int(d.get("place", len(table))), 1)
            weights.append(np.full(len(d["action"]), table[min(place, len(table)) - 1], dtype=np.float64))
        self.races = len(files)
        if files:
            self.obs, self.masks, self.actions = np.concatenate(obs), np.concatenate(masks), np.concatenate(actions)
            w = np.concatenate(weights)
            self.pick = w / w.sum()
        return self

    def strength(self) -> float:
        """お手本の本数 → 寄せる強さ（0〜1）。"""
        points = self.settings["strength_by_races"]
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        return float(np.interp(self.races, xs, ys))

    def keep_weight(self, steps: int) -> float:
        """学びの途中で寄せる力（判断の数が進むほど、半分ずつ弱める）。"""
        return self.strength() * self.settings["keep_start"] * 0.5 ** (steps / self.settings["keep_half_life_steps"])

    def imitate(self, policy, batches: int, weight: float) -> float:
        """お手本の操作を選ぶ見込みを上げる向きに、頭を batches 回直す。返すのは、お手本と同じ操作を選ぶ見込みの平均。"""
        if len(self.obs) == 0 or batches <= 0 or weight <= 0.0:
            return 0.0
        policy.set_training_mode(True)
        size = min(self.settings["batch_size"], len(self.obs))
        total = 0.0
        for _ in range(batches):
            idx = self._rng.choice(len(self.obs), size, p=self.pick)
            obs = torch.as_tensor(self.obs[idx], device=policy.device)
            actions = torch.as_tensor(self.actions[idx], device=policy.device)
            masks = self.masks[idx]
            _, log_prob, _ = policy.evaluate_actions(obs, actions, action_masks=masks)
            loss = -weight * log_prob.mean()
            policy.optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(policy.parameters(), 0.5)
            policy.optimizer.step()
            total += float(log_prob.detach().mean().exp())
        return total / batches


def report():
    """使った・外した記録の表（rl_demos.gd が書いた _index.json から）。"""
    path = DEMO_DIR / "_index.json"
    if not path.exists():
        print("まだお手本を作っていません")
        return
    with open(path, encoding="utf-8") as f:
        index = json.load(f)
    print("記録 | 使った | 外した理由 | ぷるりん | 距離 | 着順")
    for name in sorted(index):
        r = index[name]
        print(f"{name} | {'○' if r['used'] else '×'} | {r['reason']} | {r['pururin']} | {int(r['distance_m'])} | {r['place']}")
    used = sum(1 for r in index.values() if r["used"])
    print(f"使った {used} 本、外した {len(index) - used} 本")


if __name__ == "__main__":
    report()
