extends GutTest

const FirstDrawWarmup := preload("res://scripts/presentation/first_draw_warmup.gd")
const FpsLabel := preload("res://scripts/debug/fps_label.gd")


func test_camera_is_high_enough_to_fit_the_whole_range() -> void:
	var radius := 500.0
	var height := FirstDrawWarmup.camera_height_m(radius)
	# その高さから見える半径（画面の端まで）が、描いておきたい範囲より広い。
	var seen_radius := height * tan(deg_to_rad(FirstDrawWarmup.CAMERA_FOV_DEG) * 0.5)
	assert_gt(seen_radius, radius)


func test_distance_limits_are_lifted_while_warming_and_put_back_after() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var limited := MeshInstance3D.new()
	limited.visibility_range_end = 123.0
	root.add_child(limited)
	var warmup := FirstDrawWarmup.new()
	warmup.setup(Vector3.ZERO, 100.0)
	root.add_child(warmup)
	assert_eq(limited.visibility_range_end, 0.0)
	for i in FirstDrawWarmup.FRAMES + 1:
		await get_tree().process_frame
	assert_almost_eq(limited.visibility_range_end, 123.0, 0.0001)
	assert_null(root.get_node_or_null("FirstDrawWarmup"))


func test_frames_per_second_counts_the_frames_actually_drawn() -> void:
	assert_eq(FpsLabel.frames_per_second(20, 0.5), 40)
	assert_eq(FpsLabel.frames_per_second(1, 0.5), 2)


func test_status_text_shows_frames_process_time_and_draw_calls() -> void:
	var text := FpsLabel.status_text(40, 12.4, 88.0, 230)
	for part in ["40", "12", "88", "230"]:
		assert_string_contains(text, part)
