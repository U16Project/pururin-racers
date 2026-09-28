extends RefCounted
## ローカルCPUトレーナーの方針決定。個別プロファイルと走行状態から同じ式で指示を作る。

const NORMAL_RACE_FINISH_TARGET_RANK := 1.0


static func decide(profile: Dictionary, state: Dictionary, settings: Dictionary) -> Dictionary:
	var progress := clampf(float(state.get("progress_ratio", 0.0)), 0.0, 1.0)
	var field_size := maxf(float(state.get("field_size", 1.0)), 1.0)
	var live_place := clampf(float(state.get("live_place", field_size)), 1.0, field_size)
	var max_speed := float(state.get("max_speed_kmh", 0.0))
	var stamina_ratio := clampf(float(state.get("stamina_ratio", 1.0)), 0.0, 1.0)
	var has_draft := bool(state.get("has_draft", false))
	var current_speed := maxf(float(state.get("current_speed_kmh", 0.0)), 0.0)
	var field_pace := maxf(float(state.get("field_pace_kmh", current_speed)), 0.0)
	var field_pace_reference := maxf(float(settings["field_pace_reference_kmh"]), 0.001)
	var pace_delta := clampf(field_pace - current_speed, -field_pace_reference, field_pace_reference)
	var pace_correction := (
		pace_delta / field_pace_reference
	) * float(settings["field_pace_correction_max_kmh"])
	var nearest_ahead_gap := maxf(float(state.get("nearest_ahead_gap_m", 0.0)), 0.0)
	var nearest_ahead_speed := maxf(float(state.get("nearest_ahead_speed_kmh", current_speed)), 0.0)
	var acceleration_stat := clampf(float(state.get("acceleration_stat", 5.0)), 1.0, 15.0)
	var closing_gap_pressure := clampf(
		nearest_ahead_gap / maxf(float(settings["closing_gap_reference_m"]), 0.001),
		0.0,
		1.0
	)
	var closing_speed_reference := maxf(float(settings["closing_speed_reference_kmh"]), 0.001)
	var max_speed_advantage := clampf(
		(max_speed - nearest_ahead_speed) / closing_speed_reference,
		0.0,
		1.0
	)
	var current_speed_deficit := clampf(
		(nearest_ahead_speed - current_speed) / closing_speed_reference,
		0.0,
		1.0
	)
	var acceleration_factor := lerpf(0.5, 1.0, (acceleration_stat - 1.0) / 14.0)
	var closing_signal := clampf(
		(max_speed_advantage * 0.65 + current_speed_deficit * 0.35) * acceleration_factor,
		0.0,
		1.0
	)
	var closing_pressure := (
		closing_gap_pressure * closing_signal * float(settings["closing_pressure_max_kmh"])
	)
	var global_gap_reference := maxf(float(settings["global_gap_reference_m"]), 0.001)
	var leader_gap_pressure := clampf(float(state.get("leader_gap_m", 0.0)) / global_gap_reference, 0.0, 1.0)
	# 先頭から離れるほど、温存やドラフト待ちを段階的にやめて追走する。
	# これは目標速度の補正ではなく、既存の温存補正を弱める係数なので、
	# 自然最高速を直接超えることはない。
	var chase_urgency_reference := maxf(float(settings["chase_urgency_gap_reference_m"]), 0.001)
	var chase_urgency := clampf(float(state.get("leader_gap_m", 0.0)) / chase_urgency_reference, 0.0, 1.0)
	# 集団中心より後ろなら追走、前に出過ぎていれば同じ式でわずかに抑制する。
	# 先頭だけが独走し続ける特別処理は置かず、位置関係の符号で表現する。
	var pack_gap_pressure := clampf(float(state.get("pack_center_gap_m", 0.0)) / global_gap_reference, -1.0, 1.0)
	var global_chase_pressure := (
		leader_gap_pressure * 0.60 + pack_gap_pressure * 0.40
	) * float(settings["global_chase_pressure_max_kmh"])
	var aggression := clampf(float(profile.get("aggression", 0.5)), 0.0, 1.0)
	var patience := clampf(float(profile.get("patience", 0.5)), 0.0, 1.0)
	var drafting_pref := clampf(float(profile.get("drafting_pref", 0.5)), 0.0, 1.0)
	# 前が詰まったときに、抜け道を探すか後ろで溜めるかの連続値。
	# 性格だけで決めず、最高速・加速力・現在の速度差・スタミナも同じ式に含める。
	var acceleration_capability := clampf((acceleration_stat - 1.0) / 14.0, 0.0, 1.0)
	var capability_signal := clampf(
		max_speed_advantage * 0.45 + acceleration_capability * 0.30 + current_speed_deficit * 0.25,
		0.0,
		1.0
	)
	var profile_overtake_signal := (
		aggression * 0.55 + (1.0 - patience) * 0.25 + (1.0 - drafting_pref) * 0.20
	)
	# スタミナが半分程度残っている段階では追走を諦めず、
	# 本当に余力が尽きた時だけ後方で溜める判断へ寄せる。
	var stamina_gate := lerpf(0.65, 1.0, stamina_ratio)
	var overtake_bias := clampf(
		(profile_overtake_signal * 0.60 + capability_signal * 0.40) * stamina_gate * 2.2 - 0.85,
		-1.0,
		1.0
	)
	# 前方との差があるのに集団の速度へ張り付く状態を避けるための共通追走圧力。
	# 最高速を直接変更せず、前方差・自然最高速までの余裕・加速力・スタミナ・性格を
	# 連続的に目標速度へ反映する。前走者がいない場合は発生させない。
	var has_ahead_runner := nearest_ahead_gap > 0.001
	var natural_speed_headroom := clampf(
		(max_speed - current_speed) / closing_speed_reference,
		0.0,
		1.0
	)
	var front_chase_signal := clampf(
		(current_speed_deficit * 0.30 + max_speed_advantage * 0.30 + natural_speed_headroom * 0.20 + acceleration_capability * 0.20)
			* (0.65 + profile_overtake_signal * 0.35)
			* stamina_gate,
		0.0,
		1.0
	) if has_ahead_runner else 0.0
	var front_chase_pressure := front_chase_signal * float(settings["front_chase_pressure_max_kmh"])

	# 前寄りのCPUほど小さい順位（先頭側）を望む。終盤に全員が前へ寄るが、温存型は遅い。
	var opening_rank := lerpf(field_size * 0.78, field_size * 0.30, aggression)
	# 通常レースの最終目的は全員1着。序盤の脚質・積極性は opening_rank と
	# finish_progress の立ち上がりで表現し、順位の強制変更や速度の直接加算はしない。
	var finish_rank := NORMAL_RACE_FINISH_TARGET_RANK
	var finish_progress := _smoothstep(
		float(settings["finish_start_progress"]),
		float(settings["finish_full_progress"]),
		progress
	)
	var desired_rank := lerpf(opening_rank, finish_rank, finish_progress)
	var position_error := clampf((live_place - desired_rank) / field_size, -1.0, 1.0)

	# 中盤は温存型ほど余力を残す。ドラフト中は、同じ位置を低い目標速度で保とうとする。
	var cruise_reduction := float(settings["cruise_reduction_max_kmh"])
	var reserve := (1.0 - progress) * patience * float(settings["reserve_max_kmh"]) * (1.0 - chase_urgency)
	var position_push := position_error * float(settings["position_push_max_kmh"])
	# 終盤の仕掛けは距離だけで一律に発生させない。
	# 現在の順位誤差と先頭との差がある個体ほど強くなり、先頭が独走している場合は
	# 後続の追走圧力が増える。全員1位を目標にしたまま、同じ速度への収束を避ける。
	var finish_chase_signal := clampf(
		float(settings["finish_chase_base_ratio"])
			+ maxf(position_error, 0.0) * float(settings["finish_chase_position_ratio"])
			+ leader_gap_pressure * float(settings["finish_chase_leader_gap_ratio"]),
		0.0,
		1.0
	)
	var finish_push := finish_progress * finish_chase_signal * float(settings["finish_push_max_kmh"])
	var draft_saving := 0.0
	if has_draft and progress < float(settings["finish_full_progress"]):
		draft_saving = drafting_pref * (1.0 - finish_progress) * float(settings["draft_saving_max_kmh"]) * (1.0 - chase_urgency)
	var low_stamina_saving := (1.0 - stamina_ratio) * (1.0 - progress) * float(settings["low_stamina_saving_max_kmh"])
	var target := max_speed - cruise_reduction - reserve + position_push + global_chase_pressure + pace_correction + closing_pressure + front_chase_pressure + finish_push - draft_saving - low_stamina_saving
	target = clampf(target, float(settings["min_target_speed_kmh"]), max_speed)
	var effort_ratio := clampf((target - float(settings["min_target_speed_kmh"])) / maxf(max_speed - float(settings["min_target_speed_kmh"]), 0.001), 0.0, 1.0)
	var drive_level := roundi(lerpf(float(settings["min_drive_level"]), float(settings["max_drive_level"]), effort_ratio))
	return {
		"target_speed_kmh": target,
		"desired_rank": desired_rank,
		"position_error": position_error,
		"overtake_bias": overtake_bias,
		"pace_correction_kmh": pace_correction,
		"closing_pressure_kmh": closing_pressure,
		"front_chase_pressure_kmh": front_chase_pressure,
		"finish_chase_pressure_kmh": finish_push,
		"drive_level": drive_level,
	}


static func _smoothstep(from: float, to: float, value: float) -> float:
	if to <= from:
		return 1.0 if value >= to else 0.0
	var t := clampf((value - from) / (to - from), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
