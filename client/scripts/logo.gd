extends Control
## 起動して最初に出す、U16-Projectのロゴ。ふわっと出て消えたら、タイトルへ進む。どのボタンでも飛ばせる。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const LOGO_IMAGE_PATH := "res://assets/ui/logo_u16project.png"
const FADE_IN_S := 0.5
const HOLD_S := 1.0
const FADE_OUT_S := 0.5
const BACKGROUND_COLOR := Color(0.055, 0.07, 0.11, 1.0)

var _logo: TextureRect
var _leaving := false


func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO_IMAGE_PATH)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.offset_left = 220.0
	_logo.offset_right = -220.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	add_child(_logo)
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, FADE_IN_S)
	tween.tween_interval(HOLD_S)
	tween.tween_property(_logo, "modulate:a", 0.0, FADE_OUT_S)
	tween.tween_callback(go_to_title)


func _unhandled_input(event: InputEvent) -> void:
	if is_skip_event(event):
		get_viewport().set_input_as_handled()
		go_to_title()


## キー・ゲームパッドのボタン・マウスのボタンを押したら、飛ばす。
static func is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return (event is InputEventJoypadButton or event is InputEventMouseButton) and event.pressed


func next_scene_path() -> String:
	return TITLE_SCENE_PATH


func go_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(next_scene_path())
