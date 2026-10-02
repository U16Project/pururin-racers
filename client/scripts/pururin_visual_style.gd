extends RefCounted
## 属性ごとの表示色。個体の配列順・ゲート・順位には依存させない。

const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")

static func color_for_pururin(pururin: Dictionary) -> Color:
	var attribute_id := str(pururin.get("attribute", ""))
	var attributes: Dictionary = PururinStatsConfig.values().get("attributes", {})
	var definition: Variant = attributes.get(attribute_id, {})
	var fallback := Color.WHITE
	if definition is Dictionary:
		var color_value := str(definition.get("color", ""))
		if not color_value.is_empty():
			fallback = Color.from_string(color_value, Color.WHITE)
	var individual_color := str(pururin.get("visual_color", ""))
	if not individual_color.is_empty():
		return Color.from_string(individual_color, fallback)
	return fallback

static func color_for_racer_id(racer_id: String) -> Color:
	var pururin := PururinRosterConfig.pururin_by_id(racer_id)
	return color_for_pururin(pururin) if not pururin.is_empty() else Color.WHITE
