extends GutTest
## オンライン対戦の土台：サーバーにつなぐ・合言葉の部屋に入る・部屋の人の一覧が届く。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineClient := preload("res://scripts/online/online_client.gd")

## テスト用の入口の番号（本番の番号とは別にする）。
const TEST_PORT := Protocol.DEFAULT_PORT + 1000
const WAIT_S := 3.0

var _server: Node
var _inbox := {}


func before_each() -> void:
	_inbox = {}
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


func _client(label: String) -> Node:
	var client: Node = OnlineClient.new()
	add_child_autofree(client)
	_inbox[label] = []
	client.message_received.connect(func(data: Dictionary) -> void: (_inbox[label] as Array).append(data))
	assert_eq(client.connect_to("ws://127.0.0.1:%d" % TEST_PORT), OK)
	return client


## その人に、その種類の文が届くまで待って、届いた文を返す（届かなければ空）。
func _wait_for(label: String, type: String) -> Dictionary:
	var waited := 0.0
	while waited < WAIT_S:
		for data: Dictionary in _inbox[label]:
			if str(data["t"]) == type:
				(_inbox[label] as Array).erase(data)
				return data
		await wait_seconds(0.05)
		waited += 0.05
	return {}


func test_messages_carry_the_version_and_type() -> void:
	var data := Protocol.message(Protocol.HELLO, {"name": "ユウ", "room": "abc"})
	assert_eq(int(data["v"]), Protocol.VERSION)
	assert_eq(Protocol.decode(Protocol.encode(data))["room"], "abc")
	# 読めない文・種類の無い文は、空で返す。
	assert_true(Protocol.decode("こんにちは").is_empty())
	assert_true(Protocol.decode("{\"v\": 1}").is_empty())
	# 名前と合言葉は、空白を取り、上限で切る。
	assert_eq(Protocol.clean_text("  ユウ  ", Protocol.NAME_MAX_LENGTH), "ユウ")
	assert_eq(Protocol.clean_text("あ".repeat(Protocol.NAME_MAX_LENGTH + 5), Protocol.NAME_MAX_LENGTH).length(), Protocol.NAME_MAX_LENGTH)


func test_joining_a_room_answers_with_the_members() -> void:
	var client := _client("a")
	await wait_for_signal(client.connected, WAIT_S)
	assert_true(client.is_open())
	assert_true(client.join_room("ユウ", "合言葉"))
	var welcome := await _wait_for("a", Protocol.WELCOME)
	assert_eq(str(welcome.get("room", "")), "合言葉")
	assert_eq(int(welcome.get("capacity", 0)), Protocol.ROOM_CAPACITY)
	assert_eq((welcome.get("members", []) as Array).size(), 1)
	assert_eq(str(welcome["members"][0]["name"]), "ユウ")
	assert_eq(int(welcome["members"][0]["peer_id"]), int(welcome["peer_id"]))


func test_people_with_the_same_code_meet_and_others_do_not() -> void:
	var a := _client("a")
	var b := _client("b")
	var c := _client("c")
	await wait_for_signal(c.connected, WAIT_S)
	a.join_room("アオ", "部屋1")
	assert_false((await _wait_for("a", Protocol.WELCOME)).is_empty())
	b.join_room("ベニ", "部屋1")
	assert_false((await _wait_for("b", Protocol.WELCOME)).is_empty())
	c.join_room("チャ", "部屋2")
	assert_false((await _wait_for("c", Protocol.WELCOME)).is_empty())
	# 先に入っていた人にも、2人になった一覧が届く。
	var names: Array = []
	var waited := 0.0
	while names.size() < 2 and waited < WAIT_S:
		var update := await _wait_for("a", Protocol.ROOM)
		names = (update.get("members", []) as Array).map(func(member: Dictionary) -> String: return str(member["name"]))
		waited += 0.5
	assert_eq(names, ["アオ", "ベニ"])
	assert_eq(_server.room_members("部屋1").size(), 2)
	assert_eq(_server.room_members("部屋2").size(), 1)


func test_leaving_tells_the_rest_of_the_room() -> void:
	var a := _client("a")
	var b := _client("b")
	await wait_for_signal(b.connected, WAIT_S)
	a.join_room("アオ", "部屋")
	await _wait_for("a", Protocol.WELCOME)
	b.join_room("ベニ", "部屋")
	await _wait_for("b", Protocol.WELCOME)
	b.disconnect_from_server()
	var waited := 0.0
	while _server.room_members("部屋").size() > 1 and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_eq(_server.room_members("部屋").size(), 1)
	assert_eq(str(_server.room_members("部屋")[0]["name"]), "アオ")


func test_a_full_room_turns_the_next_person_away() -> void:
	var last: Node
	for index in Protocol.ROOM_CAPACITY:
		last = _client("p%d" % index)
	await wait_for_signal(last.connected, WAIT_S)
	for index in Protocol.ROOM_CAPACITY:
		get_child(get_child_count() - Protocol.ROOM_CAPACITY + index).join_room("人%d" % index, "満員")
		assert_false((await _wait_for("p%d" % index, Protocol.WELCOME)).is_empty())
	var extra := _client("extra")
	await wait_for_signal(extra.connected, WAIT_S)
	extra.join_room("あふれ", "満員")
	var refused := await _wait_for("extra", Protocol.ERROR)
	assert_eq(str(refused.get("code", "")), Protocol.ERROR_ROOM_FULL)
	assert_eq(_server.room_members("満員").size(), Protocol.ROOM_CAPACITY)


func test_bad_messages_are_refused_without_dropping_the_connection() -> void:
	var client := _client("a")
	await wait_for_signal(client.connected, WAIT_S)
	# 合言葉が空。
	client.join_room("ユウ", "   ")
	assert_eq(str((await _wait_for("a", Protocol.ERROR)).get("code", "")), Protocol.ERROR_BAD_MESSAGE)
	# 知らない種類。
	client.send("知らない種類")
	assert_eq(str((await _wait_for("a", Protocol.ERROR)).get("code", "")), Protocol.ERROR_BAD_MESSAGE)
	# そのあとも、ふつうに使える。
	client.send(Protocol.PING, {"client_ts": 42})
	assert_eq(int((await _wait_for("a", Protocol.PONG)).get("client_ts", 0)), 42)
	assert_true(client.is_open())
