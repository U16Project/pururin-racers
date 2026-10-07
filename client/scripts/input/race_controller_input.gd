extends RefCounted
## キーボードと標準ゲームパッドをレース画面で共通に扱う小さな入力部品。

const DEVICE := 0
const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.5


static func line_axis() -> float:
	var axis := 0.0
	if Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_LEFT):
		axis -= 1.0
	if Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_RIGHT):
		axis += 1.0
	if not is_zero_approx(axis):
		return axis
	return _deadzone(Input.get_joy_axis(DEVICE, JOY_AXIS_LEFT_X))


static func notch_axis() -> float:
	var axis := 0.0
	if Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_UP):
		axis += 1.0
	if Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_DOWN):
		axis -= 1.0
	return axis


## ブレーキ操作。押している間だけ制動し、ノッチ設定は変えない。
## キーボードはスペース、ゲームパッドはAボタンまたは左トリガー。
static func brake_pressed() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_SPACE)
		or Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_A)
		or Input.get_joy_axis(DEVICE, JOY_AXIS_TRIGGER_LEFT) >= TRIGGER_THRESHOLD
	)


## ダッシュ。押した瞬間だけ（押しっぱなしの繰り返しは数えない）。ゲームパッドはB、キーボードはZ。
## （キーボードのAは、カメラを左へずらす操作に使っている）
static func is_dash_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_B) or _is_key_just_pressed(event, KEY_Z)


## ブースト。押した瞬間だけ。ゲームパッドはX、キーボードはX。
static func is_boost_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_X) or _is_key_just_pressed(event, KEY_X)


static func _is_key_just_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == keycode


## 見回し（右スティック）。倒していなければゼロ。倒した向きと量を、そのまま返す。
static func look_vector() -> Vector2:
	var stick := Vector2(Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_X), Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_Y))
	return stick if stick.length() >= STICK_DEADZONE else Vector2.ZERO


static func chase_yaw_axis() -> float:
	return _deadzone(Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_X))


static func is_button_pressed(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


static func is_menu_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_START)


static func is_cancel_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_B)


static func activate_focused_control(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner()
	return activate_control(focused)


static func activate_control(control: Control) -> bool:
	if not control is BaseButton or not control.is_visible_in_tree() or control.disabled:
		return false
	control.emit_signal("pressed")
	return true


static func _deadzone(value: float) -> float:
	return value if absf(value) >= STICK_DEADZONE else 0.0
