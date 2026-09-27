extends RefCounted
## ローカルCPUトレーナーの方針決定。個別プロファイルと走行状態から同じ式で指示を作る。


static func decide(profile: Dictionary, state: Dictionary, settings: Dictionary) -> Dictionary:
	var progress := clampf(float(state.get("progress_ratio", 0.0)), 0.0, 1.0)
	var field_size := maxf(float(state.get("field_size", 1.0)), 1.0)
	var live_place := clampf(float(state.get("live_place", field_size)), 1.0, field_size)
	var max_speed := float(state.get("max_speed_kmh", 0.0))
	var stamina_ratio := clampf(float(state.get("stamina_ratio", 1.0)), 0.0, 1.0)
	var has_draft := bool(state.get("has_draft", false))
	var aggression := clampf(float(profile.get("aggression", 0.5)), 0.0, 1.0)
	var patience := clampf(float(profile.get("patience", 0.5)), 0.0, 1.0)
	var drafting_pref := clampf(float(profile.get("drafting_pref", 0.5)), 0.0, 1.0)

	# 前寄りのCPUほど小さい順位（先頭側）を望む。終盤に全員が前へ寄るが、温存型は遅い。
	var opening_rank := lerpf(field_size * 0.78, field_size * 0.30, aggression)
	var finish_rank := lerpf(field_size * 0.55, 1.5, aggression)
	var finish_progress := _smoothstep(
		float(settings["finish_start_progress"]),
		float(settings["finish_full_progress"]),
		progress
	)
	finish_progress *= lerpf(1.0, 0.72, patience)
	var desired_rank := lerpf(opening_rank, finish_rank, finish_progress)
	var position_error := clampf((live_place - desired_rank) / field_size, -1.0, 1.0)

	# 中盤は温存型ほど余力を残す。ドラフト中は、同じ位置を低い目標速度で保とうとする。
	var reserve := (1.0 - progress) * patience * float(settings["reserve_max_kmh"])
	var position_push := position_error * float(settings["position_push_max_kmh"])
	var finish_push := finish_progress * float(settings["finish_push_max_kmh"])
	var draft_saving := 0.0
	if has_draft and progress < float(settings["finish_full_progress"]):
		draft_saving = drafting_pref * (1.0 - finish_progress) * float(settings["draft_saving_max_kmh"])
	var low_stamina_saving := (1.0 - stamina_ratio) * (1.0 - progress) * float(settings["low_stamina_saving_max_kmh"])
	var target := max_speed - reserve + position_push + finish_push - draft_saving - low_stamina_saving
	target = clampf(target, float(settings["min_target_speed_kmh"]), max_speed)
	var effort_ratio := clampf((target - float(settings["min_target_speed_kmh"])) / maxf(max_speed - float(settings["min_target_speed_kmh"]), 0.001), 0.0, 1.0)
	var drive_level := roundi(lerpf(float(settings["min_drive_level"]), float(settings["max_drive_level"]), effort_ratio))
	return {
		"target_speed_kmh": target,
		"desired_rank": desired_rank,
		"position_error": position_error,
		"drive_level": drive_level,
	}


static func _smoothstep(from: float, to: float, value: float) -> float:
	if to <= from:
		return 1.0 if value >= to else 0.0
	var t := clampf((value - from) / (to - from), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
