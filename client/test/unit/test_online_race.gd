extends GutTest
## オンラインのレース：待機室でレース開始 → レース設定（距離・席）→ ぷるりんを選ぶ、サーバーがレースを走らせて状態を配る、通信ごしの操作が走者に効く、着順が届く。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineServer := preload("res://scripts/online/online_server.gd")
const OnlineClient := preload("res://scripts/online/online_client.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")

const TEST_PORT := Protocol.DEFAULT_PORT + 1002
const WAIT_S := 3.0
## スタート前の待ち時間を早送りする倍率（テストを短くするため）。
const FAST_FORWARD := 6.0

var _server: Node
var _inbox := {}
var _clients := {}
## 部屋の名前 → サーバーが付けた部屋の番号。
var _room_ids := {}
var _course_only_before := false


func before_each() -> void:
	_inbox = {}
	_clients = {}
	_room_ids = {}
	_course_only_before = RaceSession.is_course_only()
	_server = OnlineServer.new()
	_server.listen_on_ready = false
	add_child_autofree(_server)
	assert_eq(_server.listen(TEST_PORT), OK)


func after_each() -> void:
	Engine.time_scale = 1.0
	RaceSession.set_course_only(_course_only_before)
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	OnlineSession.close()


func _roster_ids() -> Array:
	return (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))


## つないで、部屋に入る。返すのは、その人の番号。
func _enter(label: String, room: String) -> int:
	var client: Node = OnlineClient.new()
	add_child_autofree(client)
	_clients[label] = client
	_inbox[label] = []
	client.message_received.connect(func(data: Dictionary) -> void: (_inbox[label] as Array).append(data))
	assert_eq(client.connect_to("ws://127.0.0.1:%d" % TEST_PORT), OK)
	await wait_for_signal(client.connected, WAIT_S)
	client.hello(label)
	await _wait_for(label, Protocol.LOBBY)
	# その名前の部屋が無ければ作り（作った人が主）、あれば入る。
	if _room_ids.has(room):
		client.join_room(int(_room_ids[room]))
	else:
		client.create_room(room)
	var welcome := await _wait_for(label, Protocol.WELCOME)
	_room_ids[room] = int(welcome.get("room_id", 0))
	return int(welcome.get("peer_id", 0))


## その人に、その種類の文が届くまで待って、いちばん新しいものを返す（届かなければ空）。
func _wait_for(label: String, type: String, max_s: float = WAIT_S) -> Dictionary:
	var waited := 0.0
	while waited < max_s * Engine.time_scale:
		var inbox: Array = _inbox[label]
		for index in range(inbox.size() - 1, -1, -1):
			if str(inbox[index]["t"]) == type:
				var found: Dictionary = inbox[index]
				# 見つけた文までを捨てる（そのあとに届いた文は、残す）。
				for _removed in index + 1:
					inbox.pop_front()
				return found
		await wait_seconds(0.05)
		waited += 0.05
	return {}


## 待機室：readies が準備OKを押し、主がレース開始を押して、レース設定へ進む。
func _open_settings(host: String, readies: Array) -> void:
	for label: String in readies:
		_clients[label].set_lobby_ready(true)
	await wait_seconds(0.2)
	_clients[host].send(Protocol.RACE_OPEN)
	await wait_seconds(0.2)


## 待機室からレース設定を通って、ぷるりんを選ぶ所まで進める。seats を渡すと、人の足りない席を、その並びにする。
func _open_race(host: String, readies: Array, seats: Array = []) -> void:
	await _open_settings(host, readies)
	if not seats.is_empty():
		_clients[host].send(Protocol.SETTINGS, {"seats": seats})
		await wait_seconds(0.2)
	_clients[host].send(Protocol.PICK_OPEN)
	await wait_seconds(0.2)


## 部屋の全員が確定 → 主が出走表へ → 全員が確定 → 主がレース開始、までを進める。
func _go(host: String, labels: Array) -> void:
	for label: String in labels:
		_clients[label].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_clients[host].send(Protocol.ENTRIES)
	await wait_seconds(0.2)
	for label: String in labels:
		_clients[label].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_clients[host].send(Protocol.START)


func _error_code(label: String) -> String:
	return str((await _wait_for(label, Protocol.ERROR)).get("code", ""))


func test_entries_put_people_first_and_fill_the_rest_with_cpu() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	await _open_race("a", ["b"])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[2]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	var entries: Array = _server.build_entries(_room_ids["部屋"])
	assert_eq(entries.size(), mini(RaceSession.SLOT_COUNT, ids.size()))
	# 人は、レース開始のときの並びで1枠から。名前は、その人の名前。
	assert_eq([int(entries[0]["peer_id"]), str(entries[0]["id"]), str(entries[0]["trainer_name"])], [a, ids[2], "a"])
	assert_eq([int(entries[1]["peer_id"]), str(entries[1]["id"]), str(entries[1]["trainer_name"])], [b, ids[0], "b"])
	var seen := {}
	for index in entries.size():
		var entry: Dictionary = entries[index]
		assert_eq(int(entry["gate"]), index)
		assert_false(seen.has(str(entry["id"])), "同じ個体が2回出ない")
		seen[str(entry["id"])] = true
		# 3枠目からは、CPU。
		if index >= 2:
			assert_eq(int(entry["peer_id"]), 0)
			assert_false(bool(entry["player"]))


func test_picking_distance_and_starting_follow_the_room_rules() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _enter("b", "部屋")
	# 待機室では、距離も席も変えられない。レース開始も、主だけ。
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": RaceSession.supported_distances_m()[0]})
	assert_eq(await _error_code("a"), Protocol.ERROR_WRONG_PHASE)
	_clients["b"].send(Protocol.RACE_OPEN)
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	await _open_settings("a", ["b"])
	# 距離を決めるのも、始めるのも、部屋の主（最初に入った人）だけ。
	var distances: Array = RaceSession.supported_distances_m()
	_clients["b"].send(Protocol.SETTINGS, {"distance_m": distances[0]})
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": distances[0]})
	assert_almost_eq(float((await _wait_for("b", Protocol.ROOM)).get("distance_m", 0.0)), float(distances[0]), 0.001)
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": 777.0})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# レース設定では、まだ選べない。
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	assert_eq(await _error_code("a"), Protocol.ERROR_WRONG_PHASE)
	_clients["b"].send(Protocol.PICK_OPEN)
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	_clients["a"].send(Protocol.PICK_OPEN)
	await wait_seconds(0.2)
	# 知らない個体は、選べない。
	_clients["a"].send(Protocol.PICK, {"pururin_id": "いない個体"})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# ほかの人と同じプルでも選べる。
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("a", Protocol.ROOM)
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await wait_seconds(0.2)
	var picked: Array = _server.room_members(_room_ids["部屋"]).map(func(member: Dictionary) -> String: return str(member["pururin_id"]))
	assert_eq(picked, [ids[1], ids[1]])
	_clients["b"].send(Protocol.START)
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	# まだ確定していない人がいると、パドックへ進めない。パドックでないと、始められない。
	_clients["a"].send(Protocol.ENTRIES)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_CONFIRMED)
	_clients["a"].send(Protocol.START)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_IN_ENTRIES)
	assert_null(_server.room_race(_room_ids["部屋"]))


func test_only_ready_people_go_to_the_race_and_the_rest_stay_in_the_waiting_room() -> void:
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	var c := await _enter("c", "部屋")
	var room_id: int = _room_ids["部屋"]
	assert_eq(str(_server.call("_room_fields", room_id)["phase"]), Protocol.PHASE_LOBBY)
	_inbox["c"].clear()
	await _open_settings("a", ["b"])
	# 主と、準備OKの b だけが、レースに出る。c は、待機室に残る。全員に、レース開始の知らせが届く。
	var fields: Dictionary = _server.call("_room_fields", room_id)
	assert_eq(str(fields["phase"]), Protocol.PHASE_SETTINGS)
	assert_eq(fields["racers"], [a, b])
	var notice := await _wait_for("c", Protocol.NOTICE)
	assert_eq(str(notice["kind"]), Protocol.NOTICE_RACE_OPEN)
	# 人の足りない席は、はじめは全部CPU。席の数は、8 − レースに出る人数。
	assert_eq((fields["seats"] as Array).size(), Protocol.ROOM_CAPACITY - 2)
	assert_eq(int(fields["field_size"]), Protocol.ROOM_CAPACITY)
	# 残った人は、選べない。席の並びが合わない設定は、断る。
	_clients["c"].send(Protocol.PICK, {"pururin_id": _roster_ids()[0]})
	assert_eq(await _error_code("c"), Protocol.ERROR_NOT_RACER)
	_clients["a"].send(Protocol.SETTINGS, {"seats": [true]})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# 主でない人の「戻る」は、自分だけレースを抜けて、待機室へ。空いた席は、CPUの席として足す。
	_clients["b"].send(Protocol.BACK)
	await wait_seconds(0.2)
	fields = _server.call("_room_fields", room_id)
	assert_eq(fields["racers"], [a])
	assert_eq((fields["seats"] as Array).size(), Protocol.ROOM_CAPACITY - 1)
	assert_eq(str(fields["phase"]), Protocol.PHASE_SETTINGS)
	# 主が「戻る」と、待機室へ。レースに出る人も、準備OKも、解ける。
	_clients["a"].send(Protocol.BACK)
	await wait_seconds(0.2)
	fields = _server.call("_room_fields", room_id)
	assert_eq(str(fields["phase"]), Protocol.PHASE_LOBBY)
	assert_eq((fields["racers"] as Array).size(), 0)
	assert_false(bool(_server.room_members(room_id)[1]["ready"]))
	assert_gt(b + c, 0)


func test_the_server_runs_the_race_and_remote_input_moves_the_runners() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	await _open_settings("a", ["b"])
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": RaceSession.supported_distances_m()[0]})
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.PICK_OPEN)
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	await _go("a", ["a", "b"])
	var start := await _wait_for("b", Protocol.RACE_START)
	assert_eq((start.get("entries", []) as Array).size(), mini(RaceSession.SLOT_COUNT, ids.size()))
	assert_almost_eq(float(start.get("distance_m", 0.0)), float(RaceSession.supported_distances_m()[0]), 0.001)
	var race: Node = _server.room_race(_room_ids["部屋"])
	assert_not_null(race)
	# 全員のレースの画面ができるまで、スタートへ向かう時計は止まっている。
	assert_true(bool(race.call("is_start_held")))
	var wait_before := float(race.get("_entry_wait_remaining"))
	_clients["a"].send(Protocol.READY)
	await wait_seconds(0.4)
	assert_true(bool(race.call("is_start_held")), "1人だけでは、まだ始まらない")
	assert_almost_eq(float(race.get("_entry_wait_remaining")), wait_before, 0.0001)
	assert_true(bool((await _wait_for("a", Protocol.RACE_STATE)).get("hold", false)))
	_clients["b"].send(Protocol.READY)
	await wait_seconds(0.4)
	assert_false(bool(race.call("is_start_held")), "全員そろったら、動き出す")
	# サーバーの上のレースには、「この画面の自分」はいない。人の走者は、通信で動かす。
	assert_null(race.get("_player"))
	var runner_a: Node3D = race.call("remote_runner", a)
	var runner_b: Node3D = race.call("remote_runner", b)
	assert_true(bool(runner_a.get("remote_controlled")))
	assert_true(bool(runner_a.get("player_controlled")))
	# サーバーには画面が無いので、見た目だけの処理（表情・体の動き・カメラ・画面の部品）は止めてある。走りの計算は、そのまま。
	for runner in race.get("_runners"):
		assert_false(bool(runner.get("presentation_enabled")))
		assert_eq(runner.get_node("Body").process_mode, Node.PROCESS_MODE_DISABLED)
		assert_true(runner.is_processing())
	assert_eq(race.get_node("UI").process_mode, Node.PROCESS_MODE_DISABLED)
	# このPCをサーバーにしたとき、つないであるゲームパッドの操作を、サーバーの上のレースは受け取らない。
	assert_false(race.is_processing_unhandled_input())
	# スタートまで（入場の待ちとカウントダウン）を早送りする。
	Engine.time_scale = FAST_FORWARD
	var waited := 0.0
	while not bool(race.call("is_race_started")) and waited < 30.0 * FAST_FORWARD:
		await wait_seconds(0.2)
		waited += 0.2
	Engine.time_scale = 1.0
	assert_true(bool(race.call("is_race_started")))
	# 状態が届く。全員ぶん入っている（スタートの直前に配られたものが残っていることがあるので、スタート後のものを待つ）。
	var state := {}
	for _attempt in 20:
		state = await _wait_for("b", Protocol.RACE_STATE)
		if bool(state.get("started", false)):
			break
		await wait_seconds(0.1)
	assert_true(bool(state.get("started", false)))
	assert_eq((state.get("runners", []) as Array).size(), (start["entries"] as Array).size())
	# a がラインを動かし、b がノッチを上げる。a がダッシュを押す。
	# 枠順はくじなので、a が端の枠にいても動けるように、コースのまん中へ向かって動かす。
	var offset_before := float(runner_a.get("_offset"))
	var toward_center := -1.0 if offset_before > 0.0 else 1.0
	var notch_before := float(runner_b.call("get_drive_level"))
	_clients["a"].send(Protocol.INPUT, {"line": toward_center, "notch": 0.0, "brake": false})
	_clients["b"].send(Protocol.INPUT, {"line": 0.0, "notch": 1.0, "brake": false})
	_clients["a"].send(Protocol.ACTION, {"kind": Protocol.ACTION_DASH})
	await wait_seconds(0.6)
	# 届いた操作が、a の走者に入っている。枠順はくじなので、となりの走者にふさがれたり、押されたりして、
	# 思った向きに動けないことがある。動いた向きまでは、確かめない。
	assert_almost_eq(float(runner_a.get("_remote_line")), toward_center, 0.0001)
	assert_gt(float(runner_b.call("get_drive_level")), notch_before)
	assert_true(bool(runner_a.call("is_dash_active")))
	assert_gt(float(runner_a.call("get_race_progress")), 0.0)
	# 配られた状態にも、ダッシュ中であることが出る。
	state = await _wait_for("b", Protocol.RACE_STATE)
	var dashing := false
	for runner_state: Dictionary in state["runners"]:
		if str(runner_state["id"]) == ids[0]:
			dashing = float(runner_state["dash_ratio"]) > 0.0
	assert_true(dashing)
	# レースが終わると、着順が届く（1回だけ）。サーバーは、そのあとも、しばらくレースを走らせ続けて、位置を配る。
	race.set("_race_over", true)
	var result := await _wait_for("a", Protocol.RACE_RESULT)
	assert_eq((result.get("rows", []) as Array).size(), (start["entries"] as Array).size())
	_inbox["a"].clear()
	await wait_seconds(0.4)
	assert_not_null(_server.room_race(_room_ids["部屋"]), "結果のあとも、レースは片づけない")
	assert_false((await _wait_for("a", Protocol.RACE_STATE)).is_empty(), "結果のあとも、位置が届く")
	assert_true(_inbox["a"].filter(func(data: Dictionary) -> bool: return str(data["t"]) == Protocol.RACE_RESULT).is_empty(), "結果は、1回だけ")
	# 1人が見終わっただけでは、片づけない。全員が見終わると、片づけて、部屋に戻す。
	_clients["a"].send(Protocol.RACE_DONE)
	await wait_seconds(0.3)
	assert_not_null(_server.room_race(_room_ids["部屋"]))
	_clients["b"].send(Protocol.RACE_DONE)
	assert_false((await _wait_for("a", Protocol.RACE_END)).is_empty())
	assert_null(_server.room_race(_room_ids["部屋"]))
	assert_false(bool((await _wait_for("a", Protocol.ROOM)).get("racing", true)))


func test_nobody_picks_while_racing_and_a_late_comer_waits_in_the_waiting_room() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _open_race("a", [])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("a", Protocol.ROOM)
	await _go("a", ["a"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[1]})
	assert_eq(await _error_code("a"), Protocol.ERROR_RACING)
	# あとから来た人も、レース中の部屋に入れる。待機室で待ち、レースの文は届かない。
	var late: Node = OnlineClient.new()
	add_child_autofree(late)
	_inbox["late"] = []
	late.message_received.connect(func(data: Dictionary) -> void: (_inbox["late"] as Array).append(data))
	late.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(late.connected, WAIT_S)
	late.hello("late")
	await _wait_for("late", Protocol.LOBBY)
	late.join_room(int(_room_ids["部屋"]))
	var welcome := await _wait_for("late", Protocol.WELCOME)
	assert_true(bool(welcome["racing"]))
	assert_false((welcome["racers"] as Array).has(int(welcome["peer_id"])))
	await wait_seconds(0.3)
	for message: Dictionary in _inbox["late"]:
		assert_false(str(message["t"]) in [Protocol.RACE_START, Protocol.RACE_STATE], "レースの文は、出る人にだけ")
	# 画面ができたと言ってこない人がいても、決めた秒数で打ち切って始める。
	var race: Node = _server.room_race(_room_ids["部屋"])
	assert_true(bool(race.call("is_start_held")))
	_server.get("_rooms")[_room_ids["部屋"]]["ready_wait_s"] = Protocol.READY_TIMEOUT_S
	await wait_seconds(0.2)
	assert_false(bool(race.call("is_start_held")))
	# 最後の1人が抜けたら、レースも部屋も片づく。
	late.disconnect_from_server()
	_clients["a"].disconnect_from_server()
	await wait_seconds(0.5)
	assert_eq(_server.room_members(_room_ids["部屋"]).size(), 0)
	assert_null(_server.room_race(_room_ids["部屋"]))


## ゲーム側のレース（サーバーのレースを映すだけ）を、サーバーなしで作る。view_peer が、自分の番号。
func _view_race(view_peer: int) -> Node:
	var ids := _roster_ids()
	var entries: Array = []
	for index in mini(RaceSession.SLOT_COUNT, ids.size()):
		var pururin := PururinRosterConfig.pururin_by_id(ids[index])
		# 1枠と2枠が人（番号は11と12）、残りはCPU。
		var peer := 11 + index if index < 2 else 0
		entries.append(OnlineServer._entry(index, pururin, peer, "人%d" % index if peer != 0 else "CPU"))
	RaceSession.select_distance(RaceSession.supported_distances_m()[0])
	RaceSession.set_online_entries(entries)
	RaceSession.set_online_view(view_peer)
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	return race


func test_the_game_side_shows_the_servers_race_without_computing_it() -> void:
	var ids := _roster_ids()
	var race := await _view_race(12)
	var runners: Array = race.get("_runners")
	# 全員が、届いた状態を映すだけの走者。自分の番号（12）の走者が、この画面の「自分」。
	for runner in runners:
		assert_true(bool(runner.get("puppet")))
		assert_false(bool(runner.get("remote_controlled")))
		# ゲーム側は画面があるので、見た目の処理は動かす。
		assert_true(bool(runner.get("presentation_enabled")))
	var me: Node3D = race.get("_player")
	assert_eq(str(me.call("get_snapshot")["id"]), ids[1])
	# オンラインでは、もう1回は部屋から。戻る先は部屋。
	assert_false((race.find_child("ResultRetryButton", true, false) as Button).visible)
	# サーバーから状態が届くと、スタートし、走者がその位置・状態になる。
	var states: Array = []
	for index in runners.size():
		var state: Dictionary = runners[index].call("get_online_state")
		state["progress"] = 100.0 + 10.0 * index
		state["offset"] = 1.5
		state["actual_speed"] = 54.0
		state["heart"] = 150.0 + index
		state["notch"] = 4.0
		state["stamina_ratio"] = 0.5
		states.append(state)
	assert_false(bool(race.call("is_race_started")))
	# スタート前は、届いた位置のまま動かさない（届く「速さ」が0でなくても、先へ進めない。進めると、前後に揺れて見える）。
	var waiting: Array = []
	for state: Dictionary in states:
		var before_start := state.duplicate()
		before_start["progress"] = 0.0
		waiting.append(before_start)
	race.call("_on_online_message", Protocol.message(Protocol.RACE_STATE, {"elapsed": 0.0, "started": false, "entry_wait": 0.0, "countdown": 2.0, "hold": false, "over": false, "runners": waiting}))
	for _frame in 5:
		me.call("_process", 0.016)
	assert_almost_eq(float(me.call("get_race_progress")), 0.0, 0.0001)
	race.call("_on_online_message", Protocol.message(Protocol.RACE_STATE, {"elapsed": 12.5, "started": true, "entry_wait": 0.0, "countdown": 0.0, "hold": false, "over": false, "runners": states}))
	assert_true(bool(race.call("is_race_started")))
	assert_almost_eq(float(me.call("get_heart_rate_bpm")), 151.0, 0.001)
	assert_almost_eq(float(me.call("get_drive_level")), 4.0, 0.001)
	assert_almost_eq(float(me.call("get_stamina_ratio")), 0.5, 0.001)
	# 次の状態が届くまでは、速さのぶんだけ先へ進めて、なめらかに動かす（自分では走りを計算しない）。
	# 先へ進めるのは、決めた秒数ぶんまで（届かなくなっても、走り続けて見えないように）。
	for _frame in 120:
		me.call("_process", 0.016)
	assert_gt(float(me.call("get_race_progress")), 110.0)
	assert_lte(float(me.call("get_race_progress")), 110.0 + 54.0 / 3.6 * float(me.PUPPET_EXTRAPOLATE_MAX_S) + 0.001)
	assert_almost_eq(float(me.call("get_heart_rate_bpm")), 151.0, 0.001)
	# 着順が届くと、着順の板を出して、レースは終わり。
	var rows: Array = []
	for index in runners.size():
		rows.append({"id": ids[index], "place": index + 1, "time": 70.0 + index})
	race.call("_on_online_message", Protocol.message(Protocol.RACE_RESULT, {"rows": rows}))
	assert_true(bool(race.call("is_race_over")))
	assert_eq(int(me.call("get_finish_order")), 2)
	assert_true((race.find_child("ResultPanel", true, false) as Control).visible)
	assert_eq(str(race.call("_result_rows")[1]["trainer"]), "人1")


func test_a_runner_whose_player_leaves_is_handed_to_the_cpu() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	await _open_race("a", ["b"])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	await _go("a", ["a", "b"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	var race: Node = _server.room_race(_room_ids["部屋"])
	var runner_b: Node3D = race.call("remote_runner", b)
	assert_true(bool(runner_b.get("remote_controlled")))
	# b が抜ける。b の走者は、育てたCPUに任される（性格は、その個体のトレーナー）。レースは、残った人のために続く。
	_clients["b"].disconnect_from_server()
	var waited := 0.0
	while race.call("remote_runner", b) != null and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_null(race.call("remote_runner", b))
	assert_true((race.get("_brain") as RefCounted).has_seat(runner_b))
	assert_not_null(_server.room_race(_room_ids["部屋"]))
	assert_not_null(race.call("remote_runner", a))
	# 抜けた人を待たずに、残った人の準備だけで始まる。
	_clients["a"].send(Protocol.READY)
	await wait_seconds(0.3)
	assert_false(bool(race.call("is_start_held")))


func test_a_racer_who_quits_mid_race_goes_to_the_waiting_room_and_the_cpu_runs_on() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	await _open_race("a", ["b"])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	await _go("a", ["a", "b"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	var room: int = _room_ids["部屋"]
	var race: Node = _server.room_race(room)
	var runner_b: Node3D = race.call("remote_runner", b)
	# b が、一時停止の「レースをやめて待機室へ」を押す。b は部屋に残ったまま、レースに出る人から外れる。
	_clients["b"].send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})
	var waited := 0.0
	while race.call("remote_runner", b) != null and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_null(race.call("remote_runner", b))
	assert_true((race.get("_brain") as RefCounted).has_seat(runner_b))
	assert_false(_server.is_racer(room, b))
	assert_true((_server.room_members(room) as Array).any(func(m: Dictionary) -> bool: return int(m["peer_id"]) == b))
	assert_not_null(_server.room_race(room))
	# 主がやめても、主のまま待機室へ。走者はCPUが走り、レースはサーバーの上で続く。
	_clients["a"].send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})
	waited = 0.0
	while race.call("remote_runner", a) != null and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_null(race.call("remote_runner", a))
	assert_eq(int(_server._rooms[room]["host"]), a)
	assert_not_null(_server.room_race(room))
	assert_true(bool(race.call("_is_online_host")))


func test_the_seats_decide_how_many_cpus_run() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _enter("b", "部屋")
	# 人の足りない6席のうち、3席だけCPU：出走は5体。
	await _open_race("a", ["b"], [true, true, true, false, false, false])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await wait_seconds(0.2)
	assert_eq((_server.build_entries(_room_ids["部屋"]) as Array).size(), 5)
	# ぷるりんを選ぶ所では、席は変えられない（レース設定でだけ）。
	_clients["a"].send(Protocol.SETTINGS, {"seats": [false, false, false, false, false, false]})
	assert_eq(await _error_code("a"), Protocol.ERROR_WRONG_PHASE)


func test_a_race_needs_at_least_two_runners() -> void:
	await _enter("a", "部屋")
	# 人が1人で、CPUの席が無いと、ぷるりんを選ぶ所へ進めない。
	await _open_settings("a", [])
	_clients["a"].send(Protocol.SETTINGS, {"seats": [false, false, false, false, false, false, false]})
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.PICK_OPEN)
	assert_eq(await _error_code("a"), Protocol.ERROR_TOO_FEW)
	assert_eq(str(_server.call("_room_fields", _room_ids["部屋"])["phase"]), Protocol.PHASE_SETTINGS)



func test_everyone_confirms_before_the_entry_list_and_again_before_the_start() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	# 人の足りない6席のうち、4席をCPU：出走は6体。
	await _open_race("a", ["b"], [true, true, true, true, false, false])
	# プル選択に入ると、はじめから一覧の1番目のプルが入っている（「未選択」にならない）。
	assert_eq(_server.room_members(_room_ids["部屋"]).map(func(member: Dictionary) -> String: return str(member["pururin_id"])), [ids[0], ids[0]])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	# 1人でも確定していないと、出走表へ進めない。
	_clients["a"].send(Protocol.ENTRIES)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_CONFIRMED)
	_clients["b"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	assert_true(_server.everyone_confirmed(_room_ids["部屋"]))
	# 選び直すと、自分の確定は外れる。
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[2]})
	await wait_seconds(0.2)
	var members: Array = _server.room_members(_room_ids["部屋"])
	assert_eq([bool(members[0]["confirmed"]), bool(members[1]["confirmed"])], [true, false])
	# 全員が確定すると、出走表へ。枠順が付き、確定は、いったん外れる。
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	_clients["b"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_inbox["b"].clear()
	_clients["a"].send(Protocol.ENTRIES)
	var room := await _wait_for("b", Protocol.ROOM)
	assert_eq(str(room["phase"]), Protocol.PHASE_ENTRIES)
	var entries: Array = room["entries"]
	assert_eq(entries.size(), 6)
	for index in entries.size():
		assert_eq(int(entries[index]["gate"]), index)
	assert_false(bool(room["members"][0]["confirmed"]))
	# 出走表では、選び直せない。主でない人は、枠順を変えられない。
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[3]})
	assert_eq(await _error_code("b"), Protocol.ERROR_IN_ENTRIES)
	_clients["b"].send(Protocol.GATES, {"action": Protocol.GATES_SHUFFLE})
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	# 主が、2つの枠を入れ替える。
	var first_id := str(entries[0]["id"])
	var third_id := str(entries[2]["id"])
	_inbox["b"].clear()
	_clients["a"].send(Protocol.GATES, {"action": Protocol.GATES_SWAP, "a": 0, "b": 2})
	var swapped: Array = (await _wait_for("b", Protocol.ROOM))["entries"]
	assert_eq([str(swapped[0]["id"]), str(swapped[2]["id"])], [third_id, first_id])
	assert_eq([int(swapped[0]["gate"]), int(swapped[2]["gate"])], [0, 2])
	# 全員の確定がそろうまで、始められない。
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.START)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_CONFIRMED)
	# パドックから、プル選択へは戻れない（選び直しは、パドックではしない）。主の「待機室へ戻る」で、全員が待機室へ。
	_clients["a"].send(Protocol.BACK)
	assert_eq(await _error_code("a"), Protocol.ERROR_WRONG_PHASE)
	_inbox["b"].clear()
	_clients["a"].send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})
	var back := await _wait_for("b", Protocol.ROOM)
	assert_eq(str(back["phase"]), Protocol.PHASE_LOBBY)
	assert_eq((back["entries"] as Array).size(), 0)
	assert_gt(a + b, 0)


func test_the_host_decides_cpu_pururins_and_same_pururins_get_their_own_runner_numbers() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _enter("b", "部屋")
	var room_id: int = _room_ids["部屋"]
	await _open_race("a", ["b"], [true, true, false, false, false, false])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await wait_seconds(0.2)
	assert_eq(_server.cpu_slot_count(room_id), 2)
	# 主でない人は、決められない。トレーナーは、変えられない（そのプルのデフォルト）。
	_clients["b"].send(Protocol.CPU_PICK, {"index": 0, "pururin_id": ids[5]})
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	_clients["a"].send(Protocol.CPU_PICK, {"index": 0, "trainer_id": "x"})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# 人と同じプルでも、CPUに決められる。
	_clients["a"].send(Protocol.CPU_PICK, {"index": 0, "pururin_id": ids[0]})
	await wait_seconds(0.2)
	assert_eq(str(_server.room_cpus(room_id)[0]["pururin_id"]), ids[0])
	# 出走：同じプルが3体。走者の番号は、1体目はプルの番号、2体目から「番号#2」「番号#3」。トレーナーは、そのプルのデフォルト。
	var entries: Array = _server.build_entries(room_id)
	assert_eq(entries.size(), 4)
	assert_eq(entries.map(func(entry: Dictionary) -> String: return str(entry["runner_id"])).slice(0, 3), [ids[0], ids[0] + "#2", ids[0] + "#3"])
	assert_eq(str(entries[2]["trainer_id"]), str(PururinRosterConfig.pururin_by_id(ids[0])["trainer_id"]))
	assert_false(str(entries[3]["id"]) in [ids[0]])
	# 全員が確定すると、パドックへ。確定は、いったん外れる。
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	_clients["b"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.ENTRIES)
	await wait_seconds(0.3)
	# パドックでは、CPUのプルは変えられない。
	_clients["a"].send(Protocol.CPU_PICK, {"index": 0, "pururin_id": ids[7]})
	assert_eq(await _error_code("a"), Protocol.ERROR_WRONG_PHASE)
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	assert_false(_server.everyone_confirmed(room_id))


func test_the_race_is_cleared_a_set_time_after_the_result_even_if_people_stay() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _open_race("a", [])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("a", Protocol.ROOM)
	await _go("a", ["a"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	var room_id: int = _room_ids["部屋"]
	var race: Node = _server.room_race(room_id)
	race.set("_race_over", true)
	assert_false((await _wait_for("a", Protocol.RACE_RESULT)).is_empty())
	assert_not_null(_server.room_race(room_id))
	# 決めた秒数（設定）がたつと、だれも画面を出ていなくても、片づけて、全員を待機室へ戻す。
	_server.get("_rooms")[room_id]["linger_s"] = load("res://scripts/config/online_config.gd").result_linger_s()
	assert_false((await _wait_for("a", Protocol.RACE_END)).is_empty())
	assert_null(_server.room_race(room_id))
	var fields: Dictionary = _server.call("_room_fields", room_id)
	assert_eq(str(fields["phase"]), Protocol.PHASE_LOBBY)
	assert_eq((fields["racers"] as Array).size(), 0)


func test_the_server_keeps_a_detailed_record_of_each_online_race() -> void:
	var OnlineRaceLog = load("res://scripts/online/online_race_log.gd")
	var folder := ProjectSettings.globalize_path("user://online_race_logs_test")
	OS.set_environment(OnlineRaceLog.DIRECTORY_ENVIRONMENT, folder)
	DirAccess.make_dir_recursive_absolute(folder)
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	var ids := _roster_ids()
	await _enter("a", "記録の部屋")
	await _open_race("a", [])
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("a", Protocol.ROOM)
	await _go("a", ["a"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	_clients["a"].send(Protocol.READY)
	Engine.time_scale = FAST_FORWARD
	await _wait_for("a", Protocol.RACE_STATE)
	var race: Node = _server.room_race(_room_ids["記録の部屋"])
	while not bool(race.call("is_race_started")):
		await wait_seconds(0.1)
	_clients["a"].send(Protocol.INPUT, {"line": 1.0, "notch": 1.0, "brake": false})
	_clients["a"].send(Protocol.ACTION, {"kind": Protocol.ACTION_DASH})
	await wait_seconds(1.0)
	Engine.time_scale = 1.0
	race.set("_race_over", true)
	await _wait_for("a", Protocol.RACE_RESULT)
	_clients["a"].send(Protocol.RACE_DONE)
	assert_false((await _wait_for("a", Protocol.RACE_END)).is_empty())
	var files := DirAccess.get_files_at(folder)
	assert_eq(files.size(), 1)
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(files[0])))
	assert_eq(str(record["race_type"]), "online")
	assert_eq(str(record["room_name"]), "記録の部屋")
	assert_eq((record["entries"] as Array).size(), (record["samples"][0]["runners"] as Array).size())
	assert_eq(str(record["people"][0]["name"]), "a")
	assert_gt((record["track"] as Array).size(), 5, "0.1秒ごとの位置")
	assert_eq((record["track"][0]["r"] as Array).size(), (record["entries"] as Array).size())
	assert_gt((record["samples"] as Array).size(), 1, "0.5秒ごとの詳しい状態")
	var kinds: Array = (record["events"] as Array).map(func(event: Dictionary) -> String: return str(event["kind"]))
	assert_true(kinds.has("input"))
	assert_true(kinds.has(Protocol.ACTION_DASH))
	assert_true(kinds.has("result"))
	assert_eq((record["result_rows"] as Array).size(), (record["entries"] as Array).size())
	# 決めた日数より古い記録は、消す。
	var old := folder.path_join("old.json")
	FileAccess.open(old, FileAccess.WRITE).store_string("{}")
	assert_eq(OnlineRaceLog.remove_old(folder, 1), 0, "新しいものは消さない")
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	OS.set_environment(OnlineRaceLog.DIRECTORY_ENVIRONMENT, "")


func test_quitting_an_online_race_asks_first_and_b_goes_back_to_the_pause_panel() -> void:
	var race := LocalRaceScene.instantiate()
	add_child_autofree(race)
	await get_tree().process_frame
	race.set("_online_view", true)
	race.call("_set_paused", true)
	var pause_box := race.get_node("UI/PausePanel/PauseBox") as Control
	var confirm_box := race.find_child("QuitConfirmBox", true, false) as Control
	# 「レースをやめて待機室へ」を押しても、すぐには抜けない。確かめの板が出て、カーソルは「やめない」。
	(race.get("_pause_return_button") as Button).pressed.emit()
	assert_true(confirm_box.visible)
	assert_false(pause_box.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), race.find_child("QuitCancelButton", true, false))
	# B で、一時停止の板へ戻る（レースは一時停止のまま）。
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	race._unhandled_input(b)
	assert_false(confirm_box.visible)
	assert_true(pause_box.visible)
	assert_true(bool(race.get("_paused")))
	assert_eq(get_viewport().gui_get_focus_owner(), race.get("_pause_return_button"))
	# 一時停止を解くと、確かめの板も閉じる。
	(race.get("_pause_return_button") as Button).pressed.emit()
	race.call("_set_paused", false)
	assert_false(confirm_box.visible)
