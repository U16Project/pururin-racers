extends Control
## オフラインフリー対戦のレース選択画面。距離と、自分が操作するぷるりんを選んで、レースを始める。

const TITLE_SCENE_PATH := "res://scenes/title.tscn"
const RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const PANEL_SIZE := Vector2(820.0, 560.0)

var _distance_buttons: Array[Button] = []
var _pururin_option: OptionButton
var _pururin_preview: Label
var _race_button: Button
var _back_button: Button


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
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 16, 36.0, 26.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var heading := MenuStyle.label("オフラインフリー対戦", 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	content.add_child(MenuStyle.label("距離", 20, MenuStyle.COLOR_DIM))
	content.add_child(_build_distance_row())
	content.add_child(MenuStyle.label("自分のぷるりん", 20, MenuStyle.COLOR_DIM))
	_pururin_option = OptionButton.new()
	_pururin_option.name = "PururinOption"
	_pururin_option.custom_minimum_size = Vector2(0.0, 52.0)
	_pururin_option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.style_button(_pururin_option, 22, MenuStyle.COLOR_BUTTON_QUIET)
	for pururin: Variant in PururinRosterConfig.values().get("roster", []):
		if pururin is Dictionary:
			_pururin_option.add_item(str(pururin.get("display_name", "")))
	_pururin_option.select(_pururin_index(RaceSession.selected_player_pururin_id()))
	_pururin_option.item_selected.connect(_on_pururin_selected)
	content.add_child(_pururin_option)
	_pururin_preview = MenuStyle.label("", 17)
	_pururin_preview.name = "PururinPreview"
	_pururin_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pururin_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_pururin_preview)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	content.add_child(buttons)
	_back_button = MenuStyle.button("タイトルへ戻る", 22, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(240.0, 64.0)
	_back_button.pressed.connect(go_to_title)
	buttons.add_child(_back_button)
	_race_button = MenuStyle.button("レース開始", 26)
	_race_button.name = "RaceButton"
	_race_button.custom_minimum_size = Vector2(0.0, 64.0)
	_race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_button.pressed.connect(go_to_race)
	buttons.add_child(_race_button)
	_refresh_pururin_preview()
	_race_button.grab_focus()


## 距離は、横に並べたボタンから1つ選ぶ。
func _build_distance_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "DistanceRow"
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	var selected := RaceSession.selected_distance_m()
	for distance_m: float in RaceSession.supported_distances_m():
		var button := MenuStyle.button("%d m" % int(distance_m), 22, MenuStyle.COLOR_BUTTON_QUIET)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = is_equal_approx(distance_m, selected)
		button.pressed.connect(_on_distance_pressed.bind(distance_m))
		row.add_child(button)
		_distance_buttons.append(button)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_to_title()


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func go_to_race() -> void:
	get_tree().change_scene_to_file(RACE_SCENE_PATH)


func _on_distance_pressed(distance_m: float) -> void:
	RaceSession.select_distance(distance_m)


func _on_pururin_selected(index: int) -> void:
	var roster: Array = PururinRosterConfig.values().get("roster", [])
	if index >= 0 and index < roster.size() and roster[index] is Dictionary:
		RaceSession.select_player_pururin(str(roster[index].get("id", "")))
		_refresh_pururin_preview()


func _pururin_index(identifier: String) -> int:
	var roster: Array = PururinRosterConfig.values().get("roster", [])
	for index in roster.size():
		if roster[index] is Dictionary and str(roster[index].get("id", "")) == identifier:
			return index
	return 0


## 選んでいるぷるりんの、表示用の情報（名前・属性・脚質・出走前の能力）。
static func selected_pururin_preview() -> Dictionary:
	var pururin := PururinRosterConfig.pururin_by_id(RaceSession.selected_player_pururin_id())
	if pururin.is_empty():
		return {}
	var definitions := PururinStatsConfig.values()
	var attribute_id := str(pururin.get("attribute", ""))
	var style_id := str(pururin.get("running_style", ""))
	return {
		"id": str(pururin.get("id", "")),
		"display_name": str(pururin.get("display_name", "")),
		"attribute": str(definitions.get("attributes", {}).get(attribute_id, {}).get("label", attribute_id)),
		"running_style": str(definitions.get("running_styles", {}).get(style_id, {}).get("label", style_id)),
		"pre_race_stats": PururinStatsMath.pre_race_stats(attribute_id, pururin.get("allocation", {})),
	}


func _refresh_pururin_preview() -> void:
	var preview := selected_pururin_preview()
	if preview.is_empty():
		_pururin_preview.text = "個体情報を読み込めませんでした"
		return
	var stats: Dictionary = preview["pre_race_stats"]
	_pururin_preview.text = "\n".join(PackedStringArray([
		"属性：%s　脚質：%s" % [preview["attribute"], preview["running_style"]],
		"最高速 %d　加速力 %d　スタミナ %d　心肺 %d" % [
			int(stats["top_speed"]), int(stats["acceleration"]), int(stats["stamina"]), int(stats["cardio"]),
		],
		"空力 %d　集団 %d　接触耐性 %d　操作性 %d" % [
			int(stats["aero"]), int(stats["pack"]), int(stats["contact_resistance"]), int(stats["handling"]),
		],
		"（出走前の値。順位・区間の補正は、レース中に変わります）",
	]))
