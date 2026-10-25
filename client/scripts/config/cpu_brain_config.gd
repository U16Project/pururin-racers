extends RefCounted
## 育てたCPU（強化学習の頭）の設定。JSONのみを初期値の正本とする（data/config/cpu_brain.json）。

const PATH := "res://data/config/cpu_brain.json"
const OBSERVE_KEYS := ["gap_scale_m", "speed_scale_kmh", "group_gap_m", "typical_finish_s"]
static var _cached := {}
static var _attempted := false


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary or data.get("schema_version") != 1:
		return PackedStringArray(["育てたCPUの設定の形式が不正です"])
	if str(data.get("brain", "")).is_empty():
		errors.append("brain: 使う頭のファイルが必要です")
	if float(data.get("decide_every_s", 0.0)) <= 0.0 or int(data.get("field", 0)) < 2:
		errors.append("decide_every_s・field が不正です")
	var observe: Variant = data.get("observe")
	if not observe is Dictionary:
		errors.append("observe が必要です")
	else:
		for key: String in OBSERVE_KEYS:
			if not (observe as Dictionary).has(key):
				errors.append("observe.%s が必要です" % key)
	return errors


static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var errors := validate(data)
		if not errors.is_empty():
			push_error("%s: %s" % [PATH, "; ".join(errors)])
		else:
			_cached = data
	return _cached


static func observe() -> Dictionary:
	return values().get("observe", {})
