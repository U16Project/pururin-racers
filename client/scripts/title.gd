extends Control
## タイトル画面。背景の画像だけを出し、下の方に「PRESS ANY BUTTON」を点滅させる。
## キー・ゲームパッドのボタン・マウスのボタンで、メニュー画面へ進む。

const TRAINER_PROFILE_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_screen_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const Logo := preload("res://scripts/logo.gd")
const BuildInfo := preload("res://scripts/build_info.gd")
const PROMPT_TEXT := "ー　PRESS ANY BUTTON　ー"
## ロゴからの押しっぱなしで、すぐ抜けないようにする待ち時間。
const ARM_DELAY_MSEC := 250

var _prompt: Label
var _armed_at_msec := 0
var _leaving := false


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
	_prompt = MenuStyle.label(PROMPT_TEXT, 28)
	_prompt.name = "PressAnyButton"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -360.0
	_prompt.offset_right = 360.0
	_prompt.offset_top = -88.0
	_prompt.offset_bottom = -36.0
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	# 右下に、版の目印（いつ書き出した版か）を小さく出す。ブラウザ版で、古い版が出ていないかを見分けるため。
	var version := MenuStyle.label(BuildInfo.label_text(), 14, MenuStyle.COLOR_DIM)
	version.name = "VersionLabel"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -420.0
	version.offset_right = -12.0
	version.offset_top = -30.0
	version.offset_bottom = -8.0
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version)
	var tween := create_tween().set_loops()
	tween.tween_property(_prompt, "modulate:a", 0.15, 0.55)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.55)
	_armed_at_msec = Time.get_ticks_msec()


## タイトルには操作部品がないため、未処理入力ではなく最初の入力段階で受ける。
## これでマウスクリックも、GUIへ消費されずに確実に進める。
func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _armed_at_msec < ARM_DELAY_MSEC:
		return
	if Logo.is_skip_event(event):
		get_viewport().set_input_as_handled()
		go_to_menu()


func next_scene_path() -> String:
	return TRAINER_PROFILE_SCENE_PATH


func go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	UIAudio.play_confirmation()
	get_tree().change_scene_to_file(next_scene_path())
