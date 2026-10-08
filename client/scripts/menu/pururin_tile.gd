extends Button
## キャラの一覧の窓に並べるタイル1つ。上から、画像・名前・属性の印と脚質の印。
## 「ー未選択ー」のタイル（スロットを空にする）も、この部品で作る。
## 状態（空き・このスロットで選択中・他の枠が使用中・他の枠が施錠中）で、見た目が変わる。

signal tile_focused(pururin_id: String)
signal force_requested(pururin_id: String)

enum State { FREE, CURRENT, TAKEN, LOCKED }

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const FitLabel := preload("res://scripts/menu/fit_label.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const TILE_SIZE := Vector2(104.0, 118.0)
const PORTRAIT_SIZE := 58.0
const MARK_SIZE := 18.0
const NAME_FONT_SIZE := 15
const NAME_SIDE_MARGIN := 4.0
const CHEVRON_SCALE := 0.8
const EMPTY_TEXT := "ー未選択ー"
const CURRENT_TEXT := "選択中"
const COLOR_TILE := Color(0.2, 0.25, 0.33, 1.0)
const COLOR_CURRENT := Color(0.3, 0.8, 0.5, 1.0)
const COLOR_LOCK := Color(1.0, 0.82, 0.3, 1.0)

var _pururin_id := ""
var _preview: Dictionary = {}
var _state := State.FREE
var _holder_slot := -1
var _portrait: Control
var _name_label: Control
var _marks: Control
var _badge: Label


## pururin_id が空なら、「ー未選択ー」のタイル。
func setup(pururin_id: String) -> void:
	_pururin_id = pururin_id
	_preview = PururinDetail.preview_for(pururin_id) if not pururin_id.is_empty() else {}
	name = "Tile_%s" % (pururin_id if not pururin_id.is_empty() else "empty")
	custom_minimum_size = TILE_SIZE
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 6.0
	column.offset_bottom = -5.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.offset_left = NAME_SIDE_MARGIN
	column.offset_right = -NAME_SIDE_MARGIN
	_name_label = FitLabel.new()
	_name_label.call("setup", NAME_FONT_SIZE, 0.5)
	_name_label.call("set_text", EMPTY_TEXT if _preview.is_empty() else str(_preview["display_name"]))
	if _preview.is_empty():
		_name_label.call("set_color", MenuStyle.COLOR_DIM)
		column.add_child(_name_label)
	else:
		_portrait = Portrait.new()
		_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(_portrait)
		_portrait.call("set_pururin", PururinDetail.PururinRosterConfig.pururin_by_id(pururin_id))
		column.add_child(_name_label)
		_marks = Control.new()
		_marks.custom_minimum_size = Vector2(0.0, MARK_SIZE + 2.0)
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marks.draw.connect(_draw_marks)
		column.add_child(_marks)
	# 状態の札（選択中・◯枠）。タイルの右上に重ねる。
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 12)
	_badge.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	add_child(_badge)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.offset_top = 4.0
	_badge.offset_right = -4.0
	focus_entered.connect(func() -> void:
		queue_redraw()
		tile_focused.emit(_pururin_id))
	focus_exited.connect(queue_redraw)


## 状態を変える。holder_slot は、使っているスロットの枠（TAKEN・LOCKED のとき）。
func set_state(state: State, holder_slot: int = -1) -> void:
	_state = state
	_holder_slot = holder_slot
	var dimmed := state == State.TAKEN or state == State.LOCKED
	if _portrait != null:
		_portrait.modulate.a = 0.4 if dimmed else 1.0
		_marks.modulate.a = 0.4 if dimmed else 1.0
	_name_label.call("set_color", MenuStyle.COLOR_DIM if dimmed or _preview.is_empty() else MenuStyle.COLOR_TEXT)
	_badge.visible = state != State.FREE
	match state:
		State.CURRENT:
			_badge.text = CURRENT_TEXT
			_badge.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_CURRENT, 6, 5.0, 0.0))
		State.TAKEN:
			_badge.text = "%d枠" % (holder_slot + 1)
			_badge.add_theme_stylebox_override("normal", MenuStyle.box(MenuStyle.COLOR_TAKEN, 6, 5.0, 0.0))
		State.LOCKED:
			# 南京錠の絵のぶん、左を空ける。
			_badge.text = "%d枠" % (holder_slot + 1)
			_badge.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_LOCK, 6, 5.0, 0.0))
	queue_redraw()


func pururin_id() -> String:
	return _pururin_id


## 名前を、今の幅で収めた結果（text・font_size・x_scale・width）。
func fitted_name() -> Dictionary:
	return _name_label.call("fitted")


func state() -> State:
	return _state


func holder_slot() -> int:
	return _holder_slot


## 決定できるタイルか（空き、または、このスロットで選択中）。
func can_pick() -> bool:
	return _state == State.FREE or _state == State.CURRENT


func _gui_input(event: InputEvent) -> void:
	if RaceControllerInput.is_slot_force_pressed(event):
		accept_event()
		force_requested.emit(_pururin_id)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var back := COLOR_TILE.darkened(0.25) if (_state == State.TAKEN or _state == State.LOCKED) else COLOR_TILE
	if is_hovered() and can_pick():
		back = back.lightened(0.1)
	draw_style_box(MenuStyle.box(back, 10, 0.0, 0.0), rect)
	if _state == State.CURRENT:
		var frame := MenuStyle.focus_box(10)
		frame.border_color = COLOR_CURRENT
		frame.set_border_width_all(2)
		frame.set_expand_margin_all(0.0)
		draw_style_box(frame, rect)
	if has_focus():
		var focus := MenuStyle.focus_box(10)
		if _state == State.TAKEN:
			focus.border_color = MenuStyle.COLOR_TAKEN
		draw_style_box(focus, rect)
	if _state == State.LOCKED:
		_draw_lock(Vector2(14.0, 15.0))


## 属性の印と、脚質の印を、横に並べて中央に描く。
func _draw_marks() -> void:
	var chevrons_width := RaceHud.STYLE_CHEVRON_STEP * CHEVRON_SCALE * PururinStatsMath.rank_group_count()
	var total := MARK_SIZE + 6.0 + chevrons_width
	var left := (_marks.size.x - total) * 0.5
	var center_y := _marks.size.y * 0.5
	PururinDetail.draw_attribute_mark(_marks, Vector2(left + MARK_SIZE * 0.5, center_y), MARK_SIZE, str(_preview["attribute_id"]), _preview["attribute_color"])
	RaceHud.draw_style_chevrons(
		_marks,
		Vector2(left + MARK_SIZE + 6.0, center_y),
		RaceHud.COLOR_STYLE_MATCH,
		PururinStatsMath.rank_group_count(),
		PururinStatsMath.style_rank_group_index(str(_preview["style_id"])),
		CHEVRON_SCALE
	)


## 施錠済みの印（閉じた金色の南京錠）。
func _draw_lock(center: Vector2) -> void:
	var shackle := PackedVector2Array([center + Vector2(-4.0, 0.0)])
	for index in 9:
		var angle := PI + PI * float(index) / 8.0
		shackle.append(center + Vector2(cos(angle) * 4.0, -1.5 + sin(angle) * 4.5))
	shackle.append(center + Vector2(4.0, 0.0))
	draw_polyline(shackle, MenuStyle.COLOR_OUTLINE, 4.0, true)
	draw_polyline(shackle, COLOR_LOCK, 2.0, true)
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_LOCK
	box.set_corner_radius_all(3)
	box.border_color = MenuStyle.COLOR_OUTLINE
	box.set_border_width_all(1)
	draw_style_box(box, Rect2(center + Vector2(-6.0, -1.0), Vector2(12.0, 10.0)))
