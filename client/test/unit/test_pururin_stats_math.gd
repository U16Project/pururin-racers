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
