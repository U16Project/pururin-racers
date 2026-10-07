extends Control
## タイトル画面。背景の画像（ゲーム名のロゴ入り）の上に、「オフラインフリー対戦」のボタンだけを置く。

const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")

var _free_race_button: Button


func _ready() -> void:
	# 画面の比率が画像と違うときは、暗くした同じ画像で、すき間を埋める。
	var filler := TextureRect.new()
	filler.name = "BackgroundFiller"
	filler.texture = load(BACKGROUND_IMAGE_PATH)
	filler.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	filler.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	filler.modulate = Color(0.35, 0.35, 0.4, 1.0)
	filler.set_anchors_preset(Control.PRESET_FULL_RECT)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(filler)
	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_free_race_button = MenuStyle.button("オフラインフリー対戦", 28)
	_free_race_button.name = "FreeRaceButton"
	# 仮の画像に描かれているボタンの上に、本物のボタンを重ねる。
	_free_race_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_free_race_button.offset_left = -182.0
	_free_race_button.offset_right = 182.0
	_free_race_button.offset_top = -82.0
	_free_race_button.offset_bottom = -6.0
	_free_race_button.pressed.connect(go_to_race_select)
	add_child(_free_race_button)
	_free_race_button.grab_focus()


func next_scene_path() -> String:
	return RACE_SELECT_SCENE_PATH


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(next_scene_path())
