extends RefCounted
## ローカル簡易レース用の定数・進捗・前方ブロック（検討事項 #23）。


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

const SPEED_TIERS := [14.0, 15.0, 16.0]
const PLAYER_MAX_SPEED := 25.0
const TARGET_SPEED_STEP := 1.0
const TARGET_SPEED_MIN := 8.0
const ACCEL_MPS2 := 6.0

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


static func clamp_target_speed(target: float, max_speed: float) -> float:
	return clampf(target, TARGET_SPEED_MIN, max_speed)


static func step_target_speed(target: float, direction: float, max_speed: float) -> float:
	var next := target + direction * TARGET_SPEED_STEP
	return clamp_target_speed(next, max_speed)


static func follow_speed(current: float, target: float, delta: float) -> float:
	if delta <= 0.0:
		return current
	var diff := target - current
	var max_step := ACCEL_MPS2 * delta
	if absf(diff) <= max_step:
		return target
	return current + signf(diff) * max_step


## other が self の前方にいる中心線距離（0 超〜 path_length）。真後ろは path_length に近い。
static func forward_gap(self_distance: float, other_distance: float, path_length: float) -> float:
	if path_length <= 0.0:
		return 0.0
	return fposmod(other_distance - self_distance, path_length)


static func is_laterally_blocking(self_offset: float, other_offset: float) -> bool:
	return absf(self_offset - other_offset) <= BLOCK_LATERAL_M


## 直前にいるブロッカーの対地速度。いなければ -1。
static func blocking_speed(
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


static func apply_block_cap(desired_speed: float, blocker_speed: float) -> float:
	if blocker_speed < 0.0:
		return desired_speed
	return minf(desired_speed, blocker_speed * BLOCK_SPEED_FACTOR)


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


## 対地速度で進んだときの中心線増分（ラップしない）。
static func centerline_delta(speed: float, delta: float, offset: float, curvature: float) -> float:
	var mult := M2TrackMath.distance_multiplier(offset, curvature)
	return speed * delta / mult


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


static func tier_speed_for_index(index: int) -> float:
	return SPEED_TIERS[index % SPEED_TIERS.size()]
