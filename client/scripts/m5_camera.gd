extends Camera3D
## M5 camera: adjustable chase camera and overview camera.

const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

@export var follow_distance: float = 12.0
@export var follow_height: float = 4.0
@export var overview_height: float = 420.0
@export var overview_ortho_size: float = 560.0
@export var chase_adjust_speed: float = 8.0
@export var chase_turn_speed: float = 1.2

enum CameraMode { CHASE, OVERVIEW }
var mode := CameraMode.CHASE
var _target: Node3D
var _chase_fov := 55.0
var _follow_distance_default := 12.0
var _follow_height_default := 4.0
var _follow_lateral_default := 0.0
var _follow_yaw_default := 0.0
var _follow_lateral := 0.0
var _follow_yaw := 0.0

func _ready() -> void:
	_chase_fov = fov
	_follow_distance_default = follow_distance
	_follow_height_default = follow_height
	current = true

func set_follow_target(node: Node3D) -> void:
	_target = node
	if mode == CameraMode.CHASE:
		_apply_chase()

func _unhandled_input(event: InputEvent) -> void:
	if RaceControllerInput.is_button_pressed(event, JOY_BUTTON_Y):
		_toggle_view()
		get_viewport().set_input_as_handled()
	elif RaceControllerInput.is_button_pressed(event, JOY_BUTTON_RIGHT_STICK):
		_reset_to_chase()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		_toggle_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		_reset_to_chase()
		get_viewport().set_input_as_handled()


func _toggle_view() -> void:
	mode = CameraMode.OVERVIEW if mode == CameraMode.CHASE else CameraMode.CHASE
	if mode == CameraMode.CHASE:
		_restore_perspective()


func _reset_to_chase() -> void:
	mode = CameraMode.CHASE
	_reset_chase_adjustment()
	_restore_perspective()

func _process(delta: float) -> void:
	if mode == CameraMode.CHASE:
		_process_chase_adjustment(delta)
		_apply_chase()
	elif mode == CameraMode.OVERVIEW:
		_apply_overview()

func _apply_chase() -> void:
	if _target == null:
		return
	var forward := -_target.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	global_position = _target.global_position - forward * follow_distance + right * _follow_lateral + Vector3.UP * follow_height
	var view_target := _target.global_position + Vector3.UP * 0.6
	var view_direction := (view_target - global_position).normalized()
	if absf(_follow_yaw) > 0.0001:
		view_direction = (Basis(Vector3.UP, _follow_yaw) * view_direction).normalized()
	look_at(global_position + view_direction, Vector3.UP)

func _process_chase_adjustment(delta: float) -> void:
	var speed := chase_adjust_speed * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if Input.is_key_pressed(KEY_W):
		follow_distance = maxf(3.0, follow_distance - speed * delta)
	if Input.is_key_pressed(KEY_S):
		follow_distance = minf(40.0, follow_distance + speed * delta)
	if Input.is_key_pressed(KEY_A):
		_follow_lateral = maxf(-12.0, _follow_lateral - speed * delta)
	if Input.is_key_pressed(KEY_D):
		_follow_lateral = minf(12.0, _follow_lateral + speed * delta)
	if Input.is_key_pressed(KEY_Q):
		_follow_yaw += chase_turn_speed * delta * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if Input.is_key_pressed(KEY_E):
		_follow_yaw -= chase_turn_speed * delta * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_follow_yaw -= RaceControllerInput.chase_yaw_axis() * chase_turn_speed * delta

func _reset_chase_adjustment() -> void:
	follow_distance = _follow_distance_default
	follow_height = _follow_height_default
	_follow_lateral = _follow_lateral_default
	_follow_yaw = _follow_yaw_default

func _apply_overview() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = overview_ortho_size
	global_position = Vector3(0.0, overview_height, 0.0)
	look_at(Vector3.ZERO, Vector3(0.0, 0.0, 1.0))

func _restore_perspective() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = _chase_fov
	if mode == CameraMode.CHASE:
		_apply_chase()
