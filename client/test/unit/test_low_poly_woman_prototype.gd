extends GutTest

const Builder := preload("res://scripts/prototype/low_poly_woman_builder.gd")
const PrototypeScene := preload("res://scenes/low_poly_woman_prototype.tscn")


func test_builder_contains_the_major_human_body_and_costume_parts() -> void:
	var woman: Node3D = Builder.build()
	add_child_autofree(woman)
	for part_name: String in [
		"Head", "Neck", "Torso", "Skirt", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"LeftShoe", "RightShoe", "HairCap", "LeftEye", "RightEye", "Mouth", "ChestGem",
	]:
		assert_not_null(woman.get_node_or_null(part_name), "%s がある" % part_name)
	assert_gt(woman.find_children("*", "MeshInstance3D", true, false).size(), 20)
	assert_true(bool(woman.get_meta("prototype_only")), "本編接続用ではない印を持つ")


func test_arms_extend_downward_from_the_shoulders_and_gloves_touch_the_upper_arms() -> void:
	var woman: Node3D = Builder.build()
	add_child_autofree(woman)
	for arm_name: String in ["LeftArm", "RightArm"]:
		var arm := woman.get_node(arm_name) as Node3D
		var glove := arm.get_node("Glove") as MeshInstance3D
		assert_lt(arm.transform.basis.y.y, 0.0, "%s は肩から下へ向く" % arm_name)
		assert_almost_eq(glove.position.y, 0.92, 0.0001, "%s の手袋は上腕の先端から始まる" % arm_name)


func test_prototype_scene_builds_a_camera_lights_and_three_view_positions() -> void:
	var prototype: Node3D = PrototypeScene.instantiate()
	add_child_autofree(prototype)
	assert_not_null(prototype.get_node_or_null("LowPolyWoman"))
	assert_not_null(prototype.get_node_or_null("PreviewCamera"))
	assert_not_null(prototype.get_node_or_null("KeyLight"))
	assert_not_null(prototype.get_node_or_null("FillLight"))
	assert_not_null(prototype.get_node_or_null("FrontCameraPose"))
	assert_not_null(prototype.get_node_or_null("AngleCameraPose"))
	assert_not_null(prototype.get_node_or_null("SideCameraPose"))
	prototype.call("set_view", "front")
	var camera := prototype.get_node("PreviewCamera") as Camera3D
	assert_almost_eq(camera.position.x, 0.0, 0.0001)
	prototype.call("set_view", "side")
	assert_gt(camera.position.x, 10.0)
