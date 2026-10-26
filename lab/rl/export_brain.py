"""強化学習：育てたCPUを、ゲーム本体が読める形に書き出す（Python なしでゲームだけで動かすため）。

書き出すのは、操作を選ぶ部分だけ（見たもの 344 → 256 → 256 → 操作 12）。数字は float32 を base64 にして JSON に入れる。
あわせて、同じ答えになるかの確かめ用に、あなたの記録の場面から N 個の「見たもの・選べる操作・Python が選んだ操作」を書く。

使い方（リポジトリのいちばん上で）：
  /media/u16/Backup/pururin-rl-venv/bin/python lab/rl/export_brain.py --run 育成1
  保存した版から：--file lab/rl/runs/保存/本番2_20261027_0215.zip（名前は「育成の名前_日付_時刻」）
書き出し先：client/data/cpu_brains/main.json（ゲームが使う）、lab/rl/runs/brain_check.json（確かめ用）
確かめ：client/ で godot --headless -s ../lab/rl/brain_check.gd
"""

import argparse
import base64
import glob
import json
import time
from pathlib import Path

import numpy as np
from sb3_contrib import MaskablePPO

from godot_env import CLIENT, RL_DIR


def b64(array) -> str:
    return base64.b64encode(np.asarray(array, dtype=np.float32).tobytes()).decode("ascii")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", default="育成1")
    parser.add_argument("--out", default="main")
    parser.add_argument("--checks", type=int, default=200)
    parser.add_argument("--file", default="", help="育成の最新ではなく、保存した版（.zip）から書き出す")
    args = parser.parse_args()
    path = Path(args.file).resolve() if args.file else RL_DIR / "runs" / args.run / "latest.zip"
    run = path.stem.split("_")[0] if args.file else args.run
    model = MaskablePPO.load(path, device="cpu")
    policy = model.policy
    linears = [m for m in policy.mlp_extractor.policy_net if hasattr(m, "weight")] + [policy.action_net]
    layers = []
    for i, layer in enumerate(linears):
        w = layer.weight.detach().numpy()
        layers.append({"in": int(w.shape[1]), "out": int(w.shape[0]), "w": b64(w), "b": b64(layer.bias.detach().numpy()),
                       "act": "tanh" if i < len(linears) - 1 else "none"})
    saved = time.strftime("%Y-%m-%d %H:%M", time.localtime(path.stat().st_mtime))
    brain = {
        "format": 1, "label": f"{run}（{saved}）", "source": str(path.relative_to(RL_DIR.parent.parent)),
        "obs_size": int(layers[0]["in"]), "action_sizes": [int(n) for n in model.action_space.nvec], "layers": layers,
    }
    out_dir = CLIENT / "data" / "cpu_brains"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{args.out}.json"
    out.write_text(json.dumps(brain), encoding="utf-8")
    print(f"書き出し：{out}（{brain['label']}、{out.stat().st_size // 1024} KB）")

    # 確かめ用：あなたの記録の場面から、見たもの・選べる操作・Python が選んだ操作。
    rng = np.random.default_rng(0)
    obs_all, mask_all = [], []
    for f in sorted(glob.glob(str(RL_DIR / "runs" / "demos" / "2*.json"))):
        d = json.loads(open(f, encoding="utf-8").read())
        obs_all += d["obs"]
        mask_all += d["mask"]
    pick = rng.choice(len(obs_all), size=min(args.checks, len(obs_all)), replace=False)
    cases = []
    for i in pick:
        obs = np.asarray(obs_all[i], dtype=np.float32)
        mask = np.asarray(mask_all[i], dtype=bool)
        action, _ = model.predict(obs, action_masks=mask, deterministic=True)
        cases.append({"obs": obs.tolist(), "mask": [int(m) for m in mask], "action": [int(a) for a in action]})
    check = RL_DIR / "runs" / "brain_check.json"
    check.write_text(json.dumps({"brain": f"res://data/cpu_brains/{args.out}.json", "cases": cases}), encoding="utf-8")
    print(f"確かめ用：{check}（{len(cases)}場面）")


if __name__ == "__main__":
    main()
