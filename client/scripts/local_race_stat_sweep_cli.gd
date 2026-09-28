extends SceneTree
## Godot headless CLI: --script scripts/local_race_stat_sweep_cli.gd --

const Simulator := preload("res://scripts/local_race_simulator.gd")
const Sweep := preload("res://scripts/local_race_stat_sweep.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var loaded := Sweep.load_config()
	if loaded.has("error"):
		print(JSON.stringify({"error": loaded.error}))
		quit(1)
		return
	var cases: Array = Sweep.build_cases(loaded.data)
	var simulator := Simulator.new()
	var records: Array = []
	var errors: Array = []
	var started_ms := Time.get_ticks_msec()
	for case_value: Variant in cases:
		if not case_value is Dictionary:
			errors.append("不正なvariant形式")
			continue
		var case: Dictionary = case_value
		var result: Dictionary = simulator.run_scenario(get_root(), case.get("scenario", {}))
		if result.has("error"):
			errors.append({"variant_id": case.get("variant_id", ""), "error": result.error})
			continue
		records.append(Sweep.build_record(case, result))
	var passed := 0
	var failed := 0
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var assessment: Dictionary = (record_value as Dictionary).get("goal_assessment", {})
		if bool(assessment.get("passed", false)):
			passed += 1
		else:
			failed += 1
	var report := {
		"schema_version": 1,
		"variant_count": cases.size(),
		"record_count": records.size(),
		"assessment_passed": passed,
		"assessment_failed": failed,
		"errors": errors,
		"elapsed_wall_s": float(Time.get_ticks_msec() - started_ms) / 1000.0,
		"monotonicity": Sweep.assess_monotonicity(records),
		"records": records,
	}
	print(JSON.stringify(report))
	quit(1 if records.size() != cases.size() or not errors.is_empty() else 0)
