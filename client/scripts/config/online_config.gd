extends RefCounted
## オンライン対戦の設定（つなぐ先のサーバーなど）。初期値は data/config/online.json だけに置く。

const CONFIG_PATH := "res://data/config/online.json"
const Protocol := preload("res://scripts/online/online_protocol.gd")
## サーバーの計算の回数（1秒あたり）として受け付ける範囲。
const SERVER_MAX_FPS_RANGE := Vector2(10.0, 120.0)
## 整数の設定と、受け付ける範囲。max_rooms＝同時に作れる部屋の数、chat_max_length＝部屋のひとことの字数。
## result_linger_s＝結果が出たあと、サーバーがレースを走らせ続ける秒数（過ぎたら、レースを片づけて、全員を部屋へ戻す）。
## free_fill_wait_s＝オンラインフリー対戦のルームが、人を呼び始めてから、レースを始めるまでに待つ秒数の上限（足りない枠はCPU）。
## free_answer_wait_s＝呼ばれた人の、返事を待つ秒数の上限（返事がなければ、ロビーにいないとみなす）。
const WHOLE_NUMBER_RANGES := {"max_rooms": Vector2(1.0, 100.0), "chat_max_length": Vector2(1.0, 200.0), "result_linger_s": Vector2(0.0, 120.0), "log_keep_days": Vector2(1.0, 365.0), "free_fill_wait_s": Vector2(1.0, 300.0), "free_answer_wait_s": Vector2(1.0, 120.0)}
## オンラインフリー対戦のルームの、名前の長さの上限と、IDに使える文字。
const FREE_ROOM_NAME_MAX_LENGTH := 16
const FREE_ROOM_ID_PATTERN := "^[a-z0-9_]{1,24}$"
## つなぐ先として受け付ける書き出し（暗号なし・暗号あり）。
const URL_PREFIXES := ["ws://", "wss://"]

static var last_error := ""
static var _config: Dictionary = {}


static func values() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		var errors := validate(parsed)
		if errors.is_empty():
			_config = parsed
		else:
			last_error = "; ".join(errors)
			push_error(last_error)
	return _config


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("online: オブジェクトが必要です")
		return errors
	if not data.get("server_url") is String or not is_server_url(str(data["server_url"])):
		errors.append("online.server_url: ws:// か wss:// で始まるURLが必要です")
	if not (data.get("connect_timeout_s") is float or data.get("connect_timeout_s") is int) or float(data["connect_timeout_s"]) <= 0.0:
		errors.append("online.connect_timeout_s: 0より大きい数字が必要です")
	var room: Variant = data.get("default_room")
	if not room is String or str(room).strip_edges().is_empty() or str(room).length() > Protocol.ROOM_NAME_MAX_LENGTH:
		errors.append("online.default_room: 1〜%d字の部屋の名前が必要です" % Protocol.ROOM_NAME_MAX_LENGTH)
	for key: String in WHOLE_NUMBER_RANGES:
		var number: Variant = data.get(key)
		var limits: Vector2 = WHOLE_NUMBER_RANGES[key]
		if not (number is float or number is int) or float(number) != floorf(float(number)) or float(number) < limits.x or float(number) > limits.y:
			errors.append("online.%s: %d〜%d の整数が必要です" % [key, int(limits.x), int(limits.y)])
	errors.append_array(validate_free_rooms(data.get("free_rooms")))
	var fps: Variant = data.get("server_max_fps")
	if not (fps is float or fps is int) or float(fps) != floorf(float(fps)) or float(fps) < SERVER_MAX_FPS_RANGE.x or float(fps) > SERVER_MAX_FPS_RANGE.y:
		errors.append("online.server_max_fps: %d〜%d の整数が必要です" % [int(SERVER_MAX_FPS_RANGE.x), int(SERVER_MAX_FPS_RANGE.y)])
	return errors


## オンラインフリー対戦のルームの並び（1つぶん：id、name、distance_m）。id は重ならないこと。距離は、レースで選べる距離。
static func validate_free_rooms(rooms: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not rooms is Array or (rooms as Array).is_empty():
		errors.append("online.free_rooms: ルームが1つ以上必要です")
		return errors
	var pattern := RegEx.create_from_string(FREE_ROOM_ID_PATTERN)
	var ids := {}
	for index in (rooms as Array).size():
		var room: Variant = rooms[index]
		var label := "online.free_rooms[%d]" % index
		if not room is Dictionary:
			errors.append("%s: オブジェクトが必要です" % label)
			continue
		var id := str(room.get("id", ""))
		if pattern.search(id) == null or ids.has(id):
			errors.append("%s.id: 重ならない、英小文字・数字・_ のIDが必要です" % label)
		ids[id] = true
		var name: Variant = room.get("name")
		if not name is String or str(name).strip_edges().is_empty() or str(name).length() > FREE_ROOM_NAME_MAX_LENGTH:
			errors.append("%s.name: 1〜%d字の名前が必要です" % [label, FREE_ROOM_NAME_MAX_LENGTH])
		var distance: Variant = room.get("distance_m")
		if not (distance is float or distance is int) or not preload("res://scripts/race_session.gd").supported_distances_m().has(float(distance)):
			errors.append("%s.distance_m: レースで選べる距離（%s）が必要です" % [label, str(preload("res://scripts/race_session.gd").supported_distances_m())])
	return errors


## オンラインフリー対戦のルームの並び（1つぶん：id、name、distance_m）。
static func free_rooms() -> Array:
	return values()["free_rooms"]


## オンラインフリー対戦のルームが、人を呼び始めてから、レースを始めるまでに待つ秒数の上限。
static func free_fill_wait_s() -> float:
	return float(values()["free_fill_wait_s"])


## 呼ばれた人の、返事を待つ秒数の上限。
static func free_answer_wait_s() -> float:
	return float(values()["free_answer_wait_s"])


## つなぐ先として使える形か（ws:// か wss:// で始まり、そのあとに何か書いてある）。
static func is_server_url(url: String) -> bool:
	for prefix: String in URL_PREFIXES:
		if url.begins_with(prefix) and url.length() > prefix.length():
			return true
	return false


static func server_url() -> String:
	return str(values()["server_url"])


## サーバーの計算の回数の上限（1秒あたり）。画面が無いので、決めないと、力のかぎり回り続ける。
## 少ないほど、サーバーは軽い。レースの計算は「前の計算から何秒たったか」で進めるので、回数を変えても、レースの長さは変わらない。
static func server_max_fps() -> int:
	return int(values()["server_max_fps"])


## 同時に作れる部屋の数の上限。
static func max_rooms() -> int:
	return int(values()["max_rooms"])


## 結果が出たあと、サーバーがレースを走らせ続ける秒数。
static func result_linger_s() -> float:
	return float(values()["result_linger_s"])


## オンラインのレースの記録を、何日残すか（古いものは、サーバーが消す）。
static func log_keep_days() -> int:
	return int(values()["log_keep_days"])


## 部屋のひとことの、字数の上限。
static func chat_max_length() -> int:
	return int(values()["chat_max_length"])


## 部屋を作る画面に、最初から入れておく部屋の名前（文字が打ちにくい端末でも、そのまま作れるように）。
static func default_room() -> String:
	return str(values()["default_room"])


static func connect_timeout_s() -> float:
	return float(values()["connect_timeout_s"])
