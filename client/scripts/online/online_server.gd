extends Node
## オンライン対戦のサーバー（画面なしの Godot で動かす）。
## つなぐ・合言葉の部屋に集まる・ぷるりんと距離を選ぶ・レースを走らせて状態を配る、を受け持つ。
## レースは、ゲーム本体と同じ場面（local_race）を、部屋ごとに1つ作って走らせる。
## 起動：`godot --headless --path client res://scenes/online_server.tscn`

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")

## 起動したときに、自分で待ち受けを始めるか（テストでは false にして、入口の番号を選ぶ）。
@export var listen_on_ready := true

var _tcp := TCPServer.new()
## つないでいる相手。番号 → {"socket": WebSocketPeer, "name": 名前, "room": 合言葉（部屋に入る前は空）}
var _peers := {}
var _next_peer_id := 1
## 部屋。合言葉 → {"host": 部屋の主の番号, "distance_m": 距離, "picks": {人の番号: ぷるりんのID},
## "race": 走っているレース（無ければ null）, "state_wait_s": 次に状態を配るまでの秒数,
## "ready": {レースの画面ができた人の番号: true}, "ready_wait_s": 全員の画面ができるのを待った秒数}
var _rooms := {}


func _ready() -> void:
	if listen_on_ready:
		Engine.max_fps = OnlineConfig.server_max_fps()
		var port := Protocol.server_port()
		var error := listen(port)
		if error != OK:
			push_error("オンラインのサーバー：入口 %d で待ち受けられません（%s）" % [port, error_string(error)])
			get_tree().quit(1)
			return
		print("ぷるりんレーサーズ — オンラインのサーバー待機中（:%d、計算は1秒%d回まで）" % [port, Engine.max_fps])


## 入口の番号を決めて、待ち受けを始める。
func listen(port: int) -> Error:
	return _tcp.listen(port)


func stop() -> void:
	for peer_id: int in _peers.keys():
		(_peers[peer_id]["socket"] as WebSocketPeer).close()
	_peers.clear()
	for room: String in _rooms.keys():
		_end_race(room)
	_rooms.clear()
	_tcp.stop()


func _exit_tree() -> void:
	stop()


func peer_count() -> int:
	return _peers.size()


## その合言葉の部屋にいる人（入った順）。1人ぶん：{"peer_id": 番号, "name": 名前, "pururin_id": 選んだぷるりん（まだなら空）}
func room_members(room: String) -> Array:
	var members: Array = []
	var picks: Dictionary = _rooms[room]["picks"] if _rooms.has(room) else {}
	var ids := _peers.keys()
	ids.sort()
	for peer_id: int in ids:
		if str(_peers[peer_id]["room"]) == room:
			members.append({"peer_id": peer_id, "name": _peers[peer_id]["name"], "pururin_id": str(picks.get(peer_id, ""))})
	return members


## 部屋にいる全員の、レースの画面ができたか。
func everyone_ready(room: String) -> bool:
	var ready: Dictionary = _rooms[room]["ready"]
	for member: Dictionary in room_members(room):
		if not ready.has(int(member["peer_id"])):
			return false
	return true


## その部屋で走っているレース（無ければ null）。
func room_race(room: String) -> Node:
	return _rooms[room]["race"] if _rooms.has(room) else null


func _process(delta: float) -> void:
	while _tcp.is_connection_available():
		var socket := WebSocketPeer.new()
		if socket.accept_stream(_tcp.take_connection()) == OK:
			_peers[_next_peer_id] = {"socket": socket, "name": "", "room": ""}
			_next_peer_id += 1
	for peer_id: int in _peers.keys():
		var socket: WebSocketPeer = _peers[peer_id]["socket"]
		socket.poll()
		match socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while socket.get_available_packet_count() > 0:
					_receive(peer_id, socket.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_drop(peer_id)
	for room: String in _rooms.keys():
		_update_race(room, delta)


# ---------------------------------------------------------------- 受け取る

func _receive(peer_id: int, text: String) -> void:
	var data := Protocol.decode(text)
	if data.is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	if int(data.get("v", 0)) != Protocol.VERSION:
		_refuse(peer_id, Protocol.ERROR_VERSION)
		return
	var type := str(data["t"])
	match type:
		Protocol.PING:
			_send(peer_id, Protocol.message(Protocol.PONG, {"client_ts": data.get("client_ts", 0)}))
			return
		Protocol.HELLO:
			_join(peer_id, data)
			return
	# ここから下は、部屋に入ってからでないと、できない。
	var room := str(_peers[peer_id]["room"])
	if room.is_empty():
		_refuse(peer_id, Protocol.ERROR_NOT_IN_ROOM if type in [Protocol.PICK, Protocol.DISTANCE, Protocol.START, Protocol.INPUT, Protocol.ACTION, Protocol.READY] else Protocol.ERROR_BAD_MESSAGE)
		return
	match type:
		Protocol.PICK: _pick(peer_id, room, data)
		Protocol.DISTANCE: _set_distance(peer_id, room, data)
		Protocol.START: _start_race(peer_id, room)
		Protocol.INPUT: _race_input(peer_id, room, data)
		Protocol.ACTION: _race_action(peer_id, room, data)
		Protocol.READY: (_rooms[room]["ready"] as Dictionary)[peer_id] = true
		_: _refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)


## 合言葉の部屋に入る。満員なら断る。レース中の部屋には、入れない。
func _join(peer_id: int, data: Dictionary) -> void:
	var room := Protocol.clean_text(data.get("room", ""), Protocol.ROOM_CODE_MAX_LENGTH)
	var player_name := Protocol.clean_text(data.get("name", ""), Protocol.NAME_MAX_LENGTH)
	if room.is_empty() or player_name.is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var previous_room := str(_peers[peer_id]["room"])
	if previous_room != room:
		if room_members(room).size() >= Protocol.ROOM_CAPACITY:
			_refuse(peer_id, Protocol.ERROR_ROOM_FULL)
			return
		if room_race(room) != null:
			_refuse(peer_id, Protocol.ERROR_RACING)
			return
		_leave_room(peer_id)
	_peers[peer_id]["name"] = player_name
	_peers[peer_id]["room"] = room
	if not _rooms.has(room):
		_rooms[room] = {"host": peer_id, "distance_m": RaceSession.DEFAULT_DISTANCE_M, "picks": {}, "race": null, "state_wait_s": 0.0, "ready": {}, "ready_wait_s": 0.0}
	_send(peer_id, Protocol.message(Protocol.WELCOME, _room_fields(room, {"peer_id": peer_id, "capacity": Protocol.ROOM_CAPACITY})))
	_announce_room(room)


func _drop(peer_id: int) -> void:
	_leave_room(peer_id)
	_peers.erase(peer_id)


## 今いる部屋から抜ける。部屋の主が抜けたら、次に古い人が主になる。誰もいなくなった部屋は、消す。
func _leave_room(peer_id: int) -> void:
	var room := str(_peers[peer_id]["room"])
	if room.is_empty():
		return
	_peers[peer_id]["room"] = ""
	(_rooms[room]["picks"] as Dictionary).erase(peer_id)
	(_rooms[room]["ready"] as Dictionary).erase(peer_id)
	# レース中に抜けた人の走者は、その個体のCPUトレーナーに任せる。
	if room_race(room) != null:
		room_race(room).call("release_remote_runner", peer_id)
	var members := room_members(room)
	if members.is_empty():
		_end_race(room)
		_rooms.erase(room)
		return
	if int(_rooms[room]["host"]) == peer_id:
		_rooms[room]["host"] = int(members[0]["peer_id"])
	_announce_room(room)


## 自分のぷるりんを選ぶ。ほかの人が選んでいる個体は、選べない。
func _pick(peer_id: int, room: String, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	var pururin_id := str(data.get("pururin_id", ""))
	if PururinRosterConfig.pururin_by_id(pururin_id).is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var picks: Dictionary = _rooms[room]["picks"]
	for other: int in picks:
		if other != peer_id and str(picks[other]) == pururin_id:
			_refuse(peer_id, Protocol.ERROR_TAKEN)
			return
	picks[peer_id] = pururin_id
	_announce_room(room)


## 距離を決める（部屋の主だけ。選べる距離だけ）。
func _set_distance(peer_id: int, room: String, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return
	var distance := float(data.get("distance_m", 0.0))
	if not RaceSession.supported_distances_m().has(distance):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_rooms[room]["distance_m"] = distance
	_announce_room(room)


# ---------------------------------------------------------------- レース

## その部屋の出走の一覧を組む。人は、入った順に1枠から。残りは、まだ選ばれていない個体を、一覧の順にCPUで埋める。
func build_entries(room: String) -> Array:
	var entries: Array = []
	var used := {}
	for member: Dictionary in room_members(room):
		var pururin := PururinRosterConfig.pururin_by_id(str(member["pururin_id"]))
		used[str(member["pururin_id"])] = true
		entries.append(_entry(entries.size(), pururin, int(member["peer_id"]), str(member["name"])))
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		if entries.size() >= RaceSession.SLOT_COUNT:
			break
		if not used.has(str(pururin["id"])):
			entries.append(_entry(entries.size(), pururin, 0, str(CpuTrainers.by_id(str(pururin["trainer_id"])).get("name", ""))))
	return entries


static func _entry(gate: int, pururin: Dictionary, peer_id: int, trainer_name: String) -> Dictionary:
	var trainer_id := str(pururin["trainer_id"])
	return {
		"gate": gate, "id": str(pururin["id"]), "player": peer_id != 0, "peer_id": peer_id,
		"trainer_id": trainer_id, "trainer_profile_id": str(CpuTrainers.by_id(trainer_id).get("profile_id", "")), "trainer_name": trainer_name,
	}


## レースを始める（部屋の主だけ。全員が選び終わっていること）。
func _start_race(peer_id: int, room: String) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return
	for member: Dictionary in room_members(room):
		if str(member["pururin_id"]).is_empty():
			_refuse(peer_id, Protocol.ERROR_NOT_READY)
			return
	var entries := build_entries(room)
	var distance := float(_rooms[room]["distance_m"])
	# レースの場面は、作られるときに、出走と距離を読む。作り終わったら、出走の指定は戻す。
	RaceSession.select_distance(distance)
	RaceSession.set_course_only(true)
	RaceSession.set_online_entries(entries)
	var race: Node = LocalRaceScene.instantiate()
	race.name = "Race_%d" % int(_rooms[room]["host"])
	add_child(race)
	RaceSession.set_online_entries([])
	# 全員のレースの画面ができるまで、スタートへ向かう時計を止めておく。
	race.call("hold_start")
	_rooms[room]["race"] = race
	_rooms[room]["state_wait_s"] = 0.0
	_rooms[room]["ready"] = {}
	_rooms[room]["ready_wait_s"] = 0.0
	_send_room(room, Protocol.message(Protocol.RACE_START, {"distance_m": distance, "entries": entries}))
	_announce_room(room)


## レース中の操作。レースが無い・自分の走者がいないときは、だまって捨てる（終わりぎわに届いた操作のため）。
func _race_input(peer_id: int, room: String, data: Dictionary) -> void:
	var race := room_race(room)
	if race != null:
		race.call("set_remote_input", peer_id, float(data.get("line", 0.0)), float(data.get("notch", 0.0)), bool(data.get("brake", false)))


func _race_action(peer_id: int, room: String, data: Dictionary) -> void:
	var race := room_race(room)
	var kind := str(data.get("kind", ""))
	if race != null and kind in [Protocol.ACTION_DASH, Protocol.ACTION_BOOST]:
		race.call("trigger_remote_action", peer_id, kind)


## 走っているレースの状態を、決めた回数で配る。終わったら、着順を配って、レースを片づける。
func _update_race(room: String, delta: float) -> void:
	var race := room_race(room)
	if race == null:
		return
	if bool(race.call("is_race_over")):
		_send_room(room, Protocol.message(Protocol.RACE_RESULT, {"rows": race.call("online_result_rows")}))
		_end_race(room)
		_announce_room(room)
		return
	if bool(race.call("is_start_held")):
		_rooms[room]["ready_wait_s"] = float(_rooms[room]["ready_wait_s"]) + delta
		if everyone_ready(room) or float(_rooms[room]["ready_wait_s"]) >= Protocol.READY_TIMEOUT_S:
			race.call("release_start_hold")
	_rooms[room]["state_wait_s"] = float(_rooms[room]["state_wait_s"]) - delta
	if float(_rooms[room]["state_wait_s"]) <= 0.0:
		_rooms[room]["state_wait_s"] = 1.0 / Protocol.STATE_RATE_HZ
		_send_room(room, Protocol.message(Protocol.RACE_STATE, race.call("online_state")))


func _end_race(room: String) -> void:
	var race := room_race(room)
	if race != null:
		race.queue_free()
		_rooms[room]["race"] = null


# ---------------------------------------------------------------- 送る

## 部屋のようす（部屋の全員に配るもの）。
func _room_fields(room: String, extra: Dictionary = {}) -> Dictionary:
	var fields := {
		"room": room, "members": room_members(room), "host": int(_rooms[room]["host"]),
		"distance_m": float(_rooms[room]["distance_m"]), "racing": room_race(room) != null,
	}
	fields.merge(extra)
	return fields


func _announce_room(room: String) -> void:
	if _rooms.has(room):
		_send_room(room, Protocol.message(Protocol.ROOM, _room_fields(room)))


func _send_room(room: String, data: Dictionary) -> void:
	var text := Protocol.encode(data)
	for member: Dictionary in room_members(room):
		_send_text(int(member["peer_id"]), text)


func _refuse(peer_id: int, code: String) -> void:
	_send(peer_id, Protocol.message(Protocol.ERROR, {"code": code}))


func _send(peer_id: int, data: Dictionary) -> void:
	_send_text(peer_id, Protocol.encode(data))


func _send_text(peer_id: int, text: String) -> void:
	if not _peers.has(peer_id):
		return
	var socket: WebSocketPeer = _peers[peer_id]["socket"]
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(text)
