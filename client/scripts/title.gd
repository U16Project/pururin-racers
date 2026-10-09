extends Control
## タイトル画面。背景の画像（ゲーム名のロゴ入り）の上に、遊ぶモードのボタンを置く。

const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const CAMERA_EXPLORATION_SCENE_PATH := "res://scenes/camera_exploration.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
## ボタンの下の余白と、ボタンの濃さ（1で不透明）。
const BUTTON_BOTTOM_MARGIN := 56.0
const BUTTON_HEIGHT := 76.0
const BUTTON_GAP := 12.0
const BUTTON_OPACITY := 0.7
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

var _free_race_button: Button
var _camera_exploration_button: Button


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
	# ボタンは少し透けさせて、背景の絵が見えるようにする。
	_free_race_button = MenuStyle.button("オフラインフリー対戦", 28, Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_free_race_button.name = "FreeRaceButton"
	_free_race_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_free_race_button.offset_left = -182.0
	_free_race_button.offset_right = 182.0
	_free_race_button.offset_top = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT * 2.0 - BUTTON_GAP
	_free_race_button.offset_bottom = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT - BUTTON_GAP
	_free_race_button.pressed.connect(go_to_race_select)
	add_child(_free_race_button)
	_camera_exploration_button = MenuStyle.button("カメラで探検", 28, Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_camera_exploration_button.name = "CameraExplorationButton"
	_camera_exploration_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_camera_exploration_button.offset_left = -182.0
	_camera_exploration_button.offset_right = 182.0
	_camera_exploration_button.offset_top = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT
	_camera_exploration_button.offset_bottom = -BUTTON_BOTTOM_MARGIN
	_camera_exploration_button.pressed.connect(go_to_camera_exploration)
	add_child(_camera_exploration_button)
	_free_race_button.focus_neighbor_bottom = _free_race_button.get_path_to(_camera_exploration_button)
	_camera_exploration_button.focus_neighbor_top = _camera_exploration_button.get_path_to(_free_race_button)
	_free_race_button.grab_focus()


## ゲームパッドの決定（A）で、選んでいるボタンを押す（Godotの標準では、ゲームパッドのボタンは「決定」に割り当てられていない）。
func _unhandled_input(event: InputEvent) -> void:
	if not RaceControllerInput.is_accept_pressed(event):
		return
	# ボタンを押すと場面が変わることがあるので、画面は先に取っておく。
	var viewport := get_viewport()
	if RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()


func next_scene_path() -> String:
	return RACE_SELECT_SCENE_PATH


func camera_exploration_scene_path() -> String:
	return CAMERA_EXPLORATION_SCENE_PATH


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(next_scene_path())


func go_to_camera_exploration() -> void:
	get_tree().change_scene_to_file(camera_exploration_scene_path())
