extends Control
## タイトル画面。背景・ロゴ・ヒカリの3枚を重ねて出し（`title_screen.json`）、下の方に「PRESS ANY BUTTON」を点滅させる。
## キー・ゲームパッドのボタン・マウスのボタンで、メニュー画面へ進む。

const TRAINER_PROFILE_SCENE_PATH := "res://scenes/trainer_profile.tscn"
## 背景・ロゴ・ヒカリの3枚の画像と、重ねる位置。
const LAYOUT_PATH := "res://data/config/title_screen.json"
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
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var background_texture: Texture2D = load(str(layout["background"]))
	# 画面の比率が画像と違うときは、暗くした同じ画像で、すき間を埋める。
	var filler := TextureRect.new()
	filler.name = "BackgroundFiller"
	filler.texture = background_texture
	filler.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	filler.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	filler.modulate = Color(0.35, 0.35, 0.4, 1.0)
	filler.set_anchors_preset(Control.PRESET_FULL_RECT)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(filler)
	# 背景と同じ比率の枠に、背景・ロゴ・ヒカリを重ねる。画面の大きさが変わっても、3枚の位置関係は同じ。
	var frame := AspectRatioContainer.new()
	frame.name = "Frame"
	frame.ratio = float(background_texture.get_width()) / float(background_texture.get_height())
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(canvas)
	# 背景は、元画像の一部を拡大して見せる（`view`：見せる所の中心と、拡大の度合い）。枠の外ははみ出さない。
	canvas.clip_contents = true
	# 画面の部品（Control）は位置が1ピクセル単位に丸められ、ゆっくり動かすとカクつくので、絵（Sprite2D）で出す。
	var background := Sprite2D.new()
	background.name = "Background"
	background.texture = background_texture
	background.centered = false
	canvas.add_child(background)
	# 始まりの見せ方から終わりの見せ方へ、じわっと引いていく（終わったら止める）。ロゴは動かさない。
	var view_start: Dictionary = layout["view_start"]
	var view_end: Dictionary = layout["view_end"]
	var progress := {"t": 0.0}
	var refresh := func() -> void:
		_show_view(background, canvas.size, _view_between(view_start, view_end, progress["t"]))
	canvas.resized.connect(refresh)
	var move := create_tween()
	move.tween_method(func(t: float) -> void:
		progress["t"] = t
		refresh.call(), 0.0, 1.0, float(layout["view_seconds"])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for spec: Dictionary in layout["layers"]:
		canvas.add_child(_layer(spec, frame.ratio))
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


## 背景の、見せる所を決める。center は元画像の幅・高さを1とした割合、zoom は1で画像全体。
static func _show_view(background: Sprite2D, frame_size: Vector2, view: Dictionary) -> void:
	var zoom := float(view["zoom"])
	var center: Array = view["center"]
	var shown := frame_size * zoom
	background.scale = shown / background.texture.get_size()
	background.position = frame_size * 0.5 - Vector2(float(center[0]), float(center[1])) * shown


## 2つの見せ方の間（t＝0で始まり、1で終わり）。
static func _view_between(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var a: Array = from["center"]
	var b: Array = to["center"]
	return {
		"center": [lerpf(float(a[0]), float(b[0]), t), lerpf(float(a[1]), float(b[1]), t)],
		"zoom": lerpf(float(from["zoom"]), float(to["zoom"]), t),
	}


## 重ねる1枚。中心と幅は背景に対する割合、高さは画像の縦横の比から決める。
static func _layer(spec: Dictionary, background_ratio: float) -> TextureRect:
	var texture: Texture2D = load(str(spec["image"]))
	var width := float(spec["width"])
	var height := width * background_ratio * float(texture.get_height()) / float(texture.get_width())
	var center: Array = spec["center"]
	var rect := TextureRect.new()
	rect.name = str(spec["name"])
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_left = float(center[0]) - width * 0.5
	rect.anchor_right = float(center[0]) + width * 0.5
	rect.anchor_top = float(center[1]) - height * 0.5
	rect.anchor_bottom = float(center[1]) + height * 0.5
	rect.rotation_degrees = float(spec.get("rotation", 0.0))
	rect.resized.connect(func() -> void: rect.pivot_offset = rect.size * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func next_scene_path() -> String:
	return TRAINER_PROFILE_SCENE_PATH


func go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	UIAudio.play_confirmation()
	get_tree().change_scene_to_file(next_scene_path())
