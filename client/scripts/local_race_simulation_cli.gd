extends SceneTree
## Godot headless CLI: --script scripts/local_race_simulation_cli.gd -- --scenario notch4_cruise

const Simulator := preload("res://scripts/local_race_simulator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# SceneTree に root が入った後に実行し、Node3D の通常のライフサイクルを保つ。
	await process_frame
	var scenario_id := "notch4_cruise"
	var user_args := OS.get_cmdline_user_args()
	var gate_overrides := {}
	var batch_path := ""
	var output_dir := ""
	for index in user_args.size():
		if user_args[index] == "--scenario" and index + 1 < user_args.size():
			scenario_id = user_args[index + 1]
		if user_args[index] == "--gate-override" and index + 1 < user_args.size():
			var assignment := user_args[index + 1].split("=", true, 1)
			if assignment.size() == 2:
				gate_overrides[assignment[0]] = assignment[1].to_int()
		if user_args[index] == "--batch-config" and index + 1 < user_args.size():
			batch_path = user_args[index + 1]
		if user_args[index] == "--output-dir" and index + 1 < user_args.size():
			output_dir = user_args[index + 1]
	if not batch_path.is_empty():
		_run_batch(batch_path, output_dir)
		return
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id(scenario_id)
	var result: Dictionary
	if scenario.is_empty():
		result = {"error": "シナリオが見つかりません: %s" % scenario_id}
	else:
		if not gate_overrides.is_empty():
			scenario["gate_overrides"] = gate_overrides
		result = simulator.run_scenario(get_root(), scenario)
	print(JSON.stringify(result))
	quit(1 if result.has("error") else 0)


func _run_batch(path: String, output_dir: String) -> void:
	var loaded := Simulator.load_config(path)
	if loaded.has("error") or output_dir.is_empty():
		print(JSON.stringify({"error": loaded.get("error", "--output-dir を指定してください")}))
		quit(1)
		return
	var cases: Variant = loaded.data.get("cases", [])
	if not cases is Array or cases.is_empty():
		print(JSON.stringify({"error": "cases は空でない配列が必要です"}))
		quit(1)
		return
	var identifiers := {}
	for condition: Variant in cases:
		if not condition is Dictionary or str(condition.get("id", "")).is_empty() or identifiers.has(str(condition.get("id", ""))) or not str(condition.get("id", "")).is_valid_filename():
			print(JSON.stringify({"error": "case id はファイル名として有効・空でない・重複なしが必要です"}))
			quit(1)
			return
		identifiers[str(condition.id)] = true
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		print(JSON.stringify({"error": "出力ディレクトリを作成できません"}))
		quit(1)
		return
	# 既存データは上書きしない。
	for identifier: String in identifiers:
		if FileAccess.file_exists(output_dir.path_join(identifier + ".json")):
			print(JSON.stringify({"error": "出力ファイルが既にあります: %s" % identifier}))
			quit(1)
			return
	if FileAccess.file_exists(output_dir.path_join("summary.json")):
		print(JSON.stringify({"error": "summary.json が既にあります"}))
		quit(1)
		return
	var started_usec := Time.get_ticks_usec()
	var simulator := Simulator.new()
	var records: Array = []
	var references := {}
	var scenarios := {}
	var failed := 0
	for condition: Dictionary in cases:
		var result := simulator.run_case(get_root(), condition)
		var record := {"id": condition.id, "mode": condition.get("mode", "race"), "file": str(condition.id) + ".json", "execution_time_s": result.get("execution_time_s", 0.0)}
		if result.has("error"):
			failed += 1
			record["error"] = result.error
		elif str(condition.get("mode", "race")) == "isolated":
			record["metrics"] = result.metrics
			record["effective_stats"] = result.effective_stats
		else:
			record["finish_snapshots"] = result.finish_snapshots
			record["goal_assessment"] = result.goal_assessment
			record["timed_out"] = result.timed_out
			references[str(condition.id)] = {"goal_assessment": result.goal_assessment}
			scenarios[str(condition.id)] = condition.get("scenario", {})
		var file := FileAccess.open(output_dir.path_join(str(condition.id) + ".json"), FileAccess.WRITE)
		if file == null:
			failed += 1
			record["error"] = "結果保存に失敗しました"
		else:
			file.store_string(JSON.stringify(result))
			file.close()
		records.append(record)
	# 生時系列をメモリに保持せず、相対目標はコンパクトな実測値で再判定する。
	for record: Dictionary in records:
		if not record.has("goal_assessment"):
			continue
		var assessment: Dictionary = record.goal_assessment
		var checks: Array = assessment.checks
		for check: Dictionary in checks:
			if str(check.get("kind", "")) != "relative":
				continue
			var updated: Array = []
			Simulator._add_assessment_check(updated, check, assessment.metrics, references)
			check.merge(updated[0], true)
		var status := "PASS"
		for check: Dictionary in checks:
			if check.status == "FAIL":
				status = "FAIL"
			elif check.status == "NOT_EVALUATED" and status != "FAIL":
				status = "NOT_EVALUATED"
		assessment.status = status
		assessment.passed = status == "PASS"
		assessment.summary = "%s: %d件の目標を確認" % [status, checks.size()]
	var summary := {"schema_version": 1, "case_count": cases.size(), "execution_errors": failed, "execution_time_s": (Time.get_ticks_usec() - started_usec) / 1000000.0, "records": records, "batch_conditions": loaded.data}
	var summary_file := FileAccess.open(output_dir.path_join("summary.json"), FileAccess.WRITE)
	if summary_file == null:
		print(JSON.stringify({"error": "summary保存に失敗しました"}))
		quit(1)
		return
	summary_file.store_string(JSON.stringify(summary))
	summary_file.close()
	print(JSON.stringify({"case_count": cases.size(), "execution_errors": failed, "execution_time_s": summary.execution_time_s, "summary_path": output_dir.path_join("summary.json")}))
	# 数値目標FAILは検証結果として保存。CLI失敗は不正条件/実行/保存エラー。
	quit(1 if failed > 0 else 0)
