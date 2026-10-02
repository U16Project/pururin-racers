extends RefCounted
## ローカル検証用の初期ロスター。個体の共通定義を保持し、所持データとは分ける。

const PATH := "res://data/config/pururin_roster.json"
const StatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const LocalRaceConfig := preload("res://scripts/config/local_race_config.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")

static var _cached: Dictionary = {}
static var _attempted := false
static var last_error := ""


static func load_file(path: String = PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません (%s)" % [path, FileAccess.get_open_error()]}
	return parse_text(file.get_as_text(), path)


static func parse_text(content: String, source: String = PATH) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"error": "%s:%d: %s" % [source, parser.get_error_line(), parser.get_error_message()]}
	var errors := validate(parser.data)
	return {"data": parser.data} if errors.is_empty() else {"error": "%s: %s" % [source, "; ".join(errors)]}


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["ルートはオブジェクトである必要があります"])
	if int(data.get("schema_version", -1)) != 1:
		errors.append("schema_version: 1 が必要です")
	for key in data:
		if key not in ["schema_version", "roster"]:
			errors.append("%s: 未知の項目です" % key)
	var roster: Variant = data.get("roster")
	if not roster is Array or roster.size() != 8:
		errors.append("roster: 8体の配列が必要です")
		return errors
	var known_attributes: Dictionary = StatsConfig.values().get("attributes", {})
	var known_styles: Dictionary = StatsConfig.values().get("running_styles", {})
	var trainer_profile_ids := _trainer_profile_ids()
	var ids := {}
	var initial_player_count := 0
	for index in roster.size():
		var pururin: Variant = roster[index]
		if not pururin is Dictionary:
			errors.append("roster[%d]: オブジェクトが必要です" % index)
			continue
		_validate_pururin(pururin, index, known_attributes, known_styles, trainer_profile_ids, ids, errors)
		if str(pururin.get("control_kind", "")) == "player":
			initial_player_count += 1
	if initial_player_count != 1:
		errors.append("roster: control_kind が player の初期操作個体は1体必要です")
	return errors


static func _validate_pururin(pururin: Dictionary, index: int, attributes: Dictionary, styles: Dictionary, trainer_profile_ids: Dictionary, ids: Dictionary, errors: PackedStringArray) -> void:
	for key in pururin:
		if key not in ["id", "display_name", "control_kind", "trainer_profile_id", "attribute", "visual_color", "running_style", "allocation"]:
			errors.append("roster[%d].%s: 未知の項目です" % [index, key])
	var identifier := str(pururin.get("id", ""))
	if identifier.is_empty() or ids.has(identifier):
		errors.append("roster[%d].id: 空または重複です" % index)
	else:
		ids[identifier] = true
	if str(pururin.get("display_name", "")).strip_edges().is_empty():
		errors.append("roster[%d].display_name: 表示名が必要です" % index)
	var control_kind := str(pururin.get("control_kind", ""))
	if control_kind not in ["player", "cpu"]:
		errors.append("roster[%d].control_kind: player または cpu が必要です" % index)
	if not attributes.has(str(pururin.get("attribute", ""))):
		errors.append("roster[%d].attribute: 定義済み属性が必要です" % index)
	if not styles.has(str(pururin.get("running_style", ""))):
		errors.append("roster[%d].running_style: 定義済み脚質が必要です" % index)
	var visual_color := str(pururin.get("visual_color", ""))
	if not visual_color.begins_with("#") or (visual_color.length() != 7 and visual_color.length() != 9):
		errors.append("roster[%d].visual_color: 有効な色が必要です" % index)
	var allocation: Variant = pururin.get("allocation")
	var allocation_errors := StatsMath.validate_allocation(allocation)
	for allocation_error in allocation_errors:
		errors.append("roster[%d].allocation: %s" % [index, allocation_error])
	var profile_id := str(pururin.get("trainer_profile_id", ""))
	if not trainer_profile_ids.has(profile_id):
		errors.append("roster[%d].trainer_profile_id: 定義済みCPUプロフィールが必要です" % index)


static func _trainer_profile_ids() -> Dictionary:
	var result := {}
	for profile: Variant in LocalRaceConfig.values().get("cpu_trainer_profiles", []):
		if profile is Dictionary:
			result[str(profile.get("id", ""))] = true
	return result


static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var result := load_file()
		if result.has("error"):
			last_error = result.error
			push_error(last_error)
		else:
			_cached = result.data
			_cached.make_read_only()
	return _cached


static func pururin_by_id(identifier: String) -> Dictionary:
	for pururin: Variant in values().get("roster", []):
		if pururin is Dictionary and pururin.get("id") == identifier:
			return pururin
	return {}


static func default_player_pururin_id() -> String:
	for pururin: Variant in values().get("roster", []):
		if pururin is Dictionary and str(pururin.get("control_kind", "")) == "player":
			return str(pururin.get("id", ""))
	return ""
