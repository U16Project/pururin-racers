extends RefCounted
## ローカル簡易レース用の定数・進捗・前方ブロック（検討事項 #23／速度は #24）。
## 速度の単位は km/h。Path（メートル）を進めるときだけ ÷3.6 する。


const Config := preload("res://scripts/config/local_race_config.gd")
const CourseLayout := preload("res://scripts/m5_course_builder.gd")
const DraftRules := preload("res://scripts/config/m5_draft_rules.gd")

const M2TrackMath := preload("res://scripts/m2_track_math.gd")

## ローカル2000mは M5 共有コース定義を正本にする。
const RACE_DISTANCE_M := 2000.0

static var _course_layout: Dictionary = {}

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
static var DRIVE_LEVEL_MIN: float:
	get:
		return Config.number("drive_level_min")
static var DRIVE_LEVEL_MAX: float:
	get:
		return Config.number("drive_level_max")
static var DRIVE_LEVEL_STEP: float:
	get:
		return Config.number("drive_level_step")
static var MIN_SPEED_KMH: float:
	get:
		return Config.number("min_speed_kmh")
static var ROLLING_RESISTANCE_KMH_PER_S: float:
	get:
		return Config.number("rolling_resistance_kmh_per_s")
## 速度（km/h）の二乗に掛ける空気抵抗係数。抵抗の単位は km/h/s。
static var AIR_RESISTANCE_QUADRATIC_COEFFICIENT: float:
	get:
		return Config.number("air_resistance_quadratic_coefficient")
## ノッチごとの駆動力。速度帯を持たず、抵抗との差分だけで加減速する。
## 低ノッチは低速域でわずかに加速しつつ、高速域では抵抗に負ける。
## 値は「ノッチ × 一律係数」よりも、操作感を調整しやすい小さなカーブとして管理する。
static var DRIVE_FORCE_BY_LEVEL_KMH_PER_S: Array:
	get:
		return Config.values()["drive_force_by_level_kmh_per_s"]
static var BRAKE_DECELERATION_PER_LEVEL: float:
	get:
		return Config.number("brake_deceleration_per_level")
static var DRAFT_SPEED_BONUS_MAX_KMH: float:
	get:
		return DraftRules.number("assist_max_kmh")
static var DRAFT_MAX_RECEIVED_P: float:
	get:
		return DraftRules.number("max_received_p")
static var DRAFT_CHAIN_ATTENUATION: float:
	get:
		return DraftRules.number("chain_attenuation")
static var DRAFT_FORWARD_MIN_M: float:
	get:
		return DraftRules.number("forward_min_m")
static var DRAFT_AIR_RESISTANCE_FACTOR: float:
	get:
		return Config.number("draft_air_resistance_factor")
static var DRAFT_RESPONSE_EXPONENT: float:
	get:
		return Config.number("draft_response_exponent")
static var DRAFT_EFFECTIVE_MAX_RATIO: float:
	get:
		return Config.number("draft_effective_max_ratio")
static var DRAFT_AGGREGATION_EXPONENT: float:
	get:
		return Config.number("draft_aggregation_exponent")
static var DRAFT_FORWARD_MAX_M: float:
	get:
		return DraftRules.number("forward_max_m")
static var DRAFT_LATERAL_RANGE_M: float:
	get:
		return DraftRules.number("lateral_range_m")
static var DRAFT_LATERAL_FALLOFF_EXPONENT: float:
	get:
		return DraftRules.number("lateral_falloff_exponent")
static var DRIVE_REPEAT_INITIAL_S: float:
	get:
		return Config.number("drive_repeat_initial_s")
static var DRIVE_REPEAT_INTERVAL_S: float:
	get:
		return Config.number("drive_repeat_interval_s")
static var TOP_SPEED_NATURAL_MIN_KMH: float:
	get:
		return Config.number("top_speed_natural_min_kmh")
static var TOP_SPEED_NATURAL_MAX_KMH: float:
	get:
		return Config.number("top_speed_natural_max_kmh")
static var ACCELERATION_DRIVE_FORCE_BONUS_PER_STAT_KMH_PER_S: float:
	get:
		return Config.number("acceleration_drive_force_bonus_per_stat_kmh_per_s")

## 接触箱（設計案の例に近い簡易値）。
const BLOCK_LATERAL_M := 1.5
const CONTACT_LONGITUDINAL_M := 1.5

const FIELD_SIZE := 8
const BAKE_INTERVAL_M := 1.0
static func course_layout() -> Dictionary:
	if _course_layout.is_empty():
		_course_layout = CourseLayout.load_layout()
	return _course_layout


static func straight_length_m() -> float:
	return float(course_layout().get("straight_length_m", 0.0))


static func turn_radius_m() -> float:
	return float(course_layout().get("turn_radius_m", 0.0))


static func lap_length_m() -> float:
	return float(course_layout().get("track_length_m", 0.0))


static func goal_path_m() -> float:
	return float(course_layout().get("goal_path_m", 0.0))


static func start_path_m() -> float:
	var route := CourseLayout.route_for_distance(course_layout(), RACE_DISTANCE_M)
	return float(route.get("start_mainline_m", 0.0))


static func apply_course_to_path(path: Path3D) -> void:
	if path == null:
		return
	var straight := straight_length_m()
	var radius := turn_radius_m()
	path.set("straight_len", straight)
	path.set("turn_radius", radius)
	path.curve = CourseLayout.make_racecourse_curve(straight, radius, BAKE_INTERVAL_M)


static func expected_stadium_length_m(
	straight_len: float = -1.0,
	turn_radius: float = -1.0
) -> float:
	if straight_len < 0.0:
		straight_len = straight_length_m()
	if turn_radius < 0.0:
		turn_radius = turn_radius_m()
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


static func drive_force_kmh_per_s(drive_level: float, acceleration_bonus_kmh_per_s: float = 0.0) -> float:
	var level_index := int(round(clamp_drive_level(drive_level)))
	return maxf(float(DRIVE_FORCE_BY_LEVEL_KMH_PER_S[level_index]) + acceleration_bonus_kmh_per_s, 0.0)


## 出力走行の内訳。HUD・ログ・速度更新が同じ計算結果を使う。
static func drive_diagnostics_kmh_per_s(
	speed_kmh: float,
	drive_level: float,
	draft_factor: float = 0.0,
	acceleration_bonus_kmh_per_s: float = 0.0,
	top_speed_drive_adjustment_kmh_per_s: float = 0.0,
	propulsion_efficiency: float = 1.0
) -> Dictionary:
	var level := clamp_drive_level(drive_level)
	var drive_contribution := 0.0
	if level < 0.0:
		# 負ノッチは推進力の代わりに制動寄与として負値にする。
		drive_contribution = level * BRAKE_DECELERATION_PER_LEVEL
	elif level > 0.0:
		drive_contribution = drive_force_kmh_per_s(level, acceleration_bonus_kmh_per_s) + top_speed_drive_adjustment_kmh_per_s
	if drive_contribution > 0.0:
		drive_contribution *= clampf(propulsion_efficiency, 0.0, 1.0)
	var safe_speed := maxf(speed_kmh, MIN_SPEED_KMH)
	var rolling_resistance := ROLLING_RESISTANCE_KMH_PER_S
	var air_resistance := AIR_RESISTANCE_QUADRATIC_COEFFICIENT * safe_speed * safe_speed
	var draft_reduction := air_resistance * clampf(draft_factor, 0.0, 1.0)
	return {
		"drive_contribution_kmh_per_s": drive_contribution,
		"rolling_resistance_kmh_per_s": rolling_resistance,
		"air_resistance_kmh_per_s": air_resistance,
		"draft_air_reduction_kmh_per_s": draft_reduction,
		"total_acceleration_kmh_per_s": drive_contribution - rolling_resistance - air_resistance + draft_reduction,
	}


static func drive_resistance_kmh_per_s(speed_kmh: float, draft_factor: float = 0.0) -> float:
	var diagnostics := drive_diagnostics_kmh_per_s(speed_kmh, 0.0, draft_factor)
	return float(diagnostics["rolling_resistance_kmh_per_s"]) + float(diagnostics["air_resistance_kmh_per_s"]) - float(diagnostics["draft_air_reduction_kmh_per_s"])


static func draft_speed_bonus_kmh(draft_factor: float) -> float:
	var draft_presence := clampf(
		draft_factor / maxf(DRAFT_AIR_RESISTANCE_FACTOR, 0.0001),
		0.0,
		1.0
	)
	return DRAFT_SPEED_BONUS_MAX_KMH * draft_presence


## 生の受取率を正規化し、ローカル走行へ載せる実効率へ変換する共通カーブ。
## 最大受取率でも設定上限までに留め、HUD・空気抵抗軽減・速度補助はこの値を共用する。
static func draft_effective_ratio(received_draft_p: float) -> float:
	var normalized := clampf(received_draft_p, 0.0, DRAFT_MAX_RECEIVED_P) / maxf(DRAFT_MAX_RECEIVED_P, 0.0001)
	return DRAFT_EFFECTIVE_MAX_RATIO * pow(normalized, DRAFT_RESPONSE_EXPONENT)


## 個別のドラフト寄与を p ノルムで合成する。対象数ごとの分岐は持たない。
## 寄与は normalization_max_p を基準に正規化し、出力は同じ単位の受取率へ戻す。
static func draft_aggregate_contributions_p(
	contributions: Array,
	normalization_max_p: float = -1.0
) -> float:
	var cap := DRAFT_MAX_RECEIVED_P if normalization_max_p <= 0.0 else normalization_max_p
	cap = maxf(cap, 0.0001)
	var powered_sum := 0.0
	for contribution in contributions:
		var normalized := clampf(float(contribution), 0.0, cap) / cap
		powered_sum += pow(normalized, DRAFT_AGGREGATION_EXPONENT)
	var ratio := pow(powered_sum, 1.0 / DRAFT_AGGREGATION_EXPONENT) if powered_sum > 0.0 else 0.0
	return minf(cap, ratio * cap)


static func draft_air_resistance_factor(received_draft_p: float) -> float:
	return DRAFT_AIR_RESISTANCE_FACTOR * draft_effective_ratio(received_draft_p)


static func draft_assist_speed_kmh(received_draft_p: float) -> float:
	"""ローカル目標速度方式の受取率→速度補助。最大値は実効率上限に従う。"""
	return DRAFT_SPEED_BONUS_MAX_KMH * draft_effective_ratio(received_draft_p)


static func draft_wake_from_speed(speed_kmh: float) -> float:
	return minf(0.18, 0.06 + maxf(0.0, speed_kmh) / 75.0 * 0.12)


static func calculate_draft_details(snapshot: Array, index: int) -> Dictionary:
	"""M5 post-moveドラフト判定のローカル版。progressは単調値として扱う。"""
	if index < 0 or index >= snapshot.size() or not snapshot[index] is Dictionary:
		return _empty_draft_details()
	var receiver: Dictionary = snapshot[index]
	var own_wake := draft_wake_from_speed(float(receiver.get("speed", 0.0)))
	var sources: Array = []
	for source_index in snapshot.size():
		if source_index == index or not snapshot[source_index] is Dictionary:
			continue
		var source: Dictionary = snapshot[source_index]
		var gap := float(source.get("race_progress", source.get("progress", 0.0))) - float(receiver.get("race_progress", receiver.get("progress", 0.0)))
		var line_gap := absf(float(receiver.get("offset", 0.0)) - float(source.get("offset", 0.0)))
		if gap < DRAFT_FORWARD_MIN_M or gap > DRAFT_FORWARD_MAX_M or line_gap > DRAFT_LATERAL_RANGE_M:
			continue
		var source_wake := float(source.get("own_wake_p", 0.0))
		if source_wake <= 0.0:
			source_wake = draft_wake_from_speed(float(source.get("speed", 0.0)))
		source_wake = clampf(source_wake, 0.0, 0.18)
		var lateral_falloff := pow(1.0 - line_gap / DRAFT_LATERAL_RANGE_M, DRAFT_LATERAL_FALLOFF_EXPONENT)
		var strength := maxf(0.0, source_wake * (1.0 - gap / DRAFT_FORWARD_MAX_M) * lateral_falloff)
		if strength > 0.0:
			sources.append({
				"gap": gap,
				"line": line_gap,
				"strength": strength,
				"id": str(source.get("id", source.get("name", source_index))),
				"source_index": source_index,
			})
	sources.sort_custom(func(a: Dictionary, b: Dictionary):
		if not is_equal_approx(float(a["gap"]), float(b["gap"])):
			return float(a["gap"]) < float(b["gap"])
		return str(a["id"]) < str(b["id"])
	)
	var selected: Array = sources
	if selected.is_empty():
		var none_result := _empty_draft_details()
		none_result["own_wake_p"] = own_wake
		return none_result
	var direct_contributions: Array = []
	for source in selected:
		direct_contributions.append(float(source["strength"]))
	var direct := draft_aggregate_contributions_p(direct_contributions)
	var direct_raw := 0.0
	for contribution in direct_contributions:
		direct_raw += float(contribution)
	var direct_scale := direct / direct_raw if direct_raw > 0.0 else 0.0
	var direct_details: Array = []
	for source in selected:
		direct_details.append({
			"id": str(source["id"]),
			"gap": float(source["gap"]),
			"line": float(source["line"]),
			"contribution_p": float(source["strength"]) * direct_scale,
		})
	var chain_sources: Array[String] = []
	var chain_contributions: Array = []
	for source in selected:
		var source_state: Dictionary = snapshot[int(source["source_index"])]
		var source_previous := minf(DRAFT_MAX_RECEIVED_P, maxf(0.0, float(source_state.get("direct_draft_p", 0.0)) + float(source_state.get("chain_draft_p", 0.0))))
		var chain_lateral_falloff := pow(1.0 - float(source["line"]) / DRAFT_LATERAL_RANGE_M, DRAFT_LATERAL_FALLOFF_EXPONENT)
		var chain_strength := source_previous * DRAFT_CHAIN_ATTENUATION * (1.0 - float(source["gap"]) / DRAFT_FORWARD_MAX_M) * chain_lateral_falloff
		if chain_strength > 0.0:
			chain_sources.append(str(source["id"]))
			chain_contributions.append(chain_strength)
	var chain := draft_aggregate_contributions_p(
		chain_contributions,
		DRAFT_MAX_RECEIVED_P * DRAFT_CHAIN_ATTENUATION
	)
	var primary: Dictionary = direct_details[0]
	return {
		"own_wake_p": own_wake,
		"direct_draft_p": direct,
		"chain_draft_p": chain,
		"received_draft_p": direct + chain,
		"direct_source_ids": direct_details.map(func(detail: Dictionary): return str(detail["id"])),
		"chain_source_ids": chain_sources,
		"draft_source_ids": direct_details.map(func(detail: Dictionary): return str(detail["id"])),
		"primary_source_id": str(primary["id"]),
		"primary_gap_m": float(primary["gap"]),
		"primary_line_gap_m": float(primary["line"]),
		"draft_distance_m": float(primary["gap"]),
		"draft_line_gap_m": float(primary["line"]),
		"direct_source_details": direct_details,
	}


static func _empty_draft_details() -> Dictionary:
	return {
		"own_wake_p": 0.0,
		"direct_draft_p": 0.0,
		"chain_draft_p": 0.0,
		"received_draft_p": 0.0,
		"direct_source_ids": [],
		"chain_source_ids": [],
		"draft_source_ids": [],
		"primary_source_id": "",
		"primary_gap_m": 0.0,
		"primary_line_gap_m": 0.0,
		"draft_distance_m": 0.0,
		"draft_line_gap_m": 0.0,
		"direct_source_details": [],
	}


static func advance_drive_speed_kmh(
	current_kmh: float,
	drive_level: float,
	max_speed_kmh: float,
	delta: float,
	draft_factor: float = 0.0,
	acceleration_bonus_kmh_per_s: float = 0.0,
	top_speed_drive_adjustment_kmh_per_s: float = 0.0,
	propulsion_efficiency: float = 1.0
) -> float:
	if delta <= 0.0:
		return maxf(current_kmh, MIN_SPEED_KMH)
	var level := clamp_drive_level(drive_level)
	var diagnostics := drive_diagnostics_kmh_per_s(
		current_kmh,
		level,
		draft_factor,
		acceleration_bonus_kmh_per_s,
		top_speed_drive_adjustment_kmh_per_s,
		propulsion_efficiency
	)
	var next_speed := current_kmh + float(diagnostics["total_acceleration_kmh_per_s"]) * delta
	var ceiling := minf(max_speed_kmh, HARD_SPEED_CAP_KMH)
	return clampf(next_speed, MIN_SPEED_KMH, ceiling)


static func top_speed_natural_speed_kmh(top_speed: int) -> float:
	return lerpf(TOP_SPEED_NATURAL_MIN_KMH, TOP_SPEED_NATURAL_MAX_KMH, (clampi(top_speed, 1, 15) - 1) / 14.0)


## 基準加速度5・ノッチ6・単独走行では、各最高速値の自然到達速度で推進力と抵抗が釣り合う。
## 補正は速度の二乗に応じて現れるため、低速域を不自然に大きく変えない。
static func top_speed_drive_adjustment_kmh_per_s(speed_kmh: float, drive_level: float, top_speed: int) -> float:
	var level := clamp_drive_level(drive_level)
	if level <= 0.0:
		return 0.0
	var max_drive_force := drive_force_kmh_per_s(DRIVE_LEVEL_MAX)
	var level_force := drive_force_kmh_per_s(level)
	var natural_speed := top_speed_natural_speed_kmh(top_speed)
	var force_at_natural_speed := ROLLING_RESISTANCE_KMH_PER_S + AIR_RESISTANCE_QUADRATIC_COEFFICIENT * natural_speed * natural_speed
	var level_share := level_force / maxf(max_drive_force, 0.001)
	var speed_ratio := maxf(speed_kmh, MIN_SPEED_KMH) / maxf(natural_speed, 0.001)
	return (force_at_natural_speed - max_drive_force) * level_share * speed_ratio * speed_ratio


static func stat_acceleration_force_bonus_kmh_per_s(acceleration: int) -> float:
	return (acceleration - 5) * ACCELERATION_DRIVE_FORCE_BONUS_PER_STAT_KMH_PER_S




static func cpu_steer_reselect_interval_s(random_unit: float) -> float:
	return lerpf(
		Config.number("cpu_steer_reselect_min_s"),
		Config.number("cpu_steer_reselect_max_s"),
		clampf(random_unit, 0.0, 1.0)
	)


static func cpu_next_target_offset_m(current_offset: float, random_unit: float) -> float:
	var signed_unit := clampf(random_unit, 0.0, 1.0) * 2.0 - 1.0
	var random_target := current_offset + signed_unit * Config.number("cpu_steer_target_delta_max_m")
	var inward_target := Config.number("cpu_inward_target_offset_m")
	var biased_target := lerpf(
		random_target,
		inward_target,
		Config.number("cpu_inward_target_blend")
	)
	var limited_target := move_toward(
		current_offset,
		biased_target,
		Config.number("cpu_steer_target_delta_max_m")
	)
	return M2TrackMath.clamp_offset(limited_target)


## 前方の近い走者を一律の距離・横差スコアで選ぶ。プル数ごとの特例は持たない。
static func cpu_follow_candidate(
	self_race_progress: float,
	self_offset: float,
	others: Array
) -> Dictionary:
	var forward_range := Config.number("cpu_follow_forward_range_m")
	var lateral_range := Config.number("cpu_follow_lateral_range_m")
	var preferred_gap := Config.number("cpu_follow_preferred_gap_m")
	var best_score := INF
	var selected := {"found": false}
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other: Dictionary = other_value
		var other_progress := float(other.get("race_progress", other.get("progress", 0.0)))
		var forward_gap := other_progress - self_race_progress
		var lateral_gap := absf(float(other.get("offset", 0.0)) - self_offset)
		if forward_gap <= 0.0 or forward_gap > forward_range or lateral_gap > lateral_range:
			continue
		var score := absf(forward_gap - preferred_gap) / forward_range + lateral_gap / lateral_range
		var candidate_id := str(other.get("id", ""))
		if score < best_score or (is_equal_approx(score, best_score) and candidate_id < str(selected.get("id", ""))):
			best_score = score
			selected = {
				"found": true,
				"id": candidate_id,
				"forward_gap_m": forward_gap,
				"race_progress": other_progress,
				"offset": float(other.get("offset", 0.0)),
			}
	return selected


## 前走者が候補範囲にいない場合も、現在位置を含む横位置を同じ評価式で選ぶ。
## 開始直後のように全走者の進捗が同じでも、密度と空き位置を見て現在ラインを維持できる。
static func cpu_open_line_target_offset_m(
	self_race_progress: float,
	self_offset: float,
	others: Array,
	line_pref: float,
	overtake_bias: float = 0.0,
	curvature: float = 0.0
) -> Dictionary:
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	var spacing := Config.number("cpu_follow_slot_lateral_spacing_m")
	var preferred_line := lerpf(max_abs, -max_abs, clampf(line_pref, 0.0, 1.0))
	var current := M2TrackMath.clamp_offset(self_offset)
	var candidate_offsets := [
		current,
		current - spacing,
		current + spacing,
		preferred_line,
		M2TrackMath.clamp_offset(lerpf(current, preferred_line, 0.5)),
		-max_abs,
		max_abs,
	]
	var best_score := INF
	var selected_offset := current
	for offset_value in candidate_offsets:
		var slot_offset := M2TrackMath.clamp_offset(float(offset_value))
		var line_change := absf(slot_offset - current) / max_abs
		var inner_distance := absf(slot_offset - preferred_line) / max_abs
		var field_density := _cpu_follow_slot_field_density(
			self_race_progress, slot_offset, "", others
		)
		var open_forward := _cpu_follow_slot_open_forward_score(
			self_race_progress, slot_offset, "", others
		)
		var side_continuity := clampf(
			(current / max_abs) * (slot_offset / max_abs),
			-1.0,
			1.0
		)
		# 空いている現在ラインは維持し、混雑時だけ横移動を選びやすくする。
		# 密度に対して連続的に変化させ、開始時だけの特例にはしない。
		var line_change_factor := lerpf(
			1.8,
			0.7,
			clampf(field_density, 0.0, 1.0)
		)
		var score := field_density * Config.number("cpu_follow_slot_field_density_weight") \
			+ inner_distance * Config.number("cpu_follow_slot_inner_bias") \
			+ cpu_line_distance_advantage_score(slot_offset, curvature) \
			+ line_change * Config.number("cpu_follow_slot_line_change_weight") * line_change_factor \
			- side_continuity * Config.number("cpu_follow_slot_side_continuity_weight") \
			- open_forward * Config.number("cpu_follow_slot_open_forward_weight") * maxf(overtake_bias, 0.0)
		# 同点なら現在ラインを優先する。開始枠や横位置を無意味に揺らさない。
		if score < best_score - 0.0001:
			best_score = score
			selected_offset = slot_offset
	return {
		"found": true,
		"name": "open_line",
		"offset": selected_offset,
		"score": best_score,
	}


## 前走者の真後ろ固定ではなく、中央・内側斜め後方・外側斜め後方を同じ式で評価する。
## 混雑は前走者の理想車間位置に対する縦横の近さで測り、IDやプル数で役割を固定しない。
static func cpu_follow_slot(
	self_race_progress: float,
	self_offset: float,
	follow_candidate: Dictionary,
	others: Array,
	overtake_bias: float = 0.0,
	curvature: float = 0.0
) -> Dictionary:
	if not bool(follow_candidate.get("found", false)):
		return {"found": false}
	var leader_offset := M2TrackMath.clamp_offset(float(follow_candidate.get("offset", 0.0)))
	var leader_progress := float(follow_candidate.get("race_progress", self_race_progress))
	var leader_id := str(follow_candidate.get("id", ""))
	var preferred_gap := Config.number("cpu_follow_preferred_gap_m")
	var slot_progress := leader_progress - preferred_gap
	var spacing := Config.number("cpu_follow_slot_lateral_spacing_m")
	var slots := [
		{"name": "center", "offset": leader_offset, "progress": slot_progress, "tie_rank": 1, "forward": false},
		{"name": "inner", "offset": leader_offset - spacing, "progress": slot_progress, "tie_rank": 0, "forward": false},
		{"name": "outer", "offset": leader_offset + spacing, "progress": slot_progress, "tie_rank": 2, "forward": false},
	]
	var bias := clampf(overtake_bias, -1.0, 1.0)
	var has_forward_slot := false
	var has_open_forward_slot := false
	# 前方候補は積極性だけでなく、周囲が詰まっている時にも評価する。
	# スタート直後を距離イベントで扱わず、現在位置の密度から同じ式で判断する。
	var local_density := _cpu_follow_slot_field_density(
		self_race_progress, self_offset, leader_id, others
	)
	var should_probe_forward := (
		bias > Config.number("cpu_overtake_bias_threshold")
		or local_density >= Config.number("cpu_follow_slot_open_forward_threshold")
	)
	if should_probe_forward:
		var overtake_progress := leader_progress + Config.number("cpu_overtake_forward_distance_m")
		var overtake_spacing := Config.number("cpu_overtake_slot_lateral_spacing_m")
		slots.append({
			"name": "overtake_inner",
			"offset": leader_offset - overtake_spacing,
			"progress": overtake_progress,
			"tie_rank": 3,
			"forward": true,
		})
		slots.append({
			"name": "overtake_outer",
			"offset": leader_offset + overtake_spacing,
			"progress": overtake_progress,
			"tie_rank": 4,
			"forward": true,
		})
		# 通常の斜め前が埋まる集団では、外側へ大きく回る空きも同じ式で比較する。
		# 外側に限定し、内寄りとの損得は inner_distance と混雑スコアに任せる。
		slots.append({
			"name": "overtake_escape_outer",
			"offset": leader_offset + Config.number("cpu_overtake_escape_lateral_spacing_m"),
			"progress": overtake_progress,
			"tie_rank": 5,
			"forward": true,
			"escape": true,
		})
	var follow_distance_score := absf(float(follow_candidate.get("forward_gap_m", 0.0)) - preferred_gap) / Config.number("cpu_follow_forward_range_m")
	var best_score := INF
	var selected := {"found": false}
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var slot_offset := M2TrackMath.clamp_offset(float(slot["offset"]))
		var candidate_progress := float(slot.get("progress", slot_progress))
		# 前方スロットが接触範囲に入るなら、無理に割り込まず後方候補へ戻す。
		if bool(slot.get("forward", false)):
			has_forward_slot = true
			if not can_use_offset(candidate_progress, slot_offset, others):
				continue
			has_open_forward_slot = true
		var crowding := _cpu_follow_slot_crowding(candidate_progress, slot_offset, leader_id, others)
		var field_density := _cpu_follow_slot_field_density(candidate_progress, slot_offset, leader_id, others)
		var open_forward := _cpu_follow_slot_open_forward_score(
			candidate_progress, slot_offset, leader_id, others
		)
		var inner_distance := absf(slot_offset - Config.number("cpu_inward_target_offset_m")) / M2TrackMath.MAX_ABS_OFFSET_M
		# 既に走っているラインからの移動も同じ候補評価に含める。
		# 空きと混雑の差が小さいときは、スタート時の枠位置を維持する。
		var line_change := absf(slot_offset - self_offset) / M2TrackMath.MAX_ABS_OFFSET_M
		var side_continuity := clampf(
			(self_offset / M2TrackMath.MAX_ABS_OFFSET_M) * (slot_offset / M2TrackMath.MAX_ABS_OFFSET_M),
			-1.0,
			1.0
		)
		var distance_score := follow_distance_score
		if bool(slot.get("forward", false)):
			distance_score = absf(float(follow_candidate.get("forward_gap_m", 0.0)) - Config.number("cpu_overtake_forward_distance_m")) / Config.number("cpu_follow_forward_range_m")
		var score := distance_score \
			+ crowding * Config.number("cpu_follow_slot_crowding_weight") \
			+ field_density * Config.number("cpu_follow_slot_field_density_weight") \
			+ inner_distance * Config.number("cpu_follow_slot_inner_bias") \
			+ cpu_line_distance_advantage_score(slot_offset, curvature) \
			+ line_change * Config.number("cpu_follow_slot_line_change_weight") \
			- side_continuity * Config.number("cpu_follow_slot_side_continuity_weight")
		if bool(slot.get("forward", false)):
			var forward_bias_weight := Config.number("cpu_overtake_escape_bias_weight") if bool(slot.get("escape", false)) else Config.number("cpu_overtake_slot_bias_weight")
			score -= bias * forward_bias_weight
			score -= open_forward * Config.number("cpu_follow_slot_open_forward_weight")
		else:
			score += maxf(bias, 0.0) * Config.number("cpu_overtake_slot_bias_weight")
		var tie_rank := int(slot["tie_rank"])
		if score < best_score or (is_equal_approx(score, best_score) and tie_rank < int(selected.get("tie_rank", 99))):
			best_score = score
			selected = {
				"found": true,
				"name": str(slot["name"]),
				"offset": slot_offset,
				"score": score,
				"tie_rank": tie_rank,
				"progress": candidate_progress,
				"escape": bool(slot.get("escape", false)),
				"field_density": field_density,
				"open_forward": open_forward,
			}
	# 前方スロットが全て接触範囲内なら、後方候補へ下がらず現在位置を保持する。
	# 空きができた次の再選択で、同じ式により前方進路を再試行する。
	if bias > Config.number("cpu_overtake_bias_threshold") and has_forward_slot and not has_open_forward_slot:
		return {
			"found": true,
			"name": "hold_current",
			"offset": M2TrackMath.clamp_offset(self_offset),
			"score": INF,
			"tie_rank": 99,
			"progress": self_race_progress,
			"hold_current": true,
		}
	return selected


## カーブ内側の短い走行距離を、CPUのライン候補スコアへ反映する。
## 直線(curvature=0)では全候補が0になり、内外差を発生させない。
## スタミナ・心拍・速度計算には使わず、既存の距離倍率だけを再利用する。
static func cpu_line_distance_advantage_score(offset: float, curvature: float) -> float:
	return (M2TrackMath.distance_multiplier(offset, curvature) - 1.0) \
		* Config.number("cpu_line_distance_advantage_weight")


static func _cpu_follow_slot_crowding(
	slot_progress: float,
	slot_offset: float,
	leader_id: String,
	others: Array
) -> float:
	var forward_range := Config.number("cpu_follow_slot_crowding_forward_range_m")
	var lateral_range := Config.number("cpu_follow_slot_crowding_lateral_range_m")
	var crowding := 0.0
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other: Dictionary = other_value
		if str(other.get("id", "")) == leader_id:
			continue
		var forward_nearness := maxf(0.0, 1.0 - absf(float(other.get("race_progress", other.get("progress", 0.0))) - slot_progress) / forward_range)
		var lateral_nearness := maxf(0.0, 1.0 - absf(float(other.get("offset", 0.0)) - slot_offset) / lateral_range)
		crowding += forward_nearness * lateral_nearness
	return crowding


## 追従スロット周辺の広い密度。対象数で分岐せず、近い走者の重なりを連続値で合成する。
static func _cpu_follow_slot_field_density(
	slot_progress: float,
	slot_offset: float,
	leader_id: String,
	others: Array
) -> float:
	var forward_range := Config.number("cpu_follow_slot_field_density_forward_range_m")
	var lateral_range := Config.number("cpu_follow_slot_field_density_lateral_range_m")
	var density := 0.0
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other: Dictionary = other_value
		if str(other.get("id", "")) == leader_id:
			continue
		var forward_nearness := maxf(
			0.0,
			1.0 - absf(float(other.get("race_progress", other.get("progress", 0.0))) - slot_progress) / forward_range
		)
		var lateral_nearness := maxf(
			0.0,
			1.0 - absf(float(other.get("offset", 0.0)) - slot_offset) / lateral_range
		)
		density += forward_nearness * lateral_nearness
	return density


## 候補位置の少し前方が空いているほど、前方スロットを選びやすくする。
static func _cpu_follow_slot_open_forward_score(
	slot_progress: float,
	slot_offset: float,
	leader_id: String,
	others: Array
) -> float:
	var probe_progress := slot_progress + Config.number("cpu_follow_slot_open_forward_distance_m")
	return clampf(
		1.0 - _cpu_follow_slot_field_density(probe_progress, slot_offset, leader_id, others),
		0.0,
		1.0
	)


static func cpu_follow_target_offset_m(
	current_target_offset: float,
	slot_offset: float,
	blend: float = -1.0
) -> float:
	var safe_blend := Config.number("cpu_follow_offset_blend") if blend < 0.0 else clampf(blend, 0.0, 1.0)
	return M2TrackMath.clamp_offset(lerpf(
		current_target_offset,
		M2TrackMath.clamp_offset(slot_offset),
		safe_blend
	))


## 大きな外回り候補だけを素早く横移動する。handling_multiplier は将来の操作性補正用。
static func cpu_line_move_speed_m_per_s(slot: Dictionary, handling_multiplier: float = 1.0) -> float:
	var multiplier := Config.number("cpu_overtake_escape_steer_speed_multiplier") if bool(slot.get("escape", false)) else 1.0
	return Config.number("cpu_steer_speed_m_per_s") * multiplier * maxf(handling_multiplier, 0.0)


static func cpu_trainer_profile(gate_index: int) -> Dictionary:
	var values := Config.values()
	var cycle: Array = values["cpu_trainer_profile_cycle"]
	var profile_id := str(cycle[posmod(gate_index - 1, cycle.size())])
	for profile_value in values["cpu_trainer_profiles"]:
		if profile_value is Dictionary and str(profile_value.get("id", "")) == profile_id:
			return profile_value.duplicate(true)
	return {}


static func cpu_trainer_settings() -> Dictionary:
	return {
		"min_target_speed_kmh": TARGET_SPEED_MIN_KMH,
		"min_drive_level": 1.0,
		"max_drive_level": DRIVE_LEVEL_MAX,
		"finish_start_progress": Config.number("cpu_trainer_finish_start_progress"),
		"finish_full_progress": Config.number("cpu_trainer_finish_full_progress"),
		"finish_chase_base_ratio": Config.number("cpu_trainer_finish_chase_base_ratio"),
		"finish_chase_position_ratio": Config.number("cpu_trainer_finish_chase_position_ratio"),
		"finish_chase_leader_gap_ratio": Config.number("cpu_trainer_finish_chase_leader_gap_ratio"),
		"cruise_reduction_max_kmh": Config.number("cpu_trainer_cruise_reduction_max_kmh"),
		"global_chase_pressure_max_kmh": Config.number("cpu_trainer_global_chase_pressure_max_kmh"),
		"global_gap_reference_m": Config.number("cpu_trainer_global_gap_reference_m"),
		"chase_urgency_gap_reference_m": Config.number("cpu_trainer_chase_urgency_gap_reference_m"),
		"field_pace_correction_max_kmh": Config.number("cpu_trainer_field_pace_correction_max_kmh"),
		"field_pace_reference_kmh": Config.number("cpu_trainer_field_pace_reference_kmh"),
		"closing_pressure_max_kmh": Config.number("cpu_trainer_closing_pressure_max_kmh"),
		"front_chase_pressure_max_kmh": Config.number("cpu_trainer_front_chase_pressure_max_kmh"),
		"closing_gap_reference_m": Config.number("cpu_trainer_closing_gap_reference_m"),
		"closing_speed_reference_kmh": Config.number("cpu_trainer_closing_speed_reference_kmh"),
		"reserve_max_kmh": Config.number("cpu_trainer_reserve_max_kmh"),
		"position_push_max_kmh": Config.number("cpu_trainer_position_push_max_kmh"),
		"finish_push_max_kmh": Config.number("cpu_trainer_finish_push_max_kmh"),
		"draft_saving_max_kmh": Config.number("cpu_trainer_draft_saving_max_kmh"),
		"low_stamina_saving_max_kmh": Config.number("cpu_trainer_low_stamina_saving_max_kmh"),
	}


static func heart_rate_rise_rate_for_drive_level(drive_level: float) -> float:
	var level := clampf(maxf(drive_level, 0.0), 0.0, float(DRIVE_LEVEL_MAX))
	var lower_index := mini(floori(level), int(DRIVE_LEVEL_MAX))
	var upper_index := mini(lower_index + 1, int(DRIVE_LEVEL_MAX))
	var blend := level - float(lower_index)
	var rates: Array = Config.values()["heart_rate_rise_rate_by_drive_level_bpm_per_s"]
	return lerpf(float(rates[lower_index]), float(rates[upper_index]), blend)


static func heart_rate_rise_time_s(cardio_stat: int) -> float:
	var cardio_ratio := clampf((float(cardio_stat) - 1.0) / 14.0, 0.0, 1.0)
	return lerpf(
		Config.number("heart_rate_rise_time_cardio_min_s"),
		Config.number("heart_rate_rise_time_cardio_max_s"),
		cardio_ratio
	)


static func heart_rate_recovery_time_s(cardio_stat: int) -> float:
	var cardio_ratio := clampf((float(cardio_stat) - 1.0) / 14.0, 0.0, 1.0)
	return lerpf(
		Config.number("heart_rate_recovery_time_cardio_min_s"),
		Config.number("heart_rate_recovery_time_cardio_max_s"),
		cardio_ratio
	)


static func heart_rate_rise_rate_bpm_per_s(drive_level: float, cardio_stat: int) -> float:
	if drive_level <= 0.0:
		return 0.0
	var reference_rate := heart_rate_rise_rate_for_drive_level(drive_level)
	return reference_rate * heart_rate_rise_time_s(5) / maxf(heart_rate_rise_time_s(cardio_stat), 0.001)


static func heart_rate_natural_recovery_rate_bpm_per_s(current_bpm: float, cardio_stat: int) -> float:
	var full_span := Config.number("heart_rate_overheat_max_bpm") - Config.number("heart_rate_min_bpm")
	var normalized_heart := clampf(
		(current_bpm - Config.number("heart_rate_min_bpm")) / maxf(full_span, 0.001),
		0.0,
		1.0
	)
	return heart_rate_recovery_rate_base_bpm_per_s(cardio_stat) * pow(
		normalized_heart,
		Config.number("heart_rate_recovery_exponent")
	)


static func heart_rate_net_rate_bpm_per_s(current_bpm: float, drive_level: float, cardio_stat: int) -> float:
	var drive_load := heart_rate_rise_rate_bpm_per_s(drive_level, cardio_stat) * Config.number("heart_rate_drive_load_scale")
	var net_rate := drive_load - heart_rate_natural_recovery_rate_bpm_per_s(current_bpm, cardio_stat)
	# 回復方向だけを倍率調整する。正ノッチの定常域と上昇カーブは変えず、
	# ノッチを下げたときは高心拍ほど速く戻り、100付近では指数的に穏やかに収束する。
	if net_rate < 0.0:
		net_rate *= Config.number("heart_rate_recovery_rate_scale")
	return net_rate


static func heart_rate_recovery_rate_base_bpm_per_s(cardio_stat: int) -> float:
	var heart_span := Config.number("heart_rate_normal_max_bpm") - Config.number("heart_rate_min_bpm")
	return heart_span / maxf(heart_rate_recovery_time_s(cardio_stat), 0.001)


static func overheat_ratio(heart_rate_bpm: float) -> float:
	return clampf(
		(heart_rate_bpm - Config.number("heart_rate_normal_max_bpm"))
		/ maxf(Config.number("heart_rate_overheat_max_bpm") - Config.number("heart_rate_normal_max_bpm"), 0.001),
		0.0,
		1.0
	)


static func overheat_stamina_multiplier(heart_rate_bpm: float) -> float:
	return lerpf(1.0, Config.number("overheat_stamina_multiplier_max"), overheat_ratio(heart_rate_bpm))


static func propulsion_efficiency(heart_rate_bpm: float) -> float:
	return lerpf(1.0, Config.number("overheat_propulsion_efficiency_min"), overheat_ratio(heart_rate_bpm))


static func stamina_debt_efficiency(stamina: float, stamina_stat: int) -> float:
	var debt_limit := Config.number("stamina_debt_limit")
	if stamina >= 0.0 or debt_limit <= 0.0:
		return 1.0
	var debt_ratio := clampf(-stamina / debt_limit, 0.0, 1.0)
	var stat_ratio := clampf((float(stamina_stat) - 1.0) / 14.0, 0.0, 1.0)
	var penalty_at_zero_stat := 1.0 - Config.number("stamina_debt_efficiency_min")
	var penalty := penalty_at_zero_stat * (
		1.0 - Config.number("stamina_debt_stat_mitigation_max") * stat_ratio
	)
	return clampf(1.0 - debt_ratio * penalty, Config.number("stamina_debt_efficiency_min"), 1.0)


static func stamina_consumption_per_s(
	drive_level: float,
	heart_rate_bpm: float = -1.0,
	stamina_stat: int = 5
) -> float:
	var level := clamp_drive_level(drive_level)
	if level <= 0.0:
		return 0.0
	var effort := level / float(DRIVE_LEVEL_MAX)
	var safe_heart := Config.number("heart_rate_min_bpm") if heart_rate_bpm < 0.0 else heart_rate_bpm
	var heart_ratio := clampf(
		(safe_heart - Config.number("heart_rate_min_bpm"))
		/ maxf(Config.number("heart_rate_normal_max_bpm") - Config.number("heart_rate_min_bpm"), 0.001),
		0.0,
		1.0
	)
	var heart_factor := lerpf(
		Config.number("stamina_heart_rate_factor_min"),
		Config.number("stamina_heart_rate_factor_max"),
		heart_ratio
	)
	var stamina_ratio := clampf((float(stamina_stat) - 1.0) / 14.0, 0.0, 1.0)
	var stamina_factor := 1.0 - Config.number("stamina_stat_mitigation_max") * stamina_ratio
	return lerpf(
		Config.number("stamina_consumption_min_per_s"),
		Config.number("stamina_consumption_max_per_s"),
		effort
	) * heart_factor * stamina_factor * overheat_stamina_multiplier(safe_heart)


static func stamina_delta_per_s(
	drive_level: float,
	heart_rate_bpm: float = -1.0,
	stamina_stat: int = 5
) -> float:
	return -stamina_consumption_per_s(drive_level, heart_rate_bpm, stamina_stat)


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


## 他走者の現在位置を通り抜けず、次フレームで進める最大の進捗。
## 前走者の手前で止めるだけで、接触後の強制位置補正は行わない。
static func allowed_race_progress(
	current_progress: float,
	proposed_progress: float,
	offset: float,
	others: Array
) -> float:
	var allowed := maxf(proposed_progress, current_progress)
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other_offset := float(other_value.get("offset", 0.0))
		if absf(offset - other_offset) >= BLOCK_LATERAL_M:
			continue
		var other_progress := float(other_value.get("race_progress", 0.0))
		if other_progress <= current_progress:
			continue
		allowed = minf(allowed, other_progress - CONTACT_LONGITUDINAL_M)
	return maxf(current_progress, allowed)


static func can_use_offset(progress: float, offset: float, others: Array) -> bool:
	for other_value in others:
		if not other_value is Dictionary:
			continue
		if contact_overlaps(
			progress,
			offset,
			float(other_value.get("race_progress", 0.0)),
			float(other_value.get("offset", 0.0))
		):
			return false
	return true


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


## 最内＝枠1。offset は負が内側。8プルを可動幅に等間隔。
static func starting_offset_for_gate(gate_index: int, field_size: int = FIELD_SIZE) -> float:
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	if field_size <= 1:
		return -max_abs
	var t := float(gate_index) / float(field_size - 1)
	return lerpf(-max_abs, max_abs, t)
