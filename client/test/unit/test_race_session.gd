extends GutTest

const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)


func test_supported_distances_are_the_five_course_routes() -> void:
	assert_eq(RaceSession.supported_distances_m(), [1200.0, 1600.0, 2000.0, 2400.0, 3000.0])


func test_selection_keeps_only_defined_routes_and_falls_back_to_2000m() -> void:
	assert_eq(RaceSession.select_distance(1600.0), 1600.0)
	assert_eq(RaceSession.selected_distance_m(), 1600.0)
	assert_eq(RaceSession.select_distance(1700.0), 2000.0)


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
