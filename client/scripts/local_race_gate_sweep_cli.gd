extends SceneTree
## 互換CLI。枠は全頭を巡回して重複なしにし、全頭を通常CPU判断で比較する。

const Simulator := preload("res://scripts/local_race_simulator.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var simulator := Simulator.new()
	var records: Array = []
	for gate in range(0, LocalRaceMath.FIELD_SIZE):
		var scenario := Simulator.scenario_by_id("cpu_pack_and_draft")
		scenario["all_cpu"] = true
		scenario["seed"] = 1
		var assignments := {}
		var roster: Array = Simulator.RosterConfig.values().get("roster", [])
		for index in roster.size():
			assignments[str(roster[index].id)] = (index + gate + 1) % LocalRaceMath.FIELD_SIZE
		scenario["gate_overrides"] = assignments
		var result: Dictionary = simulator.run_scenario(get_root(), scenario)
		if result.has("error"):
			records.append({"gate": gate, "error": result["error"]})
			continue
		var iwa: Dictionary = {}
		for runner_value: Variant in result.get("runners", []):
			if runner_value is Dictionary and str((runner_value as Dictionary).get("id", "")) == "cpu-7":
				iwa = runner_value
				break
		var checkpoints: Array = []
		for sample_value: Variant in result.get("samples", []):
			if not sample_value is Array:
				continue
			for runner_value: Variant in sample_value:
				if runner_value is Dictionary and str((runner_value as Dictionary).get("id", "")) == "cpu-7":
					var sample: Dictionary = runner_value
					var time_s := float(sample.get("time_s", 0.0))
					var bucket := int(floor(time_s + 0.001))
					if bucket in [20, 30, 40, 60, 80, 100] and (checkpoints.is_empty() or int(checkpoints.back().get("t", -1)) != bucket):
						checkpoints.append({
							"t": bucket,
							"offset_m": sample.get("offset", 0.0),
							"rank": sample.get("rank", -1),
							"speed_kmh": sample.get("speed_kmh", 0.0),
							"heart_rate_bpm": sample.get("heart_rate_bpm", 0.0),
							"stamina": sample.get("stamina", 0.0),
						})
					break
		records.append({
			"gate": gate,
			"start_offset_m": LocalRaceMath.starting_offset_for_gate(gate),
			"final_offset_m": iwa.get("offset", 0.0),
			"final_rank": iwa.get("rank", -1),
			"finish_time_s": iwa.get("finish_time_s", -1.0),
			"heart_rate_bpm": iwa.get("heart_rate_bpm", 0.0),
			"stamina": iwa.get("stamina", 0.0),
			"overheat_ratio": iwa.get("overheat_ratio", 0.0),
			"checkpoints": checkpoints,
			"goal_status": result.get("goal_assessment", {}).get("status", ""),
		})
	print(JSON.stringify({"scenario": "cpu_pack_and_draft", "records": records}))
	quit()
