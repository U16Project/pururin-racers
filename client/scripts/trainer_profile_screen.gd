extends Control
## メニュー画面。左にトレーナーの登録、右にゲーム開始から終了までのボタン。
## 画像は、なし／用意してある人の絵／自分の画像ファイル、から選ぶ。
## 「ゲーム開始」で保存して遊び方の選択へ進む。「戻る」では、何も保存しない。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const CAMERA_EXPLORATION_SCENE_PATH := "res://scenes/camera_exploration.tscn"
const PAD_DIAGNOSTICS_SCENE_PATH := "res://scenes/pad_diagnostics.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const BUTTON_OPACITY := 0.92
const MENU_BUTTON_HEIGHT := 54.0
const SCREEN_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
const SCREEN_MODE_LABELS := ["通常ウィンドウ", "最大化", "全画面"]
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const PREVIEW_SIZE := 112.0
const CHOICE_SIZE := 62.0
const FILE_FILTERS := ["*.png, *.jpg, *.jpeg, *.webp ; 画像"]

var _name_edit: LineEdit
var _preview: Control
var _problem_label: Label
var _introduction_edit: TextEdit
var _introduction_count: Label
var _choice_buttons: Array[Button] = []
var _file_button: Button
var _game_start_button: Button
var _file_dialog: FileDialog
var _screen_mode_label: Label
var _screen_mode_index := -1
var _screen_mode_row: HBoxContainer
var _screen_direction_down := {"ui_left": false, "ui_right": false}
var _file_dialog_open := false
var _registering := false
## 選びかけの画像（登録するまでは、保存しない）。kind・id・path（file のときの、元のファイル）。
var _pending := {"kind": "none", "id": "", "path": ""}


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.45, 0.45, 0.5, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 16.0
	columns.offset_right = -16.0
	columns.offset_top = 12.0
	columns.offset_bottom = -12.0
	columns.add_theme_constant_override("separation", 16)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(columns)
	var panel := PanelContainer.new()
	panel.name = "TrainerPanel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 22.0, 14.0))
	panel.custom_minimum_size = Vector2(720.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := MenuStyle.label("トレーナー", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	# 上の段：左に今の画像、右に名前。
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	column.add_child(top)
	_preview = TrainerIcon.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	top.add_child(_preview)
	var name_box := VBoxContainer.new()
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 8)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_box)
	var rules := TrainerProfile.config()
	name_box.add_child(MenuStyle.label("トレーナー名（%d〜%d文字）" % [int(rules["name_min_length"]), int(rules["name_max_length"])], 18, MenuStyle.COLOR_DIM))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.text = TrainerProfile.trainer_name()
	_name_edit.max_length = int(rules["name_max_length"])
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.custom_minimum_size = Vector2(0.0, 52.0)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _game_start_button.grab_focus())
	name_box.add_child(_name_edit)
	_problem_label = MenuStyle.label("", 16, MenuStyle.COLOR_TAKEN)
	_problem_label.name = "ProblemLabel"
	name_box.add_child(_problem_label)
	# 画像の選択：なし、ぷるりんの絵、画像ファイル。
	# 紹介文（出走表の、トレーナーの所に出る）。
	var introduction_head := HBoxContainer.new()
	column.add_child(introduction_head)
	var introduction_title := MenuStyle.label("紹介文（%d文字まで）" % int(rules["introduction_max_length"]), 18, MenuStyle.COLOR_DIM)
	introduction_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	introduction_head.add_child(introduction_title)
	_introduction_count = MenuStyle.label("", 16, MenuStyle.COLOR_DIM)
	_introduction_count.name = "IntroductionCount"
	introduction_head.add_child(_introduction_count)
	_introduction_edit = TextEdit.new()
	_introduction_edit.name = "IntroductionEdit"
	_introduction_edit.text = TrainerProfile.introduction()
	_introduction_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_introduction_edit.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_introduction_edit.add_theme_font_size_override("font_size", 18)
	_introduction_edit.custom_minimum_size = Vector2(0.0, 72.0)
	_introduction_edit.text_changed.connect(_refresh_introduction_count)
	column.add_child(_introduction_edit)
	_refresh_introduction_count()
	column.add_child(MenuStyle.label("画像", 18, MenuStyle.COLOR_DIM))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	column.add_child(choices)
	choices.add_child(_choice_button("none", ""))
	for avatar: Dictionary in TrainerProfile.avatars():
		choices.add_child(_choice_button("avatar", str(avatar["id"])))
	_file_button = MenuStyle.button("画像ファイルを選ぶ…", 18, MenuStyle.COLOR_BUTTON_QUIET)
	_file_button.name = "FileButton"
	_file_button.pressed.connect(_open_file_dialog)
	UIAudio.bind_button_sound(_file_button, "confirmation")
	column.add_child(_file_button)
	_build_menu_column(columns)
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(FILE_FILTERS)
	_file_dialog.file_selected.connect(choose_file)
	_file_dialog.canceled.connect(func() -> void: _file_dialog_open = false)
	add_child(_file_dialog)
	# 登録してある画像から始める。
	var icon := TrainerProfile.icon()
	_pending = {"kind": str(icon["kind"]), "id": str(icon["id"]), "path": ""}
	_refresh_choices()
	_game_start_button.grab_focus()


## 画像の選択肢のボタン（なし、または、用意してある人の絵）。
func _choice_button(kind: String, id: String) -> Button:
	var button := Button.new()
	button.name = "Choice_%s%s" % [kind, ("_" + id) if not id.is_empty() else ""]
	button.custom_minimum_size = Vector2(CHOICE_SIZE, CHOICE_SIZE)
	MenuStyle.style_button(button, 14, MenuStyle.COLOR_BUTTON_QUIET)
	button.set_meta("kind", kind)
	button.set_meta("id", id)
	var icon: Control = TrainerIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5.0
	icon.offset_top = 5.0
	icon.offset_right = -5.0
	icon.offset_bottom = -5.0
	icon.call("show_icon", kind, id)
	button.add_child(icon)
	button.pressed.connect(choose_icon.bind(kind, id))
	UIAudio.bind_button_sound(button, "confirmation")
	_choice_buttons.append(button)
	return button


## 画像を選ぶ（なし、または、用意してある人の絵）。
func choose_icon(kind: String, id: String = "") -> void:
	_pending = {"kind": kind, "id": id, "path": ""}
	_refresh_choices()


## 画像ファイルを選ぶ。読めないファイルなら、理由を出して、選びかけの画像は変えない。
func choose_file(path: String) -> void:
	_file_dialog_open = false
	var image: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if image == null or image.is_empty():
		_problem_label.text = "画像を読めません"
		return
	_problem_label.text = ""
	_pending = {"kind": "file", "id": "", "path": path}
	_refresh_choices()
	_preview.call("show_icon", "file", "", ImageTexture.create_from_image(image))


func _open_file_dialog() -> void:
	_file_dialog_open = true
	_file_dialog.popup_centered_ratio(0.7)


## 選びかけの画像を、上の絵と、選択肢の印に反映する。
func _refresh_choices() -> void:
	for button in _choice_buttons:
		# 選んでいる画像のボタンは、緑にする（押しっぱなしの形にはしない。ゲームパッドのAでも、押した合図が出るように）。
		var selected := str(button.get_meta("kind")) == str(_pending["kind"]) and str(button.get_meta("id")) == str(_pending["id"])
		button.set_meta("selected", selected)
		MenuStyle.style_button(button, 14, MenuStyle.COLOR_BUTTON_ON if selected else MenuStyle.COLOR_BUTTON_QUIET)
	# 登録済みの画像ファイルを、そのまま使い続ける場合（選び直していない）は、登録してある絵を出す。
	if str(_pending["kind"]) == "file":
		_preview.call("show_icon", "file", "", TrainerProfile.icon_texture())
	else:
		_preview.call("show_icon", str(_pending["kind"]), str(_pending["id"]))


## 選びかけの画像（kind・id・path）。
func pending_icon() -> Dictionary:
	return _pending.duplicate()


## 名前と画像を保存して、遊び方の選択へ進む。名前が決まりに合わないときは、理由を出して、何も保存しない。
func register() -> void:
	if _registering or _file_dialog_open or _file_dialog.visible:
		return
	var problem := TrainerProfile.name_problem(_name_edit.text)
	if problem.is_empty():
		problem = TrainerProfile.introduction_problem(_introduction_edit.text)
	if problem.is_empty() and str(_pending["kind"]) == "file" and not str(_pending["path"]).is_empty():
		problem = TrainerProfile.set_icon_file(str(_pending["path"]))
	if not problem.is_empty():
		_problem_label.text = problem
		UIAudio.play_error()
		_name_edit.grab_focus()
		return
	TrainerProfile.set_trainer_name(_name_edit.text)
	TrainerProfile.set_introduction(_introduction_edit.text)
	_registering = true
	match str(_pending["kind"]):
		"none": TrainerProfile.clear_icon()
		"avatar": TrainerProfile.set_icon_avatar(str(_pending["id"]))
	UIAudio.play_confirmation()
	go_to_mode_select()


func go_to_mode_select() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if RaceControllerInput.is_menu_pressed(event):
		viewport.set_input_as_handled()
		register()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event) or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_to_title()


## 紹介文の、今の文字数を出す。決まりより長いときは、色を変える。
func _refresh_introduction_count() -> void:
	var limit := int(TrainerProfile.config()["introduction_max_length"])
	var length := TrainerProfile.clean_introduction(_introduction_edit.text).length()
	_introduction_count.text = "%d／%d" % [length, limit]
	_introduction_count.add_theme_color_override("font_color", MenuStyle.COLOR_TAKEN if length > limit else MenuStyle.COLOR_DIM)


func _build_menu_column(columns: HBoxContainer) -> void:
	var menu := VBoxContainer.new()
	menu.name = "MenuColumn"
	menu.custom_minimum_size = Vector2(364.0, 0.0)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 8)
	columns.add_child(menu)
	_game_start_button = _menu_button("ゲーム開始", "FreeRaceButton", Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_game_start_button.pressed.connect(register)
	MenuStyle.add_mark(_game_start_button, "START")
	menu.add_child(_game_start_button)
	var exploration := _menu_button("カメラで探検", "CameraExplorationButton", Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	exploration.pressed.connect(go_to_camera_exploration)
	UIAudio.bind_button_sound(exploration, "confirmation")
	menu.add_child(exploration)
	var diagnostics := _menu_button("ゲームパッド設定・入力確認", "PadDiagnosticsButton", MenuStyle.COLOR_BUTTON_QUIET)
	diagnostics.add_theme_font_size_override("font_size", 16)
	diagnostics.pressed.connect(go_to_pad_diagnostics)
	UIAudio.bind_button_sound(diagnostics, "confirmation")
	menu.add_child(diagnostics)
	_build_screen_mode_selector(menu)
	var quit_button := _menu_button("ゲームを終了", "QuitButton", Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	quit_button.pressed.connect(func(): get_tree().quit())
	UIAudio.bind_button_sound(quit_button, "confirmation")
	menu.add_child(quit_button)
	var back := _menu_button("戻る", "BackButton", MenuStyle.COLOR_BUTTON_QUIET)
	back.pressed.connect(go_to_title)
	UIAudio.bind_button_sound(back, "back")
	MenuStyle.add_mark(back, "B")
	menu.add_child(back)
	_game_start_button.focus_neighbor_bottom = _game_start_button.get_path_to(exploration)
	exploration.focus_neighbor_top = exploration.get_path_to(_game_start_button)
	exploration.focus_neighbor_bottom = exploration.get_path_to(diagnostics)
	diagnostics.focus_neighbor_top = diagnostics.get_path_to(exploration)
	diagnostics.focus_neighbor_bottom = diagnostics.get_path_to(_screen_mode_row)
	_screen_mode_row.focus_neighbor_top = _screen_mode_row.get_path_to(diagnostics)
	_screen_mode_row.focus_neighbor_bottom = _screen_mode_row.get_path_to(quit_button)
	quit_button.focus_neighbor_top = quit_button.get_path_to(_screen_mode_row)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(quit_button)


func _menu_button(text: String, node_name: String, color: Color) -> Button:
	var button := MenuStyle.button(text, 22, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(364.0, MENU_BUTTON_HEIGHT)
	return button


func go_to_camera_exploration() -> void:
	get_tree().change_scene_to_file(CAMERA_EXPLORATION_SCENE_PATH)


func go_to_pad_diagnostics() -> void:
	get_tree().change_scene_to_file(PAD_DIAGNOSTICS_SCENE_PATH)


func _build_screen_mode_selector(menu: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ScreenModeSelector"
	_screen_mode_row = row
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(364.0, 30.0)
	row.gui_input.connect(_screen_mode_gui_input)
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	row.focus_exited.connect(func(): _screen_direction_down = {"ui_left": false, "ui_right": false})
	row.draw.connect(func():
		if row.has_focus():
			row.draw_style_box(MenuStyle.focus_box(), Rect2(Vector2.ZERO, row.size))
	)
	row.add_theme_constant_override("separation", 4)
	menu.add_child(row)
	var caption := MenuStyle.label("ウィンドウサイズ", 14)
	caption.name = "ModeCaption"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousModeButton", -1))
	_screen_mode_label = MenuStyle.label("通常ウィンドウ", 14)
	_screen_mode_label.name = "ModeLabel"
	_screen_mode_label.custom_minimum_size.x = 140.0
	_screen_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_screen_mode_label)
	row.add_child(_screen_mode_button("▶", "NextModeButton", 1))
	_sync_screen_mode()


func _screen_mode_button(text: String, node_name: String, direction: int) -> Button:
	var button := MenuStyle.button(text, 14, Color(MenuStyle.COLOR_BUTTON_QUIET, BUTTON_OPACITY))
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36, 30)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func() -> void:
		var previous := _screen_mode_index
		_cycle_screen_mode(direction)
		if _screen_mode_index != previous:
			UIAudio.play_arrow_click())
	return button


func _screen_mode_gui_input(event: InputEvent) -> void:
	if not _screen_mode_row.has_focus():
		return
	for action in ["ui_left", "ui_right"]:
		if not event.is_action(action):
			continue
		var down := event.is_action_pressed(action, true, true)
		if down and not _screen_direction_down[action] and not event.is_echo():
			var previous := _screen_mode_index
			_cycle_screen_mode(-1 if action == "ui_left" else 1)
			var sound_key := screen_mode_sound_key(event is InputEventJoypadButton or event is InputEventJoypadMotion, _screen_mode_index != previous)
			if sound_key == "selection_cycle":
				UIAudio.play_selection_cycle()
		_screen_direction_down[action] = down
		_screen_mode_row.accept_event()


func _process(_delta: float) -> void:
	_sync_screen_mode()


func _sync_screen_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		return
	var index := screen_mode_index(mode)
	if index != _screen_mode_index:
		_screen_mode_index = index
		_screen_mode_label.text = SCREEN_MODE_LABELS[index]


static func screen_mode_index(mode: int) -> int:
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return 2
	var index := SCREEN_MODES.find(mode)
	return maxi(index, 0)


static func screen_mode_sound_key(is_gamepad: bool, changed: bool) -> String:
	return "selection_cycle" if is_gamepad and changed else ""


static func cycled_screen_mode(mode: int, direction: int) -> int:
	return SCREEN_MODES[posmod(screen_mode_index(mode) + direction, SCREEN_MODES.size())]


func _cycle_screen_mode(direction: int) -> void:
	DisplayServer.window_set_mode(cycled_screen_mode(DisplayServer.window_get_mode(), direction))
	_sync_screen_mode()

