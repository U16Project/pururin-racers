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
## 走行計算・画面表示がIDで参照する項目。順序はJSONの stat_ids に従う。
const CODE_STAT_IDS := [
	"top_speed", "acceleration", "stamina", "cardio",
	"aero", "pack", "contact_resistance", "handling",
]

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
	# 値そのものはJSONが正本。コード側は値の一致ではなく、整数性と相互の整合だけを確認する。
	for key in REQUIRED_NUMBERS:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	if int(data.allocation_min) < 1 or int(data.allocation_min) > int(data.allocation_max):
		errors.append("allocation_min / allocation_max: 1 ≦ allocation_min ≦ allocation_max にしてください")
	if int(data.attribute_bonus_per_stat) < 0 or int(data.attribute_stat_max) < int(data.allocation_max):
		errors.append("属性補正: attribute_bonus_per_stat は0以上、attribute_stat_max は allocation_max 以上にしてください")
	if int(data.race_effective_min) < 1 or int(data.race_effective_min) > int(data.race_effective_max):
		errors.append("race_effective_min / race_effective_max: 1 ≦ min ≦ max にしてください")
	if int(data.race_phase_count) < 1:
		errors.append("race_phase_count: 1以上が必要です")
	var stat_ids: Variant = data.get("stat_ids")
	if not stat_ids is Array or stat_ids.is_empty():
		errors.append("stat_ids: 1個以上の配列が必要です")
	else:
		var seen := {}
		for index in stat_ids.size():
			if not stat_ids[index] is String or str(stat_ids[index]).is_empty() or seen.has(stat_ids[index]):
				errors.append("stat_ids[%d]: 空または重複です" % index)
			seen[stat_ids[index]] = true
		for stat_id in CODE_STAT_IDS:
			if not seen.has(stat_id):
				errors.append("stat_ids: コードが参照する %s が必要です" % stat_id)
		# 初期配分（default_allocation）は合計を全項目へ均等に割る。
		var total := int(data.allocation_total)
		if total % stat_ids.size() != 0:
			errors.append("allocation_total: ステータス数で割り切れる必要があります（初期配分を均等にするため）")
		elif total / stat_ids.size() < int(data.allocation_min) or total / stat_ids.size() > int(data.allocation_max):
			errors.append("allocation_total: 均等配分が allocation_min〜allocation_max に収まる必要があります")
	_validate_rank_groups(data, errors)
	_validate_attributes(data, stat_ids, errors)
	_validate_running_styles(data, stat_ids, errors)
	return errors


static func _validate_rank_groups(data: Dictionary, errors: PackedStringArray) -> void:
	var groups: Variant = data.get("rank_groups")
	if not groups is Array or groups.is_empty():
		errors.append("rank_groups: 1組以上の配列が必要です")
		return
	var previous_last := 0
	for index in groups.size():
		var group: Variant = groups[index]
		if not group is Array or group.size() != 2 or not _is_integer(group[0]) or not _is_integer(group[1]):
			errors.append("rank_groups[%d]: 2個の整数順位が必要です" % index)
			continue
		# 順位組は1位から隙間・重なりなく昇順に並べる。
		if int(group[0]) != previous_last + 1 or int(group[1]) < int(group[0]):
			errors.append("rank_groups[%d]: 前の組の次の順位から始まる昇順の範囲にしてください" % index)
		previous_last = int(group[1])
	var bonus: Variant = data.get("rank_bonus")
	if not bonus is Dictionary:
		errors.append("rank_bonus: matching / adjacent / distant が必要です")
		return
	for key in ["matching", "adjacent", "distant"]:
		if not _is_integer(bonus.get(key)):
			errors.append("rank_bonus.%s: 整数が必要です" % key)


static func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


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
		var color_value := str(definition.get("color", ""))
		if not color_value.begins_with("#") or (color_value.length() != 7 and color_value.length() != 9):
			errors.append("attributes.%s.color: 有効な色が必要です" % attribute_id)
		for stat_id in definition.bonus_stats:
			if not stat_id in stat_ids:
				errors.append("attributes.%s.bonus_stats: 未知のステータスです" % attribute_id)
		# 第一カラーの選択肢（体の色と、ふちの線の色の組）。
		var primary_colors: Variant = definition.get("primary_colors")
		if not primary_colors is Array or primary_colors.is_empty():
			errors.append("attributes.%s.primary_colors: 第一カラーの選択肢が1つ以上必要です" % attribute_id)
			continue
		for index in primary_colors.size():
			var choice: Variant = primary_colors[index]
			if not choice is Dictionary or not choice.get("color") is String or not Color.html_is_valid(choice["color"]) or not choice.get("outline") is String or not Color.html_is_valid(choice["outline"]):
				errors.append("attributes.%s.primary_colors[%d]: color と outline（どちらも色）が必要です" % [attribute_id, index])


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
		var group_count: int = data.rank_groups.size() if data.get("rank_groups") is Array else 0
		if group_index < 0 or group_index >= group_count or phase_index < 0 or phase_index >= int(data.race_phase_count):
			errors.append("running_styles.%s: 順位組または区間が不正です" % style_id)
		if not phase_bonus is Dictionary or not phase_bonus.get("stat") in stat_ids or not _is_integer(phase_bonus.get("amount")):
			errors.append("running_styles.%s.phase_bonus: 定義済み項目と整数の加算量が必要です" % style_id)


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
