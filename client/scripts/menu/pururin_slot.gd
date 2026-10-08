extends Control
## キャラ選択のスロット1行。札（ユーザー／CPU）、◀、小さい画像、名前、▶、南京錠。
## 左右（キー・十字キー・スティック・◀▶のクリック）で中の個体を切り替える依頼、Xで未選択、Yで強制選択、
## SELECTで施錠・解錠、L2・R2で枠の移動、決定（A）でキャラの一覧を開く依頼を出す。何が入っているかは、画面側が set_* で渡す。

signal cycle_requested(slot: int, direction: int)
signal slot_focused(slot: int)
signal slot_unfocused(slot: int)
signal clear_requested(slot: int)
signal force_requested(slot: int)
signal lock_requested(slot: int)
signal move_requested(slot: int, direction: int)
## 決定（A・Enter・クリック）。キャラの一覧の窓を開く依頼。
signal pick_requested(slot: int)

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const FitLabel := preload("res://scripts/menu/fit_label.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const EMPTY_TEXT := "ー未選択ー"
const TAKEN_TEXT := "選択済み"
const USER_TAG := "ユーザー"
const CPU_TAG := "CPU"
const ROW_HEIGHT := 34.0
const TAG_WIDTH := 58.0
const NAME_FONT_SIZE := 16
const CHEVRON_SCALE := 0.9
const ARROW_WIDTH := 26.0
const LOCK_WIDTH := 28.0
const COLOR_USER := Color(0.45, 0.92, 1.0, 1.0)
const COLOR_LOCK := Color(1.0, 0.82, 0.3, 1.0)

## このスロットがある枠（0〜7）。
var slot := 0
var _tag_label: Label
var _name_label: Control
var _style_mark: Control
var _style_id := ""
var _portrait: Control
var _lock_button: Button
var _pururin_id := ""
var _taken_badge: Label
var _taken := false
var _locked := false
var _is_user := false


func setup(slot_index: int) -> void:
	slot = slot_index
	name = "Slot%d" % slot_index
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -2.0
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_tag_label = MenuStyle.label(CPU_TAG, 14, MenuStyle.COLOR_DIM)
	_tag_label.custom_minimum_size = Vector2(TAG_WIDTH, 0.0)
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_tag_label)
	row.add_child(_arrow("◀", -1))
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(ROW_HEIGHT - 6.0, ROW_HEIGHT - 6.0)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)
	_name_label = FitLabel.new()
	_name_label.call("setup", NAME_FONT_SIZE)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name_label.call("set_text", EMPTY_TEXT)
	row.add_child(_name_label)
	# 脚質の印（操作盤と同じ「〈」。得意な順位の組だけ光る）。
	_style_mark = Control.new()
	_style_mark.custom_minimum_size = Vector2(RaceHud.STYLE_CHEVRON_STEP * CHEVRON_SCALE * PururinStatsMath.rank_group_count() + 4.0, 0.0)
	_style_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_mark.draw.connect(_draw_style_mark)
	_style_mark.visible = false
	row.add_child(_style_mark)
	# 他のスロットで使っているキャラを出しているときの札。
	_taken_badge = Label.new()
	_taken_badge.text = TAKEN_TEXT
	_taken_badge.add_theme_font_size_override("font_size", 13)
	_taken_badge.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
	_taken_badge.add_theme_stylebox_override("normal", MenuStyle.box(MenuStyle.COLOR_TAKEN, 6, 6.0, 1.0))
	_taken_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_taken_badge.visible = false
	row.add_child(_taken_badge)
	row.add_child(_arrow("▶", 1))
	# 南京錠。クリックでも、施錠・解錠を切り替える。
	_lock_button = Button.new()
	_lock_button.name = "LockButton"
	_lock_button.flat = true
	_lock_button.focus_mode = Control.FOCUS_NONE
	_lock_button.custom_minimum_size = Vector2(LOCK_WIDTH, 0.0)
	_lock_button.draw.connect(_draw_lock)
	_lock_button.pressed.connect(func() -> void:
		grab_focus()
		lock_requested.emit(slot))
	row.add_child(_lock_button)
	focus_entered.connect(func() -> void:
		queue_redraw()
		slot_focused.emit(slot))
	focus_exited.connect(func() -> void:
		queue_redraw()
		slot_unfocused.emit(slot))


func _arrow(text: String, direction: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(ARROW_WIDTH, 0.0)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", MenuStyle.COLOR_DIM)
	button.add_theme_color_override("font_hover_color", MenuStyle.COLOR_TEXT)
	button.pressed.connect(func() -> void:
		grab_focus()
		cycle_requested.emit(slot, direction))
	return button


## ユーザーのスロットか、CPUのスロットか。
func set_role(is_user: bool) -> void:
	_is_user = is_user
	_tag_label.text = USER_TAG if is_user else CPU_TAG
	_tag_label.add_theme_color_override("font_color", COLOR_USER if is_user else MenuStyle.COLOR_DIM)
	queue_redraw()


func is_user() -> bool:
	return _is_user


func set_locked(locked: bool) -> void:
	_locked = locked
	_lock_button.queue_redraw()
	queue_redraw()


func is_locked() -> bool:
	return _locked


## このスロットに出す個体。空の辞書なら「未選択」。
## taken が true なら、「他のスロットで使っている個体を、見ているだけ」の表示（暗い名前と「選択済み」の札）。
func set_pururin(pururin: Dictionary, taken: bool = false) -> void:
	_pururin_id = str(pururin["id"]) if not pururin.is_empty() else ""
	_taken = taken and not pururin.is_empty()
	_taken_badge.visible = _taken
	_portrait.call("set_pururin", pururin)
	_portrait.modulate.a = 0.45 if _taken else 1.0
	queue_redraw()
	_style_id = str(pururin["running_style"]) if not pururin.is_empty() else ""
	# 脚質の印は、決まっているキャラのときだけ（未選択と「選択済み」のときは出さない）。
	_style_mark.visible = not pururin.is_empty() and not _taken
	_style_mark.queue_redraw()
	_name_label.call("set_text", EMPTY_TEXT if pururin.is_empty() else str(pururin["display_name"]))
	_name_label.call("set_color", MenuStyle.COLOR_DIM if pururin.is_empty() or _taken else MenuStyle.COLOR_TEXT)


func _draw_style_mark() -> void:
	if _style_id.is_empty():
		return
	RaceHud.draw_style_chevrons(
		_style_mark,
		Vector2(2.0, _style_mark.size.y * 0.5),
		RaceHud.COLOR_STYLE_MATCH,
		PururinStatsMath.rank_group_count(),
		PururinStatsMath.style_rank_group_index(_style_id),
		CHEVRON_SCALE
	)


## 「選択済み」の表示になっているか。
func is_taken() -> bool:
	return _taken


func pururin_id() -> String:
	return _pururin_id


## 出している名前（未選択なら EMPTY_TEXT）。縮める前の、元の文字。
func shown_text() -> String:
	return str(_name_label.get("text"))


## 名前を、今の幅で収めた結果（text・font_size・x_scale・width）。
func fitted_name() -> Dictionary:
	return _name_label.call("fitted")


func _gui_input(event: InputEvent) -> void:
	var direction := cycle_direction(event)
	if direction != 0:
		accept_event()
		cycle_requested.emit(slot, direction)
		return
	var move := RaceControllerInput.slot_move_direction(event)
	if move != 0:
		accept_event()
		move_requested.emit(slot, move)
	elif RaceControllerInput.is_slot_clear_pressed(event):
		accept_event()
		clear_requested.emit(slot)
	elif RaceControllerInput.is_slot_force_pressed(event):
		accept_event()
		force_requested.emit(slot)
	elif RaceControllerInput.is_slot_lock_pressed(event):
		accept_event()
		lock_requested.emit(slot)
	elif is_pick_event(event):
		accept_event()
		pick_requested.emit(slot)


## 決定の入力か（ゲームパッドのA、キーボードのEnter・スペース、マウスの左クリック）。
static func is_pick_event(event: InputEvent) -> bool:
	if RaceControllerInput.is_accept_pressed(event) or event.is_action_pressed("ui_accept"):
		return true
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


## 左右の入力なら、-1（前）か 1（次）。それ以外は 0。
## スティックは、倒した瞬間だけ数える（倒している間、何度も切り替わらないように）。
static func cycle_direction(event: InputEvent) -> int:
	for pair: Array in [["ui_left", -1], ["ui_right", 1]]:
		if not event.is_action_pressed(pair[0], true):
			continue
		if event is InputEventJoypadMotion and not Input.is_action_just_pressed(pair[0]):
			continue
		return pair[1]
	return 0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(MenuStyle.box(MenuStyle.COLOR_BUTTON_QUIET, 8, 0.0, 0.0), rect)
	if _is_user:
		# ユーザーのスロットは、左に水色の線。
		draw_rect(Rect2(Vector2(0.0, 5.0), Vector2(3.0, size.y - 10.0)), COLOR_USER)
	if has_focus():
		var frame := MenuStyle.focus_box(8)
		if _taken:
			frame.border_color = MenuStyle.COLOR_TAKEN
		draw_style_box(frame, rect)


## 南京錠。施錠中は金色で閉じた錠、解錠中は暗い色で、つるが開いた錠。
func _draw_lock() -> void:
	var canvas := _lock_button
	var center := canvas.size * 0.5
	var color := COLOR_LOCK if _locked else Color(MenuStyle.COLOR_DIM, 0.55)
	var body := Rect2(center + Vector2(-7.0, -1.0), Vector2(14.0, 11.0))
	# つる（上の輪）。解錠中は、右側を持ち上げて開いた形にする。
	var shackle := PackedVector2Array()
	for index in 9:
		var angle := PI + PI * float(index) / 8.0
		shackle.append(center + Vector2(cos(angle) * 4.5, -2.0 + sin(angle) * 5.0))
	if _locked:
		shackle.insert(0, center + Vector2(-4.5, 0.0))
		shackle.append(center + Vector2(4.5, 0.0))
	else:
		shackle.insert(0, center + Vector2(-4.5, 0.0))
		for index in shackle.size():
			if index > 4:
				shackle[index] += Vector2(0.0, -3.0)
	canvas.draw_polyline(shackle, MenuStyle.COLOR_OUTLINE, 4.5, true)
	canvas.draw_polyline(shackle, color, 2.2, true)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.border_color = MenuStyle.COLOR_OUTLINE
	box.set_border_width_all(1)
	canvas.draw_style_box(box, body)
	if _locked:
		canvas.draw_circle(body.get_center() + Vector2(0.0, -0.5), 1.8, MenuStyle.COLOR_OUTLINE)
