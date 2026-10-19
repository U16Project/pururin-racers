extends GutTest
## オンラインの部屋の画面：つなぐ → 部屋の一覧（作る・入る）→ 部屋の中（選ぶ・主の決めごと・人を出す）。つながらない・断られたときは、わけを出す。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const ServerChoice := preload("res://scripts/config/online_server_choice.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const LobbyScene := preload("res://scenes/online_lobby.tscn")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const TEST_PORT := Protocol.DEFAULT_PORT + 1001
const WAIT_S := 3.0
const CHOICE_FILE := "user://test_online_server.json"

var _server: Node


func before_each() -> void:
	# 「さっき選んだプル」は、テストごとに消す（前のテストから持ち越さない）。
	OnlineSession.last_pick = ""
	# 本物のサーバーの選びに触らないように、テスト用の保存場所を使う。
	DirAccess.remove_absolute(CHOICE_FILE)
	ServerChoice.use_path(CHOICE_FILE)
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


func after_each() -> void:
	DirAccess.remove_absolute(CHOICE_FILE)
	ServerChoice.use_path(ServerChoice.DEFAULT_SAVE_PATH)
	# つながりは場面をまたいで残るので、テストごとに切る。
	OnlineSession.close()


func _lobby() -> Control:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	(lobby.find_child("CustomServerRadio", true, false) as CheckBox).button_pressed = true
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


## 主の画面で、待機室の「レース開始」→ レース設定の「次へ」と進めて、ぷるりんを選ぶ所まで行く。
func _to_pick(lobby: Control) -> void:
	lobby.open_race()
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	lobby.open_pick()
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	await wait_seconds(0.1)


## 主が画面を使わない部屋で、画面の人が準備OKを押し、主がレース開始・次へを押して、ぷるりんを選ぶ所まで行く。
func _guest_to_pick(lobby: Control, owner: Node) -> void:
	lobby.toggle_lobby_ready()
	await _wait_until(func() -> bool: return OnlineSession.my_lobby_ready())
	owner.send(Protocol.RACE_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	owner.send(Protocol.PICK_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	await wait_seconds(0.1)


## 自分の席（プル選択の、横長の席）の番号。無ければ -1。
func _my_pick_row(lobby: Control) -> int:
	var rows: Array = lobby.get("_pick_rows")
	for index in rows.size():
		if str(rows[index]["kind"]) == "self":
			return index
	return -1


## 一覧の部屋を押して、入室の窓が出るのを待つ（押しただけでは、入らない）。
func _open_join_dialog(lobby: Control, room_id: int) -> Control:
	lobby.choose_room(room_id)
	var dialog := lobby.find_child("JoinDialog", true, false) as Control
	await _wait_until(func() -> bool: return dialog.visible)
	return dialog


## 一覧の部屋に入る（窓の「入室する」まで押す）。
func _enter_listed_room(lobby: Control, room_id: int, password: String = "") -> void:
	await _open_join_dialog(lobby, room_id)
	(lobby.find_child("JoinPasswordEdit", true, false) as LineEdit).text = password
	lobby.join_with_password()


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
	var local := lobby.find_child("LocalServerButton", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), connect)
	# 「つなぐ」の下は、「このPCをサーバーにする」のボタン、その下が「戻る」。
	_press_key(KEY_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), local)
	_press_key(KEY_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), back)
	_press_pad(JOY_BUTTON_DPAD_UP)
	assert_eq(get_viewport().gui_get_focus_owner(), local)
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
	var good := {"server_url": "ws://x", "default_room": "部屋", "connect_timeout_s": 8.0, "server_max_fps": int(fps_range.x), "max_rooms": 6, "chat_max_length": 60, "result_linger_s": 20, "log_keep_days": 14,
		"free_rooms": [{"id": "middle", "name": "中距離", "distance_m": RaceSession.supported_distances_m()[0]}], "free_fill_wait_s": 20, "free_answer_wait_s": 10}
	assert_true(OnlineConfig.validate(good).is_empty())
	for bad: Dictionary in [
		{"server_url": "http://x"}, {"connect_timeout_s": 0.0},
		{"server_max_fps": fps_range.x - 1.0}, {"server_max_fps": fps_range.y + 1.0}, {"server_max_fps": 30.5}, {"server_max_fps": "30"},
		{"default_room": "  "}, {"default_room": "あ".repeat(Protocol.ROOM_NAME_MAX_LENGTH + 1)}, {"default_room": 5},
		{"max_rooms": 0}, {"max_rooms": 2.5}, {"chat_max_length": 0},
		{"free_rooms": []}, {"free_rooms": [{"id": "Bad ID", "name": "a", "distance_m": RaceSession.supported_distances_m()[0]}]},
		{"free_rooms": [{"id": "a", "name": "a", "distance_m": 999.0}]},
		{"free_rooms": [{"id": "a", "name": "a", "distance_m": RaceSession.supported_distances_m()[0]}, {"id": "a", "name": "b", "distance_m": RaceSession.supported_distances_m()[0]}]},
		{"free_fill_wait_s": 0}, {"free_answer_wait_s": 0},
	]:
		var changed := good.duplicate()
		changed.merge(bad, true)
		assert_false(OnlineConfig.validate(changed).is_empty(), str(bad))


func test_the_screen_starts_with_the_configured_server_and_the_trainer_name() -> void:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	# 初めは「標準のサーバー」が選ばれ、そのURLが見える。入力欄は、使えない。
	assert_true((lobby.find_child("DefaultServerRadio", true, false) as CheckBox).button_pressed)
	assert_eq((lobby.find_child("DefaultServerUrl", true, false) as Label).text, OnlineConfig.server_url())
	assert_false((lobby.find_child("ServerEdit", true, false) as LineEdit).editable)
	assert_eq(lobby.selected_server_url(), OnlineConfig.server_url())
	assert_true((lobby.find_child("NameLabel", true, false) as Label).text.contains(TrainerProfile.trainer_name()))
	# つなぐ前は、つなぐ所だけを出す。
	assert_true((lobby.find_child("ConnectBox", true, false) as Control).visible)
	assert_false((lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_false((lobby.find_child("PaddockScreen", true, false) as Control).visible)
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
	# 入るとまず、待機室。上に部屋の名前、席の1つ目に自分（主の印）。右にルームチャット。
	assert_true((lobby.find_child("WaitingRoom", true, false) as Control).visible)
	assert_false((lobby.find_child("PaddockScreen", true, false) as Control).visible)
	assert_false((lobby.find_child("LobbyBox", true, false) as Control).visible)
	# 上の見出し：部屋の名前と、流れの道しるべ（いまは「待機室」）。
	assert_eq((lobby.find_child("RoomTitle", true, false) as Label).text, "テスト部屋")
	assert_eq(str((lobby.find_child("Step1", true, false) as Control).get_meta("state")), "now")
	assert_eq(str((lobby.find_child("Step3", true, false) as Control).get_meta("state")), "next")
	var seat := lobby.find_child("Seat1", true, false) as Button
	assert_true((seat.find_child("SeatName", true, false) as Label).text.contains(TrainerProfile.trainer_name()))
	assert_true((seat.find_child("SeatName", true, false) as Label).text.contains("主"))
	assert_eq(((lobby.find_child("Seat2", true, false) as Button).find_child("SeatName", true, false) as Label).text, "空き")
	assert_eq((lobby.find_child("RoomChatTitle", true, false) as Label).text, "ルームチャット")
	# 主は、レース開始を押せる。準備OKは要らない。
	assert_false((lobby.find_child("RaceOpenButton", true, false) as Button).disabled)
	assert_true((lobby.find_child("ReadyButton", true, false) as Button).disabled)
	await _to_pick(lobby)
	assert_true((lobby.find_child("PickScreen", true, false) as Control).visible)
	# プル選択：自分の席が1つ目（名前と、部屋の主の印）。いつものプル（一覧の1体目）が入っていて、変えられる旨が出る。
	var first: Dictionary = lobby.get("_pick_rows")[0]
	assert_eq(str(first["kind"]), "self")
	assert_true((first["who"] as Label).text.contains(TrainerProfile.trainer_name()))
	assert_true((first["who"] as Label).text.contains("主"))
	assert_true((first["note"] as Control).visible)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == str(RaceSession.roster_ids()[0]))
	assert_eq(lobby.my_pururin_id(), str(RaceSession.roster_ids()[0]))
	# 2つ目からは、CPU（レース設定で、はじめは全部CPU）。まだ「おまかせ」。右に、ルームチャット。
	var second: Dictionary = lobby.get("_pick_rows")[1]
	assert_eq((second["who"] as Label).text, "CPU")
	assert_eq((second["pururin"] as Label).text, "おまかせ")
	assert_eq((lobby.find_child("PickChatTitle", true, false) as Label).text, "ルームチャット")
	assert_true((lobby.find_child("RoomTitle", true, false) as Label).text.contains("テスト部屋"))
	assert_true(lobby.is_host())
	# プル選択の B（戻る）は、部屋を出ずに、待機室へ戻る。
	assert_false((lobby.find_child("BackButton", true, false) as Button).is_visible_in_tree())
	lobby.go_back()
	await _wait_until(func() -> bool: return (lobby.find_child("WaitingRoom", true, false) as Control).is_visible_in_tree())
	assert_true(OnlineSession.in_room())
	# 待機室の B（部屋を出る）は、すぐには出ない。「部屋を出ますか」の窓が出て、カーソルは「やめる」。B で窓だけ閉じる。
	lobby.go_back()
	var leave := lobby.find_child("LeaveDialog", true, false) as Control
	assert_true(leave.visible)
	assert_eq(_focused_name(), "LeaveConfirmCancelButton")
	lobby.go_back()
	assert_false(leave.visible)
	assert_true(OnlineSession.in_room())
	# 窓の「部屋を出る」で、一覧へ戻る（つながりは切らない）。誰もいなくなった部屋は、消える。
	lobby.go_back()
	(lobby.find_child("LeaveConfirmButton", true, false) as Button).pressed.emit()
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
	# 押しても、すぐには入らない。入室の窓が出て、部屋の名前・主の名前・人数・紹介が見える。
	var dialog := lobby.find_child("JoinDialog", true, false) as Control
	assert_false(dialog.visible)
	row.pressed.emit()
	await _wait_until(func() -> bool: return dialog.visible)
	assert_true(dialog.visible)
	assert_eq((dialog.find_child("JoinRoomName", true, false) as Label).text, "朝の部屋")
	assert_true((dialog.find_child("JoinHostName", true, false) as Label).text.contains("ミナト"))
	assert_true((dialog.find_child("JoinCount", true, false) as Label).text.contains("1／"))
	assert_true((dialog.find_child("JoinLock", true, false) as Control).visible)
	assert_true((dialog.find_child("JoinPasswordRow", true, false) as Control).visible)
	assert_eq(_server.room_members(room_id).size(), 1)
	# 違うパスワードでは、入れない。わけが出る。
	(lobby.find_child("JoinPasswordEdit", true, false) as LineEdit).text = "ちがう"
	lobby.join_with_password()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return _status(lobby).contains("パスワード"))
	assert_true(_status(lobby).contains("パスワード"))
	# 「やめる」（戻る）は、窓だけを閉じる。
	await _open_join_dialog(lobby, room_id)
	lobby.go_back()
	assert_false(dialog.visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	await _enter_listed_room(lobby, room_id, "ひみつ")
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	assert_eq(int(OnlineSession.all_members()[1]["peer_id"]), OnlineSession.peer_id)
	assert_false(lobby.is_host())
	assert_eq(_server.room_members(room_id).size(), 2)


func test_the_join_dialog_shows_the_description_and_the_host_changes_it() -> void:
	var owner := await _other("ミナト")
	owner.create_room("昼の部屋", "", "のんびり走ります")
	var lobby := await _connected_lobby()
	var room_id := _first_room_id()
	await _wait_until(func() -> bool: return lobby.find_child("Room%d" % room_id, true, false) != null)
	# 一覧の部屋にカーソルを合わせると、紹介文が吹き出しで出る。
	var row := lobby.find_child("Room%d" % room_id, true, false) as Button
	row.grab_focus()
	await wait_process_frames(2)
	var popup := lobby.find_child("HoverPopup", true, false) as Control
	assert_true(popup.visible)
	assert_eq((popup.get_child(0) as Label).text, "のんびり走ります")
	var dialog := await _open_join_dialog(lobby, room_id)
	assert_eq((dialog.find_child("JoinDescription", true, false) as Label).text, "のんびり走ります")
	# 施錠のない部屋は、パスワードの欄も、施錠の印も出ない。
	assert_false((dialog.find_child("JoinPasswordRow", true, false) as Control).visible)
	assert_false((dialog.find_child("JoinLock", true, false) as Control).visible)
	assert_eq(lobby.start_button(), dialog.find_child("JoinButton", true, false))
	lobby.join_with_password()
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	# 主が、部屋の中で紹介を書き換えると、次に押した人に、新しい紹介が見える。
	owner.send(Protocol.SETTINGS, {"description": "初心者歓迎"})
	await _wait_until(func() -> bool: return str(lobby.get("_room").get("description", "")) == "初心者歓迎")
	assert_eq(str(lobby.get("_room").get("description", "")), "初心者歓迎")


func test_choosing_your_own_server_enables_the_field_and_is_remembered() -> void:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	await wait_process_frames(2)
	var edit := lobby.find_child("ServerEdit", true, false) as LineEdit
	var custom := lobby.find_child("CustomServerRadio", true, false) as CheckBox
	var connect := lobby.find_child("ConnectButton", true, false) as Button
	# 標準のあいだは、入力欄にフォーカスが行かない。
	assert_ne(custom.focus_neighbor_bottom, custom.get_path_to(edit))
	custom.button_pressed = true
	assert_true(edit.editable)
	assert_eq(custom.focus_neighbor_bottom, custom.get_path_to(edit))
	edit.text = "wss://example.test"
	assert_eq(lobby.selected_server_url(), "wss://example.test")
	lobby.connect_to_server()
	assert_eq(ServerChoice.choice(), ServerChoice.CHOICE_CUSTOM)
	assert_eq(ServerChoice.custom_url(), "wss://example.test")
	OnlineSession.close()
	# 開き直しても、選びと入力したURLが残っている。
	var again: Control = LobbyScene.instantiate()
	add_child_autofree(again)
	assert_true((again.find_child("CustomServerRadio", true, false) as CheckBox).button_pressed)
	assert_eq((again.find_child("ServerEdit", true, false) as LineEdit).text, "wss://example.test")
	assert_eq(again.selected_server_url(), "wss://example.test")
	# 標準に戻すと、標準のURLでつなぐ。入力した文字は残す。
	(again.find_child("DefaultServerRadio", true, false) as CheckBox).button_pressed = true
	assert_eq(again.selected_server_url(), OnlineConfig.server_url())
	assert_eq(ServerChoice.choice(), ServerChoice.CHOICE_DEFAULT)
	assert_eq(ServerChoice.custom_url(), "wss://example.test")
	assert_not_null(connect)


func test_this_pc_can_be_the_server_and_the_player_at_once() -> void:
	var LocalServer = load("res://scripts/online/local_server.gd")
	var lobby := _lobby()
	await wait_seconds(0.1)
	# つなぐ画面の下に「このPCをサーバーにする」の欄がある（ブラウザ版では出さない）。
	var card := lobby.find_child("LocalServerCard", true, false) as Control
	assert_eq(card.visible, not OS.has_feature("web"))
	assert_eq((lobby.find_child("LocalServerButton", true, false) as Button).text, "このPCでサーバーを始めて、つなぐ")
	assert_true((lobby.find_child("LocalServerAddress", true, false) as Label).text.begins_with("ほかの人がつなぐ場所："))
	# 同じアプリを、画面なしで、サーバーとして起動する指定。自分は 127.0.0.1 につなぐ。
	var arguments: PackedStringArray = LocalServer.start_arguments()
	assert_true(arguments.has("--headless"))
	assert_eq(arguments[arguments.size() - 1], LocalServer.SERVER_FLAG)
	assert_eq(LocalServer.local_url(), "ws://127.0.0.1:%d" % Protocol.server_port())
	assert_false(LocalServer.requested())
	for address: String in ["192.168.1.5", "10.0.0.2", "172.20.3.4"]:
		assert_true(LocalServer.is_private_address(address), address)
	for address: String in ["127.0.0.1", "8.8.8.8", "172.32.0.1", "fe80::1"]:
		assert_false(LocalServer.is_private_address(address), address)


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
	var room_id := _first_room_id()
	# 待機室で、パスワードを窓で確かめて、変える。最初は「なし」。
	var change_dialog := lobby.find_child("PasswordChangeDialog", true, false) as Control
	(lobby.find_child("WaitingPasswordButton", true, false) as Button).pressed.emit()
	assert_true(change_dialog.visible)
	assert_true((lobby.find_child("CurrentPassword", true, false) as Label).text.contains("なし"))
	(lobby.find_child("PasswordEdit", true, false) as LineEdit).text = "かぎ"
	lobby.change_password()
	assert_false(change_dialog.visible)
	await _wait_until(func() -> bool: return bool(_server.call("_room_fields", room_id)["locked"]))
	await _wait_until(func() -> bool: return (lobby.find_child("RoomLock", true, false) as Control).visible)
	assert_true((lobby.find_child("RoomLock", true, false) as Control).visible)
	lobby.open_password_change_dialog()
	assert_true((lobby.find_child("CurrentPassword", true, false) as Label).text.contains("かぎ"))
	lobby.close_dialogs()
	# レース開始で、レース設定へ。距離のボタンを押すと、サーバーの部屋の距離が変わり、そのボタンが選ばれた見た目になる。
	lobby.open_race()
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	var distances: Array = RaceSession.supported_distances_m()
	var default_button := lobby.find_child("Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), true, false) as Button
	assert_true(default_button.button_pressed)
	var wanted := float(distances[posmod(distances.find(RaceSession.DEFAULT_DISTANCE_M) + 1, distances.size())])
	var wanted_button := lobby.find_child("Distance%d" % int(wanted), true, false) as Button
	wanted_button.pressed.emit()
	await _wait_until(func() -> bool: return is_equal_approx(float(_server.call("_room_fields", room_id)["distance_m"]), wanted))
	await _wait_until(func() -> bool: return wanted_button.button_pressed and not default_button.button_pressed)
	assert_true(wanted_button.button_pressed)
	assert_false(default_button.button_pressed)
	# 席：2つ目の席（人の足りない最初の席）を押すと、「CPU」と「入れない」が切り替わる。
	var seat := lobby.find_child("SettingsSeat2", true, false) as Button
	var seat_name := seat.find_child("SeatName", true, false) as Label
	assert_eq(seat_name.text, "CPU")
	seat.pressed.emit()
	await _wait_until(func() -> bool: return int(_server.call("_room_fields", room_id)["field_size"]) == Protocol.ROOM_CAPACITY - 1)
	await _wait_until(func() -> bool: return seat_name.text == "入れない")
	assert_eq(seat_name.text, "入れない")
	# 人の席は、待機室と同じ、絵と名前。右には、待機室と同じルームチャット。
	assert_true(((lobby.find_child("SettingsSeat1", true, false) as Button).find_child("SeatName", true, false) as Label).text.contains(TrainerProfile.trainer_name()))
	assert_eq((lobby.find_child("SettingsChatTitle", true, false) as Label).text, "ルームチャット")
	assert_true((lobby.find_child("RaceSettingsCount", true, false) as Label).text.contains(str(Protocol.ROOM_CAPACITY - 1)))
	lobby.open_pick()
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	await wait_seconds(0.1)
	var confirm := lobby.find_child("PickConfirmButton", true, false) as Button
	var paddock := lobby.find_child("PickPaddockButton", true, false) as Button
	assert_true((lobby.find_child("PickInfo", true, false) as Label).text.contains("%d体" % (Protocol.ROOM_CAPACITY - 1)))
	# 入ると、いつものプルが入っている。自分の席を押すと、ステータスの窓（変更・もどる）。「変更」で、プル選択の窓。
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	var dialog := lobby.find_child("PickDialog", true, false) as Control
	lobby.open_pick_dialog(_my_pick_row(lobby))
	assert_true(dialog.visible)
	assert_true((lobby.find_child("PickChangeButton", true, false) as Button).visible)
	(lobby.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	assert_false(dialog.visible)
	assert_true(lobby.is_picker_open())
	# 選ばずに閉じても（B・Esc）、カーソルは自分の席へ戻る（ゲームパッドで動けなくならない）。
	lobby.go_back()
	assert_false(lobby.is_picker_open())
	var my_row_button := lobby.get("_pick_rows")[_my_pick_row(lobby)]["button"] as Button
	await _wait_until(func() -> bool: return my_row_button.has_focus())
	assert_true(my_row_button.has_focus())
	lobby.open_pick_dialog(_my_pick_row(lobby))
	(lobby.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	assert_true(lobby.is_picker_open())
	var second_id := str(PururinRosterConfig.values()["roster"][1]["id"])
	# 窓でプルを押すと、すぐには決まらない。そのプルのステータスが出て、「このプルにする」で決まる。「もどる」なら、窓へ戻る。
	lobby.call("_on_picker_picked", second_id)
	assert_true(dialog.visible)
	assert_eq((lobby.find_child("PickChangeButton", true, false) as Button).text, "このプルにする")
	assert_eq(str(lobby.get("_pick_dialog_detail").call("shown_pururin_id")), second_id)
	(lobby.find_child("PickDialogBackButton", true, false) as Button).pressed.emit()
	assert_false(dialog.visible)
	assert_true(lobby.is_picker_open())
	# B（戻る）も、「もどる」と同じ。プル一覧へ戻る（全部を閉じない）。
	lobby.call("_on_picker_picked", second_id)
	lobby.go_back()
	assert_false(dialog.visible)
	assert_true(lobby.is_picker_open())
	lobby.call("_on_picker_picked", second_id)
	(lobby.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == second_id)
	assert_eq(str((lobby.get("_pick_rows")[_my_pick_row(lobby)]["pururin"] as Label).text), lobby.pururin_name(second_id))
	# パドックへは、全員が確定してから（ここでは自分だけ）。
	assert_true(paddock.disabled)
	confirm.pressed.emit()
	await _wait_until(func() -> bool: return not paddock.disabled)
	assert_eq(confirm.text, "確定を取り消す")
	paddock.pressed.emit()
	await _wait_until(func() -> bool: return OnlineSession.in_entries())
	# 知らせを出しているあいだ（2秒ほど）は、前の画面のまま。パドックの画面が出るまで待つ。
	await _wait_until(func() -> bool: return (lobby.find_child("PaddockScreen", true, false) as Control).visible)
	await _wait_until(func() -> bool: return str((lobby.find_child("Step4", true, false) as Control).get_meta("state", "")) == "now")
	assert_eq(str((lobby.find_child("Step3", true, false) as Control).get_meta("state")), "done")


func test_a_guest_cannot_change_the_room_and_may_pick_the_same_pururin() -> void:
	var owner := await _other("主")
	owner.create_room("客の部屋")
	var first_id := str(PururinRosterConfig.values()["roster"][0]["id"])
	await wait_seconds(0.2)
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	# 2人目は、主ではない。待機室で、レース開始は押せず、紹介・パスワードの変更ボタンも出ない。
	assert_false(lobby.is_host())
	assert_true((lobby.find_child("RaceOpenButton", true, false) as Button).disabled)
	assert_false((lobby.find_child("WaitingPasswordButton", true, false) as Button).visible)
	assert_false(((lobby.find_child("Seat1", true, false) as Button).find_child("SeatMenu", true, false) as Button).visible)
	# パスワードそのものは、主にしか届かない。
	assert_false(OnlineSession.room.has("password"))
	# 準備OKを押してから、主がレース開始。レース設定では、距離も席も、見るだけ。
	lobby.toggle_lobby_ready()
	await _wait_until(func() -> bool: return OnlineSession.my_lobby_ready())
	owner.send(Protocol.RACE_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	assert_true((lobby.find_child("Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), true, false) as Button).disabled)
	assert_eq((lobby.find_child("SettingsSeat3", true, false) as Button).focus_mode, Control.FOCUS_NONE)
	# 主でない人にも「待機室へ戻る」と「次へ」はある。「次へ」は押せない。
	assert_true((lobby.find_child("SettingsNextButton", true, false) as Button).visible)
	assert_true((lobby.find_child("SettingsNextButton", true, false) as Button).disabled)
	assert_eq((lobby.find_child("SettingsBackButton", true, false) as Button).text, "待機室へ戻る")
	owner.send(Protocol.PICK_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	owner.send(Protocol.PICK, {"pururin_id": first_id})
	# 主と同じプル（いつものプル）でも選べる。主の席は、見るだけ（窓に「変更」が出ない）。パドックへは押せない。
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == first_id)
	assert_eq(lobby.my_pururin_id(), first_id)
	lobby.open_pick_dialog(0)
	assert_false((lobby.find_child("PickChangeButton", true, false) as Button).visible)
	lobby.close_dialogs()
	assert_true((lobby.find_child("PickPaddockButton", true, false) as Button).disabled)


func test_the_host_puts_a_guest_out_and_the_guest_is_told_why() -> void:
	var lobby := await _lobby_in_new_room("出す部屋")
	var room_id := _first_room_id()
	var guest := await _other("客")
	var heard := []
	guest.message_received.connect(func(data: Dictionary) -> void: heard.append(str(data["t"])))
	guest.join_room(room_id)
	var menu_of := func(seat: int) -> Button: return (lobby.find_child("Seat%d" % seat, true, false) as Button).find_child("SeatMenu", true, false) as Button
	await _wait_until(func() -> bool: return (menu_of.call(2) as Button).visible)
	# 主の画面には、ほかの人の席にだけ「︙」がある（自分の席・空き席には無い）。
	assert_false((menu_of.call(1) as Button).visible)
	assert_false((menu_of.call(3) as Button).visible)
	# 押すと、確かめる窓が出るだけ。「やめる」なら、何も起きない。
	var dialog := lobby.find_child("KickDialog", true, false) as Control
	(menu_of.call(2) as Button).pressed.emit()
	assert_true(dialog.visible)
	assert_true((dialog.find_child("Title", true, false) as Label).text.contains("客"))
	lobby.close_dialogs()
	await wait_seconds(0.3)
	assert_false(heard.has(Protocol.KICKED))
	assert_eq(_server.room_members(room_id).size(), 2)
	# 窓の「退出させる」で、はじめて退出になる。
	(menu_of.call(2) as Button).pressed.emit()
	lobby.confirm_kick()
	assert_false(dialog.visible)
	await _wait_until(func() -> bool: return heard.has(Protocol.KICKED))
	assert_true(heard.has(Protocol.KICKED))
	assert_eq(_server.room_members(room_id).size(), 1)


func test_the_waiting_room_shows_seats_ready_marks_and_introductions() -> void:
	var lobby := await _lobby_in_new_room("待つ部屋")
	var guest := await _other("客")
	guest.hello("客", "よろしくお願いします。")
	await wait_seconds(0.2)
	guest.join_room(_first_room_id())
	var seat := lobby.find_child("Seat2", true, false) as Button
	await _wait_until(func() -> bool: return (seat.find_child("SeatName", true, false) as Label).text == "客")
	var mark := seat.find_child("SeatReady", true, false) as Control
	assert_false(mark.visible)
	# 準備OKを押すと、その席に印が出る。
	guest.set_lobby_ready(true)
	await _wait_until(func() -> bool: return mark.visible)
	assert_true(mark.visible)
	# 席にカーソルを合わせると、その人の紹介文が小さく出る。
	seat.grab_focus()
	await wait_process_frames(2)
	var popup := lobby.find_child("HoverPopup", true, false) as Control
	assert_true(popup.visible)
	assert_eq((popup.get_child(0) as Label).text, "よろしくお願いします。")
	# ルームチャット：送ると、待機室の右の欄に出る。
	(lobby.find_child("RoomChatEdit", true, false) as LineEdit).text = "はじめまして"
	(lobby.find_child("RoomChatSendButton", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return (lobby.find_child("RoomChatLog", true, false) as RichTextLabel).get_parsed_text().contains("はじめまして"))
	assert_true((lobby.find_child("RoomChatLog", true, false) as RichTextLabel).get_parsed_text().contains("はじめまして"))
	# 主がレース開始を押すと、2秒ほど知らせが出て、準備OKの人と主がレース設定へ進む。
	lobby.open_race()
	await _wait_until(func() -> bool: return lobby.is_race_open_popup_visible())
	assert_eq((lobby.find_child("RaceOpenText", true, false) as Label).text, "部屋主が「レース設定へ」を押したので、レース設定に進みます。")
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	await _wait_until(func() -> bool: return not lobby.is_race_open_popup_visible(), 4.0)
	assert_false(lobby.is_race_open_popup_visible())


func test_a_person_who_is_not_ready_stays_in_the_waiting_room() -> void:
	var owner := await _other("主")
	owner.create_room("残る部屋")
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	owner.send(Protocol.RACE_OPEN)
	await _wait_until(func() -> bool: return lobby.is_race_open_popup_visible())
	assert_true((lobby.find_child("RaceOpenText", true, false) as Label).text.contains("待機室で次のレースを待ちます"))
	await wait_seconds(0.2)
	# 準備OKでなかったので、待機室のまま。状態は「レース中」。
	assert_true((lobby.find_child("WaitingRoom", true, false) as Control).visible)
	assert_false((lobby.find_child("RaceSettings", true, false) as Control).visible)
	# 席の下に「現在レース中」の帯。進んだ人の席には「出走中」。
	await _wait_until(func() -> bool: return (lobby.find_child("WaitingRaceBand", true, false) as Control).visible)
	assert_true((lobby.find_child("WaitingRaceText", true, false) as Label).text.begins_with("現在レース中：主（1人）"))
	assert_eq(((lobby.find_child("Seat1", true, false) as Button).find_child("SeatReady", true, false) as Label).text, "出走中")


func test_being_put_out_returns_the_screen_to_the_room_list_with_the_reason() -> void:
	var owner := await _other("主")
	owner.create_room("出される部屋")
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	owner.send(Protocol.KICK, {"peer_id": OnlineSession.peer_id})
	await _wait_until(func() -> bool: return (lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true((lobby.find_child("LobbyBox", true, false) as Control).visible)
	assert_true(_status(lobby).contains("退出"))


func test_the_paddock_shows_gates_details_and_only_the_host_reorders() -> void:
	var lobby := await _lobby_in_new_room("パドックの部屋")
	var room_id := _first_room_id()
	var guest := await _other("客")
	# 客は、自己紹介と、自分で入れた画像（小さなJPEG）を名乗っている。
	var picture := Image.create(8, 8, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.9, 0.3, 0.2))
	guest.hello("客", "レースが好きです。", {"kind": "file", "id": "", "image": Marshalls.raw_to_base64(picture.save_jpg_to_buffer(0.9))})
	await wait_seconds(0.2)
	guest.join_room(room_id)
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	guest.set_lobby_ready(true)
	await _wait_until(func() -> bool: return bool(OnlineSession.all_members()[1].get("ready", false)))
	await _to_pick(lobby)
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	guest.send(Protocol.PICK, {"pururin_id": ids[3]})
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	guest.send(Protocol.CONFIRM, {"on": true})
	lobby.toggle_pick_confirm()
	await _wait_until(func() -> bool: return not (lobby.find_child("PickPaddockButton", true, false) as Button).disabled)
	lobby.open_paddock()
	await _wait_until(func() -> bool: return (lobby.find_child("PaddockScreen", true, false) as Control).visible)
	await wait_seconds(0.2)
	# パドック：大きな枠が、枠順に全出走（人とCPU）。右にルームチャット。
	var entries: Array = OnlineSession.room["entries"]
	assert_eq(entries.size(), Protocol.ROOM_CAPACITY)
	var rows: Array = lobby.get("_paddock_rows")
	for index in entries.size():
		assert_eq((rows[index]["pururin"] as Label).text, lobby.pururin_name(str(entries[index]["id"])))
	assert_eq((lobby.find_child("PaddockChatTitle", true, false) as Label).text, "ルームチャット")
	# 枠を押すと、人（CPUはトレーナー）とプルの、両方の詳細。
	for index in entries.size():
		var entry: Dictionary = entries[index]
		lobby.open_paddock_dialog(index)
		var detail: Control = lobby.get("_paddock_dialog_detail")
		assert_eq(str(detail.call("shown_pururin_id")), str(entry["id"]))
		var name_label := lobby.find_child("PaddockPersonName", true, false) as Label
		if int(entry["peer_id"]) == 0:
			assert_eq(name_label.text, str(entry["trainer_name"]))
			assert_true((lobby.find_child("PaddockPersonNote", true, false) as Label).text.contains("CPUトレーナー"))
		elif str(entry.get("trainer_name", "")) == "客":
			await _wait_until(func() -> bool: return OnlineSession.profiles.size() >= 2)
			lobby.open_paddock_dialog(index)
			assert_eq(name_label.text, "客")
			assert_true((lobby.find_child("PaddockPersonIntro", true, false) as Label).text.contains("レースが好き"))
		lobby.close_dialogs()
	# 枠順：主は、選んだ枠を下へ（R1）。カーソルは、動かした先に付いていく。
	var first_id := str(entries[0]["id"])
	var second_id := str(entries[1]["id"])
	(rows[0]["button"] as Button).grab_focus()
	lobby.move_selected_gate(1)
	await _wait_until(func() -> bool: return str(OnlineSession.room["entries"][1]["id"]) == first_id)
	assert_eq([str(OnlineSession.room["entries"][0]["id"]), str(OnlineSession.room["entries"][1]["id"])], [second_id, first_id])
	assert_eq(int(lobby.get("_selected_gate")), 1)
	# ランダム・上へ・下へは、主だけ押せる。プルの選び直しのボタンは無い。
	assert_false((lobby.find_child("PaddockShuffleButton", true, false) as Button).disabled)
	assert_null(lobby.find_child("BackToRoomButton", true, false))
	# 全員が確定すると、主は「レース開始」を押せる。
	var start := lobby.find_child("PaddockStartButton", true, false) as Button
	assert_true(start.disabled)
	guest.send(Protocol.CONFIRM, {"on": true})
	lobby.toggle_pick_confirm()
	await _wait_until(func() -> bool: return not start.disabled)
	assert_false(start.disabled)


func _focused_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return str(focused.name) if focused != null else ""


## 上下左右・決定の操作を、キーボードやゲームパッドの代わりに送る。
func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_seconds(0.05)


func test_the_room_can_be_worked_without_a_mouse() -> void:
	var lobby := await _lobby_in_new_room("キーの部屋")
	var room_id := _first_room_id()
	var distances: Array = RaceSession.supported_distances_m()
	var default_index := distances.find(RaceSession.DEFAULT_DISTANCE_M)
	lobby.open_race()
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	# 両端に、オフラインと同じ「‹ L1」「R1 ›」がある。
	assert_not_null(lobby.find_child("DistancePrev", true, false))
	assert_not_null(lobby.find_child("DistanceNext", true, false))
	# 今の距離のボタンから「右」で、となりの距離へ移り、そのまま、その距離になる。
	(lobby.find_child("Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), true, false) as Control).grab_focus()
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
	# 「下」で、席の1つ目（自分）へ。「右」で、人の足りない席（2つ目）へ。
	await wait_seconds(0.2)
	await _press("ui_down")
	assert_eq(_focused_name(), "SettingsSeat1")
	await _press("ui_right")
	assert_eq(_focused_name(), "SettingsSeat2")
	lobby.open_pick()
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	await wait_seconds(0.2)
	# プル選択：自分の席から「下」で、CPUの席へ。決定で、ステータスの窓。いちばん下の席の「下」は、下のボタン。
	(lobby.find_child("PickRow1", true, false) as Control).grab_focus()
	await _press("ui_down")
	assert_eq(_focused_name(), "PickRow2")
	await _press("ui_up")
	await _press("ui_accept")
	assert_true((lobby.find_child("PickDialog", true, false) as Control).visible)
	lobby.close_dialogs()
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	(lobby.find_child("PickRow%d" % Protocol.ROOM_CAPACITY, true, false) as Control).grab_focus()
	await _press("ui_down")
	assert_eq(_focused_name(), "PickBackButton")
	await _press("ui_right")
	assert_eq(_focused_name(), "PickConfirmButton")


func test_a_guest_cannot_move_the_distance() -> void:
	var owner := await _other("主")
	owner.create_room("客の距離")
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	lobby.toggle_lobby_ready()
	await _wait_until(func() -> bool: return OnlineSession.my_lobby_ready())
	owner.send(Protocol.RACE_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	# 主でない人は、距離の段にカーソルを置けない。L1・R1 も効かない。
	assert_eq((lobby.find_child("Distance%d" % int(RaceSession.DEFAULT_DISTANCE_M), true, false) as Control).focus_mode, Control.FOCUS_NONE)
	lobby.step_distance(1)
	await wait_seconds(0.3)
	assert_almost_eq(float(_server.call("_room_fields", _first_room_id())["distance_m"]), RaceSession.DEFAULT_DISTANCE_M, 0.001)
	assert_true((lobby.find_child("DistanceNext", true, false) as Button).disabled)
	owner.send(Protocol.PICK_OPEN)
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	assert_false((lobby.find_child("DistanceNext", true, false) as Control).is_visible_in_tree(), "プル選択には、距離の段は無い")


func test_the_host_picks_cpu_pururins_and_cannot_change_trainers() -> void:
	var lobby := await _lobby_in_new_room("CPUの部屋")
	var room_id := _first_room_id()
	await _to_pick(lobby)
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	# CPUの席（2つ目）を押すと、ステータスの窓。主には「変更」がある。自分と同じプルでも選べる。
	lobby.open_pick_dialog(1)
	assert_true((lobby.find_child("PickChangeButton", true, false) as Button).visible)
	lobby.open_pick_picker()
	assert_true(lobby.is_picker_open())
	lobby.call("_on_picker_picked", ids[0])
	(lobby.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return str(_server.room_cpus(room_id)[0]["pururin_id"]) == ids[0])
	assert_eq(str(_server.room_cpus(room_id)[0]["pururin_id"]), ids[0])
	# トレーナーは、そのプルのデフォルト（変える所は無い）。
	var row: Dictionary = lobby.get("_pick_rows")[1]
	await _wait_until(func() -> bool: return (row["who"] as Label).text.begins_with("CPU "))
	var trainer: Dictionary = load("res://scripts/config/cpu_trainers_config.gd").by_id(str(PururinRosterConfig.pururin_by_id(ids[0])["trainer_id"]))
	assert_eq((row["who"] as Label).text, "CPU %s" % str(trainer["name"]))
	assert_null(lobby.find_child("ProfileTrainerButton", true, false))


func test_a_guest_cannot_pick_cpu_pururins() -> void:
	var owner := await _other("主")
	owner.create_room("客とCPU")
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	await _guest_to_pick(lobby, owner)
	# CPUの席を押しても、ステータスを見るだけ（「変更」は無い）。
	lobby.open_pick_dialog(2)
	assert_true((lobby.find_child("PickDialog", true, false) as Control).visible)
	assert_false((lobby.find_child("PickChangeButton", true, false) as Button).visible)


func test_room_events_show_as_a_notice_and_in_the_chat() -> void:
	var owner := await _other("主")
	owner.create_room("知らせの部屋")
	var lobby := await _connected_lobby()
	await _enter_listed_room(lobby, _first_room_id())
	await _wait_until(func() -> bool: return (lobby.get("_members") as Array).size() >= 2)
	var chat := lobby.find_child("RoomChatLog", true, false) as RichTextLabel
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
	var edit := lobby.find_child("RoomChatEdit", true, false) as LineEdit
	edit.text = "こちらこそ"
	lobby.send_chat(edit)
	await _wait_until(func() -> bool: return OnlineSession.chat_log.size() >= 2)
	var shown := (lobby.find_child("RoomChatLog", true, false) as RichTextLabel).get_parsed_text()
	assert_true(shown.contains("客"))
	assert_true(shown.contains("よろしく"))
	assert_true(shown.contains("こちらこそ"))
	assert_eq(edit.text, "", "送ったら、入力らんは空になる")


func test_the_race_screen_uses_the_quality_chosen_in_the_options() -> void:
	var course_only_before := RaceSession.is_course_only()
	RaceSession.set_course_only(not OS.has_feature("web"))
	var lobby := await _lobby_in_new_room("景色の部屋")
	# オプション設定で選んだ画質を、レースの画面にも使う。
	assert_eq(lobby.is_light_scenery(), not OS.has_feature("web"))
	lobby.prepare_race({"distance_m": RaceSession.supported_distances_m()[0], "entries": [{"gate": 0, "id": "x", "player": true, "peer_id": 1}]})
	assert_eq(RaceSession.is_course_only(), lobby.is_light_scenery())
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	RaceSession.set_course_only(course_only_before)


func test_start_targets_the_visible_next_step_and_never_cancels_confirmation() -> void:
	var lobby := await _connected_lobby()
	var create: Button = lobby.find_child("OpenCreateButton", true, false)
	create.grab_focus()
	assert_null(lobby.start_button(), "一覧では、STARTで先へ進むものはない")
	lobby.open_create_dialog()
	var confirm_create: Button = lobby.find_child("CreateButton", true, false)
	assert_eq(lobby.start_button(), confirm_create)
	assert_eq(confirm_create.get_node("ButtonMark").get("kind"), "START")
	(lobby.find_child("RoomNameEdit", true, false) as LineEdit).text = "START確認"
	_press_pad(JOY_BUTTON_START)
	await _wait_until(func() -> bool: return OnlineSession.in_room())
	assert_true(OnlineSession.in_room())
	# 待機室では、主のSTARTは「レース開始」。レース設定では「次へ」。
	await _wait_until(func() -> bool: return (lobby.find_child("WaitingRoom", true, false) as Control).visible)
	assert_eq(lobby.start_button(), lobby.find_child("RaceOpenButton", true, false))
	lobby.open_race()
	await _wait_until(func() -> bool: return (lobby.find_child("RaceSettings", true, false) as Control).visible)
	assert_eq(lobby.start_button(), lobby.find_child("SettingsNextButton", true, false))
	lobby.open_pick()
	await _wait_until(func() -> bool: return (lobby.find_child("PickScreen", true, false) as Control).visible)
	await _wait_until(func() -> bool: return not lobby.my_pururin_id().is_empty())
	# プル選択では、まず「確定」。全員がそろうと、主は「パドックへ」。
	var confirm: Button = lobby.find_child("PickConfirmButton", true, false)
	assert_eq(lobby.start_button(), confirm)
	confirm.pressed.emit()
	await _wait_until(func() -> bool: return not (lobby.find_child("PickPaddockButton", true, false) as Button).disabled)
	assert_eq(lobby.start_button(), lobby.find_child("PickPaddockButton", true, false))
	(lobby.find_child("PickChatEdit", true, false) as LineEdit).grab_focus()
	assert_null(lobby.start_button(), "チャット入力中は先へ進まない")
