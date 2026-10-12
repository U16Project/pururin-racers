extends Control
## 画面の上に出す、仮想パッド（スマホで遊ぶときの操作盤）。
## F2で出し入れする。指で触る画面では、最初から出す。
## 押した状態は touch_pad_input.gd に入れ、本物のパッドと同じ扱いでレースに届く。

const TouchPadInput := preload("res://scripts/input/touch_pad_input.gd")

## ラインを左右へ動かすボタン（左下に、◀ ▶ を横に並べる。スマホの親指が届くように、左の端に寄せる）。
## 1つぶん：名前、文字、左下の角からの位置、半径、押しているあいだ入れる左右の値（-1＝左、1＝右）。
const LINE_BUTTON_RADIUS := 50.0
const LINE_BUTTONS := [
	{"id": "line_left", "text": "◀", "offset": Vector2(90.0, 104.0), "radius": LINE_BUTTON_RADIUS, "axis_value": -1.0, "color": Color("#5b6b8c"), "from_left": true},
	{"id": "line_right", "text": "▶", "offset": Vector2(194.0, 104.0), "radius": LINE_BUTTON_RADIUS, "axis_value": 1.0, "color": Color("#5b6b8c"), "from_left": true},
]
## ラインのボタンの、右の端（左から）。丸い操作盤は、このすぐ右に置く。
const LINE_BUTTONS_RIGHT := 244.0
## 丸ボタン。1つぶん：名前、文字、角からの位置、半径、パッドのボタン番号。
## 位置は右下の角から。`from_left` が true なら左から、`from_top` が true なら上から測る。
## ABXYに当たる3つは、本物のパッドと同じひし形（下＝A、右＝B、左＝X）に並べる。
const ROUND_BUTTONS := [
	{"id": "brake", "text": "ブレーキ", "offset": Vector2(140.0, 74.0), "radius": 40.0, "button": JOY_BUTTON_A, "color": Color("#5b6b8c")},
	{"id": "dash", "text": "DASH", "offset": Vector2(62.0, 152.0), "radius": 40.0, "button": JOY_BUTTON_B, "color": Color("#d9534f")},
	{"id": "boost", "text": "BOOST", "offset": Vector2(218.0, 152.0), "radius": 40.0, "button": JOY_BUTTON_X, "color": Color("#2f7fd0")},
	{"id": "view", "text": "視点", "offset": Vector2(140.0, 230.0), "radius": 40.0, "button": JOY_BUTTON_Y, "color": Color("#c7a24a")},
	{"id": "notch_up", "text": "▲", "offset": Vector2(330.0, 178.0), "radius": 46.0, "button": JOY_BUTTON_DPAD_UP, "color": Color("#4a8f5a")},
	{"id": "notch_down", "text": "▼", "offset": Vector2(330.0, 80.0), "radius": 46.0, "button": JOY_BUTTON_DPAD_DOWN, "color": Color("#4a8f5a")},
	{"id": "menu", "text": "≡", "offset": Vector2(56.0, 56.0), "radius": 28.0, "button": JOY_BUTTON_START, "color": Color("#6b6f7a"), "from_top": true},
]
## 色。
const COLOR_FACE := Color(0.1, 0.13, 0.2, 0.42)
const COLOR_FACE_ON := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_EDGE := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_TEXT := Color(1.0, 1.0, 1.0, 0.92)
const FONT_PATH := "res://fonts/NotoSansJP-Regular.otf"

## 仮想パッドを出しているか。
var _shown := false
## マウスを、指の番号として扱うときの番号（指は0以上）。
const MOUSE_FINGER := -1


## 指（またはマウス）の番号 → さわっている部品のID。
var _touching := {}
var _font: Font


func _ready() -> void:
	name = "TouchControls"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(FONT_PATH) as Font
	_shown = TouchPadInput.shows_by_default()
	set_process_input(true)
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)


## 画面いっぱいに広げる（CanvasLayerの下では、自分で大きさを合わせる必要がある）。
func _fit_to_screen() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _exit_tree() -> void:
	TouchPadInput.release_all()


## 出す・消すを、直に決める（結果の板を出したときなど）。
func set_pad_shown(shown: bool) -> void:
	if _shown != shown:
		toggle_pad()


func is_pad_shown() -> bool:
	return _shown


## 出し入れを切り替える。消すときは、押しっぱなしを残さない。
func toggle_pad() -> void:
	_shown = not _shown
	if not _shown:
		_touching.clear()
		TouchPadInput.release_all()
	queue_redraw()


# ---------------------------------------------------------------- 置き場所

## 「ライン左右」の文字を出す場所（2つのボタンの、まん中の上）。
func line_label_center() -> Vector2:
	var left := button_center(LINE_BUTTONS[0])
	var right := button_center(LINE_BUTTONS[1])
	return (left + right) * 0.5 - Vector2(0.0, LINE_BUTTON_RADIUS + 20.0)


func button_center(spec: Dictionary) -> Vector2:
	var offset: Vector2 = spec["offset"]
	var x: float = offset.x if bool(spec.get("from_left", false)) else size.x - offset.x
	var y: float = offset.y if bool(spec.get("from_top", false)) else size.y - offset.y
	return Vector2(x, y)


## 全部のボタン（ラインの左右と、丸ボタン）。
static func all_buttons() -> Array:
	return LINE_BUTTONS + ROUND_BUTTONS


## その場所にある部品のID。無ければ空文字。
func widget_at(point: Vector2) -> String:
	if not _shown:
		return ""
	for spec: Dictionary in all_buttons():
		if point.distance_to(button_center(spec)) <= float(spec["radius"]):
			return str(spec["id"])
	return ""


static func button_spec(id: String) -> Dictionary:
	for spec: Dictionary in all_buttons():
		if str(spec["id"]) == id:
			return spec
	return {}


# ---------------------------------------------------------------- 入力

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		toggle_pad()
		get_viewport().set_input_as_handled()
		return
	# 指（スマホ）と、マウス（パソコンで試すとき）の両方を受ける。
	if event is InputEventScreenTouch:
		_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _is_from_touch(event):
		_press(MOUSE_FINGER, event.position, event.pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not _is_from_touch(event):
		_drag(MOUSE_FINGER, event.position)


## 指でさわったときに、Godotが代わりに作るマウスの入力か（device が -1 なら、それ）。
## 同じ1回の操作で、指とマウスの両方が届くので、こちらは読み飛ばす。
static func _is_from_touch(event: InputEvent) -> bool:
	return event.device == MOUSE_FINGER


func _press(finger: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		_release(finger)
		return
	var id := widget_at(point)
	if id == "":
		return
	get_viewport().set_input_as_handled()
	_touching[finger] = id
	if is_line_button(id):
		_apply_line()
	else:
		TouchPadInput.set_button(int(button_spec(id)["button"]), true)
	queue_redraw()


## ラインのボタンを押したまま、指をとなりのラインのボタンへすべらせたら、そちらに切り替える。
func _drag(finger: int, point: Vector2) -> void:
	if not is_line_button(str(_touching.get(finger, ""))):
		return
	get_viewport().set_input_as_handled()
	var id := widget_at(point)
	if is_line_button(id) and id != str(_touching[finger]):
		_touching[finger] = id
		_apply_line()
		queue_redraw()


func _release(finger: int) -> void:
	var id := str(_touching.get(finger, ""))
	if id == "":
		return
	_touching.erase(finger)
	if is_line_button(id):
		_apply_line()
	else:
		TouchPadInput.set_button(int(button_spec(id)["button"]), false)
	queue_redraw()


static func is_line_button(id: String) -> bool:
	for spec: Dictionary in LINE_BUTTONS:
		if str(spec["id"]) == id:
			return true
	return false


## 今押しているラインのボタンから、左右の値を決める（◀だけ＝-1、▶だけ＝1、両方か、どちらも無し＝0）。
func _apply_line() -> void:
	var value := 0.0
	for spec: Dictionary in LINE_BUTTONS:
		if str(spec["id"]) in _touching.values():
			value += float(spec["axis_value"])
	TouchPadInput.set_axis(JOY_AXIS_LEFT_X, value)


# ---------------------------------------------------------------- 見た目

func _draw() -> void:
	if not _shown:
		return
	_draw_text(line_label_center(), "ライン左右", 20)
	for spec: Dictionary in all_buttons():
		var at := button_center(spec)
		var radius := float(spec["radius"])
		var held := str(spec["id"]) in _touching.values()
		draw_circle(at, radius, (spec["color"] as Color) * Color(1.0, 1.0, 1.0, 0.55))
		if held:
			draw_circle(at, radius, COLOR_FACE_ON)
		draw_arc(at, radius, 0.0, TAU, 40, COLOR_EDGE, 3.0, true)
		var text := str(spec["text"])
		# 1文字の印（▲▼・≡）は、丸の大きさに合わせて大きく出す。
		var text_size: int = int(radius * 0.62) if text.length() <= 1 else (22 if radius > 36.0 else 26)
		_draw_text(at, text, text_size)


func _draw_text(center: Vector2, text: String, size: int) -> void:
	if _font == null:
		return
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(_font, center + Vector2(-width * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(_font, center + Vector2(-width * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_TEXT)
