extends GutTest
## オンラインフリー対戦：共通のロビー、☑（希望の順）、長く待っている順に呼ぶ、確かめの返事、CPUで埋めて始める、レースのあと。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")

## テスト用の入口の番号（ほかのテストとも、本番とも別にする）。
const TEST_PORT := Protocol.DEFAULT_PORT + 1200
const WAIT_S := 4.0
## テストでは、待つ秒数を短くする。
const FILL_WAIT_S := 0.6
const ANSWER_WAIT_S := 0.4

var _server: Node
var _inbox := {}
var _clients := {}
## レースを作ると、サーバーが景色の軽さを切り替えるので、テストのあとで戻す。
var _course_only_before := false


func before_each() -> void:
	_course_only_before = RaceSession.is_course_only()
	_inbox = {}
	_clients = {}
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	_server.fill_wait_s = FILL_WAIT_S
	_server.answer_wait_s = ANSWER_WAIT_S
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


func _free_ids() -> Array:
	var ids: Array = []
	for room: Dictionary in OnlineConfig.free_rooms():
		ids.append(str(room["id"]))
	return ids


func _first_pururin() -> String:
	return str(PururinRosterConfig.values()["roster"][0]["id"])


## つないで、名乗って、フリー対戦のロビーに入る。届いた free_lobby を返す。
func _enter_free(label: String) -> Dictionary:
	var client: Node = OnlineClient.new()
	add_child_autofree(client)
	_inbox[label] = []
	_clients[label] = client
	client.message_received.connect(func(data: Dictionary) -> void: (_inbox[label] as Array).append(data))
	assert_eq(client.connect_to("ws://127.0.0.1:%d" % TEST_PORT), OK)
	await wait_for_signal(client.connected, WAIT_S)
	client.hello(label)
	await _wait_for(label, Protocol.LOBBY)
	client.send(Protocol.FREE_ENTER)
	return await _wait_for(label, Protocol.FREE_LOBBY)


## その人に、その種類の文が届くまで待って、届いた文を返す（届かなければ空）。古いものから順に取る。
func _wait_for(label: String, type: String, max_s: float = WAIT_S) -> Dictionary:
	var waited := 0.0
	while waited < max_s:
		for data: Dictionary in _inbox[label]:
			if str(data["t"]) == type:
				(_inbox[label] as Array).erase(data)
				return data
		await wait_seconds(0.05)
		waited += 0.05
	return {}


## いちばん新しい free_lobby（届くまで待つ）。それまでのものは捨てる。
func _latest_lobby(label: String) -> Dictionary:
	await wait_seconds(0.2)
	var latest := {}
	for data: Dictionary in (_inbox[label] as Array).duplicate():
		if str(data["t"]) == Protocol.FREE_LOBBY:
			latest = data
			(_inbox[label] as Array).erase(data)
	return latest if not latest.is_empty() else await _wait_for(label, Protocol.FREE_LOBBY)


func _room_line(lobby: Dictionary, free_id: String) -> Dictionary:
	for room: Dictionary in lobby["rooms"]:
		if str(room["room_id"]) == free_id:
			return room
	return {}


## ぷるりんを選んで、☑する。
func _pick_and_wish(label: String, wishes: Array) -> void:
	_clients[label].send(Protocol.FREE_PICK, {"pururin_id": _first_pururin()})
	_clients[label].send(Protocol.FREE_WISH, {"room_ids": wishes})


func test_the_free_lobby_lists_the_configured_rooms_and_friend_rooms_do_not_show_them() -> void:
	var lobby := await _enter_free("a")
	var ids: Array = []
	for room: Dictionary in lobby["rooms"]:
		ids.append(str(room["room_id"]))
		assert_eq(str(room["state"]), Protocol.FREE_STATE_IDLE)
	assert_eq(ids, _free_ids())
	assert_almost_eq(float(lobby["fill_wait_s"]), FILL_WAIT_S, 0.001)
	# ともだち対戦の部屋の一覧と、部屋の数には、入らない。
	assert_eq(_server.room_count(), 0)
	assert_eq(_server.room_list().size(), 0)


func test_wishing_needs_a_pururin_and_known_rooms() -> void:
	await _enter_free("a")
	_clients["a"].send(Protocol.FREE_WISH, {"room_ids": [_free_ids()[0]]})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_PICK)
	_clients["a"].send(Protocol.FREE_PICK, {"pururin_id": _first_pururin()})
	_clients["a"].send(Protocol.FREE_WISH, {"room_ids": ["no_such_room"]})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_BAD_MESSAGE)


func test_the_first_wish_is_called_first_and_the_offer_names_the_room_and_its_priority() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[1], ids[0]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	assert_eq(str(offer["room_id"]), ids[1])
	assert_eq(int(offer["priority"]), 1)
	assert_eq(str(offer["name"]), str(OnlineConfig.free_rooms()[1]["name"]))
	assert_almost_eq(float(offer["distance_m"]), float(OnlineConfig.free_rooms()[1]["distance_m"]), 0.001)


func test_those_who_waited_longer_stand_earlier_in_the_line() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	await _enter_free("b")
	# 呼ばれても返事をしないまま並んでいられるよう、待つ秒数を長くする。a が先に☑する。
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_pick_and_wish("a", [ids[0]])
	await wait_seconds(0.1)
	_pick_and_wish("b", [ids[0]])
	var b_lobby := await _latest_lobby("b")
	var line: Array = _server.free_line(ids[0])
	assert_eq(line.size(), 2)
	assert_eq(int(_room_line(b_lobby, ids[0])["place"]), 2)
	assert_eq(int(_room_line(b_lobby, ids[0])["waiting"]), 2)


func test_accepting_starts_the_race_after_the_wait_and_cpus_fill_the_field() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[0]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": true})
	var start := await _wait_for("a", Protocol.RACE_START)
	assert_false(start.is_empty())
	var entries: Array = start["entries"]
	assert_eq(entries.size(), Protocol.ROOM_CAPACITY)
	assert_eq(entries.filter(func(entry: Dictionary) -> bool: return bool(entry["player"])).size(), 1)
	assert_almost_eq(float(start["distance_m"]), float(OnlineConfig.free_rooms()[0]["distance_m"]), 0.001)
	var lobby := await _latest_lobby("a")
	assert_eq(str(_room_line(lobby, ids[0])["state"]), Protocol.FREE_STATE_RACING)


func test_declining_unchecks_only_that_room() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[0], ids[1]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": false})
	var lobby := await _latest_lobby("a")
	assert_eq(lobby["wishes"], [ids[1]])


func test_no_answer_unchecks_every_room() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[0], ids[1]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	assert_false(offer.is_empty())
	var ended := await _wait_for("a", Protocol.FREE_OFFER_END)
	assert_eq(str(ended["reason"]), Protocol.FREE_OFFER_TIMEOUT)
	var lobby := await _latest_lobby("a")
	assert_eq((lobby["wishes"] as Array).size(), 0)


func test_after_the_race_the_wishes_stay_and_the_runner_goes_to_the_back_of_the_line() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[0]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": true})
	await _wait_for("a", Protocol.RACE_START)
	var room: int = _server.get("_free_rooms")[ids[0]]
	var peers: Dictionary = _server.get("_peers")
	var peer_id := 0
	for id: int in peers:
		if str(peers[id]["name"]) == "a":
			peer_id = id
	var before := int(peers[peer_id]["wait_since_msec"])
	await wait_seconds(0.05)
	# レースを片づけたあとの流れ（本物のレースを最後まで走らせると長いので、片づけを直接呼ぶ）。
	_server.call("_end_race", room)
	_server.call("_free_race_over", room)
	assert_eq(int(peers[peer_id]["free_room"]), 0)
	assert_eq(peers[peer_id]["wishes"], [ids[0]])
	assert_gt(int(peers[peer_id]["wait_since_msec"]), before)


func test_quitting_mid_race_returns_to_the_lobby_and_the_cpu_runs_on() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_pick_and_wish("a", [ids[0]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": true})
	await _wait_for("a", Protocol.RACE_START)
	var room: int = _server.get("_free_rooms")[ids[0]]
	_clients["a"].send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})
	await _latest_lobby("a")
	assert_not_null(_server.room_race(room), "レースは、CPUで続く")
	assert_eq((_server.get("_rooms")[room]["order"] as Array).size(), 0)


# ---------------------------------------------------------------- ゲームの画面

const FreeLobbyScene := preload("res://scenes/online_free_lobby.tscn")
const FreeLobby := preload("res://scripts/online_free_lobby.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const ServerChoice := preload("res://scripts/config/online_server_choice.gd")
const ModeSelectScene := preload("res://scenes/mode_select.tscn")
const CHOICE_FILE := "user://test_online_free_server.json"


func _screen() -> Control:
	DirAccess.remove_absolute(CHOICE_FILE)
	ServerChoice.use_path(CHOICE_FILE)
	ServerChoice.save(ServerChoice.CHOICE_CUSTOM, "ws://127.0.0.1:%d" % TEST_PORT)
	var screen: Control = FreeLobbyScene.instantiate()
	add_child_autofree(screen)
	return screen


func after_each() -> void:
	RaceSession.set_course_only(_course_only_before)
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	DirAccess.remove_absolute(CHOICE_FILE)
	ServerChoice.use_path(ServerChoice.DEFAULT_SAVE_PATH)
	OnlineSession.close()
	OnlineSession.free_mode = false


## 画面に、その名前の部品が出るまで待つ。
func _wait_node(screen: Control, node_name: String) -> Node:
	var waited := 0.0
	while waited < WAIT_S:
		var node := screen.find_child(node_name, true, false)
		if node != null:
			return node
		await wait_seconds(0.05)
		waited += 0.05
	return null


func test_the_mode_select_opens_the_free_lobby() -> void:
	var mode: Control = ModeSelectScene.instantiate()
	add_child_autofree(mode)
	var button: Button = mode.find_child("OnlineFreeRaceButton", true, false)
	assert_false(button.disabled)
	assert_eq(button.text, "オンラインフリー対戦")


func test_the_screen_lists_the_rooms_and_checking_shows_the_priority_number() -> void:
	var ids := _free_ids()
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var screen := _screen()
	var first: Button = await _wait_node(screen, "Room_%s" % ids[1])
	assert_not_null(first, "ルームが並ぶ")
	await wait_seconds(0.3)
	# ぷるりんは、選んでいなければ、自動で1体選ぶ。
	assert_false(str(OnlineSession.free_lobby.get("pururin_id", "")).is_empty())
	screen.toggle_room(ids[1], true)
	screen.toggle_room(ids[0], true)
	await wait_seconds(0.3)
	assert_true(first.text.begins_with("☑ 1"), first.text)
	assert_true((screen.find_child("Room_%s" % ids[0], true, false) as Button).text.begins_with("☑ 2"))
	# 呼ばれると、どのルームかを出した確かめの画面が出る。
	var panel: Control = screen.find_child("OfferPanel", true, false)
	var waited := 0.0
	while not panel.visible and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_true(panel.visible)
	var text: String = (screen.find_child("OfferText", true, false) as Label).text
	assert_true(text.contains(str(OnlineConfig.free_rooms()[1]["name"])), text)
	assert_true(text.contains("第1希望"), text)
	# やめると、そのルームの☑だけが外れて、番号が詰まる。次の希望のルームが空いていれば、すぐそちらに呼ばれる。
	screen.answer(false)
	await wait_seconds(0.4)
	assert_true((screen.find_child("Room_%s" % ids[0], true, false) as Button).text.begins_with("☑ 1"))
	assert_true(first.text.begins_with("☐"))
	text = (screen.find_child("OfferText", true, false) as Label).text
	assert_true(panel.visible)
	assert_true(text.contains(str(OnlineConfig.free_rooms()[0]["name"])), text)


func test_the_room_text_shows_the_state_the_line_and_my_place() -> void:
	var text := FreeLobby.room_text({"name": "中距離", "distance_m": 2000.0, "state": Protocol.FREE_STATE_RACING, "waiting": 3, "place": 2}, 1)
	assert_true(text.begins_with("☑ 1"))
	assert_true(text.contains("中距離 2000m"))
	assert_true(text.contains("レース中"))
	assert_true(text.contains("待っている人 3"))
	assert_true(text.contains("あなたは 2 番目"))
	assert_true(FreeLobby.room_text({"name": "a", "distance_m": 1200.0, "state": Protocol.FREE_STATE_IDLE, "waiting": 0, "place": 0}, 0).begins_with("☐"))
