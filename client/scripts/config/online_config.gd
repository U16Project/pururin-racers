extends RefCounted
## オンライン対戦の設定（つなぐ先のサーバーなど）。初期値は data/config/online.json だけに置く。

const CONFIG_PATH := "res://data/config/online.json"
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
	return errors


## つなぐ先として使える形か（ws:// か wss:// で始まり、そのあとに何か書いてある）。
static func is_server_url(url: String) -> bool:
	for prefix: String in URL_PREFIXES:
		if url.begins_with(prefix) and url.length() > prefix.length():
			return true
	return false


static func server_url() -> String:
	return str(values()["server_url"])


static func connect_timeout_s() -> float:
	return float(values()["connect_timeout_s"])
