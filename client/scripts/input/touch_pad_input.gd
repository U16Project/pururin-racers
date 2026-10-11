extends RefCounted
## 画面の上に出す仮想パッドが、今どう押されているかを覚えておく場所。
## レースの入力（race_controller_input.gd）は、本物のパッドと、ここの状態の両方を見る。
## 押した瞬間を数える操作（ダッシュなど）のために、本物のパッドと同じ形の入力も流す。

## ボタン番号 → 押しているか。
static var _buttons := {}
## 軸番号 → 今の値（-1〜1）。
static var _axes := {}


## 仮想パッドを、最初から出すか（スマホなど、指で触る画面のとき）。
static func shows_by_default() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


static func button_down(button: int) -> bool:
	return bool(_buttons.get(button, false))


static func axis_value(axis: int) -> float:
	return float(_axes.get(axis, 0.0))


## ボタンの押し・離しを記録し、本物のパッドと同じ形の入力も流す（押した瞬間を見る処理のため）。
static func set_button(button: int, pressed: bool) -> void:
	if bool(_buttons.get(button, false)) == pressed:
		return
	_buttons[button] = pressed
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	# パッドの補正（pad_input_options.gd）は通さない。仮想パッドは、はじめから正しい割り当てで出すため。
	event.set_meta("pad_corrected", true)
	Input.parse_input_event(event)


static func set_axis(axis: int, value: float) -> void:
	var clamped := clampf(value, -1.0, 1.0)
	if is_equal_approx(float(_axes.get(axis, 0.0)), clamped):
		return
	_axes[axis] = clamped
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = clamped
	event.set_meta("pad_corrected", true)
	Input.parse_input_event(event)


## 画面を離れるときなど、押しっぱなしを残さないように、全部もとへ戻す。
static func release_all() -> void:
	for button: int in _buttons.keys():
		set_button(button, false)
	for axis: int in _axes.keys():
		set_axis(axis, 0.0)


## スティックの倒し方。center はスティックのまん中、point は指の場所、radius は端までの長さ。
## 返すのは、-1〜1の横と縦（倒しきると長さ1）。
static func stick_vector(center: Vector2, point: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var offset := (point - center) / radius
	return offset if offset.length() <= 1.0 else offset.normalized()
