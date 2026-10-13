extends GutTest
## オンラインのレース：ぷるりんと距離を選ぶ、サーバーがレースを走らせて状態を配る、通信ごしの操作が走者に効く、着順が届く。

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
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[2]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	var entries: Array = _server.build_entries(_room_ids["部屋"])
	assert_eq(entries.size(), mini(RaceSession.SLOT_COUNT, ids.size()))
	# 人は、入った順に1枠から。名前は、その人の名前。
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
	# 知らない個体は、選べない。
	_clients["a"].send(Protocol.PICK, {"pururin_id": "いない個体"})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# ほかの人が選んだ個体は、選べない。
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("a", Protocol.ROOM)
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	assert_eq(await _error_code("b"), Protocol.ERROR_TAKEN)
	# 距離を決めるのも、始めるのも、部屋の主（最初に入った人）だけ。
	var distances: Array = RaceSession.supported_distances_m()
	_clients["b"].send(Protocol.SETTINGS, {"distance_m": distances[0]})
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	_clients["b"].send(Protocol.START)
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_HOST)
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": distances[0]})
	assert_almost_eq(float((await _wait_for("b", Protocol.ROOM)).get("distance_m", 0.0)), float(distances[0]), 0.001)
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": 777.0})
	assert_eq(await _error_code("a"), Protocol.ERROR_BAD_MESSAGE)
	# まだ選んでいない人がいると、出走表へ進めない。出走表でないと、始められない。
	_clients["a"].send(Protocol.ENTRIES)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_READY)
	_clients["a"].send(Protocol.START)
	assert_eq(await _error_code("a"), Protocol.ERROR_NOT_IN_ENTRIES)
	assert_null(_server.room_race(_room_ids["部屋"]))


func test_the_server_runs_the_race_and_remote_input_moves_the_runners() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("b", Protocol.ROOM)
	_clients["a"].send(Protocol.SETTINGS, {"distance_m": RaceSession.supported_distances_m()[0]})
	await _wait_for("b", Protocol.ROOM)
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
	# レースが終わると、着順が届き、サーバーはレースを片づけて、部屋に戻す。
	race.set("_race_over", true)
	var result := await _wait_for("a", Protocol.RACE_RESULT)
	assert_eq((result.get("rows", []) as Array).size(), (start["entries"] as Array).size())
	await wait_seconds(0.2)
	assert_null(_server.room_race(_room_ids["部屋"]))
	assert_false(bool((await _wait_for("a", Protocol.ROOM)).get("racing", true)))


func test_nobody_joins_or_picks_while_the_room_is_racing() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	await _wait_for("a", Protocol.ROOM)
	await _go("a", ["a"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[1]})
	assert_eq(await _error_code("a"), Protocol.ERROR_RACING)
	# あとから来た人は、レース中の部屋には入れない。
	var late: Node = OnlineClient.new()
	add_child_autofree(late)
	_inbox["late"] = []
	late.message_received.connect(func(data: Dictionary) -> void: (_inbox["late"] as Array).append(data))
	late.connect_to("ws://127.0.0.1:%d" % TEST_PORT)
	await wait_for_signal(late.connected, WAIT_S)
	late.hello("late")
	await _wait_for("late", Protocol.LOBBY)
	late.join_room(int(_room_ids["部屋"]))
	assert_eq(await _error_code("late"), Protocol.ERROR_RACING)
	# 画面ができたと言ってこない人がいても、決めた秒数で打ち切って始める。
	var race: Node = _server.room_race(_room_ids["部屋"])
	assert_true(bool(race.call("is_start_held")))
	_server.get("_rooms")[_room_ids["部屋"]]["ready_wait_s"] = Protocol.READY_TIMEOUT_S
	await wait_seconds(0.2)
	assert_false(bool(race.call("is_start_held")))
	# 最後の1人が抜けたら、レースも部屋も片づく。
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
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	await _wait_for("b", Protocol.ROOM)
	await wait_seconds(0.2)
	await _go("a", ["a", "b"])
	assert_false((await _wait_for("a", Protocol.RACE_START)).is_empty())
	var race: Node = _server.room_race(_room_ids["部屋"])
	var runner_b: Node3D = race.call("remote_runner", b)
	assert_true(bool(runner_b.get("remote_controlled")))
	# b が抜ける。b の走者は、その個体のCPUトレーナーに任される。レースは、残った人のために続く。
	_clients["b"].disconnect_from_server()
	var waited := 0.0
	while race.call("remote_runner", b) != null and waited < WAIT_S:
		await wait_seconds(0.05)
		waited += 0.05
	assert_null(race.call("remote_runner", b))
	assert_false(bool(runner_b.get("remote_controlled")))
	assert_false(bool(runner_b.get("player_controlled")))
	assert_eq(runner_b.get("_cpu_trainer_profile"), LocalRaceMath.cpu_trainer_profile_by_id(str(PururinRosterConfig.pururin_by_id(ids[1])["trainer_profile_id"])) if PururinRosterConfig.pururin_by_id(ids[1]).has("trainer_profile_id") else runner_b.get("_cpu_trainer_profile"))
	assert_not_null(_server.room_race(_room_ids["部屋"]))
	assert_not_null(race.call("remote_runner", a))
	# 抜けた人を待たずに、残った人の準備だけで始まる。
	_clients["a"].send(Protocol.READY)
	await wait_seconds(0.3)
	assert_false(bool(race.call("is_start_held")))


func test_the_field_size_and_the_cpu_switch_shape_the_entries() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	await _enter("b", "部屋")
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[1]})
	_clients["a"].send(Protocol.SETTINGS, {"field_size": 5})
	await _wait_for("a", Protocol.ROOM)
	await wait_seconds(0.2)
	# CPUあり：人のあとを、出走数まで、CPUで埋める。
	assert_eq((_server.build_entries(_room_ids["部屋"]) as Array).size(), 5)
	# CPUなし：人だけ。
	_clients["a"].send(Protocol.SETTINGS, {"cpu": false})
	await _wait_for("a", Protocol.ROOM)
	await wait_seconds(0.2)
	var people_only: Array = _server.build_entries(_room_ids["部屋"])
	assert_eq(people_only.size(), 2)
	for entry: Dictionary in people_only:
		assert_true(bool(entry["player"]))


func test_a_race_needs_at_least_two_runners() -> void:
	var ids := _roster_ids()
	await _enter("a", "部屋")
	_clients["a"].send(Protocol.PICK, {"pururin_id": ids[0]})
	_clients["a"].send(Protocol.SETTINGS, {"cpu": false})
	await _wait_for("a", Protocol.ROOM)
	_clients["a"].send(Protocol.CONFIRM, {"on": true})
	await wait_seconds(0.2)
	_clients["a"].send(Protocol.ENTRIES)
	assert_eq(await _error_code("a"), Protocol.ERROR_TOO_FEW)
	assert_null(_server.room_race(_room_ids["部屋"]))



func test_everyone_confirms_before_the_entry_list_and_again_before_the_start() -> void:
	var ids := _roster_ids()
	var a := await _enter("a", "部屋")
	var b := await _enter("b", "部屋")
	# 選ぶ前は、確定できない。
	_clients["b"].send(Protocol.CONFIRM, {"on": true})
	assert_eq(await _error_code("b"), Protocol.ERROR_NOT_READY)
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
	# 選び直すと、自分の確定は外れる。決めごとが変わると、全員の確定が外れる。
	_clients["b"].send(Protocol.PICK, {"pururin_id": ids[2]})
	await wait_seconds(0.2)
	var members: Array = _server.room_members(_room_ids["部屋"])
	assert_eq([bool(members[0]["confirmed"]), bool(members[1]["confirmed"])], [true, false])
	_clients["a"].send(Protocol.SETTINGS, {"field_size": 6})
	await wait_seconds(0.2)
	assert_false(bool(_server.room_members(_room_ids["部屋"])[0]["confirmed"]))
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
	# 主が「部屋へ戻る」と、選ぶ所へ戻る。
	_inbox["b"].clear()
	_clients["a"].send(Protocol.BACK)
	var back := await _wait_for("b", Protocol.ROOM)
	assert_eq(str(back["phase"]), Protocol.PHASE_ROOM)
	assert_eq((back["entries"] as Array).size(), 0)
	assert_gt(a + b, 0)
