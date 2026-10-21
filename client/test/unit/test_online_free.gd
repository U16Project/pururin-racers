extends GutTest
## オンラインフリー対戦：全体のロビー、ルームの画面を見てからエントリー、優先の順番・一時保留・取り消し、長く待っている順に呼ぶ、
## 確かめの返事、CPUで埋めて始める、1つのルームで同時にいくつものレース、レースのあとの選択。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const OwnedPururins := preload("res://scripts/config/owned_pururins.gd")
const OWNED_FILE := "user://test_owned_pururins.json"
const TICKET_FILE := "user://test_online_tickets.json"
const RESULT_FILE := "user://test_online_results.json"

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
	_server.rest_after_race_s = 0.0
	# 自分のぷるりんとチケットは、テスト用の場所に置く（本物に触らない）。
	DirAccess.remove_absolute(OWNED_FILE)
	DirAccess.remove_absolute(TICKET_FILE)
	OwnedPururins.use_path(OWNED_FILE)
	_server.tickets_path = TICKET_FILE
	DirAccess.remove_absolute(RESULT_FILE)
	_server.results_path = RESULT_FILE
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


## エントリーの文（自分のぷるりんのIDと合言葉つき）。
func _entry_message(room_id: String, pururin_id: String) -> Dictionary:
	return {"room_id": room_id, "pururin_id": pururin_id, "uid": OwnedPururins.uid(pururin_id), "secret": OwnedPururins.secret(pururin_id)}


## エントリーする（どれも、一覧の最初のぷるりんで）。
func _enter_rooms(label: String, room_ids: Array) -> void:
	for room_id: String in room_ids:
		_clients[label].send(Protocol.FREE_ENTRY, _entry_message(room_id, _first_pururin()))


func _peer_id(label: String) -> int:
	var peers: Dictionary = _server.get("_peers")
	for id: int in peers:
		if str(peers[id]["name"]) == label:
			return id
	return 0


func _entry_ids(lobby: Dictionary) -> Array:
	return (lobby["entries"] as Array).map(func(entry: Dictionary) -> String: return str(entry["room_id"]))


## 呼ばれるまで待って、入ると答え、レースが始まるのを待つ。始まったレースの部屋の番号を返す。
func _accept_and_start(label: String) -> Dictionary:
	var offer := await _wait_for(label, Protocol.FREE_OFFER)
	_clients[label].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": true})
	return await _wait_for(label, Protocol.RACE_START)


func test_the_free_lobby_lists_the_configured_rooms_and_friend_rooms_do_not_show_them() -> void:
	var lobby := await _enter_free("a")
	var ids: Array = []
	for index in (lobby["rooms"] as Array).size():
		var room: Dictionary = lobby["rooms"][index]
		var spec: Dictionary = OnlineConfig.free_rooms()[index]
		ids.append(str(room["room_id"]))
		assert_eq(str(room["state"]), Protocol.FREE_STATE_IDLE)
		for key: String in ["name", "tag", "tag_color", "rule"]:
			assert_eq(str(room[key]), str(spec[key]))
		assert_eq(int(room["max_races"]), int(spec["max_races"]))
	assert_eq(ids, _free_ids())
	assert_eq((lobby["entries"] as Array).size(), 0)
	assert_almost_eq(float(lobby["answer_wait_s"]), ANSWER_WAIT_S, 0.001)
	# ともだち対戦の部屋の一覧と、部屋の数には、入らない。
	assert_eq(_server.room_count(), 0)
	assert_eq(_server.room_list().size(), 0)


func test_the_room_screen_gets_the_details_and_the_image() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_clients["a"].send(Protocol.FREE_VIEW, {"room_id": ids[0]})
	var detail := await _wait_for("a", Protocol.FREE_ROOM)
	assert_eq(str(detail["intro"]), str(OnlineConfig.free_rooms()[0]["intro"]))
	assert_eq(int(detail["capacity"]), Protocol.ROOM_CAPACITY)
	_clients["a"].send(Protocol.FREE_IMAGE_ASK, {"room_id": ids[0]})
	var image := await _wait_for("a", Protocol.FREE_IMAGE)
	assert_not_null(FreeLobby.image_texture(str(image["image"])), "画像が絵になる")
	_clients["a"].send(Protocol.FREE_VIEW, {"room_id": "no_such_room"})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_ROOM)


func test_entering_needs_a_known_pururin_and_room_and_re_entering_only_changes_the_pururin() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(ids[0], "no_such_pururin"))
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_BAD_MESSAGE)
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message("no_such_room", _first_pururin()))
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_ROOM)
	var second := str(PururinRosterConfig.values()["roster"][1]["id"])
	_enter_rooms("a", [ids[0]])
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(ids[0], second))
	var lobby := await _latest_lobby("a")
	assert_eq(_entry_ids(lobby), [ids[0]])
	assert_eq(str(lobby["entries"][0]["pururin_id"]), second)


func test_the_first_entry_is_called_first_and_the_offer_names_the_room_its_priority_and_the_pururin() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[1], ids[0]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	assert_eq(str(offer["room_id"]), ids[1])
	assert_eq(int(offer["priority"]), 1)
	assert_eq(str(offer["pururin_id"]), _first_pururin())
	assert_eq(str(offer["name"]), str(OnlineConfig.free_rooms()[1]["name"]))
	assert_almost_eq(float(offer["distance_m"]), float(OnlineConfig.free_rooms()[1]["distance_m"]), 0.001)


func test_reordering_moves_which_room_is_called_first() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	# 先に2つとも保留にしてから入れ替え、保留を外す（入れ替える前に呼ばれないように）。
	_enter_rooms("a", [ids[0], ids[1]])
	_clients["a"].send(Protocol.FREE_HOLD, {"room_id": ids[0], "hold": true})
	_clients["a"].send(Protocol.FREE_HOLD, {"room_id": ids[1], "hold": true})
	await _latest_lobby("a")
	_inbox["a"].clear()
	_clients["a"].send(Protocol.FREE_ORDER, {"room_ids": [ids[1], ids[0]]})
	_clients["a"].send(Protocol.FREE_HOLD, {"room_id": ids[0], "hold": false})
	_clients["a"].send(Protocol.FREE_HOLD, {"room_id": ids[1], "hold": false})
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	assert_eq(str(offer["room_id"]), ids[1])
	# 並べ替えは、今のエントリー候補の全部でないと断る。
	_clients["a"].send(Protocol.FREE_ORDER, {"room_ids": [ids[0]]})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_BAD_MESSAGE)


func test_a_held_entry_is_not_called_and_keeps_its_place_in_the_line() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	await _enter_free("b")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_enter_rooms("a", [ids[0]])
	_clients["a"].send(Protocol.FREE_HOLD, {"room_id": ids[0], "hold": true})
	await wait_seconds(0.3)
	assert_true((await _wait_for("a", Protocol.FREE_OFFER, 0.5)).is_empty(), "保留のあいだは呼ばれない")
	_enter_rooms("b", [ids[0]])
	var b_offer := await _wait_for("b", Protocol.FREE_OFFER)
	assert_eq(str(b_offer["room_id"]), ids[0])
	var a_lobby := await _latest_lobby("a")
	assert_true(bool(a_lobby["entries"][0]["hold"]))
	# 待っている列は、保留中の a が先（待っている時間は、保留のあいだも数え続ける）。
	assert_eq(_server.free_line(ids[0]), [_peer_id("a"), _peer_id("b")])
	assert_eq(int(a_lobby["entries"][0]["place"]), 1)


func test_those_who_waited_longer_are_called_first() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	await _enter_free("b")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_enter_rooms("a", [ids[0]])
	await wait_seconds(0.1)
	_enter_rooms("b", [ids[0]])
	var b_lobby := await _latest_lobby("b")
	assert_eq(_server.free_line(ids[0]), [_peer_id("a"), _peer_id("b")])
	assert_eq(int(b_lobby["entries"][0]["place"]), 2)
	assert_eq(int(_room_line(b_lobby, ids[0])["waiting"]), 2)


func test_accepting_starts_the_race_after_the_wait_and_cpus_fill_the_field() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	var start := await _accept_and_start("a")
	assert_false(start.is_empty())
	assert_eq(str(start["free_room_id"]), ids[0])
	var entries: Array = start["entries"]
	assert_eq(entries.size(), Protocol.ROOM_CAPACITY)
	assert_eq(entries.filter(func(entry: Dictionary) -> bool: return bool(entry["player"])).size(), 1)
	assert_almost_eq(float(start["distance_m"]), float(OnlineConfig.free_rooms()[0]["distance_m"]), 0.001)
	var lobby := await _latest_lobby("a")
	assert_eq(str(_room_line(lobby, ids[0])["state"]), Protocol.FREE_STATE_RACING)
	assert_eq(int(_room_line(lobby, ids[0])["races"]), 1)
	assert_eq(str(lobby["entries"][0]["state"]), Protocol.FREE_ENTRY_RACING)


func test_a_second_race_starts_in_the_same_room_while_the_first_is_running() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	await _enter_free("b")
	_enter_rooms("a", [ids[0]])
	await _accept_and_start("a")
	_enter_rooms("b", [ids[0]])
	var start := await _accept_and_start("b")
	assert_eq(str(start["free_room_id"]), ids[0])
	var lobby := await _latest_lobby("b")
	assert_eq(int(_room_line(lobby, ids[0])["races"]), 2)
	assert_eq((_server.get("_free_rooms")[ids[0]]["races"] as Array).size(), 2)


func test_declining_cancels_only_that_room() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0], ids[1]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": str(offer["room_id"]), "accept": false})
	var lobby := await _latest_lobby("a")
	assert_eq(_entry_ids(lobby), [ids[1]])


func test_no_answer_cancels_only_that_room() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0], ids[1]])
	var offer := await _wait_for("a", Protocol.FREE_OFFER)
	assert_eq(str(offer["room_id"]), ids[0])
	var ended := await _wait_for("a", Protocol.FREE_OFFER_END)
	assert_eq(str(ended["reason"]), Protocol.FREE_OFFER_TIMEOUT)
	var lobby := await _latest_lobby("a")
	assert_false(_entry_ids(lobby).has(ids[0]))
	assert_true(_entry_ids(lobby).has(ids[1]))


func test_cancelling_while_called_withdraws_the_call() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("answer_wait_s", 60.0)
	_server.set("fill_wait_s", 60.0)
	_enter_rooms("a", [ids[0]])
	await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_CANCEL, {"room_id": ids[0]})
	var lobby := await _latest_lobby("a")
	assert_eq((lobby["entries"] as Array).size(), 0)
	assert_eq(str(_server.get("_peers")[_peer_id("a")]["offer"]), "")
	_clients["a"].send(Protocol.FREE_CANCEL, {"room_id": ids[0]})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_ENTRY)


func test_after_the_race_the_entry_stays_and_is_not_called_until_back_in_the_lobby() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[ids[0]]["races"] as Array)[0]
	var peers: Dictionary = _server.get("_peers")
	var peer_id := _peer_id("a")
	var before := int(_server.call("_free_entry_of", peer_id, ids[0])["since_msec"])
	await wait_seconds(0.05)
	# レースを片づけたあとの流れ（本物のレースを最後まで走らせると長いので、片づけを直接呼ぶ）。
	_server.call("_end_race", room)
	_server.call("_free_race_over", room)
	assert_false((_server.get("_rooms") as Dictionary).has(room), "片づけたレースは消える")
	assert_eq(int(peers[peer_id]["free_room"]), 0)
	assert_true(bool(peers[peer_id]["returning"]))
	assert_gt(int(_server.call("_free_entry_of", peer_id, ids[0])["since_msec"]), before, "列の後ろへ")
	_inbox["a"].clear()
	assert_true((await _wait_for("a", Protocol.FREE_OFFER, 0.5)).is_empty(), "戻るまで呼ばない")
	# 結果の画面で「保留」を選んで戻る：呼ばれない。
	_clients["a"].send(Protocol.FREE_AFTER, {"room_id": ids[0], "entry": Protocol.FREE_AFTER_HOLD, "top": false})
	_clients["a"].send(Protocol.FREE_ENTER)
	var lobby := await _latest_lobby("a")
	assert_true(bool(lobby["entries"][0]["hold"]))
	assert_true((await _wait_for("a", Protocol.FREE_OFFER, 0.5)).is_empty())


func test_the_after_race_choice_can_cancel_or_move_the_entry_to_the_top() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_enter_rooms("a", [ids[0], ids[1], ids[2]])
	for room_id: String in [ids[0], ids[1], ids[2]]:
		_clients["a"].send(Protocol.FREE_HOLD, {"room_id": room_id, "hold": true})
	_clients["a"].send(Protocol.FREE_AFTER, {"room_id": ids[2], "entry": Protocol.FREE_AFTER_HOLD, "top": true})
	_clients["a"].send(Protocol.FREE_AFTER, {"room_id": ids[1], "entry": Protocol.FREE_AFTER_OFF, "top": false})
	var lobby := await _latest_lobby("a")
	assert_eq(_entry_ids(lobby), [ids[2], ids[0]])


func test_quitting_mid_race_returns_to_the_lobby_and_the_cpu_runs_on() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[ids[0]]["races"] as Array)[0]
	_clients["a"].send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})
	await _latest_lobby("a")
	assert_not_null(_server.room_race(room), "レースは、CPUで続く")
	assert_eq((_server.get("_rooms")[room]["order"] as Array).size(), 0)


func test_leaving_the_free_lobby_clears_every_entry() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	_enter_rooms("a", [ids[0], ids[1]])
	await _latest_lobby("a")
	_clients["a"].send(Protocol.FREE_LEAVE)
	await _wait_for("a", Protocol.LOBBY)
	assert_eq((_server.get("_peers")[_peer_id("a")]["entries"] as Array).size(), 0)
	assert_eq(_server.free_line(ids[0]).size(), 0)


## そのチャットの、これまでの行が届くまで待つ（ほかのチャットのものは捨てる）。
func _wait_for_chat_log(label: String, room_id: String) -> Dictionary:
	var log := await _wait_for(label, Protocol.FREE_CHAT_LOG)
	while not log.is_empty() and str(log["room_id"]) != room_id:
		log = await _wait_for(label, Protocol.FREE_CHAT_LOG)
	return log


func test_the_lobby_chat_reaches_everyone_and_the_room_chat_only_those_viewing_the_room() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	await _enter_free("b")
	_clients["b"].send(Protocol.FREE_VIEW, {"room_id": ids[0]})
	assert_false((await _wait_for_chat_log("b", ids[0])).is_empty())
	_clients["a"].send(Protocol.FREE_CHAT, {"room_id": "", "text": "  こんにちは  "})
	var to_b := await _wait_for("b", Protocol.FREE_CHAT_MESSAGE)
	assert_eq(str(to_b["room_id"]), "")
	assert_eq(str(to_b["text"]), "こんにちは")
	assert_eq(str(to_b["name"]), "a")
	assert_false((await _wait_for("a", Protocol.FREE_CHAT_MESSAGE)).is_empty(), "書いた本人にも届く")
	# ルームのチャットは、そのルームを開いている b にだけ届く。
	_clients["b"].send(Protocol.FREE_CHAT, {"room_id": ids[0], "text": "x".repeat(OnlineConfig.chat_max_length() + 5)})
	var room_line := await _wait_for("b", Protocol.FREE_CHAT_MESSAGE)
	assert_eq(str(room_line["room_id"]), ids[0])
	assert_eq(str(room_line["text"]).length(), OnlineConfig.chat_max_length())
	assert_true((await _wait_for("a", Protocol.FREE_CHAT_MESSAGE, 0.5)).is_empty())
	# あとから開いた人には、これまでの行が届く。
	_clients["a"].send(Protocol.FREE_VIEW, {"room_id": ids[0]})
	var log := await _wait_for_chat_log("a", ids[0])
	assert_eq((log["lines"] as Array).size(), 1)
	_clients["a"].send(Protocol.FREE_CHAT, {"room_id": "", "text": "   "})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_BAD_MESSAGE)


func test_the_server_keeps_only_the_newest_chat_lines() -> void:
	await _enter_free("a")
	for index in Protocol.FREE_CHAT_HISTORY + 3:
		_clients["a"].send(Protocol.FREE_CHAT, {"room_id": "", "text": str(index)})
	await wait_seconds(0.3)
	_clients["a"].send(Protocol.FREE_ENTER)
	var log := await _wait_for("a", Protocol.FREE_CHAT_LOG)
	while not log.is_empty() and (log["lines"] as Array).size() < Protocol.FREE_CHAT_HISTORY:
		log = await _wait_for("a", Protocol.FREE_CHAT_LOG)
	assert_eq((log["lines"] as Array).size(), Protocol.FREE_CHAT_HISTORY)
	assert_eq(str(log["lines"][0]["text"]), "3")


func _room_spec(key: String, value: String) -> Dictionary:
	for spec: Dictionary in OnlineConfig.free_rooms():
		if str(spec.get(key, "")) == value:
			return spec
	return {}


func test_entering_needs_the_id_and_secret() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_clients["a"].send(Protocol.FREE_ENTRY, {"room_id": ids[0], "pururin_id": _first_pururin()})
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_BAD_MESSAGE)


func test_a_ticket_room_needs_the_ticket_and_the_winner_of_the_giving_room_gets_it() -> void:
	var ticket_room := _room_spec("needs_ticket", str(OnlineConfig.values()["free_tickets"][0]["id"]))
	var giving_room := _room_spec("gives_ticket", str(ticket_room["needs_ticket"]))
	assert_false(ticket_room.is_empty() or giving_room.is_empty(), "チケットを渡すルームと、要るルームが設定にある")
	await _enter_free("a")
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var pururin := _first_pururin()
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(str(ticket_room["id"]), pururin))
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_TICKET)
	# チケットを渡すルームで、走って1位になった（本物のレースを最後まで走らせると長いので、結果を直接渡す）。
	_server.set("fill_wait_s", FILL_WAIT_S)
	_server.set("answer_wait_s", ANSWER_WAIT_S)
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(str(giving_room["id"]), pururin))
	var start := await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[str(giving_room["id"])]["races"] as Array)[0]
	var mine: Dictionary = (start["entries"] as Array).filter(func(entry: Dictionary) -> bool: return bool(entry["player"]))[0]
	_server.call("_free_give_ticket", room, [{"id": str(mine["runner_id"]), "place": 1}])
	var ticket := await _wait_for("a", Protocol.FREE_TICKET)
	assert_eq(str(ticket["ticket_id"]), str(ticket_room["needs_ticket"]))
	assert_eq(str(ticket["uid"]), OwnedPururins.uid(pururin))
	assert_true(FileAccess.file_exists(TICKET_FILE), "チケットはファイルに残る")
	# チケットを持っていれば、入れる。合言葉が違えば、入れない。
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(str(ticket_room["id"]), pururin))
	var lobby := await _latest_lobby("a")
	assert_true(_entry_ids(lobby).has(str(ticket_room["id"])))
	var wrong := _entry_message(str(ticket_room["id"]), pururin)
	wrong["secret"] = "0".repeat(64)
	_clients["a"].send(Protocol.FREE_ENTRY, wrong)
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_NO_TICKET)
	# サーバーを起動し直しても、チケットは残る。
	_server.call("load_tickets")
	assert_true(_server.has_ticket(OwnedPururins.uid(pururin), OwnedPururins.secret(pururin).sha256_text(), pururin, str(ticket_room["needs_ticket"])))


func test_a_cpu_win_gives_no_ticket() -> void:
	var giving_room := _room_spec("gives_ticket", str(OnlineConfig.values()["free_tickets"][0]["id"]))
	await _enter_free("a")
	_clients["a"].send(Protocol.FREE_ENTRY, _entry_message(str(giving_room["id"]), _first_pururin()))
	var start := await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[str(giving_room["id"])]["races"] as Array)[0]
	var cpu: Dictionary = (start["entries"] as Array).filter(func(entry: Dictionary) -> bool: return not bool(entry["player"]))[0]
	_server.call("_free_give_ticket", room, [{"id": str(cpu["runner_id"]), "place": 1}])
	assert_true((await _wait_for("a", Protocol.FREE_TICKET, 0.5)).is_empty())
	assert_eq((_server.get("_tickets") as Dictionary).size(), 0)


func test_owned_pururins_get_a_long_id_and_secret_and_keep_tickets() -> void:
	var pururin := _first_pururin()
	var uid := OwnedPururins.uid(pururin)
	assert_eq(uid.length(), OwnedPururins.UID_BYTES * 2)
	assert_eq(OwnedPururins.secret(pururin).length(), OwnedPururins.SECRET_BYTES * 2)
	assert_ne(uid, OwnedPururins.uid(str(PururinRosterConfig.values()["roster"][1]["id"])))
	assert_false(OwnedPururins.any_has_ticket("t", 0))
	assert_true(OwnedPururins.add_ticket(uid, "t", "テストのチケット", 0))
	assert_false(OwnedPururins.add_ticket("no_such_uid", "t", "x", 0))
	assert_true(OwnedPururins.add_ticket(uid, "old", "期限つき", 1000))
	# 読み直しても同じ。
	OwnedPururins.use_path(OWNED_FILE)
	assert_eq(OwnedPururins.uid(pururin), uid)
	assert_eq(OwnedPururins.tickets(pururin, 999), {"t": "テストのチケット", "old": "期限つき"})
	assert_eq(OwnedPururins.tickets(pururin, 1000), {"t": "テストのチケット"}, "期限を過ぎたチケットは使えない")
	assert_true(OwnedPururins.any_has_ticket("t", 1000))
	assert_false(OwnedPururins.any_has_ticket("old", 1000))


func test_schedule_times_are_japan_time() -> void:
	assert_eq(OnlineConfig.schedule_unix("2026-10-25 07:00"), Time.get_unix_time_from_datetime_string("2026-10-24T22:00:00"))
	assert_eq(OnlineConfig.schedule_unix("2026-10-25 7:00"), -1)
	assert_eq(OnlineConfig.schedule_unix("2026-13-25 07:00"), -1)
	assert_eq(OnlineConfig.schedule_unix(5), -1)
	var rooms: Array = [_room_spec("id", _free_ids()[0]).duplicate()]
	rooms[0]["open_at"] = "2026-10-25 07:30"
	rooms[0]["close_at"] = "2026-10-25 07:00"
	assert_false(OnlineConfig.validate_free_rooms(rooms, OnlineConfig.values()["free_tickets"]).is_empty(), "終了は開始より後")
	rooms[0]["close_at"] = "2026-10-25 08:00"
	assert_true(OnlineConfig.validate_free_rooms(rooms, OnlineConfig.values()["free_tickets"]).is_empty())
	rooms[0].erase("close_at")
	assert_false(OnlineConfig.validate_free_rooms(rooms, OnlineConfig.values()["free_tickets"]).is_empty(), "2つそろって")


func test_a_scheduled_room_takes_entries_only_while_open_and_disappears_after() -> void:
	var ids := _free_ids()
	var room: Dictionary = _server.get("_free_rooms")[ids[0]]
	room["open_unix"] = 10000
	room["close_unix"] = 20000
	_server.set("clock_unix", 9000)
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_CLOSED, "受付の前")
	_server.call("_announce_free")
	var lobby := await _latest_lobby("a")
	assert_eq(int(_room_line(lobby, ids[0])["open_unix"]), 10000)
	assert_eq(int(lobby["now_unix"]), 9000)
	_server.set("clock_unix", 10000)
	_enter_rooms("a", [ids[0]])
	assert_false((await _wait_for("a", Protocol.FREE_OFFER)).is_empty(), "受付中は、呼ばれる")
	# 受付が終わると、エントリーは取り消され、走っているレースが無ければ、ロビーから消える。
	_server.set("clock_unix", 20000)
	await wait_seconds(0.2)
	lobby = await _latest_lobby("a")
	assert_eq((lobby["entries"] as Array).size(), 0)
	assert_true(_room_line(lobby, ids[0]).is_empty())
	_enter_rooms("a", [ids[0]])
	assert_eq(str((await _wait_for("a", Protocol.ERROR))["code"]), Protocol.ERROR_CLOSED, "受付の後")


func test_an_expired_ticket_no_longer_opens_the_room() -> void:
	var ticket: Dictionary = OnlineConfig.values()["free_tickets"][0]
	var ticket_id := str(ticket["id"])
	var pururin := _first_pururin()
	var uid := OwnedPururins.uid(pururin)
	var secret_sha := OwnedPururins.secret(pururin).sha256_text()
	(_server.get("_tickets") as Dictionary)[uid] = {"secret_sha256": secret_sha, "pururin_id": pururin, "stats": OnlineServer.pururin_stats(pururin), "tickets": {ticket_id: {}}}
	assert_true(_server.has_ticket(uid, secret_sha, pururin, ticket_id))
	ticket["expires_at"] = "2026-10-25 07:00"
	_server.set("clock_unix", OnlineConfig.schedule_unix("2026-10-25 07:00"))
	var expired: bool = not _server.has_ticket(uid, secret_sha, pururin, ticket_id)
	_server.set("clock_unix", OnlineConfig.schedule_unix("2026-10-25 06:59"))
	var before: bool = _server.has_ticket(uid, secret_sha, pururin, ticket_id)
	ticket.erase("expires_at")
	assert_true(expired, "期限を過ぎたら使えない")
	assert_true(before, "期限の前は使える")


func test_the_schedule_texts() -> void:
	var open := OnlineConfig.schedule_unix("2026-10-25 07:00")
	var room := {"open_unix": open, "close_unix": open + 1800}
	assert_eq(FreeLobby.schedule_text(open), "10/25 7:00")
	assert_eq(FreeLobby.schedule_range_text(open, open + 1800), "10/25 7:00〜7:30")
	assert_eq(FreeLobby.schedule_range_text(open, open + 86400), "10/25 7:00〜10/26 7:00")
	assert_eq(FreeLobby.schedule_state_text(room, open - 60), "受付は 10/25 7:00 から")
	assert_eq(FreeLobby.schedule_state_text(room, open + 60), "締め切りまで 29分")
	assert_eq(FreeLobby.schedule_state_text({"open_unix": open, "close_unix": open + 7200}, open), "締め切りまで 2時間0分")
	assert_eq(FreeLobby.schedule_state_text(room, open + 1800), "受付は終わりました")
	assert_eq(FreeLobby.schedule_state_text({"open_unix": 0, "close_unix": 0}, open), "")


## そのルームを、本戦にする（設定に本戦のルームが無いので、テストの中で作る）。
func _make_final(free_id: String, start_unix: int, max_players: int, answer_wait_s: float) -> void:
	var room: Dictionary = _server.get("_free_rooms")[free_id]
	room["final"] = {"start_at": "", "max_players": max_players, "answer_wait_s": answer_wait_s}
	room["start_unix"] = start_unix
	room["phase"] = Protocol.FINAL_PHASE_ENTRY
	room["accepted"] = []
	room["advancers"] = []
	room["wait_until_msec"] = 0


func test_final_groups_are_even_and_at_most_eight() -> void:
	var sizes: Array = OnlineServer.final_groups(range(20)).map(func(group: Array) -> int: return group.size())
	sizes.sort()
	assert_eq(sizes, [6, 7, 7])
	assert_eq(OnlineServer.final_groups(range(9)).size(), 2)
	var all: Array = []
	for group: Array in OnlineServer.final_groups(range(17)):
		assert_true(group.size() <= Protocol.ROOM_CAPACITY)
		all.append_array(group)
	all.sort()
	assert_eq(all, range(17))


func test_the_final_takes_entries_until_the_start_up_to_the_limit() -> void:
	var ids := _free_ids()
	_server.set("clock_unix", 1000)
	_make_final(ids[0], 2000, 1, 30.0)
	await _enter_free("a")
	await _enter_free("b")
	_enter_rooms("a", [ids[0]])
	var lobby := await _latest_lobby("a")
	assert_eq(_entry_ids(lobby), [ids[0]])
	var line := _room_line(lobby, ids[0])
	assert_eq(str(line["kind"]), "final")
	assert_eq(int(line["start_unix"]), 2000)
	assert_eq(str(line["phase"]), Protocol.FINAL_PHASE_ENTRY)
	assert_true((await _wait_for("a", Protocol.FREE_OFFER, 0.4)).is_empty(), "開始の前は、呼ばない")
	_enter_rooms("b", [ids[0]])
	assert_eq(str((await _wait_for("b", Protocol.ERROR))["code"]), Protocol.ERROR_ROOM_FULL, "上限まで")


func test_at_the_start_everyone_is_called_and_no_answer_means_out() -> void:
	var ids := _free_ids()
	_server.set("clock_unix", 1000)
	_make_final(ids[0], 2000, 64, 0.5)
	await _enter_free("a")
	await _enter_free("b")
	_enter_rooms("a", [ids[0]])
	_enter_rooms("b", [ids[0]])
	await _latest_lobby("b")
	_server.set("clock_unix", 2000)
	var offer_a := await _wait_for("a", Protocol.FREE_OFFER)
	assert_eq(str(offer_a["stage"]), Protocol.STAGE_SEMI)
	assert_almost_eq(float(offer_a["wait_s"]), 0.5, 0.001)
	assert_false((await _wait_for("b", Protocol.FREE_OFFER)).is_empty())
	# a は入る、b は答えない（失格）。8人以下なので、すぐ決勝。
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": ids[0], "accept": true})
	var start := await _wait_for("a", Protocol.RACE_START)
	assert_eq(str(start["stage"]), Protocol.STAGE_FINAL)
	assert_eq((start["entries"] as Array).filter(func(entry: Dictionary) -> bool: return bool(entry["player"])).size(), 1)
	assert_eq(str((await _wait_for("b", Protocol.FREE_OFFER_END))["reason"]), Protocol.FREE_OFFER_TIMEOUT)
	assert_true(_server.call("_free_entry_of", _peer_id("b"), ids[0]).is_empty(), "答えなかった人は失格")


func test_semifinal_winners_go_to_the_final_and_a_cpu_win_lifts_the_best_human() -> void:
	var ids := _free_ids()
	var labels: Array = []
	for index in Protocol.ROOM_CAPACITY + 1:
		labels.append("p%d" % index)
	_server.set("clock_unix", 1000)
	_make_final(ids[0], 2000, 64, 30.0)
	for label: String in labels:
		await _enter_free(label)
		_enter_rooms(label, [ids[0]])
	await wait_seconds(0.3)
	_server.set("clock_unix", 2000)
	for label: String in labels:
		assert_false((await _wait_for(label, Protocol.FREE_OFFER)).is_empty())
		_clients[label].send(Protocol.FREE_ANSWER, {"room_id": ids[0], "accept": true})
	var starts := {}
	for label: String in labels:
		starts[label] = await _wait_for(label, Protocol.RACE_START)
		assert_eq(str(starts[label]["stage"]), Protocol.STAGE_SEMI)
	var races: Array = (_server.get("_free_rooms")[ids[0]]["races"] as Array).duplicate()
	assert_eq(races.size(), 2, "9人なら、準決勝は2つ")
	# 1つ目の準決勝は CPU が1位、人は2位と3位 → 2位の人が決勝へ。2つ目は人が1位。
	var rooms: Dictionary = _server.get("_rooms")
	var advancers: Array = []
	for room: int in races:
		var entries: Array = rooms[room]["entries"]
		var humans: Array = entries.filter(func(entry: Dictionary) -> bool: return bool(entry["player"]))
		var cpus: Array = entries.filter(func(entry: Dictionary) -> bool: return not bool(entry["player"]))
		var rows: Array = []
		if room == races[0]:
			rows.append({"id": str(cpus[0]["runner_id"]), "place": 1})
		for index in humans.size():
			rows.append({"id": str(humans[index]["runner_id"]), "place": index + 2})
		advancers.append(int(humans[0]["peer_id"]))
		_server.call("_free_final_result", room, rows)
	for room: int in races:
		_server.call("_end_race", room)
		_server.call("_free_race_over", room)
	# 決勝に進む人だけが、ロビーに戻ると、決勝の呼び出しを受ける。敗退した人のエントリーは消える。
	for label: String in labels:
		_clients[label].send(Protocol.FREE_ENTER)
	for label: String in labels:
		var peer_id := _peer_id(label)
		if advancers.has(peer_id):
			var offer := await _wait_for(label, Protocol.FREE_OFFER)
			assert_eq(str(offer["stage"]), Protocol.STAGE_FINAL, label)
		else:
			assert_true(_server.call("_free_entry_of", peer_id, ids[0]).is_empty(), label)
	for label: String in labels:
		if advancers.has(_peer_id(label)):
			_clients[label].send(Protocol.FREE_ANSWER, {"room_id": ids[0], "accept": true})
	for label: String in labels:
		if advancers.has(_peer_id(label)):
			assert_eq(str((await _wait_for(label, Protocol.RACE_START))["stage"]), Protocol.STAGE_FINAL)
	assert_eq(str(_server.get("_free_rooms")[ids[0]]["phase"]), Protocol.FINAL_PHASE_FINAL)


func test_the_final_texts() -> void:
	var room := {"kind": "final", "phase": Protocol.FINAL_PHASE_ENTRY, "start_unix": 1000, "waiting": 12, "max_players": 64}
	assert_eq(FreeLobby.final_state_text(room, 1000 - 18 * 60), "エントリー 12/64人　開始まで 18分")
	assert_eq(FreeLobby.final_state_text(room, 1000), "エントリー 12/64人　まもなく開始")
	assert_eq(FreeLobby.final_state_text(room, 1000 - 18 * 60, true), "12/64人　開始まで 18分")
	room["phase"] = Protocol.FINAL_PHASE_SEMIS
	room["races"] = 8
	assert_eq(FreeLobby.final_state_text(room, 0), "準決勝 8レース中")
	room["phase"] = Protocol.FINAL_PHASE_FINAL_CALLING
	assert_eq(FreeLobby.final_state_text(room, 0), "決勝の呼び出し中")


## 始まったレースに、着順を直接入れて、結果を残す（人が1位、CPUはそのあと）。
func _record_fake_result(room: int) -> void:
	var entries: Array = _server.get("_rooms")[room]["entries"]
	var rows: Array = []
	var place := 1
	for entry: Dictionary in entries.filter(func(e: Dictionary) -> bool: return bool(e["player"])) + entries.filter(func(e: Dictionary) -> bool: return not bool(e["player"])):
		rows.append({"id": str(entry["runner_id"]), "place": place, "time": 100.0 + place})
		place += 1
	_server.call("_free_record_result", room, rows)


func test_results_are_kept_per_room_newest_first_and_saved() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[ids[0]]["races"] as Array)[0]
	for index in OnlineConfig.free_result_keep() + 2:
		_server.set("clock_unix", 1000 + index)
		_record_fake_result(room)
	var results: Array = _server.free_room_results(ids[0])
	assert_eq(results.size(), OnlineConfig.free_result_keep(), "新しいほうから決めた数だけ")
	assert_eq(int(results[0]["unix"]), 1000 + OnlineConfig.free_result_keep() + 1, "新しいものが前")
	var first: Dictionary = results[0]["rows"][0]
	assert_eq(int(first["place"]), 1)
	assert_eq(str(first["name"]), "a")
	assert_true(bool(first["player"]))
	assert_eq(str(first["pururin"]), str(PururinRosterConfig.values()["roster"][0]["display_name"]))
	assert_almost_eq(float(first["time"]), 101.0, 0.001)
	# ファイルに残り、読み直しても同じ。問い合わせにも答える。
	_server.call("load_results")
	assert_eq(_server.free_room_results(ids[0]).size(), OnlineConfig.free_result_keep())
	_clients["a"].send(Protocol.FREE_RESULTS_ASK, {"room_id": ids[0]})
	var answer := await _wait_for("a", Protocol.FREE_RESULTS)
	assert_eq((answer["results"] as Array).size(), OnlineConfig.free_result_keep())


func test_a_main_event_keeps_its_semifinals_and_final_as_an_event() -> void:
	var ids := _free_ids()
	_server.set("clock_unix", 1000)
	_make_final(ids[0], 2000, 64, 30.0)
	await _enter_free("a")
	_enter_rooms("a", [ids[0]])
	await _latest_lobby("a")
	_server.set("clock_unix", 2000)
	await _wait_for("a", Protocol.FREE_OFFER)
	_clients["a"].send(Protocol.FREE_ANSWER, {"room_id": ids[0], "accept": true})
	await _wait_for("a", Protocol.RACE_START)
	var room: int = (_server.get("_free_rooms")[ids[0]]["races"] as Array)[0]
	_server.set("clock_unix", 2600)
	_record_fake_result(room)
	var events: Array = _server.free_event_results()
	assert_eq(events.size(), 1)
	assert_eq(str(events[0]["name"]), str(OnlineConfig.free_rooms()[0]["name"]))
	assert_eq(int(events[0]["start_unix"]), 2000)
	assert_eq(int(events[0]["end_unix"]), 2600)
	assert_eq(str(events[0]["final"][0]["name"]), "a")
	_clients["a"].send(Protocol.FREE_EVENTS_ASK, {"room_id": ""})
	assert_eq(((await _wait_for("a", Protocol.FREE_EVENTS))["events"] as Array).size(), 1)


func test_race_times_read_as_minutes_seconds_and_hundredths() -> void:
	assert_eq(FreeLobby.time_text(104.84), "1分44秒84")
	assert_eq(FreeLobby.time_text(59.999), "1分00秒00")
	assert_eq(FreeLobby.time_text(5.07), "0分05秒07")


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
	OwnedPururins.use_path(OwnedPururins.DEFAULT_SAVE_PATH)
	DirAccess.remove_absolute(OWNED_FILE)
	DirAccess.remove_absolute(TICKET_FILE)
	DirAccess.remove_absolute(RESULT_FILE)


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


func _wait_until(condition: Callable) -> bool:
	var waited := 0.0
	while not bool(condition.call()) and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	return bool(condition.call())


func test_the_mode_select_opens_the_free_lobby() -> void:
	var mode: Control = ModeSelectScene.instantiate()
	add_child_autofree(mode)
	var button: Button = mode.find_child("OnlineFreeRaceButton", true, false)
	assert_false(button.disabled)
	assert_eq(button.text, "オンラインフリー対戦")


func test_clicking_a_card_only_opens_the_room_and_the_entry_button_enters() -> void:
	var ids := _free_ids()
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var screen := _screen()
	var card: Button = await _wait_node(screen, "Card_%s" % ids[1])
	assert_not_null(card, "ルームのカードが並ぶ")
	assert_eq((card.find_child("Name", true, false) as Label).text, str(OnlineConfig.free_rooms()[1]["name"]))
	# カードを押しても、エントリーにはならない（ルームの画面が開くだけ）。
	card.pressed.emit()
	assert_true(await _wait_until(func() -> bool: return not screen.get("_detail").is_empty()), "くわしいようすが届く")
	assert_true((screen.find_child("RoomView", true, false) as Control).visible)
	assert_eq((screen.find_child("Intro", true, false) as Label).text, str(OnlineConfig.free_rooms()[1]["intro"]))
	assert_eq(_server.free_line(ids[1]).size(), 0)
	# 「エントリーする」を押して、はじめてエントリーになる。
	var entry_button: Button = screen.find_child("EntryButton", true, false)
	entry_button.pressed.emit()
	assert_true(await _wait_until(func() -> bool: return (screen.get("_entries") as Array).size() == 1))
	assert_eq(entry_button.text, "取り消す")
	# 呼ばれると、どのルームかを出した確かめの窓が出る。
	var panel: Control = screen.find_child("OfferPanel", true, false)
	assert_true(await _wait_until(func() -> bool: return panel.visible))
	assert_true((screen.find_child("OfferRoom", true, false) as Label).text.contains(str(OnlineConfig.free_rooms()[1]["name"])))
	assert_true((screen.find_child("OfferInfo", true, false) as Label).text.contains("第1候補"))
	# 入らないと、そのルームのエントリーが取り消される。
	screen.answer(false)
	assert_true(await _wait_until(func() -> bool: return (screen.get("_entries") as Array).is_empty()))
	assert_eq(entry_button.text, "エントリーする")


func test_the_entries_tab_lists_the_entries_with_hold_and_cancel() -> void:
	var ids := _free_ids()
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	var client: Node = OnlineSession.client(get_tree())
	for room_id: String in [ids[0], ids[1]]:
		client.send(Protocol.FREE_ENTRY, _entry_message(room_id, _first_pururin()))
		client.send(Protocol.FREE_HOLD, {"room_id": room_id, "hold": true})
	assert_true(await _wait_until(func() -> bool: return (screen.get("_entries") as Array).size() == 2))
	screen.show_tab(FreeLobby.TAB_ENTRIES)
	var list: Control = screen.find_child("EntryList", true, false)
	var rows := list.get_children().filter(func(row: Control) -> bool: return row.visible)
	assert_eq(rows.size(), 2)
	assert_true((rows[0].find_child("State", true, false) as Label).text.begins_with("保留中"))
	assert_eq((screen.find_child("EntriesCount", true, false) as Label).text, "2")
	(rows[1].find_child("Cancel", true, false) as Button).pressed.emit()
	assert_true(await _wait_until(func() -> bool: return (screen.get("_entries") as Array).size() == 1))


func test_the_state_texts() -> void:
	assert_eq(FreeLobby.state_text({"state": Protocol.FREE_STATE_RACING, "races": 2, "waiting": 5}), "レース中 2　待ち 5人")
	assert_eq(FreeLobby.state_text({"state": Protocol.FREE_STATE_CALLING, "waiting": 3}), "呼び出し中　待ち 3人")
	assert_eq(FreeLobby.state_text({"state": Protocol.FREE_STATE_IDLE, "waiting": 0}), "空いています　待ち 0人")
	assert_eq(FreeLobby.entry_state_text({"state": Protocol.FREE_ENTRY_WAIT, "hold": false, "place": 3}), "待ち 3番目")
	assert_eq(FreeLobby.entry_state_text({"state": Protocol.FREE_ENTRY_WAIT, "hold": true, "place": 1}), "保留中（待ち 1番目）")
	assert_eq(FreeLobby.entry_state_text({"state": Protocol.FREE_ENTRY_CALLED, "hold": false, "place": 1}), "呼ばれています")


func test_the_status_window_shows_the_pururin_and_changing_goes_through_the_pick_window() -> void:
	var ids := _free_ids()
	var screen := _screen()
	var card: Button = await _wait_node(screen, "Card_%s" % ids[0])
	card.pressed.emit()
	await wait_seconds(0.2)
	var first: String = screen.selected_pururin_id()
	(screen.find_child("StatusButton", true, false) as Button).pressed.emit()
	assert_true((screen.find_child("PickDialog", true, false) as Control).visible, "ステータスの窓が開く")
	# 「変更」でプル選択の窓、プルを押すと「このプルにしますか」、「このプルにする」で決まる。
	(screen.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	assert_true(screen.is_picker_open())
	var other := str(PururinRosterConfig.values()["roster"][2]["id"])
	screen.find_child("Picker", true, false).picked.emit(other)
	assert_eq((screen.find_child("PickDialogTitle", true, false) as Label).text, "このプルにしますか")
	assert_eq(screen.selected_pururin_id(), first, "決めるまでは替わらない")
	(screen.find_child("PickChangeButton", true, false) as Button).pressed.emit()
	assert_eq(screen.selected_pururin_id(), other)
	assert_false((screen.find_child("PickDialog", true, false) as Control).visible)


func test_the_chat_boxes_send_and_show_the_lines() -> void:
	var ids := _free_ids()
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	var edit: LineEdit = screen.find_child("LobbyChatEdit", true, false)
	edit.text = "やあ"
	(screen.find_child("LobbyChatSend", true, false) as Button).pressed.emit()
	var log: RichTextLabel = screen.find_child("LobbyChatLog", true, false)
	assert_true(await _wait_until(func() -> bool: return log.get_parsed_text().contains("やあ")))
	assert_eq(edit.text, "")
	screen.open_room(ids[0])
	var room_edit: LineEdit = screen.find_child("RoomChatEdit", true, false)
	room_edit.text = "ルームで"
	room_edit.text_submitted.emit(room_edit.text)
	var room_log: RichTextLabel = screen.find_child("RoomChatLog", true, false)
	assert_true(await _wait_until(func() -> bool: return room_log.get_parsed_text().contains("ルームで")))
	assert_false(log.get_parsed_text().contains("ルームで"))


func test_the_big_chat_box_opens_with_t_and_writes_to_the_chosen_chat() -> void:
	var ids := _free_ids()
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	await wait_seconds(0.2)
	var overlay: Control = screen.find_child("ChatOverlay", true, false)
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	screen._unhandled_input(key)
	assert_true(overlay.visible, "T で開く")
	assert_false((screen.find_child("ChatOverlayTabs", true, false) as Control).visible, "ロビーでは、全体のチャットだけ")
	var edit: LineEdit = screen.find_child("ChatOverlayEdit", true, false)
	assert_eq(get_viewport().gui_get_focus_owner(), edit)
	edit.text = "大きい欄から"
	edit.text_submitted.emit(edit.text)
	var log: RichTextLabel = screen.find_child("ChatOverlayLog", true, false)
	assert_true(await _wait_until(func() -> bool: return log.get_parsed_text().contains("大きい欄から")))
	assert_true((screen.find_child("LobbyChatLog", true, false) as RichTextLabel).get_parsed_text().contains("大きい欄から"))
	screen.toggle_chat_overlay()
	assert_false(overlay.visible)
	# ルームの画面では、はじめは「このルーム」。タブで全体に切り替えられる。
	screen.open_room(ids[0])
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	screen._unhandled_input(pad)
	assert_true(overlay.visible, "SELECT で開く")
	assert_true((screen.find_child("ChatOverlayRoomTab", true, false) as Button).button_pressed)
	edit.text = "ルームへ"
	edit.text_submitted.emit(edit.text)
	assert_true(await _wait_until(func() -> bool: return (screen.find_child("RoomChatLog", true, false) as RichTextLabel).get_parsed_text().contains("ルームへ")))
	(screen.find_child("ChatOverlayLobbyTab", true, false) as Button).pressed.emit()
	assert_true(log.get_parsed_text().contains("大きい欄から"))
	assert_false(log.get_parsed_text().contains("ルームへ"))


func test_a_ticket_room_card_is_locked_until_a_pururin_has_the_ticket() -> void:
	var ticket_room := _room_spec("needs_ticket", str(OnlineConfig.values()["free_tickets"][0]["id"]))
	var screen := _screen()
	var card: Button = await _wait_node(screen, "Card_%s" % str(ticket_room["id"]))
	await wait_seconds(0.2)
	assert_true((card.get_node("Lock") as Control).visible)
	card.pressed.emit()
	assert_false((screen.find_child("RoomView", true, false) as Control).visible, "錠のカードは開かない")
	assert_true((screen.find_child("Status", true, false) as Label).text.contains(str(OnlineConfig.free_ticket_name(str(ticket_room["needs_ticket"])))))
	# チケットが届くと、開けられる。
	screen.apply_ticket({"uid": OwnedPururins.uid(_first_pururin()), "ticket_id": str(ticket_room["needs_ticket"]), "name": "x", "expires_unix": 0})
	assert_false((card.get_node("Lock") as Control).visible)


func test_the_results_tab_and_the_room_results_show_the_saved_results() -> void:
	var ids := _free_ids()
	(_server.get("_results")["events"] as Array).append({"room_id": ids[0], "name": "テストの本戦", "distance_m": 2400.0, "start_unix": 1000, "semis": [],
		"final": [{"place": 1, "name": "U16", "pururin": "ヒカリ", "player": true, "time": 150.5}]})
	(_server.get("_results")["rooms"] as Dictionary)[ids[0]] = [{"unix": 1000, "room_id": ids[0], "name": "x", "distance_m": 1200.0, "stage": "",
		"rows": [{"place": 1, "name": "モモの人", "pururin": "モモ", "player": true, "time": 75.0}]}]
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	screen.show_tab(FreeLobby.TAB_RESULTS)
	var events: RichTextLabel = screen.find_child("EventsLog", true, false)
	assert_true(await _wait_until(func() -> bool: return events.get_parsed_text().contains("テストの本戦")))
	assert_true(events.get_parsed_text().contains("優勝　ヒカリ（U16）"))
	screen.show_tab(FreeLobby.TAB_ROOMS)
	screen.open_room(ids[0])
	screen.show_room_part(FreeLobby.PART_RESULTS)
	var log: RichTextLabel = screen.find_child("RoomResultsLog", true, false)
	assert_true(await _wait_until(func() -> bool: return log.get_parsed_text().contains("モモ（モモの人）")))
	assert_true(log.get_parsed_text().contains("1分15秒00"))


func test_leaving_the_lobby_with_entries_asks_first() -> void:
	var ids := _free_ids()
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	OnlineSession.client(get_tree()).send(Protocol.FREE_ENTRY, _entry_message(ids[0], _first_pururin()))
	OnlineSession.client(get_tree()).send(Protocol.FREE_HOLD, {"room_id": ids[0], "hold": true})
	assert_true(await _wait_until(func() -> bool: return (screen.get("_entries") as Array).size() == 1))
	screen.press_back()
	var dialog: Control = screen.find_child("ConfirmDialog", true, false)
	assert_true(dialog.visible, "エントリーがあれば、出る前に確かめる")
	assert_true((screen.find_child("ConfirmText", true, false) as Label).text.contains("1件"))
	assert_eq(get_viewport().gui_get_focus_owner(), screen.find_child("ConfirmNo", true, false), "うっかり出ないよう、はじめは「出ない」")
	(screen.find_child("ConfirmNo", true, false) as Button).pressed.emit()
	assert_false(dialog.visible)
	assert_eq((screen.get("_entries") as Array).size(), 1, "出ないなら、そのまま")


func test_a_lost_connection_offers_to_reconnect() -> void:
	var ids := _free_ids()
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	_server.stop()
	var dialog: Control = screen.find_child("ConfirmDialog", true, false)
	assert_true(await _wait_until(func() -> bool: return dialog.visible), "切れたら、つなぎ直すかを聞く")
	assert_eq((screen.find_child("ConfirmYes", true, false) as Button).text, "つなぎ直す")
	# サーバーを起動し直したのと同じにする（止めると、ルームの一覧も消えるため）。
	_server.call("_make_free_rooms")
	assert_eq(_server.listen(TEST_PORT), OK)
	(screen.find_child("ConfirmYes", true, false) as Button).pressed.emit()
	assert_true((screen.get("_rooms") as Array).is_empty(), "つなぎ直すときは、前のようすを消す")
	assert_true(await _wait_until(func() -> bool: return not (screen.get("_rooms") as Array).is_empty() and OnlineSession.in_lobby()), "つなぎ直して、ロビーに入り直す")


func test_pad_moves_reach_the_room_tabs_and_skip_the_chat_boxes() -> void:
	var ids := _free_ids()
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	for edit_name: String in ["LobbyChatEdit", "RoomChatEdit"]:
		assert_eq((screen.find_child(edit_name, true, false) as LineEdit).focus_mode, Control.FOCUS_CLICK, "方向キーでは入らない")
	var entry: Button = screen.find_child("EntryButton", true, false)
	assert_eq(entry.get_node(entry.focus_neighbor_left), screen.find_child("RoomResultsTab", true, false), "左で、下のタブへ")


func test_after_accepting_a_call_the_cursor_is_not_on_cancel() -> void:
	var ids := _free_ids()
	_server.set("fill_wait_s", 60.0)
	_server.set("answer_wait_s", 60.0)
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	screen.open_room(ids[0])
	(screen.find_child("EntryButton", true, false) as Button).pressed.emit()
	var panel: Control = screen.find_child("OfferPanel", true, false)
	assert_true(await _wait_until(func() -> bool: return panel.visible))
	screen.answer(true)
	assert_eq(get_viewport().gui_get_focus_owner(), screen.find_child("StatusButton", true, false))



func test_after_a_race_the_runner_rests_before_being_called_again() -> void:
	var ids := _free_ids()
	await _enter_free("a")
	_server.set("rest_after_race_s", 0.8)
	_enter_rooms("a", [ids[0]])
	await _accept_and_start("a")
	var room: int = (_server.get("_free_rooms")[ids[0]]["races"] as Array)[0]
	_server.call("_end_race", room)
	_server.call("_free_race_over", room)
	_clients["a"].send(Protocol.FREE_ENTER)
	var lobby := await _latest_lobby("a")
	assert_gt(float(lobby["rest_s"]), 0.0, "休んでいる残りの秒数が届く")
	assert_true((await _wait_for("a", Protocol.FREE_OFFER, 0.5)).is_empty(), "休んでいるあいだは呼ばない")
	assert_false((await _wait_for("a", Protocol.FREE_OFFER, 2.0)).is_empty(), "休み終わったら呼ぶ")


func test_the_server_button_opens_the_choice_and_switches_the_server() -> void:
	var ids := _free_ids()
	var screen := _screen()
	await _wait_node(screen, "Card_%s" % ids[0])
	(screen.find_child("ServerButton", true, false) as Button).pressed.emit()
	assert_true((screen.find_child("ServerDialog", true, false) as Control).visible)
	assert_true((screen.find_child("ServerCustom", true, false) as Button).button_pressed, "今の選び（自分で指定）が選ばれている")
	var edit: LineEdit = screen.find_child("ServerUrl", true, false)
	edit.text = "http://bad"
	screen.apply_server_choice()
	assert_true((screen.find_child("ServerDialog", true, false) as Control).visible, "正しくないURLでは、つながない")
	edit.text = "ws://127.0.0.1:%d" % TEST_PORT
	screen.apply_server_choice()
	assert_false((screen.find_child("ServerDialog", true, false) as Control).visible)
	assert_false((screen.find_child("ConfirmDialog", true, false) as Control).visible, "自分で替えたときは、切れたことを聞かない")
	assert_true(await _wait_until(func() -> bool: return not (screen.get("_rooms") as Array).is_empty()), "つなぎ直して、ロビーに入り直す")
