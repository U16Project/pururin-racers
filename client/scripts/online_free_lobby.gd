extends Control
## オンラインフリー対戦のロビー（共通ルーム）。
## サーバーにつないで、出るぷるりんを選び、入りたいルーム（距離ごと）に☑する。☑した順が、優先の順番（ボタンに番号を出す）。
## ルームが空くと、長く待っている人から順に呼ばれる。呼ばれたら、どのルームかを出した確かめの画面で、入るかを答える。
## レースが始まったら、レースの画面へ。レースのあとは、ここへ戻る（☑は残る）。
## ルームの並び・待つ秒数は、サーバーの設定（data/config/online.json の free_rooms など）。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const ServerChoice := preload("res://scripts/config/online_server_choice.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const LOCAL_RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const PANEL_WIDTH := 640.0
const ROOM_BUTTON_HEIGHT := 64.0
## ルームの今のようすの言葉。
const STATE_TEXTS := {
	Protocol.FREE_STATE_IDLE: "空いています",
	Protocol.FREE_STATE_CALLING: "呼んでいます",
	Protocol.FREE_STATE_RACING: "レース中",
}
const ERROR_TEXTS := {
	Protocol.ERROR_NO_PICK: "先に、出るぷるりんを選んでください。",
	Protocol.ERROR_VERSION: "ゲームとサーバーの版が違います。ゲームを新しくしてください。",
}

var _client: Node
var _status: Label
var _pick_button: OptionButton
var _rooms_box: VBoxContainer
## ルームのID → ☑のボタン。
var _room_buttons := {}
var _back_button: Button
## 自分の☑（前ほど優先）。サーバーから届いた最後のもの。
var _wishes: Array = []
## 呼ばれたときの、確かめの画面。
var _offer_panel: PanelContainer
var _offer_text: Label
var _offer_time: Label
var _accept_button: Button
var _decline_button: Button
var _offer := {}
var _offer_until_msec := 0
## つながるのを待っている秒数（待っていなければ負）。
var _connect_wait_s := -1.0


func _ready() -> void:
	OnlineSession.free_mode = true
	_build()
	_client = OnlineSession.client(get_tree())
	_client.message_received.connect(_on_message)
	_client.connected.connect(_on_connected)
	_client.closed.connect(_on_closed)
	if OnlineSession.in_lobby():
		# レースから戻ってきた：つながったまま、ロビーのようすを聞き直す。
		_set_status("ロビーに戻りました。")
		_client.send(Protocol.FREE_ENTER)
		if not OnlineSession.free_lobby.is_empty():
			_show_lobby(OnlineSession.free_lobby)
	elif _client.is_open():
		_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())
	else:
		connect_to_server()


## つなぐ先：ともだち対戦の画面で選んだもの（自分で指定したURLが正しければ、それ。でなければ、標準のサーバー）。
static func server_url() -> String:
	if ServerChoice.choice() == ServerChoice.CHOICE_CUSTOM and OnlineConfig.is_server_url(ServerChoice.custom_url()):
		return ServerChoice.custom_url()
	return OnlineConfig.server_url()


func connect_to_server() -> void:
	var error: Error = _client.connect_to(server_url())
	if error != OK:
		_set_status("サーバーにつながりません（%s）。" % error_string(error))
		return
	_connect_wait_s = 0.0
	_set_status("サーバーにつないでいます…")


func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.45, 0.45, 0.5, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 28.0, 22.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := MenuStyle.label("オンラインフリー対戦", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_status = MenuStyle.label("", 16, MenuStyle.COLOR_DIM)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 12)
	column.add_child(pick_row)
	pick_row.add_child(MenuStyle.label("出るぷるりん", 20))
	_pick_button = OptionButton.new()
	_pick_button.name = "PickButton"
	_pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_button(_pick_button, 20)
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		_pick_button.add_item(str(pururin["display_name"]))
		_pick_button.set_item_metadata(_pick_button.item_count - 1, str(pururin["id"]))
	_pick_button.item_selected.connect(func(_index: int) -> void: pick(selected_pururin_id()))
	pick_row.add_child(_pick_button)
	var note := MenuStyle.label("入りたいルームに☑してください。☑した順が、優先の順番です（数字）。\nルームが空くと、長く待っている人から呼ばれます。", 15, MenuStyle.COLOR_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_rooms_box = VBoxContainer.new()
	_rooms_box.name = "Rooms"
	_rooms_box.add_theme_constant_override("separation", 6)
	column.add_child(_rooms_box)
	_back_button = MenuStyle.button("戻る", 20, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(0.0, 48.0)
	_back_button.pressed.connect(go_back)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	column.add_child(_back_button)
	_build_offer()
	_pick_button.grab_focus()


## 呼ばれたときの、確かめの画面（画面のまん中に重ねる）。
func _build_offer() -> void:
	_offer_panel = PanelContainer.new()
	_offer_panel.name = "OfferPanel"
	_offer_panel.visible = false
	_offer_panel.add_theme_stylebox_override("panel", MenuStyle.box(Color(0.06, 0.1, 0.18, 0.97), 18, 30.0, 24.0))
	_offer_panel.set_anchors_preset(Control.PRESET_CENTER)
	_offer_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_offer_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_offer_panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(520.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	_offer_panel.add_child(column)
	_offer_text = MenuStyle.label("", 24)
	_offer_text.name = "OfferText"
	_offer_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_offer_text)
	_offer_time = MenuStyle.label("", 18, MenuStyle.COLOR_DIM)
	_offer_time.name = "OfferTime"
	_offer_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_offer_time)
	_accept_button = MenuStyle.button("入る", 22)
	_accept_button.name = "AcceptButton"
	_accept_button.custom_minimum_size = Vector2(0.0, 52.0)
	_accept_button.pressed.connect(answer.bind(true))
	UIAudio.bind_button_sound(_accept_button, "confirmation")
	MenuStyle.add_mark(_accept_button, "A")
	column.add_child(_accept_button)
	_decline_button = MenuStyle.button("やめる", 20, MenuStyle.COLOR_BUTTON_QUIET)
	_decline_button.name = "DeclineButton"
	_decline_button.custom_minimum_size = Vector2(0.0, 48.0)
	_decline_button.pressed.connect(answer.bind(false))
	UIAudio.bind_button_sound(_decline_button, "back")
	MenuStyle.add_mark(_decline_button, "B")
	column.add_child(_decline_button)
	_accept_button.focus_neighbor_bottom = _accept_button.get_path_to(_decline_button)
	_decline_button.focus_neighbor_top = _decline_button.get_path_to(_accept_button)


func _set_status(text: String) -> void:
	_status.text = text


func selected_pururin_id() -> String:
	if _pick_button.selected < 0:
		return ""
	return str(_pick_button.get_item_metadata(_pick_button.selected))


## 出るぷるりんを選ぶ（このアプリを開いているあいだ覚えておく）。
func pick(pururin_id: String) -> void:
	if pururin_id.is_empty():
		return
	OnlineSession.last_pick = pururin_id
	_client.send(Protocol.FREE_PICK, {"pururin_id": pururin_id})


## ルームの☑を付ける・外す。付けたら、優先の順番の最後に足す。外したら、後ろの番号が詰まる。
func toggle_room(free_id: String, on: bool) -> void:
	var wishes := _wishes.duplicate()
	if on and not wishes.has(free_id):
		wishes.append(free_id)
	elif not on:
		wishes.erase(free_id)
	_wishes = wishes
	_client.send(Protocol.FREE_WISH, {"room_ids": wishes})
	_refresh_room_buttons(OnlineSession.free_lobby.get("rooms", []))


## 呼ばれたルームに答える。
func answer(accept: bool) -> void:
	if _offer.is_empty():
		return
	_client.send(Protocol.FREE_ANSWER, {"room_id": str(_offer["room_id"]), "accept": accept})
	_set_status("入ると答えました。レースが始まるのを待っています…" if accept else "「%s」の☑を外しました。" % str(_offer["name"]))
	_close_offer()


## 戻る：ロビーを出て、つながりを切り、ゲームモード選択へ。
func go_back() -> void:
	if _client != null and is_instance_valid(_client):
		_client.send(Protocol.FREE_LEAVE)
	OnlineSession.free_mode = false
	OnlineSession.close()
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func _on_connected() -> void:
	_connect_wait_s = -1.0
	_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())


func _on_closed() -> void:
	var was_waiting := _connect_wait_s >= 0.0
	_connect_wait_s = -1.0
	_close_offer()
	_set_status("サーバーにつながりません。" if was_waiting else "サーバーとのつながりが切れました。")


func _on_message(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.LOBBY:
			# 名乗り終えた：フリー対戦のロビーに入る。
			_client.send(Protocol.FREE_ENTER)
		Protocol.FREE_LOBBY:
			_show_lobby(data)
		Protocol.FREE_OFFER:
			_show_offer(data)
		Protocol.FREE_OFFER_END:
			_close_offer()
			if str(data.get("reason", "")) == Protocol.FREE_OFFER_TIMEOUT:
				_set_status("返事がなかったので、☑を全部外しました。")
			else:
				_set_status("待たずにレースが始まりました。次を待ちます。")
		Protocol.RACE_START:
			_close_offer()
			_go_to_race(data)
		Protocol.ERROR:
			_set_status(str(ERROR_TEXTS.get(str(data.get("code", "")), "サーバーに断られました。")))


## ロビーのようすを出す。まだぷるりんを選んでいなければ、前に選んだもの（無ければ、一覧の最初）を選ぶ。
func _show_lobby(data: Dictionary) -> void:
	if _status.text.is_empty() or _status.text.begins_with("サーバーにつないで"):
		_set_status("ロビーに入りました。")
	_wishes = (data.get("wishes", []) as Array).map(func(value: Variant) -> String: return str(value))
	var pururin_id := str(data.get("pururin_id", ""))
	if pururin_id.is_empty():
		pururin_id = OnlineSession.last_pick if not OnlineSession.last_pick.is_empty() else str(_pick_button.get_item_metadata(0))
		pick(pururin_id)
	for index in _pick_button.item_count:
		if str(_pick_button.get_item_metadata(index)) == pururin_id:
			_pick_button.select(index)
	_refresh_room_buttons(data.get("rooms", []))


## ルームのボタン：☑と優先の番号、名前と距離、今のようす（待っている人数と、自分が何番目か）。
func _refresh_room_buttons(rooms: Array) -> void:
	for room: Dictionary in rooms:
		var free_id := str(room["room_id"])
		var button: Button = _room_buttons.get(free_id)
		if button == null:
			button = MenuStyle.button("", 20, MenuStyle.COLOR_BUTTON_QUIET)
			button.name = "Room_%s" % free_id
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0.0, ROOM_BUTTON_HEIGHT)
			button.toggled.connect(func(on: bool) -> void: toggle_room(free_id, on))
			UIAudio.bind_button_sound(button, "confirmation")
			_rooms_box.add_child(button)
			_room_buttons[free_id] = button
		var priority := _wishes.find(free_id) + 1
		button.set_pressed_no_signal(priority > 0)
		button.text = room_text(room, priority)
	# 上下の移動：ぷるりん → ルーム → 戻る。
	var buttons: Array = []
	for child in _rooms_box.get_children():
		buttons.append(child)
	var chain: Array = [_pick_button] + buttons + [_back_button]
	for index in chain.size():
		var node: Control = chain[index]
		node.focus_neighbor_top = node.get_path_to(chain[maxi(index - 1, 0)])
		node.focus_neighbor_bottom = node.get_path_to(chain[mini(index + 1, chain.size() - 1)])


## ルームのボタンの文字。priority は、優先の番号（☑していなければ0）。
static func room_text(room: Dictionary, priority: int) -> String:
	var mark := "☑ %d" % priority if priority > 0 else "☐  "
	var state := str(STATE_TEXTS.get(str(room.get("state", "")), ""))
	var line := "%s　%s %dm　（%s・待っている人 %d）" % [mark, str(room["name"]), int(round(float(room["distance_m"]))), state, int(room.get("waiting", 0))]
	if int(room.get("place", 0)) > 0:
		line += "　あなたは %d 番目" % int(room["place"])
	return line


## 呼ばれた：どのルームか（名前・距離・何番目の希望か）と、返事の残り秒を出して、答えを待つ。
func _show_offer(data: Dictionary) -> void:
	_offer = data
	_offer_until_msec = Time.get_ticks_msec() + int(float(data.get("wait_s", 0.0)) * 1000.0)
	_offer_text.text = "「%s %dm」のレースに呼ばれました。\n（第%d希望）\n入りますか？" % [str(data["name"]), int(round(float(data["distance_m"]))), int(data.get("priority", 1))]
	_offer_panel.visible = true
	_update_offer_time()
	_accept_button.grab_focus()
	UIAudio.play_confirmation()


func _close_offer() -> void:
	_offer = {}
	if _offer_panel != null:
		_offer_panel.visible = false
	if is_inside_tree() and (get_viewport().gui_get_focus_owner() == null or not get_viewport().gui_get_focus_owner().is_visible_in_tree()):
		_pick_button.grab_focus()


func _update_offer_time() -> void:
	var left := maxi(int(ceil(float(_offer_until_msec - Time.get_ticks_msec()) / 1000.0)), 0)
	_offer_time.text = "返事を待つのは、あと %d 秒" % left


func _process(delta: float) -> void:
	if not _offer.is_empty():
		_update_offer_time()
	if _connect_wait_s >= 0.0:
		_connect_wait_s += delta
		if _connect_wait_s >= OnlineConfig.connect_timeout_s():
			_connect_wait_s = -1.0
			_client.disconnect_from_server()
			_set_status("サーバーにつながりません。")


## レースの画面が読むもの（距離・出走・自分の番号）を決めて、レースの画面へ。
func _go_to_race(data: Dictionary) -> void:
	RaceSession.select_distance(float(data["distance_m"]))
	RaceSession.set_online_entries(data["entries"])
	RaceSession.set_online_view(OnlineSession.peer_id)
	get_tree().change_scene_to_file(LOCAL_RACE_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		viewport.set_input_as_handled()
		if not _offer.is_empty():
			answer(false)
		else:
			UIAudio.play_back()
			go_back()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
