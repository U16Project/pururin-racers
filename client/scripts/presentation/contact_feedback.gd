extends RefCounted
## 接触の見た目のうち、光り方。接触中は少し白く光り、押し合い中はさらに強く光る。
## 強さ（0〜1）を滑らかに追いかけ、光る量を返す。値の計算だけをここに置き、体への反映は走者が行う。
## つぶれる・震えるのは、体の動き（設定の body_motions の contact・push）で出す。

## 接触中・押し合い中の強さの目標。
const LEVEL_CONTACT := 0.5
const LEVEL_PUSH := 1.0
## 強さが目標へ追いつく速さ（1秒あたりの割合）。
const FOLLOW_RATE_PER_S := 12.0
## 強さ1のときの光る量（emissionの強さ）。
const GLOW_MAX := 0.1

static func target_level(contact_count: int, in_push_contest: bool) -> float:
	if in_push_contest:
		return LEVEL_PUSH
	return LEVEL_CONTACT if contact_count > 0 else 0.0


## 強さを目標へ、滑らかに近づける。
static func next_level(current: float, target: float, delta: float) -> float:
	return lerpf(current, target, clampf(delta * FOLLOW_RATE_PER_S, 0.0, 1.0))


static func glow_energy(level: float) -> float:
	return clampf(level, 0.0, 1.0) * GLOW_MAX
