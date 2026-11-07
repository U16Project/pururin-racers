extends RefCounted
## この機械の表示設定。初期値の正本は online.json。
const Config := preload("res://scripts/config/online_config.gd")
const DEFAULT_PATH := "user://online_parts_settings.json"
static var _path := DEFAULT_PATH
static var _loaded := false
static var _hidden: bool

static func use_path(path: String) -> void:
	_path = path
	_loaded = false

static func hidden() -> bool:
	if not _loaded:
		_loaded = true
		_hidden = bool(Config.values()["hide_remote_parts"])
		if FileAccess.file_exists(_path):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
			if value is Dictionary and value.get("hide_remote_parts") is bool:
				_hidden = value["hide_remote_parts"]
	return _hidden

static func set_hidden(on: bool) -> void:
	_hidden = on
	_loaded = true
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"hide_remote_parts": on}))
	load("res://scripts/online/online_custom_pururins.gd").refresh()
