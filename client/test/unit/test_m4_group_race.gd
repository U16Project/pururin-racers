extends GutTest

const M4GroupRaceMath := preload("res://scripts/m4_group_race_math.gd")
const M4GroupRaceScene := preload("res://scenes/m4_group_race.tscn")

func test_fixed_profiles_match_m4_plan() -> void:
	var player := M4GroupRaceMath.profile_for("player")
	var inner := M4GroupRaceMath.profile_for("inner")
	var outer := M4GroupRaceMath.profile_for("outer")
	assert_eq([player["max_speed"], player["acceleration"], player["handling"], player["contact_resistance"], player["group_affinity"]], [7, 6, 6, 5, 5])
	assert_eq([inner["max_speed"], inner["acceleration"], inner["handling"], inner["contact_resistance"], inner["group_affinity"]], [6, 5, 9, 7, 7])
	assert_eq([outer["max_speed"], outer["acceleration"], outer["handling"], outer["contact_resistance"], outer["group_affinity"]], [10, 8, 4, 3, 2])
	assert_eq(player["max_speed_kmh"], 80.0)
	assert_eq(inner["max_speed_kmh"], 65.0)
	assert_eq(outer["max_speed_kmh"], 75.0)
	assert_eq(M4GroupRaceMath.PLAYER_INITIAL_SPEED_KMH, 70.0)

func test_draft_requires_front_and_nearby_line() -> void:
	var leader := M4GroupRaceMath.draft_leader(100.0, 0.0, [{"distance": 104.0, "offset": 0.5, "speed": 62.0}], 2083.0)
	assert_eq(leader.get("speed"), 62.0)
	var absent := M4GroupRaceMath.draft_leader(100.0, 0.0, [{"distance": 96.0, "offset": 0.5, "speed": 62.0}], 2083.0)
	assert_true(absent.is_empty())

func test_group_affinity_changes_draft_assist() -> void:
	var inner_assist := M4GroupRaceMath.draft_assist_target_kmh(58.0, 64.0, 7, 65.0)
	var outer_assist := M4GroupRaceMath.draft_assist_target_kmh(58.0, 64.0, 2, 75.0)
	assert_gt(inner_assist, outer_assist)
	assert_lte(inner_assist, 65.0)

func test_slow_leader_does_not_make_drafting_slower() -> void:
	var target := M4GroupRaceMath.draft_assist_target_kmh(80.0, 60.0, 5, 80.0)
	assert_eq(target, 80.0)

func test_m4_time_uses_competition_style_minutes() -> void:
	assert_eq(M4GroupRaceMath.format_race_time(58.44), "58.4")
	assert_eq(M4GroupRaceMath.format_race_time(83.44), "1:23.4")

func test_m4_scene_exists() -> void:
	assert_true(ResourceLoader.exists("res://scenes/m4_group_race.tscn"))

func test_m4_scene_configures_three_runners() -> void:
	var race := M4GroupRaceScene.instantiate()
	add_child(race)
	var runners: Node3D = race.get_node("Runners")
	assert_eq(runners.get_child_count(), 3)
	assert_eq(
		[
			runners.get_child(0).call("get_snapshot")["role"],
			runners.get_child(1).call("get_snapshot")["role"],
			runners.get_child(2).call("get_snapshot")["role"],
		],
		["player", "inner", "outer"]
	)
	race.free()

func test_m4_finishes_at_2000m_and_shows_results() -> void:
	var race := M4GroupRaceScene.instantiate()
	add_child(race)
	var runners: Node3D = race.get_node("Runners")
	for runner in runners.get_children():
		runner.set("_race_progress", M4GroupRaceMath.RACE_DISTANCE_M)

	race.call("_check_finishes")

	assert_eq(race.get("_finish_count"), 3)
	assert_true(race.get("_results_pending"))
	for runner in runners.get_children():
		assert_true(runner.call("is_finished"))
		assert_gte(runner.call("get_finish_order"), 1)

	race.call("_show_results")

	assert_true(race.get("_race_over"))
	assert_true(race.get_node("UI/ResultPanel").visible)
	assert_eq(race.get_node("UI/ResultPanel/ResultBox/ResultLabel").text.count("\n"), 2)
	race.free()
