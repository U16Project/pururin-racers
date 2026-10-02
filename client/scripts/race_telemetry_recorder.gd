extends RefCounted
## ローカル実機レースの再検証用テレメトリを user:// に保存する。

const LOG_DIRECTORY := "user://pururin_race_logs"
const FORMAT_VERSION := 1

var sample_interval_s: float = 0.5
var _active := false
var _race_distance_m := 0.0
var _started_at := ""
var _next_sample_elapsed := 0.0
var _samples: Array = []
var _last_file_path := ""


func start(race_distance_m: float, interval_s: float = 0.5) -> void:
	_race_distance_m = race_distance_m
	sample_interval_s = maxf(interval_s, 0.1)
	_started_at = Time.get_datetime_string_from_system(true)
	_next_sample_elapsed = 0.0
	_samples.clear()
	_last_file_path = ""
	_active = true


func record_sample(elapsed_s: float, runners: Array, force: bool = false) -> void:
	if not _active or (not force and elapsed_s + 0.0001 < _next_sample_elapsed):
		return
	_samples.append({
		"elapsed_s": elapsed_s,
		"race_distance_m": _race_distance_m,
		"runners": _runner_records(runners),
	})
	while _next_sample_elapsed <= elapsed_s:
		_next_sample_elapsed += sample_interval_s


func finalize(elapsed_s: float, runners: Array) -> String:
	if not _active:
		return _last_file_path
	record_sample(elapsed_s, runners, true)
	var payload := {
		"format_version": FORMAT_VERSION,
		"race_type": "local",
		"started_at": _started_at,
		"finished_at": Time.get_datetime_string_from_system(true),
		"race_distance_m": _race_distance_m,
		"sample_interval_s": sample_interval_s,
		"sample_count": _samples.size(),
		"samples": _samples,
		"final_results": _final_results(runners),
	}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIRECTORY))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("レーステレメトリの保存先を作成できません: %s" % error_string(directory_error))
		_active = false
		return ""
	var stamp := _started_at.replace("-", "").replace(":", "").replace("T", "_")
	var filename := "%s_%dm.json" % [stamp, int(roundi(_race_distance_m))]
	_last_file_path = "%s/%s" % [LOG_DIRECTORY, filename]
	var file := FileAccess.open(_last_file_path, FileAccess.WRITE)
	if file == null:
		push_error("レーステレメトリを保存できません: %s" % _last_file_path)
		_active = false
		return ""
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_active = false
	print("レーステレメトリ保存: %s（%dサンプル）" % [_last_file_path, _samples.size()])
	return _last_file_path


func is_recording() -> bool:
	return _active


func sample_count() -> int:
	return _samples.size()


func last_file_path() -> String:
	return _last_file_path


func build_payload() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"race_type": "local",
		"started_at": _started_at,
		"race_distance_m": _race_distance_m,
		"sample_interval_s": sample_interval_s,
		"sample_count": _samples.size(),
		"samples": _samples.duplicate(true),
	}


func _runner_records(runners: Array) -> Array:
	var records: Array = []
	for runner in runners:
		if runner != null and runner.has_method("get_telemetry_snapshot"):
			records.append(runner.call("get_telemetry_snapshot"))
	return records


func _final_results(runners: Array) -> Array:
	var results: Array = []
	for runner in runners:
		if runner == null:
			continue
		var snapshot: Dictionary = runner.call("get_snapshot") if runner.has_method("get_snapshot") else {}
		results.append({
			"id": str(snapshot.get("id", "")),
			"name": str(runner.get("display_name")),
			"finish_order": int(runner.call("get_finish_order")) if runner.has_method("get_finish_order") else -1,
			"finish_time_s": float(runner.call("get_finish_time")) if runner.has_method("get_finish_time") else -1.0,
		})
	return results
