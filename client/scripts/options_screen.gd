extends Control
## オプション設定。画質・画面モード・操作ガイド。トレーナー画面の次、ゲームモード選択の前。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const MENU_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const ControlGuide := preload("res://scripts/presentation/control_guide.gd")
const PartsSettings := preload("res://scripts/online/online_parts_settings.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const SCREEN_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
const SCREEN_MODE_LABELS := ["通常ウィンドウ", "最大化", "全画面"]
const PANEL_WIDTH := 620.0
const PANEL_HEIGHT := 430.0
## 「次へ」の下の余白と、オプションの行・操作ガイドのボタンの高さ（そろえる）。
const NEXT_GAP := 16.0
const ROW_HEIGHT := 46.0
## ◀ と ▶ の幅（36×2）と、値とのすき間（4×2）。
const ARROWS_WIDTH := 80.0
## 画質の説明の字の大きさ。
const NOTE_FONT_SIZE := 14
## オプションの板と板のあいだ。
const CARD_GAP := 8
## 相手の自作部品の行の値（オフ・オン）。
const PARTS_LABELS := ["表示する", "表示しない"]
## 操作ガイドのボタンに出す、ゲームパッドの絵（Phosphor Icons。白い絵を、ボタンの字と同じ色にして出す）。
const PAD_ICON_PATH := "res://assets/ui/icon_gamepad.svg"
const PAD_ICON_SIZE := 30.0
const BUTTON_HEIGHT := 68.0

var _guide_button: Button
var _next_button: Button
var _back_button: Button
var _guide_overlay: Control
## 下の帯の「←→ 変える」（オプションの行にいるときだけ出す）。
var _change_hint: Label
var _screen_mode_label: Label
var _screen_mode_index := -1
var _screen_mode_row: HBoxContainer
var _screen_direction_down := {"ui_left": false, "ui_right": false}
var _quality_button: HBoxContainer
var _quality_label: Label
var _quality_note: Label
var _parts_label: Label
## ◀ 値 ▶ の幅。画質の説明（長いほう）が1行で入る幅に合わせる。説明はこの幅の中央に置く。
var _selector_width := 0.0
## 画質の説明。軽量＝観客席・町・遠くの景色と、太陽の影を出さない（コースと柵だけ）。
const QUALITY_NOTE_STANDARD := "観客席・町並み・影まで、すべて表示。"
const QUALITY_NOTE_LIGHT := "コースと柵だけ、影なし。ノートPCなどで重いときに。"
var _quality_direction_down := {"ui_left": false, "ui_right": false}


func _ready() -> void:
	_selector_width = _note_width()
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "オプション設定", TrainerProfile.trainer_name())
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(28.0, 22.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = -PANEL_HEIGHT * 0.5
	panel.offset_bottom = PANEL_HEIGHT * 0.5
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	# 1. いちばんよく押す「次へ」を、いちばん上に。
	_next_button = MenuStyle.pill_button("次へ（ゲームモード選択）", "primary", 26)
	_next_button.name = "NextButton"
	_next_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_next_button.pressed.connect(go_to_mode_select)
	UIAudio.bind_button_sound(_next_button, "confirmation")
	MenuStyle.add_mark(_next_button, "START")
	column.add_child(_next_button)
	# 2. この画面の主役：オプション（画質・ウィンドウサイズ）。
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, NEXT_GAP)
	column.add_child(gap)
	column.add_child(MenuStyle.section_title("オプション", 17))
	# 3つのオプションは、1行ずつ同じ形の板に乗せる（左に名前、右に「◀ 値 ▶」）。
	var options := VBoxContainer.new()
	options.name = "OptionCards"
	options.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(options)
	_build_quality_selector(options)
	_build_screen_mode_selector(options)
	var parts_row: Control = _build_parts_selector(options)
	# 3. 操作ガイドは、いちばん下に、小さな入口だけ。
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	# 画質・ウィンドウサイズの行と同じ幅・高さで、左にゲームパッドの絵。
	_guide_button = MenuStyle.pill_button("操作ガイドを見る", "secondary", 17)
	_guide_button.name = "ControlGuideButton"
	_guide_button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var pad_icon := TextureRect.new()
	pad_icon.name = "PadIcon"
	pad_icon.texture = load(PAD_ICON_PATH)
	pad_icon.modulate = MenuStyle.COLOR_ACCENT
	pad_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pad_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pad_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pad_icon.offset_left = 22.0
	pad_icon.offset_right = 22.0 + PAD_ICON_SIZE
	pad_icon.offset_top = (ROW_HEIGHT - PAD_ICON_SIZE) * 0.5
	pad_icon.offset_bottom = -(ROW_HEIGHT - PAD_ICON_SIZE) * 0.5
	_guide_button.add_child(pad_icon)
	_guide_button.pressed.connect(_open_control_guide)
	UIAudio.bind_button_sound(_guide_button, "confirmation")
	column.add_child(_guide_button)
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	_back_button = MenuStyle.guide_button(guide, "B", "戻る")
	_back_button.name = "BackButton"
	_back_button.pressed.connect(go_to_menu)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.guide_item(guide, "START", "次へ")
	_change_hint = MenuStyle.label("←→　変える", 16, MenuStyle.COLOR_BAR_DIM)
	_change_hint.add_theme_constant_override("outline_size", 0)
	_change_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_change_hint.visible = false
	guide.add_child(_change_hint)
	_next_button.focus_neighbor_top = _next_button.get_path_to(_next_button)
	_next_button.focus_neighbor_bottom = _next_button.get_path_to(_quality_button)
	_quality_button.focus_neighbor_top = _quality_button.get_path_to(_next_button)
	_quality_button.focus_neighbor_bottom = _quality_button.get_path_to(_screen_mode_row)
	_screen_mode_row.focus_neighbor_top = _screen_mode_row.get_path_to(_quality_button)
	_screen_mode_row.focus_neighbor_bottom = _screen_mode_row.get_path_to(parts_row)
	parts_row.focus_neighbor_top = parts_row.get_path_to(_screen_mode_row)
	parts_row.focus_neighbor_bottom = parts_row.get_path_to(_guide_button)
	_guide_button.focus_neighbor_top = _guide_button.get_path_to(parts_row)
	_guide_button.focus_neighbor_bottom = _guide_button.get_path_to(_guide_button)
	# オプションの行にいるときだけ、下の帯に「←→ 変える」を出す。
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		_change_hint.visible = control in [_quality_button, _screen_mode_row, parts_row])
	_next_button.grab_focus()


func step_quality() -> void:
	RaceSession.set_course_only(not RaceSession.is_course_only())
	_update_quality_text()


func _update_quality_text() -> void:
	_quality_label.text = "軽量" if RaceSession.is_course_only() else "標準"
	if _quality_note != null:
		_quality_note.text = QUALITY_NOTE_LIGHT if RaceSession.is_course_only() else QUALITY_NOTE_STANDARD


func _quality_input(event: InputEvent) -> void:
	if not _quality_button.has_focus():
		return
	for action in ["ui_left", "ui_right"]:
		if event.is_action(action):
			var down := event.is_action_pressed(action, true, true)
			if down and not _quality_direction_down[action] and not event.is_echo():
				step_quality()
				UIAudio.play_selection_cycle()
			_quality_direction_down[action] = down
			_quality_button.accept_event()


func _build_quality_selector(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "QualityButton"
	_quality_button = row
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(364, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 4)
	row.gui_input.connect(_quality_input)
	row.focus_exited.connect(func(): _quality_direction_down = {"ui_left": false, "ui_right": false})
	# 画質の板には、行の下に、今の画質で何が変わるか（いつ選ぶとよいか）を小さく入れる。
	var card := _option_card(column, row)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 0)
	card.add_child(inside)
	inside.add_child(row)
	# 説明は、値（標準・軽量）の真下に、中央そろえで置く。
	var note_line := HBoxContainer.new()
	note_line.name = "QualityNoteLine"
	note_line.add_theme_constant_override("separation", 4)
	inside.add_child(note_line)
	var under_caption := Control.new()
	under_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_line.add_child(under_caption)
	_quality_note = MenuStyle.label("", NOTE_FONT_SIZE, MenuStyle.COLOR_DIM)
	_quality_note.name = "QualityNote"
	_quality_note.custom_minimum_size.x = _selector_width
	_quality_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_line.add_child(_quality_note)
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size.y = 8.0
	inside.add_child(bottom_gap)
	var caption := MenuStyle.label("画質", 17, MenuStyle.COLOR_TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousQualityButton", -1, true))
	_quality_label = MenuStyle.bold_label("", 19)
	_quality_label.name = "QualityLabel"
	_quality_label.custom_minimum_size.x = _selector_width - ARROWS_WIDTH
	_quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_quality_label)
	row.add_child(_screen_mode_button("▶", "NextQualityButton", 1, true))
	_update_quality_text()


func go_to_mode_select() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _open_control_guide() -> void:
	if is_instance_valid(_guide_overlay):
		return
	var guide := ControlGuide.new()
	_guide_overlay = guide
	add_child(guide)
	guide.closed.connect(_on_control_guide_closed)


func _on_control_guide_closed() -> void:
	_guide_overlay = null
	if is_instance_valid(_guide_button):
		_guide_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if is_instance_valid(_guide_overlay):
		if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
			viewport.set_input_as_handled()
		return
	if RaceControllerInput.is_menu_pressed(event):
		# 「次へ」に付けた START の目印のとおり、Start で次へ進む。
		viewport.set_input_as_handled()
		RaceControllerInput.activate_control(_next_button)
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_to_menu()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()


func _build_screen_mode_selector(menu: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ScreenModeSelector"
	_screen_mode_row = row
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(364.0, ROW_HEIGHT)
	row.gui_input.connect(_screen_mode_gui_input)
	row.focus_exited.connect(func(): _screen_direction_down = {"ui_left": false, "ui_right": false})
	row.add_theme_constant_override("separation", 4)
	_option_card(menu, row).add_child(row)
	var caption := MenuStyle.label("ウィンドウサイズ", 17, MenuStyle.COLOR_TEXT)
	caption.name = "ModeCaption"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousModeButton", -1))
	_screen_mode_label = MenuStyle.bold_label("通常ウィンドウ", 19)
	_screen_mode_label.name = "ModeLabel"
	_screen_mode_label.custom_minimum_size.x = _selector_width - ARROWS_WIDTH
	_screen_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_screen_mode_label)
	row.add_child(_screen_mode_button("▶", "NextModeButton", 1))
	_sync_screen_mode()


func _screen_mode_button(text: String, node_name: String, direction: int, quality: bool = false, on_press: Callable = Callable()) -> Button:
	# 矢印は箱なしの小さな印だけ。押せる広さは保ち、乗せると白く光る。
	var button := Button.new()
	button.text = text
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36, 34)
	button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", MenuStyle.COLOR_ACCENT)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, MenuStyle.COLOR_TEXT)
	button.pressed.connect(func() -> void:
		if on_press.is_valid():
			on_press.call()
			UIAudio.play_arrow_click()
			return
		if quality:
			step_quality()
			UIAudio.play_arrow_click()
			return
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



# オプション1つぶんの板。カーソルが乗ると、板そのものが黄色い枠に変わる。
func _option_card(parent: Control, focus_owner: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = str(focus_owner.name) + "Card"
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	plain.set_corner_radius_all(10)
	var focused := MenuStyle.focus_box()
	for style: StyleBox in [plain, focused]:
		style.content_margin_left = 16.0
		style.content_margin_right = 6.0
		style.content_margin_top = 0.0
		style.content_margin_bottom = 0.0
	card.add_theme_stylebox_override("panel", plain)
	focus_owner.focus_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", focused))
	focus_owner.focus_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", plain))
	parent.add_child(card)
	return card


# 相手の自作部品：ほかの2つと同じ「◀ 値 ▶」の行。←→ で切り替わる。
func _build_parts_selector(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "HideRemoteParts"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 4)
	_option_card(parent, row).add_child(row)
	var caption := MenuStyle.label("相手の自作部品", 17, MenuStyle.COLOR_TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousPartsButton", -1, false, flip_hide_remote_parts))
	_parts_label = MenuStyle.bold_label("", 19)
	_parts_label.name = "PartsLabel"
	_parts_label.custom_minimum_size.x = _selector_width - ARROWS_WIDTH
	_parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_parts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_parts_label)
	row.add_child(_screen_mode_button("▶", "NextPartsButton", 1, false, flip_hide_remote_parts))
	_update_parts_text()
	row.gui_input.connect(func(event: InputEvent) -> void:
		for action in ["ui_left", "ui_right"]:
			if event.is_action_pressed(action, false, true):
				flip_hide_remote_parts()
				UIAudio.play_selection_cycle()
				row.accept_event())
	return row


func flip_hide_remote_parts() -> void:
	PartsSettings.set_hidden(not PartsSettings.hidden())
	_update_parts_text()


func _update_parts_text() -> void:
	_parts_label.text = PARTS_LABELS[int(PartsSettings.hidden())]


func _note_width() -> float:
	var probe := MenuStyle.label("", NOTE_FONT_SIZE, MenuStyle.COLOR_DIM)
	var font := probe.get_theme_font("font")
	var widest := 0.0
	for text in [QUALITY_NOTE_STANDARD, QUALITY_NOTE_LIGHT]:
		widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_FONT_SIZE).x)
	probe.free()
	return ceilf(widest) + 8.0
