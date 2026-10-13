extends RefCounted
## オンライン対戦の設定（つなぐ先のサーバーなど）。初期値は data/config/online.json だけに置く。

const CONFIG_PATH := "res://data/config/online.json"
const Protocol := preload("res://scripts/online/online_protocol.gd")
## サーバーの計算の回数（1秒あたり）として受け付ける範囲。
const SERVER_MAX_FPS_RANGE := Vector2(10.0, 120.0)
## 整数の設定と、受け付ける範囲。max_rooms＝同時に作れる部屋の数、chat_max_length＝部屋のひとことの字数。
const WHOLE_NUMBER_RANGES := {"max_rooms": Vector2(1.0, 100.0), "chat_max_length": Vector2(1.0, 200.0)}
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
	var fps: Variant = data.get("server_max_fps")
	if not (fps is float or fps is int) or float(fps) != floorf(float(fps)) or float(fps) < SERVER_MAX_FPS_RANGE.x or float(fps) > SERVER_MAX_FPS_RANGE.y:
		errors.append("online.server_max_fps: %d〜%d の整数が必要です" % [int(SERVER_MAX_FPS_RANGE.x), int(SERVER_MAX_FPS_RANGE.y)])
	return errors


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


## 部屋のひとことの、字数の上限。
static func chat_max_length() -> int:
	return int(values()["chat_max_length"])


## 部屋を作る画面に、最初から入れておく部屋の名前（文字が打ちにくい端末でも、そのまま作れるように）。
static func default_room() -> String:
	return str(values()["default_room"])


static func connect_timeout_s() -> float:
	return float(values()["connect_timeout_s"])
