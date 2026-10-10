extends Control
## トレーナーの画面。ゲーム開始のあとに出る。登録してあるユーザーの名前と画像を出し、変えることもできる。
## 画像は、なし／用意してある人の絵／自分の画像ファイル、から選ぶ。「OK」を押すと、保存して、レース選択へ進む。
## 「戻る」では、何も保存しない。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const PANEL_SIZE := Vector2(760.0, 620.0)
const PREVIEW_SIZE := 132.0
const CHOICE_SIZE := 62.0
const FILE_FILTERS := ["*.png, *.jpg, *.jpeg, *.webp ; 画像"]

var _name_edit: LineEdit
var _preview: Control
var _problem_label: Label
var _introduction_edit: TextEdit
var _introduction_count: Label
var _choice_buttons: Array[Button] = []
var _file_button: Button
var _register_button: Button
var _back_button: Button
var _file_dialog: FileDialog
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
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 30.0, 22.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
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
	_name_edit.text_submitted.connect(func(_text: String) -> void: _register_button.grab_focus())
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
	_introduction_edit.custom_minimum_size = Vector2(0.0, 84.0)
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
	column.add_child(_file_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_back_button = MenuStyle.button("戻る", 22, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(220.0, 58.0)
	_back_button.pressed.connect(go_to_title)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	buttons.add_child(_back_button)
	_register_button = MenuStyle.button("OK（レース選択へ）", 22)
	_register_button.name = "RegisterButton"
	_register_button.custom_minimum_size = Vector2(0.0, 58.0)
	_register_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_button.pressed.connect(register)
	MenuStyle.add_mark(_register_button, "START")
	buttons.add_child(_register_button)
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
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()


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


## 名前と画像を保存して、レース選択へ進む。名前が決まりに合わないときは、理由を出して、何も保存しない。
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
		_name_edit.grab_focus()
		return
	TrainerProfile.set_trainer_name(_name_edit.text)
	TrainerProfile.set_introduction(_introduction_edit.text)
	_registering = true
	match str(_pending["kind"]):
		"none": TrainerProfile.clear_icon()
		"avatar": TrainerProfile.set_icon_avatar(str(_pending["id"]))
	UIAudio.play_confirmation()
	go_to_race_select()


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_SCENE_PATH)


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

