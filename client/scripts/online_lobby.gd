extends Control
## オンラインフリー対戦の、部屋の画面。サーバーにつなぎ、合言葉の部屋に入り、集まった人の一覧を出す。
## 部屋では、自分のぷるりんを選ぶ。部屋の主（最初に入った人）は、距離を決めて、レースを始める。
## 名前は、トレーナー登録の名前を使う。サーバーとのつながりは、レースの画面へ持っていくので、OnlineSession に置く。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LOCAL_RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const Protocol := preload("res://scripts/online/online_protocol.gd")
const PANEL_SIZE := Vector2(640.0, 624.0)
const ARROW_BUTTON_SIZE := Vector2(52.0, 40.0)
const BUTTON_HEIGHT := 44.0
const FIELD_HEIGHT := 40.0
const LABEL_WIDTH := 110.0

## サーバーに断られたときの、画面に出す文。
const ERROR_TEXTS := {
	Protocol.ERROR_ROOM_FULL: "その部屋は満員です（%d人）。" % Protocol.ROOM_CAPACITY,
	Protocol.ERROR_VERSION: "ゲームとサーバーの版が合っていません。",
	Protocol.ERROR_BAD_MESSAGE: "サーバーに断られました（名前か合言葉を確かめてください）。",
	Protocol.ERROR_TAKEN: "そのぷるりんは、ほかの人が選んでいます。",
	Protocol.ERROR_NOT_HOST: "部屋の主（最初に入った人）だけができます。",
	Protocol.ERROR_NOT_READY: "まだ、ぷるりんを選んでいない人がいます。",
	Protocol.ERROR_RACING: "その部屋は、レース中です。終わるまで待ってください。",
}

var _client: Node
var _server_edit: LineEdit
var _room_edit: LineEdit
var _join_button: Button
var _back_button: Button
var _status: Label
var _members_box: VBoxContainer
## 部屋に入ってから出す部分（ぷるりん・距離・開始）。
var _room_controls: VBoxContainer
var _pururin_label: Label
var _distance_label: Label
var _distance_buttons: Array[Button] = []
var _start_button: Button
## 部屋のようす（サーバーから届いた最後のもの）。
var _room := {}
## 入ろうとしている合言葉（つながるのを待っているあいだ、覚えておく）。
var _pending_room := ""
## 部屋に入れたときの、自分の番号（入る前は0）と、部屋の人。
var _peer_id := 0
var _members: Array = []
var _connect_wait_s := -1.0


func _ready() -> void:
	_client = OnlineSession.client(get_tree())
	_client.connected.connect(_on_connected)
	_client.message_received.connect(_on_message)
	_client.closed.connect(_on_closed)
	_build()
	_room_edit.grab_focus()
	# レースから戻ってきたときは、部屋に入ったまま。
	if OnlineSession.in_room():
		_peer_id = OnlineSession.peer_id
		_room_edit.text = str(OnlineSession.room.get("room", ""))
		_set_status("部屋「%s」にいます。" % _room_edit.text)
		_apply_room(OnlineSession.room)
	else:
		_apply_room({})


func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.45, 0.45, 0.5, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 28.0, 22.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var heading := MenuStyle.label("オンラインフリー対戦", 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var name_label := MenuStyle.label("名前：%s" % TrainerProfile.trainer_name(), 20, MenuStyle.COLOR_DIM)
	name_label.name = "NameLabel"
	column.add_child(name_label)
	_server_edit = _field(column, "サーバー", "ServerEdit", OnlineConfig.server_url(), 200)
	_room_edit = _field(column, "合言葉", "RoomEdit", "", Protocol.ROOM_CODE_MAX_LENGTH)
	_room_edit.placeholder_text = "同じ合言葉の人と、同じ部屋に入ります"
	_room_edit.text_submitted.connect(func(_text: String) -> void: join())
	_join_button = MenuStyle.button("部屋に入る", 22)
	_join_button.name = "JoinButton"
	_join_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_join_button.pressed.connect(join)
	UIAudio.bind_button_sound(_join_button, "confirmation")
	column.add_child(_join_button)
	_status = MenuStyle.label("", 18)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size = Vector2(0.0, 26.0)
	column.add_child(_status)
	_room_controls = VBoxContainer.new()
	_room_controls.name = "RoomControls"
	_room_controls.add_theme_constant_override("separation", 4)
	column.add_child(_room_controls)
	_pururin_label = _chooser(_room_controls, "ぷるりん", "Pururin", step_pururin)
	_distance_label = _chooser(_room_controls, "距離", "Distance", step_distance, _distance_buttons)
	_start_button = MenuStyle.button("レース開始", 22, MenuStyle.COLOR_BUTTON_ON)
	_start_button.name = "StartButton"
	_start_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_start_button.pressed.connect(start_race)
	UIAudio.bind_button_sound(_start_button, "confirmation")
	_room_controls.add_child(_start_button)
	_members_box = VBoxContainer.new()
	_members_box.name = "Members"
	_members_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_members_box.add_theme_constant_override("separation", 0)
	column.add_child(_members_box)
	_back_button = MenuStyle.button("戻る", 22, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_back_button.pressed.connect(go_back)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	column.add_child(_back_button)


## 「名前　入力らん」の1行を足して、入力らんを返す。
func _field(column: VBoxContainer, title: String, node_name: String, text: String, max_length: int) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := MenuStyle.label(title, 20)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.name = node_name
	edit.text = text
	edit.max_length = max_length
	edit.custom_minimum_size = Vector2(0.0, FIELD_HEIGHT)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 20)
	row.add_child(edit)
	return edit


## 「名前　◀　今の値　▶」の1行を足して、今の値のラベルを返す。押すと step に -1 か 1 を渡す。
func _chooser(parent: VBoxContainer, title: String, node_name: String, step: Callable, buttons: Array[Button] = []) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := MenuStyle.label(title, 20)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)
	var value := MenuStyle.label("", 20)
	value.name = node_name + "Label"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for direction: int in [-1, 1]:
		var button := MenuStyle.button("◀" if direction < 0 else "▶", 20, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = node_name + ("Previous" if direction < 0 else "Next")
		button.custom_minimum_size = ARROW_BUTTON_SIZE
		button.pressed.connect(step.bind(direction))
		UIAudio.bind_button_sound(button, "confirmation")
		buttons.append(button)
		if direction > 0:
			row.add_child(value)
		row.add_child(button)
	return value


func _process(delta: float) -> void:
	# つながるのを待つのは、決めた秒数まで。
	if _connect_wait_s >= 0.0:
		_connect_wait_s += delta
		if _connect_wait_s >= OnlineConfig.connect_timeout_s():
			_connect_wait_s = -1.0
			_client.disconnect_from_server()
			_pending_room = ""
			_set_status("サーバーにつながりません。サーバーの場所を確かめてください。")


## 「部屋に入る」：サーバーにつなぎ（まだなら）、合言葉の部屋に入る。
func join() -> void:
	var room := Protocol.clean_text(_room_edit.text, Protocol.ROOM_CODE_MAX_LENGTH)
	var url := _server_edit.text.strip_edges()
	if room.is_empty():
		_set_status("合言葉を入れてください。")
		return
	if not OnlineConfig.is_server_url(url):
		_set_status("サーバーの場所は、ws:// か wss:// で始めてください。")
		return
	_pending_room = room
	if _client.is_open():
		_client.join_room(TrainerProfile.trainer_name(), room)
		return
	var error: Error = _client.connect_to(url)
	if error != OK:
		_pending_room = ""
		_set_status("サーバーにつながりません（%s）。" % error_string(error))
		return
	_connect_wait_s = 0.0
	_set_status("サーバーにつないでいます…")


func _on_connected() -> void:
	_connect_wait_s = -1.0
	if not _pending_room.is_empty():
		_client.join_room(TrainerProfile.trainer_name(), _pending_room)


func _on_message(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.WELCOME:
			_peer_id = int(data["peer_id"])
			_pending_room = ""
			_set_status("部屋「%s」に入りました。ぷるりんを選んでください。" % str(data["room"]))
			_apply_room(data)
		Protocol.ROOM:
			_apply_room(data)
		Protocol.RACE_START:
			_go_to_race(data)
		Protocol.ERROR:
			_pending_room = ""
			_set_status(str(ERROR_TEXTS.get(str(data.get("code", "")), "サーバーに断られました。")))


func _on_closed() -> void:
	var was_waiting := _connect_wait_s >= 0.0
	_connect_wait_s = -1.0
	_pending_room = ""
	_peer_id = 0
	_apply_room({})
	_set_status("サーバーにつながりません。サーバーの場所を確かめてください。" if was_waiting else "サーバーとのつながりが切れました。")


func _set_status(text: String) -> void:
	_status.text = text


## 部屋のようすを、画面に出す（部屋に入っていないときは、空の辞書を渡す）。
func _apply_room(room: Dictionary) -> void:
	_room = room if _peer_id != 0 else {}
	_members = _room.get("members", [])
	_room_controls.visible = _peer_id != 0
	_show_members()
	if _peer_id == 0:
		return
	var mine := my_pururin_id()
	_pururin_label.text = pururin_name(mine) if not mine.is_empty() else "（まだ選んでいません）"
	_distance_label.text = "%d m" % int(float(_room.get("distance_m", 0.0)))
	# 距離と開始は、部屋の主だけ。開始は、全員が選び終わってから。
	var host := is_host()
	for button: Button in _distance_buttons:
		button.disabled = not host
	_start_button.visible = host
	_start_button.disabled = not everyone_picked()


func is_host() -> bool:
	return _peer_id != 0 and int(_room.get("host", 0)) == _peer_id


## 自分が選んでいるぷるりん（まだなら空）。
func my_pururin_id() -> String:
	for member: Dictionary in _members:
		if int(member["peer_id"]) == _peer_id:
			return str(member["pururin_id"])
	return ""


func everyone_picked() -> bool:
	for member: Dictionary in _members:
		if str(member["pururin_id"]).is_empty():
			return false
	return not _members.is_empty()


static func pururin_name(pururin_id: String) -> String:
	return str(PururinRosterConfig.pururin_by_id(pururin_id).get("display_name", pururin_id))


## ぷるりんを、次（1）か前（-1）の個体に替える。ほかの人が選んでいる個体は、飛ばす。
func step_pururin(direction: int) -> void:
	var taken := {}
	for member: Dictionary in _members:
		if int(member["peer_id"]) != _peer_id and not str(member["pururin_id"]).is_empty():
			taken[str(member["pururin_id"])] = true
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	var index := ids.find(my_pururin_id())
	# まだ選んでいないとき、次へ＝最初の個体、前へ＝最後の個体から始める。
	if index < 0:
		index = -1 if direction > 0 else ids.size()
	for _attempt in ids.size():
		index = posmod(index + direction, ids.size())
		if not taken.has(ids[index]):
			_client.send(Protocol.PICK, {"pururin_id": ids[index]})
			return


## 距離を、次（1）か前（-1）に替える（部屋の主だけ）。
func step_distance(direction: int) -> void:
	var distances: Array = RaceSession.supported_distances_m()
	var index := distances.find(float(_room.get("distance_m", 0.0)))
	_client.send(Protocol.DISTANCE, {"distance_m": distances[posmod(index + direction, distances.size())]})


func start_race() -> void:
	_client.send(Protocol.START)


## レースが始まった：届いた出走と距離で、レースの画面へ進む（レースは、サーバーから届く状態を映す）。
func _go_to_race(data: Dictionary) -> void:
	RaceSession.select_distance(float(data["distance_m"]))
	RaceSession.set_online_entries(data["entries"])
	RaceSession.set_online_view(_peer_id)
	get_tree().change_scene_to_file(LOCAL_RACE_SCENE_PATH)


## 部屋の人の一覧を出す。自分には印、部屋の主には「主」、選んだぷるりんの名前を付ける。部屋に入る前は、何も出さない。
func _show_members() -> void:
	for child in _members_box.get_children():
		child.free()
	if _peer_id == 0:
		return
	_members_box.add_child(MenuStyle.label("部屋の人（%d／%d人）" % [_members.size(), Protocol.ROOM_CAPACITY], 18, MenuStyle.COLOR_DIM))
	# 8人でも画面に収まるように、2列に並べる。
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 0)
	_members_box.add_child(grid)
	for index in _members.size():
		var member: Dictionary = _members[index]
		var is_me := int(member["peer_id"]) == _peer_id
		var picked := str(member["pururin_id"])
		var text := "%d　%s%s%s　— %s" % [
			index + 1, str(member["name"]), "（あなた）" if is_me else "",
			"［主］" if int(member["peer_id"]) == int(_room.get("host", 0)) else "",
			pururin_name(picked) if not picked.is_empty() else "選び中",
		]
		var line := MenuStyle.label(text, 17, MenuStyle.COLOR_BUTTON_ON if is_me else MenuStyle.COLOR_TEXT)
		line.name = "Member%d" % (index + 1)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.clip_text = true
		grid.add_child(line)


func go_back() -> void:
	OnlineSession.close()
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_back()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
