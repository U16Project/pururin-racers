extends RefCounted
## M4 集団プロトタイプの固定能力値とドラフト判定。
## 位置判定は設計案どおり distance / offset の自前判定だけで行う。

const M2TrackMath := preload("res://scripts/m2_track_math.gd")

const RACE_DISTANCE_M := 2000.0
const START_PATH_DISTANCE_M := 609.0
const GOAL_PATH_DISTANCE_M := 526.0
const NORMAL_SPEED_CAP_KMH := 80.0
const DRAFT_FORWARD_MIN_M := 0.5
const DRAFT_FORWARD_MAX_M := 8.0
const DRAFT_LATERAL_RANGE_M := 1.8
const DRAFT_ASSIST_MAX_KMH := 4.0
const CONTACT_LONGITUDINAL_M := 1.5
const CONTACT_LATERAL_M := 1.5
const PLAYER_INITIAL_SPEED_KMH := 70.0

const PROFILES := {
	"player": {
		"name": "あなた",
		"max_speed": 7,
		"acceleration": 6,
		"handling": 6,
		"contact_resistance": 5,
		"group_affinity": 5,
		"max_speed_kmh": 80.0,
	},
	"inner": {
		"name": "CPU・内側型",
		"max_speed": 6,
		"acceleration": 5,
		"handling": 9,
		"contact_resistance": 7,
		"group_affinity": 7,
		"max_speed_kmh": 65.0,
	},
	"outer": {
		"name": "CPU・外側型",
		"max_speed": 10,
		"acceleration": 8,
		"handling": 4,
		"contact_resistance": 3,
		"group_affinity": 2,
		"max_speed_kmh": 75.0,
	},
}

static func profile_for(role: String) -> Dictionary:
	return PROFILES.get(role, PROFILES["player"]).duplicate()

static func kmh_to_mps(speed_kmh: float) -> float:
	return speed_kmh / 3.6

static func clamp_target_speed_kmh(target_kmh: float, max_speed_kmh: float) -> float:
	return clampf(target_kmh, 48.0, minf(max_speed_kmh, NORMAL_SPEED_CAP_KMH))

static func step_target_speed_kmh(target_kmh: float, direction: float, max_speed_kmh: float) -> float:
	return clamp_target_speed_kmh(target_kmh + direction, max_speed_kmh)

static func follow_speed_kmh(current_kmh: float, target_kmh: float, delta: float, acceleration: int) -> float:
	if delta <= 0.0:
		return current_kmh
	var max_step := (12.0 + float(acceleration)) * delta
	return move_toward(current_kmh, target_kmh, max_step)

static func forward_gap(self_distance: float, other_distance: float, path_length: float) -> float:
	return fposmod(other_distance - self_distance, path_length)

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
		if absf(self_offset - entry.get("offset", 0.0)) > DRAFT_LATERAL_RANGE_M:
			continue
		if gap < best_gap:
			best_gap = gap
			leader = entry
	return leader

static func draft_assist_target_kmh(
	desired_kmh: float,
	leader_speed_kmh: float,
	group_affinity: int,
	max_speed_kmh: float
) -> float:
	if leader_speed_kmh < 0.0 or group_affinity <= 0:
		return desired_kmh
	var assist := minf(
		DRAFT_ASSIST_MAX_KMH,
		DRAFT_ASSIST_MAX_KMH * float(group_affinity) / 10.0
	)
	# 先行者が遅くても、ドラフトが追従を強制して減速させてはいけない。
	# 追いついた後の接触・追い抜き判断は別の位置取り処理で扱う。
	return clamp_target_speed_kmh(desired_kmh + assist, max_speed_kmh)

static func contact_overlaps(
	first_progress: float,
	first_offset: float,
	second_progress: float,
	second_offset: float
) -> bool:
	return (
		absf(first_progress - second_progress) < CONTACT_LONGITUDINAL_M
		and absf(first_offset - second_offset) < CONTACT_LATERAL_M
	)

static func centerline_delta_from_kmh(speed_kmh: float, delta: float, offset: float, curvature: float) -> float:
	return kmh_to_mps(speed_kmh) * delta / M2TrackMath.distance_multiplier(offset, curvature)


static func format_race_time(seconds: float) -> String:
	var safe_seconds := maxf(seconds, 0.0)
	var minutes := int(safe_seconds / 60.0)
	var remaining := fmod(safe_seconds, 60.0)
	if minutes > 0:
		return "%d:%04.1f" % [minutes, remaining]
	return "%.1f" % remaining
