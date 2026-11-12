extends Control
## ぷるりん作成コーナー。名前・属性・脚質・能力の配分と、見た目の部品を選んで、自分のぷるりんを作る。
## 作ったぷるりんは、1体ずつ別のファイルに保存する（MyPururins）。数に決まりは無い。
## 部品は、組み込みの部品と、ユーザーが置き場所（UserParts）に用意した部品から選ぶ。
## 上：自分のぷるりんの一覧と、保存・消す。左：選ぶ種類（L1・R1でも替わる）。まん中：回る下見。
## 右：その種類で選べるもの。部品は、その部品を付けた姿の絵を並べる（どの種類も、1画面に収める）。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/race_select_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const MakerConfig := preload("res://scripts/config/pururin_maker_config.gd")
const MyPururins := preload("res://scripts/config/my_pururins.gd")
const UserParts := preload("res://scripts/config/user_parts.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinBodyBuilder := preload("res://scripts/presentation/pururin_body_builder.gd")
const PortraitCache := preload("res://scripts/presentation/pururin_portrait_cache.gd")
const Stage := preload("res://scripts/presentation/pururin_portrait_stage.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const TAB_WIDTH := 150.0
const RIGHT_WIDTH := 540.0
const GAP := 14.0
const STRIP_HEIGHT := 48.0
## 選んでいる場所の光る枠：まわりに空ける幅と、明るさが1回りする秒数。
const FOCUS_RING_ROOM := 5.0
const FOCUS_RING_SECONDS := 1.4
## 自分のぷるりんの一覧の窓：大きさ、1行に並べる数、絵の大きさ。
const LIST_WINDOW_SIZE := Vector2(900.0, 560.0)
const LIST_COLUMNS := 6
const LIST_TILE_SIZE := Vector2(124.0, 124.0)
const ROW_TITLE_WIDTH := 56.0
## 色のページの、見本の大きさと、1行に並べる数。
const COLOR_SWATCH := 46.0
const COLOR_COLUMNS := 8
## 能力の棒の枠の高さ（レース選択の詳細の棒と、同じくらい）。
const STAT_BARS_HEIGHT := 230.0
## 棒の段が始まる高さ（枠の上から。上に数字を描く）。
const STAT_BAR_TOP := 26.0
const COLOR_WARN := Color(1.0, 0.55, 0.45, 1.0)
## 選んでいるものの縁（カーソルの黄色い枠と見分けるため、水色）。
const COLOR_CHOSEN := Color(0.35, 0.86, 1.0, 1.0)
## 種類：[名前, 画面の名前]。
const TABS := [["basic", "基本"], ["stats", "能力"], ["color", "色"], ["top", "頭"], ["sides", "横"], ["tail", "しっぽ"], ["face", "顔"], ["marks", "マーク"]]
## 体の一部の種類 → 部品のスロット。
const BODY_PART_SLOTS := {"top": "top", "sides": "side", "tail": "tail"}
## 部品の絵：一辺（ピクセル）、写す範囲（m）、体の向き（度。0が正面）、体を持ち上げる高さ（m。顔を大きく写すとき）、
## 体を横へずらす量（m。横・しっぽの部品のあたりを、絵のまん中にする）。
const THUMB_PX := 160
const TILE_SIZE := Vector2(92.0, 108.0)
const TILE_COLUMNS := 5
## 顔のページの、場所の切り替え：[場所, 画面の名前]。
const FACE_SLOT_TABS := [["eyes", "目"], ["brows", "まゆ"], ["mouth", "口"], ["cheeks", "ほっぺ"]]
## 1行に6つ並べるときのタイル（マーク・元にする）。
const SMALL_TILE_SIZE := Vector2(76.0, 92.0)
const THUMB_VIEWS := {
	"top": {"view": 1.7, "yaw": 20.0, "lift": -0.15, "shift": 0.0},
	"sides": {"view": 1.1, "yaw": 0.0, "lift": 0.3, "shift": 0.7},
	"tail": {"view": 1.1, "yaw": -90.0, "lift": 0.35, "shift": 0.7},
	"face": {"view": 0.85, "yaw": 0.0, "lift": 0.28, "shift": 0.0},
	"marks": {"view": 1.0, "yaw": 0.0, "lift": 0.0, "shift": 0.0},
}
## 絵を写し続けるフレーム数（最初の数フレームは、描き方の準備が終わっていないことがある）。
const THUMB_FRAMES := 20

## 今つくっている（直している）ぷるりんの、保存の中身。
var _entry: Dictionary = {}
## 保存したことがあるか（消せるか）。
var _saved := false
var _expression_index := 0
## 消すボタンを1回押したか（2回目で消す）。
var _delete_armed := false
## マークの場所ごとの、マーク（無い場所は空）。開いたときに、並びの順に場所へ入れる。
var _mark_slots: Array = []
## 能力のページで、選んでいる能力。
var _selected_stat := "top_speed"
## マークのページで、いま直している場所の番号。
var _mark_spot := 0
var _tab := "basic"
## 顔のページで、いま選んでいる場所（eyes・brows・mouth・cheeks）。
var _face_slot := "eyes"

var _list_button: Button
var _list_window: Control
## ゲームパッドで、いま選んでいる場所に重ねる、光る枠。
var _focus_ring: Panel
var _ring_time := 0.0
var _tab_buttons := {}
var _page: VBoxContainer
var _portrait: Control
var _name_label: Label
var _expression_label: Label
var _message: Label
var _problems_button: Button
var _delete_button: Button
## 今のページで、選んでいる印を付け直すもの：{"button": Button, "chosen": Callable}。
var _choices: Array[Dictionary] = []
## 今のページの、文字を出し直すもの：{"label": Label か Button, "text": Callable}。
var _texts: Array[Dictionary] = []
## 部品の絵を写している舞台（ページを替えると捨てる）。
var _thumb_holder: Node


func _ready() -> void:
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "ぷるりん作成コーナー", TrainerProfile.trainer_name())
	_thumb_holder = Node.new()
	_thumb_holder.name = "Thumbnails"
	add_child(_thumb_holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(GAP) - 4)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = MenuStyle.SCREEN_MARGIN
	column.offset_right = -MenuStyle.SCREEN_MARGIN
	column.offset_top = MenuStyle.BAR_HEIGHT + 10.0
	column.offset_bottom = -MenuStyle.GUIDE_HEIGHT - 10.0
	add_child(column)
	column.add_child(_build_strip())
	var main := HBoxContainer.new()
	main.name = "Main"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", int(GAP))
	column.add_child(main)
	main.add_child(_build_tabs())
	main.add_child(_build_preview())
	var right := PanelContainer.new()
	right.name = "PagePanel"
	right.custom_minimum_size.x = RIGHT_WIDTH
	right.add_theme_stylebox_override("panel", MenuStyle.panel_box(14.0, 12.0))
	main.add_child(right)
	_page = VBoxContainer.new()
	_page.name = "Page"
	_page.add_theme_constant_override("separation", 10)
	right.add_child(_page)
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	# L1 と R1 は、1つの案内に並べる（左の項目を、前後に切り替える）。
	var switch_item := MenuStyle.guide_item(guide, "R1", "項目切替え").get_parent()
	var l1_mark := MenuStyle.mark("L1", 24.0)
	l1_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switch_item.add_child(l1_mark)
	switch_item.move_child(l1_mark, 0)
	# L2 と R2 も、1つの案内に並べる（まん中の下見の表情を、前後に切り替える）。
	var face_item := MenuStyle.guide_item(guide, "R2", "表情切替え").get_parent()
	var l2_mark := MenuStyle.mark("L2", 24.0)
	l2_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face_item.add_child(l2_mark)
	face_item.move_child(l2_mark, 0)
	var back := MenuStyle.guide_button(guide, "B", "戻る")
	back.name = "BackButton"
	back.pressed.connect(go_back)
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
	var folder_error := UserParts.make_folders()
	start_new()
	if not folder_error.is_empty():
		_show_message(folder_error, true)


## 上の帯：自分のぷるりんの一覧（横に並べる）と、保存・消す。
func _build_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.name = "Strip"
	strip.custom_minimum_size.y = STRIP_HEIGHT
	strip.add_theme_constant_override("separation", 10)
	var title := MenuStyle.bold_label("自分のぷるりん", 17, MenuStyle.COLOR_TEXT, 6)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.add_child(title)
	# 上の帯のボタンは、ゲームパッドでは決まったボタンで押す（選ぶ場所は、左の項目と右のページだけにする）。
	_list_button = _strip_button("", "tab", "X", open_list)
	_list_button.name = "ListButton"
	_list_button.custom_minimum_size.x = 360.0
	strip.add_child(_list_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(spacer)
	var save_button := _strip_button("保存する", "primary", "Y", save)
	save_button.name = "SaveButton"
	save_button.custom_minimum_size.x = 180.0
	strip.add_child(save_button)
	_delete_button = _strip_button("消す", "secondary", "SELECT", request_delete)
	_delete_button.name = "DeleteButton"
	_delete_button.custom_minimum_size.x = 200.0
	strip.add_child(_delete_button)
	return strip


## 上の帯のボタン。左端に、ゲームパッドのボタンのマークを付ける。
func _strip_button(text: String, kind: String, pad: String, action: Callable) -> Button:
	var button := MenuStyle.pill_button(text, kind, 18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	UIAudio.bind_button_sound(button, "confirmation")
	var mark := MenuStyle.add_mark(button, pad, 24.0)
	# 文字が、左端のマークに重ならないよう、左に空きを作る。
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = mark.offset_right + 10.0
		button.add_theme_stylebox_override(state, style)
	return button


# ---------------------------------------------------------------- 自分のぷるりんの一覧（窓）

## 自分のぷるりんを、絵つきで並べた窓を開く。何体あっても、上下に動かして選べる。
func open_list() -> void:
	close_list()
	_list_window = Control.new()
	_list_window.name = "ListWindow"
	_list_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_window.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_list_window)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_list())
	_list_window.add_child(shade)
	var panel := PanelContainer.new()
	var box := MenuStyle.card_box(Color(0.07, 0.11, 0.2, 0.98), MenuStyle.COLOR_CARD_BORDER, 16)
	box.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -LIST_WINDOW_SIZE.x * 0.5
	panel.offset_right = LIST_WINDOW_SIZE.x * 0.5
	panel.offset_top = -LIST_WINDOW_SIZE.y * 0.5
	panel.offset_bottom = LIST_WINDOW_SIZE.y * 0.5
	_list_window.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := MenuStyle.bold_label("自分のぷるりん（%d 体）" % MyPururins.ids().size(), 20, MenuStyle.COLOR_TEXT, 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _strip_button("閉じる", "secondary", "B", close_list)
	close.custom_minimum_size.x = 140.0
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	# 選んだときの枠が切れないよう、まわりにすき間を空ける。
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		room.add_theme_constant_override("margin_" + side, 8)
	scroll.add_child(room)
	var grid := GridContainer.new()
	grid.columns = LIST_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	room.add_child(grid)
	var new_tile := _tile("新しく作る", LIST_TILE_SIZE)
	new_tile.name = "NewTile"
	var plus := MenuStyle.bold_label("＋", 54, MenuStyle.COLOR_TEXT, 6)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus.offset_bottom = -20.0
	new_tile.add_child(plus)
	new_tile.pressed.connect(func() -> void:
		close_list()
		start_new())
	grid.add_child(new_tile)
	var first: Button = new_tile
	for identifier in MyPururins.ids():
		var tile := _tile(str(MyPururins.pururin_by_id(identifier)["display_name"]), LIST_TILE_SIZE)
		tile.name = "Open_%s" % identifier
		tile.toggle_mode = true
		tile.button_pressed = identifier == str(_entry.get("id", ""))
		if tile.button_pressed:
			first = tile
		_set_tile_picture(tile, PortraitCache.texture_for(identifier, get_tree()))
		tile.pressed.connect(func() -> void:
			close_list()
			open_pururin(identifier))
		grid.add_child(tile)
	first.grab_focus.call_deferred()


func close_list() -> void:
	if _list_window == null:
		return
	_list_window.queue_free()
	_list_window = null
	_focus_page.call_deferred()


## 左：選ぶ種類と、部品の置き場所。
func _build_tabs() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Tabs"
	panel.custom_minimum_size.x = TAB_WIDTH
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(10.0, 12.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	for tab: Array in TABS:
		var button := MenuStyle.pill_button(str(tab[1]), "tab", 17)
		button.name = "Tab_%s" % tab[0]
		button.toggle_mode = true
		button.pressed.connect(show_tab.bind(str(tab[0])))
		UIAudio.bind_button_sound(button, "confirmation")
		column.add_child(button)
		_tab_buttons[str(tab[0])] = button
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var caption := MenuStyle.label("自分の部品", 13, MenuStyle.COLOR_DIM)
	caption.add_theme_constant_override("outline_size", 0)
	caption.tooltip_text = ProjectSettings.globalize_path(UserParts.folder())
	caption.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(caption)
	for item: Array in [["OpenFolderButton", "フォルダを開く", open_parts_folder], ["ReloadPartsButton", "読み直す", reload_parts]]:
		var button := MenuStyle.pill_button(str(item[1]), "secondary", 13)
		button.name = str(item[0])
		button.pressed.connect(item[2])
		UIAudio.bind_button_sound(button, "confirmation")
		column.add_child(button)
	_problems_button = MenuStyle.pill_button("", "secondary", 13)
	_problems_button.name = "ProblemsButton"
	_problems_button.add_theme_color_override("font_color", COLOR_WARN)
	_problems_button.pressed.connect(show_problems)
	column.add_child(_problems_button)
	return panel


## まん中：回る下見と、表情の切り替え、知らせ。
func _build_preview() -> Control:
	var panel := PanelContainer.new()
	panel.name = "PreviewPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(10.0, 10.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	_name_label = MenuStyle.bold_label("", 22, MenuStyle.COLOR_TEXT, 6)
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name_label)
	_portrait = Portrait.new()
	_portrait.name = "Preview"
	_portrait.live = true
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_portrait)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var expressions: Array = PururinLookConfig.values()["expression_names"]
	row.add_child(_small_button("◀", func() -> void: _step_expression(-1, expressions.size())))
	_expression_label = MenuStyle.label("", 16, MenuStyle.COLOR_TEXT)
	_expression_label.name = "ExpressionLabel"
	_expression_label.custom_minimum_size.x = 210.0
	_expression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_expression_label)
	row.add_child(_small_button("▶", func() -> void: _step_expression(1, expressions.size())))
	_message = MenuStyle.label("", 14, MenuStyle.COLOR_ACCENT)
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	return panel


func _small_button(text: String, action: Callable) -> Button:
	var button := MenuStyle.button(text, 14, MenuStyle.COLOR_BUTTON_QUIET)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(38.0, 32.0)
	button.pressed.connect(action)
	return button


func _step_expression(direction: int, count: int) -> void:
	_expression_index = posmod(_expression_index + direction, count)
	_refresh_preview()


# ---------------------------------------------------------------- ページ

## 種類のページを開く。
func show_tab(tab: String) -> void:
	_tab = tab
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab)
	_build_page()


func _build_page() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	for child in _thumb_holder.get_children():
		child.queue_free()
	_choices.clear()
	_texts.clear()
	match _tab:
		"basic": _build_basic_page()
		"stats": _build_stats_page()
		"color": _build_color_page()
		"top", "sides", "tail": _build_part_page(_tab)
		"face": _build_face_page()
		"marks": _build_marks_page()
	_refresh_page()
	_focus_page.call_deferred()


## ページの中で、選んでいるもの（無ければ最初のもの）にカーソルを置く。
func _focus_page() -> void:
	for choice: Dictionary in _choices:
		if (choice["chosen"] as Callable).call():
			(choice["button"] as Button).grab_focus()
			return
	var first := _first_focusable(_page)
	if first != null:
		first.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL and (child as Control).is_visible_in_tree():
			return child
		var found := _first_focusable(child)
		if found != null:
			return found
	return null


func _heading(text: String) -> Label:
	var label := MenuStyle.bold_label(text, 16, MenuStyle.COLOR_DIM, 0)
	_page.add_child(label)
	return label


## 横に並べる、文字の選択肢（属性・脚質・質感など）。
func _pill_choices(holder: Container, items: Array, current: Callable, choose: Callable) -> void:
	for item: Array in items:
		var button := MenuStyle.pill_button(str(item[1]), "tab", 17)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Variant = item[0]
		button.pressed.connect(func() -> void: _apply(func() -> void: choose.call(value)))
		UIAudio.bind_button_sound(button, "confirmation")
		holder.add_child(button)
		_choices.append({"button": button, "chosen": func() -> bool: return current.call() == value})


## 中身を替えて、下見と印を出し直す。
func _apply(change: Callable) -> void:
	change.call()
	_delete_armed = false
	_refresh_page()
	_refresh_preview()


## 横の並び。title があれば、左に見出しを付ける。
func _row(title: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page.add_child(row)
	if not title.is_empty():
		var label := MenuStyle.bold_label(title, 16, MenuStyle.COLOR_DIM, 0)
		label.custom_minimum_size.x = ROW_TITLE_WIDTH
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
	return row


# --- 基本

func _build_basic_page() -> void:
	var name_row := _row("名前")
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.max_length = int(MakerConfig.values()["name_max_length"])
	name_edit.placeholder_text = "名前を入れる"
	name_edit.text = str(_entry["display_name"])
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void:
		_entry["display_name"] = text.strip_edges()
		_refresh_preview())
	name_row.add_child(name_edit)
	var attributes: Dictionary = PururinStatsConfig.values()["attributes"]
	var attribute_items: Array = []
	for attribute_id: String in attributes:
		attribute_items.append([attribute_id, str(attributes[attribute_id]["label"])])
	_pill_choices(_row("属性"), attribute_items, func() -> String: return str(_entry["attribute"]), func(value: Variant) -> void:
		_entry["attribute"] = str(value)
		_entry["look"]["primary_color_index"] = mini(int(_entry["look"]["primary_color_index"]), _primary_colors().size() - 1))
	var styles: Dictionary = PururinStatsConfig.values()["running_styles"]
	var style_items: Array = []
	for style_id: String in styles:
		style_items.append([style_id, str(styles[style_id]["label"])])
	_pill_choices(_row("脚質"), style_items, func() -> String: return str(_entry["running_style"]), func(value: Variant) -> void: _entry["running_style"] = str(value))
	_heading("元にする（押すと、能力と見た目を写します。名前はそのまま）")
	var bases: Array[String] = []
	for pururin: Dictionary in PururinRosterConfig.values().get("roster", []):
		bases.append(str(pururin["id"]))
	bases.append_array(MyPururins.ids())
	var grid := _tile_grid(TILE_COLUMNS + 1)
	for base_id in bases:
		var tile := _tile(str(PururinRosterConfig.pururin_by_id(base_id).get("display_name", base_id)), SMALL_TILE_SIZE)
		_set_tile_picture(tile, PortraitCache.texture_for(base_id, get_tree()))
		tile.pressed.connect(func() -> void:
			_copy_from(base_id)
			_read_marks()
			_show_message("%s を写しました" % PururinRosterConfig.pururin_by_id(base_id).get("display_name", ""), false)
			_refresh_preview())
		grid.add_child(tile)


# --- 能力

## 上：レース選択の詳細と同じ形の、8本の棒（1つの枠に横に並べる）。左右で選び、上下で1点ずつ増やす・減らす。
## マウスは、棒の段をクリックでその高さに、ホイールで1点ずつ。下：選んでいる能力の説明。
func _build_stats_page() -> void:
	var points := MenuStyle.bold_label("", 17, MenuStyle.COLOR_TEXT, 0)
	points.name = "PointsLabel"
	_page.add_child(points)
	_texts.append({"label": points, "text": func() -> String:
		points.add_theme_color_override("font_color", MenuStyle.COLOR_TEXT if _points_left() == 0 else COLOR_WARN)
		var stats := PururinStatsConfig.values()
		var bonus := 0
		for stat_id: String in stats["stat_ids"]:
			bonus += PururinStatsMath.with_attribute_bonus(str(_entry["attribute"]), stat_id, int(_entry["allocation"][stat_id])) - int(_entry["allocation"][stat_id])
		var total := int(stats["allocation_total"])
		return "のこり %d 点　（配る点 %d ＋ 属性のおまけ %d ＝ %d）" % [_points_left(), total, bonus, total + bonus]})
	var bars_panel := PanelContainer.new()
	bars_panel.name = "StatBars"
	bars_panel.custom_minimum_size.y = STAT_BARS_HEIGHT
	bars_panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(8.0, 8.0))
	_page.add_child(bars_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 2)
	bars_panel.add_child(columns)
	for stat_id: String in PururinStatsConfig.values()["stat_ids"]:
		columns.add_child(_stat_column(stat_id))
	var about := PanelContainer.new()
	about.name = "StatAbout"
	about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	about.add_theme_stylebox_override("panel", MenuStyle.panel_box(16.0, 12.0))
	_page.add_child(about)
	var about_column := VBoxContainer.new()
	about_column.add_theme_constant_override("separation", 8)
	about.add_child(about_column)
	var title := MenuStyle.bold_label("", 20, MenuStyle.COLOR_TEXT, 0)
	title.name = "StatTitle"
	about_column.add_child(title)
	_texts.append({"label": title, "text": func() -> String:
		var given := int(_entry["allocation"][_selected_stat])
		var total := PururinStatsMath.with_attribute_bonus(str(_entry["attribute"]), _selected_stat, given)
		var name := str(PururinDetail.STAT_LABELS.get(_selected_stat, _selected_stat))
		return "%s　%d" % [name, total] if total == given else "%s　%d（配った点 %d ＋ 属性のおまけ %d）" % [name, total, given, total - given]})
	var text := MenuStyle.label("", 16, MenuStyle.COLOR_DIM)
	text.name = "StatText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	about_column.add_child(text)
	_texts.append({"label": text, "text": func() -> String:
		return str(MakerConfig.values()["labels"]["stat_descriptions"].get(_selected_stat, ""))})
	var hint := MenuStyle.label("マウス：棒の段をクリックで、その高さに。ホイールで 1点ずつ。", 14, MenuStyle.COLOR_DIM)
	hint.name = "StatHint"
	hint.add_theme_constant_override("outline_size", 0)
	about_column.add_child(hint)


## 能力1本ぶん（数字・段・名前）。カーソルや、押して選ぶ。選んでいると、水色の縁。
func _stat_column(stat_id: String) -> Button:
	var column := Button.new()
	column.name = "Stat_%s" % stat_id
	column.toggle_mode = true
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clear := MenuStyle.box(Color(0.0, 0.0, 0.0, 0.0), 8, 0.0, 0.0)
	var chosen := MenuStyle.card_box(Color(0.12, 0.3, 0.42, 0.6), COLOR_CHOSEN, 8)
	for state in ["normal", "hover"]:
		column.add_theme_stylebox_override(state, clear)
	for state in ["pressed", "hover_pressed"]:
		column.add_theme_stylebox_override(state, chosen)
	column.add_theme_stylebox_override("focus", MenuStyle.focus_box(10))
	var bar := Control.new()
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_stat_bar.bind(bar, stat_id))
	column.add_child(bar)
	var choose := func() -> void:
		_selected_stat = stat_id
		_refresh_page()
	column.pressed.connect(choose)
	column.focus_entered.connect(choose)
	column.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_up", true):
			column.accept_event()
			_apply(_step_stat.bind(1, stat_id))
		elif event.is_action_pressed("ui_down", true):
			column.accept_event()
			_apply(_step_stat.bind(-1, stat_id))
		elif event is InputEventMouseButton and event.pressed:
			_on_stat_mouse(event, column, bar, stat_id))
	_choices.append({"button": column, "chosen": func() -> bool: return _selected_stat == stat_id})
	# 中身を替えたら、描き直す。
	_texts.append({"label": column, "text": func() -> String:
		bar.queue_redraw()
		return ""})
	return column


func _draw_stat_bar(bar: Control, stat_id: String) -> void:
	var font := get_theme_default_font()
	var value := PururinStatsMath.with_attribute_bonus(str(_entry["attribute"]), stat_id, int(_entry["allocation"][stat_id]))
	var bonus_stats: Array = PururinStatsConfig.values()["attributes"][_entry["attribute"]]["bonus_stats"]
	var attribute_color := Color.from_string(str(PururinStatsConfig.values()["attributes"][_entry["attribute"]]["color"]), Color.WHITE)
	var bonus_color := PururinDetail.bonus_bar_color(str(_entry["attribute"]), attribute_color)
	var center_x := bar.size.x * 0.5
	var number := str(value)
	var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	_draw_outlined(bar, font, number, Vector2(center_x - number_width * 0.5, 20.0), 19, MenuStyle.COLOR_TEXT)
	var bar_top := STAT_BAR_TOP
	var bar_height := maxf(bar.size.y - bar_top - PururinDetail.BAR_BOTTOM_MARGIN, 0.0)
	var segments := PururinDetail.bar_segment_count()
	var segment_height := (bar_height - PururinDetail.BAR_SEGMENT_GAP * float(segments - 1)) / float(segments)
	var filled := PururinDetail.bar_filled_segments(value)
	for segment in segments:
		var top := bar_top + bar_height - segment_height * float(segment + 1) - PururinDetail.BAR_SEGMENT_GAP * float(segment)
		var rect := Rect2(Vector2(center_x - PururinDetail.BAR_WIDTH * 0.5, top), Vector2(PururinDetail.BAR_WIDTH, segment_height))
		match PururinDetail.bar_segment_kind(stat_id in bonus_stats, filled, segment):
			"bonus":
				bar.draw_rect(rect, bonus_color)
			"filled":
				bar.draw_rect(rect, PururinDetail.COLOR_BAR)
			"locked":
				bar.draw_rect(rect, PururinDetail.COLOR_BAR_LOCKED)
				bar.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(rect.size.x, 0.0), PururinDetail.COLOR_BAR_LOCKED_LINE, 1.0)
			_:
				bar.draw_rect(rect, PururinDetail.COLOR_BAR_TRACK)
	var label := str(PururinDetail.STAT_LABELS.get(stat_id, stat_id))
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_draw_outlined(bar, font, label, Vector2(center_x - label_width * 0.5, bar.size.y - 4.0), 13, MenuStyle.COLOR_DIM)


## マウス：ホイールで1点ずつ、左クリックで、押した段の高さに。
func _on_stat_mouse(event: InputEventMouseButton, column: Button, bar: Control, stat_id: String) -> void:
	var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else (-1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
	if direction != 0:
		column.accept_event()
		_selected_stat = stat_id
		_apply(_step_stat.bind(direction, stat_id))
	elif event.button_index == MOUSE_BUTTON_LEFT:
		var segment := _segment_at(bar, event.position.y)
		if segment >= 0:
			_selected_stat = stat_id
			_apply(_set_stat_to_segment.bind(stat_id, segment))


## 棒の、その高さ（上からの位置）にある段（下から0）。段の外なら -1。
func _segment_at(bar: Control, y: float) -> int:
	var bar_height := maxf(bar.size.y - STAT_BAR_TOP - PururinDetail.BAR_BOTTOM_MARGIN, 0.0)
	var from_bottom := STAT_BAR_TOP + bar_height - y
	if from_bottom < 0.0 or from_bottom > bar_height:
		return -1
	return clampi(int(from_bottom / (bar_height / float(PururinDetail.bar_segment_count()))), 0, PururinDetail.bar_segment_count() - 1)


## 押した段まで点を入れる（下から数えて、その段が一番上になるように）。属性のおまけの段は、配った点に数えない。
## のこりの点が足りないときは、入るところまで入れる。配れる上限・下限は越えない。
func _set_stat_to_segment(stat_id: String, segment: int) -> void:
	var stats := PururinStatsConfig.values()
	var bonus := PururinStatsMath.with_attribute_bonus(str(_entry["attribute"]), stat_id, 0)
	var wanted := clampi(segment + 1 - bonus, int(stats["allocation_min"]), int(stats["allocation_max"]))
	var current := int(_entry["allocation"][stat_id])
	if wanted > current + _points_left():
		wanted = current + _points_left()
		_show_message("のこりの点数が足りないので、入るところまで入れました", true)
	_entry["allocation"][stat_id] = wanted


func _draw_outlined(canvas: Control, font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	canvas.draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, MenuStyle.COLOR_OUTLINE)
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _step_stat(direction: int, stat_id: String) -> void:
	var stats := PururinStatsConfig.values()
	var value := int(_entry["allocation"][stat_id]) + direction
	if value < int(stats["allocation_min"]) or value > int(stats["allocation_max"]):
		return
	if direction > 0 and _points_left() <= 0:
		_show_message("のこりの点数がありません。ほかの能力を下げてから上げます", true)
		return
	_entry["allocation"][stat_id] = value


func _points_left() -> int:
	var used := 0
	for stat_id: String in _entry["allocation"]:
		used += int(_entry["allocation"][stat_id])
	return int(PururinStatsConfig.values()["allocation_total"]) - used


# --- 色

func _build_color_page() -> void:
	var body_grid := _color_grid("体の色")
	for index in _primary_colors().size():
		var swatch := _swatch(Color(str(_primary_colors()[index]["color"])), COLOR_SWATCH)
		swatch.pressed.connect(func() -> void: _apply(func() -> void: _entry["look"]["primary_color_index"] = index))
		body_grid.add_child(swatch)
		_choices.append({"button": swatch, "chosen": func() -> bool: return int(_entry["look"]["primary_color_index"]) == index})
	# 下の色。高さが「なし」のときに色を選んだら、見えるように、2つ目の高さにする。
	var lower_grid := _color_grid("下の色")
	var heights: Array = MakerConfig.values()["secondary_heights"]
	for color: String in MakerConfig.values()["secondary_colors"]:
		var swatch := _swatch(Color(color), COLOR_SWATCH)
		swatch.pressed.connect(func() -> void: _apply(_set_lower_color.bind(color, heights)))
		lower_grid.add_child(swatch)
		_choices.append({"button": swatch, "chosen": func() -> bool: return float(_entry["look"]["secondary_top_ratio"]) > 0.0 and str(_entry["look"]["secondary_color"]).to_upper() == color.to_upper()})
	var height_items: Array = []
	for height: Dictionary in heights:
		height_items.append([float(height["ratio"]), str(height["label"])])
	_pill_choices(_row("下の高さ"), height_items, func() -> float: return float(_entry["look"]["secondary_top_ratio"]), func(value: Variant) -> void: _entry["look"]["secondary_top_ratio"] = float(value))
	var finish_items: Array = []
	for finish_id: String in PururinLookConfig.finishes():
		finish_items.append([finish_id, MakerConfig.label("finishes", finish_id)])
	_pill_choices(_row("質感"), finish_items, func() -> String: return str(_entry["look"]["finish"]), func(value: Variant) -> void: _entry["look"]["finish"] = str(value))


## 色の見本を並べる枠（題の横に、8つずつ折り返す）。
func _color_grid(title: String) -> GridContainer:
	var row := _row(title)
	var grid := GridContainer.new()
	grid.columns = COLOR_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	return grid


func _set_lower_color(color: String, heights: Array) -> void:
	_entry["look"]["secondary_color"] = color
	if float(_entry["look"]["secondary_top_ratio"]) <= 0.0 and heights.size() > 1:
		_entry["look"]["secondary_top_ratio"] = float(heights[1]["ratio"])


## 色の見本のボタン（丸）。選んでいると、水色の縁。
func _swatch(color: Color, diameter: float) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(diameter, diameter)
	var radius := int(diameter * 0.5)
	var normal := MenuStyle.box(color, radius, 0.0, 0.0)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.35)
	normal.set_border_width_all(2)
	var chosen := MenuStyle.box(color, radius, 0.0, 0.0)
	chosen.border_color = COLOR_CHOSEN
	chosen.set_border_width_all(5)
	for state in ["normal", "hover"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, chosen)
	button.add_theme_stylebox_override("focus", MenuStyle.focus_box(radius + 3))
	UIAudio.bind_button_sound(button, "confirmation")
	return button


# --- 頭・横・しっぽ

func _build_part_page(key: String) -> void:
	_heading("%s（＊は自分で用意した部品）" % _tab_label(key))
	var grid := _tile_grid(TILE_COLUMNS)
	var choices: Array = [null]
	for part_id: String in PururinLookConfig.parts():
		if str(PururinLookConfig.parts()[part_id]["slot"]) == BODY_PART_SLOTS[key]:
			choices.append(part_id)
	for part_id: Variant in choices:
		var tile := _tile("なし" if part_id == null else _part_label(str(part_id)))
		var look: Dictionary = _entry["look"].duplicate(true)
		look[key] = _placement(key, part_id)
		_thumbnail(tile, look, key)
		tile.pressed.connect(func() -> void: _apply(func() -> void: _entry["look"][key] = _placement(key, part_id)))
		grid.add_child(tile)
		_choices.append({"button": tile, "chosen": func() -> bool: return _current_part(key) == part_id})


func _current_part(key: String) -> Variant:
	return null if _entry["look"][key] == null else str(_entry["look"][key]["part"])


## 部品の付け方。元の置き方（高さ・角度）があれば、そのまま使う。
func _placement(key: String, part_id: Variant) -> Variant:
	if part_id == null:
		return null
	var placement := {"part": part_id, "params": {}}
	var placements: Dictionary = MakerConfig.values()["placements"]
	if placements.has(key):
		placement.merge(placements[key])
	if _entry["look"][key] != null:
		for spot_key: String in ["yaw_deg", "height_ratio"]:
			if _entry["look"][key].has(spot_key):
				placement[spot_key] = _entry["look"][key][spot_key]
	return placement


func _part_label(part_id: String) -> String:
	var user_labels: Dictionary = PururinLookConfig.values().get("user_labels", {})
	return "%s＊" % user_labels[part_id] if user_labels.has(part_id) else MakerConfig.label("parts", part_id)


func _tab_label(key: String) -> String:
	for tab: Array in TABS:
		if tab[0] == key:
			return str(tab[1])
	return key


# --- 顔

func _build_face_page() -> void:
	_heading("顔（＊は自分で用意した部品。表情は、まん中の ◀ ▶ で確かめる）")
	var slot_row := _row()
	for item: Array in FACE_SLOT_TABS:
		var slot := str(item[0])
		var button := MenuStyle.pill_button(str(item[1]), "tab", 17)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_face_slot = slot
			_build_page())
		UIAudio.bind_button_sound(button, "confirmation")
		slot_row.add_child(button)
		_choices.append({"button": button, "chosen": func() -> bool: return _face_slot == slot})
	var grid := _tile_grid(TILE_COLUMNS)
	var families := _face_families(_face_slot)
	for family_id: String in families:
		var family: Dictionary = families[family_id]
		var tile := _tile(str(family["label"]))
		var look: Dictionary = _entry["look"].duplicate(true)
		_put_face_family(look, _face_slot, family)
		_thumbnail(tile, look, "face")
		var slot := _face_slot
		tile.pressed.connect(func() -> void: _apply(func() -> void: _put_face_family(_entry["look"], slot, family)))
		grid.add_child(tile)
		_choices.append({"button": tile, "chosen": func() -> bool: return _is_face_family(_entry["look"], slot, family)})


## その場所で選べる顔の部品（組み込みのあとに、自分で用意したもの。名前に ＊）。
func _face_families(slot: String) -> Dictionary:
	var families: Dictionary = (MakerConfig.values()["face_parts"][slot] as Dictionary).duplicate()
	var user_parts: Dictionary = PururinLookConfig.values().get("user_face_parts", {}).get(slot, {})
	for family_id: String in user_parts:
		var family: Dictionary = (user_parts[family_id] as Dictionary).duplicate()
		family["label"] = "%s＊" % family["label"]
		families[family_id] = family
	return families


## 見た目の顔の、その場所を、顔の部品に入れ替える。表情ごとに、部品の絵を入れる（絵の無い表情は書かず、ノーマルを出す）。
func _put_face_family(look: Dictionary, slot: String, family: Dictionary) -> void:
	var expressions: Dictionary = look["face"]["expressions"]
	var pictures: Dictionary = family["expressions"]
	for expression: String in PururinLookConfig.values()["expression_names"]:
		if expressions.has(expression):
			(expressions[expression] as Dictionary).erase(slot)
		if pictures.get(expression) != null:
			if not expressions.has(expression):
				expressions[expression] = {}
			expressions[expression][slot] = pictures[expression]


## 見た目の顔の、その場所が、その顔の部品と同じか。
func _is_face_family(look: Dictionary, slot: String, family: Dictionary) -> bool:
	var expressions: Dictionary = look["face"]["expressions"]
	for expression: String in PururinLookConfig.values()["expression_names"]:
		if (expressions.get(expression, {}) as Dictionary).get(slot) != family["expressions"].get(expression):
			return false
	return true


# --- マーク

func _build_marks_page() -> void:
	var spots: Array = MakerConfig.values()["mark_spots"]
	var spot_items: Array = []
	for index in spots.size():
		spot_items.append([index, str(spots[index]["label"])])
	var spot_row := _row("場所")
	for item: Array in spot_items:
		var button := MenuStyle.pill_button(str(item[1]), "tab", 17)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spot_index := int(item[0])
		# 場所を替えると、その場所から見た絵に写し直す。
		button.pressed.connect(func() -> void:
			_mark_spot = spot_index
			_build_page())
		UIAudio.bind_button_sound(button, "confirmation")
		spot_row.add_child(button)
		_choices.append({"button": button, "chosen": func() -> bool: return _mark_spot == spot_index})
	var color_row := _row("色")
	var colors: Array = MakerConfig.values()["mark_colors"]
	for color: String in colors:
		var swatch := _swatch(Color(color), 40.0)
		swatch.pressed.connect(func() -> void: _apply(_set_mark_color.bind(color)))
		color_row.add_child(swatch)
		_choices.append({"button": swatch, "chosen": func() -> bool: return str(_mark_slots[_mark_spot].get("color", "")).to_upper() == color})
	var grid := _tile_grid(TILE_COLUMNS + 1)
	var choices: Array = [null]
	for part_id: String in PururinLookConfig.parts():
		if str(PururinLookConfig.parts()[part_id]["slot"]) == "mark":
			choices.append(part_id)
	var view: Dictionary = THUMB_VIEWS["marks"].duplicate()
	view["yaw"] = float(spots[_mark_spot]["yaw_deg"])
	for part_id: Variant in choices:
		var tile := _tile("なし" if part_id == null else _part_label(str(part_id)), SMALL_TILE_SIZE)
		var slots := _mark_slots.duplicate(true)
		slots[_mark_spot] = _mark_for(_mark_spot, part_id)
		var look: Dictionary = _entry["look"].duplicate(true)
		look["marks"] = _marks_from(slots)
		_thumbnail(tile, look, "marks", view)
		tile.pressed.connect(func() -> void: _apply(func() -> void:
			_mark_slots[_mark_spot] = _mark_for(_mark_spot, part_id)
			_write_marks()))
		grid.add_child(tile)
		_choices.append({"button": tile, "chosen": func() -> bool:
			var mark: Dictionary = _mark_slots[_mark_spot]
			return (null if mark.is_empty() else str(mark["part"])) == part_id})


## 場所に置くマーク（part_id が null なら、空）。色は、今の色のまま。
func _mark_for(spot_index: int, part_id: Variant) -> Dictionary:
	if part_id == null:
		return {}
	var spot: Dictionary = MakerConfig.values()["mark_spots"][spot_index]
	var color := str(_mark_slots[spot_index].get("color", MakerConfig.values()["mark_colors"][0]))
	return {"part": part_id, "yaw_deg": spot["yaw_deg"], "height_ratio": spot["height_ratio"], "size": spot["size"], "color": color}


func _set_mark_color(color: String) -> void:
	if _mark_slots[_mark_spot].is_empty():
		_show_message("先にマークを選んでください", true)
		return
	_mark_slots[_mark_spot]["color"] = color
	_write_marks()


## 場所ごとのマークを、見た目の設定の並びにする（無い場所は入れない）。
func _marks_from(slots: Array) -> Array:
	var marks: Array = []
	for mark: Dictionary in slots:
		if not mark.is_empty():
			marks.append(mark)
	return marks


func _write_marks() -> void:
	_entry["look"]["marks"] = _marks_from(_mark_slots)


## 見た目の設定のマークを、向き（yaw_deg）が同じ場所に入れる。どの場所にも合わないマーク（前の、顔のそばのマークなど）は外す。
func _read_marks() -> void:
	var spots: Array = MakerConfig.values()["mark_spots"]
	_mark_slots = []
	for spot: Dictionary in spots:
		var found := {}
		for mark: Dictionary in _entry["look"]["marks"]:
			if is_equal_approx(float(mark["yaw_deg"]), float(spot["yaw_deg"])):
				found = mark.duplicate()
				break
		_mark_slots.append(found)
	_write_marks()


# ---------------------------------------------------------------- タイルと絵

## タイルの並び。ページの残りの高さに収める（自分の部品やぷるりんが多くて、はみ出すときだけ、縦に送れる）。
func _tile_grid(columns: int) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "TileScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_page.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return grid


## 絵と名前のタイル。選んでいると、水色の縁。
func _tile(text: String, tile_size: Vector2 = TILE_SIZE) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.custom_minimum_size = tile_size
	tile.clip_contents = false
	tile.add_theme_stylebox_override("normal", MenuStyle.card_box(MenuStyle.COLOR_CARD, Color(1.0, 1.0, 1.0, 0.18), 10))
	tile.add_theme_stylebox_override("hover", MenuStyle.card_box(MenuStyle.COLOR_CARD.lightened(0.08), Color(1.0, 1.0, 1.0, 0.4), 10))
	var chosen := MenuStyle.card_box(Color(0.12, 0.3, 0.42, 0.95), COLOR_CHOSEN, 10)
	chosen.set_border_width_all(4)
	tile.add_theme_stylebox_override("pressed", chosen)
	tile.add_theme_stylebox_override("hover_pressed", chosen)
	tile.add_theme_stylebox_override("focus", MenuStyle.focus_box(12))
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.offset_bottom = -20.0
	tile.add_child(picture)
	var caption := MenuStyle.label(text, 12, MenuStyle.COLOR_TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -22.0
	caption.offset_left = 2.0
	caption.offset_right = -2.0
	tile.add_child(caption)
	tile.tooltip_text = text
	UIAudio.bind_button_sound(tile, "confirmation")
	return tile


func _set_tile_picture(tile: Button, texture: Texture2D) -> void:
	(tile.get_node("Picture") as TextureRect).texture = texture


## その見た目の体を写して、タイルの絵にする。kind は、写し方（THUMB_VIEWS）。
func _thumbnail(tile: Button, look: Dictionary, kind: String, view: Dictionary = {}) -> void:
	var setting: Dictionary = view if not view.is_empty() else THUMB_VIEWS[kind]
	var viewport := Stage.make(THUMB_PX, float(setting["view"]))
	_thumb_holder.add_child(viewport)
	var body := PururinBodyBuilder.build(PururinLookConfig.resolved_look(look, _primary_colors()), PururinLookConfig.values())
	# 持ち上げると、写る場所が下へずれる（顔を、絵のまん中にする）。
	body.position.y = float(setting["lift"])
	var table := Stage.turntable(viewport)
	table.rotation.y = deg_to_rad(float(setting["yaw"]))
	table.position.x = float(setting["shift"])
	table.add_child(body)
	body.call("set_expression", "normal")
	_set_tile_picture(tile, viewport.get_texture())
	_take_picture(viewport)


func _take_picture(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _frame in THUMB_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# ---------------------------------------------------------------- 写す・一覧・開く

## 個体の能力と見た目を、今つくっているぷるりんに写す（名前とIDは、そのまま）。
func _copy_from(pururin_id: String) -> void:
	var pururin := PururinRosterConfig.pururin_by_id(pururin_id)
	var saved := MyPururins.entry(pururin_id)
	_entry["trainer_id"] = str(pururin["trainer_id"])
	_entry["attribute"] = str(pururin["attribute"])
	_entry["running_style"] = str(pururin["running_style"])
	_entry["allocation"] = (pururin["allocation"] as Dictionary).duplicate(true)
	if not saved.is_empty():
		_entry["look"] = saved["look"]
	else:
		var look := PururinLookConfig.look_for(pururin_id).duplicate(true)
		# 色に直した項目は、保存の形には入れない（番号で持つ）。
		look.erase("primary_color")
		look.erase("outline_color")
		_entry["look"] = look


func _refresh_list() -> void:
	_list_button.text = "一覧（%d 体）　いま：%s" % [MyPururins.ids().size(), str(_entry["display_name"]) if _saved else "新しいぷるりん"]
	var count := _problems().size()
	_problems_button.text = "使えない %d 件" % count
	_problems_button.visible = count > 0


func _problems() -> Array[String]:
	var problems: Array[String] = []
	for problem in MyPururins.errors():
		problems.append("使えない保存: " + problem)
	for problem: String in PururinLookConfig.values().get("user_part_errors", []):
		problems.append("使えない部品: " + problem)
	return problems


func show_problems() -> void:
	_show_message("\n".join(_problems()), true)


## 新しいぷるりんを、元の個体（設定の base_pururin）を写して始める。
func start_new() -> void:
	_entry = {"schema_version": MyPururins.SCHEMA_VERSION, "id": MyPururins.new_id(), "display_name": ""}
	_copy_from(str(MakerConfig.values()["base_pururin"]))
	_entry["display_name"] = "ぷるりん%d" % (MyPururins.ids().size() + 1)
	_saved = false
	_open_entry()


## 保存したぷるりんを開いて、直す。
func open_pururin(identifier: String) -> void:
	_entry = MyPururins.entry(identifier)
	if _entry.is_empty():
		return
	_saved = true
	_open_entry()


func _open_entry() -> void:
	_delete_armed = false
	_mark_spot = 0
	_read_marks()
	_refresh_list()
	_refresh_preview()
	show_tab(_tab)


# ---------------------------------------------------------------- 見せる

## 今のページの、選んでいる印と文字を出し直す。
func _refresh_page() -> void:
	for choice: Dictionary in _choices:
		(choice["button"] as Button).set_pressed_no_signal((choice["chosen"] as Callable).call())
	for item: Dictionary in _texts:
		item["label"].text = str((item["text"] as Callable).call())


func _refresh_preview() -> void:
	_delete_button.disabled = not _saved
	_delete_button.text = "もう一度で消す" if _delete_armed else "消す"
	var expressions: Array = PururinLookConfig.values()["expression_names"]
	_portrait.set("fixed_expression", str(expressions[_expression_index]))
	_portrait.call("set_pururin", {"id": str(_entry["id"]), "look": PururinLookConfig.resolved_look(_entry["look"], _primary_colors())})
	_name_label.text = str(_entry["display_name"]) if not str(_entry["display_name"]).is_empty() else "名前なし"
	_expression_label.text = "表情：%s" % MakerConfig.label("expressions", str(expressions[_expression_index]))


func _primary_colors() -> Array:
	return PururinStatsConfig.primary_colors(str(_entry["attribute"]))


func _show_message(text: String, warn: bool) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", COLOR_WARN if warn else MenuStyle.COLOR_ACCENT)


# ---------------------------------------------------------------- 保存・消す・部品

func save() -> void:
	if str(_entry["display_name"]).is_empty():
		_show_message("名前を入れてください（基本のページ）", true)
		return
	if _points_left() != 0:
		_show_message("能力の点数を、ちょうど使い切ってください（のこり %d 点）" % _points_left(), true)
		return
	var error := MyPururins.save(_entry)
	if not error.is_empty():
		_show_message("保存できません: " + error, true)
		return
	_saved = true
	PortraitCache.forget(str(_entry["id"]))
	_show_message("%s を保存しました。レース選択で選べます" % _entry["display_name"], false)
	_refresh_list()
	_refresh_preview()


## 1回目は確かめるだけ。2回目で消す。
func request_delete() -> void:
	if not _saved:
		return
	if not _delete_armed:
		_delete_armed = true
		_refresh_preview()
		return
	var name := str(_entry["display_name"])
	var error := MyPururins.remove(str(_entry["id"]))
	if not error.is_empty():
		_show_message(error, true)
		return
	PortraitCache.forget(str(_entry["id"]))
	start_new()
	_show_message("%s を消しました" % name, false)


func open_parts_folder() -> void:
	var error := UserParts.make_folders()
	if not error.is_empty():
		_show_message(error, true)
		return
	OS.shell_open(ProjectSettings.globalize_path(UserParts.folder()))


## 置き場所の部品を読み直す（置いたり消したりしたあと）。今つくっているぷるりんは、そのまま。
func reload_parts() -> void:
	var keep := _entry.duplicate(true)
	var saved := _saved
	PururinLookConfig.reload()
	MyPururins.reload()
	_entry = keep
	_saved = saved
	var errors := PururinLookConfig.validate_single_look(_entry["look"], _primary_colors())
	if not errors.is_empty():
		# 使っていた部品が無くなったときは、元の個体から始め直す（黙って別の部品にはしない）。
		start_new()
		_show_message("使っていた部品が読めないので、新しく作り直します: " + "; ".join(errors), true)
		return
	_open_entry()
	_show_message("部品を読み直しました" + ("（使えないものは、左の赤いボタンで理由を出します）" if not _problems().is_empty() else ""), false)


func go_back() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


## いま選んでいる場所に、光る枠を重ねる（ゆっくり明るくなったり暗くなったりする）。
func _update_focus_ring() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	_focus_ring.visible = owner != null and owner.is_visible_in_tree() and not owner is LineEdit
	if not _focus_ring.visible:
		return
	var rect := owner.get_global_rect().grow(FOCUS_RING_ROOM)
	_focus_ring.position = rect.position
	_focus_ring.size = rect.size
	_focus_ring.modulate.a = 0.65 + 0.35 * sin(_ring_time * TAU / FOCUS_RING_SECONDS)


func _process(delta: float) -> void:
	_ring_time += delta
	_update_focus_ring()
	# 一覧の窓を開いている間は、選ぶ場所を窓の中だけにする。
	if _list_window != null:
		var owner := get_viewport().gui_get_focus_owner()
		if owner == null or not _list_window.is_ancestor_of(owner):
			var tile := _first_focusable(_list_window)
			if tile != null:
				tile.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if _list_window != null:
		if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
			viewport.set_input_as_handled()
		elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event) or RaceControllerInput.is_face_pressed(event, JOY_BUTTON_X):
			UIAudio.play_back()
			close_list()
			viewport.set_input_as_handled()
		return
	var step := RaceControllerInput.distance_step(event)
	if step != 0:
		var index := 0
		for tab_index in TABS.size():
			if TABS[tab_index][0] == _tab:
				index = tab_index
		show_tab(str(TABS[posmod(index + step, TABS.size())][0]))
		UIAudio.play_selection_cycle()
		viewport.set_input_as_handled()
		return
	# L2・R2（キーボードは PageUp・PageDown）で、表情を切り替える。
	var face_step := RaceControllerInput.slot_move_direction(event)
	if face_step != 0:
		_step_expression(face_step, (PururinLookConfig.values()["expression_names"] as Array).size())
		UIAudio.play_selection_cycle()
		viewport.set_input_as_handled()
		return
	if viewport.gui_get_focus_owner() is LineEdit and not RaceControllerInput.is_cancel_pressed(event):
		return
	if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
	elif RaceControllerInput.is_face_pressed(event, JOY_BUTTON_Y):
		UIAudio.play_confirmation()
		save()
		viewport.set_input_as_handled()
	elif RaceControllerInput.is_face_pressed(event, JOY_BUTTON_X):
		UIAudio.play_confirmation()
		open_list()
		viewport.set_input_as_handled()
	elif RaceControllerInput.is_button_pressed(event, JOY_BUTTON_BACK):
		UIAudio.play_confirmation()
		request_delete()
		viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_back()
