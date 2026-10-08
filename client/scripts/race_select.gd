extends Control
## オフラインフリー対戦のレース選択画面。距離を選び、スロットにユーザーのぷるりんと対戦相手を入れて、レースを始める。
## 左が、枠番号（1〜8。動かない）とキャラスロット（ユーザー1つ＋CPU7つ。上下に動かして枠順を決める）。
## 右が、今見ているスロットの個体の詳細。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinSlot := preload("res://scripts/menu/pururin_slot.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const PururinPicker := preload("res://scripts/menu/pururin_picker.gd")
const ButtonMark := preload("res://scripts/menu/button_mark.gd")
const PANEL_SIZE := Vector2(880.0, 616.0)
const SLOT_COLUMN_WIDTH := 436.0
const GATE_BADGE_SIZE := 28.0
const DISTANCE_STEP_BUTTON_WIDTH := 70.0
const DISTANCE_MARK_SIZE := 20.0
const NOTE_MARK_SIZE := 18.0
const NOTE_ITEM_WIDTH := 190.0
## キャラの一覧の窓と、板の端との間。
const PICKER_MARGIN := 12.0
## 距離を動かすボタン（L1・R1）の色。茶色系。
const COLOR_STEP_BUTTON := Color(0.36, 0.23, 0.13, 1.0)
const COLOR_STEP_BUTTON_BORDER := Color(0.62, 0.43, 0.25, 1.0)
## レースを始められない理由の文。
const START_PROBLEM_TEXT := {
	"no_player": "ユーザーのぷるりんを選んでください",
	"no_opponent": "相手を1体以上選んでください",
}

var _distance_buttons: Array[Button] = []
var _slots: Array[Control] = []
var _detail: Control
var _order_button: Button
var _random_button: Button
var _clear_button: Button
## 他のスロットで使っているキャラを「見ているだけ」のスロットと、そのキャラ。無ければ -1 と空。
var _preview_slot := -1
var _preview_id := ""
## 右側の詳細に出しているスロット。
var _viewed_slot := 0
var _hint_label: Label
var _race_button: Button
var _back_button: Button
var _panel: PanelContainer
## キャラの一覧の窓と、窓が開いている間、後ろの部品を押せなくする覆い。
var _picker: Control
var _picker_cover: Control


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 背景は暗くして、選ぶ部分を読みやすくする。
	background.modulate = Color(0.38, 0.38, 0.44, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(Color(MenuStyle.COLOR_PANEL, 0.93), 16, 30.0, 14.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)
	_panel = panel
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := MenuStyle.label("オフラインフリー対戦", 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	content.add_child(_build_distance_row())
	var middle := HBoxContainer.new()
	middle.name = "Middle"
	middle.add_theme_constant_override("separation", 22)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(middle)
	middle.add_child(_build_slot_column())
	_detail = PururinDetail.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_detail)
	_hint_label = MenuStyle.label("", 16, MenuStyle.COLOR_FOCUS)
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.custom_minimum_size = Vector2(0.0, 22.0)
	content.add_child(_hint_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	content.add_child(buttons)
	_back_button = MenuStyle.button("タイトルへ戻る", 22, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(260.0, 56.0)
	_back_button.pressed.connect(go_to_title)
	MenuStyle.add_mark(_back_button, "B")
	buttons.add_child(_back_button)
	_race_button = MenuStyle.button("レース開始", 26)
	_race_button.name = "RaceButton"
	_race_button.custom_minimum_size = Vector2(0.0, 56.0)
	_race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_button.pressed.connect(go_to_race)
	MenuStyle.add_mark(_race_button, "START")
	buttons.add_child(_race_button)
	_detail.connect("force_requested", _on_force_requested)
	_build_picker()
	_viewed_slot = RaceSession.user_slot()
	_refresh_slots()
	_refresh_focus_links()
	_refresh_detail()
	# レースから戻ったときは、すぐ次のレースを始められるように、レース開始ボタンから。
	# タイトルから来たときは、一番上の、距離の段から。
	if RaceSession.take_returning_from_race() and RaceSession.race_start_problem().is_empty():
		_race_button.grab_focus()
	else:
		for button in _distance_buttons:
			if button.button_pressed:
				button.grab_focus()


## 距離は、横に並べたボタンから1つ選ぶ。左右で動かすと、そのまま選ばれる（Aを押さなくてよい）。
func _build_distance_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "DistanceRow"
	row.add_theme_constant_override("separation", 10)
	var caption := MenuStyle.label("距離", 20, MenuStyle.COLOR_DIM)
	caption.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(caption)
	row.add_child(_distance_step_button(-1))
	var group := ButtonGroup.new()
	var selected := RaceSession.selected_distance_m()
	for distance_m: float in RaceSession.supported_distances_m():
		var button := MenuStyle.button("%d m" % int(distance_m), 21, MenuStyle.COLOR_BUTTON_QUIET)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = is_equal_approx(distance_m, selected)
		button.focus_entered.connect(func() -> void: button.button_pressed = true)
		button.toggled.connect(_on_distance_toggled.bind(distance_m))
		row.add_child(button)
		_distance_buttons.append(button)
	row.add_child(_distance_step_button(1))
	return row


## 距離を1つ動かすボタン。左が「‹ L1」、右が「R1 ›」。ゲームパッドの L1・R1 で、どこを選んでいても動く。
## 距離のボタン（灰色の四角）と見分けがつくように、茶色の丸い形にする。矢印とマークは金色。
func _distance_step_button(direction: int) -> Button:
	var button := Button.new()
	button.text = "‹" if direction < 0 else "›"
	button.name = "DistancePrev" if direction < 0 else "DistanceNext"
	button.custom_minimum_size = Vector2(DISTANCE_STEP_BUTTON_WIDTH, 36.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, ButtonMark.COLOR_GOLD)
	button.add_theme_stylebox_override("normal", _step_button_box(COLOR_STEP_BUTTON, COLOR_STEP_BUTTON_BORDER))
	button.add_theme_stylebox_override("hover", _step_button_box(COLOR_STEP_BUTTON.lightened(0.12), COLOR_STEP_BUTTON_BORDER.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _step_button_box(COLOR_STEP_BUTTON.lightened(0.25), ButtonMark.COLOR_GOLD))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if direction < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var kind := "L1" if direction < 0 else "R1"
	var mark := MenuStyle.mark(kind, DISTANCE_MARK_SIZE)
	mark.name = "ButtonMark"
	button.add_child(mark)
	var mark_width := float(mark.custom_minimum_size.x)
	mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT if direction < 0 else Control.PRESET_CENTER_LEFT)
	mark.offset_left = -9.0 - mark_width if direction < 0 else 9.0
	mark.offset_right = mark.offset_left + mark_width
	mark.offset_top = -DISTANCE_MARK_SIZE * 0.5
	mark.offset_bottom = DISTANCE_MARK_SIZE * 0.5
	button.pressed.connect(step_distance.bind(direction))
	return button


static func _step_button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(18)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 4.0
	return box


## 距離を、1つ前（-1）か次（1）へ動かす。端では止まる。
func step_distance(direction: int) -> void:
	var index := 0
	for position in _distance_buttons.size():
		if _distance_buttons[position].button_pressed:
			index = position
	var next := clampi(index + direction, 0, _distance_buttons.size() - 1)
	_distance_buttons[next].button_pressed = true
	# 距離の段を選んでいるときは、選択の枠も、動かした先の距離へ付いていく
	# （枠だけ元の距離に残ると、そのあとの左右が、ずれた場所から動いてしまう）。
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and _distance_buttons.has(focused as Button):
		_distance_buttons[next].grab_focus()


## 左側：枠番号の札（動かない）とキャラスロットを8行、その下にボタンの説明2行と、ボタン3つ。
func _build_slot_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "SlotColumn"
	column.custom_minimum_size = Vector2(SLOT_COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 3)
	for slot in RaceSession.SLOT_COUNT:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		column.add_child(line)
		var badge: Control = GateBadge.new()
		badge.call("setup", slot, GATE_BADGE_SIZE)
		line.add_child(badge)
		var row: Control = PururinSlot.new()
		row.call("setup", slot)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.connect("cycle_requested", _on_slot_cycle_requested)
		row.connect("slot_focused", _on_slot_focused)
		row.connect("slot_unfocused", _on_slot_unfocused)
		row.connect("clear_requested", _on_slot_clear_requested)
		row.connect("force_requested", _on_slot_force_requested)
		row.connect("lock_requested", _on_slot_lock_requested)
		row.connect("move_requested", _on_slot_move_requested)
		row.connect("pick_requested", _on_slot_pick_requested)
		line.add_child(row)
		_slots.append(row)
	column.add_child(_note_row("ButtonNote1", [[["A"], "一覧から選ぶ"], [["X"], "選択解除"]]))
	column.add_child(_note_row("ButtonNote2", [[["SELECT"], "施錠・解錠"], [["L2", "R2"], "枠を上下へ"]]))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	column.add_child(buttons)
	_order_button = _column_button("OrderButton", "枠順ランダム", _on_order_random_pressed)
	_random_button = _column_button("RandomButton", "キャラ選択ランダム", _on_random_pressed)
	_clear_button = _column_button("ClearButton", "キャラ選択全解除", _on_clear_all_pressed)
	for button: Button in [_order_button, _random_button, _clear_button]:
		buttons.add_child(button)
	return column


## ボタンの説明の1行。items は [マークの種類の並び, 説明] の並び。
func _note_row(row_name: String, items: Array) -> HBoxContainer:
	var note := HBoxContainer.new()
	note.name = row_name
	note.add_theme_constant_override("separation", 5)
	note.custom_minimum_size = Vector2(0.0, 22.0)
	for item: Array in items:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		group.custom_minimum_size = Vector2(NOTE_ITEM_WIDTH, 0.0)
		for kind: String in item[0]:
			group.add_child(MenuStyle.mark(kind, NOTE_MARK_SIZE))
		group.add_child(MenuStyle.label(str(item[1]), 14, MenuStyle.COLOR_DIM))
		note.add_child(group)
	return note


func _column_button(button_name: String, text: String, handler: Callable) -> Button:
	var button := MenuStyle.button(text, 13, MenuStyle.COLOR_BUTTON_QUIET)
	button.name = button_name
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var compact: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		compact.content_margin_left = 6.0
		compact.content_margin_right = 6.0
		button.add_theme_stylebox_override(state, compact)
	button.pressed.connect(handler)
	return button


## 使っているスロットの呼び名（例「3枠」）。
static func slot_tag(slot: int) -> String:
	return "%d枠" % (slot + 1)


## 上下左右で移るときの行き先を、全部の部品について、はっきり決める
## （決めておかないと、Godotが位置から自動で選び、距離の段で左を押すとスロットへ飛ぶ、などが起きる）。
## 距離の段へ入るときは、今選ばれている距離のボタンへ移す（移っただけで、別の距離に変わらないように）。
func _refresh_focus_links() -> void:
	var selected_distance: Button = _distance_buttons[0]
	for button in _distance_buttons:
		if button.button_pressed:
			selected_distance = button
	for index in _distance_buttons.size():
		_link(_distance_buttons[index], {
			"left": _distance_buttons[maxi(index - 1, 0)],
			"right": _distance_buttons[mini(index + 1, _distance_buttons.size() - 1)],
			"top": _distance_buttons[index],
			"bottom": _slots[0],
		})
	for slot in _slots.size():
		_link(_slots[slot], {
			"left": _slots[slot],
			"right": _slots[slot],
			"top": selected_distance if slot == 0 else _slots[slot - 1],
			"bottom": _random_button if slot == _slots.size() - 1 else _slots[slot + 1],
		})
	var column_buttons: Array[Button] = [_order_button, _random_button, _clear_button]
	for index in column_buttons.size():
		_link(column_buttons[index], {
			"left": column_buttons[maxi(index - 1, 0)],
			"right": column_buttons[mini(index + 1, column_buttons.size() - 1)],
			"top": _slots[_slots.size() - 1],
			"bottom": _race_button,
		})
	_link(_back_button, {"left": _back_button, "right": _race_button, "top": _order_button, "bottom": _back_button})
	_link(_race_button, {"left": _back_button, "right": _race_button, "top": _random_button, "bottom": _race_button})


## 1つの部品の、上下左右の行き先を決める。
static func _link(node: Control, neighbors: Dictionary) -> void:
	node.focus_neighbor_left = node.get_path_to(neighbors["left"])
	node.focus_neighbor_right = node.get_path_to(neighbors["right"])
	node.focus_neighbor_top = node.get_path_to(neighbors["top"])
	node.focus_neighbor_bottom = node.get_path_to(neighbors["bottom"])


## スロットの表示と、レースを始められるかどうかを、今の選択に合わせる。
func _refresh_slots() -> void:
	for slot in _slots.size():
		var taken := slot == _preview_slot
		var identifier := _preview_id if taken else RaceSession.slot_pururin_id(slot)
		_slots[slot].call("set_pururin", PururinRosterConfig.pururin_by_id(identifier) if identifier != RaceSession.EMPTY else {}, taken)
		_slots[slot].call("set_role", RaceSession.is_user_slot(slot))
		_slots[slot].call("set_locked", RaceSession.is_locked(slot))
	var problem := RaceSession.race_start_problem()
	_race_button.disabled = not problem.is_empty()
	_hint_label.text = str(START_PROBLEM_TEXT[problem]) if not problem.is_empty() else ""


## 右側の詳細を、今見ているスロットに合わせる。「見ているだけ」のキャラなら、誰が使っているかも出す。
func _refresh_detail() -> void:
	if _viewed_slot == _preview_slot:
		var holder := RaceSession.slot_holding(_preview_id)
		_detail.call("show_pururin", _preview_id, slot_tag(holder), RaceSession.is_locked(holder))
	else:
		_detail.call("show_pururin", RaceSession.slot_pururin_id(_viewed_slot))


## ゲームパッドは、Aで決定、Bで戻る、STARTでレース開始、L1・R1で距離
## （Godotの標準では、ゲームパッドのボタンは「決定」「戻る」に割り当てられていない）。
func _unhandled_input(event: InputEvent) -> void:
	if _picker.call("is_open"):
		# 一覧の窓が開いている間は、窓の操作だけ（決定と閉じる）。後ろの操作は受け付けない。
		if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
			get_viewport().set_input_as_handled()
			_picker.call("close")
		elif RaceControllerInput.is_accept_pressed(event):
			var picker_viewport := get_viewport()
			if RaceControllerInput.activate_focused_control(picker_viewport):
				picker_viewport.set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		get_viewport().set_input_as_handled()
		go_to_title()
	elif RaceControllerInput.is_menu_pressed(event):
		get_viewport().set_input_as_handled()
		go_to_race()
	elif RaceControllerInput.distance_step(event) != 0:
		get_viewport().set_input_as_handled()
		step_distance(RaceControllerInput.distance_step(event))
	elif RaceControllerInput.is_accept_pressed(event):
		# ボタンを押すと場面が変わることがあるので、画面は先に取っておく。
		var viewport := get_viewport()
		if RaceControllerInput.activate_focused_control(viewport):
			viewport.set_input_as_handled()


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func go_to_race() -> void:
	if RaceSession.race_start_problem().is_empty():
		get_tree().change_scene_to_file(RACE_SCENE_PATH)


func _on_distance_toggled(pressed: bool, distance_m: float) -> void:
	if pressed:
		RaceSession.select_distance(distance_m)
		_refresh_focus_links()


## 左右：次（前）のキャラを出す。どのスロットも使っていなければ、そのキャラで決まり。
## 他のスロットが使っていれば、このスロットは空のまま、「選択済み」として見せるだけにする。
func _on_slot_cycle_requested(slot: int, direction: int) -> void:
	if RaceSession.is_locked(slot):
		return
	var candidate := RaceSession.cycle_candidate(str(_slots[slot].call("pururin_id")), direction)
	var holder := RaceSession.slot_holding(candidate)
	if holder >= 0 and holder != slot:
		RaceSession.set_slot(slot, RaceSession.EMPTY)
		_preview_slot = slot
		_preview_id = candidate
	else:
		RaceSession.set_slot(slot, candidate)
		_clear_preview()
	_viewed_slot = slot
	_refresh_slots()
	_refresh_detail()


func _clear_preview() -> void:
	_preview_slot = -1
	_preview_id = ""


func _on_slot_focused(slot: int) -> void:
	_viewed_slot = slot
	_refresh_detail()


## 「見ているだけ」のキャラを出したまま、別の場所へ移ったら、そのスロットは未選択に戻す。
func _on_slot_unfocused(slot: int) -> void:
	if slot == _preview_slot and is_inside_tree():
		_clear_preview()
		_refresh_slots()
		_refresh_detail()


## X：そのスロットを未選択にする。
func _on_slot_clear_requested(slot: int) -> void:
	if RaceSession.is_locked(slot):
		return
	RaceSession.set_slot(slot, RaceSession.EMPTY)
	if slot == _preview_slot:
		_clear_preview()
	_refresh_slots()
	_refresh_detail()


## Y：「見ているだけ」のキャラを、先に使っていたスロットから奪う。
func _on_slot_force_requested(slot: int) -> void:
	if slot != _preview_slot:
		return
	# 先に使っているスロットが施錠中なら、奪えない（表示はそのまま）。
	if not RaceSession.take_slot(slot, _preview_id):
		return
	_clear_preview()
	_refresh_slots()
	_refresh_detail()


func _on_force_requested() -> void:
	if _picker.call("is_open"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_method("pururin_id"):
			_on_picker_force_requested(str(focused.call("pururin_id")))
		return
	_on_slot_force_requested(_preview_slot)


## キャラの一覧の窓を作る（最初は閉じている）。窓の後ろに、板の左側を押せなくする覆いを置く。
func _build_picker() -> void:
	_picker_cover = Control.new()
	_picker_cover.name = "PickerCover"
	_picker_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_cover.visible = false
	add_child(_picker_cover)
	_picker = PururinPicker.new()
	_picker.name = "Picker"
	add_child(_picker)
	_picker.connect("picked", _on_picker_picked)
	_picker.connect("force_requested", _on_picker_force_requested)
	_picker.connect("tile_focused", _on_picker_tile_focused)
	_picker.connect("closed", _on_picker_closed)


## スロットで決定：キャラの一覧の窓を開く。施錠中のスロットでは開かない。
func _on_slot_pick_requested(slot: int) -> void:
	if RaceSession.is_locked(slot):
		return
	_clear_preview()
	_refresh_slots()
	_viewed_slot = slot
	# 窓は、板の左側に重ねる。右側の詳細パネルは隠さない。
	var panel_rect := _panel.get_global_rect()
	var detail_left := _detail.get_global_rect().position.x
	var left := panel_rect.position.x + PICKER_MARGIN
	_picker.global_position = Vector2(left, panel_rect.position.y + PICKER_MARGIN)
	_picker.size = Vector2(minf(float(PururinPicker.window_width()), detail_left - PICKER_MARGIN - left), panel_rect.size.y - PICKER_MARGIN * 2.0)
	# 覆いは、板の左側（詳細パネルより左）だけ。詳細パネルの「強制選択」は押せるままにする。
	_picker_cover.global_position = Vector2.ZERO
	_picker_cover.size = Vector2(detail_left, get_viewport_rect().size.y)
	_picker_cover.visible = true
	_picker.call("open", slot, "%s（%s）のキャラを選ぶ" % [slot_tag(slot), PururinSlot.USER_TAG if RaceSession.is_user_slot(slot) else PururinSlot.CPU_TAG])


## 窓で決定：そのキャラ（空なら未選択）をスロットに入れて、閉じる。
func _on_picker_picked(pururin_id: String) -> void:
	RaceSession.set_slot(int(_picker.call("slot")), pururin_id)
	_picker.call("close")


## 窓で強制選択：先に使っていたスロットを空にして、このスロットに入れて、閉じる。施錠中なら、何もしない。
func _on_picker_force_requested(pururin_id: String) -> void:
	if RaceSession.take_slot(int(_picker.call("slot")), pururin_id):
		_picker.call("close")


## 窓のカーソルが動いた：右側の詳細を、そのキャラに変える。他のスロットが使っていれば、その表示も出す。
func _on_picker_tile_focused(pururin_id: String) -> void:
	var holder := RaceSession.slot_holding(pururin_id)
	if holder >= 0 and holder != int(_picker.call("slot")):
		_detail.call("show_pururin", pururin_id, slot_tag(holder), RaceSession.is_locked(holder))
	else:
		_detail.call("show_pururin", pururin_id)


## 窓が閉じた：選択の枠を元のスロットに戻し、表示を今の選択に合わせる。
func _on_picker_closed() -> void:
	_picker_cover.visible = false
	_refresh_slots()
	_slots[_viewed_slot].grab_focus()
	_refresh_detail()


## SELECT：施錠・解錠を切り替える。
func _on_slot_lock_requested(slot: int) -> void:
	RaceSession.toggle_lock(slot)
	_refresh_slots()
	_refresh_detail()


## L2・R2：スロットを上（下）の枠のスロットと入れ替える。選択の枠は、動かしたスロットに付いていく。
func _on_slot_move_requested(slot: int, direction: int) -> void:
	var target := RaceSession.move_slot(slot, direction)
	if target == slot:
		return
	# 「見ているだけ」のキャラを出したまま枠を動かしたら、未選択に戻す（別のスロットへ移ったときと同じ）。
	_clear_preview()
	_viewed_slot = target
	_refresh_slots()
	_slots[target].grab_focus()
	_refresh_detail()


func _on_order_random_pressed() -> void:
	RaceSession.shuffle_gate_order()
	_clear_preview()
	_refresh_slots()
	_refresh_detail()


func _on_random_pressed() -> void:
	RaceSession.randomize_unlocked()
	_clear_preview()
	_refresh_slots()
	_refresh_detail()


func _on_clear_all_pressed() -> void:
	RaceSession.clear_unlocked()
	_clear_preview()
	_refresh_slots()
	_refresh_detail()
