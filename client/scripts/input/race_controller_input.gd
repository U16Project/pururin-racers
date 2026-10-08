extends RefCounted
## キーボードと標準ゲームパッドをレース画面で共通に扱う小さな入力部品。

const DEVICE := 0
const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.5

## 引き金（L2・R2）が、今引かれているか。「引いた瞬間」を数えるために覚えておく。
static var _trigger_down := {}


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


## レース選択で、距離を1つ前（-1）・次（1）へ動かす。ゲームパッドの L1・R1。それ以外は 0。
static func distance_step(event: InputEvent) -> int:
	if is_button_pressed(event, JOY_BUTTON_LEFT_SHOULDER):
		return -1
	if is_button_pressed(event, JOY_BUTTON_RIGHT_SHOULDER):
		return 1
	return 0


## キャラ選択で、スロットの施錠・解錠を切り替える。ゲームパッドは SELECT、キーボードは L。
static func is_slot_lock_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_BACK) or _is_key_just_pressed(event, KEY_L)


## キャラ選択で、スロットを上の枠（-1）・下の枠（1）へ動かす。それ以外は 0。
## ゲームパッドは L2・R2（引いた瞬間だけ数える）、キーボードは PageUp・PageDown。
## 引き金の状態を覚えるので、1つの入力につき1回だけ呼ぶ。
static func slot_move_direction(event: InputEvent) -> int:
	if _is_key_just_pressed(event, KEY_PAGEUP):
		return -1
	if _is_key_just_pressed(event, KEY_PAGEDOWN):
		return 1
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var down: bool = event.axis_value >= TRIGGER_THRESHOLD
		var was_down := bool(_trigger_down.get(event.axis, false))
		_trigger_down[event.axis] = down
		if down and not was_down:
			return -1 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
	return 0


## キャラ選択で、スロットを未選択にする。ゲームパッドはX、キーボードはX。
static func is_slot_clear_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_X) or _is_key_just_pressed(event, KEY_X)


## キャラ選択で、他のスロットのキャラを奪う。ゲームパッドはY、キーボードはY。
static func is_slot_force_pressed(event: InputEvent) -> bool:
	return is_button_pressed(event, JOY_BUTTON_Y) or _is_key_just_pressed(event, KEY_Y)


static func activate_focused_control(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner()
	return activate_control(focused)


## ゲームパッドのAで、選んでいるボタンを押す。切り替え式のボタンは、入・切を切り替える
## （どれか1つを選ぶ組のボタンは、入にするだけ）。
static func activate_control(control: Control) -> bool:
	if not control is BaseButton or not control.is_visible_in_tree() or control.disabled:
		return false
	var button := control as BaseButton
	if button.toggle_mode:
		button.button_pressed = true if button.button_group != null else not button.button_pressed
		return true
	button.emit_signal("pressed")
	return true


static func _deadzone(value: float) -> float:
	return value if absf(value) >= STICK_DEADZONE else 0.0
