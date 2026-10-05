extends GutTest

const CourseMarkers := preload("res://scripts/presentation/course_markers.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")


func test_marker_distances_are_spaced_and_stay_before_the_goal() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var total := interval * 4.0 + interval * 0.5
	var distances := CourseMarkers.marker_distances(total, interval)
	assert_eq(distances.size(), 4)
	for index in distances.size():
		assert_almost_eq(distances[index], interval * float(index + 1), 0.0001)
	assert_lt(distances[distances.size() - 1], total)


func test_marker_distances_exclude_the_goal_position() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var distances := CourseMarkers.marker_distances(interval * 3.0, interval)
	assert_eq(distances.size(), 2)
	assert_eq(CourseMarkers.marker_distances(interval * 3.0, 0.0).size(), 0)


func test_sign_number_is_the_remaining_distance() -> void:
	assert_eq(CourseMarkers.sign_number(2000.0, 100.0), 1900)
	assert_eq(CourseMarkers.sign_number(2000.0, 1500.0), 500)


func test_only_the_last_few_signs_are_large() -> void:
	for remaining: int in CourseMarkers.LARGE_SIGN_REMAINING_M:
		assert_true(CourseMarkers.is_large_sign(remaining))
	assert_false(CourseMarkers.is_large_sign(400))
	assert_false(CourseMarkers.is_large_sign(1900))


func test_cones_sit_midway_between_signs() -> void:
	var interval := LocalRaceMath.Config.number("course_marker_sign_interval_m")
	var total := interval * 3.0 + interval * 0.2
	var midpoints := CourseMarkers.midpoint_distances(total, interval)
	assert_eq(midpoints.size(), 3)
	for index in midpoints.size():
		assert_almost_eq(midpoints[index], interval * (float(index) + 0.5), 0.0001)
	assert_eq(CourseMarkers.midpoint_distances(total, 0.0).size(), 0)


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
