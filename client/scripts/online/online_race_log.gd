extends RefCounted
## オンラインのレースの記録（サーバーで作る）。テスト期間の調べと、あとのリプレイに使う。
## 中身：部屋と出走の情報、0.1秒ごとの全員の位置（リプレイ用）、0.5秒ごとの全員の詳しい状態（オフラインの記録と同じ形）、
## 人の操作とできごと（ライン・ノッチ・ブレーキの変わり目、ダッシュ・ブースト、抜けた・CPUに任せた）、着順。
## 置き場所は、環境変数 PURURIN_LOG_DIR（無ければ user://online_race_logs）。決めた日数より古い記録は、消す。

const RaceTelemetryRecorder := preload("res://scripts/race_telemetry_recorder.gd")
const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const FORMAT_VERSION := 1
const DEFAULT_DIRECTORY := "user://online_race_logs"
const DIRECTORY_ENVIRONMENT := "PURURIN_LOG_DIR"
## リプレイ用の位置を残す間（秒）。
const TRACK_INTERVAL_S := 0.1
## 詳しい状態を残す間（秒。オフラインの記録と同じ）。
const DETAIL_INTERVAL_S := 0.5

var _detail := RaceTelemetryRecorder.new()
var _header := {}
var _track: Array = []
var _events: Array = []
var _next_track_s := 0.0
var _last_inputs := {}
var _active := false


## 記録の置き場所（文字の書き出しは、そのまま開ける形）。
static func directory() -> String:
	var from_environment := OS.get_environment(DIRECTORY_ENVIRONMENT).strip_edges()
	return from_environment if not from_environment.is_empty() else ProjectSettings.globalize_path(DEFAULT_DIRECTORY)


## レースが始まった。header：部屋・出走・人の情報（そのまま記録の頭に入る）。
func start(header: Dictionary) -> void:
	_header = header.duplicate(true)
	_header["started_at"] = Time.get_datetime_string_from_system(true)
	_detail.start(float(header.get("distance_m", 0.0)), DETAIL_INTERVAL_S)
	_track.clear()
	_events.clear()
	_last_inputs.clear()
	_next_track_s = 0.0
	_active = true


func is_recording() -> bool:
	return _active


## 毎コマ呼ぶ。elapsed＝レースの時計（スタート前は0）。
func record(elapsed_s: float, runners: Array) -> void:
	if not _active:
		return
	_detail.record_sample(elapsed_s, runners)
	if elapsed_s + 0.0001 < _next_track_s:
		return
	var frame: Array = []
	for runner in runners:
		var state: Dictionary = runner.call("get_online_state")
		frame.append([
			int(state["gate"]), snappedf(float(state["progress"]), 0.001), snappedf(float(state["offset"]), 0.001),
			snappedf(float(state["actual_speed"]), 0.01), snappedf(float(state["notch"]), 0.01), 1 if bool(state["braking"]) else 0,
			snappedf(float(state["heart"]), 0.1), snappedf(float(state["stamina_ratio"]), 0.001),
			snappedf(float(state["dash_ratio"]), 0.01), snappedf(float(state["boost_ratio"]), 0.01), int(state["contacts"]),
			1 if bool(state["pushing"]) else 0, int(state["finish_order"]) if bool(state["finished"]) else 0,
		])
	_track.append({"t": snappedf(elapsed_s, 0.001), "r": frame})
	while _next_track_s <= elapsed_s:
		_next_track_s += TRACK_INTERVAL_S


## 人の操作（変わったときだけ残す）。
func record_input(elapsed_s: float, peer_id: int, line: float, notch: float, brake: bool) -> void:
	if not _active:
		return
	var input := [snappedf(line, 0.01), snappedf(notch, 0.01), brake]
	if _last_inputs.get(peer_id) == input:
		return
	_last_inputs[peer_id] = input
	_events.append({"t": snappedf(elapsed_s, 0.001), "kind": "input", "peer_id": peer_id, "line": input[0], "notch": input[1], "brake": brake})


## できごと（ダッシュ・ブースト・抜けた・結果、など）。fields は、そのまま残す。
func record_event(elapsed_s: float, kind: String, fields: Dictionary = {}) -> void:
	if not _active:
		return
	var event := {"t": snappedf(elapsed_s, 0.001), "kind": kind}
	event.merge(fields)
	_events.append(event)


## レースを片づける前に呼ぶ。ファイルに書いて、書いたファイルの名前を返す（書けなければ空）。
func finish(elapsed_s: float, runners: Array, result_rows: Array) -> String:
	if not _active:
		return ""
	_active = false
	_detail.record_sample(elapsed_s, runners, true)
	var detail := _detail.build_payload()
	var payload := _header.duplicate(true)
	payload.merge({
		"format_version": FORMAT_VERSION,
		"race_type": "online",
		"protocol_version": Protocol.VERSION,
		"server_ticks_per_s": Engine.max_fps,
		"finished_at": Time.get_datetime_string_from_system(true),
		"result_rows": result_rows,
		"track_interval_s": TRACK_INTERVAL_S,
		"track_columns": ["gate", "progress_m", "offset_m", "actual_speed_kmh", "notch", "braking", "heart_bpm", "stamina_ratio", "dash_ratio", "boost_ratio", "contacts", "pushing", "finish_order"],
		"track": _track,
		"events": _events,
		"sample_interval_s": DETAIL_INTERVAL_S,
		"samples": detail["samples"],
	}, true)
	var folder := directory()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("オンラインのレースの記録の置き場所を作れません: %s（%s）" % [folder, error_string(error)])
		return ""
	var stamp := str(_header["started_at"]).replace("-", "").replace(":", "").replace("T", "_")
	var filename := "%s_%s_%dm.json" % [stamp, safe_name(str(_header.get("room_name", ""))), int(float(_header.get("distance_m", 0.0)))]
	var file := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
	if file == null:
		push_error("オンラインのレースの記録を書けません: %s" % folder.path_join(filename))
		return ""
	file.store_string(JSON.stringify(payload))
	file.close()
	remove_old(folder, OnlineConfig.log_keep_days())
	return filename


## ファイルの名前に使えない文字を、取り除く。
static func safe_name(text: String) -> String:
	var result := ""
	for character in text:
		result += character if not character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " ", "."] else "_"
	return result.left(24)


## 決めた日数より古い記録を、消す。消した数を返す。
static func remove_old(folder: String, keep_days: int) -> int:
	var dir := DirAccess.open(folder)
	if dir == null:
		return 0
	var limit := Time.get_unix_time_from_system() - float(keep_days) * 86400.0
	var removed := 0
	for name in dir.get_files():
		if name.ends_with(".json") and FileAccess.get_modified_time(folder.path_join(name)) < limit:
			if dir.remove(name) == OK:
				removed += 1
	return removed
