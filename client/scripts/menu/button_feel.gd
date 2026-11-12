extends Node
## メニューのボタンの動き（2026-11-12、ボタンスタジオで決めた値）。レース中の画面には付けない。
## ・カーソルが乗ったボタンを、少し大きくする。
## ・押した瞬間に、ボタンを一瞬縮めて、明るく光らせる。
## ・画面が切り替わるときは、前の画面をすっと暗くしてから、次の画面を出す。
## 画面のない起動（テスト・サーバー）では、何もしない。

## カーソルが乗ったときの大きさ。
const FOCUS_SCALE := 1.05
const FOCUS_SCALE_S := 0.08
## 押した瞬間：縮める大きさ・明るさ・秒数。
const PRESS_SCALE := 0.94
const PRESS_FLASH := Color(1.35, 1.35, 1.35, 1.0)
const PRESS_S := 0.12
## 画面の切り替えの秒数（前の画面を暗くする時間と、次の画面を明るくする時間の合計）。
const FADE_S := 0.25
## 押してから、この秒数のうちに画面が切り替わったら、押した画面の写しを暗くして見せる。
const SNAPSHOT_KEEP_S := 0.6
const RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const RaceEntries := preload("res://scripts/race_entries.gd")

var _enabled := false
var _focused: WeakRef
var _layer: CanvasLayer
var _shot: TextureRect
var _shade: ColorRect
var _shot_msec := 0
var _fade_tween: Tween


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_shot = TextureRect.new()
	_shot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shot.stretch_mode = TextureRect.STRETCH_SCALE
	_shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot.visible = false
	_layer.add_child(_shot)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_shade)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_on_scene_changed)


## レース中の画面のボタンか（パドックで重ねる出走表は、メニューと同じに扱う）。
func _in_race(control: Control) -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != RACE_SCENE_PATH:
		return false
	var node: Node = control
	while node != null:
		if node.get_script() == RaceEntries:
			return false
		node = node.get_parent()
	return true


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_on_pressed.bind(node))


func _on_focus_changed(control: Control) -> void:
	var before: Control = _focused.get_ref() if _focused != null else null
	if is_instance_valid(before) and before != control:
		_scale_to(before, 1.0)
	_focused = null
	if control is BaseButton and not _in_race(control):
		_focused = weakref(control)
		_scale_to(control, FOCUS_SCALE)


func _scale_to(control: Control, target: float) -> void:
	control.pivot_offset = control.size * 0.5
	control.create_tween().tween_property(control, "scale", Vector2.ONE * target, FOCUS_SCALE_S)
	# 並びの箱（Container）は、並べ直すたびに大きさを1に戻すので、並べ直したあとに、もう一度合わせる。
	var box := control.get_parent() as Container
	if box != null and not box.sort_children.is_connected(_on_sorted):
		box.sort_children.connect(_on_sorted, CONNECT_DEFERRED)


func _on_sorted() -> void:
	var control: Control = _focused.get_ref() if _focused != null else null
	if is_instance_valid(control) and control.has_focus():
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * FOCUS_SCALE


func _on_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree() or _in_race(button):
		return
	# 押した画面の写しを取っておく（このあとすぐ画面が切り替わったら、これを暗くして見せる）。
	_shot.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	_shot_msec = Time.get_ticks_msec()
	var rest := button.scale
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", rest * PRESS_SCALE, PRESS_S * 0.5)
	tween.parallel().tween_property(button, "modulate", PRESS_FLASH, PRESS_S * 0.5)
	tween.tween_property(button, "scale", rest, PRESS_S * 0.5)
	tween.parallel().tween_property(button, "modulate", Color.WHITE, PRESS_S * 0.5)


## 画面が切り替わった：押した直後なら、前の画面の写しを暗くしてから、次の画面を明るくする。そうでなければ、暗い所から明るくする。
func _on_scene_changed() -> void:
	_focused = null
	# 開いた画面で、はじめからカーソルがあるボタンも、大きくする。
	(func() -> void:
		await get_tree().process_frame
		_on_focus_changed(get_viewport().gui_get_focus_owner())).call()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var half := FADE_S * 0.5
	_fade_tween = create_tween()
	if Time.get_ticks_msec() - _shot_msec <= int(SNAPSHOT_KEEP_S * 1000.0) and _shot.texture != null:
		_shot.visible = true
		_shade.color.a = 0.0
		_fade_tween.tween_property(_shade, "color:a", 1.0, half)
		_fade_tween.tween_callback(func() -> void: _shot.visible = false)
	else:
		_shade.color.a = 1.0
	_fade_tween.tween_property(_shade, "color:a", 0.0, half)
	_shot_msec = 0
