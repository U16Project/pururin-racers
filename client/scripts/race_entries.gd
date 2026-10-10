extends Control
## 出走する枠と担当の読み取り専用確認。レース選択の状態は変更しない。
const Session := preload("res://scripts/race_session.gd")
const Roster := preload("res://scripts/config/pururin_roster_config.gd")
const Profile := preload("res://scripts/config/trainer_profile.gd")
const Style := preload("res://scripts/menu/menu_style.gd")
const Detail := preload("res://scripts/menu/pururin_detail.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const InputHelper := preload("res://scripts/input/race_controller_input.gd")
const STYLE_NAMES := {"escape": "逃げ", "pace": "先行", "stalk": "差し", "closer": "追い込み"}
const ATTRIBUTE_NAMES := {"fire": "火", "water": "水", "earth": "地", "wind": "風"}
const Stats := preload("res://scripts/config/pururin_stats_config.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")
const Hud := preload("res://scripts/presentation/race_hud.gd")
## 出走表の行の、属性と脚質の印の大きさ。
const MARK_SIZE := 15.0
const CHEVRON_SCALE := 0.62
var _entries: Array = []
var _rows: Array[Button] = []
var _detail: Control
var _trainer_image: TextureRect
var _player_image: Control
var _trainer_name: Label
var _favorite: Label
var _introduction: Label
var _start: Button
var _back: Button
var _transitioning := false
var shown_gate := -1

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/race_select_background.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.35, 0.35, 0.4)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", Style.box(Style.COLOR_PANEL, 16, 18, 14))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -546
	panel.offset_right = 546
	panel.offset_top = -304
	panel.offset_bottom = 304
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Style.label("出走表　%d m" % int(Session.selected_distance_m()), 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 286
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	_entries = Session.field_entries()
	for entry: Dictionary in _entries:
		var gate := int(entry["gate"])
		var pururin := Roster.pururin_by_id(str(entry["id"]))
		var player := bool(entry["player"])
		var row := Style.button("", 16, Style.COLOR_BUTTON_QUIET)
		row.name = "Gate%d" % (gate + 1)
		row.custom_minimum_size = Vector2(286, 46)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var box: StyleBoxFlat = row.get_theme_stylebox(state).duplicate()
			box.content_margin_top = 3
			box.content_margin_bottom = 3
			row.add_theme_stylebox_override(state, box)
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 8)
		row.add_child(content)
		var portrait: Control = Portrait.new()
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		portrait.call("set_pururin", pururin)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 0)
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(names)
		var name := Style.label("%d枠 %s%s" % [gate + 1, str(pururin["display_name"]), "（自分）" if player else ""], 16)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		names.add_child(name)
		var trainer_name := Profile.trainer_name() if player else str(Session.trainer_for_slot(gate).get("name", "CPU"))
		# 属性と脚質は、名前の前に、印も付ける（属性＝詳細パネルと同じ印、脚質＝操作盤と同じ「〈」）。
		var attribute_id := str(pururin["attribute"])
		var style_id := str(pururin["running_style"])
		var summary := HBoxContainer.new()
		summary.name = "Summary"
		summary.add_theme_constant_override("separation", 3)
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		names.add_child(summary)
		var attribute_mark := Control.new()
		attribute_mark.name = "AttributeMark"
		attribute_mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
		attribute_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		attribute_mark.draw.connect(func() -> void:
			Detail.draw_attribute_mark(attribute_mark, attribute_mark.size * 0.5, MARK_SIZE, attribute_id, Color.from_string(str(Stats.values()["attributes"][attribute_id]["color"]), Color.WHITE)))
		summary.add_child(attribute_mark)
		summary.add_child(_dim_label("%s・" % ATTRIBUTE_NAMES.get(attribute_id, attribute_id)))
		var style_mark := Control.new()
		style_mark.name = "StyleMark"
		style_mark.custom_minimum_size = Vector2(Hud.STYLE_CHEVRON_STEP * CHEVRON_SCALE * StatsMath.rank_group_count() + 2.0, MARK_SIZE)
		style_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_mark.draw.connect(func() -> void:
			Hud.draw_style_chevrons(style_mark, Vector2(1.0, style_mark.size.y * 0.5), Hud.COLOR_STYLE_MATCH, StatsMath.rank_group_count(), StatsMath.style_rank_group_index(style_id), CHEVRON_SCALE))
		summary.add_child(style_mark)
		summary.add_child(_dim_label("%s　%s" % [STYLE_NAMES.get(style_id, ""), trainer_name]))
		row.focus_entered.connect(_show_entry.bind(entry))
		row.mouse_entered.connect(_show_entry.bind(entry))
		row.pressed.connect(_show_entry.bind(entry))
		list.add_child(row)
		_rows.append(row)
	_detail = Detail.new()
	_detail.name = "PururinDetail"
	_detail.custom_minimum_size.x = 410
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)
	var trainer_panel := VBoxContainer.new()
	trainer_panel.name = "TrainerDetail"
	trainer_panel.custom_minimum_size.x = 244
	trainer_panel.add_theme_constant_override("separation", 12)
	body.add_child(trainer_panel)
	trainer_panel.add_child(Style.label("トレーナー", 20, Style.COLOR_DIM))
	_trainer_image = TextureRect.new()
	_trainer_image.custom_minimum_size = Vector2(220, 220)
	_trainer_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trainer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trainer_panel.add_child(_trainer_image)
	_player_image = TrainerIcon.new()
	_player_image.custom_minimum_size = Vector2(220, 220)
	trainer_panel.add_child(_player_image)
	_trainer_name = Style.label("", 23)
	trainer_panel.add_child(_trainer_name)
	_favorite = Style.label("", 17, Style.COLOR_DIM)
	trainer_panel.add_child(_favorite)
	# 紹介文は、長めの文が入るように、小さめの字で、行を折り返して出す。
	_introduction = Style.label("", 13, Style.COLOR_DIM)
	_introduction.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_introduction.custom_minimum_size = Vector2(244, 96)
	trainer_panel.add_child(_introduction)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_back = Style.button("選択に戻る", 22, Style.COLOR_BUTTON_QUIET)
	_back.name = "BackButton"
	_back.custom_minimum_size = Vector2(286, 48)
	Style.add_mark(_back, "B")
	_back.pressed.connect(back)
	buttons.add_child(_back)
	_start = Style.button("レース開始", 22)
	_start.name = "StartButton"
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.add_mark(_start, "START")
	_start.disabled = not Session.race_start_problem().is_empty()
	_start.pressed.connect(start)
	buttons.add_child(_start)
	_link_focus()
	if not _rows.is_empty():
		_rows[0].grab_focus()
		_show_entry(_entries[0])
	else:
		_back.grab_focus()

func _show_entry(entry: Dictionary) -> void:
	shown_gate = int(entry["gate"])
	_detail.call("show_pururin", str(entry["id"]))
	var player := bool(entry["player"])
	_trainer_image.visible = not player
	_player_image.visible = player
	if player:
		_player_image.call("show_registered")
		_trainer_name.text = Profile.trainer_name()
		_trainer_name.add_theme_color_override("font_color", Color(0.5, 1, 1))
		_favorite.text = "プレイヤー操作"
		_introduction.text = Profile.introduction()
	else:
		var trainer := Session.trainer_for_slot(shown_gate)
		_trainer_image.texture = load(str(trainer.get("portrait_path", "")))
		_trainer_name.text = str(trainer.get("name", "CPU"))
		_trainer_name.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if Session.is_default_trainer(shown_gate, str(trainer.get("id", ""))) else Style.COLOR_TEXT)
		_favorite.text = "得意脚質：" + str(STYLE_NAMES.get(str(trainer.get("favorite_running_style", "")), ""))
		_introduction.text = str(trainer.get("introduction", ""))

func _link_focus() -> void:
	for index in _rows.size():
		var row := _rows[index]
		row.focus_neighbor_top = row.get_path_to(_rows[maxi(index - 1, 0)])
		row.focus_neighbor_bottom = row.get_path_to(_rows[index + 1] if index + 1 < _rows.size() else _back)
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)
	for button: Button in [_back, _start]:
		button.focus_neighbor_top = button.get_path_to(_rows.back() if not _rows.is_empty() else _back)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_neighbor_left = button.get_path_to(_back)
		button.focus_neighbor_right = button.get_path_to(_start)

func _navigate(path: String) -> void:
	get_tree().change_scene_to_file(path)

func start() -> void:
	if _transitioning or not Session.race_start_problem().is_empty():
		return
	_transitioning = true
	_navigate("res://scenes/local_race.tscn")

func back() -> void:
	if _transitioning:
		return
	_transitioning = true
	_navigate("res://scenes/race_select.tscn")

func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if InputHelper.is_menu_pressed(event):
		viewport.set_input_as_handled()
		start()
	elif event.is_action_pressed("ui_cancel") or InputHelper.is_cancel_pressed(event):
		viewport.set_input_as_handled()
		back()
	elif InputHelper.is_accept_pressed(event) and InputHelper.activate_focused_control(viewport):
		viewport.set_input_as_handled()


## 行の2段目の、小さい文字。
func _dim_label(text: String) -> Label:
	var label := Style.label(text, 13, Style.COLOR_DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

