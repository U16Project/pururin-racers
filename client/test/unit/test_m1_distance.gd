extends GutTest

const M1Distance := preload("res://scripts/m1_distance.gd")


func test_advance_increases_by_speed_times_delta() -> void:
	var next := M1Distance.advance(1.0, 0.5, 4.0, 100.0)
	assert_eq(next, 3.0)


func test_advance_wraps_on_closed_path() -> void:
	var next := M1Distance.advance(9.0, 1.0, 3.0, 10.0)
	assert_eq(next, 2.0)


func test_advance_zero_length_stays_zero() -> void:
	var next := M1Distance.advance(5.0, 1.0, 2.0, 0.0)
	assert_eq(next, 0.0)


func test_advance_from_start_offset_zero() -> void:
	var next := M1Distance.advance(0.0, 0.25, 8.0, 20.0)
	assert_eq(next, 2.0)
