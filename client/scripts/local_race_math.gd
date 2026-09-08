extends RefCounted
## ローカル簡易レース用の定数・進捗・前方ブロック（検討事項 #23／速度は #24）。
## 速度の単位は km/h。Path（メートル）を進めるときだけ ÷3.6 する。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")

## 東京芝 A コース準拠のスタジアム近似（JRA 公表値に合わせた仮決め）。
const TOKYO_STRAIGHT_M := 526.0
const TOKYO_TURN_RADIUS_M := 164.0
const TOKYO_LAP_M := 2083.0
const RACE_DISTANCE_M := 2000.0
## ホームストレート終端をゴールにする。ここから次の周回方向へ進む。
const GOAL_PATH_DISTANCE_M := TOKYO_STRAIGHT_M
## ゴールから 2000m 戻った地点をスタートにする。
const START_PATH_DISTANCE_M := fposmod(
	GOAL_PATH_DISTANCE_M - RACE_DISTANCE_M,
	TOKYO_LAP_M
)

## CPU 最高速ティア（km/h）。旧 14/15/16 m/s 相当を丸めた値。
const SPEED_TIERS_KMH := [50.0, 54.0, 58.0]
## プレイヤー通常上限（#24・ブーストなし）。
const PLAYER_MAX_SPEED_KMH := 75.0
## プレイヤー開始時の現在／目標（#24 巡航帯）。
const PLAYER_INITIAL_SPEED_KMH := 58.0
## 世界の絶対上限（#24）。ローカル簡易ではブースト未実装のため通常は PLAYER_MAX まで。
const HARD_SPEED_CAP_KMH := 90.0
const TARGET_SPEED_STEP_KMH := 1.0
const TARGET_SPEED_MIN_KMH := 48.0
## 旧 6 m/s² 相当。
const ACCEL_KMH_PER_S := 21.6

## 接触箱（設計案の例に近い簡易値）。
const BLOCK_LATERAL_M := 1.5
const BLOCK_FORWARD_M := 3.0
const CONTACT_LONGITUDINAL_M := 1.5
const BLOCK_SPEED_FACTOR := 1.0

const FIELD_SIZE := 8
const BAKE_INTERVAL_M := 1.0


static func expected_stadium_length_m(
	straight_len: float = TOKYO_STRAIGHT_M,
	turn_radius: float = TOKYO_TURN_RADIUS_M
) -> float:
	return 2.0 * straight_len + TAU * turn_radius


static func kmh_to_mps(speed_kmh: float) -> float:
	return speed_kmh / 3.6


static func mps_to_kmh(speed_mps: float) -> float:
	return speed_mps * 3.6


static func clamp_target_speed_kmh(target_kmh: float, max_speed_kmh: float) -> float:
	var ceiling := minf(max_speed_kmh, HARD_SPEED_CAP_KMH)
	return clampf(target_kmh, TARGET_SPEED_MIN_KMH, ceiling)


static func step_target_speed_kmh(
	target_kmh: float,
	direction: float,
	max_speed_kmh: float
) -> float:
	var next := target_kmh + direction * TARGET_SPEED_STEP_KMH
	return clamp_target_speed_kmh(next, max_speed_kmh)


static func follow_speed_kmh(current_kmh: float, target_kmh: float, delta: float) -> float:
	if delta <= 0.0:
		return current_kmh
	var diff := target_kmh - current_kmh
	var max_step := ACCEL_KMH_PER_S * delta
	if absf(diff) <= max_step:
		return target_kmh
	return current_kmh + signf(diff) * max_step


## other が self の前方にいる中心線距離（0 超〜 path_length）。真後ろは path_length に近い。
static func forward_gap(self_distance: float, other_distance: float, path_length: float) -> float:
	if path_length <= 0.0:
		return 0.0
	return fposmod(other_distance - self_distance, path_length)


static func is_laterally_blocking(self_offset: float, other_offset: float) -> bool:
	return absf(self_offset - other_offset) <= BLOCK_LATERAL_M


## 直前にいるブロッカーの対地速度（km/h）。いなければ -1。
static func blocking_speed_kmh(
	self_distance: float,
	self_offset: float,
	others: Array,
	path_length: float
) -> float:
	var best_gap := BLOCK_FORWARD_M
	var found := false
	var blocker_speed := -1.0
	for entry in others:
		var other_d: float = entry.get("distance", 0.0)
		var other_o: float = entry.get("offset", 0.0)
		var other_s: float = entry.get("speed", 0.0)
		if not is_laterally_blocking(self_offset, other_o):
			continue
		var gap := forward_gap(self_distance, other_d, path_length)
		if gap <= 0.0001 or gap > BLOCK_FORWARD_M:
			continue
		if (not found) or gap < best_gap:
			found = true
			best_gap = gap
			blocker_speed = other_s
	return blocker_speed if found else -1.0


static func apply_block_cap_kmh(desired_kmh: float, blocker_kmh: float) -> float:
	if blocker_kmh < 0.0:
		return desired_kmh
	return minf(desired_kmh, blocker_kmh * BLOCK_SPEED_FACTOR)


static func contact_overlaps(
	first_progress: float,
	first_offset: float,
	second_progress: float,
	second_offset: float
) -> bool:
	return (
		absf(first_progress - second_progress) < CONTACT_LONGITUDINAL_M
		and absf(first_offset - second_offset) < BLOCK_LATERAL_M
	)


## 対地速度（km/h）で進んだときの中心線増分（m。ラップしない）。
static func centerline_delta_from_kmh(
	speed_kmh: float,
	delta: float,
	offset: float,
	curvature: float
) -> float:
	var mult := M2TrackMath.distance_multiplier(offset, curvature)
	# コースはメートルなので、進む量だけ km/h → m/s 相当にする。
	return (speed_kmh / 3.6) * delta / mult


static func add_race_progress(progress: float, delta_centerline: float) -> float:
	return progress + maxf(delta_centerline, 0.0)


static func has_finished(progress: float, race_distance: float = RACE_DISTANCE_M) -> bool:
	return progress >= race_distance


static func format_race_time(seconds: float) -> String:
	var safe_seconds := maxf(seconds, 0.0)
	var minutes := int(safe_seconds / 60.0)
	var remaining := fmod(safe_seconds, 60.0)
	if minutes > 0:
		return "%d:%04.1f" % [minutes, remaining]
	return "%.1f" % remaining


## 最内＝枠1。offset は負が内側。8 頭を可動幅に等間隔。
static func starting_offset_for_gate(gate_index: int, field_size: int = FIELD_SIZE) -> float:
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	if field_size <= 1:
		return -max_abs
	var t := float(gate_index) / float(field_size - 1)
	return lerpf(-max_abs, max_abs, t)


static func tier_speed_kmh_for_index(index: int) -> float:
	return SPEED_TIERS_KMH[index % SPEED_TIERS_KMH.size()]
