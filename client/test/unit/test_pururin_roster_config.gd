extends GutTest

const RosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")


func test_shipped_roster_has_eight_cpu_capable_entries_with_valid_allocations() -> void:
	var result := RosterConfig.load_file()
	assert_true(result.has("data"))
	assert_true(RosterConfig.validate(result.data).is_empty())
	var roster: Array = result.data["roster"]
	assert_eq(roster.size(), 8)
	for pururin in roster:
		assert_true(StatsMath.validate_allocation(pururin["allocation"]).is_empty())
		assert_ne(str(pururin.get("trainer_profile_id", "")), "")
	var default_id := RosterConfig.default_player_pururin_id()
	assert_eq(default_id, "player-1")
	assert_eq(RosterConfig.pururin_by_id(default_id)["display_name"], "ヒカリ")
	assert_eq(RosterConfig.pururin_by_id(default_id)["trainer_profile_id"], "balanced")


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


func test_roster_requires_exactly_one_player_control_kind() -> void:
	var no_player: Dictionary = RosterConfig.load_file().data.duplicate(true)
	no_player["roster"][0]["control_kind"] = "cpu"
	assert_true(";".join(RosterConfig.validate(no_player)).contains("初期操作個体は1体必要です"))
	var two_players: Dictionary = RosterConfig.load_file().data.duplicate(true)
	two_players["roster"][1]["control_kind"] = "player"
	assert_true(";".join(RosterConfig.validate(two_players)).contains("初期操作個体は1体必要です"))
