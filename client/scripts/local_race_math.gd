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

## M5.1 出力操作実験。出力は整数ノッチだが、入力は長押しでリピートする。
const DRIVE_LEVEL_MIN := -3
const DRIVE_LEVEL_MAX := 5
const DRIVE_LEVEL_STEP := 1
const MIN_SPEED_KMH := 40.0
const ROLLING_RESISTANCE_KMH_PER_S := 0.55
const AIR_RESISTANCE_COEFFICIENT := 0.024
## ノッチごとの駆動力。速度帯を持たず、抵抗との差分だけで加減速する。
## 低ノッチは低速域でわずかに加速しつつ、高速域では抵抗に負ける。
## 値は「ノッチ × 一律係数」よりも、操作感を調整しやすい小さなカーブとして管理する。
const DRIVE_FORCE_BY_LEVEL_KMH_PER_S := [0.0, 1.8, 1.9, 2.2, 2.6, 3.0]
const BRAKE_DECELERATION_PER_LEVEL := 4.0
const DRAFT_SPEED_BONUS_MAX_KMH := 4.0
const DRAFT_AIR_RESISTANCE_FACTOR := 0.55
const DRAFT_FORWARD_MIN_M := 0.5
const DRAFT_FORWARD_MAX_M := 8.0
const DRAFT_LATERAL_RANGE_M := 1.8
const DRIVE_REPEAT_INITIAL_S := 0.24
const DRIVE_REPEAT_INTERVAL_S := 0.10

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


static func clamp_drive_level(level: float) -> float:
	return clampf(level, float(DRIVE_LEVEL_MIN), float(DRIVE_LEVEL_MAX))


static func step_drive_level(level: float, direction: float) -> float:
	var sign_direction := signf(direction)
	if is_zero_approx(sign_direction):
		return clamp_drive_level(level)
	return clamp_drive_level(level + sign_direction * DRIVE_LEVEL_STEP)


static func drive_force_kmh_per_s(drive_level: float) -> float:
	var level_index := int(round(clamp_drive_level(drive_level)))
	return float(DRIVE_FORCE_BY_LEVEL_KMH_PER_S[level_index])


static func drive_resistance_kmh_per_s(speed_kmh: float, draft_factor: float = 0.0) -> float:
	var safe_speed := maxf(speed_kmh, MIN_SPEED_KMH)
	var air_resistance := AIR_RESISTANCE_COEFFICIENT * safe_speed
	return ROLLING_RESISTANCE_KMH_PER_S + air_resistance * (1.0 - clampf(draft_factor, 0.0, 1.0))


static func draft_speed_bonus_kmh(draft_factor: float) -> float:
	var draft_presence := clampf(
		draft_factor / maxf(DRAFT_AIR_RESISTANCE_FACTOR, 0.0001),
		0.0,
		1.0
	)
	return DRAFT_SPEED_BONUS_MAX_KMH * draft_presence


static func advance_drive_speed_kmh(
	current_kmh: float,
	drive_level: float,
	max_speed_kmh: float,
	delta: float,
	draft_factor: float = 0.0
) -> float:
	if delta <= 0.0:
		return maxf(current_kmh, MIN_SPEED_KMH)
	var level := clamp_drive_level(drive_level)
	var next_speed := current_kmh
	if level < 0.0:
		# 負ノッチは従来どおり明確な制動として扱う。
		var braking := -level * BRAKE_DECELERATION_PER_LEVEL
		var acceleration := -braking - drive_resistance_kmh_per_s(current_kmh, draft_factor)
		next_speed += acceleration * delta
	elif level > 0.0:
		# 正ノッチは速度帯ではなく、駆動力と抵抗の差分を積み上げる。
		var drive_force := drive_force_kmh_per_s(level)
		var acceleration := drive_force - drive_resistance_kmh_per_s(current_kmh, draft_factor)
		next_speed += acceleration * delta
	else:
		# 0 は惰性。抵抗だけで最低速度へ自然に戻る。
		next_speed -= drive_resistance_kmh_per_s(current_kmh, draft_factor) * delta
	var ceiling := minf(max_speed_kmh, HARD_SPEED_CAP_KMH)
	if level > 0.0 and draft_factor > 0.0:
		# ドラフト成立時だけ、個体上限に最大4km/hを加えられる。
		var draft_bonus := draft_speed_bonus_kmh(draft_factor)
		ceiling = minf(max_speed_kmh + draft_bonus, HARD_SPEED_CAP_KMH)
	return clampf(next_speed, MIN_SPEED_KMH, ceiling)


static func draft_leader(
	self_distance: float,
	self_offset: float,
	others: Array,
	path_length: float
) -> Dictionary:
	var best_gap := DRAFT_FORWARD_MAX_M
	var leader: Dictionary = {}
	for entry in others:
		var gap := forward_gap(self_distance, entry.get("distance", 0.0), path_length)
		if gap < DRAFT_FORWARD_MIN_M or gap > DRAFT_FORWARD_MAX_M:
			continue
		if absf(self_offset - float(entry.get("offset", 0.0))) > DRAFT_LATERAL_RANGE_M:
			continue
		if gap < best_gap:
			best_gap = gap
			leader = entry
	return leader


static func heart_rate_target_bpm(drive_level: float) -> float:
	var effort := absf(clamp_drive_level(drive_level)) / float(DRIVE_LEVEL_MAX)
	return lerpf(118.0, 185.0, effort)


static func stamina_delta_per_s(drive_level: float) -> float:
	if is_zero_approx(clamp_drive_level(drive_level)):
		return 0.0
	var effort := absf(clamp_drive_level(drive_level)) / float(DRIVE_LEVEL_MAX)
	return lerpf(2.5, -7.0, effort)


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
