extends GutTest

const Config := preload("res://scripts/config/pururin_stats_config.gd")
const Stats := preload("res://scripts/pururin_stats_math.gd")


func test_shipped_stat_definition_is_valid_and_default_allocation_is_forty_points() -> void:
	var result := Config.load_file()
	assert_true(result.has("data"))
	assert_true(Config.validate(result.data).is_empty())
	var allocation := Stats.default_allocation()
	assert_true(Stats.validate_allocation(allocation).is_empty())
	assert_eq(allocation.size(), 8)
	assert_eq(allocation.values().reduce(func(total, value): return total + value, 0), 40)


func test_attribute_adds_four_points_and_only_its_two_stats_can_reach_twelve() -> void:
	var allocation := Stats.default_allocation()
	allocation.top_speed = 10
	allocation.aero = 10
	allocation.stamina = 1
	allocation.cardio = 1
	allocation.acceleration = 4
	allocation.pack = 4
	allocation.contact_resistance = 5
	allocation.handling = 5
	assert_true(Stats.validate_allocation(allocation).is_empty())
	var stats := Stats.pre_race_stats("wind", allocation)
	assert_eq(stats.top_speed, 12)
	assert_eq(stats.aero, 12)
	assert_eq(stats.stamina, 1)
	assert_eq(stats.cardio, 1)


func test_rank_and_phase_bonuses_produce_the_effective_range_one_to_fifteen() -> void:
	var allocation := Stats.default_allocation()
	allocation.acceleration = 10
	allocation.cardio = 10
	allocation.stamina = 1
	allocation.top_speed = 1
	allocation.aero = 4
	allocation.pack = 4
	allocation.contact_resistance = 5
	allocation.handling = 5
	var first_phase := Stats.effective_stats("fire", allocation, "escape", 1, 0.1)
	assert_eq(first_phase.acceleration, 15)
	assert_eq(first_phase.cardio, 13)
	var out_of_position := Stats.effective_stats("fire", allocation, "escape", 8, 0.5)
	assert_eq(out_of_position.stamina, 1)


func test_invalid_allocation_rejects_zero_unknown_stat_and_wrong_total() -> void:
	var allocation := Stats.default_allocation()
	allocation.stamina = 0
	allocation.unexpected = 1
	var errors := ";".join(Stats.validate_allocation(allocation))
	assert_true(errors.contains("stamina"))
	assert_true(errors.contains("unexpected"))
	assert_true(errors.contains("配分合計"))


func test_definition_rejects_unknown_setting_and_missing_attribute() -> void:
	var data: Dictionary = Config.load_file().data.duplicate(true)
	data.unexpected_setting = true
	var attributes: Dictionary = data["attributes"]
	attributes.erase("wind")
	data["attributes"] = attributes
	var errors := ";".join(Config.validate(data))
	assert_true(errors.contains("unexpected_setting"))
	assert_true(errors.contains("attributes.wind"))


func test_definition_accepts_edited_values_when_consistent() -> void:
	# JSONの値を変えても、整合していれば受け付ける（値をコードへ二重定義しない）。
	var data: Dictionary = Config.load_file().data.duplicate(true)
	data.allocation_total = 48
	data.allocation_max = 12
	data.attribute_stat_max = 14
	data.rank_bonus = {"matching": 2, "adjacent": 0, "distant": -2}
	data.running_styles.escape.phase_bonus.amount = 3
	assert_eq(Config.validate(data), PackedStringArray())


func test_definition_rejects_inconsistent_ranges_and_rank_groups() -> void:
	var data: Dictionary = Config.load_file().data.duplicate(true)
	data.allocation_total = 41
	data.allocation_min = 11
	data.rank_groups = [[1, 2], [4, 5]]
	data.stat_ids = data.stat_ids.filter(func(stat_id): return stat_id != "handling")
	var errors := ";".join(Config.validate(data))
	assert_true(errors.contains("allocation_total"))
	assert_true(errors.contains("allocation_min"))
	assert_true(errors.contains("rank_groups[1]"))
	assert_true(errors.contains("handling"))


func test_style_rank_group_matches_the_group_that_gives_the_matching_bonus() -> void:
	var config: Dictionary = Config.values()
	var groups: Array = config["rank_groups"]
	assert_eq(Stats.rank_group_count(), groups.size())
	for style_id: String in config["running_styles"]:
		var group_index: int = Stats.style_rank_group_index(style_id)
		var rank_in_group := int(groups[group_index][0])
		assert_eq(Stats.rank_bonus(style_id, rank_in_group), int(config["rank_bonus"]["matching"]), style_id)
