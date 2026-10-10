extends Node
## 共通UI音声。フォーカス移動と、画面側から明示されたUI操作を鳴らす。

const CLICK_SOUND_PATH := "res://assets/audio/ui/click1.ogg"
const SWITCH26_SOUND_PATH := "res://assets/audio/ui/switch26.ogg"
const CLICK3_SOUND_PATH := "res://assets/audio/ui/click3.ogg"
const BACK_SOUND_PATH := "res://assets/audio/ui/back_003.ogg"
const CONFIRMATION_SOUND_PATH := "res://assets/audio/ui/confirmation_002.ogg"
const CLEAR_SELECTION_SOUND_PATH := "res://assets/audio/ui/select_006.ogg"
const CHECKBOX_SOUND_PATH := "res://assets/audio/ui/switch_001.ogg"
const NOTCH_UP_SOUND_PATH := "res://assets/audio/ui/switch_002.ogg"
const NOTCH_DOWN_SOUND_PATH := "res://assets/audio/ui/switch_003.ogg"
const ERROR_SOUND_PATH := "res://assets/audio/ui/error_001.ogg"
const NAVIGATION_ACTIONS := ["ui_left", "ui_right", "ui_up", "ui_down"]
const SOUND_PATHS := {
	"focus_move": CLICK_SOUND_PATH,
	"selection_cycle": SWITCH26_SOUND_PATH,
	"arrow_click": CLICK3_SOUND_PATH,
	"back": BACK_SOUND_PATH,
	"confirmation": CONFIRMATION_SOUND_PATH,
	"clear_selection": CLEAR_SELECTION_SOUND_PATH,
	"checkbox_toggle": CHECKBOX_SOUND_PATH,
	"notch_up": NOTCH_UP_SOUND_PATH,
	"notch_down": NOTCH_DOWN_SOUND_PATH,
	"error": ERROR_SOUND_PATH,
}

var _players: Dictionary = {}


func _ready() -> void:
	for key: String in SOUND_PATHS:
		var player := AudioStreamPlayer.new()
		player.name = "%sPlayer" % key.capitalize()
		player.stream = load(str(SOUND_PATHS[key])) as AudioStream
		if player.stream == null:
			push_error("UI音声を読み込めません: %s" % SOUND_PATHS[key])
		_players[key] = player
		add_child(player)


func _input(event: InputEvent) -> void:
	if not _is_gamepad_navigation_event(event):
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	for action in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action, false, true):
			call_deferred("_play_if_focus_changed", previous_focus)
			return


func _is_gamepad_navigation_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	if event.has_meta("pad_corrected"):
		return true
	var pad_options := get_node_or_null("/root/PadInputOptions")
	return pad_options == null or not pad_options.correction_enabled()


func _play_if_focus_changed(previous_focus) -> void:
	var current_focus := get_viewport().gui_get_focus_owner()
	if not should_play_focus_move(previous_focus, current_focus):
		return
	if previous_focus is Control and str(previous_focus.get_meta("ui_audio_focus_sound", "")).is_empty() == false:
		_play_sound(str(previous_focus.get_meta("ui_audio_focus_sound")))
		return
	_play_focus_click()


func _play_focus_click() -> void:
	_play_sound("focus_move")


func play_selection_cycle() -> void:
	_play_sound("selection_cycle")


func play_arrow_click() -> void:
	_play_sound("arrow_click")


func play_back() -> void:
	_play_sound("back")


func play_confirmation() -> void:
	_play_sound("confirmation")


func play_clear_selection() -> void:
	_play_sound("clear_selection")


func play_checkbox_toggle() -> void:
	_play_sound("checkbox_toggle")


func play_notch_up() -> void:
	_play_sound("notch_up")


func play_notch_down() -> void:
	_play_sound("notch_down")


func play_error() -> void:
	_play_sound("error")


## マウス押下は gui_input で先に鳴らし、キーボード／ゲームパッドは pressed で鳴らす。
## これで1回のボタン操作を、入力経路ごとに二重再生しない。
func bind_button_sound(button: BaseButton, key: String) -> void:
	button.set_meta("ui_audio_mouse_pending", false)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button.set_meta("ui_audio_mouse_pending", true)
			_play_sound(key))
	button.pressed.connect(func() -> void:
		if bool(button.get_meta("ui_audio_mouse_pending")):
			button.set_meta("ui_audio_mouse_pending", false)
		else:
			_play_sound(key))


## 無効化されているボタンをクリックしたときだけ、失敗音を鳴らす。
func bind_disabled_button_error(button: BaseButton) -> void:
	button.gui_input.connect(func(event: InputEvent) -> void:
		if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			play_error())


func _play_sound(key: String) -> void:
	var player := _players.get(key) as AudioStreamPlayer
	if player != null and player.stream != null:
		player.play()


func should_play_focus_move(previous_focus, current_focus) -> bool:
	return is_instance_valid(previous_focus) and is_instance_valid(current_focus) and previous_focus != current_focus
