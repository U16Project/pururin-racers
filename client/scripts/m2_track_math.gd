extends RefCounted
## M2: offset クランプと内外の距離倍率。
## 対地スピードを内外で揃えるため、倍率は半径比 (R+offset)/R を基本に、GEOMETRIC_BLEND で弱める。
## ※設計案の弱い ±6% 表とも、完全な幾何比とも相違 → 設計案は幾何＋BLEND（現状 0.85）を M2 正とし、弱い表は将来調整例。


const BODY_DIAMETER_M := 1.5
const BODY_RADIUS_M := BODY_DIAMETER_M * 0.5
## 10 頭分のコース全幅。
const TRACK_WIDTH_M := 15.0
const HALF_WIDTH_M := TRACK_WIDTH_M * 0.5
## 機体がはみ出さないよう、中心寄せの可動半幅。
const MAX_ABS_OFFSET_M := HALF_WIDTH_M - BODY_RADIUS_M
## 曲率推定の前方サンプル距離(m)。
const CURVE_LOOK_AHEAD_M := 2.0
## 内側で R+offset が潰れない下限。
const MIN_DISTANCE_MULT := 0.05
## 幾何倍率 (R+offset)/R への寄せ。1=半径どおり、0=差なし。差を少し縮める。
const GEOMETRIC_BLEND := 0.85
## curve_strength 用: κ を R=12m で 1.0 に写す（負荷など将来用）。
const CURVATURE_STRENGTH_REF_RADIUS_M := 12.0


## offset を可動範囲に収める。
static func clamp_offset(offset: float) -> float:
	return clampf(offset, -MAX_ABS_OFFSET_M, MAX_ABS_OFFSET_M)


## 中心線の曲率 κ(1/m)。直線≈0、半径 R の円で ≈1/R。
static func curvature_at(curve: Curve3D, distance: float) -> float:
	if curve == null:
		return 0.0
	var path_len := curve.get_baked_length()
	if path_len <= 0.0:
		return 0.0
	var look := CURVE_LOOK_AHEAD_M
	var d0 := fposmod(distance, path_len)
	var d1 := fposmod(distance + look, path_len)
	var f0 := -curve.sample_baked_with_rotation(d0).basis.z
	var f1 := -curve.sample_baked_with_rotation(d1).basis.z
	f0.y = 0.0
	f1.y = 0.0
	if f0.length_squared() < 1e-8 or f1.length_squared() < 1e-8:
		return 0.0
	f0 = f0.normalized()
	f1 = f1.normalized()
	return f0.angle_to(f1) / look


## 設計案 curve_strength 0..1（κ から写像。負荷など用）。
static func curve_strength_at(curve: Curve3D, distance: float) -> float:
	return clampf(curvature_at(curve, distance) * CURVATURE_STRENGTH_REF_RADIUS_M, 0.0, 1.0)


## 必要中心線距離の倍率。幾何 (R+offset)/R を GEOMETRIC_BLEND で弱める。直線(κ=0)は 1。
static func distance_multiplier(offset: float, curvature: float = 0.0) -> float:
	var geometric := 1.0 + offset * curvature
	var blended := lerpf(1.0, geometric, GEOMETRIC_BLEND)
	return maxf(blended, MIN_DISTANCE_MULT)


## 同一対地速度で進むとき、中心線 distance の増分。
static func advance_distance(
	distance: float,
	delta: float,
	speed: float,
	path_length: float,
	offset: float,
	curvature: float = 0.0
) -> float:
	if path_length <= 0.0:
		return 0.0
	var mult := distance_multiplier(offset, curvature)
	return fposmod(distance + speed * delta / mult, path_length)


## 競馬場形中心線上の「外向き」水平単位ベクトル。
static func stadium_outward(
	pos: Vector3,
	straight_len: float,
	turn_radius: float
) -> Vector3:
	var half_s := straight_len * 0.5
	var r := turn_radius
	var eps := 0.05
	var pr := Vector3(pos.x - half_s, 0.0, pos.z)
	var pl := Vector3(pos.x + half_s, 0.0, pos.z)
	if pr.length() <= r + eps and pos.x >= half_s - eps:
		if pr.length_squared() < 1e-8:
			return Vector3(1.0, 0.0, 0.0)
		return pr.normalized()
	if pl.length() <= r + eps and pos.x <= -half_s + eps:
		if pl.length_squared() < 1e-8:
			return Vector3(-1.0, 0.0, 0.0)
		return pl.normalized()
	if pos.z < 0.0:
		return Vector3(0.0, 0.0, -1.0)
	return Vector3(0.0, 0.0, 1.0)
