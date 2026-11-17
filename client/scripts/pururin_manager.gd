extends Control
## ぷるりん管理コーナー。左：ぷるりんのカードの一覧（先頭に「＋新規作成」、自分のぷるりん、最初からいるぷるりん）。
## カードを選ぶと、右のパネルに詳細と「戻る」「編集」「複製」「消去」。最初からいるぷるりんは、複製だけできる。
## 新規作成・編集・複製は、作る画面（pururin_maker）へ移る。何を開くかは PururinMakerRequest に入れる。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const MAKER_SCENE_PATH := "res://scenes/pururin_maker.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/race_select_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const MyPururins := preload("res://scripts/config/my_pururins.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PortraitCache := preload("res://scripts/presentation/pururin_portrait_cache.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const PururinMakerRequest := preload("res://scripts/menu/pururin_maker_request.gd")
const GAP := 14.0
const RIGHT_WIDTH := 580.0
const CARD_SIZE := Vector2(104.0, 120.0)
const CARD_COLUMNS := 5
## 選んでいる場所の光る枠：まわりに空ける幅と、明るさが1回りする秒数。
const FOCUS_RING_ROOM := 5.0
const FOCUS_RING_SECONDS := 1.4
const CONFIRM_SIZE := Vector2(560.0, 220.0)
## 「＋新規作成」のカードの、ID の代わりの印。
const NEW_CARD := "+new"

var _list: VBoxContainer
var _detail: Control
var _back_button: Button
var _edit_button: Button
var _copy_button: Button
var _delete_button: Button
## ID → カード。
var _cards := {}
## 右のパネルに出しているぷるりん（カードを押したもの。空なら、まだ選んでいない）。
var _shown_id := ""
var _confirm: Control
var _focus_ring: Panel
var _ring_time := 0.0


func _ready() -> void:
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "ぷるりん管理コーナー", TrainerProfile.trainer_name())
	var main := HBoxContainer.new()
	main.name = "Main"
	main.add_theme_constant_override("separation", int(GAP))
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = MenuStyle.SCREEN_MARGIN
	main.offset_right = -MenuStyle.SCREEN_MARGIN
	main.offset_top = MenuStyle.BAR_HEIGHT + 10.0
	main.offset_bottom = -MenuStyle.GUIDE_HEIGHT - 10.0
	add_child(main)
	var left := PanelContainer.new()
	left.name = "ListPanel"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_stylebox_override("panel", MenuStyle.panel_box(14.0, 12.0))
	main.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	# 選んだときの枠が切れないよう、まわりにすき間を空ける。
	_list = VBoxContainer.new()
	_list.name = "CardList"
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(MenuStyle.focus_room(_list))
	var right := PanelContainer.new()
	right.name = "DetailPanel"
	right.custom_minimum_size.x = RIGHT_WIDTH
	right.add_theme_stylebox_override("panel", MenuStyle.panel_box(14.0, 12.0))
	main.add_child(right)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	right.add_child(column)
	_detail = PururinDetail.new()
	_detail.name = "Detail"
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_detail)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_back_button = _button(buttons, "BackToListButton", "戻る", "secondary", back_to_list, "back")
	_edit_button = _button(buttons, "EditButton", "編集", "primary", edit_shown, "confirmation")
	_copy_button = _button(buttons, "CopyButton", "複製", "primary", copy_shown, "confirmation")
	_delete_button = _button(buttons, "DeleteButton", "消去", "secondary", ask_delete, "confirmation")
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	var back := MenuStyle.guide_button(guide, "B", "戻る")
	back.name = "BackButton"
	back.pressed.connect(_on_cancel)
	UIAudio.bind_button_sound(back, "back")
	_focus_ring = Panel.new()
	_focus_ring.name = "FocusRing"
	_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_ring.top_level = true
	_focus_ring.z_index = 100
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = MenuStyle.COLOR_FOCUS
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(14)
	ring.shadow_color = Color(MenuStyle.COLOR_FOCUS, 0.6)
	ring.shadow_size = 10
	_focus_ring.add_theme_stylebox_override("panel", ring)
	add_child(_focus_ring)
	_build_cards()
	_show("")
	var focus_id := PururinMakerRequest.focus_id
	PururinMakerRequest.focus_id = ""
	_card_for(focus_id).grab_focus.call_deferred()


func _button(holder: Container, node_name: String, text: String, kind: String, action: Callable, sound: String) -> Button:
	var button := MenuStyle.pill_button(text, kind, 18)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	UIAudio.bind_button_sound(button, sound)
	holder.add_child(button)
	return button


# ---------------------------------------------------------------- 一覧

## カードを並べ直す。先頭に「＋新規作成」、次に自分のぷるりん（作った順）、見出しのあとに最初からいるぷるりん。
func _build_cards() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	_list.add_child(_section_title("自分のぷるりん（%d 体）" % MyPururins.ids().size()))
	var mine := _grid()
	_list.add_child(mine)
	mine.add_child(_new_card())
	for identifier in MyPururins.ids():
		mine.add_child(_card(identifier))
	_list.add_child(_section_title("最初からいるぷるりん（複製だけできます）"))
	var roster := _grid()
	_list.add_child(roster)
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		roster.add_child(_card(str(pururin["id"])))


func _section_title(text: String) -> Label:
	return MenuStyle.bold_label(text, 17, MenuStyle.COLOR_TEXT, 6)


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _card_base(node_name: String, caption_text: String) -> Button:
	var card := Button.new()
	card.name = node_name
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", MenuStyle.card_box(MenuStyle.COLOR_CARD, MenuStyle.COLOR_CARD_BORDER, 10))
	card.add_theme_stylebox_override("hover", MenuStyle.card_box(MenuStyle.COLOR_CARD.lightened(0.08), Color(1.0, 1.0, 1.0, 0.4), 10))
	card.add_theme_stylebox_override("pressed", MenuStyle.card_box(MenuStyle.COLOR_CARD.lightened(0.08), Color(1.0, 1.0, 1.0, 0.4), 10))
	card.add_theme_stylebox_override("focus", MenuStyle.focus_box(12))
	var caption := MenuStyle.label(caption_text, 13, MenuStyle.COLOR_TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -24.0
	caption.offset_left = 2.0
	caption.offset_right = -2.0
	card.add_child(caption)
	card.tooltip_text = caption_text
	UIAudio.bind_button_sound(card, "confirmation")
	return card


func _new_card() -> Button:
	var card := _card_base("NewCard", "新規作成")
	var plus := MenuStyle.bold_label("＋", 54, MenuStyle.COLOR_TEXT, 6)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus.offset_bottom = -24.0
	card.add_child(plus)
	card.focus_entered.connect(_show.bind(""))
	card.pressed.connect(func() -> void: _open_maker("new", ""))
	_cards[NEW_CARD] = card
	return card


func _card(identifier: String) -> Button:
	var card := _card_base("Card_%s" % identifier, str(PururinRosterConfig.pururin_by_id(identifier).get("display_name", identifier)))
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.offset_bottom = -24.0
	picture.texture = PortraitCache.texture_for(identifier, get_tree())
	card.add_child(picture)
	# カーソルを乗せると、右に出す。押すと、右の「戻る」を選ぶ（そこから編集・複製・消去へ）。
	card.focus_entered.connect(_show.bind(identifier))
	card.pressed.connect(func() -> void:
		_show(identifier)
		_back_button.grab_focus())
	_cards[identifier] = card
	return card


## その ID のカード。無ければ「＋新規作成」。
func _card_for(identifier: String) -> Button:
	return _cards.get(identifier, _cards[NEW_CARD])


# ---------------------------------------------------------------- 右のパネル

## 右のパネルに出す。空なら、何も選んでいない（ボタンは「戻る」だけ）。
func _show(identifier: String) -> void:
	_shown_id = identifier
	_detail.call("show_pururin", identifier, "", false, false)
	var mine := MyPururins.ids().has(identifier)
	_edit_button.disabled = not mine
	_delete_button.disabled = not mine
	_copy_button.disabled = identifier.is_empty()


## 「戻る」：一覧の、今のぷるりんのカードへ戻る。
func back_to_list() -> void:
	_card_for(_shown_id).grab_focus()


func edit_shown() -> void:
	if MyPururins.ids().has(_shown_id):
		_open_maker("edit", _shown_id)


func copy_shown() -> void:
	if not _shown_id.is_empty():
		_open_maker("copy", _shown_id)


func _open_maker(mode: String, identifier: String) -> void:
	PururinMakerRequest.open(mode, identifier)
	get_tree().change_scene_to_file(MAKER_SCENE_PATH)


# ---------------------------------------------------------------- 消去

## 「消去」：確かめる窓を出す。はじめは「やめる」を選んでおく。
func ask_delete() -> void:
	if not MyPururins.ids().has(_shown_id) or _confirm != null:
		return
	_confirm = Control.new()
	_confirm.name = "ConfirmWindow"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(shade)
	var panel := PanelContainer.new()
	var box := MenuStyle.card_box(Color(0.07, 0.11, 0.2, 0.98), MenuStyle.COLOR_CARD_BORDER, 16)
	box.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -CONFIRM_SIZE.x * 0.5
	panel.offset_right = CONFIRM_SIZE.x * 0.5
	panel.offset_top = -CONFIRM_SIZE.y * 0.5
	panel.offset_bottom = CONFIRM_SIZE.y * 0.5
	_confirm.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var pururin_name := str(PururinRosterConfig.pururin_by_id(_shown_id).get("display_name", ""))
	var question := MenuStyle.bold_label("%s を消去しますか？\n消すと、元に戻せません。" % pururin_name, 20, MenuStyle.COLOR_TEXT, 6)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	var yes := MenuStyle.pill_button("消去する", "secondary", 18)
	yes.name = "ConfirmDeleteButton"
	yes.custom_minimum_size.x = 160.0
	yes.pressed.connect(_delete_shown)
	UIAudio.bind_button_sound(yes, "confirmation")
	row.add_child(yes)
	var no := MenuStyle.pill_button("やめる", "primary", 18)
	no.name = "CancelDeleteButton"
	no.custom_minimum_size.x = 160.0
	no.pressed.connect(_close_confirm.bind(true))
	UIAudio.bind_button_sound(no, "back")
	row.add_child(no)
	no.grab_focus.call_deferred()


## 窓を閉じる。back_to_detail なら、右の「消去」へ戻る。
func _close_confirm(back_to_detail: bool) -> void:
	if _confirm == null:
		return
	_confirm.queue_free()
	_confirm = null
	if back_to_detail:
		_delete_button.grab_focus.call_deferred()


func _delete_shown() -> void:
	var identifier := _shown_id
	var error := MyPururins.remove(identifier)
	_close_confirm(false)
	if not error.is_empty():
		push_warning(error)
		return
	PortraitCache.forget(identifier)
	_build_cards()
	_show("")
	_cards[NEW_CARD].grab_focus.call_deferred()


# ---------------------------------------------------------------- 入力

## B：右のパネルにいれば一覧へ、一覧にいればモード選択へ。
func _on_cancel() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and owner.get_parent() == _back_button.get_parent():
		back_to_list()
		return
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func _update_focus_ring() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	_focus_ring.visible = owner != null and owner.is_visible_in_tree()
	if not _focus_ring.visible:
		return
	var rect := owner.get_global_rect().grow(FOCUS_RING_ROOM)
	_focus_ring.position = rect.position
	_focus_ring.size = rect.size
	_focus_ring.modulate.a = 0.65 + 0.35 * sin(_ring_time * TAU / FOCUS_RING_SECONDS)


func _process(delta: float) -> void:
	_ring_time += delta
	_update_focus_ring()
	# 確かめる窓を開いている間は、選ぶ場所を窓の中だけにする。
	if _confirm != null:
		var owner := get_viewport().gui_get_focus_owner()
		if owner == null or not _confirm.is_ancestor_of(owner):
			_confirm.find_child("CancelDeleteButton", true, false).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		if _confirm != null:
			_close_confirm(true)
		else:
			_on_cancel()
