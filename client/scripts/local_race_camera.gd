extends Camera3D
## ローカルレースのカメラ。追う視点を4つ切り替える（デフォルト・遠距離・上空・一人称の順）。
## ゲームパッドの右スティックを倒している間は「見回し」になり、倒した向きを見る。離すと元の視点に戻る。

const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

enum View { DEFAULT, FAR, FIRST_PERSON, OVERHEAD }

## 各視点の、後ろへの距離・高さ（m）と、見る先。look_ahead が true のときは、まっすぐ前を見る（傾きなし）。
const VIEW_SETTINGS := {
	View.DEFAULT: {"back": 6.0, "height": 3.0, "look_ahead": false},
	View.FAR: {"back": 12.0, "height": 4.0, "look_ahead": false},
	View.FIRST_PERSON: {"back": 0.0, "height": 1.5, "look_ahead": true},
	View.OVERHEAD: {"back": 5.0, "height": 40.0, "look_ahead": false},
}
const VIEW_ORDER := [View.DEFAULT, View.FAR, View.OVERHEAD, View.FIRST_PERSON]
## 追う視点で見る点の高さ（走者の足元から）。
const LOOK_TARGET_HEIGHT_M := 0.6
## 走者の体の高さ（頭の位置）。
const BODY_TOP_HEIGHT_M := 1.5
## 見回し：頭の上の高さと、見下ろす角度。
const LOOK_AROUND_ABOVE_HEAD_M := 1.6
const LOOK_AROUND_PITCH_DEG := 12.0
const BACK_MIN_M := 0.0
const BACK_MAX_M := 40.0
const LATERAL_MAX_M := 12.0

@export var chase_adjust_speed: float = 8.0
@export var chase_turn_speed: float = 1.2

var view: View = View.DEFAULT
var _target: Node3D
## キーボードでの微調整（視点ごとの基準に足す）。
var _back_offset := 0.0
var _lateral_offset := 0.0
var _yaw_offset := 0.0


func _ready() -> void:
	current = true


func set_follow_target(node: Node3D) -> void:
	_target = node
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if RaceControllerInput.is_button_pressed(event, JOY_BUTTON_Y) or _is_key(event, KEY_C):
		_set_view(next_view(view))
		get_viewport().set_input_as_handled()
	elif RaceControllerInput.is_button_pressed(event, JOY_BUTTON_RIGHT_STICK) or _is_key(event, KEY_R):
		_reset_adjustment()
		_set_view(View.DEFAULT)
		get_viewport().set_input_as_handled()


static func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == keycode


## 視点を順番に切り替える。
static func next_view(current_view: View) -> View:
	var index := VIEW_ORDER.find(current_view)
	return VIEW_ORDER[(index + 1) % VIEW_ORDER.size()]


## 右スティックの倒した向きを、進行方向からの回転（ラジアン）にする。前が0、右が正。
static func look_yaw_from_stick(stick: Vector2) -> float:
	return atan2(stick.x, -stick.y)


func _set_view(next: View) -> void:
	view = next
	_apply()


func _reset_adjustment() -> void:
	_back_offset = 0.0
	_lateral_offset = 0.0
	_yaw_offset = 0.0


func _process(delta: float) -> void:
	_process_keyboard_adjustment(delta)
	_apply()


func _process_keyboard_adjustment(delta: float) -> void:
	var fast := 2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var speed := chase_adjust_speed * fast
	if Input.is_key_pressed(KEY_W):
		_back_offset -= speed * delta
	if Input.is_key_pressed(KEY_S):
		_back_offset += speed * delta
	if Input.is_key_pressed(KEY_A):
		_lateral_offset = maxf(-LATERAL_MAX_M, _lateral_offset - speed * delta)
	if Input.is_key_pressed(KEY_D):
		_lateral_offset = minf(LATERAL_MAX_M, _lateral_offset + speed * delta)
	if Input.is_key_pressed(KEY_Q):
		_yaw_offset += chase_turn_speed * delta * fast
	if Input.is_key_pressed(KEY_E):
		_yaw_offset -= chase_turn_speed * delta * fast


func _apply() -> void:
	if _target == null:
		return
	var forward := -_target.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var stick := RaceControllerInput.look_vector()
	var looking_around := stick.length_squared() > 0.0
	_set_own_body_visible(looking_around or view != View.FIRST_PERSON)
	if looking_around:
		_apply_look_around(forward, stick)
	else:
		_apply_view(forward)


## 見回し：頭の上から、倒した向きを、やや見下ろして見る。
func _apply_look_around(forward: Vector3, stick: Vector2) -> void:
	global_position = _target.global_position + Vector3.UP * (BODY_TOP_HEIGHT_M + LOOK_AROUND_ABOVE_HEAD_M)
	var direction := Basis(Vector3.UP, -look_yaw_from_stick(stick)) * forward
	var right := direction.cross(Vector3.UP).normalized()
	direction = Basis(right, -deg_to_rad(LOOK_AROUND_PITCH_DEG)) * direction
	look_at(global_position + direction, Vector3.UP)


func _apply_view(forward: Vector3) -> void:
	var settings: Dictionary = VIEW_SETTINGS[view]
	var back := clampf(float(settings["back"]) + _back_offset, BACK_MIN_M, BACK_MAX_M)
	# 微調整は、限度を超えて溜めない。
	_back_offset = back - float(settings["back"])
	var right := forward.cross(Vector3.UP).normalized()
	global_position = _target.global_position - forward * back + right * _lateral_offset + Vector3.UP * float(settings["height"])
	var direction := forward
	if not bool(settings["look_ahead"]):
		direction = (_target.global_position + Vector3.UP * LOOK_TARGET_HEIGHT_M - global_position).normalized()
	if absf(_yaw_offset) > 0.0001:
		direction = (Basis(Vector3.UP, _yaw_offset) * direction).normalized()
	# 真下を見るとき（上空で真上に来たとき）でも、向きが決まるようにする。
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.999 else forward
	look_at(global_position + direction, up)


## 一人称のときは、自分の体が視界をふさがないように、体だけ隠す。
func _set_own_body_visible(shown: bool) -> void:
	var body := _target.get_node_or_null("Body") as Node3D
	if body != null and body.visible != shown:
		body.visible = shown
