extends GutTest
## オンラインの部屋の画面：つなぐ → 部屋の一覧（作る・入る）→ 部屋の中（選ぶ・主の決めごと・人を出す）。つながらない・断られたときは、わけを出す。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const LobbyScene := preload("res://scenes/online_lobby.tscn")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const TEST_PORT := Protocol.DEFAULT_PORT + 1001
const WAIT_S := 3.0

var _server: Node


func before_each() -> void:
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


func after_each() -> void:
	# つながりは場面をまたいで残るので、テストごとに切る。
	OnlineSession.close()


func _lobby() -> Control:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	(lobby.find_child("ServerEdit", true, false) as LineEdit).text = "ws://127.0.0.1:%d" % TEST_PORT
	return lobby


func _status(lobby: Control) -> String:
	return (lobby.find_child("Status", true, false) as Label).text


## 条件が成り立つまで待つ（成り立たなければ、決めた秒数であきらめる）。
func _wait_until(condition: Callable, max_s: float = WAIT_S) -> void:
	var waited := 0.0
	while not condition.call() and waited < max_s:
		await wait_seconds(0.05)
		waited += 0.05


## つないで、部屋の一覧が出るまで待つ。
func _connected_lobby() -> Control:
	var lobby := _lobby()
	lobby.connect_to_server()
	await _wait_until(func() -> bool: return (lobby.find_child("LobbyBox", true, false) as Control).visible)
	return lobby


## つないで、部屋を作って、中に入るまで待つ。
func _lobby_in_new_room(room_name: String, password: String = "") -> Control:
	var lobby := await _connected_lobby()
	(lobby.find_child("RoomNameEdit", true, false) as LineEdit).text = room_name
	(lobby.find_child("CreatePasswordEdit", true, false) as LineEdit).text = password
	lobby.create_room()
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 1)
	return lobby


## 画面を使わない、もう1人（名乗って、部屋の一覧の所にいる）。
func _other(player_name: String) -> Node:
	var other: Node = OnlineClient.new()
	add_child_autofree(other)
	other.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(other.connected, WAIT_S)
	other.hello(player_name)
	await wait_seconds(0.2)
	return other


func _first_room_id() -> int:
	return int(_server.room_list()[0]["room_id"])


func _press_key(key: Key, character: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = character
	event.pressed = true
	get_viewport().push_input(event)
	event.pressed = false
	get_viewport().push_input(event)


func _press_pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	get_viewport().push_input(event)
	event.pressed = false
	get_viewport().push_input(event)


func test_connect_screen_keyboard_and_pad_navigation_without_a_mouse() -> void:
	var lobby := _lobby()
	await wait_process_frames(2)
	var connect := lobby.find_child("ConnectButton", true, false) as Button
	var back := lobby.find_child("BackButton", true, false) as Button
	var edit := lobby.find_child("ServerEdit", true, false) as LineEdit
	assert_eq(get_viewport().gui_get_focus_owner(), connect)
	_press_key(KEY_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), back)
	_press_pad(JOY_BUTTON_DPAD_UP)
	assert_eq(get_viewport().gui_get_focus_owner(), connect)
	_press_key(KEY_UP)
	assert_eq(get_viewport().gui_get_focus_owner(), edit)
	var address := edit.text
	edit.caret_column = address.length()
	_press_key(KEY_C, 99)
	assert_eq(edit.text, address + "c", "サーバー入力中のCは文字入力")
	edit.text = address
	_press_key(KEY_TAB)
	assert_eq(get_viewport().gui_get_focus_owner(), connect)
	_press_key(KEY_X)
	await _wait_until(func() -> bool: return (lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	var create := lobby.find_child("OpenCreateButton", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), create)
	_press_pad(JOY_BUTTON_A)
	assert_true(lobby.is_dialog_open())
	_press_pad(JOY_BUTTON_B)
	assert_false(lobby.is_dialog_open())
	assert_eq(get_viewport().gui_get_focus_owner(), create)
	_press_key(KEY_X)
	assert_true(lobby.is_dialog_open())
	_press_key(KEY_ESCAPE)
	assert_false(lobby.is_dialog_open())
	assert_eq(get_viewport().gui_get_focus_owner(), create)


func test_refresh_preserves_focus_and_recovers_after_disconnect() -> void:
	var owner := await _other("一覧の主")
	owner.create_room("選択を維持")
	var lobby := await _connected_lobby()
	var room_name := "Room%d" % _first_room_id()
	await _wait_until(func() -> bool: return lobby.find_child(room_name, true, false) != null)
	(lobby.find_child(room_name, true, false) as Button).grab_focus()
	lobby.call("_refresh")
	assert_eq(str(get_viewport().gui_get_focus_owner().name), room_name)
	var back := lobby.find_child("BackButton", true, false) as Button
	back.grab_focus()
	lobby.call("_refresh")
	assert_eq(get_viewport().gui_get_focus_owner(), back)
	(lobby.find_child(room_name, true, false) as Button).grab_focus()
	_server.stop()
	await _wait_until(func() -> bool: return (lobby.find_child("ConnectBox", true, false) as Control).visible)
	assert_eq(get_viewport().gui_get_focus_owner(), lobby.find_child("ConnectButton", true, false))


func test_online_config_names_a_server_and_the_limits() -> void:
	assert_true(OnlineConfig.validate(OnlineConfig.values()).is_empty())
	assert_true(OnlineConfig.is_server_url(OnlineConfig.server_url()))
	assert_gt(OnlineConfig.connect_timeout_s(), 0.0)
	assert_true(OnlineConfig.is_server_url("wss://example.onrender.com"))
	assert_false(OnlineConfig.is_server_url("http://example.com"))
	assert_false(OnlineConfig.is_server_url("ws://"))
	# サーバーの計算の回数は、決めた範囲の整数。
	var fps_range: Vector2 = OnlineConfig.SERVER_MAX_FPS_RANGE
	assert_between(float(OnlineConfig.server_max_fps()), fps_range.x, fps_range.y)
	assert_gt(OnlineConfig.max_rooms(), 0)
	assert_gt(OnlineConfig.chat_max_length(), 0)
	var good := {"server_url": "ws://x", "default_room": "部屋", "connect_timeout_s": 8.0, "server_max_fps": int(fps_range.x), "max_rooms": 6, "chat_max_length": 60, "result_linger_s": 20, "log_keep_days": 14}
	assert_true(OnlineConfig.validate(good).is_empty())
	for bad: Dictionary in [
		{"server_url": "http://x"}, {"connect_timeout_s": 0.0},
		{"server_max_fps": fps_range.x - 1.0}, {"server_max_fps": fps_range.y + 1.0}, {"server_max_fps": 30.5}, {"server_max_fps": "30"},
		{"default_room": "  "}, {"default_room": "あ".repeat(Protocol.ROOM_NAME_MAX_LENGTH + 1)}, {"default_room": 5},
		{"max_rooms": 0}, {"max_rooms": 2.5}, {"chat_max_length": 0},
	]:
		var changed := good.duplicate()
		changed.merge(bad, true)
		assert_false(OnlineConfig.validate(changed).is_empty(), str(bad))


func test_the_screen_starts_with_the_configured_server_and_the_trainer_name() -> void:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	assert_eq((lobby.find_child("ServerEdit", true, false) as LineEdit).text, OnlineConfig.server_url())
	assert_true((lobby.find_child("NameLabel", true, false) as Label).text.contains(TrainerProfile.trainer_name()))
	# つなぐ前は、つなぐ所だけを出す。
	assert_true((lobby.find_child("ConnectBox", true, false) as Control).visible)
	assert_false((lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_false((lobby.find_child("RoomBox", true, false) as Control).visible)
	# 部屋の名前は、最初から入っている（文字が打ちにくい端末でも、そのまま作れるように）。
	assert_eq((lobby.find_child("RoomNameEdit", true, false) as LineEdit).text, OnlineConfig.default_room())


func test_connecting_shows_the_room_list_and_creating_enters_the_room() -> void:
	var lobby := await _connected_lobby()
	assert_false((lobby.find_child("ConnectBox", true, false) as Control).visible)
	assert_true((lobby.find_child("RoomsTitle", true, false) as Label).text.contains("0／%d" % OnlineConfig.max_rooms()))
	# 「部屋を作る」で、作る窓が出る。注意書きは、窓の中にある。
	var dialog := lobby.find_child("CreateDialog", true, false) as Control
	assert_false(dialog.visible)
	(lobby.find_child("OpenCreateButton", true, false) as Button).pressed.emit()
	assert_true(dialog.visible)
	assert_true((dialog.find_child("CreateNote", true, false) as Label).text.contains("部屋の主"))
	(lobby.find_child("RoomNameEdit", true, false) as LineEdit).text = "テスト部屋"
	lobby.create_room()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 1)
	assert_true((lobby.find_child("RoomBox", true, false) as Control).visible)
	assert_false((lobby.find_child("LobbyBox", true, false) as Control).visible)
	# 自分は、1枠の行に出る（名前と、部屋の主の印）。この行でだけ、ぷるりんを選べる。
	var first: Control = lobby.get("_slots")[0]
	assert_true(str(first.call("trainer_text")).contains(TrainerProfile.trainer_name()))
	assert_true(str(first.call("trainer_text")).contains("主"))
	assert_eq(first.focus_mode, Control.FOCUS_ALL)
	assert_eq(lobby.my_slot(), 0)
	# 2行目からは、CPU（入れる部屋なので）。まだ「おまかせ」。主は、この行でCPUのぷるりんを決められる。
	var second: Control = lobby.get("_slots")[1]
	assert_eq(str(second.call("trainer_text")), "CPU")
	assert_eq(str(second.call("shown_text")), "おまかせ")
	assert_eq(second.focus_mode, Control.FOCUS_ALL)
	assert_true((lobby.find_child("RoomTitle", true, false) as Label).text.contains("テスト部屋"))
	assert_true(lobby.is_host())
	# 「部屋を出る」で、一覧へ戻る（つながりは切らない）。誰もいなくなった部屋は、消える。
	assert_true((lobby.find_child("LeaveButton", true, false) as Button).is_visible_in_tree())
	assert_false((lobby.find_child("BackButton", true, false) as Button).is_visible_in_tree())
	lobby.go_back()
	await _wait_until(func() -> bool: return (lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_eq(_server.room_count(), 0)
	assert_eq(_server.peer_count(), 1)


func test_listed_rooms_can_be_joined_and_locked_ones_need_the_password() -> void:
	var owner := await _other("ミナト")
	owner.create_room("朝の部屋", "ひみつ")
	var lobby := await _connected_lobby()
	var room_id := _first_room_id()
	await _wait_until(func() -> bool: return lobby.find_child("Room%d" % room_id, true, false) != null)
	var row := lobby.find_child("Room%d" % room_id, true, false) as Button
	assert_eq((row.find_child("Name", true, false) as Label).text, "朝の部屋")
	assert_eq((row.find_child("Host", true, false) as Label).text, "ミナト")
	assert_true((row.find_child("Count", true, false) as Label).text.begins_with("1／"))
	# 施錠の印は、文ではなく、絵で出す。
	assert_not_null(row.find_child("Lock", true, false))
	# 作れる数ぶんの行を、いつも出す（残りは「空き」）。
	assert_eq(lobby.find_child("Rooms", true, false).get_child_count(), OnlineConfig.max_rooms())
	# 選ぶと、パスワードを聞く窓が出る。違うと、入れない。わけが出る。
	var dialog := lobby.find_child("PasswordDialog", true, false) as Control
	assert_false(dialog.visible)
	row.pressed.emit()
	assert_true(dialog.visible)
	assert_true((dialog.find_child("Title", true, false) as Label).text.contains("朝の部屋"))
	(lobby.find_child("JoinPasswordEdit", true, false) as LineEdit).text = "ちがう"
	lobby.join_with_password()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return _status(lobby).contains("パスワード"))
	assert_true(_status(lobby).contains("パスワード"))
	# 「やめる」（戻る）は、窓だけを閉じる。
	lobby.choose_room(room_id)
	lobby.go_back()
	assert_false(dialog.visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	lobby.choose_room(room_id)
	(lobby.find_child("JoinPasswordEdit", true, false) as LineEdit).text = "ひみつ"
	lobby.join_with_password()
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	assert_eq(lobby.my_slot(), 1)
	assert_false(lobby.is_host())
	assert_eq(_server.room_members(room_id).size(), 2)


func test_a_bad_server_address_is_explained_without_connecting() -> void:
	var lobby := _lobby()
	(lobby.find_child("ServerEdit", true, false) as LineEdit).text = "http://127.0.0.1"
	lobby.connect_to_server()
	assert_true(_status(lobby).contains("ws://"))
	assert_eq(_server.peer_count(), 0)


func test_a_missing_server_is_explained() -> void:
	_server.stop()
	var lobby := _lobby()
	lobby.connect_to_server()
	await _wait_until(func() -> bool: return _status(lobby).contains("つながりません"), OnlineConfig.connect_timeout_s() + 2.0)
	assert_true(_status(lobby).contains("つながりません"))
	assert_true((lobby.find_child("ConnectBox", true, false) as Control).visible)


func test_the_host_picks_a_pururin_and_the_room_settings_and_can_then_start() -> void:
	var lobby := await _lobby_in_new_room("選ぶ部屋")
	var advance := lobby.find_child("AdvanceDialog", true, false) as Control
	var confirm := lobby.find_child("ConfirmButton", true, false) as Button
	# 作った人は、部屋の主。まだ選んでいないので、確定できない。先へ進む窓も、出ない。
	assert_true(lobby.is_host())
	assert_false(advance.visible)
	assert_true(confirm.disabled)
	# ぷるりんを選ぶと、行に名前が出て、確定できるようになる。確定すると、主が先へ進める。
	var first_id := str(PururinRosterConfig.values()["roster"][0]["id"])
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == first_id)
	assert_eq(lobby.my_pururin_id(), first_id)
	assert_eq(str(lobby.get("_slots")[0].call("shown_text")), lobby.pururin_name(first_id))
	assert_false(confirm.disabled)
	assert_false(advance.visible)
	confirm.pressed.emit()
	# 全員（ここでは自分だけ）が確定すると、主に「出走表へ進みますか」の窓が出る。
	await _wait_until(func() -> bool: return advance.visible)
	assert_true(advance.visible)
	assert_eq((lobby.find_child("AdvanceButton", true, false) as Button).text, "出走表へ")
	assert_eq((lobby.find_child("Confirmed1", true, false) as Control).modulate.a, 1.0)
	# 「まだ進まない」で閉じても、下のボタンから、もう一度開ける。
	(lobby.find_child("AdvanceCancelButton", true, false) as Button).pressed.emit()
	assert_false(advance.visible)
	assert_eq(confirm.text, "出走表へ…")
	confirm.pressed.emit()
	assert_true(advance.visible)
	(lobby.find_child("AdvanceCancelButton", true, false) as Button).pressed.emit()
	# 距離のボタンを押すと、サーバーの部屋の距離が変わり、そのボタンが選ばれた見た目になる。
	var distances: Array = RaceSession.supported_distances_m()
	var default_button := lobby.find_child("Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), true, false) as Button
	assert_true(default_button.button_pressed)
	var wanted := float(distances[posmod(distances.find(RaceSession.DEFAULT_DISTANCE_M) + 1, distances.size())])
	var wanted_button := lobby.find_child("Distance%d" % int(wanted), true, false) as Button
	wanted_button.pressed.emit()
	await _wait_until(func() -> bool: return is_equal_approx(float(_server.call("_room_fields", _first_room_id())["distance_m"]), wanted))
	await _wait_until(func() -> bool: return wanted_button.button_pressed and not default_button.button_pressed)
	assert_true(wanted_button.button_pressed)
	assert_false(default_button.button_pressed)
	# 出走数を減らす・CPUを外す・パスワードを付ける。
	var room_id := _first_room_id()
	lobby.step_field_size(-1)
	await _wait_until(func() -> bool: return int(_server.call("_room_fields", room_id)["field_size"]) == Protocol.ROOM_CAPACITY - 1)
	assert_true((lobby.find_child("FieldSizeLabel", true, false) as Label).text.contains(str(Protocol.ROOM_CAPACITY - 1)))
	lobby.step_cpu(1)
	await _wait_until(func() -> bool: return not bool(_server.call("_room_fields", room_id)["cpu"]))
	assert_eq((lobby.find_child("CpuLabel", true, false) as Label).text, "なし")
	# パスワードは、窓で確かめて、変える。最初は「なし」。
	var change_dialog := lobby.find_child("PasswordChangeDialog", true, false) as Control
	(lobby.find_child("OpenPasswordButton", true, false) as Button).pressed.emit()
	assert_true(change_dialog.visible)
	assert_true((lobby.find_child("CurrentPassword", true, false) as Label).text.contains("なし"))
	(lobby.find_child("PasswordEdit", true, false) as LineEdit).text = "かぎ"
	lobby.change_password()
	assert_false(change_dialog.visible)
	await _wait_until(func() -> bool: return bool(_server.call("_room_fields", room_id)["locked"]))
	await _wait_until(func() -> bool: return (lobby.find_child("RoomLock", true, false) as Control).visible)
	assert_true((lobby.find_child("RoomLock", true, false) as Control).visible)
	# 主は、今のパスワードを、窓で確かめられる。
	lobby.open_password_change_dialog()
	assert_true((lobby.find_child("CurrentPassword", true, false) as Label).text.contains("かぎ"))
	lobby.close_dialogs()


func test_a_guest_cannot_change_the_room_and_skips_pururins_others_took() -> void:
	var owner := await _other("主")
	owner.create_room("客の部屋")
	var first_id := str(PururinRosterConfig.values()["roster"][0]["id"])
	var second_id := str(PururinRosterConfig.values()["roster"][1]["id"])
	await wait_seconds(0.2)
	owner.send(Protocol.PICK, {"pururin_id": first_id})
	var lobby := await _connected_lobby()
	lobby.choose_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	# 2人目は、主ではない。開始のボタンとパスワードの行は出ず、決めごとは替えられない。人を出すボタンも無い。
	assert_false(lobby.is_host())
	assert_false((lobby.find_child("AdvanceDialog", true, false) as Control).visible)
	assert_false((lobby.find_child("OpenPasswordButton", true, false) as Button).visible)
	# パスワードそのものは、主にしか届かない。
	assert_false(OnlineSession.room.has("password"))
	for button_name: String in ["Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), "FieldSizeNext", "CpuNext"]:
		assert_true((lobby.find_child(button_name, true, false) as Button).disabled, button_name)
	assert_true((lobby.find_child("MemberMenu1", true, false) as Button).disabled)
	# 主の行（1行目）は、見るだけ。主の名前と、選んだぷるりんが出る。
	var host_row: Control = lobby.get("_slots")[0]
	assert_true(str(host_row.call("trainer_text")).contains("主"))
	assert_eq(str(host_row.call("shown_text")), lobby.pururin_name(first_id))
	# ほかの人の行にも、カーソルを置ける（その人とぷるりんの紹介を見るため）。選ぶことは、できない。
	assert_eq(host_row.focus_mode, Control.FOCUS_ALL)
	# 主が1体目を選んでいるので、「次へ」は2体目になる。
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == second_id)
	assert_eq(lobby.my_pururin_id(), second_id)


func test_the_host_puts_a_guest_out_and_the_guest_is_told_why() -> void:
	var lobby := await _lobby_in_new_room("出す部屋")
	var room_id := _first_room_id()
	var guest := await _other("客")
	var heard := []
	guest.message_received.connect(func(data: Dictionary) -> void: heard.append(str(data["t"])))
	guest.join_room(room_id)
	await _wait_until(func() -> bool: return not (lobby.find_child("MemberMenu2", true, false) as Button).disabled)
	# 主の画面には、ほかの人の行にだけ「︙」がある（自分の行・CPUの行は、押せない）。
	assert_true((lobby.find_child("MemberMenu1", true, false) as Button).disabled)
	assert_true((lobby.find_child("MemberMenu3", true, false) as Button).disabled)
	# 押すと、確かめる窓が出るだけ。「やめる」なら、何も起きない。
	var dialog := lobby.find_child("KickDialog", true, false) as Control
	(lobby.find_child("MemberMenu2", true, false) as Button).pressed.emit()
	assert_true(dialog.visible)
	assert_true((dialog.find_child("Title", true, false) as Label).text.contains("客"))
	lobby.close_dialogs()
	await wait_seconds(0.3)
	assert_false(heard.has(Protocol.KICKED))
	assert_eq(_server.room_members(room_id).size(), 2)
	# 窓の「退出させる」で、はじめて退出になる。
	lobby.open_kick_dialog(1)
	lobby.confirm_kick()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return heard.has(Protocol.KICKED))
	assert_true(heard.has(Protocol.KICKED))
	assert_eq(_server.room_members(room_id).size(), 1)


func test_being_put_out_returns_the_screen_to_the_room_list_with_the_reason() -> void:
	var owner := await _other("主")
	owner.create_room("出される部屋")
	var lobby := await _connected_lobby()
	lobby.choose_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	owner.send(Protocol.KICK, {"peer_id": OnlineSession.peer_id})
	await _wait_until(func() -> bool: return (lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true(_status(lobby).contains("退出"))


func test_the_entry_list_shows_gates_and_the_host_can_redraw_and_swap_them() -> void:
	var lobby := await _lobby_in_new_room("出走表の部屋")
	var room_id := _first_room_id()
	var guest := await _other("客")
	# 客は、自己紹介と、自分で入れた画像（小さなJPEG）を名乗っている。
	var picture := Image.create(8, 8, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.9, 0.3, 0.2))
	guest.hello("客", "レースが好きです。", {"kind": "file", "id": "", "image": Marshalls.raw_to_base64(picture.save_jpg_to_buffer(0.9))})
	await wait_seconds(0.2)
	guest.join_room(room_id)
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	guest.send(Protocol.PICK, {"pururin_id": ids[3]})
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	# 部屋の場面では、枠番号を出さない（枠順は、まだ決まっていない）。
	assert_false((lobby.get("_badges")[0] as Control).visible)
	var advance := lobby.find_child("AdvanceDialog", true, false) as Control
	guest.send(Protocol.CONFIRM, {"on": true})
	lobby.toggle_confirm()
	await _wait_until(func() -> bool: return advance.visible)
	(lobby.find_child("AdvanceButton", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return OnlineSession.in_entries())
	await wait_seconds(0.2)
	# 出走表：枠番号が出て、全出走（人とCPU）が、枠順に並ぶ。確定は、いったん外れる。
	assert_true(OnlineSession.in_entries())
	assert_true((lobby.get("_badges")[0] as Control).visible)
	assert_false(advance.visible)
	# CPUの枠では、CPUトレーナーの紹介が出る。客の枠では、届いた画像が、絵に戻っている。
	for index in (OnlineSession.room["entries"] as Array).size():
		var entry: Dictionary = OnlineSession.room["entries"][index]
		if int(entry["peer_id"]) == 0:
			lobby.call("_on_row_focused", index)
			lobby.open_profile_dialog()
			assert_eq((lobby.find_child("ProfileName", true, false) as Label).text, str(entry["trainer_name"]))
			assert_true((lobby.find_child("ProfileNote", true, false) as Label).text.contains("CPUトレーナー"))
			assert_true((lobby.find_child("ProfilePortrait", true, false) as Control).visible)
			lobby.close_dialogs()
			break
	for peer: int in OnlineSession.profiles:
		if str(OnlineSession.profiles[peer]["name"]) == "客":
			assert_eq(str(OnlineSession.profiles[peer]["kind"]), "file")
			assert_not_null(OnlineSession.profiles[peer]["texture"])
	assert_false((lobby.get("_rules_card") as Control).visible)
	assert_true((lobby.get("_gates_card") as Control).visible)
	var entries: Array = OnlineSession.room["entries"]
	assert_eq(entries.size(), Protocol.ROOM_CAPACITY)
	for index in entries.size():
		assert_eq(str(lobby.get("_row_infos")[index]["pururin_id"]), str(entries[index]["id"]))
		assert_eq(str(lobby.get("_slots")[index].call("shown_text")), lobby.pururin_name(str(entries[index]["id"])))
	# 行を選んで、下の枠と入れ替える（主だけ）。
	lobby.call("_on_row_focused", 0)
	var first_id := str(entries[0]["id"])
	var second_id := str(entries[1]["id"])
	lobby.move_selected_gate(1)
	await _wait_until(func() -> bool: return str(OnlineSession.room["entries"][1]["id"]) == first_id)
	assert_eq([str(OnlineSession.room["entries"][0]["id"]), str(OnlineSession.room["entries"][1]["id"])], [second_id, first_id])
	assert_eq(int(lobby.get("_selected_gate")), 1, "カーソルは、動かした先に付いていく")
	# 全員が確定すると、主に「レース開始」の窓が出る。「まだ進まない」で閉じる。
	guest.send(Protocol.CONFIRM, {"on": true})
	lobby.toggle_confirm()
	await _wait_until(func() -> bool: return advance.visible)
	assert_eq((lobby.find_child("AdvanceButton", true, false) as Button).text, "レース開始")
	(lobby.find_child("AdvanceCancelButton", true, false) as Button).pressed.emit()
	# 主が「部屋へ戻る」と、選ぶ所へ戻り、枠番号が消える。
	lobby.back_to_room_phase()
	await _wait_until(func() -> bool: return not OnlineSession.in_entries())
	await wait_seconds(0.2)
	assert_false((lobby.get("_badges")[0] as Control).visible)
	# どの行でも、カーソルを置くと、そのぷるりんが右に出て、板の右上に、その人の画像が出る。押すと、紹介の窓。
	var person := lobby.find_child("PersonButton", true, false) as Button
	var profile := lobby.find_child("ProfileDialog", true, false) as Control
	lobby.call("_on_row_focused", 1)
	assert_true(person.visible)
	assert_false(profile.visible)
	await _wait_until(func() -> bool: return OnlineSession.profiles.size() >= 2)
	person.pressed.emit()
	assert_true(profile.visible)
	assert_eq((lobby.find_child("ProfileName", true, false) as Label).text, "客")
	assert_true((lobby.find_child("ProfileIntroduction", true, false) as Label).text.contains("レースが好き"))
	lobby.close_dialogs()
	lobby.call("_on_row_focused", 0)
	person.pressed.emit()
	assert_true((lobby.find_child("ProfileNote", true, false) as Label).text.contains("あなた"))
	assert_true((lobby.find_child("ProfileNote", true, false) as Label).text.contains("部屋の主"))
	lobby.close_dialogs()


## 上下左右・決定の操作を、キーボードやゲームパッドの代わりに送る。
func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_seconds(0.05)


func _focused_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return str(focused.name) if focused != null else ""


func test_the_room_can_be_worked_without_a_mouse() -> void:
	var lobby := await _lobby_in_new_room("キーの部屋")
	var room_id := _first_room_id()
	var distances: Array = RaceSession.supported_distances_m()
	var default_index := distances.find(RaceSession.DEFAULT_DISTANCE_M)
	# 両端に、オフラインと同じ「‹ L1」「R1 ›」がある。
	assert_not_null(lobby.find_child("DistancePrev", true, false))
	assert_not_null(lobby.find_child("DistanceNext", true, false))
	# 自分の行から「上」で、今の距離のボタンへ。「右」で、となりの距離へ移り、そのまま、その距離になる。
	(lobby.get("_slots")[0] as Control).grab_focus()
	await _press("ui_up")
	assert_eq(_focused_name(), "Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M))
	await _press("ui_right")
	var next_distance := float(distances[default_index + 1])
	assert_eq(_focused_name(), "Distance%d" % int(next_distance))
	await _wait_until(func() -> bool: return is_equal_approx(float(_server.call("_room_fields", room_id)["distance_m"]), next_distance))
	assert_almost_eq(float(_server.call("_room_fields", room_id)["distance_m"]), next_distance, 0.001)
	# L1 で、1つ前の距離へ戻る（どこにカーソルがあっても）。選択の枠も、付いていく。
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	get_viewport().push_input(shoulder)
	await _wait_until(func() -> bool: return is_equal_approx(float(_server.call("_room_fields", room_id)["distance_m"]), RaceSession.DEFAULT_DISTANCE_M))
	assert_almost_eq(float(_server.call("_room_fields", room_id)["distance_m"]), RaceSession.DEFAULT_DISTANCE_M, 0.001)
	assert_eq(_focused_name(), "Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M))
	# 「下」で自分の行へ。自分の行の「右」は、オフラインと同じで、ぷるりんを次の個体に替える。
	await wait_seconds(0.2)
	await _press("ui_down")
	assert_eq(_focused_name(), "Slot0")
	await _press("ui_right")
	assert_eq(_focused_name(), "Slot0")
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	assert_eq(lobby.my_pururin_id(), str(PururinRosterConfig.values()["roster"][0]["id"]))
	# 右下の「確定」から「上」で、人の画像へ。「下」で確定へ戻り、「左」で「部屋を出る」。
	(lobby.find_child("ConfirmButton", true, false) as Button).grab_focus()
	await _press("ui_up")
	assert_eq(_focused_name(), "PersonButton")
	await _press("ui_down")
	assert_eq(_focused_name(), "ConfirmButton")
	await _press("ui_left")
	assert_eq(_focused_name(), "LeaveButton")
	# 人の画像にカーソルを合わせて、決定で、紹介の窓が開く。「左」で、行へ戻れる。
	await _press("ui_up")
	assert_eq(_focused_name(), "PersonButton")
	await _press("ui_accept")
	assert_true((lobby.find_child("ProfileDialog", true, false) as Control).visible)
	lobby.close_dialogs()
	(lobby.find_child("PersonButton", true, false) as Button).grab_focus()
	await _press("ui_left")
	assert_eq(_focused_name(), "Slot0")
	# 自分の行から「下」をたどると、決めごとのボタンを通って、ひとことの入力らんへ着く。
	(lobby.get("_slots")[0] as Control).grab_focus()
	var seen: Array = []
	for _step in 14:
		await _press("ui_down")
		seen.append(_focused_name())
		if _focused_name() == "ChatEdit":
			break
	assert_true(seen.has("FieldSizePrevious"), str(seen))
	assert_eq(seen.back(), "ChatEdit", str(seen))


func test_a_guest_cannot_move_the_distance() -> void:
	var owner := await _other("主")
	owner.create_room("客の距離")
	var lobby := await _connected_lobby()
	lobby.choose_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	# 主でない人は、距離の段にカーソルを置けない。自分の行から「上」を押しても、動かない。L1・R1 も効かない。
	(lobby.get("_slots")[1] as Control).grab_focus()
	await _press("ui_up")
	assert_eq(_focused_name(), "Slot0")
	await _press("ui_up")
	assert_eq(_focused_name(), "Slot0")
	lobby.step_distance(1)
	await wait_seconds(0.3)
	assert_almost_eq(float(_server.call("_room_fields", _first_room_id())["distance_m"]), RaceSession.DEFAULT_DISTANCE_M, 0.001)
	assert_true((lobby.find_child("DistanceNext", true, false) as Button).disabled)
	# ほかの人の行（見るだけの行）からは、「右」で、その人の画像へ行ける。
	(lobby.get("_slots")[0] as Control).grab_focus()
	await _press("ui_right")
	assert_eq(_focused_name(), "PersonButton")
	await _press("ui_left")
	assert_eq(_focused_name(), "Slot0")


func test_the_host_picks_cpu_pururins_and_trainers_on_the_rows() -> void:
	var lobby := await _lobby_in_new_room("CPUの部屋")
	var room_id := _first_room_id()
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == ids[0])
	# CPUの行（2行目）で「次へ」：自分が使っている1体目は飛ばして、2体目になる。
	assert_true(lobby.is_cpu_row(1))
	lobby.step_row_pururin(1, 1)
	await _wait_until(func() -> bool: return str(_server.room_cpus(room_id)[0]["pururin_id"]) == ids[1])
	await _wait_until(func() -> bool: return str(lobby.get("_slots")[1].call("shown_text")) == lobby.pururin_name(ids[1]))
	assert_eq(str(lobby.get("_slots")[1].call("shown_text")), lobby.pururin_name(ids[1]))
	assert_true(str(lobby.get("_slots")[1].call("trainer_text")).begins_with("CPU "))
	# その行の紹介（Y）を開くと、トレーナーが出て、主には「トレーナーを変える」がある。
	(lobby.get("_slots")[1] as Control).grab_focus()
	var y_press := InputEventJoypadButton.new()
	y_press.button_index = JOY_BUTTON_Y
	y_press.pressed = true
	get_viewport().push_input(y_press)
	await wait_seconds(0.1)
	assert_true((lobby.find_child("ProfileDialog", true, false) as Control).visible, "Yで、紹介の窓が開く")
	assert_true((lobby.find_child("ProfileTrainerButton", true, false) as Button).visible)
	(lobby.find_child("ProfileTrainerButton", true, false) as Button).pressed.emit()
	assert_true(lobby.is_trainer_picker_open())
	var trainers: Array = load("res://scripts/config/cpu_trainers_config.gd").values()
	lobby.call("_on_trainer_picked", str(trainers[4]["id"]))
	assert_false(lobby.is_trainer_picker_open())
	await _wait_until(func() -> bool: return str(_server.room_cpus(room_id)[0]["trainer_id"]) == str(trainers[4]["id"]))
	await _wait_until(func() -> bool: return str(lobby.get("_slots")[1].call("trainer_text")).contains(str(trainers[4]["name"])))
	assert_true(str(lobby.get("_slots")[1].call("trainer_text")).contains(str(trainers[4]["name"])))
	# 一覧の窓からも選べる。Xで「おまかせ」に戻る。
	lobby.open_picker_for_row(2)
	assert_true(lobby.is_picker_open())
	lobby.call("_on_picker_picked", ids[6])
	await _wait_until(func() -> bool: return str(_server.room_cpus(room_id)[1]["pururin_id"]) == ids[6])
	assert_eq(str(_server.room_cpus(room_id)[1]["pururin_id"]), ids[6])
	await wait_seconds(0.2)
	lobby.clear_cpu_row(2)
	await _wait_until(func() -> bool: return str(_server.room_cpus(room_id)[1]["pururin_id"]).is_empty())
	assert_eq(str(_server.room_cpus(room_id)[1]["pururin_id"]), "")
	# 出走表でも、主は、CPUの枠を替えられる。
	lobby.toggle_confirm()
	await _wait_until(func() -> bool: return (lobby.find_child("AdvanceDialog", true, false) as Control).visible)
	lobby.advance()
	await _wait_until(func() -> bool: return OnlineSession.in_entries())
	await wait_seconds(0.2)
	var gate := -1
	for entry: Dictionary in OnlineSession.room["entries"]:
		if int(entry["peer_id"]) == 0 and str(entry["id"]) != ids[1]:
			gate = int(entry["gate"])
			break
	assert_true(lobby.is_cpu_row(gate))
	var before := str(OnlineSession.room["entries"][gate]["id"])
	lobby.step_row_pururin(gate, 1)
	await _wait_until(func() -> bool: return str(OnlineSession.room["entries"][gate]["id"]) != before)
	var after := str(OnlineSession.room["entries"][gate]["id"])
	assert_ne(after, before)
	var others := (OnlineSession.room["entries"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry["gate"]) != gate).map(func(entry: Dictionary) -> String: return str(entry["id"]))
	assert_false(others.has(after), "ほかの枠が使っている個体には、ならない")


func test_a_guest_cannot_pick_cpu_pururins() -> void:
	var owner := await _other("主")
	owner.create_room("客とCPU")
	var lobby := await _connected_lobby()
	lobby.choose_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	assert_false(lobby.is_cpu_row(2))
	assert_eq((lobby.get("_slots")[2] as Control).focus_mode, Control.FOCUS_NONE)
	lobby.step_row_pururin(2, 1)
	await wait_seconds(0.3)
	assert_eq(str(_server.room_cpus(_first_room_id())[0]["pururin_id"]), "")


func test_room_events_show_as_a_notice_and_in_the_chat() -> void:
	var owner := await _other("主")
	owner.create_room("知らせの部屋")
	var lobby := await _connected_lobby()
	lobby.choose_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	var chat := lobby.find_child("ChatLog", true, false) as RichTextLabel
	# もう1人が入る：上の案内と、ひとことの欄の両方に出る。
	var third := await _other("三人目")
	third.join_room(_first_room_id())
	await _wait_until(func() -> bool: return _status(lobby).contains("三人目"))
	assert_true(_status(lobby).contains("部屋に入りました"))
	assert_true(chat.get_parsed_text().contains("三人目 さんが、部屋に入りました"))
	# 主が出る：出たことと、新しい主（入った順で、自分）が、ひとことの欄に残る。
	owner.send(Protocol.LEAVE)
	await _wait_until(func() -> bool: return lobby.is_host())
	await wait_seconds(0.2)
	var shown := chat.get_parsed_text()
	assert_true(shown.contains("主 さんが、部屋を出ました"))
	assert_true(shown.contains("%s さんが、部屋の主になりました" % TrainerProfile.trainer_name()))
	assert_true(_status(lobby).contains("部屋の主になりました"))


func test_chat_lines_show_in_the_room() -> void:
	var lobby := await _lobby_in_new_room("話す部屋")
	var guest := await _other("客")
	guest.join_room(_first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	guest.send(Protocol.CHAT, {"text": "よろしく"})
	(lobby.find_child("ChatEdit", true, false) as LineEdit).text = "こちらこそ"
	lobby.send_chat()
	await _wait_until(func() -> bool: return OnlineSession.chat_log.size() >= 2)
	var shown := (lobby.find_child("ChatLog", true, false) as RichTextLabel).get_parsed_text()
	assert_true(shown.contains("客"))
	assert_true(shown.contains("よろしく"))
	assert_true(shown.contains("こちらこそ"))
	assert_eq((lobby.find_child("ChatEdit", true, false) as LineEdit).text, "", "送ったら、入力らんは空になる")


func test_scenery_is_a_personal_choice_that_the_race_screen_reads() -> void:
	var course_only_before := RaceSession.is_course_only()
	var lobby := await _lobby_in_new_room("景色の部屋")
	# ブラウザ版は、最初から軽い。それ以外は、フル。
	assert_eq(lobby.is_light_scenery(), OS.has_feature("web"))
	var label := lobby.find_child("SceneryLabel", true, false) as Label
	assert_eq(label.text, lobby.scenery_text())
	# 切り替えると、レースの画面が読む「軽い景色か」に、その選択が入る。
	for _press in 2:
		lobby.step_scenery(1)
		assert_eq(label.text, lobby.scenery_text())
		lobby.prepare_race({"distance_m": RaceSession.supported_distances_m()[0], "entries": [{"gate": 0, "id": "x", "player": true, "peer_id": 1}]})
		assert_eq(RaceSession.is_course_only(), lobby.is_light_scenery())
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	RaceSession.set_course_only(course_only_before)
