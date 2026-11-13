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
const RaceScenePreload := preload("res://scripts/race_scene_preload.gd")
const STYLE_NAMES := {"escape": "逃げ", "pace": "先行", "stalk": "差し", "closer": "追い込み"}
const ATTRIBUTE_NAMES := {"fire": "火", "water": "水", "earth": "地", "wind": "風"}
const Stats := preload("res://scripts/config/pururin_stats_config.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")
const Hud := preload("res://scripts/presentation/race_hud.gd")
## パドックの行の、属性と脚質の印の大きさ。
const MARK_SIZE := 15.0
const CHEVRON_SCALE := 0.62
## 会場の上に重ねるときの、ステータスの欄の高さ・右の列の幅。
const DETAIL_HEIGHT_OVERLAY := 380.0
const RIGHT_WIDTH_OVERLAY := 470.0
## 会場の上に重ねるときの、一覧の行（幅・高さ・絵の大きさ・名前と2段目の字の大きさ・印の大きさ）。
## 一覧は、上の帯の下から画面の下まで伸ばし、行はその高さに合わせて伸びる（高さは最小）。行は枠の線を付けず、うすい地だけにする。
const ROW_WIDTH_OVERLAY := 400.0
const ROW_HEIGHT_OVERLAY := 50.0
const ROW_PORTRAIT_OVERLAY := 54.0
const ROW_NAME_SIZE_OVERLAY := 20
const ROW_SUB_SIZE_OVERLAY := 15
const MARK_SIZE_OVERLAY := 18.0
const CHEVRON_SCALE_OVERLAY := 0.75
const COLOR_ROW_OVERLAY := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_ROW_HOVER_OVERLAY := Color(1.0, 1.0, 1.0, 0.12)
var _entries: Array = []
var _rows: Array[Button] = []
var _detail: Control
var _trainer_image: TextureRect
var _player_image: Control
var _trainer_name: Label
var _favorite: Label
## トレーナー名と、その横の、誰が動かすかの札（オンラインだけ）。
var _trainer_line: HBoxContainer
var _kind_tag: Control
var _introduction: Label
var _start: Button
var _back: Button
var _transitioning := false
var shown_gate := -1
## 枠番の抽選で、数字を回す間（秒）。
## 一覧の行の、誰が動かすかの札の字の大きさ。
const LIST_TAG_FONT_SIZE := 10
const DRAW_TICK_S := 0.08
var _list: VBoxContainer
## 会場の上に重ねるときの、右の列（ステータスの箱とボタン）。
var _right_column: VBoxContainer
## 行ごとの、名前の文字（枠番の抽選で、枠番の所を書き換える）。
var _names: Array[Label] = []
## レース会場のパドックの上に重ねて出すか（左に出走表、右にステータス。真ん中は会場が見えるように空ける）。
## このときは、レース開始・戻るは自分で画面を変えず、合図を出す（会場の画面が受けて進める）。
var overlay_mode := false
## 見るだけ（オンライン：進めるのはサーバーなので、「レース開始」「選択に戻る」は出さず、まもなく進むことだけ知らせる）。
var read_only := false
## オンラインで出走者を待っている間：枠番はまだ決まっていない（「枠未定」と出す）。待っている枠の数だけ「待受中…」の行を足す。
var gates_unknown := false
var waiting_rows := 0
## 見るだけのときに、下に「まもなくゲートイン」を出すか（ゲートインの間に出すときは出さない）。
var show_soon := true
## 見るだけのときに、A（決定）を受けずに、会場の画面へ通すか（ゲートインの間は、A でスキップするため）。
var accept_passes := false
## 枠順の抽選を見せ終わった。
signal draw_finished
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")

signal start_requested
signal back_requested
## カーソル（マウス）で見ている枠が変わった（会場のカメラが、そのぷるりんに寄る）。
signal entry_shown(gate: int)

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	if overlay_mode:
		# 会場の上：地は無し（左右の箱だけ）。上の帯は、会場の画面が出す。
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = Style.SCREEN_MARGIN
		panel.offset_right = -Style.SCREEN_MARGIN
		panel.offset_top = Style.BAR_HEIGHT + 12.0
		# 下の1行（案内・「出走者を集めています」・「Y 出走表」）を空ける。パドックとゲートインで、高さをそろえる。
		panel.offset_bottom = -(Style.GUIDE_HEIGHT + 6.0)
	else:
		# パドックにいる間に、レースの画面を裏で読み込んでおく（ラボから起動したときは、ラボが自分で始めるので読まない）。
		if not Session.race_starter.is_valid():
			RaceScenePreload.start()
		Style.background(self, "res://assets/ui/race_select_background.jpg")
		# 画面の名前（パドックと距離）は、上の帯に出す。
		Style.top_bar(self, "パドック　%d m" % int(Session.selected_distance_m()), Profile.trainer_name())
		panel.add_theme_stylebox_override("panel", Style.panel_box(18.0, 12.0))
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_bottom = 1.0
		panel.offset_left = -546
		panel.offset_right = 546
		panel.offset_top = Style.BAR_HEIGHT + 8.0
		panel.offset_bottom = -8.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = ROW_WIDTH_OVERLAY if overlay_mode else 286.0
	list.add_theme_constant_override("separation", 8)
	if overlay_mode:
		# 左の箱：出走表（上の帯の下から、画面の下まで）。
		var list_box := PanelContainer.new()
		list_box.name = "ListBox"
		list_box.add_theme_stylebox_override("panel", Style.panel_box(12.0, 12.0))
		list_box.size_flags_vertical = Control.SIZE_FILL
		list.add_theme_constant_override("separation", 6)
		list_box.add_child(list)
		body.add_child(list_box)
	else:
		body.add_child(list)
	_entries = Session.field_entries()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["gate"]) < int(b["gate"]))
	for entry: Dictionary in _entries:
		var gate := int(entry["gate"])
		var pururin := Roster.pururin_by_id(str(entry["id"]))
		var player := _is_me(entry)
		var row := Button.new()
		row.name = "Gate%d" % (gate + 1)
		row.custom_minimum_size = Vector2(ROW_WIDTH_OVERLAY, ROW_HEIGHT_OVERLAY) if overlay_mode else Vector2(286, 46)
		Style.style_card_button(row)
		if overlay_mode:
			for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
				row.add_theme_stylebox_override(state, Style.box(COLOR_ROW_OVERLAY if state == "normal" else COLOR_ROW_HOVER_OVERLAY, 12, 0.0, 0.0))
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 8)
		row.add_child(content)
		var portrait: Control = Portrait.new()
		portrait.custom_minimum_size = Vector2.ONE * (ROW_PORTRAIT_OVERLAY if overlay_mode else 40.0)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		portrait.call("set_pururin", pururin)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 2 if overlay_mode else 0)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(names)
		var gate_text := "枠未定" if gates_unknown else "%d枠" % (gate + 1)
		var name := Style.label("%s %s%s" % [gate_text, str(pururin["display_name"]), "（自分）" if player else ""], ROW_NAME_SIZE_OVERLAY if overlay_mode else 16)
		name.set_meta("rest", " %s%s" % [str(pururin["display_name"]), "（自分）" if player else ""])
		_names.append(name)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# オンラインでは、名前の横に、誰が動かすかの札（プレイヤー・CPU）。
		var kind := _control_kind(entry)
		if kind.is_empty():
			names.add_child(name)
		else:
			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 6)
			name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			names.add_child(name_row)
			name_row.add_child(name)
			name_row.add_child(_control_tag(kind, LIST_TAG_FONT_SIZE, true))
		# 自分は登録した名前、オンラインのほかの人はその人の名前、CPUはトレーナーの名前。
		var trainer_name := Profile.trainer_name() if player else (str(entry["trainer_name"]) if int(entry.get("peer_id", 0)) != 0 else str(_trainer_of(entry).get("name", "CPU")))
		# 属性と脚質は、名前の前に、印も付ける（属性＝詳細パネルと同じ印、脚質＝操作盤と同じ「〈」）。
		var attribute_id := str(pururin["attribute"])
		var style_id := str(pururin["running_style"])
		var summary := HBoxContainer.new()
		summary.name = "Summary"
		summary.add_theme_constant_override("separation", 3)
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		names.add_child(summary)
		var mark_size := MARK_SIZE_OVERLAY if overlay_mode else MARK_SIZE
		var chevron_scale := CHEVRON_SCALE_OVERLAY if overlay_mode else CHEVRON_SCALE
		var attribute_mark := Control.new()
		attribute_mark.name = "AttributeMark"
		attribute_mark.custom_minimum_size = Vector2(mark_size, mark_size)
		attribute_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		attribute_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		attribute_mark.draw.connect(func() -> void:
			Detail.draw_attribute_mark(attribute_mark, attribute_mark.size * 0.5, mark_size, attribute_id, Color.from_string(str(Stats.values()["attributes"][attribute_id]["color"]), Color.WHITE)))
		summary.add_child(attribute_mark)
		var driver := Session.driver_label_for_slot(gate)
		var style_mark := Control.new()
		style_mark.name = "StyleMark"
		style_mark.custom_minimum_size = Vector2(Hud.STYLE_CHEVRON_STEP * chevron_scale * StatsMath.rank_group_count() + 2.0, mark_size)
		style_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		style_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_mark.draw.connect(func() -> void:
			Hud.draw_style_chevrons(style_mark, Vector2(1.0, style_mark.size.y * 0.5), Hud.COLOR_STYLE_MATCH, StatsMath.rank_group_count(), StatsMath.style_rank_group_index(style_id), chevron_scale))
		if overlay_mode:
			# 会場の上：属性と脚質を左に、トレーナー名を右寄せ（区切りの「・」は使わない）。
			summary.add_theme_constant_override("separation", 5)
			summary.add_child(_dim_label(str(ATTRIBUTE_NAMES.get(attribute_id, attribute_id)), ROW_SUB_SIZE_OVERLAY))
			var gap_mark := Control.new()
			gap_mark.custom_minimum_size.x = 8.0
			gap_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			summary.add_child(gap_mark)
			summary.add_child(style_mark)
			summary.add_child(_dim_label(str(STYLE_NAMES.get(style_id, "")), ROW_SUB_SIZE_OVERLAY))
			var trainer_label := _dim_label("%s%s" % [trainer_name, "［%s］" % driver if not driver.is_empty() else ""], ROW_SUB_SIZE_OVERLAY)
			trainer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trainer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			summary.add_child(trainer_label)
		else:
			summary.add_child(_dim_label("%s・" % ATTRIBUTE_NAMES.get(attribute_id, attribute_id)))
			summary.add_child(style_mark)
			# ラボから起動したときは、その枠を走らせるCPUの名前も添える。
			summary.add_child(_dim_label("%s　%s%s" % [STYLE_NAMES.get(style_id, ""), trainer_name, "［%s］" % driver if not driver.is_empty() else ""]))
		row.focus_entered.connect(_show_entry.bind(entry))
		# マウスを乗せている間だけ、その行を見せる。離れたら、カーソルが合っている行に戻す。
		row.mouse_entered.connect(_show_entry.bind(entry))
		row.mouse_exited.connect(_show_focused_entry)
		row.pressed.connect(_show_entry.bind(entry))
		list.add_child(row)
		_rows.append(row)
	for index in waiting_rows:
		list.add_child(_waiting_row())
	_list = list
	_detail = Detail.new()
	_detail.name = "PururinDetail"
	_detail.custom_minimum_size.x = 410
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trainer_panel := VBoxContainer.new()
	trainer_panel.name = "TrainerDetail"
	trainer_panel.add_theme_constant_override("separation", 12)
	var trainer_image_size := 64.0 if overlay_mode else 220.0
	_trainer_image = TextureRect.new()
	_trainer_image.custom_minimum_size = Vector2(trainer_image_size, trainer_image_size)
	_trainer_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trainer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_image = TrainerIcon.new()
	_player_image.custom_minimum_size = Vector2(trainer_image_size, trainer_image_size)
	_trainer_name = Style.label("", 23)
	_trainer_line = HBoxContainer.new()
	_trainer_line.add_theme_constant_override("separation", 8)
	_trainer_line.add_child(_trainer_name)
	_favorite = Style.label("", 17, Style.COLOR_DIM)
	# 紹介文は、長めの文が入るように、小さめの字で、行を折り返して出す。
	_introduction = Style.label("", 13, Style.COLOR_DIM)
	_introduction.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if overlay_mode:
		# 真ん中は会場が見えるように空けて、右の箱に、トレーナー（小さい絵と名前）とステータス。
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(gap)
		# 右の列：上にトレーナーとステータスの箱、下にボタン（一覧を下まで伸ばすため、ボタンはこちらに置く）。
		var right_column := VBoxContainer.new()
		right_column.name = "RightColumn"
		right_column.custom_minimum_size.x = RIGHT_WIDTH_OVERLAY
		right_column.add_theme_constant_override("separation", 14)
		right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(right_column)
		_right_column = right_column
		var right_box := PanelContainer.new()
		right_box.name = "RightBox"
		right_box.add_theme_stylebox_override("panel", Style.panel_box(14.0, 12.0))
		right_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		right_column.add_child(right_box)
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 8)
		right_box.add_child(right)
		var trainer_row := HBoxContainer.new()
		trainer_row.add_theme_constant_override("separation", 12)
		right.add_child(trainer_row)
		trainer_row.add_child(_trainer_image)
		trainer_row.add_child(_player_image)
		var trainer_texts := VBoxContainer.new()
		trainer_texts.alignment = BoxContainer.ALIGNMENT_CENTER
		trainer_row.add_child(trainer_texts)
		trainer_texts.add_child(_trainer_line)
		trainer_texts.add_child(_favorite)
		_detail.custom_minimum_size.y = DETAIL_HEIGHT_OVERLAY
		right.add_child(_detail)
	else:
		body.add_child(_detail)
		trainer_panel.custom_minimum_size.x = 244
		body.add_child(trainer_panel)
		trainer_panel.add_child(Style.section_title("トレーナー"))
		trainer_panel.add_child(_trainer_image)
		trainer_panel.add_child(_player_image)
		trainer_panel.add_child(_trainer_line)
		trainer_panel.add_child(_favorite)
		_introduction.custom_minimum_size = Vector2(244, 96)
		trainer_panel.add_child(_introduction)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14 if overlay_mode else 20)
	var button_parent: Container = column
	if overlay_mode:
		# 右の列の下の端に寄せる。
		var push := Control.new()
		push.size_flags_vertical = Control.SIZE_EXPAND_FILL
		push.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_right_column.add_child(push)
		button_parent = _right_column
	button_parent.add_child(buttons)
	# 出走者を待っている間・枠順の抽選の間は、「まもなくゲートイン」は出さない（下に、待っているようすを出すため）。
	if read_only:
		buttons.visible = false
	if read_only and not gates_unknown and show_soon:
		var soon := Style.bold_label("まもなくゲートイン", 22)
		soon.name = "SoonLabel"
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_parent.add_child(soon)
	_back = Style.pill_button("戻る" if overlay_mode else "選択に戻る", "quiet", 20)
	_back.name = "BackButton"
	_back.custom_minimum_size = Vector2(170 if overlay_mode else 286, 52 if overlay_mode else 48)
	Style.add_mark(_back, "B")
	_back.pressed.connect(back)
	buttons.add_child(_back)
	_start = Style.pill_button("レース開始", "primary", 22)
	_start.name = "StartButton"
	if overlay_mode:
		_start.custom_minimum_size = Vector2(0, 52)
		_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.add_mark(_start, "START")
	_start.disabled = not Session.race_start_problem().is_empty()
	_start.pressed.connect(start)
	buttons.add_child(_start)
	_link_focus()
	if not _rows.is_empty():
		# はじめのカーソルは、自分のぷるりんの行（いなければ、いちばん上）。
		var first := maxi(_entries.find_custom(func(entry: Dictionary) -> bool: return _is_me(entry)), 0)
		_rows[first].grab_focus()
		_show_entry(_entries[first])
	else:
		_back.grab_focus()

## カーソルが合っている行のぷるりんを見せる（どの行にも合っていなければ、そのまま）。
func _show_focused_entry() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	for index in _rows.size():
		if _rows[index] == focused:
			_show_entry(_entries[index])
			return


func _show_entry(entry: Dictionary) -> void:
	shown_gate = int(entry["gate"])
	entry_shown.emit(shown_gate)
	_detail.call("show_pururin", str(entry["id"]))
	var player := _is_me(entry)
	if _kind_tag != null:
		_kind_tag.queue_free()
		_kind_tag = null
	var kind := _control_kind(entry)
	if not kind.is_empty():
		_kind_tag = _control_tag(kind, 14)
		_trainer_line.add_child(_kind_tag)
	_trainer_image.visible = not player
	_player_image.visible = player
	if player:
		_player_image.call("show_registered")
		_trainer_name.text = Profile.trainer_name()
		_trainer_name.add_theme_color_override("font_color", Color(0.5, 1, 1))
		_favorite.text = "プレイヤー操作"
		_introduction.text = Profile.introduction()
	elif int(entry.get("peer_id", 0)) != 0:
		# オンラインの、ほかの人：名前だけ（その人のアイコンは、ここでは持っていない）。
		_trainer_image.visible = false
		_trainer_name.text = str(entry.get("trainer_name", ""))
		_trainer_name.add_theme_color_override("font_color", Style.COLOR_TEXT)
		_favorite.text = "オンラインのプレイヤー"
		_introduction.text = ""
	else:
		var trainer := _trainer_of(entry)
		_trainer_image.texture = load(str(trainer.get("portrait_path", "")))
		_trainer_name.text = str(trainer.get("name", "CPU"))
		_trainer_name.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if Session.is_default_trainer(shown_gate, str(trainer.get("id", ""))) else Style.COLOR_TEXT)
		_favorite.text = "得意脚質：" + str(STYLE_NAMES.get(str(trainer.get("favorite_running_style", "")), ""))
		_introduction.text = str(trainer.get("introduction", ""))

	# ラボから起動したときは、その枠を走らせるCPUの名前を、トレーナー名の下に出す。
	var driver := Session.driver_label_for_slot(shown_gate)
	if not driver.is_empty():
		_trainer_name.text += "\n［%s］" % driver


## オンラインで、その走者を誰が動かすか（Hud の KIND_PLAYER・KIND_CPU）。オフラインは空（札を出さない）。
func _control_kind(entry: Dictionary) -> String:
	if not Session.is_online_view() or not entry.has("peer_id"):
		return ""
	return Hud.KIND_PLAYER if int(entry["peer_id"]) != 0 else Hud.KIND_CPU


## 誰が動かすかの札。small＝一覧の行の中に入れる、小さい札（行の高さを変えない）。
func _control_tag(kind: String, font_size: int, small: bool = false) -> Control:
	var tag: Array = Hud.CONTROL_TAGS[kind]
	var node := Style.tag(str(tag[0]), tag[1], font_size)
	if small:
		node.add_theme_stylebox_override("panel", Style.box(tag[1], 4, 4.0, 0.0))
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## 自分の走者か。オンラインでは、自分の番号の人だけ（ほかの人も player が真なので、番号で見分ける）。
func _is_me(entry: Dictionary) -> bool:
	if entry.has("peer_id"):
		return int(entry["peer_id"]) != 0 and int(entry["peer_id"]) == Session.online_view_peer_id()
	return bool(entry["player"])


## その走者のCPUトレーナー。オンラインは出走に書いてあるトレーナー、オフラインはレース選択の枠のトレーナー。
func _trainer_of(entry: Dictionary) -> Dictionary:
	if entry.has("trainer_id"):
		return CpuTrainers.by_id(str(entry["trainer_id"]))
	return Session.trainer_for_slot(int(entry["gate"]))


func _link_focus() -> void:
	for index in _rows.size():
		var row := _rows[index]
		row.focus_neighbor_top = row.get_path_to(_rows[(index - 1 + _rows.size()) % _rows.size()])
		row.focus_neighbor_bottom = row.get_path_to(_rows[(index + 1) % _rows.size()])
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row if read_only else _back)
		row.focus_entered.connect(func() -> void: _back.focus_neighbor_left = _back.get_path_to(row))
	for button: Button in [_back, _start]:
		button.focus_neighbor_top = button.get_path_to(_rows.back() if not _rows.is_empty() else _back)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_neighbor_left = button.get_path_to(_back)
		button.focus_neighbor_right = button.get_path_to(_start)

## 画面を切り替える。レースへは、裏で読み込んでおいた画面を使う。
func _navigate(path: String) -> void:
	if path == RaceScenePreload.SCENE_PATH:
		RaceScenePreload.go(get_tree())
	else:
		get_tree().change_scene_to_file(path)

func start() -> void:
	if _transitioning or not Session.race_start_problem().is_empty():
		return
	_transitioning = true
	UIAudio.play_confirmation()
	if overlay_mode:
		start_requested.emit()
	elif Session.race_starter.is_valid():
		Session.race_starter.call()
	else:
		_navigate(RaceScenePreload.SCENE_PATH)

func back() -> void:
	if _transitioning:
		return
	_transitioning = true
	UIAudio.play_back()
	if overlay_mode:
		back_requested.emit()
	else:
		_navigate("res://scenes/race_select.tscn")

func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	# 見るだけのとき：カーソルを動かして見るだけ。レース開始・戻るは無い。
	if read_only:
		if accept_passes:
			return
		if InputHelper.is_accept_pressed(event) and InputHelper.activate_focused_control(viewport):
			viewport.set_input_as_handled()
		return
	if InputHelper.is_menu_pressed(event):
		viewport.set_input_as_handled()
		start()
	elif event.is_action_pressed("ui_cancel") or InputHelper.is_cancel_pressed(event):
		viewport.set_input_as_handled()
		back()
	elif InputHelper.is_accept_pressed(event) and InputHelper.activate_focused_control(viewport):
		viewport.set_input_as_handled()


## 「待受中…」の行（まだ入っていない枠。押せない）。
func _waiting_row() -> Control:
	var row := PanelContainer.new()
	row.name = "WaitingRow"
	row.custom_minimum_size = Vector2(ROW_WIDTH_OVERLAY, ROW_HEIGHT_OVERLAY) if overlay_mode else Vector2(286, 46)
	if overlay_mode:
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", Style.card_box(Color(Style.COLOR_CARD, 0.45), Color(Style.COLOR_CARD_BORDER, 0.25)))
	var label := Style.label("枠未定　待受中…", 16, Style.COLOR_BAR_DIM)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


## 枠順の抽選を見せる：行をばらばらに並べ、どの行の枠番もくじのように回す（spin_s 秒）。
## そのあと、1枠から順に1行ずつ（each_s 秒ごと）枠番が止まって決まり、その行が正しい位置へ並ぶ。終わったら draw_finished。
func play_draw(spin_s: float, each_s: float) -> void:
	var count := _rows.size()
	var order := _rows.duplicate()
	order.shuffle()
	for index in order.size():
		_list.move_child(order[index], index)
	var decided := 0
	var spin_left := spin_s
	var next_stop := each_s
	while decided < count:
		await get_tree().create_timer(DRAW_TICK_S).timeout
		if not is_inside_tree():
			return
		for index in range(decided, count):
			_names[index].text = "%d枠%s" % [randi_range(1, count), str(_names[index].get_meta("rest"))]
		if spin_left > 0.0:
			spin_left -= DRAW_TICK_S
			continue
		next_stop -= DRAW_TICK_S
		if next_stop > 0.0:
			continue
		next_stop = each_s
		# この行（枠番の順）の、枠番が決まる。決まった行を、上から順に並べる。
		var gate := int(_entries[decided]["gate"])
		_names[decided].text = "%d枠%s" % [gate + 1, str(_names[decided].get_meta("rest"))]
		_names[decided].add_theme_color_override("font_color", Style.COLOR_FOCUS)
		_list.move_child(_rows[decided], decided)
		UIAudio.play_confirmation()
		decided += 1
	await get_tree().create_timer(each_s).timeout
	for name in _names:
		name.add_theme_color_override("font_color", Style.COLOR_TEXT)
	draw_finished.emit()


## 行の2段目の、小さい文字。
func _dim_label(text: String, font_size: int = 13) -> Label:
	var label := Style.label(text, font_size, Style.COLOR_DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
