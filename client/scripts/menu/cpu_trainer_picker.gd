extends PanelContainer
## CPUトレーナー一覧。既存判断設定は変更せず人物を選ぶ。
signal picked(identifier: String)
signal closed
const Trainers := preload("res://scripts/config/cpu_trainers_config.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const DEFAULT_COLOR := Color(0.5, 1.0, 0.6, 1.0)
const STYLE_NAMES := {"escape": "逃げ", "pace": "先行", "stalk": "差し", "closer": "追い込み"}
var selected_slot := -1
var _buttons: Array[Button] = []
var _portrait: TextureRect
var _detail_name: Label
var _favorite: Label
var _introduction: Label
var _shown_trainer_id := ""

func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", MenuStyle.box(Color(0.07, 0.1, 0.16, 0.98), 14, 18.0, 18.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(MenuStyle.label("CPUトレーナーを選ぶ", 22))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.name = "TrainerScroll"
	scroll.custom_minimum_size.x = 258
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for trainer: Dictionary in Trainers.values():
		var button := MenuStyle.button(str(trainer["name"]), 20, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = str(trainer["id"])
		button.custom_minimum_size = Vector2(224, 42)
		button.pressed.connect(func() -> void: picked.emit(str(trainer["id"])))
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 5)
		list.add_child(margin)
		margin.add_child(button)
		button.focus_entered.connect(func() -> void:
			_show_trainer(trainer)
			await get_tree().process_frame
			if is_instance_valid(button) and button.has_focus():
				scroll.ensure_control_visible(margin))
		button.mouse_entered.connect(func() -> void: _show_trainer(trainer))
		_buttons.append(button)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	body.add_child(detail)
	_portrait = TextureRect.new()
	_portrait.name = "TrainerPortrait"
	_portrait.custom_minimum_size = Vector2(220, 220)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_portrait)
	_detail_name = MenuStyle.label("", 24)
	detail.add_child(_detail_name)
	_favorite = MenuStyle.label("", 19)
	detail.add_child(_favorite)
	# 紹介文は、長めの文が入るように、小さめの字で、行を折り返して出す。
	_introduction = MenuStyle.label("", 14, MenuStyle.COLOR_DIM)
	_introduction.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_introduction.custom_minimum_size = Vector2(300, 96)
	detail.add_child(_introduction)
	var back := MenuStyle.button("閉じる（Esc／B）", 16, MenuStyle.COLOR_BUTTON_QUIET)
	back.pressed.connect(close)
	UIAudio.bind_button_sound(back, "back")
	column.add_child(back)
	for i in _buttons.size():
		var button := _buttons[i]
		button.focus_neighbor_top = button.get_path_to(_buttons[maxi(0, i - 1)])
		button.focus_neighbor_bottom = button.get_path_to(_buttons[mini(_buttons.size() - 1, i + 1)])
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_next = button.get_path_to(_buttons[(i + 1) % _buttons.size()])
		button.focus_previous = button.get_path_to(_buttons[posmod(i - 1, _buttons.size())])

func open(slot: int, current_id: String) -> void:
	selected_slot = slot
	visible = true
	for button in _buttons:
		var color := DEFAULT_COLOR if RaceSession.is_default_trainer(slot, str(button.name)) else MenuStyle.COLOR_TEXT
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, color)
	for button in _buttons:
		if button.name == current_id:
			button.grab_focus()
			return
	_buttons[0].grab_focus()

func _show_trainer(trainer: Dictionary) -> void:
	_shown_trainer_id = str(trainer["id"])
	_portrait.texture = load(str(trainer["portrait_path"])) as Texture2D
	_detail_name.text = str(trainer["name"])
	_detail_name.add_theme_color_override("font_color", DEFAULT_COLOR if RaceSession.is_default_trainer(selected_slot, _shown_trainer_id) else MenuStyle.COLOR_TEXT)
	_favorite.text = "得意な脚質：%s" % STYLE_NAMES[trainer["favorite_running_style"]]
	_introduction.text = str(trainer["introduction"])

func shown_trainer_id() -> String:
	return _shown_trainer_id

func close() -> void:
	visible = false
	closed.emit()
