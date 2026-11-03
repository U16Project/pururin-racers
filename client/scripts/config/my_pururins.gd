extends RefCounted
## 作成コーナーで作ったぷるりん。1体ずつ、保存の場所（pururin_maker.json の save_folder）に、別のファイルで置く。
## 数に決まりは無い（置ける分だけ作れる）。ファイルの中身：
##   {"schema_version": 1, "id", "display_name", "trainer_id", "attribute", "running_style", "allocation", "look"}
## look は、ぷるりんの見た目の設定（pururin_looks.json の1体ぶん）と同じ形。
## 読めないファイルや、検査を通らないファイルは、使わずに、理由を errors() に入れる（作成コーナーに出す）。
## オンラインでは使わない（サーバーは、一覧 pururin_roster.json の個体しか知らない）。

const MakerConfig := preload("res://scripts/config/pururin_maker_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")
const SCHEMA_VERSION := 1
const KEYS := ["schema_version", "id", "display_name", "trainer_id", "attribute", "running_style", "allocation", "look"]

static var _loaded := false
## ID → 個体（一覧の個体と同じ形。control_kind は player、trainer_name 付き）。並びは、作った順。
static var _pururins := {}
## ID → 見た目（第一カラーを色に直したもの）。
static var _looks := {}
## ID → 保存の中身（作成コーナーで直すとき用）。
static var _entries := {}
static var _errors: Array[String] = []
## 保存の場所を替えたとき（テスト用。本物の保存に触らないため）。空なら、設定の場所。
static var _folder_override := ""


static func reload() -> void:
	_loaded = false


static func folder() -> String:
	return _folder_override if not _folder_override.is_empty() else str(MakerConfig.values().get("save_folder", ""))


## 保存の場所を替えて、読み直す（テスト用）。空を渡すと、設定の場所に戻す。
static func use_folder(path: String) -> void:
	_folder_override = path
	_loaded = false


## 使える個体のID（作った順）。
static func ids() -> Array[String]:
	_load()
	var found: Array[String] = []
	for identifier: String in _pururins:
		found.append(identifier)
	return found


static func pururin_by_id(identifier: String) -> Dictionary:
	_load()
	return _pururins.get(identifier, {})


static func look_for(identifier: String) -> Dictionary:
	_load()
	return _looks.get(identifier, {})


## 保存の中身（直す前の形）。無ければ空。
static func entry(identifier: String) -> Dictionary:
	_load()
	return (_entries.get(identifier, {}) as Dictionary).duplicate(true)


## 使えなかったファイルと、その理由。
static func errors() -> Array[String]:
	_load()
	return _errors.duplicate()


## 新しいID（作った時刻と、でたらめな文字）。
static func new_id() -> String:
	return "%s%d-%s" % [MakerConfig.values()["id_prefix"], int(Time.get_unix_time_from_system()), Crypto.new().generate_random_bytes(3).hex_encode()]


## 保存の中身を検査する。誤りの一覧（空なら正しい）。
static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("JSONのオブジェクトが必要です")
		return errors
	for key: String in KEYS:
		if not data.has(key):
			errors.append("%s: 必要な項目がありません" % key)
	for key: String in data:
		if key not in KEYS:
			errors.append("%s: 未知の項目です" % key)
	if not errors.is_empty():
		return errors
	if int(data["schema_version"]) != SCHEMA_VERSION:
		errors.append("schema_version: %d が必要です" % SCHEMA_VERSION)
	var prefix := str(MakerConfig.values()["id_prefix"])
	if not str(data["id"]).begins_with(prefix):
		errors.append("id: %s で始まる名前が必要です" % prefix)
	if str(data["display_name"]).length() > int(MakerConfig.values()["name_max_length"]):
		errors.append("display_name: %d文字までです" % int(MakerConfig.values()["name_max_length"]))
	var stats := PururinStatsConfig.values()
	PururinRosterConfig._validate_pururin(_record(data), 0, stats["attributes"], stats["running_styles"], {}, errors)
	if errors.is_empty():
		errors.append_array(PururinLookConfig.validate_single_look(data["look"], stats["attributes"][str(data["attribute"])]["primary_colors"]))
	return errors


## 保存する（同じIDのファイルは上書き）。うまくいけば空、だめなら理由。
static func save(data: Dictionary) -> String:
	var errors := validate(data)
	if not errors.is_empty():
		return "; ".join(errors)
	var error := DirAccess.make_dir_recursive_absolute(folder())
	if error != OK:
		return "%s を作れません（%s）" % [folder(), error_string(error)]
	var file := FileAccess.open(_path(str(data["id"])), FileAccess.WRITE)
	if file == null:
		return "%s に書けません（%s）" % [_path(str(data["id"])), error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	_loaded = false
	return ""


## 消す。うまくいけば空、だめなら理由。
static func remove(identifier: String) -> String:
	var error := DirAccess.remove_absolute(_path(identifier))
	_loaded = false
	return "" if error == OK else "%s を消せません（%s）" % [_path(identifier), error_string(error)]


static func _path(identifier: String) -> String:
	return folder().path_join(identifier + ".json")


## 一覧の個体と同じ形の記録（レースや選択の画面が使う）。
static func _record(data: Dictionary) -> Dictionary:
	return {
		"id": str(data["id"]),
		"display_name": str(data["display_name"]),
		"trainer_id": str(data["trainer_id"]),
		"trainer_name": str(CpuTrainers.by_id(str(data["trainer_id"])).get("name", "")),
		"control_kind": "player",
		"attribute": str(data["attribute"]),
		"running_style": str(data["running_style"]),
		"allocation": data["allocation"],
	}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_pururins = {}
	_looks = {}
	_entries = {}
	_errors = []
	var directory := folder()
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):
		return
	var files := DirAccess.get_files_at(directory)
	files.sort()
	var attributes: Dictionary = PururinStatsConfig.values().get("attributes", {})
	for file: String in files:
		if file.get_extension() != "json":
			continue
		var path := directory.path_join(file)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var errors := validate(data)
		if errors.is_empty() and str(data["id"]) != file.get_basename():
			errors.append("id: ファイル名（%s）と同じにします" % file.get_basename())
		if not errors.is_empty():
			var name := str(data.get("display_name", file)) if data is Dictionary else file
			_errors.append("%s（%s）: %s" % [name, path, "; ".join(errors)])
			continue
		var identifier := str(data["id"])
		_entries[identifier] = data
		_pururins[identifier] = _record(data)
		_looks[identifier] = PururinLookConfig.resolved_look(data["look"], attributes[str(data["attribute"])]["primary_colors"])
