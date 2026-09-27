extends RefCounted
## 個体の基礎配分から、属性・脚質・順位・区間を反映した有効ステータスを作る。

const Config := preload("res://scripts/config/pururin_stats_config.gd")


static func default_allocation() -> Dictionary:
	var allocation := {}
	for stat_id in Config.values()["stat_ids"]:
		allocation[stat_id] = 5
	return allocation


static func validate_allocation(allocation: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not allocation is Dictionary:
		return PackedStringArray(["配分はオブジェクトである必要があります"])
	var total := 0
	for stat_id in Config.values()["stat_ids"]:
		var value: Variant = allocation.get(stat_id)
		if not (value is int or value is float) or int(value) != value:
			errors.append("%s: 整数が必要です" % stat_id)
			continue
		if value < Config.values()["allocation_min"] or value > Config.values()["allocation_max"]:
			errors.append("%s: 1〜10 の範囲にしてください" % stat_id)
		total += int(value)
	for stat_id in allocation:
		if not stat_id in Config.values()["stat_ids"]:
			errors.append("%s: 未知のステータスです" % stat_id)
	if total != int(Config.values()["allocation_total"]):
		errors.append("配分合計: 40 が必要です")
	return errors


static func pre_race_stats(attribute_id: String, allocation: Dictionary) -> Dictionary:
	var errors := validate_allocation(allocation)
	assert(errors.is_empty(), "; ".join(errors))
	var attributes: Dictionary = Config.values()["attributes"]
	assert(attributes.has(attribute_id), "未知の属性です: %s" % attribute_id)
	var bonus_stats: Array = attributes[attribute_id]["bonus_stats"]
	var result := {}
	for stat_id in Config.values()["stat_ids"]:
		var value := int(allocation[stat_id])
		if stat_id in bonus_stats:
			value = min(value + int(Config.values()["attribute_bonus_per_stat"]), int(Config.values()["attribute_stat_max"]))
		result[stat_id] = value
	return result


static func effective_stats(attribute_id: String, allocation: Dictionary, style_id: String, live_rank: int, progress_ratio: float) -> Dictionary:
	var styles: Dictionary = Config.values()["running_styles"]
	assert(styles.has(style_id), "未知の脚質です: %s" % style_id)
	var style: Dictionary = styles[style_id]
	var result := pre_race_stats(attribute_id, allocation)
	var position_bonus := rank_bonus(style_id, live_rank)
	for stat_id in result:
		result[stat_id] = int(result[stat_id]) + position_bonus
	var phase_index := mini(int(floor(clampf(progress_ratio, 0.0, 0.999999) * int(Config.values()["race_phase_count"]))), int(Config.values()["race_phase_count"]) - 1)
	if phase_index == int(style["phase_index"]):
		var phase_bonus: Dictionary = style["phase_bonus"]
		result[phase_bonus["stat"]] = int(result[phase_bonus["stat"]]) + int(phase_bonus["amount"])
	for stat_id in result:
		result[stat_id] = clampi(int(result[stat_id]), int(Config.values()["race_effective_min"]), int(Config.values()["race_effective_max"]))
	return result


static func rank_bonus(style_id: String, live_rank: int) -> int:
	var styles: Dictionary = Config.values()["running_styles"]
	assert(styles.has(style_id), "未知の脚質です: %s" % style_id)
	var group_index := _rank_group_index(live_rank)
	var desired_group := int(styles[style_id]["rank_group_index"])
	var distance: int = abs(group_index - desired_group)
	var bonus: Dictionary = Config.values()["rank_bonus"]
	if distance == 0:
		return int(bonus["matching"])
	if distance == 1:
		return int(bonus["adjacent"])
	return int(bonus["distant"])


static func _rank_group_index(live_rank: int) -> int:
	for index in Config.values()["rank_groups"].size():
		var group: Array = Config.values()["rank_groups"][index]
		if live_rank >= int(group[0]) and live_rank <= int(group[1]):
			return index
	return Config.values()["rank_groups"].size() - 1 if live_rank > 0 else 0
