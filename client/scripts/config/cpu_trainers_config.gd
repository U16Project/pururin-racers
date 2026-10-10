extends RefCounted
## 人物一覧と既存のCPU判断プロフィールを分けて管理する。
const PATH := "res://data/config/cpu_trainers.json"
const LocalRaceConfig := preload("res://scripts/config/local_race_config.gd")
static var _cached: Array = []
static var _attempted := false

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary or data.get("schema_version") != 1 or not data.get("trainers") is Array or data["trainers"].is_empty():
		return PackedStringArray(["CPUトレーナー一覧の形式が不正です"])
	var profiles := {}
	for profile: Dictionary in LocalRaceConfig.values().get("cpu_trainer_profiles", []):
		profiles[str(profile["id"])] = true
	var ids := {}
	for trainer: Variant in data["trainers"]:
		if not trainer is Dictionary:
			errors.append("トレーナーはオブジェクトが必要です")
			continue
		var id := str(trainer.get("id", ""))
		if id.is_empty() or ids.has(id):
			errors.append("CPUトレーナーIDが空または重複です")
		ids[id] = true
		if str(trainer.get("name", "")).strip_edges().is_empty() or not profiles.has(str(trainer.get("profile_id", ""))):
			errors.append("CPUトレーナー名またはプロフィールが不正です")
		if str(trainer.get("portrait_path", "")).is_empty() or str(trainer.get("introduction", "")).strip_edges().is_empty():
			errors.append("トレーナー画像と紹介文が必要です")
		if str(trainer.get("favorite_running_style", "")) not in ["escape", "pace", "stalk", "closer"]:
			errors.append("得意脚質が不正です")
	return errors

static func values() -> Array:
	if not _attempted:
		_attempted = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var errors := validate(data)
		if not errors.is_empty():
			push_error("%s: %s" % [PATH, "; ".join(errors)])
		else:
			_cached = data["trainers"].duplicate(true)
	return _cached.duplicate(true)

static func by_id(identifier: String) -> Dictionary:
	for trainer: Dictionary in values():
		if trainer["id"] == identifier:
			return trainer
	return {}
