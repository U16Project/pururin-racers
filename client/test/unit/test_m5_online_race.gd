extends GutTest

const M5Scene := preload("res://scenes/m5_online_race.tscn")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

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

func test_chase_camera_defaults_keep_target_centered_and_have_no_free_mode() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_create_visual", "player-1", 0)
	var camera: Camera3D = race.get_node("Camera3D")
	assert_eq(camera.get("mode"), 0)
	assert_eq(camera.get("follow_distance"), 12.0)
	race.free()

func test_chase_qe_rotates_view_without_moving_camera_position() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_create_visual", "player-1", 0)
	var camera: Camera3D = race.get_node("Camera3D")
	camera.call("_process", 0.0)
	var initial_position := camera.global_position
	var initial_forward := -camera.global_transform.basis.z
	camera.set("_follow_yaw", PI * 0.5)
	camera.call("_process", 0.0)
	assert_almost_eq(camera.global_position.x, initial_position.x, 0.001)
	assert_almost_eq(camera.global_position.y, initial_position.y, 0.001)
	assert_almost_eq(camera.global_position.z, initial_position.z, 0.001)
	assert_ne(camera.global_transform.basis.z, -initial_forward)
	race.free()

func test_visual_is_placed_on_track_curve_with_ground_clearance() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_create_visual", "cpu-1", 0)
	var track: Path3D = race.get_node("TrackPath")
	var distance := 700.0
	var offset := -3.0
	var route: Dictionary = race.get("_route")
	var pose: Dictionary = M5CourseBuilder.route_pose(track.curve, route, distance, 2083.1)
	var outward: Vector3 = race.call("_stadium_outward", pose.position)
	var expected := track.global_transform * Transform3D(
		Basis.IDENTITY, pose.position + outward * offset + Vector3.UP * 0.75
	)
	race.call("_apply_visual_pose", race.get_node("Runners/cpu-1"), distance, offset)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.y, expected.origin.y, 0.001)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.x, expected.origin.x, 0.001)
	assert_almost_eq(race.get_node("Runners/cpu-1").global_position.z, expected.origin.z, 0.001)
	race.free()

func test_1600_launch_route_pose_stays_straight_then_joins_mainline() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_set_route", 1600.0)
	var track: Path3D = race.get_node("TrackPath")
	var route: Dictionary = race.get("_route")
	var before: Dictionary = M5CourseBuilder.route_pose(track.curve, route, 0.0, 2083.1)
	var middle: Dictionary = M5CourseBuilder.route_pose(track.curve, route, 80.0, 2083.1)
	var join: Dictionary = M5CourseBuilder.route_pose(track.curve, route, 160.0, 2083.1)
	assert_true(before.is_straight)
	assert_true(middle.is_straight)
	assert_false(join.is_straight)
	assert_almost_eq(float(before.curvature), 0.0, 0.001)
	assert_almost_eq(float(middle.curvature), 0.0, 0.001)
	assert_almost_eq(before.travel.angle_to(middle.travel), 0.0, 0.001)
	assert_almost_eq(middle.travel.angle_to(join.travel), 0.0, 0.001)
	assert_almost_eq((join.position - middle.position).dot(middle.travel), 80.0, 0.5)
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
	# ゴールの門は、ゴールの線の真上に立ち、地面の市松の線は、コースの幅いっぱい。
	var goal_visual := preload("res://scripts/presentation/goal_visual.gd")
	var goal_gate: Node3D = race.get_node("TrackPath/%s" % goal_visual.ROOT_NAME)
	var gate_from_line := goal_gate.global_position - goal_marker.global_position
	assert_almost_eq(Vector2(gate_from_line.x, gate_from_line.z).length(), 0.0, 0.01)
	var goal_line: MeshInstance3D = goal_gate.get_node("GroundLine")
	assert_almost_eq((goal_line.mesh as PlaneMesh).size.x, 15.0, 0.001)
	assert_almost_eq((goal_line.mesh as PlaneMesh).size.y, goal_visual.LINE_DEPTH_M, 0.001)
	assert_gt(goal_line.global_position.y, goal_marker.global_position.y)
	for label_name: String in ["PlateTextFront", "PlateTextBack"]:
		var plate_text: Label3D = goal_gate.get_node(label_name)
		assert_eq(plate_text.text, goal_visual.PLATE_TEXT)
		assert_eq(plate_text.billboard, BaseMaterial3D.BILLBOARD_DISABLED)
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
	# サーバーは、個体一覧と同じ名前（player-1、cpu-1〜）で走者を送ってくる。
	var racers: Array = []
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		racers.append({
			"id": str(pururin["id"]),
			"distance": 526.0,
			"offset": 0.0,
			"finished": true,
		})
	race.call("_on_race_tick", {"racers": racers})
	var visuals: Node3D = race.get_node("Runners")
	assert_eq(visuals.get_child_count(), racers.size())
	var finished: Dictionary = race.get("_visual_finished")
	assert_eq(finished.size(), racers.size())
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
	var solo_lines: PackedStringArray = race.get_node("%HudLabel").text.split("\n")
	assert_true(solo_lines.has("タイム 0:01.20"))
	assert_true(solo_lines.has("直接 0%"))
	assert_true(solo_lines.has("連鎖 0%"))
	assert_true(solo_lines.has("総合 0%"))
	assert_true(solo_lines.has("対象 なし"))
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
			"direct_source_details": [
				{"id": "cpu-1", "gap": 4.0, "line": 1.0},
			],
			"primary_source_id": "cpu-1", "primary_gap_m": 4.0,
			"primary_line_gap_m": 1.0,
		}],
	})
	var hud_lines: PackedStringArray = race.get_node("%HudLabel").text.split("\n")
	assert_true(hud_lines.has("目標 62.0km/h"))
	assert_true(hud_lines.has("実測 44.4km/h"))
	assert_false(hud_lines.has("現在 58.0km/h"))
	assert_true(hud_lines.has("直接 67%"))
	assert_true(hud_lines.has("連鎖 33%"))
	assert_true(hud_lines.has("総合 100%"))
	assert_true(hud_lines.has("対象 cpu-1（前方 4.0m／横 1.0m）"))
	race.call("_on_race_result", {
		"results": [{"id": "player-1", "rank": 1, "finish_time": 34.5}],
	})
	assert_true(race.get_node("%ResultLabel").text.contains("0:34.50"))
	race.free()

func test_hud_and_result_time_use_hundredths() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	assert_eq(race.call("_format_race_time", 125.04), "2:05.04")
	assert_eq(race.call("_format_result_time", 125.04), "2:05.04")
	race.free()

func test_hud_shows_all_direct_draft_targets() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"elapsed_seconds": 1.3,
		"racers": [{
			"id": "player-1", "race_progress": 10.0,
			"direct_draft_p": 0.20, "chain_draft_p": 0.0,
			"direct_source_ids": ["cpu-1", "cpu-2"],
			"direct_source_details": [
				{"id": "cpu-1", "gap": 4.0, "line": 1.0},
				{"id": "cpu-2", "gap": 7.0, "line": 1.5},
			],
		}],
	})
	var hud_lines: PackedStringArray = race.get_node("%HudLabel").text.split("\n")
	assert_true(hud_lines.has("対象 cpu-1（前方 4.0m／横 1.0m）、cpu-2（前方 7.0m／横 1.5m）"))
	race.free()

func test_escape_toggles_pause_panel_and_resume() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	var pause_panel: Control = race.get_node("UI/PausePanel")
	assert_false(pause_panel.visible)
	race.call("_set_paused", true)
	assert_true(pause_panel.visible)
	assert_true(race.get("_paused"))
	race.call("_set_paused", false)
	assert_false(pause_panel.visible)
	assert_false(race.get("_paused"))
	race.free()

func test_held_controls_adjust_speed_and_line_smoothly() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	assert_true(race.call("_apply_held_input", 0.5, true, false, true, false))
	assert_almost_eq(float(race.get("_target_offset")), -5.0, 0.001)
	assert_almost_eq(float(race.get("_target_speed")), 64.0, 0.001)
	race.free()

func test_pause_keeps_visuals_rendering_latest_server_state() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"racers": [{"id": "player-1", "race_progress": 0.0, "offset": 0.0}],
	})
	var visual: Node3D = race.get_node("Runners/player-1")
	var before := visual.global_position
	race.call("_set_paused", true)
	race.call("_on_race_tick", {
		"racers": [{"id": "player-1", "race_progress": 100.0, "offset": 0.0}],
	})
	race.call("_process", 1.0 / 60.0)
	assert_ne(visual.global_position, before)
	race.free()

func test_finished_visual_runs_until_result_arrives() -> void:
	var race := M5Scene.instantiate()
	add_child(race)
	race.call("_on_race_tick", {
		"racers": [{"id": "player-1", "race_progress": 2000.0, "offset": 0.0, "finished": true}],
	})
	var visual: Node3D = race.get_node("Runners/player-1")
	var before := visual.global_position
	race.call("_process", 1.0)
	assert_ne(visual.global_position, before)
	race.call("_on_race_result", {"results": []})
	assert_true(race.get_node("%ResultPanel").visible)
	assert_false(race.get("_paused"))
	var after_result := visual.global_position
	race.call("_process", 1.0)
	assert_ne(visual.global_position, after_result)
	var during_hold := visual.global_position
	race.call("_process", 9.0)
	assert_eq(visual.global_position, during_hold)
	race.free()
