extends GutTest

const RaceVenue := preload("res://scripts/presentation/race_venue.gd")
const StartGate := preload("res://scripts/presentation/start_gate.gd")
const Parts := preload("res://scripts/presentation/venue_parts.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LocalRaceCamera := preload("res://scripts/local_race_camera.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")


func _track() -> Path3D:
	var track := Path3D.new()
	LocalRaceMath.apply_course_to_path(track)
	add_child_autofree(track)
	return track


## 助走の直線（スタート専用の直線）から始まるルートと、本線から始まるルート。
func _routes_by_launch(layout: Dictionary) -> Dictionary:
	var result := {"launch": [], "mainline": []}
	for route: Dictionary in layout["routes"]:
		var first: Dictionary = route["segments"][0]
		result["launch" if str(first["type"]) == "straight" else "mainline"].append(route)
	return result


func test_launch_strips_cover_only_routes_that_start_on_a_launch_straight() -> void:
	var track := _track()
	var layout := M5CourseBuilder.load_layout()
	var routes := _routes_by_launch(layout)
	assert_gt(routes["launch"].size(), 0)
	var strips := RaceVenue.launch_strips(track.curve, layout["routes"], LocalRaceMath.lap_length_m())
	assert_eq(strips.size(), routes["launch"].size())
	for i in strips.size():
		var strip: Dictionary = strips[i]
		var length := float(routes["launch"][i]["segments"][0]["distance_m"])
		assert_eq(float(strip["length"]), length)
		var travel: Vector3 = strip["travel"]
		var join: Vector3 = strip["join"]
		var side := Vector3(-travel.z, 0.0, travel.x)
		assert_true(RaceVenue.in_strip(join - travel * length * 0.5, strip, 1.0))
		assert_false(RaceVenue.in_strip(join + travel * 1.0, strip, 1.0))
		assert_false(RaceVenue.in_strip(join - travel * (length + 1.0), strip, 1.0))
		assert_false(RaceVenue.in_strip(join - travel * length * 0.5 + side * 2.0, strip, 1.0))


func test_distance_outside_track_is_zero_on_the_center_line() -> void:
	var straight := LocalRaceMath.straight_length_m()
	var radius := LocalRaceMath.turn_radius_m()
	assert_almost_eq(RaceVenue.distance_outside_track(0.0, radius, straight, radius), 0.0, 0.0001)
	assert_almost_eq(RaceVenue.distance_outside_track(straight * 0.5 + radius, 0.0, straight, radius), 0.0, 0.0001)
	assert_almost_eq(RaceVenue.distance_outside_track(0.0, 0.0, straight, radius), -radius, 0.0001)
	assert_almost_eq(RaceVenue.distance_outside_track(0.0, radius + 30.0, straight, radius), 30.0, 0.0001)


func test_stand_blocks_stay_in_range_and_leave_room_for_the_royal_box() -> void:
	var before := RaceVenue.STAND_BEFORE_GOAL_M
	var past := RaceVenue.STAND_PAST_GOAL_M
	var half := RaceVenue.STAND_BLOCK_LENGTH_M * 0.5
	var centers := RaceVenue.stand_block_centers(before, past)
	assert_gt(centers.size(), 1)
	centers.sort()
	for i in centers.size():
		assert_true(centers[i] + half <= before and centers[i] - half >= -past)
		assert_true(absf(centers[i]) - half >= RaceVenue.ROYAL_BOX_SIZE_M.y * 0.5)
		if i > 0:
			assert_true(centers[i] - centers[i - 1] >= RaceVenue.STAND_BLOCK_LENGTH_M)


func test_fence_opens_for_the_launch_straight_only_when_the_route_uses_it() -> void:
	var track := _track()
	var layout := M5CourseBuilder.load_layout()
	var routes := _routes_by_launch(layout)
	var launch_route: Dictionary = routes["launch"][0]
	var strip: Dictionary = RaceVenue.launch_strips(track.curve, [launch_route], LocalRaceMath.lap_length_m())[0]
	var venue := RaceVenue.new()
	var ground := StandardMaterial3D.new()
	# 本線から始まるルートでは、助走の直線の所も、柵が閉じている。
	venue.place(track, ground, layout, routes["mainline"][0])
	var closed := 0
	for point: Vector3 in venue.fence_post_positions():
		if RaceVenue.in_strip(point, strip, M2TrackMath.HALF_WIDTH_M):
			closed += 1
	assert_gt(closed, 0)
	# 助走の直線から始まるルートでは、その上に柵の柱が無い。
	venue.place(track, ground, layout, launch_route)
	assert_gt(venue.fence_post_positions().size(), 0)
	for point: Vector3 in venue.fence_post_positions():
		assert_false(RaceVenue.in_strip(point, strip, M2TrackMath.HALF_WIDTH_M))
	# 置き直しても、景色は1つだけ。
	assert_eq(track.get_child_count(), 1)


func test_start_gate_moves_to_the_start_of_each_route() -> void:
	var track := _track()
	var layout := M5CourseBuilder.load_layout()
	var lap := LocalRaceMath.lap_length_m()
	var gate := StartGate.new()
	var seen := []
	for route: Dictionary in layout["routes"]:
		gate.place(track, route, lap)
		var root := track.get_node(StartGate.ROOT_NAME) as Node3D
		var pose := M5CourseBuilder.route_pose(track.curve, route, 0.0, lap)
		var expected: Vector3 = (pose["position"] as Vector3) + (pose["travel"] as Vector3) * StartGate.AHEAD_OF_LINE_M
		assert_almost_eq(root.position.distance_to(expected), 0.0, 0.001)
		for other: Vector3 in seen:
			assert_gt(root.position.distance_to(other), 1.0)
		seen.append(root.position)
		assert_eq(track.get_child_count(), 1)


func test_start_gate_boards_hang_over_each_gate_below_the_chase_camera() -> void:
	var track := _track()
	var layout := M5CourseBuilder.load_layout()
	var gate := StartGate.new()
	gate.place(track, layout["routes"][0], LocalRaceMath.lap_length_m())
	var root := track.get_node(StartGate.ROOT_NAME) as Node3D
	for index in StartGate.GATE_COUNT:
		var board := root.get_node("Board%d" % (index + 1)) as Node3D
		assert_almost_eq(board.position.x, LocalRaceMath.starting_offset_for_gate(index), 0.0001)
	# 追う視点のカメラが、横木の上を通れる。
	var camera_height := float(LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]["height"])
	assert_lt(StartGate.beam_top_m(), camera_height)
	# 台は、コースの端と柵のあいだに収まる。
	assert_gt(StartGate.cart_offset_m() - StartGate.CART_SIZE_M.x * 0.5, M2TrackMath.HALF_WIDTH_M)
	assert_lt(StartGate.cart_offset_m() + StartGate.CART_SIZE_M.x * 0.5 + StartGate.WHEEL_WIDTH_M, Parts.FENCE_SIDE_OFFSET_M)


func test_start_gate_is_cleared_after_the_start() -> void:
	var track := _track()
	var gate := StartGate.new()
	gate.place(track, M5CourseBuilder.load_layout()["routes"][0], LocalRaceMath.lap_length_m())
	assert_true(gate.is_out())
	gate.clear_after_start(0.05)
	await wait_seconds(0.3)
	assert_false(gate.is_out())
