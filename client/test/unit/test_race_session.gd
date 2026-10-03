extends GutTest

const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)
	RaceSession.select_player_pururin(RaceSession.default_player_pururin_id())
	RaceSession.reset_stamina_load_preset()


func test_supported_distances_are_the_five_course_routes() -> void:
	assert_eq(RaceSession.supported_distances_m(), [1200.0, 1600.0, 2000.0, 2400.0, 3000.0])


func test_selection_keeps_only_defined_routes_and_falls_back_to_2000m() -> void:
	assert_eq(RaceSession.select_distance(1600.0), 1600.0)
	assert_eq(RaceSession.selected_distance_m(), 1600.0)
	assert_eq(RaceSession.select_distance(1700.0), 2000.0)


func test_player_selection_accepts_roster_ids_and_falls_back_to_hikari() -> void:
	var default_id := PururinRosterConfig.default_player_pururin_id()
	assert_eq(RaceSession.default_player_pururin_id(), default_id)
	assert_eq(RaceSession.selected_player_pururin_id(), default_id)
	assert_eq(RaceSession.select_player_pururin("cpu-4"), "cpu-4")
	assert_eq(RaceSession.selected_player_pururin_id(), "cpu-4")
	assert_eq(RaceSession.select_player_pururin("unknown"), default_id)
	assert_eq(RaceSession.selected_player_pururin_id(), default_id)


func test_stamina_load_presets_are_explicit_and_default_to_config_high_load() -> void:
	assert_eq(RaceSession.stamina_load_presets().size(), 3)
	assert_almost_eq(RaceSession.selected_stamina_load_multiplier(), 1.30, 0.0001)
	assert_eq(RaceSession.select_stamina_load_preset("standard"), "standard")
	assert_almost_eq(RaceSession.selected_stamina_load_multiplier(), 1.15, 0.0001)
	assert_eq(RaceSession.select_stamina_load_preset("strong"), "strong")
	assert_almost_eq(RaceSession.selected_stamina_load_multiplier(), 1.45, 0.0001)
	RaceSession.reset_stamina_load_preset()
	assert_almost_eq(RaceSession.selected_stamina_load_multiplier(), 1.30, 0.0001)


func test_local_runner_uses_selected_distance_and_route_goal() -> void:
	RaceSession.select_distance(1600.0)
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	assert_eq(player.call("get_race_distance"), 1600.0)
	assert_almost_eq(player.call("get_race_progress"), 0.0, 0.001)
	assert_almost_eq(player.call("get_distance"), 1043.1, 0.2)
	assert_true(LocalRaceMath.has_finished(1600.0, player.call("get_race_distance")))
	race.free()


func test_local_race_uses_the_selected_roster_entry_as_the_only_player() -> void:
	RaceSession.select_player_pururin("cpu-1")
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var runners: Array = race.call("get_runners_for_simulation")
	var expected_cpu_ids: Array[String] = []
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		if str(pururin["id"]) != "cpu-1":
			expected_cpu_ids.append(str(pururin["id"]))
	for gate in runners.size():
		var runner: Node = runners[gate]
		var snapshot: Dictionary = runner.call("get_snapshot")
		assert_eq(snapshot["gate"], gate)
		if gate == 0:
			assert_true(snapshot["player"])
			assert_eq(snapshot["id"], "cpu-1")
		else:
			var expected_id := expected_cpu_ids[gate - 1]
			assert_false(snapshot["player"])
			assert_eq(snapshot["id"], expected_id)
			var expected_pururin := PururinRosterConfig.pururin_by_id(expected_id)
			assert_eq(
				runner.get("_cpu_trainer_profile")["id"],
				expected_pururin["trainer_profile_id"]
			)
	race.free()


func test_runner_setup_does_not_change_the_selected_distance() -> void:
	RaceSession.select_distance(1600.0)
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "テスト", {}, 2400.0)
	assert_eq(float(runner.call("get_race_distance")), 2400.0)
	assert_eq(RaceSession.selected_distance_m(), 1600.0)
	runner.free()
