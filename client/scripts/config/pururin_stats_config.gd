extends RefCounted
## 出走前ステータスとレース中補正の定義。初期値の正本は JSON のみとする。

const PATH := "res://data/config/pururin_stats.json"
const REQUIRED_NUMBERS := [
	"schema_version", "allocation_total", "allocation_min", "allocation_max",
	"attribute_bonus_per_stat", "attribute_stat_max", "race_effective_min",
	"race_effective_max", "race_phase_count",
]
const ALLOWED_KEYS := [
	"schema_version", "stat_ids", "allocation_total", "allocation_min", "allocation_max",
	"attribute_bonus_per_stat", "attribute_stat_max", "race_effective_min",
	"race_effective_max", "rank_groups", "rank_bonus", "race_phase_count",
	"attributes", "running_styles",
]
const ATTRIBUTE_IDS := ["earth", "water", "fire", "wind"]
const RUNNING_STYLE_IDS := ["escape", "pace", "stalk", "closer"]

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
	for key in REQUIRED_NUMBERS:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			errors.append("%s: 有限の数値が必要です" % key)
	if not errors.is_empty():
		return errors
	for key in data:
		if not key in ALLOWED_KEYS:
			errors.append("%s: 未知の項目です" % key)
	if int(data.schema_version) != 1:
		errors.append("schema_version: 1 が必要です")
	if int(data.allocation_min) != 1 or int(data.allocation_max) != 10:
		errors.append("allocation_min / allocation_max: 1 / 10 が必要です")
	if int(data.allocation_total) != 40:
		errors.append("allocation_total: 40 が必要です")
	if int(data.attribute_bonus_per_stat) != 2 or int(data.attribute_stat_max) != 12:
		errors.append("属性補正: 各+2、上限12が必要です")
	if int(data.race_effective_min) != 1 or int(data.race_effective_max) != 15:
		errors.append("レース中有効値: 1〜15 が必要です")
	var stat_ids: Variant = data.get("stat_ids")
	if not stat_ids is Array or stat_ids.size() != 8:
		errors.append("stat_ids: 8個の配列が必要です")
	else:
		var seen := {}
		for index in stat_ids.size():
			if not stat_ids[index] is String or str(stat_ids[index]).is_empty() or seen.has(stat_ids[index]):
				errors.append("stat_ids[%d]: 空または重複です" % index)
			seen[stat_ids[index]] = true
		if int(data.allocation_total) != stat_ids.size() * 5:
			errors.append("allocation_total: 初期値5×ステータス数と一致する必要があります")
	_validate_rank_groups(data, errors)
	_validate_attributes(data, stat_ids, errors)
	_validate_running_styles(data, stat_ids, errors)
	return errors


static func _validate_rank_groups(data: Dictionary, errors: PackedStringArray) -> void:
	var groups: Variant = data.get("rank_groups")
	if not groups is Array or groups.size() != 4:
		errors.append("rank_groups: 4組の配列が必要です")
		return
	for index in groups.size():
		if not groups[index] is Array or groups[index].size() != 2:
			errors.append("rank_groups[%d]: 2個の順位が必要です" % index)
	var bonus: Variant = data.get("rank_bonus")
	if not bonus is Dictionary or int(bonus.get("matching", 99)) != 1 or int(bonus.get("adjacent", 99)) != 0 or int(bonus.get("distant", 99)) != -1:
		errors.append("rank_bonus: matching=1 / adjacent=0 / distant=-1 が必要です")


static func _validate_attributes(data: Dictionary, stat_ids: Array, errors: PackedStringArray) -> void:
	var attributes: Variant = data.get("attributes")
	if not attributes is Dictionary:
		errors.append("attributes: 地水火風の4属性が必要です")
		return
	for attribute_id in ATTRIBUTE_IDS:
		if not attributes.has(attribute_id):
			errors.append("attributes.%s: 定義が必要です" % attribute_id)
	if attributes.size() != ATTRIBUTE_IDS.size():
		errors.append("attributes: 地水火風の4属性が必要です")
		return
	for attribute_id in attributes:
		var definition: Variant = attributes[attribute_id]
		if not definition is Dictionary or not definition.get("bonus_stats") is Array or definition.bonus_stats.size() != 2:
			errors.append("attributes.%s.bonus_stats: 2項目が必要です" % attribute_id)
			continue
		for stat_id in definition.bonus_stats:
			if not stat_id in stat_ids:
				errors.append("attributes.%s.bonus_stats: 未知のステータスです" % attribute_id)


static func _validate_running_styles(data: Dictionary, stat_ids: Array, errors: PackedStringArray) -> void:
	var styles: Variant = data.get("running_styles")
	if not styles is Dictionary:
		errors.append("running_styles: 逃げ・先行・差し・追い込みが必要です")
		return
	for style_id in RUNNING_STYLE_IDS:
		if not styles.has(style_id):
			errors.append("running_styles.%s: 定義が必要です" % style_id)
	if styles.size() != RUNNING_STYLE_IDS.size():
		errors.append("running_styles: 逃げ・先行・差し・追い込みが必要です")
		return
	for style_id in styles:
		var definition: Variant = styles[style_id]
		if not definition is Dictionary:
			errors.append("running_styles.%s: オブジェクトが必要です" % style_id)
			continue
		var group_index := int(definition.get("rank_group_index", -1))
		var phase_index := int(definition.get("phase_index", -1))
		var phase_bonus: Variant = definition.get("phase_bonus")
		if group_index < 0 or group_index >= 4 or phase_index < 0 or phase_index >= int(data.race_phase_count):
			errors.append("running_styles.%s: 順位組または区間が不正です" % style_id)
		if not phase_bonus is Dictionary or not phase_bonus.get("stat") in stat_ids or int(phase_bonus.get("amount", 0)) != 2:
			errors.append("running_styles.%s.phase_bonus: 定義済み項目への+2が必要です" % style_id)


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
