extends Control
## プロフィール登録画面。名前・ひとこと（紹介文）・アイコンを登録し、オプション設定へ進む。
## 画像は、なし／用意してある人の絵／自分の画像ファイル、から選ぶ。
## 「次へ」で保存してオプション設定へ進む。「戻る」では、何も保存しない。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const OPTIONS_SCENE_PATH := "res://scenes/options.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const BUTTON_OPACITY := 0.92
const MENU_BUTTON_HEIGHT := 54.0
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
var _file_dialog_open := false
var _registering := false
var _choices: GridContainer
var _delete_button: Button
var _delete_dialog: Control
var _delete_id := ""
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
	var heading := MenuStyle.label("プロフィール登録", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var note := MenuStyle.label("あなたの名前・ひとこと・アイコンを登録します。部屋や出走表で、ほかのプレイヤーにも表示されます。", 14, MenuStyle.COLOR_DIM)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
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
	name_box.add_child(MenuStyle.label("名前（%d〜%d文字）" % [int(rules["name_min_length"]), int(rules["name_max_length"])], 18, MenuStyle.COLOR_DIM))
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
	var introduction_title := MenuStyle.label("ひとこと（%d文字まで）" % int(rules["introduction_max_length"]), 18, MenuStyle.COLOR_DIM)
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
	_introduction_edit.custom_minimum_size = Vector2(0.0, 60.0)
	_introduction_edit.text_changed.connect(_refresh_introduction_count)
	column.add_child(_introduction_edit)
	_refresh_introduction_count()
	column.add_child(MenuStyle.label("アイコン", 18, MenuStyle.COLOR_DIM))
	var choice_scroll := ScrollContainer.new()
	choice_scroll.custom_minimum_size.y = CHOICE_SIZE * 2 + 12
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(choice_scroll)
	_choices = GridContainer.new()
	_choices.name = "IconChoices"
	_choices.columns = 8
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 8)
	choice_scroll.add_child(_choices)
	var migrated := TrainerProfile.preserve_registered_icon()
	if migrated.has("error"):
		_problem_label.text = str(migrated["error"])
	_rebuild_choices()
	_file_button = MenuStyle.button("画像ファイルを選ぶ…", 18, MenuStyle.COLOR_BUTTON_QUIET)
	_file_button.name = "FileButton"
	_file_button.pressed.connect(_open_file_dialog)
	UIAudio.bind_button_sound(_file_button, "confirmation")
	column.add_child(_file_button)
	_delete_button = MenuStyle.button("選択した追加画像を削除", 18, MenuStyle.COLOR_BUTTON_QUIET)
	_delete_button.name = "DeleteIconButton"
	_delete_button.pressed.connect(request_delete_icon)
	column.add_child(_delete_button)
	_file_button.focus_neighbor_bottom = _file_button.get_path_to(_delete_button)
	_delete_button.focus_neighbor_top = _delete_button.get_path_to(_file_button)
	_build_menu_column(columns)
	_build_delete_dialog()
	_rebuild_choices()
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
	icon.call("show_icon", kind, id, TrainerProfile.custom_icon_texture(id) if kind == "file" else null)
	button.add_child(icon)
	button.pressed.connect(choose_icon.bind(kind, id))
	UIAudio.bind_button_sound(button, "confirmation")
	_choice_buttons.append(button)
	return button


## 画像を選ぶ（なし、または、用意してある人の絵）。
func choose_icon(kind: String, id: String = "") -> void:
	_pending = {"kind": kind, "id": id, "path": TrainerProfile.custom_icon_path(id) if kind == "file" else ""}
	_refresh_choices()


## 画像ファイルを選ぶ。読めないファイルなら、理由を出して、選びかけの画像は変えない。
func choose_file(path: String) -> void:
	_file_dialog_open = false
	var imported := TrainerProfile.import_custom_icon(path)
	if imported.has("error"):
		_problem_label.text = str(imported["error"])
		return
	_problem_label.text = ""
	_rebuild_choices()
	choose_icon("file", str(imported["id"]))
	_focus_pending_icon()


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
		var texture := TrainerProfile.custom_icon_texture(str(_pending["id"]))
		_preview.call("show_icon", "file", "", texture if texture != null else TrainerProfile.icon_texture())
	else:
		_preview.call("show_icon", str(_pending["kind"]), str(_pending["id"]))
	if is_instance_valid(_delete_button):
		_delete_button.disabled = str(_pending["kind"]) != "file" or TrainerProfile.custom_icon_texture(str(_pending["id"])) == null


## 選びかけの画像（kind・id・path）。
func pending_icon() -> Dictionary:
	return _pending.duplicate()


## 名前・ひとこと・アイコンを保存して、オプション設定へ進む。名前が決まりに合わないときは、理由を出して、何も保存しない。
func register() -> void:
	if _registering or _file_dialog_open or _file_dialog.visible or _delete_dialog.visible:
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
	go_to_options()


func go_to_options() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE_PATH)


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if _delete_dialog.visible:
		if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
			_close_delete_dialog()
		elif RaceControllerInput.is_accept_pressed(event):
			RaceControllerInput.activate_focused_control(viewport)
		viewport.set_input_as_handled()
		return
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
	_game_start_button = _menu_button("次へ", "FreeRaceButton", Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_game_start_button.pressed.connect(register)
	MenuStyle.add_mark(_game_start_button, "START")
	menu.add_child(_game_start_button)
	var back := _menu_button("戻る", "BackButton", MenuStyle.COLOR_BUTTON_QUIET)
	back.pressed.connect(go_to_title)
	UIAudio.bind_button_sound(back, "back")
	MenuStyle.add_mark(back, "B")
	menu.add_child(back)
	_game_start_button.focus_neighbor_bottom = _game_start_button.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(_game_start_button)

func _menu_button(text: String, node_name: String, color: Color) -> Button:
	var button := MenuStyle.button(text, 22, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(364.0, MENU_BUTTON_HEIGHT)
	return button


func _rebuild_choices() -> void:
	for child in _choices.get_children():
		child.free()
	_choice_buttons.clear()
	_choices.add_child(_choice_button("none", ""))
	for avatar: Dictionary in TrainerProfile.avatars():
		_choices.add_child(_choice_button("avatar", str(avatar["id"])))
	for entry: Dictionary in TrainerProfile.custom_icons():
		_choices.add_child(_choice_button("file", str(entry["id"])))
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		button.focus_neighbor_left = button.get_path_to(_choice_buttons[maxi(index - 1, 0)])
		button.focus_neighbor_right = button.get_path_to(_choice_buttons[mini(index + 1, _choice_buttons.size() - 1)])
		if index >= _choices.columns:
			button.focus_neighbor_top = button.get_path_to(_choice_buttons[index - _choices.columns])
		if index + _choices.columns < _choice_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(_choice_buttons[index + _choices.columns])
		elif is_instance_valid(_file_button):
			button.focus_neighbor_bottom = button.get_path_to(_file_button)


func _focus_pending_icon() -> void:
	for button in _choice_buttons:
		if bool(button.get_meta("selected", false)):
			button.grab_focus()
			return


func _build_delete_dialog() -> void:
	var shade := ColorRect.new()
	shade.name = "DeleteIconDialog"
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.hide()
	add_child(shade)
	_delete_dialog = shade
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(MenuStyle.label("この追加画像を一覧から削除しますか？\n元の画像ファイルは削除しません。", 20))
	var confirm := MenuStyle.button("削除する", 20)
	confirm.name = "ConfirmDeleteIconButton"
	confirm.pressed.connect(_confirm_delete_icon)
	column.add_child(confirm)
	var cancel := MenuStyle.button("やめる", 20, MenuStyle.COLOR_BUTTON_QUIET)
	cancel.name = "CancelDeleteIconButton"
	cancel.pressed.connect(_close_delete_dialog)
	MenuStyle.add_mark(cancel, "B")
	column.add_child(cancel)
	for button in [confirm, cancel]:
		button.focus_neighbor_top = button.get_path_to(cancel if button == confirm else confirm)
		button.focus_neighbor_bottom = button.focus_neighbor_top
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_next = button.get_path_to(cancel if button == confirm else confirm)
		button.focus_previous = button.focus_next


func request_delete_icon() -> void:
	if _delete_button.disabled:
		return
	UIAudio.play_confirmation()
	_delete_id = str(_pending["id"])
	_delete_dialog.show()
	_delete_dialog.find_child("CancelDeleteIconButton", true, false).grab_focus()


func _close_delete_dialog(play_sound: bool = true) -> void:
	if play_sound:
		UIAudio.play_back()
	_delete_dialog.hide()
	_delete_id = ""
	_focus_pending_icon()


func _confirm_delete_icon() -> void:
	if not _delete_dialog.visible or _delete_id.is_empty():
		return
	var problem := TrainerProfile.delete_custom_icon(_delete_id)
	if not problem.is_empty():
		_problem_label.text = problem
		_close_delete_dialog(false)
		UIAudio.play_error()
		return
	UIAudio.play_clear_selection()
	_delete_dialog.hide()
	_delete_id = ""
	_pending = {"kind": "none", "id": "", "path": ""}
	_rebuild_choices()
	_refresh_choices()
	_focus_pending_icon()
