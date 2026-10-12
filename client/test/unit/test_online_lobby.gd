extends GutTest
## オンラインの部屋の画面：つないで部屋に入ると人の一覧が出る。つながらない・断られたときは、わけを出す。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const LobbyScene := preload("res://scenes/online_lobby.tscn")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
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


func test_online_config_names_a_server_and_a_timeout() -> void:
	assert_true(OnlineConfig.validate(OnlineConfig.values()).is_empty())
	assert_true(OnlineConfig.is_server_url(OnlineConfig.server_url()))
	assert_gt(OnlineConfig.connect_timeout_s(), 0.0)
	assert_true(OnlineConfig.is_server_url("wss://example.onrender.com"))
	assert_false(OnlineConfig.is_server_url("http://example.com"))
	assert_false(OnlineConfig.is_server_url("ws://"))
	assert_false(OnlineConfig.validate({"server_url": "http://x", "connect_timeout_s": 8.0}).is_empty())
	assert_false(OnlineConfig.validate({"server_url": "ws://x", "connect_timeout_s": 0.0}).is_empty())


func test_the_lobby_starts_with_the_configured_server_and_the_trainer_name() -> void:
	var lobby: Control = LobbyScene.instantiate()
	add_child_autofree(lobby)
	assert_eq((lobby.find_child("ServerEdit", true, false) as LineEdit).text, OnlineConfig.server_url())
	assert_true((lobby.find_child("NameLabel", true, false) as Label).text.contains(TrainerProfile.trainer_name()))
	# 部屋に入る前は、人の一覧を出さない。
	assert_eq(lobby.find_child("Members", true, false).get_child_count(), 0)


func test_joining_shows_the_people_in_the_room() -> void:
	var lobby := _lobby()
	(lobby.find_child("RoomEdit", true, false) as LineEdit).text = "テスト部屋"
	lobby.join()
	await _wait_until(func() -> bool: return lobby.find_child("Member1", true, false) != null)
	var first := lobby.find_child("Member1", true, false) as Label
	assert_not_null(first)
	assert_true(first.text.contains(TrainerProfile.trainer_name()))
	assert_true(first.text.contains("あなた"))
	assert_true(_status(lobby).contains("テスト部屋"))
	# もう1人が同じ合言葉で入ると、一覧が2人になる。
	var other: Node = OnlineClient.new()
	add_child_autofree(other)
	other.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(other.connected, WAIT_S)
	other.join_room("ミナト", "テスト部屋")
	await _wait_until(func() -> bool: return lobby.find_child("Member2", true, false) != null)
	assert_not_null(lobby.find_child("Member2", true, false))
	assert_false((lobby.find_child("Member2", true, false) as Label).text.contains("あなた"))
	assert_eq(_server.room_members("テスト部屋").size(), 2)


func test_an_empty_code_or_a_bad_server_is_explained_without_connecting() -> void:
	var lobby := _lobby()
	lobby.join()
	assert_true(_status(lobby).contains("合言葉"))
	(lobby.find_child("RoomEdit", true, false) as LineEdit).text = "部屋"
	(lobby.find_child("ServerEdit", true, false) as LineEdit).text = "http://127.0.0.1"
	lobby.join()
	assert_true(_status(lobby).contains("ws://"))
	assert_eq(_server.peer_count(), 0)


func test_a_missing_server_is_explained() -> void:
	_server.stop()
	var lobby := _lobby()
	(lobby.find_child("RoomEdit", true, false) as LineEdit).text = "部屋"
	lobby.join()
	await _wait_until(func() -> bool: return _status(lobby).contains("つながりません"), OnlineConfig.connect_timeout_s() + 2.0)
	assert_true(_status(lobby).contains("つながりません"))
	assert_null(lobby.find_child("Member1", true, false))


func test_the_host_picks_a_pururin_and_a_distance_and_can_then_start() -> void:
	var lobby := _lobby()
	(lobby.find_child("RoomEdit", true, false) as LineEdit).text = "選ぶ部屋"
	# 部屋に入る前は、選ぶ所を出さない。
	assert_false((lobby.find_child("RoomControls", true, false) as Control).visible)
	lobby.join()
	await _wait_until(func() -> bool: return lobby.find_child("Member1", true, false) != null)
	assert_true((lobby.find_child("RoomControls", true, false) as Control).visible)
	var start := lobby.find_child("StartButton", true, false) as Button
	# 1人目は、部屋の主。まだ選んでいないので、始められない。
	assert_true(lobby.is_host())
	assert_true(start.visible)
	assert_true(start.disabled)
	# ぷるりんを選ぶと、一覧に名前が出て、始められるようになる。
	var first_id := str(PururinRosterConfig.values()["roster"][0]["id"])
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == first_id)
	assert_eq(lobby.my_pururin_id(), first_id)
	assert_true((lobby.find_child("Member1", true, false) as Label).text.contains(lobby.pururin_name(first_id)))
	assert_false(start.disabled)
	# 距離を次へ替えると、サーバーの部屋の距離が変わる。
	var distances: Array = RaceSession.supported_distances_m()
	var before := distances.find(RaceSession.DEFAULT_DISTANCE_M)
	lobby.step_distance(1)
	var expected := "%d m" % int(float(distances[posmod(before + 1, distances.size())]))
	await _wait_until(func() -> bool: return (lobby.find_child("DistanceLabel", true, false) as Label).text == expected)
	assert_eq((lobby.find_child("DistanceLabel", true, false) as Label).text, expected)


func test_a_guest_cannot_start_and_skips_pururins_others_took() -> void:
	var host: Node = OnlineClient.new()
	add_child_autofree(host)
	host.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(host.connected, WAIT_S)
	host.join_room("主", "客の部屋")
	var first_id := str(PururinRosterConfig.values()["roster"][0]["id"])
	var second_id := str(PururinRosterConfig.values()["roster"][1]["id"])
	host.send(Protocol.PICK, {"pururin_id": first_id})
	await wait_seconds(0.3)
	var lobby := _lobby()
	(lobby.find_child("RoomEdit", true, false) as LineEdit).text = "客の部屋"
	lobby.join()
	await _wait_until(func() -> bool: return lobby.find_child("Member2", true, false) != null)
	# 2人目は、主ではない。開始のボタンは出ず、距離は替えられない。
	assert_false(lobby.is_host())
	assert_false((lobby.find_child("StartButton", true, false) as Button).visible)
	assert_true((lobby.find_child("DistanceNext", true, false) as Button).disabled)
	# 主が1体目を選んでいるので、「次へ」は2体目になる。
	lobby.step_pururin(1)
	await _wait_until(func() -> bool: return lobby.my_pururin_id() == second_id)
	assert_eq(lobby.my_pururin_id(), second_id)
