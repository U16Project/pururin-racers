extends Control
## 強化学習：人と走る前に、CPUを選ぶ画面（play.py から起動したときだけ）。
## いちばん上の行は「あなたの枠」（レース選択で自分にした枠）。最初は「あなた」。CPUにすると、CPUだけのレースを観戦する。
## その下の7行は、相手の枠。レース選択で決まった相手の枠に、上から枠の順に当てはめる。最初は全部、本命。
## 選べるCPUの一覧（choices）は、play.py が送る：[{id, label}]。最初の1つが本命。
## ゲームパッド：上下で行を動かし、選ぶ欄では左右（または A）で切り替える。ボタンは A で押す（ゲームのメニューと同じしくみ）。

signal decided(selection: Dictionary)

const Style := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

const HUMAN := "human"
const OPPONENTS := 7

var _choices: Array = []
var _me: OptionButton
var _others: Array = []


## choices：選べるCPU。selection：前に選んだ内容（{me, others}。無ければ空）。
func setup(choices: Array, selection: Dictionary) -> void:
	_choices = choices
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.05, 0.1, 1.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.COLOR_PANEL, 14, 32.0, 24.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(Style.label("CPUを選ぶ（ラボ）", 30))
	column.add_child(Style.label("いちばん上は、あなたの枠（レース選択で自分にした枠）。CPUにすると、CPUだけのレースを観戦します。", 16, Style.COLOR_DIM))
	column.add_child(Style.label("相手1〜7は、レース選択で決まった相手の枠に、枠の順に当てはめます。", 16, Style.COLOR_DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	grid.add_child(Style.label("あなたの枠", 20))
	_me = _option(true)
	grid.add_child(_me)
	for i in OPPONENTS:
		grid.add_child(Style.label("相手%d" % (i + 1), 20))
		var option := _option(false)
		_others.append(option)
		grid.add_child(option)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var reset := Style.button("全部を本命に戻す", 20, Style.COLOR_BUTTON_QUIET)
	reset.pressed.connect(_reset)
	buttons.add_child(reset)
	var go := Style.button("決定（レース選択へ）", 20)
	go.pressed.connect(_decide)
	buttons.add_child(go)
	_select(_me, str(selection.get("me", HUMAN)))
	var saved: Array = selection.get("others", [])
	for i in OPPONENTS:
		_select(_others[i], str(saved[i]) if i < saved.size() else _main_id())
	go.grab_focus.call_deferred()


func _option(with_human: bool) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(420, 0)
	option.add_theme_font_size_override("font_size", 18)
	if with_human:
		option.add_item("あなた")
		option.set_item_metadata(0, HUMAN)
	for choice: Dictionary in _choices:
		option.add_item(str(choice["label"]))
		option.set_item_metadata(option.item_count - 1, str(choice["id"]))
	return option


func _main_id() -> String:
	return str(_choices[0]["id"]) if not _choices.is_empty() else ""


func _select(option: OptionButton, id: String) -> void:
	for i in option.item_count:
		if str(option.get_item_metadata(i)) == id:
			option.select(i)
			return
	# 前に選んだCPUが、もう無い（控え室から外れた）ときは、本命にする。
	_select_first_cpu(option)


func _select_first_cpu(option: OptionButton) -> void:
	for i in option.item_count:
		if str(option.get_item_metadata(i)) != HUMAN:
			option.select(i)
			return


func _reset() -> void:
	_select(_me, HUMAN)
	for option: OptionButton in _others:
		_select(option, _main_id())


func _decide() -> void:
	var others: Array = []
	for option: OptionButton in _others:
		others.append(str(option.get_selected_metadata()))
	decided.emit({"me": str(_me.get_selected_metadata()), "others": others})


## CPUの名前（トレーナー欄に出す）。
func label_of(id: String) -> String:
	for choice: Dictionary in _choices:
		if str(choice["id"]) == id:
			return str(choice["label"])
	return id


func _input(event: InputEvent) -> void:
	# 選ぶ欄にいるときは、左右で、選ぶものを切り替える（行の移動に取られる前に受ける）。
	var focused := get_viewport().gui_get_focus_owner()
	if focused is OptionButton and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_step(focused as OptionButton, -1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not RaceControllerInput.is_accept_pressed(event):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is OptionButton:
		_step(focused as OptionButton, 1)
		get_viewport().set_input_as_handled()
	elif RaceControllerInput.activate_focused_control(get_viewport()):
		get_viewport().set_input_as_handled()


func _step(option: OptionButton, direction: int) -> void:
	if option.item_count > 0:
		option.select(posmod(option.selected + direction, option.item_count))
