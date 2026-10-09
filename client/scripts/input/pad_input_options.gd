extends Node
## 機種別補正。raw入力は残し、ゲームとGUIには標準配置のイベントを渡す。
const PROFILE_PATH := "res://data/config/pad_profiles.json"
const SAVE_PATH := "user://pad_input_options.json"
const SYNTHETIC_DEVICE := 15
var synthetic_device := SYNTHETIC_DEVICE
var profiles: Array = []
var selections: Dictionary = {}
var diagnostic_mode := false
var buttons: Dictionary = {}
var axes: Dictionary = {}
var raw_buttons: Dictionary = {}
var raw_axes: Dictionary = {}
var active_device := -1
var active_profile: Dictionary = {}
var generation := 0

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if data is Dictionary and data.get("schema_version") == 1:
		profiles = data.get("profiles", [])
	else:
		push_error("ゲームパッド対応表を読み込めません。")
	load_options()
	Input.joy_connection_changed.connect(_connection_changed)
	refresh_active()

func load_options(path: String = SAVE_PATH) -> void:
	selections.clear()
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("schema_version") == 1 and data.get("selections") is Dictionary:
		selections = data.selections

func save_options(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema_version": 1, "selections": selections}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func matching_profiles(guid: String, platform: String = OS.get_name()) -> Array:
	return profiles.filter(func(profile): return profile.guid == guid and profile.os == platform)

func profile_for(guid: String, platform: String = OS.get_name()) -> Dictionary:
	var chosen := str(selections.get(guid, "standard"))
	for profile in matching_profiles(guid, platform):
		if profile.id == chosen:
			return profile
	return {}

func select_profile(guid: String, profile_id: String) -> Error:
	var valid := profile_id == "standard"
	for profile in matching_profiles(guid):
		valid = valid or profile.id == profile_id
	if not valid:
		return ERR_INVALID_PARAMETER
	var before := selections.duplicate(true)
	selections[guid] = profile_id
	var error := save_options()
	if error != OK:
		selections = before
		return error
	refresh_active()
	return OK

func _connection_changed(_device: int, _connected: bool) -> void:
	refresh_active()

func refresh_active() -> void:
	clear_state()
	active_device = -1
	active_profile = {}
	var connected := Input.get_connected_joypads()
	synthetic_device = -1
	for candidate in range(15, 0, -1):
		if candidate not in connected:
			synthetic_device = candidate
			break
	# ゲーム本体の既存device0を維持。別IDのパッドは他機種へ誤適用しない。
	if 0 in connected and synthetic_device >= 0:
		active_device = 0
		active_profile = profile_for(Input.get_joy_guid(0))
		if correction_enabled():
			for button in range(21):
				raw_buttons[button] = Input.is_joy_button_pressed(0, button)
			for axis in range(10):
				raw_axes[axis] = Input.get_joy_axis(0, axis)
			var snapshot := InputEventJoypadButton.new()
			snapshot.button_index = 20
			for converted in convert_event(snapshot, active_profile):
				_send_event.call_deferred(converted, generation)

func clear_state() -> void:
	generation += 1
	buttons.clear()
	axes.clear()
	raw_buttons.clear()
	raw_axes.clear()
	# GUIの仮想入力も解除。設定変更や抜き差しで押しっぱなしを残さない。
	if synthetic_device < 0 or synthetic_device in Input.get_connected_joypads():
		return
	for button in range(21):
		var event := InputEventJoypadButton.new()
		event.device = synthetic_device
		event.button_index = button
		event.pressed = false
		event.set_meta("pad_corrected", true)
		Input.parse_input_event(event)
	for axis in range(6):
		var event := InputEventJoypadMotion.new()
		event.device = synthetic_device
		event.axis = axis
		event.axis_value = 0.0
		event.set_meta("pad_corrected", true)
		Input.parse_input_event(event)

func set_diagnostic_mode(enabled: bool) -> void:
	diagnostic_mode = enabled
	clear_state()

func correction_enabled() -> bool:
	return not diagnostic_mode and not active_profile.is_empty()

func button_down(button: int) -> bool:
	return bool(buttons.get(button, false)) if correction_enabled() else Input.is_joy_button_pressed(0, button)

func axis_value(axis: int) -> float:
	return float(axes.get(axis, 0.0)) if correction_enabled() else Input.get_joy_axis(0, axis)

func _input(event: InputEvent) -> void:
	if event.has_meta("pad_corrected") or not correction_enabled():
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or event.device != active_device:
		return
	get_viewport().set_input_as_handled()
	for converted in convert_event(event, active_profile):
		_send_event.call_deferred(converted, generation)

func _send_event(event: InputEvent, expected_generation: int) -> void:
	if expected_generation == generation and correction_enabled():
		Input.parse_input_event(event)

## 純粋な対応表変換＋状態。SDLの軸番号ではなく診断したGodotイベントに合わせる。
func convert_event(event: InputEvent, profile: Dictionary) -> Array:
	if event is InputEventJoypadButton:
		raw_buttons[event.button_index] = event.pressed
	elif event is InputEventJoypadMotion:
		raw_axes[event.axis] = event.axis_value
	else:
		return []
	var result: Array = []
	for target in profile.buttons:
		var value := bool(raw_buttons.get(int(profile.buttons[target]), false))
		_append_button(result, int(target), value)
	for target in profile.axes:
		var source: Dictionary = profile.axes[target]
		var value := 0.0
		if source.has("axis"):
			value = float(raw_axes.get(int(source.axis), 0.0))
		elif source.has("button"):
			value = float(bool(raw_buttons.get(int(source.button), false)))
		else:
			value = float(bool(raw_buttons.get(int(source.positive_button), false))) - float(bool(raw_buttons.get(int(source.negative_button), false)))
		if not is_equal_approx(value, float(axes.get(int(target), 0.0))):
			axes[int(target)] = value
			var converted := InputEventJoypadMotion.new()
			converted.axis = int(target)
			converted.axis_value = value
			_mark(converted)
			result.append(converted)
	for source in profile.dpad_axes:
		var value := float(raw_axes.get(int(source), 0.0))
		_append_button(result, int(profile.dpad_axes[source][0]), value < -0.5)
		_append_button(result, int(profile.dpad_axes[source][1]), value > 0.5)
	return result

func _append_button(result: Array, target: int, value: bool) -> void:
	if value == bool(buttons.get(target, false)):
		return
	buttons[target] = value
	var converted := InputEventJoypadButton.new()
	converted.button_index = target
	converted.pressed = value
	_mark(converted)
	result.append(converted)

func _mark(event: InputEvent) -> void:
	event.device = synthetic_device
	event.set_meta("pad_corrected", true)
