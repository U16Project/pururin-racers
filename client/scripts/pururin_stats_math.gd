extends RefCounted
## 個体の基礎配分から、属性・脚質・順位・区間を反映した有効ステータスを作る。

const Config := preload("res://scripts/config/pururin_stats_config.gd")


static func default_allocation() -> Dictionary:
	# 合計を全項目へ均等に割る。割り切れることは設定検証で保証する。
	var stat_ids: Array = Config.values()["stat_ids"]
	var per_stat := int(Config.values()["allocation_total"]) / stat_ids.size()
	var allocation := {}
	for stat_id in stat_ids:
		allocation[stat_id] = per_stat
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
			errors.append("%s: %d〜%d の範囲にしてください" % [stat_id, int(Config.values()["allocation_min"]), int(Config.values()["allocation_max"])])
		total += int(value)
	for stat_id in allocation:
		if not stat_id in Config.values()["stat_ids"]:
			errors.append("%s: 未知のステータスです" % stat_id)
	if total != int(Config.values()["allocation_total"]):
		errors.append("配分合計: %d が必要です" % int(Config.values()["allocation_total"]))
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


static func effective_stats(attribute_id: String, allocation: Dictionary, style_id: String, live_rank: int, progress_ratio: float, field_size: int = rank_reference_size()) -> Dictionary:
	var styles: Dictionary = Config.values()["running_styles"]
	assert(styles.has(style_id), "未知の脚質です: %s" % style_id)
	var style: Dictionary = styles[style_id]
	var result := pre_race_stats(attribute_id, allocation)
	var position_bonus := rank_bonus(style_id, live_rank, field_size)
	for stat_id in result:
		result[stat_id] = int(result[stat_id]) + position_bonus
	var phase_index := mini(int(floor(clampf(progress_ratio, 0.0, 0.999999) * int(Config.values()["race_phase_count"]))), int(Config.values()["race_phase_count"]) - 1)
	if phase_index == int(style["phase_index"]):
		var phase_bonus: Dictionary = style["phase_bonus"]
		result[phase_bonus["stat"]] = int(result[phase_bonus["stat"]]) + int(phase_bonus["amount"])
	for stat_id in result:
		result[stat_id] = clampi(int(result[stat_id]), int(Config.values()["race_effective_min"]), int(Config.values()["race_effective_max"]))
	return result


## 脚質が得意とする順位の組（0が先頭の組）。
static func style_rank_group_index(style_id: String) -> int:
	var styles: Dictionary = Config.values()["running_styles"]
	assert(styles.has(style_id), "未知の脚質です: %s" % style_id)
	return int(styles[style_id]["rank_group_index"])


static func rank_group_count() -> int:
	return Config.values()["rank_groups"].size()


## 順位の組が前提にしている出走数（組の最後の順位。現行8）。
static func rank_reference_size() -> int:
	var groups: Array = Config.values()["rank_groups"]
	return int(groups[groups.size() - 1][1])


## 脚質の「得意な順位」が、いくつ続くか。満員（現行8人）のときの1組の幅（現行2）が最小で、
## 出る人数が多いときは「人数 ÷ 脚質の組の数」の切り上げまで広げる（9〜12人なら3、13〜16人なら4）。
static func rank_window_width(field_size: int) -> int:
	var groups: Array = Config.values()["rank_groups"]
	var base_width := int(groups[0][1]) - int(groups[0][0]) + 1
	return maxi(base_width, ceili(float(field_size) / float(groups.size())))


## その脚質の「得意な順位」の範囲（x が最初の順位、y が最後の順位）。
## 逃げ（組0）はいつも上から、追込（最後の組）はいつも下から。間の脚質は、その間を均等に割った位置（四捨五入）。
## 満員（現行8人）のときは、設定の rank_groups と同じ範囲になる。
static func style_rank_window(style_id: String, field_size: int) -> Vector2i:
	var width := rank_window_width(field_size)
	var last_group := rank_group_count() - 1
	var span := maxi(field_size - width, 0)
	var first := 1 + roundi(float(style_rank_group_index(style_id)) * float(span) / float(maxi(last_group, 1)))
	return Vector2i(first, first + width - 1)


## 順位による補正。得意な順位の中なら matching、そこから「得意な順位の幅」以内なら adjacent、それより離れたら distant。
static func rank_bonus(style_id: String, live_rank: int, field_size: int = rank_reference_size()) -> int:
	var window := style_rank_window(style_id, field_size)
	var distance := 0
	if live_rank < window.x:
		distance = window.x - live_rank
	elif live_rank > window.y:
		distance = live_rank - window.y
	var bonus: Dictionary = Config.values()["rank_bonus"]
	if distance == 0:
		return int(bonus["matching"])
	if distance <= rank_window_width(field_size):
		return int(bonus["adjacent"])
	return int(bonus["distant"])
