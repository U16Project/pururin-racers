extends RefCounted
## つなぐサーバーの選び方（標準／自分で指定）と、自分で指定したURL。ユーザーの保存場所（user://）に置く。
## 標準のサーバーの場所は、data/config/online.json（OnlineConfig）。ここには、使う人の選びだけを置く。

const DEFAULT_SAVE_PATH := "user://online_server.json"
const CHOICE_DEFAULT := "default"
const CHOICE_CUSTOM := "custom"

static var _save_path: String = DEFAULT_SAVE_PATH
static var _loaded := false
static var _choice := CHOICE_DEFAULT
static var _custom_url := ""


## 保存する場所を替えて、読み直す（テスト用。本物の選びに触らないため）。
static func use_path(path: String) -> void:
	_save_path = path
	_loaded = false


static func choice() -> String:
	_load()
	return _choice


static func custom_url() -> String:
	_load()
	return _custom_url


## 選びと、自分で指定したURLを保存する。
static func save(new_choice: String, new_custom_url: String) -> void:
	_choice = new_choice if new_choice == CHOICE_CUSTOM else CHOICE_DEFAULT
	_custom_url = new_custom_url.strip_edges()
	_loaded = true
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_error("サーバーの選びを保存できません: %s" % _save_path)
		return
	file.store_string(JSON.stringify({"choice": _choice, "custom_url": _custom_url}, "  "))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_choice = CHOICE_DEFAULT
	_custom_url = ""
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not parsed is Dictionary:
		return
	if parsed.get("custom_url") is String:
		_custom_url = str(parsed["custom_url"])
	if parsed.get("choice") == CHOICE_CUSTOM:
		_choice = CHOICE_CUSTOM
