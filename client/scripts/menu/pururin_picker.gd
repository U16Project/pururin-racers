extends Control
## キャラの一覧の窓。スロットで決定すると開き、タイル（1段3つ、下へスクロール）からキャラを直接選ぶ。
## 決定で picked、選択済みのタイルで強制選択すると force_requested、閉じると closed を出す。
## どのスロットに何を入れるかは、画面側（レース選択）が決める。

signal picked(pururin_id: String)
signal force_requested(pururin_id: String)
signal tile_focused(pururin_id: String)
signal closed

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const Tile := preload("res://scripts/menu/pururin_tile.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const COLUMNS := 3
const MARGIN := 14.0
const TILE_GAP := 6
const GRID_MARGIN := 5
const TILE_FOCUS_MARGIN := 4
const COLOR_WINDOW := Color(0.07, 0.1, 0.16, 0.98)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.35)

var _title: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _tiles: Array[Button] = []
var _slot := -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = MARGIN
	column.offset_top = MARGIN
	column.offset_right = -MARGIN
	column.offset_bottom = -MARGIN
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = MenuStyle.label("", 20)
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := MenuStyle.button("×", 18, MenuStyle.COLOR_BUTTON_QUIET)
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(36.0, 30.0)
	close_button.pressed.connect(close)
	UIAudio.bind_button_sound(close_button, "back")
	header.add_child(close_button)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# カーソルを動かすと、見える位置まで自動でスクロールする。
	_scroll.follow_focus = false
	column.add_child(_scroll)
	# タイルのまわりに少し余白を取る（選択の枠が、スクロールの端で切れないように）。
	var grid_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		grid_margin.add_theme_constant_override(side, GRID_MARGIN)
	_scroll.add_child(grid_margin)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", TILE_GAP)
	_grid.add_theme_constant_override("v_separation", TILE_GAP)
	grid_margin.add_child(_grid)
	var note := HBoxContainer.new()
	note.name = "Note"
	note.add_theme_constant_override("separation", 5)
	for item: Array in [["A", "決定"], ["Y", "強制選択"], ["B", "閉じる"]]:
		note.add_child(MenuStyle.mark(str(item[0]), 18.0))
		var text := MenuStyle.label(str(item[1]), 14, MenuStyle.COLOR_DIM)
		text.custom_minimum_size = Vector2(86.0, 0.0)
		note.add_child(text)
	column.add_child(note)


## 窓の幅（タイルの列数と、すき間と、余白と、スクロールの棒のぶん）。
static func window_width() -> float:
	return (Tile.TILE_SIZE.x + TILE_FOCUS_MARGIN * 2.0) * COLUMNS + TILE_GAP * (COLUMNS - 1) + GRID_MARGIN * 2.0 + MARGIN * 2.0 + 14.0


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_WINDOW
	box.border_color = COLOR_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 12
	draw_style_box(box, Rect2(Vector2.ZERO, size))


func is_open() -> bool:
	return visible


func slot() -> int:
	return _slot


## そのスロットのキャラを選ぶ窓を開く。カーソルは、今入っているキャラ（空なら「未選択」）に置く。
func open(slot_index: int, title_text: String) -> void:
	_slot = slot_index
	_title.text = title_text
	_rebuild()
	visible = true
	var current := RaceSession.slot_pururin_id(slot_index)
	for tile in _tiles:
		if str(tile.call("pururin_id")) == current:
			tile.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func tiles() -> Array[Button]:
	return _tiles


func tile_for(pururin_id: String) -> Button:
	for tile in _tiles:
		if str(tile.call("pururin_id")) == pururin_id:
			return tile
	return null


## タイルを並べ直す：最初に「ー未選択ー」、そのあと一覧の順。状態は、今の選択から決める。
func _rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var ids: Array[String] = [RaceSession.EMPTY]
	ids.append_array(RaceSession.roster_ids())
	for identifier in ids:
		var tile: Button = Tile.new()
		tile.call("setup", identifier)
		var holder := RaceSession.slot_holding(identifier)
		if identifier == RaceSession.slot_pururin_id(_slot):
			tile.call("set_state", Tile.State.CURRENT)
		elif holder >= 0:
			tile.call("set_state", Tile.State.LOCKED if RaceSession.is_locked(holder) else Tile.State.TAKEN, holder)
		else:
			tile.call("set_state", Tile.State.FREE)
		tile.pressed.connect(_on_tile_pressed.bind(tile))
		tile.connect("tile_focused", func(pururin_id: String) -> void: tile_focused.emit(pururin_id))
		tile.connect("force_requested", _on_tile_force_requested.bind(tile))
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, TILE_FOCUS_MARGIN)
		_grid.add_child(margin)
		margin.add_child(tile)
		tile.focus_entered.connect(func() -> void:
			await get_tree().process_frame
			if is_instance_valid(tile) and tile.has_focus():
				_scroll.ensure_control_visible(margin))
		_tiles.append(tile)
	_link_tiles()


## タイルどうしの、上下左右の行き先を決める（端では動かない。窓の外へは出ない）。
func _link_tiles() -> void:
	for index in _tiles.size():
		var tile := _tiles[index]
		var column := index % COLUMNS
		var left := index - 1 if column > 0 else index
		var right := index + 1 if column < COLUMNS - 1 and index + 1 < _tiles.size() else index
		var up := index - COLUMNS if index - COLUMNS >= 0 else index
		var down := index + COLUMNS if index + COLUMNS < _tiles.size() else index
		tile.focus_neighbor_left = tile.get_path_to(_tiles[left])
		tile.focus_neighbor_right = tile.get_path_to(_tiles[right])
		tile.focus_neighbor_top = tile.get_path_to(_tiles[up])
		tile.focus_neighbor_bottom = tile.get_path_to(_tiles[down])
		tile.focus_next = tile.get_path_to(_tiles[(index + 1) % _tiles.size()])
		tile.focus_previous = tile.get_path_to(_tiles[posmod(index - 1, _tiles.size())])


## 決定：空きか、このスロットで選択中のタイルだけ、選べる。
func _on_tile_pressed(tile: Button) -> void:
	if bool(tile.call("can_pick")):
		picked.emit(str(tile.call("pururin_id")))
	else:
		UIAudio.play_error()


## 強制選択：他のスロットが使っていて、施錠していないタイルだけ、奪える。
func _on_tile_force_requested(_pururin_id: String, tile: Button) -> void:
	if int(tile.call("state")) == Tile.State.TAKEN:
		force_requested.emit(str(tile.call("pururin_id")))
	else:
		UIAudio.play_error()
