extends GutTest

const CourseMarkers := preload("res://scripts/presentation/course_markers.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const Parts := preload("res://scripts/presentation/venue_parts.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")


func test_marker_distances_are_spaced_and_stay_before_the_goal() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var total := interval * 4.0 + interval * 0.5
	var distances := CourseMarkers.marker_distances(total, interval, total)
	assert_eq(distances.size(), 4)
	for index in distances.size():
		assert_almost_eq(distances[index], interval * float(index + 1), 0.0001)
	assert_lt(distances[distances.size() - 1], total)


func test_marker_distances_exclude_the_goal_position() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var distances := CourseMarkers.marker_distances(interval * 3.0, interval, interval * 3.0)
	assert_eq(distances.size(), 2)
	assert_eq(CourseMarkers.marker_distances(interval * 3.0, 0.0, interval * 3.0).size(), 0)


func test_sign_number_is_the_remaining_distance() -> void:
	assert_eq(CourseMarkers.sign_number(2000.0, 100.0), 1900)
	assert_eq(CourseMarkers.sign_number(2000.0, 1500.0), 500)


func test_only_the_last_few_signs_are_large() -> void:
	for remaining: int in CourseMarkers.LARGE_SIGN_REMAINING_M:
		assert_true(CourseMarkers.is_large_sign(remaining))
	assert_false(CourseMarkers.is_large_sign(400))
	assert_false(CourseMarkers.is_large_sign(1900))


func test_inner_side_points_toward_the_course_center() -> void:
	var travel := Vector3(0.0, 0.0, -1.0)
	var position := Vector3(0.0, 0.0, 0.0)
	var left_center := Vector3(-100.0, 0.0, -50.0)
	var right_center := Vector3(100.0, 0.0, -50.0)
	assert_true(CourseMarkers.inner_side(position, travel, left_center).x < 0.0)
	assert_true(CourseMarkers.inner_side(position, travel, right_center).x > 0.0)


func test_sign_number_splits_the_trailing_hundreds() -> void:
	assert_eq(CourseMarkers.sign_number_parts(1900), ["19", "00"])
	assert_eq(CourseMarkers.sign_number_parts(500), ["5", "00"])
	assert_eq(CourseMarkers.sign_number_parts(150), ["150", ""])
	assert_eq(CourseMarkers.sign_number_parts(50), ["50", ""])


func test_signs_stand_on_the_fence_line_with_the_board_above_the_fence() -> void:
	assert_eq(CourseMarkers.SIGN_SIDE_OFFSET_M, Parts.FENCE_SIDE_OFFSET_M)
	for size: Vector2 in [CourseMarkers.SIGN_SIZE_M, CourseMarkers.SIGN_LARGE_SIZE_M]:
		var bottom := CourseMarkers.sign_center_height_m(size) - size.y * 0.5 - CourseMarkers.SIGN_FRAME_M
		assert_gt(bottom, Parts.FENCE_HEIGHT_M)


func test_signs_do_not_hang_over_the_track() -> void:
	for size: Vector2 in [CourseMarkers.SIGN_SIZE_M, CourseMarkers.SIGN_LARGE_SIZE_M]:
		# 板の、コース側の端（コースの中心線から）。
		var track_side_edge := CourseMarkers.SIGN_SIDE_OFFSET_M + CourseMarkers.sign_side_shift_m(size) - CourseMarkers.sign_half_width_m(size)
		assert_gt(track_side_edge, M2TrackMath.HALF_WIDTH_M)


func test_marker_distances_skip_signs_farther_than_the_max_remaining() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var total := interval * 6.0
	var distances := CourseMarkers.marker_distances(total, interval, interval * 2.0)
	assert_eq(distances.size(), 2)
	assert_almost_eq(total - distances[0], interval * 2.0, 0.0001)
	assert_almost_eq(total - distances[1], interval, 0.0001)


func test_signs_never_stand_close_together_on_any_route() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var max_remaining := LocalRaceMath.Config.number("course_marker_sign_max_remaining_m")
	var lap := LocalRaceMath.lap_length_m()
	# 同じ場所を2回通るレースでも、標識が並ばない（1周より短い範囲にだけ立てる）。
	assert_lt(max_remaining, lap)
	var track := Path3D.new()
	LocalRaceMath.apply_course_to_path(track)
	add_child_autofree(track)
	for route: Dictionary in M5CourseBuilder.load_layout()["routes"]:
		var total := float(route["distance_m"])
		var positions: Array[Vector3] = []
		for distance in CourseMarkers.marker_distances(total, interval, max_remaining):
			var position: Vector3 = M5CourseBuilder.route_pose(track.curve, route, distance, lap)["position"]
			for other in positions:
				assert_gt(position.distance_to(other), interval * 0.8)
			positions.append(position)
		assert_eq(positions.size(), int(minf(max_remaining, total - interval) / interval))
