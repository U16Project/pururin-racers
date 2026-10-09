extends Control
## 診断中のゲームパッド入力は GUI に渡さず、マウス・キーボードで操作する。
const Record := preload("res://scripts/input/pad_diagnostic_record.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const BUTTON_NAMES := ["A", "B", "X", "Y", "BACK", "GUIDE", "START", "左押込", "右押込", "L1", "R1", "十字上", "十字下", "十字左", "十字右", "MISC1", "PADDLE1", "PADDLE2", "PADDLE3", "PADDLE4", "TOUCHPAD"]
var record := Record.new()
var _device_picker: OptionButton
var _identity: Label
var _state: Label
var _guide: Label
var _result: Label
var _metadata: Dictionary = {}
var _profile_picker: OptionButton
var _profile_status: Label
var _profile_ids: Array[String] = []

func _ready() -> void:
	PadInputOptions.set_diagnostic_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.04, 0.07, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 16
	scroll.offset_right = -24
	scroll.offset_bottom = -16
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	column.add_child(MenuStyle.label("ゲームパッド設定・入力確認", 28))
	column.add_child(MenuStyle.label("MODEは固定。操作はマウス／キーボード。戻る：Esc／B\n設定は保存され、タイトルへ戻ると適用します。下の診断は補正前の入力です。", 18))
	_device_picker = OptionButton.new()
	_device_picker.item_selected.connect(_select_device)
	column.add_child(_device_picker)
	_identity = MenuStyle.label("", 16)
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_identity)
	_profile_picker = OptionButton.new()
	_profile_picker.item_selected.connect(_profile_selected)
	column.add_child(_profile_picker)
	_profile_status = MenuStyle.label("", 18)
	_profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_profile_status)
	_state = MenuStyle.label("", 16)
	column.add_child(_state)
	_guide = MenuStyle.label("", 18)
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_guide)
	var row := HFlowContainer.new()
	column.add_child(row)
	_add_button(row, "記録を始める", _start)
	_add_button(row, "この操作を採取", _arm)
	_add_button(row, "これで確定／次へ", _confirm)
	_add_button(row, "ない／反応なし", _skip)
	_add_button(row, "JSONを保存", _save)
	_add_button(row, "タイトルへ戻る", _back)
	_result = MenuStyle.label("", 16)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_result)
	Input.joy_connection_changed.connect(_connection_changed)
	_refresh_devices()

func _add_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := MenuStyle.button(caption, 18)
	button.pressed.connect(callback)
	parent.add_child(button)

func _refresh_devices() -> void:
	_device_picker.clear()
	for id in Input.get_connected_joypads():
		_device_picker.add_item("%s（ID %d）" % [Input.get_joy_name(id), id], id)
	if _device_picker.item_count == 0:
		record.select_device(-1)
		_metadata.clear()
		_identity.text = "ゲームパッドが接続されていません。"
		_profile_picker.disabled = true
		_profile_status.text = "接続後に設定を選べます。"
	else:
		var index := _device_picker.get_item_index(record.device)
		if index < 0:
			_select_device(0)
		else:
			_device_picker.select(index)

func _select_device(index: int) -> void:
	var id := _device_picker.get_item_id(index)
	record.select_device(id)
	for axis in range(10):
		record.axes[axis] = Input.get_joy_axis(id, axis)
	for button in range(21):
		record.buttons[button] = Input.is_joy_button_pressed(id, button)
	_metadata = {"name": Input.get_joy_name(id), "guid": Input.get_joy_guid(id), "known": Input.is_joy_known(id), "info": Input.get_joy_info(id)}
	_identity.text = "名前：%s\nGUID：%s　known：%s\ninfo：%s" % [_metadata.name, _metadata.guid, _metadata.known, JSON.stringify(_metadata.info)]
	_device_picker.select(index)
	_refresh_profiles()
	if is_instance_valid(_result):
		_result.text = "対象を変更しました。記録を始める前に全操作を離してください。"

func _connection_changed(id: int, connected: bool) -> void:
	if not connected and id == record.device:
		record.disconnect_device(id)
		_identity.text += "\n対象が切断されました。記録は中断しました。"
		_profile_picker.disabled = true
		_profile_status.text = "対象が切断されました。再接続して選択してください。"
		# 残った別パッドへ自動で記録を移さない。
		_device_picker.clear()
		for other in Input.get_connected_joypads():
			_device_picker.add_item("%s（ID %d）" % [Input.get_joy_name(other), other], other)
		return
	_refresh_devices()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and not record.armed:
			_back()
		else:
			record.record(event)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()

func _process(_delta: float) -> void:
	var lines := PackedStringArray()
	for start in [0, 7, 14]:
		var parts := PackedStringArray()
		for button in range(start, start + 7):
			parts.append("%02d %s:%s" % [button, BUTTON_NAMES[button], "●" if record.buttons.get(button, false) else "・"])
		lines.append("   ".join(parts))
	for start in [0, 5]:
		var parts := PackedStringArray()
		for axis in range(start, start + 5):
			parts.append("軸%d: %+.3f" % [axis, record.axes.get(axis, 0.0)])
		lines.append("   ".join(parts))
	lines.append("直近入力：%s" % (JSON.stringify(record.events.back()) if not record.events.is_empty() else "なし"))
	_state.text = "\n".join(lines)
	if not record.connected:
		_guide.text = "対象を接続し、選択してください。"
	elif record.step < 0:
		_guide.text = "全ボタンを離し、スティックを中央に戻して『記録を始める』。\n各操作で『この操作を採取』→指定操作→内容を確認→『これで確定／次へ』。"
	elif record.step >= Record.STEPS.size():
		_guide.text = "全操作の確認が完了しました。JSONを保存してください。"
	else:
		var status := "操作を離して元に戻し、『この操作を採取』を押してください。"
		if record.armed:
			status = "指定の操作を1つだけ行ってください。"
		elif not record.candidate.is_empty():
			status = "採取：%s\n正しい操作なら確定。違う場合は元に戻して再採取。" % JSON.stringify(record.candidate)
		_guide.text = "%d / %d：%s\n%s" % [record.step + 1, Record.STEPS.size(), Record.STEPS[record.step], status]

func _start() -> void:
	_result.text = "記録を開始しました。MODEを変えずに進めてください。" if record.start_guide() else "対象を接続し、ボタンを離してください。"

func _arm() -> void:
	_result.text = "採取待ちです。" if record.arm() else "全操作を離して開始時の位置に戻してください。"

func _confirm() -> void:
	_result.text = "確定しました。操作を元に戻してください。" if record.confirm() else "先に指定の操作を採取してください。"

func _skip() -> void:
	record.skip()

func _save() -> void:
	var directory := "user://pad_diagnostics"
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		_result.text = "保存先を作成できませんでした：%s" % error_string(error)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/%s-%d.json" % [directory, stamp, Time.get_ticks_usec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_result.text = "保存できませんでした：%s" % error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"schema_version": 1, "input_layer": "Godot joypad events (mapped when known)", "godot": Engine.get_version_info(), "os": OS.get_name(), "device_id": record.device, "connected": record.connected, "device": _metadata, "mode_instruction": "MODE fixed during recording", "rest_axes": record.baseline, "guide_samples": record.samples, "recent_events": record.events}, "\t"))
	file.close()
	_result.text = "保存しました：\n%s" % ProjectSettings.globalize_path(path)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _exit_tree() -> void:
	PadInputOptions.set_diagnostic_mode(false)
	PadInputOptions.refresh_active()

func _refresh_profiles() -> void:
	_profile_picker.clear()
	_profile_picker.disabled = false
	_profile_ids.assign(["standard"])
	_profile_picker.add_item("標準配置")
	var available := PadInputOptions.matching_profiles(str(_metadata.guid))
	for profile in available:
		_profile_ids.append(str(profile.id))
		_profile_picker.add_item(str(profile.label))
	var current := str(PadInputOptions.selections.get(_metadata.guid, "standard"))
	var index := _profile_ids.find(current)
	_profile_picker.select(maxi(index, 0))
	if _profile_picker.selected == 0:
		_profile_status.text = "標準配置を使用します。" + ("この機種の補正は未登録です。必要なら下で入力を記録してください。" if available.is_empty() else "配置が合わなければ機種別補正を選べます。")
	else:
		_profile_status.text = available[_profile_picker.selected - 1].warning
	if record.device != 0:
		_profile_status.text += "\n現在ゲーム本体が操作に使うのはID 0です。"

func _profile_selected(index: int) -> void:
	var error := PadInputOptions.select_profile(str(_metadata.guid), _profile_ids[index])
	_refresh_profiles()
	if error != OK:
		_profile_status.text = "設定を保存できませんでした：%s" % error_string(error)
	else:
		_profile_status.text += "\n保存しました。タイトルへ戻ると適用します。"
