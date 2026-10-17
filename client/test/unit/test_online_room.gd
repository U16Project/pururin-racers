extends GutTest
## オンライン対戦の土台：サーバーにつなぐ・部屋を作る・部屋に入る・部屋の決めごと・出す・ひとこと・管理人。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")

## テスト用の入口の番号（本番の番号とは別にする）。
const TEST_PORT := Protocol.DEFAULT_PORT + 1000
const WAIT_S := 3.0

var _server: Node
var _inbox := {}
var _clients := {}


func before_each() -> void:
	_inbox = {}
	_clients = {}
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


## つないで、名乗って、部屋の一覧の所に入る。届いた lobby を返す。
func _enter_lobby(label: String) -> Dictionary:
	var client: Node = OnlineClient.new()
	add_child_autofree(client)
	_inbox[label] = []
	_clients[label] = client
	client.message_received.connect(func(data: Dictionary) -> void: (_inbox[label] as Array).append(data))
	assert_eq(client.connect_to("ws://127.0.0.1:%d" % TEST_PORT), OK)
	await wait_for_signal(client.connected, WAIT_S)
	client.hello(label)
	return await _wait_for(label, Protocol.LOBBY)


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


func _error(label: String) -> String:
	return str((await _wait_for(label, Protocol.ERROR)).get("code", ""))


## 部屋を作って、届いた welcome を返す。
func _create(label: String, room_name: String, password: String = "") -> Dictionary:
	_clients[label].create_room(room_name, password)
	return await _wait_for(label, Protocol.WELCOME)


func test_messages_carry_the_version_and_type() -> void:
	var data := Protocol.message(Protocol.HELLO, {"name": "ユウ"})
	assert_eq(int(data["v"]), Protocol.VERSION)
	assert_eq(Protocol.decode(Protocol.encode(data))["name"], "ユウ")
	# 読めない文・種類の無い文は、空で返す。
	assert_true(Protocol.decode("こんにちは").is_empty())
	assert_true(Protocol.decode("{\"v\": 1}").is_empty())
	# 名前は、空白を取り、上限で切る。
	assert_eq(Protocol.clean_text("  ユウ  ", Protocol.NAME_MAX_LENGTH), "ユウ")
	assert_eq(Protocol.clean_text("あ".repeat(Protocol.NAME_MAX_LENGTH + 5), Protocol.NAME_MAX_LENGTH).length(), Protocol.NAME_MAX_LENGTH)


func test_hello_answers_with_the_room_list_and_the_limit() -> void:
	var lobby := await _enter_lobby("a")
	assert_gt(int(lobby["peer_id"]), 0)
	assert_eq(int(lobby["max_rooms"]), OnlineConfig.max_rooms())
	assert_eq((lobby["rooms"] as Array).size(), 0)
	# 名乗る前は、部屋を作れない。
	var stranger: Node = OnlineClient.new()
	add_child_autofree(stranger)
	_inbox["x"] = []
	stranger.message_received.connect(func(data: Dictionary) -> void: (_inbox["x"] as Array).append(data))
	stranger.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(stranger.connected, WAIT_S)
	stranger.create_room("部屋")
	assert_eq(await _error("x"), Protocol.ERROR_NO_NAME)


func test_creating_a_room_makes_the_creator_the_host_and_lists_the_room() -> void:
	await _enter_lobby("a")
	var b_lobby := await _enter_lobby("b")
	var welcome := await _create("a", "朝の部屋", "ひみつ")
	assert_eq(str(welcome["room"]), "朝の部屋")
	assert_eq(int(welcome["host"]), int(welcome["peer_id"]))
	assert_true(bool(welcome["locked"]))
	assert_eq(int(welcome["field_size"]), Protocol.ROOM_CAPACITY)
	# 入るとまず、待機室。
	assert_eq(str(welcome["phase"]), Protocol.PHASE_LOBBY)
	assert_eq(int(welcome["capacity"]), Protocol.ROOM_CAPACITY)
	assert_false(welcome.has("password"), "パスワードそのものは、配らない")
	# 一覧を見ている人に、新しい部屋が届く。
	var rooms := await _wait_for("b", Protocol.ROOMS)
	assert_eq((rooms["rooms"] as Array).size(), 1)
	var listed: Dictionary = rooms["rooms"][0]
	assert_eq(str(listed["name"]), "朝の部屋")
	assert_eq(str(listed["host_name"]), "a")
	assert_eq(int(listed["count"]), 1)
	assert_true(bool(listed["locked"]))
	assert_false(bool(listed["racing"]))
	assert_eq(int(listed["capacity"]), Protocol.ROOM_CAPACITY)
	assert_eq(int(b_lobby["peer_id"]) != int(welcome["peer_id"]), true)


func test_peeking_a_listed_room_returns_its_host_description_and_people_without_joining() -> void:
	await _enter_lobby("host")
	await _enter_lobby("guest")
	_clients["host"].create_room("朝の部屋", "ひみつ", "  のんびり走ります  ")
	var welcome := await _wait_for("host", Protocol.WELCOME)
	assert_eq(str(welcome["description"]), "のんびり走ります", "前後の空白は取る")
	var room_id := int(welcome["room_id"])
	_clients["guest"].peek_room(room_id)
	var info := await _wait_for("guest", Protocol.ROOM_INFO)
	assert_eq(int(info["room_id"]), room_id)
	assert_eq(str(info["name"]), "朝の部屋")
	assert_eq(str(info["host_name"]), "host")
	assert_eq(str(info["description"]), "のんびり走ります")
	assert_eq(int(info["count"]), 1)
	assert_true(bool(info["locked"]))
	assert_true(info["host_icon"] is Dictionary)
	assert_false(info.has("password"), "パスワードそのものは返さない")
	# 見ただけでは、入らない。
	assert_eq(_server.room_members(room_id).size(), 1)
	_clients["guest"].peek_room(room_id + 99)
	assert_eq(await _error("guest"), Protocol.ERROR_NO_ROOM)


func test_the_description_is_cut_to_the_limit_and_only_the_host_changes_it() -> void:
	await _enter_lobby("host")
	await _enter_lobby("guest")
	_clients["host"].create_room("夜の部屋", "", "あ".repeat(Protocol.ROOM_DESCRIPTION_MAX_LENGTH + 20))
	var welcome := await _wait_for("host", Protocol.WELCOME)
	assert_eq(str(welcome["description"]).length(), Protocol.ROOM_DESCRIPTION_MAX_LENGTH)
	_clients["guest"].join_room(int(welcome["room_id"]))
	await _wait_for("guest", Protocol.WELCOME)
	_clients["guest"].send(Protocol.SETTINGS, {"description": "のっとり"})
	assert_eq(await _error("guest"), Protocol.ERROR_NOT_HOST)
	_clients["host"].send(Protocol.SETTINGS, {"description": "新しい紹介"})
	var room := await _wait_for("guest", Protocol.ROOM)
	while not room.is_empty() and str(room["description"]) != "新しい紹介":
		room = await _wait_for("guest", Protocol.ROOM)
	assert_eq(str(room.get("description", "")), "新しい紹介")


func test_joining_needs_the_password_and_a_free_place() -> void:
	await _enter_lobby("a")
	await _enter_lobby("b")
	await _enter_lobby("c")
	var welcome := await _create("a", "部屋", "ひみつ")
	var room_id := int(welcome["room_id"])
	_clients["b"].join_room(room_id, "ちがう")
	assert_eq(await _error("b"), Protocol.ERROR_WRONG_PASSWORD)
	_clients["b"].join_room(room_id + 99, "ひみつ")
	assert_eq(await _error("b"), Protocol.ERROR_NO_ROOM)
	_clients["b"].join_room(room_id, "ひみつ")
	var joined := await _wait_for("b", Protocol.WELCOME)
	assert_eq((joined["members"] as Array).size(), 2)
	# 入れる人数（8人）に達すると、それ以上は入れない。
	for index in Protocol.ROOM_CAPACITY - 2:
		var label := "x%d" % index
		await _enter_lobby(label)
		_clients[label].join_room(room_id, "ひみつ")
		await _wait_for(label, Protocol.WELCOME)
	_clients["c"].join_room(room_id, "ひみつ")
	assert_eq(await _error("c"), Protocol.ERROR_ROOM_FULL)


func test_rooms_are_limited_and_names_are_unique() -> void:
	var limit := OnlineConfig.max_rooms()
	for index in limit + 1:
		await _enter_lobby("p%d" % index)
	for index in limit:
		assert_false((await _create("p%d" % index, "部屋%d" % index)).is_empty())
	assert_eq(_server.room_count(), limit)
	_clients["p%d" % limit].create_room("もう1つ")
	assert_eq(await _error("p%d" % limit), Protocol.ERROR_ROOMS_FULL)
	# 同じ名前の部屋は、作れない。自分しかいない部屋からなら、作り直せる（その部屋が消えるので）。
	_clients["p0"].create_room("部屋1")
	assert_eq(await _error("p0"), Protocol.ERROR_ROOM_NAME_TAKEN)
	assert_false((await _create("p0", "作り直し")).is_empty())
	assert_eq(_server.room_count(), limit)


func test_only_the_host_changes_the_room_settings() -> void:
	await _enter_lobby("a")
	await _enter_lobby("b")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_clients["b"].send(Protocol.SETTINGS, {"password": "かぎ"})
	assert_eq(await _error("b"), Protocol.ERROR_NOT_HOST)
	_inbox["b"].clear()
	_inbox["a"].clear()
	# 待機室では、パスワードと紹介だけ変えられる。距離・席は、レース設定でだけ。
	_clients["a"].send(Protocol.SETTINGS, {"password": "かぎ"})
	var room := await _wait_for("b", Protocol.ROOM)
	assert_true(bool(room["locked"]))
	# パスワードそのものは、主にだけ届く（確かめて、変えられるように）。ほかの人には、あるかどうかだけ。
	assert_false(room.has("password"))
	assert_eq(str((await _wait_for("a", Protocol.ROOM)).get("password", "")), "かぎ")
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": RaceSession.supported_distances_m()[0]})
	assert_eq(await _error("a"), Protocol.ERROR_WRONG_PHASE)
	# レース設定では、選べない距離は断る（ほかの項目も変えない）。
	_clients["a"].send(Protocol.RACE_OPEN)
	await _wait_for("a", Protocol.ROOM)
	var distance_before := float(_server.call("_room_fields", int(welcome["room_id"]))["distance_m"])
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": 123.0, "password": ""})
	assert_eq(await _error("a"), Protocol.ERROR_BAD_MESSAGE)
	var fields: Dictionary = _server.call("_room_fields", int(welcome["room_id"]))
	assert_almost_eq(float(fields["distance_m"]), distance_before, 0.001)
	assert_true(bool(fields["locked"]))


func test_the_host_can_put_a_person_out_and_that_person_returns_to_the_list() -> void:
	await _enter_lobby("a")
	var b_lobby := await _enter_lobby("b")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_clients["b"].send(Protocol.KICK, {"peer_id": int(welcome["peer_id"])})
	assert_eq(await _error("b"), Protocol.ERROR_NOT_HOST)
	_inbox["b"].clear()
	_clients["a"].send(Protocol.KICK, {"peer_id": int(b_lobby["peer_id"])})
	assert_eq(str((await _wait_for("b", Protocol.KICKED))["by"]), Protocol.KICKED_BY_HOST)
	assert_false((await _wait_for("b", Protocol.LOBBY)).is_empty())
	assert_eq(_server.room_members(int(welcome["room_id"])).size(), 1)


func test_when_the_host_leaves_the_next_person_becomes_the_host_and_an_empty_room_closes() -> void:
	await _enter_lobby("a")
	var b_lobby := await _enter_lobby("b")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_inbox["b"].clear()
	_clients["a"].send(Protocol.LEAVE)
	assert_false((await _wait_for("a", Protocol.LOBBY)).is_empty())
	var room := await _wait_for("b", Protocol.ROOM)
	assert_eq(int(room["host"]), int(b_lobby["peer_id"]))
	_clients["b"].send(Protocol.LEAVE)
	await _wait_for("b", Protocol.LOBBY)
	assert_eq(_server.room_count(), 0)


func test_chat_reaches_everyone_in_the_room_and_is_cut_to_the_limit() -> void:
	await _enter_lobby("a")
	await _enter_lobby("b")
	await _enter_lobby("c")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_clients["b"].send(Protocol.CHAT, {"text": "よ".repeat(OnlineConfig.chat_max_length() + 10)})
	var heard := await _wait_for("a", Protocol.CHAT_MESSAGE)
	assert_eq(str(heard["name"]), "b")
	assert_eq(str(heard["text"]).length(), OnlineConfig.chat_max_length())
	assert_false((await _wait_for("b", Protocol.CHAT_MESSAGE)).is_empty(), "送った本人にも届く")
	# 部屋の外の人には、届かない。部屋に入っていない人は、送れない。
	assert_true(_inbox["c"].filter(func(data: Dictionary) -> bool: return str(data["t"]) == Protocol.CHAT_MESSAGE).is_empty())
	_clients["c"].send(Protocol.CHAT, {"text": "やあ"})
	assert_eq(await _error("c"), Protocol.ERROR_NOT_IN_ROOM)


func test_the_administrator_lists_rooms_puts_people_out_and_closes_rooms() -> void:
	await _enter_lobby("admin")
	var a_lobby := await _enter_lobby("a")
	await _enter_lobby("b")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	# 合い札が設定されていないサーバーでは、何もできない。違う合い札も、断る。
	_clients["admin"].send(Protocol.ADMIN, {"token": "", "command": Protocol.ADMIN_LIST})
	assert_eq(await _error("admin"), Protocol.ERROR_NOT_ADMIN)
	_server.admin_token = "あいふだ"
	_clients["admin"].send(Protocol.ADMIN, {"token": "ちがう", "command": Protocol.ADMIN_LIST})
	assert_eq(await _error("admin"), Protocol.ERROR_NOT_ADMIN)
	_clients["admin"].send(Protocol.ADMIN, {"token": "あいふだ", "command": Protocol.ADMIN_LIST})
	var listed := await _wait_for("admin", Protocol.ADMIN_RESULT)
	assert_eq((listed["rooms"] as Array).size(), 1)
	assert_eq((listed["rooms"][0]["members"] as Array).size(), 2)
	# 部屋の主でも、出せる。
	_clients["admin"].send(Protocol.ADMIN, {"token": "あいふだ", "command": Protocol.ADMIN_KICK, "peer_id": int(a_lobby["peer_id"])})
	assert_eq(str((await _wait_for("a", Protocol.KICKED))["by"]), Protocol.KICKED_BY_ADMIN)
	assert_true(bool((await _wait_for("admin", Protocol.ADMIN_RESULT))["done"]))
	assert_eq(_server.room_members(int(welcome["room_id"])).size(), 1)
	# 部屋を閉じると、中の人は一覧の所へ戻り、部屋は消える。
	_inbox["b"].clear()
	_clients["admin"].send(Protocol.ADMIN, {"token": "あいふだ", "command": Protocol.ADMIN_CLOSE, "room_id": int(welcome["room_id"])})
	assert_false((await _wait_for("b", Protocol.KICKED)).is_empty())
	assert_false((await _wait_for("b", Protocol.LOBBY)).is_empty())
	assert_eq(_server.room_count(), 0)


func test_profiles_reach_people_in_the_same_room_only() -> void:
	await _enter_lobby("a")
	await _enter_lobby("b")
	var c_lobby := await _enter_lobby("c")
	# a は、自己紹介と、自分で入れた画像を名乗り直す。
	_clients["a"].hello("a", "よろしく。", {"kind": "file", "id": "", "image": "QUJD"})
	var a_lobby := await _wait_for("a", Protocol.LOBBY)
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_clients["b"].send(Protocol.PROFILE, {"peer_id": int(a_lobby["peer_id"])})
	var info := await _wait_for("b", Protocol.PROFILE_INFO)
	assert_eq(str(info["name"]), "a")
	assert_eq(str(info["introduction"]), "よろしく。")
	assert_eq([str(info["icon"]["kind"]), str(info["icon"]["image"])], ["file", "QUJD"])
	# 同じ部屋にいない人のことは、聞けない。部屋に入っていない人は、聞けない。
	_clients["b"].send(Protocol.PROFILE, {"peer_id": int(c_lobby["peer_id"])})
	assert_eq(await _error("b"), Protocol.ERROR_BAD_MESSAGE)
	_clients["c"].send(Protocol.PROFILE, {"peer_id": int(a_lobby["peer_id"])})
	assert_eq(await _error("c"), Protocol.ERROR_NOT_IN_ROOM)


func test_bad_or_oversized_icons_become_no_icon() -> void:
	assert_eq(str(OnlineServer.clean_icon("x")["kind"]), "none")
	assert_eq(str(OnlineServer.clean_icon({"kind": "movie"})["kind"]), "none")
	assert_eq(str(OnlineServer.clean_icon({"kind": "file", "image": ""})["kind"]), "none")
	assert_eq(str(OnlineServer.clean_icon({"kind": "file", "image": "あ".repeat(Protocol.ICON_IMAGE_MAX_CHARS + 1)})["kind"]), "none")
	var avatar := OnlineServer.clean_icon({"kind": "avatar", "id": "avatar-3", "image": "QUJD"})
	assert_eq([str(avatar["kind"]), str(avatar["id"]), str(avatar["image"])], ["avatar", "avatar-3", ""], "用意された絵には、画像を付けない")


func test_everyone_in_the_room_is_told_who_came_who_left_and_who_became_the_host() -> void:
	await _enter_lobby("a")
	var b_lobby := await _enter_lobby("b")
	await _enter_lobby("c")
	var welcome := await _create("a", "部屋")
	var room_id := int(welcome["room_id"])
	_clients["b"].join_room(room_id)
	await _wait_for("b", Protocol.WELCOME)
	# 入ったことは、先にいた人に届く。
	var joined := await _wait_for("a", Protocol.NOTICE)
	assert_eq([str(joined["kind"]), str(joined["name"])], [Protocol.NOTICE_JOINED, "b"])
	_clients["c"].join_room(room_id)
	await _wait_for("c", Protocol.WELCOME)
	_inbox["a"].clear()
	_inbox["b"].clear()
	# 主が、c を退出させる：残った全員に、だれが・だれによって、が届く。
	var c_id := 0
	for member: Dictionary in _server.room_members(room_id):
		if str(member["name"]) == "c":
			c_id = int(member["peer_id"])
	_clients["a"].send(Protocol.KICK, {"peer_id": c_id})
	for label: String in ["a", "b"]:
		var kicked := await _wait_for(label, Protocol.NOTICE)
		assert_eq([str(kicked["kind"]), str(kicked["name"]), str(kicked["by"])], [Protocol.NOTICE_KICKED, "c", Protocol.KICKED_BY_HOST], label)
	# 主が部屋を出る：残った人に、出たことと、新しい主が届く。
	_clients["a"].send(Protocol.LEAVE)
	var left := await _wait_for("b", Protocol.NOTICE)
	assert_eq([str(left["kind"]), str(left["name"])], [Protocol.NOTICE_LEFT, "a"])
	var host := await _wait_for("b", Protocol.NOTICE)
	assert_eq([str(host["kind"]), str(host["name"])], [Protocol.NOTICE_HOST, "b"])
	assert_eq(int(_server.call("_room_fields", room_id)["host"]), int(b_lobby["peer_id"]))


func test_a_dropped_connection_is_told_apart_from_leaving() -> void:
	await _enter_lobby("a")
	await _enter_lobby("b")
	var welcome := await _create("a", "部屋")
	_clients["b"].join_room(int(welcome["room_id"]))
	await _wait_for("b", Protocol.WELCOME)
	_inbox["a"].clear()
	_clients["b"].disconnect_from_server()
	var notice := await _wait_for("a", Protocol.NOTICE)
	assert_eq([str(notice["kind"]), str(notice["name"])], [Protocol.NOTICE_DISCONNECTED, "b"])
