extends GutTest
## トレーナー画像の枠。自分で選んだ画像は、角丸の枠と同じ形で切る。

const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")


func test_rounded_frame_cuts_square_corners() -> void:
	var rect := Rect2(10, 20, 100, 100)
	var radius := 18.0
	var points := TrainerIcon.rounded_frame_points(rect, radius)
	assert_gt(points.size(), 8)
	var nearest := points[0].distance_to(rect.position)
	for point in points:
		nearest = minf(nearest, point.distance_to(rect.position))
		assert_true(rect.grow(0.05).has_point(point))
	# 角の尖りまでは届かない。一番近い点は、曲線の対角側。
	assert_almost_eq(nearest, radius * (sqrt(2.0) - 1.0), 0.2)
	var top_tangent := Vector2(rect.position.x + radius, rect.position.y)
	var found := false
	for point in points:
		if point.distance_to(top_tangent) < 0.2:
			found = true
	assert_true(found, "枠の上辺は、角丸の接点から直線になる")


func test_every_prepared_avatar_has_an_image() -> void:
	for avatar: Dictionary in TrainerProfile.avatars():
		assert_not_null(TrainerIcon.avatar_texture(str(avatar["id"])), "人の絵の画像: %s" % avatar["id"])
	assert_null(TrainerIcon.avatar_texture("no-such-avatar"))
