extends Control
## プロフィール登録画面。名前・ひとこと（紹介文）・アイコンを登録し、オプション設定へ進む。
## 画像は、なし／用意してある人の絵／自分の画像ファイル、から選ぶ。
## 「次へ」で保存してオプション設定へ進む。「戻る」では、何も保存しない。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const OPTIONS_SCENE_PATH := "res://scenes/options.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MENU_BUTTON_HEIGHT := 54.0
## 上下の帯と、中の箱とのすき間。
const CONTENT_GAP := 20.0
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const PREVIEW_SIZE := 112.0
const CHOICE_SIZE := 62.0
## アイコンの一覧の、横に並べる数と、見せる段の数（それより多いと、下へスクロール）。
const CHOICE_COLUMNS := 6
const CHOICE_ROWS_SHOWN := 3
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
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "プロフィール登録", TrainerProfile.trainer_name())
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = MenuStyle.SCREEN_MARGIN
	columns.offset_right = -MenuStyle.SCREEN_MARGIN
	columns.offset_top = MenuStyle.BAR_HEIGHT + CONTENT_GAP
	columns.offset_bottom = -MenuStyle.GUIDE_HEIGHT - CONTENT_GAP
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)
	# 左の箱：名前・ひとこと。
	var panel := PanelContainer.new()
	panel.name = "TrainerPanel"
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(MenuStyle.section_title("あなたのプロフィール"))
	var note := MenuStyle.label("あなたの名前・ひとこと・アイコンを登録します。部屋や出走表で、ほかのプレイヤーにも表示されます。", 14, MenuStyle.COLOR_BAR_DIM)
	note.name = "Note"
	note.add_theme_constant_override("outline_size", 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	name_box.add_child(_caption("名前（%d〜%d文字）" % [int(rules["name_min_length"]), int(rules["name_max_length"])]))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.text = TrainerProfile.trainer_name()
	_name_edit.max_length = int(rules["name_max_length"])
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.custom_minimum_size = Vector2(0.0, 52.0)
	_style_edit(_name_edit)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _game_start_button.grab_focus())
	name_box.add_child(_name_edit)
	_problem_label = MenuStyle.label("", 16, MenuStyle.COLOR_TAKEN)
	_problem_label.name = "ProblemLabel"
	name_box.add_child(_problem_label)
	# 紹介文（出走表の、トレーナーの所に出る）。
	var introduction_head := HBoxContainer.new()
	column.add_child(introduction_head)
	var introduction_title := _caption("ひとこと（%d文字まで）" % int(rules["introduction_max_length"]))
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
	_introduction_edit.custom_minimum_size = Vector2(0.0, 84.0)
	_style_edit(_introduction_edit)
	_introduction_edit.text_changed.connect(_refresh_introduction_count)
	column.add_child(_introduction_edit)
	_refresh_introduction_count()
	# 右の箱：アイコン、その下に「次へ」。
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.add_theme_stylebox_override("panel", MenuStyle.panel_box())
	icon_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(icon_panel)
	var icon_column := VBoxContainer.new()
	icon_column.add_theme_constant_override("separation", 10)
	icon_panel.add_child(icon_column)
	icon_column.add_child(MenuStyle.section_title("アイコン"))
	var choice_scroll := ScrollContainer.new()
	choice_scroll.custom_minimum_size.y = CHOICE_SIZE * CHOICE_ROWS_SHOWN + 8 * (CHOICE_ROWS_SHOWN - 1)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	icon_column.add_child(choice_scroll)
	_choices = GridContainer.new()
	_choices.name = "IconChoices"
	_choices.columns = CHOICE_COLUMNS
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 8)
	choice_scroll.add_child(_choices)
	var migrated := TrainerProfile.preserve_registered_icon()
	if migrated.has("error"):
		_problem_label.text = str(migrated["error"])
	_rebuild_choices()
	var file_row := HBoxContainer.new()
	file_row.add_theme_constant_override("separation", 10)
	icon_column.add_child(file_row)
	_file_button = MenuStyle.pill_button("画像ファイルを選ぶ…", "secondary", 15)
	_file_button.name = "FileButton"
	_file_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_button.pressed.connect(_open_file_dialog)
	UIAudio.bind_button_sound(_file_button, "confirmation")
	file_row.add_child(_file_button)
	_delete_button = MenuStyle.pill_button("選んだ追加画像を削除", "quiet", 15)
	_delete_button.name = "DeleteIconButton"
	_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_button.pressed.connect(request_delete_icon)
	file_row.add_child(_delete_button)
	_file_button.focus_neighbor_right = _file_button.get_path_to(_delete_button)
	_delete_button.focus_neighbor_left = _delete_button.get_path_to(_file_button)
	_build_menu_column(icon_column)
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
	_style_choice(button, false)
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


## アイコンの選択肢の見た目。選んでいるものは、水色の縁と地。
func _style_choice(button: Button, selected: bool) -> void:
	MenuStyle.style_card_button(button)
	if selected:
		var on := MenuStyle.card_box(Color(MenuStyle.COLOR_ACCENT, 0.3), MenuStyle.COLOR_ACCENT, 12)
		on.set_border_width_all(3)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, on)


## 選びかけの画像を、上の絵と、選択肢の印に反映する。
func _refresh_choices() -> void:
	for button in _choice_buttons:
		# 選んでいる画像のボタンは、緑にする（押しっぱなしの形にはしない。ゲームパッドのAでも、押した合図が出るように）。
		var selected := str(button.get_meta("kind")) == str(_pending["kind"]) and str(button.get_meta("id")) == str(_pending["id"])
		button.set_meta("selected", selected)
		_style_choice(button, selected)
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


## 右の箱のいちばん下に「次へ」（黄色）。「戻る」は、下の帯（B）。
func _build_menu_column(icon_column: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_column.add_child(spacer)
	var menu := VBoxContainer.new()
	menu.name = "MenuColumn"
	icon_column.add_child(menu)
	_game_start_button = MenuStyle.pill_button("次へ", "primary", 22)
	_game_start_button.name = "FreeRaceButton"
	_game_start_button.custom_minimum_size = Vector2(0.0, MENU_BUTTON_HEIGHT)
	_game_start_button.pressed.connect(register)
	MenuStyle.add_mark(_game_start_button, "START")
	menu.add_child(_game_start_button)
	for button: Button in [_file_button, _delete_button]:
		button.focus_neighbor_bottom = button.get_path_to(_game_start_button)
	_game_start_button.focus_neighbor_top = _game_start_button.get_path_to(_file_button)
	_game_start_button.focus_neighbor_bottom = _game_start_button.get_path_to(_game_start_button)
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	var back := MenuStyle.guide_button(guide, "B", "戻る")
	back.name = "BackButton"
	back.pressed.connect(go_to_title)
	UIAudio.bind_button_sound(back, "back")
	MenuStyle.guide_item(guide, "START", "次へ")


## 小さな見出し（「名前」など）。
func _caption(text: String) -> Label:
	var node := MenuStyle.label(text, 15, MenuStyle.COLOR_BAR_DIM)
	node.add_theme_constant_override("outline_size", 0)
	return node


## 入力らんを、箱と同じ暗い地と水色の縁にする。
func _style_edit(edit: Control) -> void:
	var normal := MenuStyle.card_box(Color(0.03, 0.05, 0.1, 0.7), MenuStyle.COLOR_CARD_BORDER, 10)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	edit.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = MenuStyle.COLOR_FOCUS
	focus.set_border_width_all(3)
	edit.add_theme_stylebox_override("focus", focus)


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
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(26.0, 20.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(MenuStyle.label("この追加画像を一覧から削除しますか？\n元の画像ファイルは削除しません。", 20))
	var confirm := MenuStyle.pill_button("削除する", "secondary", 20)
	confirm.name = "ConfirmDeleteIconButton"
	confirm.pressed.connect(_confirm_delete_icon)
	column.add_child(confirm)
	var cancel := MenuStyle.pill_button("やめる", "quiet", 20)
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
