extends Camera3D
## レース場を自由に見て回るカメラ。レースの走者や進行状態には依存しない。

signal move_speed_changed(speed_mps: float)

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const DEVICE := 0
const STICK_DEADZONE := 0.25
const MIN_HEIGHT_M := 1.2
const MIN_MOVE_SPEED_MPS := 5.0
const MAX_MOVE_SPEED_MPS := 300.0
const SPEED_WHEEL_FACTOR := 1.25
const FAST_MULTIPLIER := 3.0
const MOUSE_SENSITIVITY := 0.0022
const PAD_LOOK_SPEED := 1.8
const PITCH_LIMIT_RAD := deg_to_rad(88.0)

@export var move_speed_mps := 80.0

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	current = true
	_yaw = rotation.y
	_pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	move_speed_changed.emit(move_speed_mps)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if _is_return_event(event):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look((event as InputEventMouseMotion).screen_relative * MOUSE_SENSITIVITY)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_move_speed(move_speed_mps * SPEED_WHEEL_FACTOR)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_move_speed(move_speed_mps / SPEED_WHEEL_FACTOR)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var look := _right_stick()
	if not look.is_zero_approx():
		_apply_look(look * PAD_LOOK_SPEED * delta)
	var move := movement_input()
	var vertical := vertical_input()
	if move.is_zero_approx() and is_zero_approx(vertical):
		return
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := global_basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var direction := right * move.x + forward * move.y + Vector3.UP * vertical
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var fast := FAST_MULTIPLIER if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	global_position += direction * move_speed_mps * fast * delta
	global_position.y = maxf(global_position.y, MIN_HEIGHT_M)


## キーボード・左スティック・十字ボタンを、同じ前後左右入力へまとめる。
func movement_input() -> Vector2:
	var move := Vector2.ZERO
	move.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	move.y += float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	move.x += float(Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_RIGHT)) \
		- float(Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_LEFT))
	move.y += float(Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_UP)) \
		- float(Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_DPAD_DOWN))
	var stick := Vector2(
		Input.get_joy_axis(DEVICE, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(DEVICE, JOY_AXIS_LEFT_Y)
	)
	if stick.length() >= STICK_DEADZONE:
		move += stick
	return move.normalized() if move.length_squared() > 1.0 else move


func vertical_input() -> float:
	var vertical := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
	vertical += trigger_strength(JOY_AXIS_TRIGGER_RIGHT) - trigger_strength(JOY_AXIS_TRIGGER_LEFT)
	return clampf(vertical, -1.0, 1.0)


func set_move_speed(value: float) -> void:
	var next := clampf(value, MIN_MOVE_SPEED_MPS, MAX_MOVE_SPEED_MPS)
	if is_equal_approx(next, move_speed_mps):
		return
	move_speed_mps = next
	move_speed_changed.emit(move_speed_mps)


func _apply_look(delta_angles: Vector2) -> void:
	_yaw -= delta_angles.x
	_pitch = clampf(_pitch - delta_angles.y, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
	rotation = Vector3(_pitch, _yaw, 0.0)


func _right_stick() -> Vector2:
	var stick := Vector2(
		Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_Y)
	)
	return stick if stick.length() >= STICK_DEADZONE else Vector2.ZERO


static func trigger_strength(axis: JoyAxis) -> float:
	return clampf(Input.get_joy_axis(DEVICE, axis), 0.0, 1.0)


static func _is_return_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	) or (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	)
