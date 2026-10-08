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


func test_a_full_field_gives_each_style_exactly_its_configured_rank_group() -> void:
	var config := Config.values()
	var reference := Stats.rank_reference_size()
	for style_id: String in config["running_styles"]:
		var group: Array = config["rank_groups"][Stats.style_rank_group_index(style_id)]
		assert_eq(Stats.style_rank_window(style_id, reference), Vector2i(int(group[0]), int(group[1])), style_id)


func test_every_style_has_a_full_width_matching_window_inside_the_field_at_any_size() -> void:
	var config := Config.values()
	var last_group := Stats.rank_group_count() - 1
	for field_size in range(2, 17):
		var width := Stats.rank_window_width(field_size)
		var previous_first := 0
		for group_index in Stats.rank_group_count():
			var style_id := ""
			for candidate: String in config["running_styles"]:
				if Stats.style_rank_group_index(candidate) == group_index:
					style_id = candidate
			var window := Stats.style_rank_window(style_id, field_size)
			assert_eq(window.y - window.x + 1, width, "%s（%d人）の幅" % [style_id, field_size])
			assert_gte(window.x, 1)
			assert_lte(window.y, maxi(field_size, width))
			assert_gte(window.x, previous_first, "先頭の脚質ほど、得意な順位が前")
			previous_first = window.x
			# 得意な順位の数だけ、matching の補正が付く。
			var matching := 0
			for rank in range(1, field_size + 1):
				if Stats.rank_bonus(style_id, rank, field_size) == int(config["rank_bonus"]["matching"]):
					matching += 1
			assert_eq(matching, mini(width, field_size), "%s（%d人）" % [style_id, field_size])
			if group_index == 0:
				assert_eq(window.x, 1, "先頭の脚質は、いつも1位から")
			if group_index == last_group and field_size >= width:
				assert_eq(window.y, field_size, "最後の脚質は、いつも最後尾まで")


func test_matching_window_is_two_ranks_up_to_a_full_field_and_grows_beyond_it() -> void:
	var reference := Stats.rank_reference_size()
	var base_width := Stats.rank_window_width(reference)
	for field_size in range(2, reference + 1):
		assert_eq(Stats.rank_window_width(field_size), base_width)
	assert_eq(Stats.rank_window_width(reference + 1), base_width + 1)
	assert_eq(Stats.rank_window_width(reference + Stats.rank_group_count()), base_width + 1)
	assert_eq(Stats.rank_window_width(reference + Stats.rank_group_count() + 1), base_width + 2)


func test_rank_bonus_falls_from_matching_to_adjacent_to_distant_with_distance() -> void:
	var config := Config.values()
	var bonus: Dictionary = config["rank_bonus"]
	for field_size in [5, 8, 12]:
		for style_id: String in config["running_styles"]:
			var window := Stats.style_rank_window(style_id, field_size)
			var width := Stats.rank_window_width(field_size)
			for rank in range(1, field_size + 1):
				var distance := maxi(maxi(window.x - rank, rank - window.y), 0)
				var expected := int(bonus["matching"]) if distance == 0 else (int(bonus["adjacent"]) if distance <= width else int(bonus["distant"]))
				assert_eq(Stats.rank_bonus(style_id, rank, field_size), expected, "%s %d位（%d人）" % [style_id, rank, field_size])
