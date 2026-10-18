extends GutTest
## 絵の部品で組み立てる操作盤（PartsRaceHud）と、部品の一覧（HeartHudPartsConfig）の確認。
## 絵は、テストの中で小さな仮の絵を作って使う（本物の絵の置き場には書かない）。期待値は、設定や式から作る。

const PartsConfig := preload("res://scripts/config/heart_hud_parts_config.gd")
const PartsRaceHud := preload("res://scripts/presentation/parts_race_hud.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const TEST_DIR := "user://test_parts_race_hud"


func _counts() -> Vector2i:
	return Vector2i(int(LocalRaceMath.DRIVE_LEVEL_MAX), int(LocalRaceMath.Config.number("boost_max_uses")))


## 一覧の絵を、全部、小さな仮の絵で作る（まん中に、色の付いた四角）。skip のファイルは作らない。
func _make_images(skip: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var counts := _counts()
	for file in PartsConfig.image_files(PartsConfig.config(), counts.x, counts.y):
		var path := TEST_DIR.path_join(file)
		if file in skip:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(8, 8, 16, 16), Color.WHITE)
		image.save_png(ProjectSettings.globalize_path(path))


func _hud(state: Dictionary) -> Control:
	var hud: Control = PartsRaceHud.new()
	hud.image_dir_override = ProjectSettings.globalize_path(TEST_DIR)
	add_child_autofree(hud)
	hud.update_state(state)
	return hud


func test_the_parts_list_is_valid() -> void:
	assert_eq(PartsConfig.validate_config(JSON.parse_string(FileAccess.get_file_as_string(PartsConfig.CONFIG_PATH))), PackedStringArray())


func test_the_parts_list_rejects_unknown_fills_and_each_files_without_a_number() -> void:
	var data: Dictionary = PartsConfig.config().duplicate(true)
	data["layers"].append({"file": "extra.png", "fill": "no_such_fill"})
	data["layers"].append({"file": "extra_each.png", "each": "notch"})
	var errors := PartsConfig.validate_config(data)
	assert_eq(errors.size(), 2)


func test_notch_and_boost_images_follow_the_game_settings() -> void:
	var counts := _counts()
	var files := PartsConfig.image_files(PartsConfig.config(), counts.x, counts.y)
	for n in range(1, counts.x + 1):
		assert_true(files.has("notch_%d.png" % n))
	assert_false(files.has("notch_%d.png" % (counts.x + 1)))
	for n in range(1, counts.y + 1):
		assert_true(files.has("boost_%d.png" % n))
	assert_false(files.has("boost_%d.png" % (counts.y + 1)))


func test_missing_images_are_named() -> void:
	_make_images(["board.png", "dash_full.png"])
	var counts := _counts()
	var hud := _hud({"notch_max": counts.x, "boost_max_uses": counts.y})
	assert_eq(hud.missing_images, PackedStringArray(["board.png", "dash_full.png"]))
	assert_push_error("操作盤の部品の絵がありません")


func test_fills_show_the_value_as_a_share() -> void:
	_make_images()
	var counts := _counts()
	var full := float(PartsConfig.config()["fills"]["speed"]["full_value"])
	var hud := _hud({"notch_max": counts.x, "boost_max_uses": counts.y, "speed_kmh": full * 0.5, "fuel_ratio": -0.25, "dash_ratio": 0.4, "air_green": 0.1, "air_blue": 0.2})
	var stage: Control = hud.get_node("Stage")
	assert_almost_eq((stage.get_node("speed_full") as TextureProgressBar).value, 0.5, 0.0001)
	assert_almost_eq((stage.get_node("stamina_full") as TextureProgressBar).value, 0.0, 0.0001)
	assert_almost_eq((stage.get_node("stamina_debt") as TextureProgressBar).value, 0.25, 0.0001)
	assert_almost_eq((stage.get_node("dash_full") as TextureProgressBar).value, 0.4, 0.0001)
	assert_almost_eq((stage.get_node("aero_blue") as TextureProgressBar).value, 0.3, 0.0001)
	assert_almost_eq((stage.get_node("aero_green") as TextureProgressBar).value, 0.1, 0.0001)


func test_notch_bars_light_up_to_the_current_notch_and_boost_shows_the_running_one() -> void:
	_make_images()
	var counts := _counts()
	var notch := 2
	var hud := _hud({"notch_max": counts.x, "boost_max_uses": counts.y, "notch": notch, "boost_uses_left": 1, "boost_ratio": 0.6})
	var stage: Control = hud.get_node("Stage")
	for n in range(1, counts.x + 1):
		assert_eq((stage.get_node("notch_%d" % n) as Control).visible, n <= notch, "ノッチ%d" % n)
	assert_almost_eq((stage.get_node("boost_1") as TextureProgressBar).value, 1.0, 0.0001)
	assert_almost_eq((stage.get_node("boost_2") as TextureProgressBar).value, 0.6, 0.0001)
	for n in range(3, counts.y + 1):
		assert_almost_eq((stage.get_node("boost_%d" % n) as TextureProgressBar).value, 0.0, 0.0001)


func test_radial_fills_turn_around_the_center_from_the_list() -> void:
	_make_images()
	var counts := _counts()
	var hud := _hud({"notch_max": counts.x, "boost_max_uses": counts.y})
	var bar: TextureProgressBar = hud.get_node("Stage/speed_full")
	var fill: Dictionary = PartsConfig.config()["fills"]["speed"]
	var center := Vector2(float(fill["center"][0]), float(fill["center"][1]))
	assert_eq(bar.fill_mode, TextureProgressBar.FILL_CLOCKWISE)
	assert_almost_eq(bar.radial_initial_angle, float(fill["start_deg"]), 0.0001)
	assert_almost_eq(bar.radial_fill_degrees, float(fill["sweep_deg"]), 0.0001)
	# 部品の絵のまん中から、弧のまん中までのずれ。
	assert_almost_eq(bar.position + bar.size * 0.5 + bar.radial_center_offset, center, Vector2(0.001, 0.001))


func test_texts_fill_in_the_values() -> void:
	_make_images()
	var counts := _counts()
	var hud := _hud({"notch_max": counts.x, "boost_max_uses": counts.y, "player_name": "アカネ", "trainer_name": "U16", "speed_kmh": 63.4, "boost_uses_left": 2})
	assert_eq(hud.fill_text("{name}{trainer}"), "アカネ（U16）")
	assert_eq(hud.fill_text("{speed} km/h"), "63 km/h")
	assert_eq(hud.fill_text("( {boost} )"), "( 2 )")
