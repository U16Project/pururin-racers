extends GutTest

const Recorder := preload("res://scripts/race_telemetry_recorder.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")


func test_recorder_keeps_samples_and_serializable_payload() -> void:
	var recorder := Recorder.new()
	recorder.start(1200.0, 0.5)
	recorder.record_sample(0.0, [])
	recorder.record_sample(0.25, [])
	recorder.record_sample(0.5, [])
	var payload := recorder.build_payload()
	assert_eq(payload["race_distance_m"], 1200.0)
	assert_eq(payload["sample_count"], 2)
	assert_eq(payload["samples"].size(), 2)
	assert_eq(JSON.stringify(payload).is_empty(), false)


func test_recorder_does_not_record_before_start() -> void:
	var recorder := Recorder.new()
	recorder.record_sample(1.0, [])
	assert_eq(recorder.sample_count(), 0)


func test_final_results_keep_the_roster_id_when_player_assignment_changes() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	var sora: Dictionary = PururinRosterConfig.pururin_by_id("cpu-4")
	runner.call("setup_for_race", null, 3, 75.0, true, str(sora["display_name"]), sora)
	var recorder := Recorder.new()
	var results: Array = recorder.call("_final_results", [runner])
	assert_eq(results[0]["id"], "cpu-4")
	assert_eq(results[0]["name"], "ソラ")
	runner.free()
