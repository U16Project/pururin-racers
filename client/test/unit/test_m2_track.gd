extends GutTest

const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const M2CourseBuilder := preload("res://scripts/m2_course_builder.gd")


func test_clamp_offset_limits_by_body_and_width() -> void:
	assert_eq(M2TrackMath.TRACK_WIDTH_M, 15.0)
	assert_eq(M2TrackMath.BODY_DIAMETER_M, 1.5)
	assert_eq(M2TrackMath.MAX_ABS_OFFSET_M, 6.75)
	assert_eq(M2TrackMath.clamp_offset(100.0), 6.75)
	assert_eq(M2TrackMath.clamp_offset(-100.0), -6.75)
	assert_eq(M2TrackMath.clamp_offset(0.0), 0.0)


func test_distance_multiplier_straight_ignores_offset() -> void:
	var inside := M2TrackMath.distance_multiplier(-M2TrackMath.HALF_WIDTH_M, 0.0)
	var outside := M2TrackMath.distance_multiplier(M2TrackMath.HALF_WIDTH_M, 0.0)
	assert_eq(inside, 1.0)
	assert_eq(outside, 1.0)


func test_distance_multiplier_matches_radius_ratio() -> void:
	var r := 18.0
	var kappa := 1.0 / r
	var blend := M2TrackMath.GEOMETRIC_BLEND
	var mid := M2TrackMath.distance_multiplier(0.0, kappa)
	var inside := M2TrackMath.distance_multiplier(-6.75, kappa)
	var outside := M2TrackMath.distance_multiplier(6.75, kappa)
	assert_eq(mid, 1.0)
	assert_almost_eq(inside, lerpf(1.0, (r - 6.75) / r, blend), 0.0001)
	assert_almost_eq(outside, lerpf(1.0, (r + 6.75) / r, blend), 0.0001)


func test_advance_inside_gains_centerline_faster_on_curve() -> void:
	var path_len := 100.0
	var kappa := 1.0 / 18.0
	var d_in := M2TrackMath.advance_distance(0.0, 1.0, 10.0, path_len, -5.0, kappa)
	var d_out := M2TrackMath.advance_distance(0.0, 1.0, 10.0, path_len, 5.0, kappa)
	assert_gt(d_in, d_out)
	var d_in_straight := M2TrackMath.advance_distance(0.0, 1.0, 10.0, path_len, -5.0, 0.0)
	var d_out_straight := M2TrackMath.advance_distance(0.0, 1.0, 10.0, path_len, 5.0, 0.0)
	assert_eq(d_in_straight, d_out_straight)


func test_racecourse_curve_is_closed_with_positive_length() -> void:
	var curve := M2CourseBuilder.make_racecourse_curve(28.0, 18.0)
	assert_true(curve.closed)
	assert_gt(curve.get_baked_length(), 100.0)
	assert_lt(curve.get_baked_length(), 250.0)


func test_racecourse_winding_is_counterclockwise() -> void:
	var curve := M2CourseBuilder.make_racecourse_curve(28.0, 18.0)
	var xf0: Transform3D = curve.sample_baked_with_rotation(0.0)
	var xf1: Transform3D = curve.sample_baked_with_rotation(2.0)
	var tangent := xf1.origin - xf0.origin
	tangent.y = 0.0
	tangent = tangent.normalized()
	var to_center := Vector3(-xf0.origin.x, 0.0, -xf0.origin.z).normalized()
	assert_gt(tangent.cross(to_center).y, 0.0)


func test_racecourse_turns_are_nearly_circular() -> void:
	var s := 28.0
	var r := 18.0
	var curve := M2CourseBuilder.make_racecourse_curve(s, r)
	var half_s := s * 0.5
	var left_c := Vector3(-half_s, 0.0, 0.0)
	var right_c := Vector3(half_s, 0.0, 0.0)
	var max_err := 0.0
	var len := curve.get_baked_length()
	var samples := 80
	for i in samples:
		var d := len * float(i) / float(samples)
		var p := curve.sample_baked(d)
		var on_left := p.x <= -half_s + 0.05
		var on_right := p.x >= half_s - 0.05
		if not on_left and not on_right:
			continue
		var c := left_c if on_left else right_c
		max_err = maxf(max_err, absf((p - c).length() - r))
	assert_lt(max_err, 0.05)


func test_curvature_low_on_straight_high_on_turn() -> void:
	var s := 28.0
	var r := 18.0
	var curve := M2CourseBuilder.make_racecourse_curve(s, r)
	var len := curve.get_baked_length()
	var d_straight := -1.0
	var best_mid := 1e9
	for i in 40:
		var d := len * float(i) / 40.0
		var p := curve.sample_baked(d)
		var mid_err := absf(p.x) + absf(p.z + r)
		if mid_err < best_mid:
			best_mid = mid_err
			d_straight = d
	var d_turn := -1.0
	var best_left := 1e9
	for i in 40:
		var d2 := len * float(i) / 40.0
		var p2 := curve.sample_baked(d2)
		var left_err := absf(p2.x + s * 0.5 + r) + absf(p2.z)
		if left_err < best_left:
			best_left = left_err
			d_turn = d2
	assert_lt(M2TrackMath.curvature_at(curve, d_straight), 0.01)
	assert_gt(M2TrackMath.curvature_at(curve, d_turn), 0.04)


func test_stadium_outward_on_straight_and_arc() -> void:
	var s := 28.0
	var r := 18.0
	var bottom := M2TrackMath.stadium_outward(Vector3(0.0, 0.0, -r), s, r)
	assert_eq(bottom, Vector3(0.0, 0.0, -1.0))
	var top := M2TrackMath.stadium_outward(Vector3(0.0, 0.0, r), s, r)
	assert_eq(top, Vector3(0.0, 0.0, 1.0))
	var right := M2TrackMath.stadium_outward(Vector3(s * 0.5 + r, 0.0, 0.0), s, r)
	assert_eq(right, Vector3(1.0, 0.0, 0.0))
	var left := M2TrackMath.stadium_outward(Vector3(-s * 0.5 - r, 0.0, 0.0), s, r)
	assert_eq(left, Vector3(-1.0, 0.0, 0.0))
	var near_corner := M2TrackMath.stadium_outward(Vector3(s * 0.5 * 0.9, 0.0, -r), s, r)
	assert_eq(near_corner, Vector3(0.0, 0.0, -1.0))
