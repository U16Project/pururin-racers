extends RefCounted
## ローカル簡易レース用の定数・進捗・前方ブロック（検討事項 #23／速度は #24）。
## 速度の単位は km/h。Path（メートル）を進めるときだけ ÷3.6 する。


const Config := preload("res://scripts/config/local_race_config.gd")
const CourseLayout := preload("res://scripts/m5_course_builder.gd")
const DraftRules := preload("res://scripts/config/m5_draft_rules.gd")
const RaceSession := preload("res://scripts/race_session.gd")

const M2TrackMath := preload("res://scripts/m2_track_math.gd")

## ローカル2000mは M5 共有コース定義を正本にする。
const RACE_DISTANCE_M := 2000.0

static var _course_layout: Dictionary = {}

## 初期化時に使う自然最高速の既定値。出力走行のハード上限ではない。
static var PLAYER_MAX_SPEED_KMH: float:
	get:
		return TOP_SPEED_NATURAL_MAX_KMH

## M5.1 出力操作実験。出力は整数ノッチだが、入力は長押しでリピートする。
## ノッチは0（ニュートラル）〜最大。制動はノッチではなく別のブレーキ操作で行う。
const DRIVE_LEVEL_MIN := 0.0
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
static var AERO_AIR_RESISTANCE_REFERENCE_STAT: int:
	get:
		return int(Config.number("aero_air_resistance_reference_stat"))
static var AERO_AIR_RESISTANCE_MULTIPLIER_PER_STAT: float:
	get:
		return Config.number("aero_air_resistance_multiplier_per_stat")
## ノッチごとの駆動力。速度帯を持たず、抵抗との差分だけで加減速する。
## 低ノッチは低速域でわずかに加速しつつ、高速域では抵抗に負ける。
## 値は「ノッチ × 一律係数」よりも、操作感を調整しやすい小さなカーブとして管理する。
static var DRIVE_FORCE_BY_LEVEL_KMH_PER_S: Array:
	get:
		return Config.values()["drive_force_by_level_kmh_per_s"]
## ブレーキ操作を押している間の制動（km/h/s）。ノッチの設定とは独立で、離すと元のノッチへ戻る。
static var BRAKE_DECELERATION_KMH_PER_S: float:
	get:
		return Config.number("brake_deceleration_kmh_per_s")
static var DRAFT_SPEED_BONUS_MAX_KMH: float:
	get:
		return DraftRules.number("assist_max_kmh")
static var DRAFT_CHAIN_ATTENUATION: float:
	get:
		return DraftRules.number("chain_attenuation")
static var DRAFT_FORWARD_MIN_M: float:
	get:
		return DraftRules.number("forward_min_m")
static var DRAFT_AIR_RESISTANCE_FACTOR: float:
	get:
		return Config.number("draft_air_resistance_factor")
## 応答曲線の基準を、HUD表示の基準（真後ろ1走者のwake）の何倍に置くか。
## 大きいほど、少ない頭数ではドラフトが効きにくく、大きな集団で伸びる。
static var DRAFT_RESPONSE_REFERENCE_SCALE: float:
	get:
		return Config.number("draft_response_reference_scale")
## 後ろの走者から受ける効果（後方支援）。後方の範囲、最大の減り、空力1点あたりの倍率差。
## 前の走者にふさがれている間、出力上の速度が実際の速度を上回れる最大の差（km/h）。
## 操作性ステータスによる、左右のライン移動の速さの倍率（基準値で1.0）。
static var HANDLING_STEER_REFERENCE_STAT: int:
	get:
		return int(Config.number("handling_steer_reference_stat"))
static var HANDLING_STEER_MULTIPLIER_PER_STAT: float:
	get:
		return Config.number("handling_steer_multiplier_per_stat")
## 横の接触（並走）の負荷。接触耐性が低いほど大きい。前後の接触は対象外。
static var CONTACT_TOUCH_MARGIN_M: float:
	get:
		return Config.number("contact_touch_margin_m")
static var CONTACT_HEART_LOAD_BPM_PER_S: float:
	get:
		return Config.number("contact_heart_load_bpm_per_s")
static var CONTACT_STAMINA_LOAD_L_PER_S: float:
	get:
		return Config.number("contact_stamina_load_l_per_s")
static var CONTACT_RESISTANCE_REFERENCE_STAT: int:
	get:
		return int(Config.number("contact_resistance_reference_stat"))
static var CONTACT_RESISTANCE_MULTIPLIER_PER_STAT: float:
	get:
		return Config.number("contact_resistance_multiplier_per_stat")
## 押し合い（横に動いて他の走者に重なったときの勝負）。
static var PUSH_STRENGTH_PER_STAT: float:
	get:
		return Config.number("push_strength_per_stat")
static var PUSH_INTENT_MULTIPLIER: float:
	get:
		return Config.number("push_intent_multiplier")
static var PUSH_PASSIVE_MULTIPLIER: float:
	get:
		return Config.number("push_passive_multiplier")
static var PUSH_LOAD_MULTIPLIER: float:
	get:
		return Config.number("push_load_multiplier")
const PUSH_PASSES := 4
## 同時に数える接触の最大人数（左右）。
const CONTACT_COUNT_MAX := 2
static var BLOCKED_SPEED_EXCESS_MAX_KMH: float:
	get:
		return Config.number("blocked_speed_excess_max_kmh")
static var REAR_ASSIST_RANGE_M: float:
	get:
		return Config.number("rear_assist_range_m")
static var REAR_ASSIST_TRANSFER_RATE: float:
	get:
		return Config.number("rear_assist_transfer_rate")
static var REAR_ASSIST_AERO_MULTIPLIER_PER_STAT: float:
	get:
		return Config.number("rear_assist_aero_multiplier_per_stat")
static var DRAFT_RESPONSE_EXPONENT: float:
	get:
		return Config.number("draft_response_exponent")
static var DRAFT_AGGREGATION_EXPONENT: float:
	get:
		return Config.number("draft_aggregation_exponent")
static var PACK_DRAFT_EFFECTIVE_REFERENCE_STAT: int:
	get:
		return int(Config.number("pack_draft_effective_reference_stat"))
static var PACK_DRAFT_EFFECTIVE_MULTIPLIER_PER_STAT: float:
	get:
		return Config.number("pack_draft_effective_multiplier_per_stat")
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

## 接触箱。寸法はローカルレース設定で調整する。
static var BLOCK_LATERAL_M: float:
	get:
		return Config.number("contact_lateral_range_m")
static var CONTACT_LONGITUDINAL_M: float:
	get:
		return Config.number("contact_longitudinal_range_m")
static var BLOCK_APPROACH_RATE_PER_S: float:
	get:
		return Config.number("block_approach_rate_per_s")

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
	return start_path_for_distance_m(RaceSession.selected_distance_m())


static func start_path_for_distance_m(distance_m: float) -> float:
	var route := CourseLayout.route_for_distance(course_layout(), distance_m)
	return float(route.get("start_mainline_m", 0.0))


static func race_distance_m() -> float:
	return RaceSession.selected_distance_m()


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


static func clamp_drive_level(level: float) -> float:
	return clampf(level, float(DRIVE_LEVEL_MIN), float(DRIVE_LEVEL_MAX))


static func step_drive_level(level: float, direction: float) -> float:
	var sign_direction := signf(direction)
	if is_zero_approx(sign_direction):
		return clamp_drive_level(level)
	return clamp_drive_level(level + sign_direction * DRIVE_LEVEL_STEP)


static func drive_force_kmh_per_s(drive_level: float, acceleration_bonus_kmh_per_s: float = 0.0) -> float:
	# 負ノッチは制動側で扱う。配列の末尾参照にならないよう0未満を0にする。
	var level_index := maxi(int(round(clamp_drive_level(drive_level))), 0)
	return maxf(float(DRIVE_FORCE_BY_LEVEL_KMH_PER_S[level_index]) + acceleration_bonus_kmh_per_s, 0.0)


## 出力走行の内訳。HUD・ログ・速度更新が同じ計算結果を使う。
static func drive_diagnostics_kmh_per_s(
	speed_kmh: float,
	drive_level: float,
	draft_factor: float = 0.0,
	acceleration_bonus_kmh_per_s: float = 0.0,
	top_speed_drive_adjustment_kmh_per_s: float = 0.0,
	propulsion_efficiency: float = 1.0,
	air_resistance_multiplier: float = 1.0,
	acceleration_response_multiplier: float = 1.0,
	braking: bool = false
) -> Dictionary:
	var level := clamp_drive_level(drive_level)
	var drive_contribution := 0.0
	if braking:
		# ブレーキ中は推進力の代わりに制動寄与を負値で入れる。
		drive_contribution = -BRAKE_DECELERATION_KMH_PER_S
	elif level > 0.0:
		drive_contribution = drive_force_kmh_per_s(level, acceleration_bonus_kmh_per_s) + top_speed_drive_adjustment_kmh_per_s
	if drive_contribution > 0.0:
		drive_contribution *= clampf(propulsion_efficiency, 0.0, 1.0)
	var safe_speed := maxf(speed_kmh, MIN_SPEED_KMH)
	var rolling_resistance := ROLLING_RESISTANCE_KMH_PER_S
	var safe_air_multiplier := maxf(air_resistance_multiplier, 0.0)
	var air_resistance := AIR_RESISTANCE_QUADRATIC_COEFFICIENT * safe_speed * safe_speed * safe_air_multiplier
	var draft_reduction := air_resistance * clampf(draft_factor, 0.0, 1.0)
	var net_acceleration := drive_contribution - rolling_resistance - air_resistance + draft_reduction
	# 加速適性は正ノッチで速度が増える場合だけに効く。釣り合い・減速は変えない。
	var response := maxf(acceleration_response_multiplier, 0.0) if level > 0.0 and not braking and net_acceleration > 0.0 else 1.0
	return {
		"drive_contribution_kmh_per_s": drive_contribution,
		"rolling_resistance_kmh_per_s": rolling_resistance,
		"air_resistance_multiplier": safe_air_multiplier,
		"air_resistance_kmh_per_s": air_resistance,
		"draft_air_reduction_kmh_per_s": draft_reduction,
		"net_force_acceleration_kmh_per_s": net_acceleration,
		"acceleration_response_multiplier": response,
		"acceleration_response_bonus_kmh_per_s": net_acceleration * (response - 1.0),
		"total_acceleration_kmh_per_s": net_acceleration * response,
	}


static func drive_resistance_kmh_per_s(
	speed_kmh: float,
	draft_factor: float = 0.0,
	air_resistance_multiplier: float = 1.0
) -> float:
	var diagnostics := drive_diagnostics_kmh_per_s(speed_kmh, 0.0, draft_factor, 0.0, 0.0, 1.0, air_resistance_multiplier)
	return float(diagnostics["rolling_resistance_kmh_per_s"]) + float(diagnostics["air_resistance_kmh_per_s"]) - float(diagnostics["draft_air_reduction_kmh_per_s"])


## 横に並んで接している走者の数（0〜2）。前後の差が接触範囲（前後）内で、横の差が接触範囲（横）以上
## 〜 接触範囲＋余裕の幅の間にいる走者が対象。同じライン上の前後の接触（横の差が範囲内）は数えない。
static func lateral_contact_count(snapshot: Array, index: int) -> int:
	if index < 0 or index >= snapshot.size() or not snapshot[index] is Dictionary:
		return 0
	var me: Dictionary = snapshot[index]
	var count := 0
	for other_index in snapshot.size():
		if other_index == index or not snapshot[other_index] is Dictionary:
			continue
		var other: Dictionary = snapshot[other_index]
		var gap := absf(float(me.get("race_progress", me.get("progress", 0.0))) - float(other.get("race_progress", other.get("progress", 0.0))))
		var side := absf(float(me.get("offset", 0.0)) - float(other.get("offset", 0.0)))
		if gap < CONTACT_LONGITUDINAL_M and side >= BLOCK_LATERAL_M - 0.0001 and side < BLOCK_LATERAL_M + CONTACT_TOUCH_MARGIN_M:
			count += 1
	return mini(count, CONTACT_COUNT_MAX)


## 押し合いの強さ。接触耐性が基準で、相手の方向へ動こうとしていれば大きく、そうでなければ小さい。
static func push_strength(contact_resistance_stat: int, moving_toward_other: bool) -> float:
	var stat := clampi(contact_resistance_stat, 1, 15)
	var base := maxf(0.2, 1.0 + PUSH_STRENGTH_PER_STAT * (stat - CONTACT_RESISTANCE_REFERENCE_STAT))
	return base * (PUSH_INTENT_MULTIPLIER if moving_toward_other else PUSH_PASSIVE_MULTIPLIER)


## 体は楕円（前後 CONTACT_LONGITUDINAL_M × 横 BLOCK_LATERAL_M）。
## 横の差がこの値のとき、前後に最低限あけるべき間隔。横の差が範囲以上なら 0。
static func required_longitudinal_gap(lateral_diff: float) -> float:
	var ratio := absf(lateral_diff) / BLOCK_LATERAL_M
	if ratio >= 1.0:
		return 0.0
	return CONTACT_LONGITUDINAL_M * sqrt(1.0 - ratio * ratio)


## 前後の差がこの値のとき、横に最低限あけるべき間隔。前後の差が範囲以上なら 0。
static func required_lateral_gap(longitudinal_diff: float) -> float:
	var ratio := absf(longitudinal_diff) / CONTACT_LONGITUDINAL_M
	if ratio >= 1.0:
		return 0.0
	return BLOCK_LATERAL_M * sqrt(1.0 - ratio * ratio)


static func _entries_overlap(a_progress: float, a_offset: float, b_progress: float, b_offset: float) -> bool:
	return absf(a_offset - b_offset) < required_lateral_gap(a_progress - b_progress)


## 横に動く前に、勝ち負けを決める。
## 新しい横位置が、前のフレームの位置にいる走者の体に入るとき、自分の強さ（相手の方向へ動いている）が
## 相手の強さ（止まっている）以下なら、体の縁で止める。強ければそのまま入り、あとで相手が押し出される。
## others の各要素: {race_progress, offset, contact_resistance}。
static func limit_offset_by_stronger_neighbors(
	previous_offset: float,
	new_offset: float,
	progress: float,
	own_contact_resistance: int,
	others: Array
) -> float:
	var result := new_offset
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other_offset := float(other_value.get("offset", 0.0))
		var longitudinal_diff := progress - float(other_value.get("race_progress", 0.0))
		var required := required_lateral_gap(longitudinal_diff)
		if absf(result - other_offset) >= required:
			continue
		# すでに重なっている相手との勝負は、動いたあとの押し合いに任せる。
		if absf(previous_offset - other_offset) < required:
			continue
		var own_power := push_strength(own_contact_resistance, true)
		var other_power := push_strength(int(other_value.get("contact_resistance", 5)), false)
		if own_power > other_power:
			continue
		var side := 1.0 if previous_offset >= other_offset else -1.0
		result = other_offset + side * required
	return result


## 横に動いたあとの重なりを、押し合いの勝負で解く。
## entries の各要素: {id, progress, offset(動いたあと), old_offset(動く前), intent(-1/0/+1: 横に動こうとした向き), stat(接触耐性)}。
## 強い方が勝ち。勝った方は動いたまま、弱い方が重なり全部だけ押し出される。同じ強さなら、どちらも動く前の位置へ戻る。
## 壁で押し出せなかった分は、勝った方が戻される（動く前の位置までが限度）。
## 押し出された走者が次の走者と重なれば、その二人で同じ勝負をする（最大 PUSH_PASSES 回）。壁は押せない。
## 戻り値: {"offsets": {id: 横位置}, "contest_ids": 勝負が起きた走者のID}
static func resolve_lateral_pushes(entries: Array) -> Dictionary:
	var count := entries.size()
	var pos: Array[float] = []
	var intent: Array[int] = []
	for entry in entries:
		pos.append(float(entry["offset"]))
		intent.append(int(entry.get("intent", 0)))
	var contest := {}
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	for pass_index in PUSH_PASSES:
		var correction: Array[float] = []
		correction.resize(count)
		correction.fill(0.0)
		var any := false
		for i in count:
			for j in range(i + 1, count):
				if not _entries_overlap(float(entries[i]["progress"]), pos[i], float(entries[j]["progress"]), pos[j]):
					continue
				any = true
				contest[str(entries[i]["id"])] = true
				contest[str(entries[j]["id"])] = true
				var direction := 1 if pos[j] >= pos[i] else -1
				var overlap := required_lateral_gap(float(entries[i]["progress"]) - float(entries[j]["progress"])) - absf(pos[j] - pos[i])
				var power_i := push_strength(int(entries[i].get("stat", 5)), intent[i] == direction)
				var power_j := push_strength(int(entries[j].get("stat", 5)), intent[j] == -direction)
				# 勝者 winner（強い方）と敗者 loser。同じ強さなら i を押した側とみなす。
				var winner := i if power_i >= power_j else j
				var loser := j if winner == i else i
				var loser_away := direction if winner == i else -direction  # 敗者が押される向き
				var margin := absf(power_i - power_j) / maxf(power_i + power_j, 0.0001)
				# 強さに差があれば、勝者は動かず、敗者が重なり全部を押し出される。同じ強さなら、どちらも戻る。
				var push := overlap if margin > 0.0001 else 0.0
				var retreat := overlap - push
				# 敗者は壁の先へは押せない。押せなかった分は、勝者がさらに戻される。
				var loser_target := clampf(pos[loser] + correction[loser] + loser_away * push, -max_abs, max_abs)
				var pushed := (loser_target - pos[loser] - correction[loser]) * loser_away
				retreat += maxf(push - pushed, 0.0)
				correction[loser] += loser_away * maxf(pushed, 0.0)
				# 勝者が戻れるのは、動く前の位置まで。戻りきれない分は、敗者がさらに押される。
				var winner_away := -loser_away
				var room := maxf((float(entries[winner]["old_offset"]) - pos[winner] - correction[winner]) * winner_away, 0.0)
				var actual_retreat := minf(retreat, room)
				correction[winner] += winner_away * actual_retreat
				var leftover := retreat - actual_retreat
				if leftover > 0.0001:
					var extra_target := clampf(pos[loser] + correction[loser] + loser_away * leftover, -max_abs, max_abs)
					correction[loser] += extra_target - pos[loser] - correction[loser]
		if not any:
			break
		for k in count:
			if not is_zero_approx(correction[k]):
				# 押し出された走者は、その向きへ動いている扱いにする（次の勝負で強さに効く）。
				intent[k] = 1 if correction[k] > 0.0 else -1
			pos[k] = clampf(pos[k] + correction[k], -max_abs, max_abs)
	# 解けなかった重なりは、動く前の位置へ戻す（重なりを増やさない）。
	for i in count:
		for j in range(i + 1, count):
			if _entries_overlap(float(entries[i]["progress"]), pos[i], float(entries[j]["progress"]), pos[j]):
				pos[i] = float(entries[i]["old_offset"])
				pos[j] = float(entries[j]["old_offset"])
	var offsets := {}
	for k in count:
		offsets[str(entries[k]["id"])] = pos[k]
	return {"offsets": offsets, "contest_ids": contest.keys()}


## 接触耐性による負荷の倍率（基準値で1.0、高いほど小さい）。
static func contact_resistance_multiplier(contact_resistance_stat: int = 5) -> float:
	var stat := clampi(contact_resistance_stat, 1, 15)
	return maxf(0.2, 1.0 - CONTACT_RESISTANCE_MULTIPLIER_PER_STAT * (stat - CONTACT_RESISTANCE_REFERENCE_STAT))


static func contact_heart_load_bpm_per_s(contact_count: int, contact_resistance_stat: int = 5) -> float:
	return float(clampi(contact_count, 0, CONTACT_COUNT_MAX)) * CONTACT_HEART_LOAD_BPM_PER_S * contact_resistance_multiplier(contact_resistance_stat)


static func contact_stamina_load_l_per_s(contact_count: int, contact_resistance_stat: int = 5) -> float:
	return float(clampi(contact_count, 0, CONTACT_COUNT_MAX)) * CONTACT_STAMINA_LOAD_L_PER_S * contact_resistance_multiplier(contact_resistance_stat)


## 操作性は左右のライン移動の速さだけを連続的に補正する。プレイヤーとCPUに共通。
static func handling_steer_multiplier(handling_stat: int = 5) -> float:
	var stat := clampi(handling_stat, 1, 15)
	return maxf(0.1, 1.0 + HANDLING_STEER_MULTIPLIER_PER_STAT * (stat - HANDLING_STEER_REFERENCE_STAT))


## 空力適性は二乗空気抵抗だけを連続的に補正する。基準値では現行抵抗と同じ。
static func aero_air_resistance_multiplier(aero_stat: int = 5) -> float:
	var stat := clampi(aero_stat, 1, 15)
	return maxf(0.0, 1.0 - AERO_AIR_RESISTANCE_MULTIPLIER_PER_STAT * (stat - AERO_AIR_RESISTANCE_REFERENCE_STAT))


## 集団適性は生の受取率や対象判定を変えず、応答曲線後の実効率だけを連続的に補正する。
static func pack_draft_effective_multiplier(pack_stat: int = 5) -> float:
	var stat := clampi(pack_stat, 1, 15)
	return maxf(0.0, 1.0 + PACK_DRAFT_EFFECTIVE_MULTIPLIER_PER_STAT * (stat - PACK_DRAFT_EFFECTIVE_REFERENCE_STAT))


## 基準速度時に1走者が真後ろへ作る wake を単位として、
## 生の受取率をローカル走行へ載せる実効率へ変換する共通カーブ。
## 受取率は丸めない。実効率は x / (1 + x) で、増えるほど1へ近づく。
static func draft_response_reference_p() -> float:
	return DraftRules.wake_reference_p()


static func draft_effective_ratio(received_draft_p: float, pack_stat: int = 5) -> float:
	var normalized := maxf(0.0, received_draft_p) / (draft_response_reference_p() * DRAFT_RESPONSE_REFERENCE_SCALE)
	var base_ratio := pow(normalized, DRAFT_RESPONSE_EXPONENT)
	var scaled := base_ratio * pack_draft_effective_multiplier(pack_stat)
	return scaled / (1.0 + scaled)


## 個別のドラフト寄与を p ノルムで合成する。対象数ごとの分岐・合算上限は持たない。
static func draft_aggregate_contributions_p(contributions: Array) -> float:
	var powered_sum := 0.0
	for contribution in contributions:
		powered_sum += pow(maxf(0.0, float(contribution)), DRAFT_AGGREGATION_EXPONENT)
	return pow(powered_sum, 1.0 / DRAFT_AGGREGATION_EXPONENT) if powered_sum > 0.0 else 0.0


static func draft_air_resistance_factor(received_draft_p: float, pack_stat: int = 5) -> float:
	return DRAFT_AIR_RESISTANCE_FACTOR * draft_effective_ratio(received_draft_p, pack_stat)


static func draft_assist_speed_kmh(received_draft_p: float, pack_stat: int = 5) -> float:
	"""ローカル目標速度方式の受取率→速度補助。通常ノッチ方式では診断用。"""
	return DRAFT_SPEED_BONUS_MAX_KMH * draft_effective_ratio(received_draft_p, pack_stat)


static func draft_wake_from_speed(speed_kmh: float) -> float:
	var base := DraftRules.number("wake_base_p")
	var reference := DraftRules.number("wake_speed_reference_kmh")
	var gain := DraftRules.number("wake_speed_gain_p")
	return base + maxf(0.0, speed_kmh) / reference * gain


## 後ろの走者から前の走者が受ける効果。後方 DRAFT_FORWARD_MIN_M〜REAR_ASSIST_RANGE_M、
## 横ずれ DRAFT_LATERAL_RANGE_M 以内の全走者から、離れ具合に応じて直接受ける。連鎖はしない。
## 元になる値は後ろの走者の wake（出力上の速度から決まる）で、実際に進めた速さではない。
## 出力上の速度が、実際の速度を max_excess 以上は上回らないようにする。最低速度は下回らない。
static func limit_speed_excess_kmh(output_kmh: float, actual_kmh: float, max_excess_kmh: float) -> float:
	return maxf(minf(output_kmh, actual_kmh + maxf(max_excess_kmh, 0.0)), MIN_SPEED_KMH)


static func calculate_rear_assist_details(snapshot: Array, index: int) -> Dictionary:
	var result := {"rear_assist_p": 0.0, "rear_source_ids": []}
	if index < 0 or index >= snapshot.size() or not snapshot[index] is Dictionary:
		return result
	var receiver: Dictionary = snapshot[index]
	var receiver_progress := float(receiver.get("race_progress", receiver.get("progress", 0.0)))
	var contributions: Array = []
	var ids: Array = []
	for source_index in snapshot.size():
		if source_index == index or not snapshot[source_index] is Dictionary:
			continue
		var source: Dictionary = snapshot[source_index]
		var behind := receiver_progress - float(source.get("race_progress", source.get("progress", 0.0)))
		var line_gap := absf(float(receiver.get("offset", 0.0)) - float(source.get("offset", 0.0)))
		if behind < DRAFT_FORWARD_MIN_M or behind > REAR_ASSIST_RANGE_M or line_gap > DRAFT_LATERAL_RANGE_M:
			continue
		var source_wake := float(source.get("own_wake_p", 0.0))
		if source_wake <= 0.0:
			source_wake = draft_wake_from_speed(float(source.get("speed", 0.0)))
		var lateral_falloff := pow(1.0 - line_gap / DRAFT_LATERAL_RANGE_M, DRAFT_LATERAL_FALLOFF_EXPONENT)
		var strength := maxf(0.0, source_wake) * (1.0 - behind / REAR_ASSIST_RANGE_M) * lateral_falloff
		if strength > 0.0:
			contributions.append(strength)
			ids.append(str(source.get("id", source.get("name", source_index))))
	result["rear_assist_p"] = draft_aggregate_contributions_p(contributions)
	result["rear_source_ids"] = ids
	return result


## 空力が高いほど、後方支援を多く受ける。空力5が標準。
static func rear_assist_aero_multiplier(aero_stat: int = 5) -> float:
	var stat := clampi(aero_stat, 1, 15)
	return maxf(0.0, 1.0 + REAR_ASSIST_AERO_MULTIPLIER_PER_STAT * (stat - AERO_AIR_RESISTANCE_REFERENCE_STAT))


## 後方支援の受取量 → 空気抵抗の減る割合。REAR_ASSIST_TRANSFER_RATE が最大の減り。
static func rear_assist_air_factor(rear_assist_p: float, aero_stat: int = 5) -> float:
	var normalized := maxf(0.0, rear_assist_p) / draft_response_reference_p() * rear_assist_aero_multiplier(aero_stat)
	return REAR_ASSIST_TRANSFER_RATE * normalized / (1.0 + normalized)


## ドラフトと後方支援の減る割合を合成する。どちらも1未満なら結果も1未満で、空気抵抗はマイナスにならない。
static func combined_air_reduction_factor(draft_factor: float, rear_factor: float) -> float:
	return 1.0 - (1.0 - clampf(draft_factor, 0.0, 1.0)) * (1.0 - clampf(rear_factor, 0.0, 1.0))


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
		source_wake = maxf(0.0, source_wake)
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
		var source_previous := maxf(0.0, float(source_state.get("direct_draft_p", 0.0)) + float(source_state.get("chain_draft_p", 0.0)))
		var chain_lateral_falloff := pow(1.0 - float(source["line"]) / DRAFT_LATERAL_RANGE_M, DRAFT_LATERAL_FALLOFF_EXPONENT)
		var chain_strength := source_previous * DRAFT_CHAIN_ATTENUATION * (1.0 - float(source["gap"]) / DRAFT_FORWARD_MAX_M) * chain_lateral_falloff
		if chain_strength > 0.0:
			chain_sources.append(str(source["id"]))
			chain_contributions.append(chain_strength)
	var chain := draft_aggregate_contributions_p(chain_contributions)
	var received := direct + chain
	var primary: Dictionary = direct_details[0]
	return {
		"own_wake_p": own_wake,
		"direct_draft_p": direct,
		"chain_draft_p": chain,
		"received_draft_p": received,
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
	propulsion_efficiency: float = 1.0,
	air_resistance_multiplier: float = 1.0,
	acceleration_response_multiplier: float = 1.0,
	simulation_legacy_speed_cap: bool = false,
	braking: bool = false
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
		propulsion_efficiency,
		air_resistance_multiplier,
		acceleration_response_multiplier,
		braking
	)
	var next_speed := current_kmh + float(diagnostics["total_acceleration_kmh_per_s"]) * delta
	# 通常は自然到達速度で切らない。旧挙動の比較測定時だけ明示的に上限を再現する。
	if simulation_legacy_speed_cap:
		return clampf(next_speed, MIN_SPEED_KMH, maxf(max_speed_kmh, MIN_SPEED_KMH))
	return maxf(next_speed, MIN_SPEED_KMH)


static func top_speed_natural_speed_kmh(top_speed: int) -> float:
	return lerpf(TOP_SPEED_NATURAL_MIN_KMH, TOP_SPEED_NATURAL_MAX_KMH, (clampi(top_speed, 1, 15) - 1) / 14.0)


## ノッチ6・空力5・ドラフトなしでは、各最高速値の自然到達速度で推進力と抵抗が釣り合う。
## 補正は速度の二乗に応じて現れる。空力は、実際に残る空気抵抗と同じ割合で入れる。
## ドラフトは補正に含めない。軽くなった空気抵抗の分だけ、速度は自然に自然最高速を超えて伸びる。
static func top_speed_drive_adjustment_kmh_per_s(
	speed_kmh: float,
	drive_level: float,
	top_speed: int,
	air_resistance_multiplier: float = 1.0
) -> float:
	var level := clamp_drive_level(drive_level)
	if level <= 0.0:
		return 0.0
	var max_drive_force := drive_force_kmh_per_s(DRIVE_LEVEL_MAX)
	var level_force := drive_force_kmh_per_s(level)
	var natural_speed := top_speed_natural_speed_kmh(top_speed)
	var safe_air_multiplier := maxf(air_resistance_multiplier, 0.0)
	var force_at_natural_speed := ROLLING_RESISTANCE_KMH_PER_S + AIR_RESISTANCE_QUADRATIC_COEFFICIENT * natural_speed * natural_speed * safe_air_multiplier
	var level_share := level_force / maxf(max_drive_force, 0.001)
	var speed_ratio := maxf(speed_kmh, MIN_SPEED_KMH) / maxf(natural_speed, 0.001)
	return (force_at_natural_speed - max_drive_force) * level_share * speed_ratio * speed_ratio


static func stat_acceleration_force_bonus_kmh_per_s(acceleration: int) -> float:
	# 旧モデル比較用。現行設定では係数0で、常時推進加算を無効にする。
	return (acceleration - 5) * ACCELERATION_DRIVE_FORCE_BONUS_PER_STAT_KMH_PER_S


static func stat_acceleration_response_multiplier(acceleration: int) -> float:
	return 1.0 + Config.number("acceleration_response_multiplier_per_stat") * (clampi(acceleration, 1, 15) - 5)




static func cpu_steer_reselect_interval_s(random_unit: float) -> float:
	return lerpf(
		Config.number("cpu_steer_reselect_min_s"),
		Config.number("cpu_steer_reselect_max_s"),
		clampf(random_unit, 0.0, 1.0)
	)


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
		M2TrackMath.clamp_offset(lerpf(
			current,
			preferred_line,
			Config.number("cpu_follow_slot_inner_midpoint_blend")
		)),
		-max_abs,
		max_abs,
	]
	var best_score := INF
	var selected_offset := current
	for offset_value in candidate_offsets:
		var slot_offset := M2TrackMath.clamp_offset(float(offset_value))
		var inner_distance := absf(slot_offset - preferred_line) / max_abs
		var field_density := _cpu_follow_slot_field_density(
			self_race_progress, slot_offset, "", others
		)
		var open_forward := _cpu_follow_slot_open_forward_score(
			self_race_progress, slot_offset, "", others
		)
		# 空き、内側志向、カーブの距離差を同じ式で評価する。
		# 開始時だけの特例や、横移動そのものを抑える係数は持たない。
		var score := field_density * Config.number("cpu_follow_slot_field_density_weight") \
			+ inner_distance * Config.number("cpu_follow_slot_inner_bias") \
			+ cpu_line_distance_advantage_score(slot_offset, curvature) \
			- open_forward * Config.number("cpu_follow_slot_open_forward_weight") * maxf(overtake_bias, 0.0)
		# 同点なら候補列の先頭（現在ライン）を優先する。
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
	curvature: float = 0.0,
	line_pref: float = -1.0
) -> Dictionary:
	if not bool(follow_candidate.get("found", false)):
		return {"found": false}
	var leader_offset := M2TrackMath.clamp_offset(float(follow_candidate.get("offset", 0.0)))
	var leader_progress := float(follow_candidate.get("race_progress", self_race_progress))
	var leader_id := str(follow_candidate.get("id", ""))
	var preferred_gap := Config.number("cpu_follow_preferred_gap_m")
	var slot_progress := leader_progress - preferred_gap
	var spacing := Config.number("cpu_follow_slot_lateral_spacing_m")
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	var inside_reference := Config.number("cpu_inward_target_offset_m")
	var slots := [
		{"name": "center", "offset": leader_offset, "progress": slot_progress, "tie_rank": 1, "forward": false},
		{"name": "inner", "offset": leader_offset - spacing, "progress": slot_progress, "tie_rank": 0, "forward": false},
		{"name": "outer", "offset": leader_offset + spacing, "progress": slot_progress, "tie_rank": 2, "forward": false},
	]
	if line_pref >= 0.0:
		inside_reference = lerpf(max_abs, -max_abs, clampf(line_pref, 0.0, 1.0))
		slots.append({
			"name": "inside_line",
			"offset": inside_reference,
			"progress": slot_progress,
			"tie_rank": 6,
			"forward": false,
		})
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
		var inner_distance := absf(slot_offset - inside_reference) / M2TrackMath.MAX_ABS_OFFSET_M
		# 現在ラインからの移動も、空き・混雑・内側志向と同じ候補評価に含める。
		var distance_score := follow_distance_score
		if bool(slot.get("forward", false)):
			distance_score = absf(float(follow_candidate.get("forward_gap_m", 0.0)) - Config.number("cpu_overtake_forward_distance_m")) / Config.number("cpu_follow_forward_range_m")
		var score := distance_score \
			+ crowding * Config.number("cpu_follow_slot_crowding_weight") \
			+ field_density * Config.number("cpu_follow_slot_field_density_weight") \
			+ inner_distance * Config.number("cpu_follow_slot_inner_bias") \
			+ cpu_line_distance_advantage_score(slot_offset, curvature)
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


## roster の trainer_profile_id から CPU 方針を引く。
static func cpu_trainer_profile_by_id(profile_id: String) -> Dictionary:
	var values := Config.values()
	for profile_value in values["cpu_trainer_profiles"]:
		if profile_value is Dictionary and str(profile_value.get("id", "")) == profile_id:
			return profile_value.duplicate(true)
	return {}


static func cpu_trainer_settings() -> Dictionary:
	return {
		"cpu_start_drive_level": Config.number("cpu_start_drive_level"),
		"heart_rate_min_bpm": Config.number("heart_rate_min_bpm"),
		"heart_rate_normal_max_bpm": Config.number("heart_rate_normal_max_bpm"),
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


## CPUが通常心拍上限以上にいる時、次の判断間隔まで心拍を下げられる最大ノッチを返す。
## 200 bpm未満ではトレーナーの既存判断をそのまま使う。候補は設定済みのノッチ別心拍曲線から導き、
## キャラクター・距離・固定ノッチによる例外は置かない。
static func cpu_heart_safe_drive_level(
	proposed_drive_level: float,
	current_bpm: float,
	cardio_stat: int
) -> float:
	if current_bpm < Config.number("heart_rate_normal_max_bpm"):
		return clamp_drive_level(proposed_drive_level)
	for drive_level in range(int(DRIVE_LEVEL_MAX), -1, -1):
		if heart_rate_net_rate_bpm_per_s(current_bpm, float(drive_level), cardio_stat) < 0.0:
			return float(drive_level)
	return 0.0


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


static func overheat_exposure_limit() -> float:
	var loss_per_s := Config.number("overheat_exposure_efficiency_loss_per_s")
	return maxf(
		(1.0 - Config.number("overheat_propulsion_efficiency_min")) / maxf(loss_per_s, 0.0001),
		0.0
	)


## 200 bpmを超えた負荷を、超過率で重み付けして蓄積する。
## 200 bpm未満では、より低く戻すほど速く解消する。
static func update_overheat_exposure(
	current_exposure: float,
	heart_rate_bpm: float,
	delta: float
) -> float:
	var normal_max := Config.number("heart_rate_normal_max_bpm")
	var next_exposure := maxf(current_exposure, 0.0)
	if delta <= 0.0:
		return clampf(next_exposure, 0.0, overheat_exposure_limit())
	if heart_rate_bpm > normal_max:
		next_exposure += overheat_ratio(heart_rate_bpm) * delta
	elif heart_rate_bpm < normal_max:
		var recovery_ratio := clampf(
			(normal_max - heart_rate_bpm)
			/ maxf(normal_max - Config.number("heart_rate_min_bpm"), 0.001),
			0.0,
			1.0
		)
		next_exposure -= Config.number("overheat_exposure_recovery_per_s") * recovery_ratio * delta
	return clampf(next_exposure, 0.0, overheat_exposure_limit())


static func overheat_exposure_propulsion_efficiency(exposure: float) -> float:
	return clampf(
		1.0 - maxf(exposure, 0.0) * Config.number("overheat_exposure_efficiency_loss_per_s"),
		Config.number("overheat_propulsion_efficiency_min"),
		1.0
	)


static func stamina_capacity_l(stamina_stat: int) -> float:
	return Config.number("stamina_capacity_base_l") + Config.number("stamina_capacity_per_stat_l") * clampi(stamina_stat, 1, 15)


static func stamina_debt_limit_l(capacity_l: float) -> float:
	return maxf(capacity_l, 0.0) * Config.number("stamina_debt_capacity_multiplier")


static func stamina_debt_efficiency(stamina_l: float, capacity_l: float) -> float:
	var debt_limit := stamina_debt_limit_l(capacity_l)
	if stamina_l >= 0.0 or debt_limit <= 0.0:
		return 1.0
	var debt_ratio := clampf(-stamina_l / debt_limit, 0.0, 1.0)
	return lerpf(1.0, Config.number("stamina_debt_efficiency_min"), debt_ratio)


static func stamina_consumption_l_per_s(
	drive_level: float,
	heart_rate_bpm: float = -1.0,
	load_multiplier: float = -1.0
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
	var load := Config.number("stamina_consumption_load_multiplier") if load_multiplier < 0.0 else load_multiplier
	return lerpf(
		Config.number("stamina_consumption_min_l_per_s"),
		Config.number("stamina_consumption_max_l_per_s"), effort
	) * heart_factor * load * overheat_stamina_multiplier(safe_heart)


static func stamina_delta_l_per_s(
	drive_level: float,
	heart_rate_bpm: float = -1.0,
	load_multiplier: float = -1.0
) -> float:
	return -stamina_consumption_l_per_s(drive_level, heart_rate_bpm, load_multiplier)


static func contact_overlaps(
	first_progress: float,
	first_offset: float,
	second_progress: float,
	second_offset: float
) -> bool:
	return absf(first_offset - second_offset) < required_lateral_gap(first_progress - second_progress)


## 他走者の現在位置を通り抜けず、次フレームで進める最大の進捗。
## 前走者の手前（体の楕円ぶん）までしか進めないが、急には止めない。
## 進める量 = 前走者の進む量 + 残りの距離 × BLOCK_APPROACH_RATE_PER_S × delta なので、
## 近づくほど前走者の速さへなめらかに寄る。接触後の強制位置補正は行わない。
static func allowed_race_progress(
	current_progress: float,
	proposed_progress: float,
	offset: float,
	others: Array,
	delta: float
) -> float:
	var allowed := maxf(proposed_progress, current_progress)
	for other_value in others:
		if not other_value is Dictionary:
			continue
		var other_offset := float(other_value.get("offset", 0.0))
		var other_progress := float(other_value.get("race_progress", 0.0))
		if other_progress <= current_progress:
			continue
		var limit := other_progress - required_longitudinal_gap(offset - other_offset)
		if limit >= other_progress:
			continue
		var remaining := maxf(limit - current_progress, 0.0)
		var other_move := maxf(float(other_value.get("actual_speed", 0.0)), 0.0) / 3.6 * delta
		var eased := current_progress + minf(other_move + remaining * BLOCK_APPROACH_RATE_PER_S * delta, remaining)
		allowed = minf(allowed, eased)
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


## 「1分23秒44」形式。小数点2位（1/100秒）まで、切り捨てで表示する。
static func format_race_time(seconds: float) -> String:
	var total_centiseconds := int(floorf(maxf(seconds, 0.0) * 100.0 + 0.0001))
	var minutes := total_centiseconds / 6000
	var whole_seconds := (total_centiseconds / 100) % 60
	return "%d分%02d秒%02d" % [minutes, whole_seconds, total_centiseconds % 100]


## 最内＝枠1。offset は負が内側。8プルを可動幅に等間隔。
static func starting_offset_for_gate(gate_index: int, field_size: int = FIELD_SIZE) -> float:
	var max_abs := M2TrackMath.MAX_ABS_OFFSET_M
	if field_size <= 1:
		return -max_abs
	var t := float(gate_index) / float(field_size - 1)
	return lerpf(-max_abs, max_abs, t)
