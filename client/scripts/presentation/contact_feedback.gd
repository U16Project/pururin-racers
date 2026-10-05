extends RefCounted
## 接触の見た目。接触中は少し白く光ってつぶれ、押し合い中はさらに強く光って、つぶれながら震える。
## 強さ（0〜1）を滑らかに追いかけ、光る量と体の形を返す。値の計算だけをここに置き、体への反映は走者が行う。

## 接触中・押し合い中の強さの目標。
const LEVEL_CONTACT := 0.5
const LEVEL_PUSH := 1.0
## 強さが目標へ追いつく速さ（1秒あたりの割合）。
const FOLLOW_RATE_PER_S := 12.0
## 強さ1のときの光る量（emissionの強さ）。
const GLOW_MAX := 0.1
## 強さ1のとき、横（左右）につぶれる割合と、上下・前後へふくらむ割合。
const SQUASH_SIDE := 0.14
const SQUASH_BULGE := 0.07
## 押し合い中の震え。横のつぶれ方が、この割合と速さ（回/秒）で揺れる。
const SHAKE_AMOUNT := 0.05
const SHAKE_HZ := 14.0


static func target_level(contact_count: int, in_push_contest: bool) -> float:
	if in_push_contest:
		return LEVEL_PUSH
	return LEVEL_CONTACT if contact_count > 0 else 0.0


## 強さを目標へ、滑らかに近づける。
static func next_level(current: float, target: float, delta: float) -> float:
	return lerpf(current, target, clampf(delta * FOLLOW_RATE_PER_S, 0.0, 1.0))


static func glow_energy(level: float) -> float:
	return clampf(level, 0.0, 1.0) * GLOW_MAX


## 体の形（x が左右、y が上下、z が前後）。体積がほぼ変わらないよう、横が縮むぶん上下・前後がふくらむ。
## 押し合い（強さが LEVEL_CONTACT を超えた分）に応じて、横が震える。
static func body_scale(level: float, time_s: float) -> Vector3:
	var amount := clampf(level, 0.0, 1.0)
	var shake_amount := clampf((amount - LEVEL_CONTACT) / (LEVEL_PUSH - LEVEL_CONTACT), 0.0, 1.0)
	var side := 1.0 - SQUASH_SIDE * amount + SHAKE_AMOUNT * shake_amount * sin(time_s * TAU * SHAKE_HZ)
	var bulge := 1.0 + SQUASH_BULGE * amount
	return Vector3(side, bulge, bulge)
