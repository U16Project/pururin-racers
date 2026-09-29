extends GutTest

const Recorder := preload("res://scripts/race_telemetry_recorder.gd")


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
