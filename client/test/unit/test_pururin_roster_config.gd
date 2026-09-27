extends GutTest

const RosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")


func test_shipped_roster_has_one_player_and_seven_cpu_with_valid_allocations() -> void:
	var result := RosterConfig.load_file()
	assert_true(result.has("data"))
	assert_true(RosterConfig.validate(result.data).is_empty())
	var roster: Array = result.data["roster"]
	assert_eq(roster.size(), 8)
	assert_eq(roster.filter(func(pururin): return pururin["control_kind"] == "player").size(), 1)
	assert_eq(roster.filter(func(pururin): return pururin["control_kind"] == "cpu").size(), 7)
	for pururin in roster:
		assert_true(StatsMath.validate_allocation(pururin["allocation"]).is_empty())


func test_cpu_roster_entry_references_existing_trainer_profile() -> void:
	var cpu := RosterConfig.pururin_by_id("cpu-1")
	assert_eq(cpu["display_name"], "アカネ")
	assert_eq(cpu["trainer_profile_id"], "front")
	assert_eq(cpu["running_style"], "escape")


func test_roster_rejects_invalid_cpu_profile_and_duplicate_id() -> void:
	var data: Dictionary = RosterConfig.load_file().data.duplicate(true)
	data["roster"][1]["trainer_profile_id"] = "missing"
	data["roster"][2]["id"] = "cpu-1"
	var errors := ";".join(RosterConfig.validate(data))
	assert_true(errors.contains("trainer_profile_id"))
	assert_true(errors.contains("空または重複"))
