extends GutTest

const M5Scene := preload("res://scenes/m5_online_race.tscn")
const IntroScene := preload("res://scenes/m3_intro.tscn")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")

func test_m5_scene_exists_and_has_online_controller() -> void:
	assert_true(ResourceLoader.exists("res://scenes/m5_online_race.tscn"))
	var race := M5Scene.instantiate()
	add_child(race)
	assert_true(race.get_script() != null)
	assert_eq(race.get_node("Runners").get_child_count(), 0)
	race.free()

func test_player_visual_becomes_camera_follow_target() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_create_visual", "player-1", 0)
	var camera: Camera3D = race.get_node("Camera3D")
	camera.call("_process", 0.0)
	assert_almost_eq(camera.global_position.x, 0.0, 0.001)
	assert_almost_eq(camera.global_position.y, 4.0, 0.001)
	assert_almost_eq(camera.global_position.z, 12.0, 0.001)
	race.free()

func test_visual_is_placed_on_track_curve_with_ground_clearance() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_create_visual", "cpu-1", 0)
	var track: Path3D = race.get_node("TrackPath")
	var distance := 700.0
	var offset := -3.0
	var curve_xf := track.curve.sample_baked_with_rotation(distance)
	var outward: Vector3 = race.call("_stadium_outward", curve_xf.origin)
	var expected := track.global_transform * Transform3D(
		Basis.IDENTITY, curve_xf.origin + outward * offset + Vector3.UP * 0.75
	)
	race.call("_apply_visual_pose", race.get_node("Runners/cpu-1"), distance, offset)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.y, expected.origin.y, 0.001)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.x, expected.origin.x, 0.001)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.z, expected.origin.z, 0.001)
	race.free()

func test_visual_interpolates_between_server_ticks() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"racers": [{"id": "player-1", "distance": 609.0, "race_progress": 0.0, "offset": -3.0}],
	})
	var visual: Node3D = race.get_node("Runners/player-1")
	var first_position := visual.global_position
	race.call("_on_race_tick", {
		"racers": [{"id": "player-1", "distance": 700.0, "race_progress": 91.0, "offset": -3.0}],
	})
	assert_almost_eq(visual.global_position.x, first_position.x, 0.001)
	assert_almost_eq(visual.global_position.z, first_position.z, 0.001)
	race.call("_process", 1.0 / 60.0)
	assert_ne(visual.global_position, first_position)
	race.free()

func test_m5_places_start_and_goal_markers() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	var start_marker: MeshInstance3D = race.get_node("StartMarker")
	var goal_marker: MeshInstance3D = race.get_node("GoalMarker")
	assert_true(start_marker.mesh is BoxMesh)
	assert_true(goal_marker.mesh is BoxMesh)
	assert_almost_eq(start_marker.position.y, 0.14, 0.001)
	assert_almost_eq(goal_marker.position.y, 0.14, 0.001)
	race.free()

func test_m5_uses_shared_course_layout_and_680m_straights() -> void:
	var layout: Dictionary = M5CourseBuilder.load_layout()
	assert_eq(layout.get("course_id"), "m5_standard_oval")
	assert_almost_eq(float(layout.get("track_length_m")), 2083.1, 0.001)
	assert_almost_eq(float(layout.get("straight_length_m")), 680.0, 0.001)
	assert_almost_eq(float(layout.get("turn_radius_m")), 115.085, 0.001)
	assert_eq(layout.get("routes").size(), 5)

func test_m5_route_progress_maps_1600_launch_and_goal_deterministically() -> void:
	var layout: Dictionary = M5CourseBuilder.load_layout()
	var route: Dictionary = M5CourseBuilder.route_for_distance(layout, 1600.0)
	assert_eq(route.get("segments")[0].get("distance_m"), 160.0)
	assert_eq(route.get("segments")[1].get("distance_m"), 1440.0)
	assert_almost_eq(
		M5CourseBuilder.route_mainline_distance(route, 160.0, 2083.1),
		1043.1,
		0.001
	)
	assert_almost_eq(
		M5CourseBuilder.route_mainline_distance(route, 1600.0, 2083.1),
		400.0,
		0.001
	)

func test_all_finished_visuals_keep_their_server_pose() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	var racers: Array = []
	for index in 8:
		racers.append({
			"id": "racer-%d" % index,
			"distance": 526.0,
			"offset": 0.0,
			"finished": true,
		})
	race.call("_on_race_tick", {"racers": racers})
	var visuals: Node3D = race.get_node("Runners")
	assert_eq(visuals.get_child_count(), 8)
	var finished: Dictionary = race.get("_visual_finished")
	assert_eq(finished.size(), 8)
	for racer_id in finished:
		assert_true(finished[racer_id])
	race.free()

func test_hud_shows_single_running_when_direct_source_is_missing() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"elapsed_seconds": 1.2,
		"racers": [{
			"id": "player-1", "distance": 609.0, "race_progress": 10.0,
			"speed": 58.0, "offset": -3.0, "direct_draft_p": 0.12,
			"chain_draft_p": 0.06, "direct_source_ids": [],
		}],
	})
	assert_true(race.get_node("%HudLabel").text.contains("タイム 0:01.2"))
	assert_true(race.get_node("%HudLabel").text.contains("単独走（直接 0% ＋ 連鎖 0%　総合 0%）"))
	race.free()

func test_hud_shows_direct_chain_and_primary_source_distances() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"elapsed_seconds": 1.3,
		"racers": [{
			"id": "player-1", "distance": 609.0, "race_progress": 10.0,
			"speed": 58.0, "target_speed": 62.0, "actual_speed_kmh": 44.4,
			"offset": -3.0, "direct_draft_p": 0.12,
			"chain_draft_p": 0.06, "direct_source_ids": ["cpu-1"],
			"primary_source_id": "cpu-1", "primary_gap_m": 4.0,
			"primary_line_gap_m": 1.0,
		}],
	})
	var hud_text: String = race.get_node("%HudLabel").text
	assert_true(hud_text.contains("目標 62.0km/h　実測 44.4km/h"))
	assert_true(not hud_text.contains("現在 58.0km/h"))
	assert_true(hud_text.contains("ドラフト 直接 50% ＋ 連鎖 25%"))
	assert_true(hud_text.contains("総合 75%"))
	assert_true(hud_text.contains("対象 cpu-1　前方 4.0m　横 1.0m"))
	race.call("_on_race_result", {
		"results": [{"id": "player-1", "rank": 1, "finish_time": 34.5}],
	})
	assert_true(race.get_node("%ResultLabel").text.contains("0:34.50"))
	race.free()

func test_result_time_uses_hundredths_while_hud_time_uses_tenths() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	assert_eq(race.call("_format_race_time", 125.04), "2:05.0")
	assert_eq(race.call("_format_result_time", 125.04), "2:05.04")
	race.free()

func test_intro_exposes_m5_entry() -> void:
	var intro := IntroScene.instantiate()
	add_child(intro)
	assert_true(intro.get_node("%M5Button") != null)
	intro.free()
