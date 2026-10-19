extends Node
## オンライン対戦のサーバー（画面なしの Godot で動かす）。
## つなぐ・部屋を作る・部屋に入る・部屋の決めごと・ぷるりんを選ぶ・ひとこと・レースを走らせて状態を配る、を受け持つ。
## オンラインフリー対戦（サーバーが持つ、距離ごとのルーム。☑した人を、長く待っている順に呼んで、レースを始める）も受け持つ。
## レースは、ゲーム本体と同じ場面（local_race）を、部屋ごとに1つ作って走らせる。
## 起動：`godot --headless --path client res://scenes/online_server.tscn`

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const OnlineRaceLog := preload("res://scripts/online/online_race_log.gd")

## 起動したときに、自分で待ち受けを始めるか（テストでは false にして、入口の番号を選ぶ）。
@export var listen_on_ready := true

var _tcp := TCPServer.new()
## つないでいる相手。番号 → {"socket": WebSocketPeer, "name": 名前（名乗る前は空）, "room": 部屋の番号（部屋に入っていなければ 0）}
var _peers := {}
var _next_peer_id := 1
## 部屋。部屋の番号 → {"name": 部屋の名前, "password": パスワード（空なら、だれでも入れる）, "host": 部屋の主の番号,
## "distance_m": 距離, "seats": 人の足りない席ごとに、CPUを入れるか（真偽の並び）, "picks": {人の番号: ぷるりんのID},
## "racers": レースに出る人の番号（待機室でレース開始を押したときの、準備OKの人と主。待機室では空）,
## "lobby_ready": {待機室で「準備OK」を押した人の番号: true},
## "cpu_picks": 主が決めたCPU（何番目のCPUか → {"pururin_id", "trainer_id"}。空の文字は「おまかせ」）,
## "phase": 場面（待機室・レース設定・ぷるりんを選ぶ所・出走表）, "confirmed": {「確定」を押した人の番号: true}, "entries": 出走表（枠順に並んだ出走の一覧）,
## "race": 走っているレース（無ければ null）, "state_wait_s": 次に状態を配るまでの秒数,
## "result_sent": 結果を配ったか, "linger_s": 結果を配ってからの秒数, "done": {結果を見終わって、画面を出た人の番号: true},
## "log": レースの記録（OnlineRaceLog）,
## "ready": {レースの画面ができた人の番号: true}, "ready_wait_s": 全員の画面ができるのを待った秒数}
var _rooms := {}
var _next_room_id := 1
## オンラインフリー対戦のルーム。ルームのID（online.json の free_rooms の id）→ 部屋の番号（_rooms の鍵）。並びは、設定の順。
## フリーのルームも、_rooms に入る（レースの走らせ方を、ともだち対戦と同じにするため）。部屋の主はいない（host は0）。
## フリーのルームにだけある項目：free＝true、free_id、call_state（idle＝空き、calling＝呼んでいる、racing＝レース中）、
## call_s＝呼び始めてからの秒数、accepted＝入ると答えた人（答えた順）、pending＝返事を待っている人 {番号: true}。
## order（レースに出ていて、まだいる人）・racers・picks・seats は、レースを始めるときに入れる。
var _free_rooms := {}
## 管理人の合い札（空なら、管理人の命令は、すべて断る）。起動時に、環境変数から読む。テストでは、直接入れる。
var admin_token := ""
## オンラインフリー対戦の、待つ秒数（0より小さければ、設定 online.json の値）。テストで、短くするため。
var fill_wait_s := -1.0
var answer_wait_s := -1.0


func _ready() -> void:
	_make_free_rooms()
	if listen_on_ready:
		# サーバーは、画面のボタンを押す操作を受け取らない（このPCをサーバーにしたとき、
		# つないであるゲームパッドの操作が、サーバーの上の画面にも届くため。レースの側は、レースを始めるときに止める）。
		get_tree().root.gui_disable_input = true
		Engine.max_fps = OnlineConfig.server_max_fps()
		admin_token = OS.get_environment(Protocol.ADMIN_TOKEN_ENVIRONMENT)
		var port := Protocol.server_port()
		var error := listen(port)
		if error != OK:
			push_error("オンラインのサーバー：入口 %d で待ち受けられません（%s）" % [port, error_string(error)])
			get_tree().quit(1)
			return
		var removed := OnlineRaceLog.remove_old(OnlineRaceLog.directory(), OnlineConfig.log_keep_days())
		print("ぷるりんレーサーズ — オンラインのサーバー待機中（:%d、計算は1秒%d回まで、部屋は%dつまで、管理人の合い札は%s）" % [port, Engine.max_fps, OnlineConfig.max_rooms(), "あり" if not admin_token.is_empty() else "なし"])
		print("レースの記録の置き場所：%s（%d日より古いものは消す。今回消した数：%d）" % [OnlineRaceLog.directory(), OnlineConfig.log_keep_days(), removed])


## 入口の番号を決めて、待ち受けを始める。
func listen(port: int) -> Error:
	return _tcp.listen(port)


func stop() -> void:
	for peer_id: int in _peers.keys():
		(_peers[peer_id]["socket"] as WebSocketPeer).close()
	_peers.clear()
	for room: int in _rooms.keys():
		_end_race(room)
	_rooms.clear()
	_free_rooms.clear()
	_tcp.stop()


func _exit_tree() -> void:
	stop()


func peer_count() -> int:
	return _peers.size()


## ともだち対戦の部屋の数（フリーのルームは数えない）。
func room_count() -> int:
	return _rooms.size() - _free_rooms.size()


## その部屋にいる人（入った順）。1人ぶん：{"peer_id": 番号, "name": 名前, "pururin_id": 選んだぷるりん（まだなら空）,
## "confirmed": 確定したか, "ready": 待機室で準備OKか, "racer": レースに出る人か, "introduction": 自己紹介, "icon": アイコン}
func room_members(room: int) -> Array:
	var members: Array = []
	if not _rooms.has(room):
		return members
	for peer_id: int in _rooms[room]["order"]:
		members.append(_member(room, peer_id))
	return members


## レースに出る人（レース開始を押したときの並び）。1人ぶんは room_members と同じ。
func racer_members(room: int) -> Array:
	var members: Array = []
	if not _rooms.has(room):
		return members
	for peer_id: int in _rooms[room]["racers"]:
		members.append(_member(room, peer_id))
	return members


func _member(room: int, peer_id: int) -> Dictionary:
	var peer: Dictionary = _peers[peer_id]
	var icon: Dictionary = peer["icon"]
	return {
		"peer_id": peer_id, "name": peer["name"], "pururin_id": str((_rooms[room]["picks"] as Dictionary).get(peer_id, "")),
		"confirmed": (_rooms[room]["confirmed"] as Dictionary).has(peer_id),
		"ready": (_rooms[room]["lobby_ready"] as Dictionary).has(peer_id),
		"racer": (_rooms[room]["racers"] as Array).has(peer_id),
		"introduction": str(peer.get("introduction", "")),
		# 自分で入れた画像は大きいので、部屋のようすには入れない（見たいときは、profile で聞く）。
		"icon": {"kind": str(icon.get("kind", "none")), "id": str(icon.get("id", ""))},
	}


## レースに出る人のうち、まだ部屋にいる人（レースの最中に抜けた人は、待たない）。
func present_racers(room: int) -> Array:
	var order: Array = _rooms[room]["order"]
	return (_rooms[room]["racers"] as Array).filter(func(peer_id: int) -> bool: return order.has(peer_id))


func is_racer(room: int, peer_id: int) -> bool:
	return (_rooms[room]["racers"] as Array).has(peer_id)


## レースに出る全員の、レースの画面ができたか。
func everyone_ready(room: int) -> bool:
	var ready: Dictionary = _rooms[room]["ready"]
	for peer_id: int in present_racers(room):
		if not ready.has(peer_id):
			return false
	return true


## レースに出た全員が、結果を見終わって、レースの画面を出たか。
func everyone_done(room: int) -> bool:
	var done: Dictionary = _rooms[room]["done"]
	for peer_id: int in present_racers(room):
		if not done.has(peer_id):
			return false
	return true


## その部屋で走っているレース（無ければ null）。
func room_race(room: int) -> Node:
	return _rooms[room]["race"] if _rooms.has(room) else null


## 部屋の一覧（作った順）。1部屋ぶん：room_id、name、host_name、count（今いる人数）、capacity（入れる人数）、locked（パスワードがあるか）、racing、phase。
func room_list() -> Array:
	var list: Array = []
	var ids := _rooms.keys()
	ids.sort()
	for room: int in ids:
		var data: Dictionary = _rooms[room]
		if bool(data.get("free", false)):
			continue
		list.append({
			"room_id": room, "name": str(data["name"]), "host_name": str(_peers[int(data["host"])]["name"]),
			"count": (data["order"] as Array).size(), "capacity": Protocol.ROOM_CAPACITY,
			"locked": not str(data["password"]).is_empty(), "racing": data["race"] != null,
			"phase": str(data["phase"]), "description": str(data["description"]),
		})
	return list


func _process(delta: float) -> void:
	while _tcp.is_connection_available():
		var socket := WebSocketPeer.new()
		if socket.accept_stream(_tcp.take_connection()) == OK:
			_peers[_next_peer_id] = {
				"socket": socket, "name": "", "room": 0, "introduction": "", "icon": clean_icon({}),
				# オンラインフリー対戦：ロビーにいるか、出るぷるりん、入りたいルーム（前ほど優先）、待ち始めた時刻（ミリ秒。待っていなければ0）、
				# 呼ばれているルーム（ID。無ければ空）とその返事の締め切り（ミリ秒）、入ると答えた・走っているルームの部屋の番号（無ければ0）。
				"free": false, "free_pick": "", "wishes": [], "wait_since_msec": 0, "offer": "", "offer_until_msec": 0, "free_room": 0,
			}
			_next_peer_id += 1
	for peer_id: int in _peers.keys():
		if not _peers.has(peer_id):
			continue
		var socket: WebSocketPeer = _peers[peer_id]["socket"]
		socket.poll()
		match socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while _peers.has(peer_id) and socket.get_available_packet_count() > 0:
					_receive(peer_id, socket.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_drop(peer_id)
	for room: int in _rooms.keys():
		_update_race(room, delta)
	_update_free(delta)


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
			_hello(peer_id, data)
			return
		Protocol.ADMIN:
			_admin(peer_id, data)
			return
	# ここから下は、名乗ってからでないと、できない。
	if str(_peers[peer_id]["name"]).is_empty():
		_refuse(peer_id, Protocol.ERROR_NO_NAME)
		return
	match type:
		Protocol.FREE_ENTER:
			_free_enter(peer_id)
			return
		Protocol.FREE_LEAVE:
			_free_leave(peer_id)
			_send_lobby(peer_id)
			return
		Protocol.FREE_PICK, Protocol.FREE_WISH, Protocol.FREE_ANSWER:
			if not bool(_peers[peer_id]["free"]):
				_refuse(peer_id, Protocol.ERROR_NOT_IN_FREE)
				return
			match type:
				Protocol.FREE_PICK: _free_pick(peer_id, data)
				Protocol.FREE_WISH: _free_wish(peer_id, data)
				Protocol.FREE_ANSWER: _free_answer(peer_id, data)
			return
		Protocol.CREATE:
			_free_leave(peer_id)
			_create(peer_id, data)
			return
		Protocol.JOIN:
			_free_leave(peer_id)
			_join(peer_id, data)
			return
		Protocol.PEEK:
			_peek(peer_id, data)
			return
		Protocol.LEAVE:
			_leave_room(peer_id)
			_send_lobby(peer_id)
			return
	# フリーのルームのレースに出ている人の、レースの文。
	if bool(_peers[peer_id]["free"]):
		_free_race_message(peer_id, type, data)
		return
	# ここから下は、部屋に入ってからでないと、できない。
	var room := int(_peers[peer_id]["room"])
	if room == 0:
		_refuse(peer_id, Protocol.ERROR_NOT_IN_ROOM if type in ROOM_MESSAGES else Protocol.ERROR_BAD_MESSAGE)
		return
	match type:
		Protocol.PROFILE: _send_profile(peer_id, room, data)
		Protocol.PICK: _pick(peer_id, room, data)
		Protocol.CPU_PICK: _cpu_pick(peer_id, room, data)
		Protocol.SETTINGS: _set_settings(peer_id, room, data)
		Protocol.KICK: _kick(peer_id, room, data)
		Protocol.LOBBY_READY: _lobby_ready(peer_id, room, data)
		Protocol.RACE_OPEN: _race_open(peer_id, room)
		Protocol.PICK_OPEN: _pick_open(peer_id, room)
		Protocol.CHAT: _chat(peer_id, room, data)
		Protocol.CONFIRM: _confirm(peer_id, room, data)
		Protocol.ENTRIES: _open_entries(peer_id, room)
		Protocol.GATES: _change_gates(peer_id, room, data)
		Protocol.BACK: _back_to_room(peer_id, room, data)
		Protocol.START: _start_race(peer_id, room)
		Protocol.INPUT: _race_input(peer_id, room, data)
		Protocol.ACTION: _race_action(peer_id, room, data)
		Protocol.READY: if is_racer(room, peer_id): (_rooms[room]["ready"] as Dictionary)[peer_id] = true
		Protocol.RACE_DONE: (_rooms[room]["done"] as Dictionary)[peer_id] = true
		_: _refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)


## 部屋の中でだけ使える文の種類。
const ROOM_MESSAGES := [Protocol.LOBBY_READY, Protocol.RACE_OPEN, Protocol.PICK_OPEN, Protocol.RACE_DONE, Protocol.PROFILE, Protocol.CPU_PICK, Protocol.PICK, Protocol.SETTINGS, Protocol.KICK, Protocol.CHAT, Protocol.CONFIRM, Protocol.ENTRIES, Protocol.GATES, Protocol.BACK, Protocol.START, Protocol.INPUT, Protocol.ACTION, Protocol.READY]


## 名乗って、部屋の一覧の所に入る。
func _hello(peer_id: int, data: Dictionary) -> void:
	var player_name := Protocol.clean_text(data.get("name", ""), Protocol.NAME_MAX_LENGTH)
	if player_name.is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_peers[peer_id]["name"] = player_name
	_peers[peer_id]["introduction"] = Protocol.clean_text(data.get("introduction", ""), Protocol.INTRODUCTION_MAX_LENGTH)
	_peers[peer_id]["icon"] = clean_icon(data.get("icon", {}))
	var room := int(_peers[peer_id]["room"])
	if room != 0:
		# 部屋にいる人が名前を変えたら、部屋の人と、一覧を見ている人に知らせる。
		_announce_room(room)
		_announce_rooms()
		return
	_send_lobby(peer_id)


## 届いたアイコンを、決まりの形にそろえる。知らない種類・大きすぎる画像は、画像なしにする。
## 画像の中身は、サーバーでは開かない（そのまま、同じ部屋の人へ渡すだけ）。
static func clean_icon(value: Variant) -> Dictionary:
	var none := {"kind": "none", "id": "", "image": ""}
	if not value is Dictionary:
		return none
	var kind := str(value.get("kind", "none"))
	if not kind in Protocol.ICON_KINDS:
		return none
	var image := str(value.get("image", "")) if kind == "file" else ""
	if kind == "file" and (image.is_empty() or image.length() > Protocol.ICON_IMAGE_MAX_CHARS):
		return none
	return {"kind": kind, "id": str(value.get("id", "")).left(32) if kind == "avatar" else "", "image": image}


## 同じ部屋の人の紹介を返す。
func _send_profile(peer_id: int, room: int, data: Dictionary) -> void:
	var target := int(data.get("peer_id", 0))
	if not (_rooms[room]["order"] as Array).has(target):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_send(peer_id, Protocol.message(Protocol.PROFILE_INFO, {
		"peer_id": target, "name": str(_peers[target]["name"]),
		"introduction": str(_peers[target]["introduction"]), "icon": _peers[target]["icon"],
	}))


## 部屋を作る。作った人が、部屋の主。
func _create(peer_id: int, data: Dictionary) -> void:
	var room_name := Protocol.clean_text(data.get("room_name", ""), Protocol.ROOM_NAME_MAX_LENGTH)
	if room_name.is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var current := int(_peers[peer_id]["room"])
	# 自分しかいない部屋から作り直すときは、その部屋が消えるぶん、上限に数えない。
	var leaving_empties_room := current != 0 and (_rooms[current]["order"] as Array).size() == 1
	if room_count() - (1 if leaving_empties_room else 0) >= OnlineConfig.max_rooms():
		_refuse(peer_id, Protocol.ERROR_ROOMS_FULL)
		return
	for other: int in _rooms:
		if bool(_rooms[other].get("free", false)):
			continue
		if str(_rooms[other]["name"]) == room_name and not (other == current and leaving_empties_room):
			_refuse(peer_id, Protocol.ERROR_ROOM_NAME_TAKEN)
			return
	_leave_room(peer_id)
	var room := _next_room_id
	_next_room_id += 1
	_rooms[room] = {
		"name": room_name, "password": Protocol.clean_text(data.get("password", ""), Protocol.PASSWORD_MAX_LENGTH),
		"description": Protocol.clean_text(data.get("description", ""), Protocol.ROOM_DESCRIPTION_MAX_LENGTH),
		"host": peer_id, "order": [], "distance_m": RaceSession.DEFAULT_DISTANCE_M,
		"seats": [], "picks": {}, "racers": [], "lobby_ready": {},
		"phase": Protocol.PHASE_LOBBY, "confirmed": {}, "entries": [], "cpu_picks": [],
		"race": null, "log": null, "state_wait_s": 0.0, "ready": {}, "ready_wait_s": 0.0,
		"result_sent": false, "linger_s": 0.0, "done": {},
	}
	_enter(peer_id, room)


## 一覧の部屋の、くわしい紹介を返す（入る前に、入るか決めるため）。画像は大きいので、一覧には入れず、ここで返す。
func _peek(peer_id: int, data: Dictionary) -> void:
	var room := int(data.get("room_id", 0))
	if not _rooms.has(room) or bool(_rooms[room].get("free", false)):
		_refuse(peer_id, Protocol.ERROR_NO_ROOM)
		return
	var data_room: Dictionary = _rooms[room]
	var host: Dictionary = _peers[int(data_room["host"])]
	_send(peer_id, Protocol.message(Protocol.ROOM_INFO, {
		"room_id": room, "name": str(data_room["name"]), "host_name": str(host["name"]), "host_icon": host["icon"],
		"count": (data_room["order"] as Array).size(), "capacity": Protocol.ROOM_CAPACITY,
		"description": str(data_room["description"]), "locked": not str(data_room["password"]).is_empty(),
		"racing": data_room["race"] != null, "phase": str(data_room["phase"]),
	}))


## 部屋に入る。無い部屋・パスワード違い・満員は、断る。レースの最中でも入れる（入った人は、待機室で次を待つ）。
func _join(peer_id: int, data: Dictionary) -> void:
	var room := int(data.get("room_id", 0))
	if not _rooms.has(room) or bool(_rooms[room].get("free", false)):
		_refuse(peer_id, Protocol.ERROR_NO_ROOM)
		return
	if int(_peers[peer_id]["room"]) == room:
		_send(peer_id, Protocol.message(Protocol.WELCOME, _room_fields(room, {"peer_id": peer_id})))
		return
	var password := str(_rooms[room]["password"])
	if not password.is_empty() and str(data.get("password", "")) != password:
		_refuse(peer_id, Protocol.ERROR_WRONG_PASSWORD)
		return
	if (_rooms[room]["order"] as Array).size() >= Protocol.ROOM_CAPACITY:
		_refuse(peer_id, Protocol.ERROR_ROOM_FULL)
		return
	_leave_room(peer_id)
	_enter(peer_id, room)


func _enter(peer_id: int, room: int) -> void:
	_peers[peer_id]["room"] = room
	# 先にいた人たちに、入ったことを知らせる。
	_notify(room, Protocol.NOTICE_JOINED, str(_peers[peer_id]["name"]))
	(_rooms[room]["order"] as Array).append(peer_id)
	_send(peer_id, Protocol.message(Protocol.WELCOME, _room_fields(room, {"peer_id": peer_id})))
	_announce_room(room)
	_announce_rooms()


func _drop(peer_id: int) -> void:
	_free_leave(peer_id)
	_leave_room(peer_id, Protocol.NOTICE_DISCONNECTED)
	_peers.erase(peer_id)


## 今いる部屋から抜ける。部屋の主が抜けたら、次に古い人が主になる。誰もいなくなった部屋は、消す。
## how は、残った人への知らせの種類（出た・切れた・退出させられた）。by は、退出させた側（"host" か "admin"）。
func _leave_room(peer_id: int, how: String = Protocol.NOTICE_LEFT, by: String = "") -> void:
	var room := int(_peers[peer_id]["room"])
	if room == 0:
		return
	_peers[peer_id]["room"] = 0
	var was_racer := is_racer(room, peer_id)
	(_rooms[room]["order"] as Array).erase(peer_id)
	(_rooms[room]["picks"] as Dictionary).erase(peer_id)
	(_rooms[room]["ready"] as Dictionary).erase(peer_id)
	(_rooms[room]["done"] as Dictionary).erase(peer_id)
	(_rooms[room]["lobby_ready"] as Dictionary).erase(peer_id)
	if room_race(room) == null:
		(_rooms[room]["racers"] as Array).erase(peer_id)
		# レースに出る人が抜けたら、出走表は作り直し（ぷるりんを選ぶ所へ戻して、全員の確定を外す）。
		# 主が抜けたとき・出る人がいなくなったときは、待機室へ戻す（レース設定を決める人がいなくなるため）。
		if was_racer and str(_rooms[room]["phase"]) == Protocol.PHASE_ENTRIES:
			_reset_to_room_phase(room)
		if was_racer and (int(_rooms[room]["host"]) == peer_id or (_rooms[room]["racers"] as Array).is_empty()):
			_reset_to_lobby(room)
	# レース中に抜けた人の走者は、その個体のCPUトレーナーに任せる。
	if room_race(room) != null:
		room_race(room).call("release_remote_runner", peer_id)
		_log_event(room, "left", {"peer_id": peer_id, "name": str(_peers[peer_id]["name"]), "how": how, "handed_to_cpu": true})
	var order: Array = _rooms[room]["order"]
	if order.is_empty():
		_close_room(room)
		return
	# 残った人に、だれが抜けたかを知らせる。主が替わったら、それも知らせる。
	_notify(room, how, str(_peers[peer_id]["name"]), by)
	if int(_rooms[room]["host"]) == peer_id:
		_rooms[room]["host"] = int(order[0])
		_notify(room, Protocol.NOTICE_HOST, str(_peers[int(order[0])]["name"]))
	_announce_room(room)
	_announce_rooms()


## 部屋を消す（中の人は、先に出しておく）。
func _close_room(room: int) -> void:
	_end_race(room)
	_rooms.erase(room)
	_announce_rooms()


## 自分のぷるりんを選ぶ。ほかの人やCPUと、同じプルでもよい。
func _pick(peer_id: int, room: int, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if not is_racer(room, peer_id):
		_refuse(peer_id, Protocol.ERROR_NOT_RACER)
		return
	if str(_rooms[room]["phase"]) != Protocol.PHASE_ROOM:
		_refuse(peer_id, Protocol.ERROR_IN_ENTRIES if str(_rooms[room]["phase"]) == Protocol.PHASE_ENTRIES else Protocol.ERROR_WRONG_PHASE)
		return
	var pururin_id := str(data.get("pururin_id", ""))
	if PururinRosterConfig.pururin_by_id(pururin_id).is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	# 同じプルを、ほかの人やCPUと重ねて選んでもよい。
	(_rooms[room]["picks"] as Dictionary)[peer_id] = pururin_id
	# 選び直したら、自分の確定は外れる。
	(_rooms[room]["confirmed"] as Dictionary).erase(peer_id)
	_announce_room(room)


## CPUのプルを決める（部屋の主だけ。プル選択でだけ）。index は何番目のCPUか。トレーナーは、そのプルのデフォルトで、変えられない。
## ほかと同じプルでもよい。決めたら、全員の確定を外す。
func _cpu_pick(peer_id: int, room: int, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return
	if str(_rooms[room]["phase"]) != Protocol.PHASE_ROOM:
		_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
		return
	var pururin_id := str(data.get("pururin_id", ""))
	if data.has("trainer_id") or (not pururin_id.is_empty() and PururinRosterConfig.pururin_by_id(pururin_id).is_empty()):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var index := int(data.get("index", -1))
	if index < 0 or index >= cpu_slot_count(room):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var picks: Array = _rooms[room]["cpu_picks"]
	while picks.size() <= index:
		picks.append({"pururin_id": "", "trainer_id": ""})
	picks[index]["pururin_id"] = pururin_id
	(_rooms[room]["confirmed"] as Dictionary).clear()
	_announce_room(room)


## その部屋のCPUの数（レース設定で、CPUを入れると決めた席の数）。待機室では0。
func cpu_slot_count(room: int) -> int:
	if str(_rooms[room]["phase"]) == Protocol.PHASE_LOBBY:
		return 0
	return (_rooms[room]["seats"] as Array).count(true)


## レースの出走数（出る人と、CPUの席）。待機室では、入れる人数の上限。
func field_size(room: int) -> int:
	if str(_rooms[room]["phase"]) == Protocol.PHASE_LOBBY:
		return Protocol.ROOM_CAPACITY
	return (_rooms[room]["racers"] as Array).size() + cpu_slot_count(room)


## 部屋のCPUの一覧（CPUの数ぶん。主が決めていない所は、空の文字＝おまかせ）。
func room_cpus(room: int) -> Array:
	var cpus: Array = []
	var picks: Array = _rooms[room]["cpu_picks"]
	for index in cpu_slot_count(room):
		cpus.append((picks[index] as Dictionary).duplicate() if index < picks.size() else {"pururin_id": "", "trainer_id": ""})
	return cpus


## 部屋の決めごとを変える（部屋の主だけ。届いた項目だけ変える。1つでも受け付けられない値があれば、何も変えない）。
func _set_settings(peer_id: int, room: int, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return
	var changes := {}
	# 距離と席は、レース設定でだけ変えられる。
	if (data.has("distance_m") or data.has("seats")) and str(_rooms[room]["phase"]) != Protocol.PHASE_SETTINGS:
		_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
		return
	if data.has("distance_m"):
		var distance := float(data["distance_m"])
		if not RaceSession.supported_distances_m().has(distance):
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
			return
		changes["distance_m"] = distance
	if data.has("seats"):
		var seats: Variant = data["seats"]
		if not seats is Array or (seats as Array).size() != (_rooms[room]["seats"] as Array).size():
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
			return
		var cleaned: Array = []
		for seat: Variant in seats:
			cleaned.append(bool(seat))
		changes["seats"] = cleaned
	if data.has("password"):
		changes["password"] = Protocol.clean_text(data["password"], Protocol.PASSWORD_MAX_LENGTH)
	if data.has("description"):
		changes["description"] = Protocol.clean_text(data["description"], Protocol.ROOM_DESCRIPTION_MAX_LENGTH)
	for key: String in changes:
		_rooms[room][key] = changes[key]
	if changes.has("seats"):
		_rooms[room]["cpu_picks"] = []
	_announce_room(room)
	_announce_rooms()


## 部屋の人を出す（部屋の主だけ。自分は出せない）。
func _kick(peer_id: int, room: int, data: Dictionary) -> void:
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return
	var target := int(data.get("peer_id", 0))
	if target == peer_id or not (_rooms[room]["order"] as Array).has(target):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_put_out(target, Protocol.KICKED_BY_HOST)


## その人を、部屋から出して、部屋の一覧の所へ戻す。
func _put_out(peer_id: int, by: String) -> void:
	_send(peer_id, Protocol.message(Protocol.KICKED, {"by": by}))
	_leave_room(peer_id, Protocol.NOTICE_KICKED, by)
	_send_lobby(peer_id)


## 部屋の中の、ひとこと。レースの最中も、待機室の人どうしで話せるように、いつでも配る。
func _chat(peer_id: int, room: int, data: Dictionary) -> void:
	var text := Protocol.clean_text(data.get("text", ""), OnlineConfig.chat_max_length())
	if text.is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_send_room(room, Protocol.message(Protocol.CHAT_MESSAGE, {"peer_id": peer_id, "name": str(_peers[peer_id]["name"]), "text": text}))


## 「確定」を押す・外す。部屋では、ぷるりんを選んでからでないと、確定できない。
func _confirm(peer_id: int, room: int, data: Dictionary) -> void:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return
	if not is_racer(room, peer_id) or not str(_rooms[room]["phase"]) in [Protocol.PHASE_ROOM, Protocol.PHASE_ENTRIES]:
		_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
		return
	var confirmed: Dictionary = _rooms[room]["confirmed"]
	if not bool(data.get("on", true)):
		confirmed.erase(peer_id)
	elif str(_rooms[room]["phase"]) == Protocol.PHASE_ROOM and not (_rooms[room]["picks"] as Dictionary).has(peer_id):
		_refuse(peer_id, Protocol.ERROR_NOT_READY)
		return
	else:
		confirmed[peer_id] = true
	_announce_room(room)


## レースに出る全員が「確定」を押しているか。
func everyone_confirmed(room: int) -> bool:
	var confirmed: Dictionary = _rooms[room]["confirmed"]
	for peer_id: int in _rooms[room]["racers"]:
		if not confirmed.has(peer_id):
			return false
	return true


## 部屋の主かどうかと、場面を確かめる。だめなら、断って false。
func _host_in_phase(peer_id: int, room: int, phase: String) -> bool:
	if room_race(room) != null:
		_refuse(peer_id, Protocol.ERROR_RACING)
		return false
	if int(_rooms[room]["host"]) != peer_id:
		_refuse(peer_id, Protocol.ERROR_NOT_HOST)
		return false
	if str(_rooms[room]["phase"]) != phase:
		var code := Protocol.ERROR_WRONG_PHASE
		if phase == Protocol.PHASE_ROOM and str(_rooms[room]["phase"]) == Protocol.PHASE_ENTRIES:
			code = Protocol.ERROR_IN_ENTRIES
		elif phase == Protocol.PHASE_ENTRIES:
			code = Protocol.ERROR_NOT_IN_ENTRIES
		_refuse(peer_id, code)
		return false
	return true


## 出走表へ進む（部屋の主だけ）。全員が選び終わって、確定していること。CPUの個体が決まり、枠順を、くじで決める。
func _open_entries(peer_id: int, room: int) -> void:
	if not _host_in_phase(peer_id, room, Protocol.PHASE_ROOM):
		return
	for member: Dictionary in racer_members(room):
		if str(member["pururin_id"]).is_empty():
			_refuse(peer_id, Protocol.ERROR_NOT_READY)
			return
	if not everyone_confirmed(room):
		_refuse(peer_id, Protocol.ERROR_NOT_CONFIRMED)
		return
	var entries := build_entries(room)
	if entries.size() < Protocol.FIELD_SIZE_MIN:
		_refuse(peer_id, Protocol.ERROR_TOO_FEW)
		return
	entries.shuffle()
	_rooms[room]["entries"] = _with_gates(entries)
	_rooms[room]["phase"] = Protocol.PHASE_ENTRIES
	(_rooms[room]["confirmed"] as Dictionary).clear()
	_announce_room(room)
	_announce_rooms()


## 並びの順に、枠の番号（0から）を振り直す。
static func _with_gates(entries: Array) -> Array:
	for index in entries.size():
		entries[index]["gate"] = index
	return entries


## 出走表の枠順を変える（部屋の主だけ）。くじを引き直すか、2つの枠を入れ替える。変えたら、全員の確定を外す。
func _change_gates(peer_id: int, room: int, data: Dictionary) -> void:
	if not _host_in_phase(peer_id, room, Protocol.PHASE_ENTRIES):
		return
	var entries: Array = _rooms[room]["entries"]
	match str(data.get("action", "")):
		Protocol.GATES_SHUFFLE:
			entries.shuffle()
		Protocol.GATES_SWAP:
			var a := int(data.get("a", -1))
			var b := int(data.get("b", -1))
			if a < 0 or b < 0 or a >= entries.size() or b >= entries.size() or a == b:
				_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
				return
			var moved: Dictionary = entries[a]
			entries[a] = entries[b]
			entries[b] = moved
		_:
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
			return
	_rooms[room]["entries"] = _with_gates(entries)
	(_rooms[room]["confirmed"] as Dictionary).clear()
	_announce_room(room)


## 待機室へ戻る。レース設定・プル選択から（主は全員を戻す。ほかの人は、自分だけレースから抜ける）。
## パドックからは、to＝"lobby" を付けて送る。
func _back_to_room(peer_id: int, room: int, data: Dictionary = {}) -> void:
	# レースの途中でやめた人（主も同じ）：待機室へ。その人の走者は、その個体のCPUトレーナーが最後まで走る。
	if str(data.get("to", "")) == Protocol.BACK_TO_LOBBY and room_race(room) != null and is_racer(room, peer_id):
		(_rooms[room]["racers"] as Array).erase(peer_id)
		room_race(room).call("release_remote_runner", peer_id)
		_log_event(room, "quit_race", {"peer_id": peer_id, "name": str(_peers[peer_id]["name"]), "handed_to_cpu": true})
		_announce_room(room)
		_announce_rooms()
		return
	# to＝"lobby"：パドックからでも、待機室へ戻る（主は全員、ほかの人は自分だけ）。
	if str(data.get("to", "")) == Protocol.BACK_TO_LOBBY and room_race(room) == null:
		var phase := str(_rooms[room]["phase"])
		if not phase in [Protocol.PHASE_SETTINGS, Protocol.PHASE_ROOM, Protocol.PHASE_ENTRIES]:
			_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
			return
		if int(_rooms[room]["host"]) == peer_id:
			_reset_to_lobby(room)
		elif is_racer(room, peer_id):
			_leave_race(room, peer_id)
			# パドックで人が抜けたら、出走表は作り直し（プル選択へ戻る）。
			if phase == Protocol.PHASE_ENTRIES:
				_reset_to_room_phase(room)
		else:
			_refuse(peer_id, Protocol.ERROR_NOT_RACER)
			return
		_announce_room(room)
		_announce_rooms()
		return
	if str(_rooms[room]["phase"]) in [Protocol.PHASE_SETTINGS, Protocol.PHASE_ROOM] and int(_rooms[room]["host"]) != peer_id and is_racer(room, peer_id):
		_leave_race(room, peer_id)
		_announce_room(room)
		_announce_rooms()
		return
	if not str(_rooms[room]["phase"]) in [Protocol.PHASE_SETTINGS, Protocol.PHASE_ROOM]:
		_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
		return
	if not _host_in_phase(peer_id, room, str(_rooms[room]["phase"])):
		return
	_reset_to_lobby(room)
	_announce_room(room)
	_announce_rooms()


## レース設定・プル選択から、自分だけレースを抜けて、待機室へ戻る。空いた席は、CPUの席として足す（主が切り替えられる）。
func _leave_race(room: int, peer_id: int) -> void:
	(_rooms[room]["racers"] as Array).erase(peer_id)
	(_rooms[room]["lobby_ready"] as Dictionary).erase(peer_id)
	(_rooms[room]["picks"] as Dictionary).erase(peer_id)
	(_rooms[room]["confirmed"] as Dictionary).erase(peer_id)
	(_rooms[room]["seats"] as Array).append(true)


## 待機室の「準備OK」を押す・外す。
func _lobby_ready(peer_id: int, room: int, data: Dictionary) -> void:
	if str(_rooms[room]["phase"]) != Protocol.PHASE_LOBBY and is_racer(room, peer_id):
		_refuse(peer_id, Protocol.ERROR_WRONG_PHASE)
		return
	if bool(data.get("on", true)):
		(_rooms[room]["lobby_ready"] as Dictionary)[peer_id] = true
	else:
		(_rooms[room]["lobby_ready"] as Dictionary).erase(peer_id)
	_announce_room(room)


## 待機室から、レースへ進む（部屋の主だけ）。準備OKの人と主が、レースに出る人になって、レース設定へ進む。
## 全員に「部屋主がレース開始を押した」と知らせる。準備OKでない人は、待機室に残る。
func _race_open(peer_id: int, room: int) -> void:
	if not _host_in_phase(peer_id, room, Protocol.PHASE_LOBBY):
		return
	var racers: Array = []
	var ready: Dictionary = _rooms[room]["lobby_ready"]
	for member: int in _rooms[room]["order"]:
		if member == peer_id or ready.has(member):
			racers.append(member)
	_rooms[room]["racers"] = racers
	# 人の足りない席は、はじめは全部CPU。
	var seats: Array = []
	for _seat in maxi(Protocol.ROOM_CAPACITY - racers.size(), 0):
		seats.append(true)
	_rooms[room]["seats"] = seats
	_rooms[room]["cpu_picks"] = []
	# レースに出る人には、はじめから一覧の1番目のプルを入れておく（「未選択」にしない）。前に使ったプルがある人は、自分で送ってくる。
	var picks := {}
	for racer: int in racers:
		picks[racer] = str(PururinRosterConfig.values()["roster"][0]["id"])
	_rooms[room]["picks"] = picks
	(_rooms[room]["confirmed"] as Dictionary).clear()
	_rooms[room]["phase"] = Protocol.PHASE_SETTINGS
	_notify(room, Protocol.NOTICE_RACE_OPEN, str(_peers[peer_id]["name"]))
	_announce_room(room)
	_announce_rooms()


## レース設定を終えて、ぷるりんを選ぶ所へ進む（部屋の主だけ）。出走が2体に足りなければ、断る。
func _pick_open(peer_id: int, room: int) -> void:
	if not _host_in_phase(peer_id, room, Protocol.PHASE_SETTINGS):
		return
	if field_size(room) < Protocol.FIELD_SIZE_MIN:
		_refuse(peer_id, Protocol.ERROR_TOO_FEW)
		return
	_rooms[room]["phase"] = Protocol.PHASE_ROOM
	_announce_room(room)
	_announce_rooms()


## ぷるりんを選ぶ所へ戻して、出走表と、全員の確定を消す。
func _reset_to_room_phase(room: int) -> void:
	_rooms[room]["phase"] = Protocol.PHASE_ROOM
	_rooms[room]["entries"] = []
	(_rooms[room]["confirmed"] as Dictionary).clear()


## 待機室へ戻す。レースに出る人・準備OK・選んだぷるりん・出走表・確定を、全部消す。
func _reset_to_lobby(room: int) -> void:
	_rooms[room]["phase"] = Protocol.PHASE_LOBBY
	_rooms[room]["racers"] = []
	_rooms[room]["seats"] = []
	_rooms[room]["picks"] = {}
	_rooms[room]["cpu_picks"] = []
	_rooms[room]["entries"] = []
	(_rooms[room]["confirmed"] as Dictionary).clear()
	(_rooms[room]["lobby_ready"] as Dictionary).clear()


## 管理人の命令。合い札が合わなければ、断る。
## list＝部屋と、中の人の一覧。kick＝その人を、部屋から出す。close＝部屋を閉じる（中の人は、全員、一覧の所へ戻す）。
func _admin(peer_id: int, data: Dictionary) -> void:
	if admin_token.is_empty() or str(data.get("token", "")) != admin_token:
		_refuse(peer_id, Protocol.ERROR_NOT_ADMIN)
		return
	var command := str(data.get("command", ""))
	match command:
		Protocol.ADMIN_LIST:
			var rooms := room_list()
			for entry: Dictionary in rooms:
				entry["members"] = room_members(int(entry["room_id"]))
			_send(peer_id, Protocol.message(Protocol.ADMIN_RESULT, {"command": command, "rooms": rooms, "peers": _peers.size()}))
		Protocol.ADMIN_KICK:
			var target := int(data.get("peer_id", 0))
			var done := _peers.has(target) and int(_peers[target]["room"]) != 0
			if done:
				_put_out(target, Protocol.KICKED_BY_ADMIN)
			_send(peer_id, Protocol.message(Protocol.ADMIN_RESULT, {"command": command, "done": done}))
		Protocol.ADMIN_CLOSE:
			var room := int(data.get("room_id", 0))
			var found := _rooms.has(room)
			if found:
				for member: int in (_rooms[room]["order"] as Array).duplicate():
					_put_out(member, Protocol.KICKED_BY_ADMIN)
			_send(peer_id, Protocol.message(Protocol.ADMIN_RESULT, {"command": command, "done": found}))
		_:
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)


# ---------------------------------------------------------------- レース

## その部屋の出走の一覧を組む。レースに出る人は、レース開始のときの並びで1枠から。CPUの席は、
## まだ選ばれていない個体で、一覧の順に埋める。
func build_entries(room: int) -> Array:
	var entries: Array = []
	var used := {}
	for member: Dictionary in racer_members(room):
		var pururin := PururinRosterConfig.pururin_by_id(str(member["pururin_id"]))
		used[str(member["pururin_id"])] = true
		entries.append(_entry(entries.size(), pururin, int(member["peer_id"]), str(member["name"])))
	# CPU：主が決めた個体は、そのまま。「おまかせ」の所は、まだ使われていない個体を、一覧の順に入れる。
	var cpus := room_cpus(room)
	for cpu: Dictionary in cpus:
		used[str(cpu["pururin_id"])] = true
	for cpu: Dictionary in cpus:
		var pururin := PururinRosterConfig.pururin_by_id(str(cpu["pururin_id"]))
		if pururin.is_empty():
			for candidate: Dictionary in PururinRosterConfig.values()["roster"]:
				if not used.has(str(candidate["id"])):
					pururin = candidate
					used[str(candidate["id"])] = true
					break
		# 個体が足りなければ、一覧の最初から、重ねて使う。
		if pururin.is_empty():
			pururin = PururinRosterConfig.values()["roster"][entries.size() % (PururinRosterConfig.values()["roster"] as Array).size()]
		entries.append(_entry(entries.size(), pururin, 0, ""))
	return _with_runner_ids(entries)


## 走者の番号（runner_id）を付ける。同じプルが何体いても、レースの中で見分けられるように、
## 1体目はプルの番号のまま、2体目からは「番号#2」「番号#3」…。
static func _with_runner_ids(entries: Array) -> Array:
	var counts := {}
	for entry: Dictionary in entries:
		var id := str(entry["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		entry["runner_id"] = id if int(counts[id]) == 1 else "%s#%d" % [id, int(counts[id])]
	return entries


## 出走の1体ぶん。人（peer_id が0でない）は、name に、その人の名前。CPUは、その個体のトレーナー（name_or_trainer は空）。
static func _entry(gate: int, pururin: Dictionary, peer_id: int, name_or_trainer: String) -> Dictionary:
	var trainer_id := str(pururin["trainer_id"])
	if peer_id == 0 and not name_or_trainer.is_empty():
		trainer_id = name_or_trainer
	var trainer := CpuTrainers.by_id(trainer_id)
	return {
		"gate": gate, "id": str(pururin["id"]), "player": peer_id != 0, "peer_id": peer_id,
		"trainer_id": trainer_id, "trainer_profile_id": str(trainer.get("profile_id", "")),
		"trainer_name": name_or_trainer if peer_id != 0 else str(trainer.get("name", "")),
	}


## レースを始める（部屋の主だけ）。出走表で、全員が確定していること。出走と枠順は、出走表のとおり。
func _start_race(peer_id: int, room: int) -> void:
	if not _host_in_phase(peer_id, room, Protocol.PHASE_ENTRIES):
		return
	if not everyone_confirmed(room):
		_refuse(peer_id, Protocol.ERROR_NOT_CONFIRMED)
		return
	_launch_race(room, (_rooms[room]["entries"] as Array).duplicate(true), float(_rooms[room]["distance_m"]))


## 出走表のとおりに、その部屋のレースを作って、レースに出る人に知らせる（ともだち対戦の部屋と、フリーのルームで共通）。
func _launch_race(room: int, entries: Array, distance: float) -> void:
	# レースの場面は、作られるときに、出走と距離を読む。作り終わったら、出走の指定は戻す。
	RaceSession.select_distance(distance)
	RaceSession.set_course_only(true)
	RaceSession.set_online_entries(entries)
	var race: Node = LocalRaceScene.instantiate()
	race.name = "Race_%d" % room
	add_child(race)
	RaceSession.set_online_entries([])
	# 全員のレースの画面ができるまで、スタートへ向かう時計を止めておく。
	race.call("hold_start")
	_rooms[room]["race"] = race
	_rooms[room]["state_wait_s"] = 0.0
	_rooms[room]["ready"] = {}
	_rooms[room]["ready_wait_s"] = 0.0
	_rooms[room]["result_sent"] = false
	_rooms[room]["linger_s"] = 0.0
	_rooms[room]["done"] = {}
	# レースの記録を始める（部屋・出走・人の情報を、頭に入れる）。
	var log := OnlineRaceLog.new()
	var people: Array = []
	for member: Dictionary in racer_members(room):
		var peer := int(member["peer_id"])
		people.append({"peer_id": peer, "name": str(member["name"]), "pururin_id": str(member["pururin_id"]), "introduction": str(_peers[peer].get("introduction", "")), "icon_kind": str((_peers[peer].get("icon", {}) as Dictionary).get("kind", "none"))})
	log.start({
		"room_id": room, "room_name": str(_rooms[room]["name"]), "host_peer_id": int(_rooms[room]["host"]),
		"distance_m": distance, "field_size": field_size(room), "seats": (_rooms[room]["seats"] as Array).duplicate(),
		"cpu_picks": room_cpus(room), "entries": entries, "people": people,
	})
	_rooms[room]["log"] = log
	_send_racers(room, Protocol.message(Protocol.RACE_START, {"distance_m": distance, "entries": entries}))
	_announce_room(room)
	_announce_rooms()


## レース中の操作。レースが無い・自分の走者がいないときは、だまって捨てる（終わりぎわに届いた操作のため）。
func _race_input(peer_id: int, room: int, data: Dictionary) -> void:
	var race := room_race(room)
	if race != null:
		race.call("set_remote_input", peer_id, float(data.get("line", 0.0)), float(data.get("notch", 0.0)), bool(data.get("brake", false)))
		var log: OnlineRaceLog = _rooms[room].get("log")
		if log != null:
			log.record_input(float(race.get("_race_elapsed")), peer_id, float(data.get("line", 0.0)), float(data.get("notch", 0.0)), bool(data.get("brake", false)))


func _race_action(peer_id: int, room: int, data: Dictionary) -> void:
	var race := room_race(room)
	var kind := str(data.get("kind", ""))
	if race != null and kind in [Protocol.ACTION_DASH, Protocol.ACTION_BOOST]:
		race.call("trigger_remote_action", peer_id, kind)
		_log_event(room, kind, {"peer_id": peer_id})


## 走っているレースの状態を、決めた回数で配る。終わったら、着順を配って、レースを片づける。
func _update_race(room: int, delta: float) -> void:
	var race := room_race(room)
	if race == null:
		return
	if bool(race.call("is_race_over")):
		# 結果は、1回だけ配る。そのあとも、しばらくレースを走らせ続けて、位置を配る
		# （ゴール後も、走者が流して走るのを、全員が同じように見られるように）。
		if not bool(_rooms[room]["result_sent"]):
			_rooms[room]["result_sent"] = true
			_send_racers(room, Protocol.message(Protocol.RACE_RESULT, {"rows": race.call("online_result_rows")}))
			_log_event(room, "result", {"rows": race.call("online_result_rows")})
		_rooms[room]["linger_s"] = float(_rooms[room]["linger_s"]) + delta
		# 決めた秒数がたつか、全員が結果を見終わって画面を出たら、レースを片づけて、全員を待機室へ戻す。
		if float(_rooms[room]["linger_s"]) >= OnlineConfig.result_linger_s() or everyone_done(room):
			_send_racers(room, Protocol.message(Protocol.RACE_END))
			_finish_log(room)
			_end_race(room)
			if bool(_rooms[room].get("free", false)):
				_free_race_over(room)
				return
			_reset_to_lobby(room)
			_announce_room(room)
			_announce_rooms()
			return
	if bool(race.call("is_start_held")):
		_rooms[room]["ready_wait_s"] = float(_rooms[room]["ready_wait_s"]) + delta
		if everyone_ready(room) or float(_rooms[room]["ready_wait_s"]) >= Protocol.READY_TIMEOUT_S:
			race.call("release_start_hold")
	var log: OnlineRaceLog = _rooms[room].get("log")
	if log != null:
		log.record(float(race.get("_race_elapsed")), race.get("_runners"))
	_rooms[room]["state_wait_s"] = float(_rooms[room]["state_wait_s"]) - delta
	if float(_rooms[room]["state_wait_s"]) <= 0.0:
		_rooms[room]["state_wait_s"] = 1.0 / Protocol.STATE_RATE_HZ
		_send_racers(room, Protocol.message(Protocol.RACE_STATE, race.call("online_state")))


## レースの記録に、できごとを足す（レースが無ければ、何もしない）。
func _log_event(room: int, kind: String, fields: Dictionary) -> void:
	var race := room_race(room)
	var log: OnlineRaceLog = _rooms[room].get("log") if _rooms.has(room) else null
	if race != null and log != null:
		log.record_event(float(race.get("_race_elapsed")), kind, fields)


## レースの記録を、ファイルに書いて閉じる。途中で終わったレース（全員が抜けた）も、そこまでを残す。
func _finish_log(room: int) -> void:
	var race := room_race(room)
	var log: OnlineRaceLog = _rooms[room].get("log") if _rooms.has(room) else null
	if race == null or log == null or not log.is_recording():
		return
	var rows: Array = race.call("online_result_rows") if bool(race.call("is_race_over")) else []
	var filename := log.finish(float(race.get("_race_elapsed")), race.get("_runners"), rows)
	_rooms[room]["log"] = null
	if not filename.is_empty():
		print("レースの記録：%s" % filename)


func _end_race(room: int) -> void:
	_finish_log(room)
	var race := room_race(room)
	if race != null:
		race.queue_free()
		_rooms[room]["race"] = null


# ---------------------------------------------------------------- オンラインフリー対戦

## ルームが人を呼び始めてから、レースを始めるまでに待つ秒数の上限。
func _fill_wait_s() -> float:
	return fill_wait_s if fill_wait_s >= 0.0 else OnlineConfig.free_fill_wait_s()


## 呼ばれた人の、返事を待つ秒数の上限。
func _answer_wait_s() -> float:
	return answer_wait_s if answer_wait_s >= 0.0 else OnlineConfig.free_answer_wait_s()


## 設定の free_rooms から、フリーのルームを作る（サーバーを起動したときに1回）。並びは、設定の順。
func _make_free_rooms() -> void:
	for spec: Dictionary in OnlineConfig.free_rooms():
		var room := _next_room_id
		_next_room_id += 1
		_rooms[room] = {
			"free": true, "free_id": str(spec["id"]), "name": str(spec["name"]), "password": "", "description": "",
			"host": 0, "order": [], "distance_m": float(spec["distance_m"]),
			"seats": [], "picks": {}, "racers": [], "lobby_ready": {},
			"phase": Protocol.PHASE_ENTRIES, "confirmed": {}, "entries": [], "cpu_picks": [],
			"race": null, "log": null, "state_wait_s": 0.0, "ready": {}, "ready_wait_s": 0.0,
			"result_sent": false, "linger_s": 0.0, "done": {},
			"call_state": Protocol.FREE_STATE_IDLE, "call_s": 0.0, "accepted": [], "pending": {},
		}
		_free_rooms[str(spec["id"])] = room


## そのルームに☑している人の、待っている列（長く待っている順。同じなら、つないだ順）。
func free_line(free_id: String) -> Array:
	var line: Array = []
	for peer_id: int in _peers:
		var peer: Dictionary = _peers[peer_id]
		if bool(peer["free"]) and (peer["wishes"] as Array).has(free_id):
			line.append(peer_id)
	line.sort_custom(_waited_longer)
	return line


func _waited_longer(a: int, b: int) -> bool:
	var wait_a := int(_peers[a]["wait_since_msec"])
	var wait_b := int(_peers[b]["wait_since_msec"])
	return wait_a < wait_b or (wait_a == wait_b and a < b)


## フリーのルームの一覧（設定の順）。peer_id を渡すと、その人が列の何番目か（place。☑していなければ0）も入れる。
func free_room_list(peer_id: int = 0) -> Array:
	var list: Array = []
	for free_id: String in _free_rooms:
		var data: Dictionary = _rooms[int(_free_rooms[free_id])]
		var line := free_line(free_id)
		var racing := str(data["call_state"]) == Protocol.FREE_STATE_RACING
		list.append({
			"room_id": free_id, "name": str(data["name"]), "distance_m": float(data["distance_m"]), "state": str(data["call_state"]),
			"racers": (data["order"] as Array).size() if racing else (data["accepted"] as Array).size(),
			"waiting": line.size(), "place": line.find(peer_id) + 1 if peer_id != 0 else 0,
		})
	return list


## オンラインフリー対戦のロビーに入る（ともだち対戦の部屋にいたら、出る）。
func _free_enter(peer_id: int) -> void:
	if int(_peers[peer_id]["room"]) != 0:
		_leave_room(peer_id)
	_peers[peer_id]["free"] = true
	_send_free_lobby(peer_id)


## オンラインフリー対戦のロビーから出る。呼ばれていたら取り消し、入ると答えたルーム・走っているレースからも抜ける
## （走っていたら、その走者は、その個体のCPUトレーナーに任せる）。☑と、待っている時間は消える。
func _free_leave(peer_id: int) -> void:
	if not _peers.has(peer_id) or not bool(_peers[peer_id]["free"]):
		return
	var peer: Dictionary = _peers[peer_id]
	if not str(peer["offer"]).is_empty():
		(_rooms[int(_free_rooms[str(peer["offer"])])]["pending"] as Dictionary).erase(peer_id)
	var room := int(peer["free_room"])
	if room != 0:
		if room_race(room) != null:
			_free_quit_race(peer_id, room)
		else:
			(_rooms[room]["accepted"] as Array).erase(peer_id)
	peer["free"] = false
	peer["wishes"] = []
	peer["wait_since_msec"] = 0
	peer["offer"] = ""
	peer["free_room"] = 0
	_announce_free()


## 出るぷるりんを選ぶ。
func _free_pick(peer_id: int, data: Dictionary) -> void:
	var pururin_id := str(data.get("pururin_id", ""))
	if PururinRosterConfig.pururin_by_id(pururin_id).is_empty():
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	_peers[peer_id]["free_pick"] = pururin_id
	_send_free_lobby(peer_id)


## 入りたいルームを決める（前ほど優先）。☑が無かった人が☑したら、そのときから待ち始める。全部外したら、待つのをやめる。
func _free_wish(peer_id: int, data: Dictionary) -> void:
	var wished: Variant = data.get("room_ids", [])
	if not wished is Array:
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var wishes: Array = []
	for value: Variant in wished:
		var free_id := str(value)
		if not _free_rooms.has(free_id) or wishes.has(free_id):
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
			return
		wishes.append(free_id)
	var peer: Dictionary = _peers[peer_id]
	if not wishes.is_empty() and str(peer["free_pick"]).is_empty():
		_refuse(peer_id, Protocol.ERROR_NO_PICK)
		return
	if wishes.is_empty():
		peer["wait_since_msec"] = 0
	elif (peer["wishes"] as Array).is_empty():
		peer["wait_since_msec"] = Time.get_ticks_msec()
	peer["wishes"] = wishes
	_announce_free()


## 呼ばれたルームに答える。入る：そのルームのレースに出る人になる。やめる：そのルームの☑だけを外す。
func _free_answer(peer_id: int, data: Dictionary) -> void:
	var peer: Dictionary = _peers[peer_id]
	var free_id := str(data.get("room_id", ""))
	if str(peer["offer"]).is_empty() or free_id != str(peer["offer"]):
		_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	var room := int(_free_rooms[free_id])
	(_rooms[room]["pending"] as Dictionary).erase(peer_id)
	peer["offer"] = ""
	if bool(data.get("accept", false)):
		(_rooms[room]["accepted"] as Array).append(peer_id)
		peer["free_room"] = room
	else:
		(peer["wishes"] as Array).erase(free_id)
		if (peer["wishes"] as Array).is_empty():
			peer["wait_since_msec"] = 0
	_announce_free()


## 毎コマ：返事の締め切りを過ぎた人を外し、呼んでいるルームを始め、空いているルームに人を呼ぶ。
func _update_free(delta: float) -> void:
	if _free_rooms.is_empty():
		return
	var now := Time.get_ticks_msec()
	var changed := false
	# 返事がない人は、ロビーにいないとみなして、全部の☑を外す。
	for peer_id: int in _peers.keys():
		var peer: Dictionary = _peers[peer_id]
		if str(peer["offer"]).is_empty() or now < int(peer["offer_until_msec"]):
			continue
		var free_id := str(peer["offer"])
		(_rooms[int(_free_rooms[free_id])]["pending"] as Dictionary).erase(peer_id)
		peer["offer"] = ""
		peer["wishes"] = []
		peer["wait_since_msec"] = 0
		_send(peer_id, Protocol.message(Protocol.FREE_OFFER_END, {"room_id": free_id, "reason": Protocol.FREE_OFFER_TIMEOUT}))
		changed = true
	# 呼んでいるルーム：満員になるか、決めた秒数がたったら、入ると答えた人で始める（足りない枠は、CPU）。
	for free_id: String in _free_rooms:
		var room := int(_free_rooms[free_id])
		var data: Dictionary = _rooms[room]
		if str(data["call_state"]) != Protocol.FREE_STATE_CALLING:
			continue
		data["call_s"] = float(data["call_s"]) + delta
		if (data["accepted"] as Array).size() >= Protocol.ROOM_CAPACITY or float(data["call_s"]) >= _fill_wait_s():
			_free_start(room)
			changed = true
	if _free_call(now):
		changed = true
	if changed:
		_announce_free()


## 空いているルームに、人を呼ぶ。呼べる人（ロビーにいて、ぷるりんを選んでいて、☑していて、呼ばれていない・どこにも入っていない人）を、
## その人の希望の順で、いちばん前の、空きのあるルームへ振り分け、ルームごとに、長く待っている順に、空きの数だけ呼ぶ。呼んだら true。
func _free_call(now: int) -> bool:
	var room_left := {}
	for free_id: String in _free_rooms:
		var data: Dictionary = _rooms[int(_free_rooms[free_id])]
		if str(data["call_state"]) == Protocol.FREE_STATE_RACING:
			continue
		var left := Protocol.ROOM_CAPACITY - (data["accepted"] as Array).size() - (data["pending"] as Dictionary).size()
		if left > 0:
			room_left[free_id] = left
	if room_left.is_empty():
		return false
	var by_room := {}
	for peer_id: int in _peers:
		var peer: Dictionary = _peers[peer_id]
		if not bool(peer["free"]) or str(peer["free_pick"]).is_empty() or not str(peer["offer"]).is_empty() or int(peer["free_room"]) != 0:
			continue
		for free_id: String in peer["wishes"]:
			if room_left.has(free_id):
				(by_room.get_or_add(free_id, []) as Array).append(peer_id)
				break
	var called := false
	for free_id: String in by_room:
		var room := int(_free_rooms[free_id])
		var data: Dictionary = _rooms[room]
		var line: Array = by_room[free_id]
		line.sort_custom(_waited_longer)
		for peer_id: int in line.slice(0, int(room_left[free_id])):
			if str(data["call_state"]) == Protocol.FREE_STATE_IDLE:
				data["call_state"] = Protocol.FREE_STATE_CALLING
				data["call_s"] = 0.0
			# 返事を待つのは、決めた秒数まで。ただし、ルームが始まるまでの残りより長くはしない。
			var wait_s := minf(_answer_wait_s(), maxf(_fill_wait_s() - float(data["call_s"]), 1.0))
			(data["pending"] as Dictionary)[peer_id] = true
			_peers[peer_id]["offer"] = free_id
			_peers[peer_id]["offer_until_msec"] = now + int(wait_s * 1000.0)
			_send(peer_id, Protocol.message(Protocol.FREE_OFFER, {
				"room_id": free_id, "name": str(data["name"]), "distance_m": float(data["distance_m"]),
				"priority": (_peers[peer_id]["wishes"] as Array).find(free_id) + 1, "wait_s": wait_s,
			}))
			called = true
	return called


## 呼んでいたルームのレースを始める。まだ返事を待っていた人は、呼ぶのを取り消す（☑と、待っている時間は、そのまま）。
## 入ると答えた人が1人もいなければ、空きに戻す。足りない枠は、CPU。枠順は、くじ。
func _free_start(room: int) -> void:
	var data: Dictionary = _rooms[room]
	for peer_id: int in (data["pending"] as Dictionary).keys():
		if _peers.has(peer_id):
			_peers[peer_id]["offer"] = ""
			_send(peer_id, Protocol.message(Protocol.FREE_OFFER_END, {"room_id": str(data["free_id"]), "reason": Protocol.FREE_OFFER_STARTED}))
	data["pending"] = {}
	var racers: Array = (data["accepted"] as Array).filter(func(peer_id: int) -> bool: return _peers.has(peer_id))
	data["accepted"] = []
	if racers.is_empty():
		data["call_state"] = Protocol.FREE_STATE_IDLE
		return
	data["racers"] = racers.duplicate()
	data["order"] = racers.duplicate()
	var picks := {}
	for peer_id: int in racers:
		picks[peer_id] = str(_peers[peer_id]["free_pick"])
	data["picks"] = picks
	var seats: Array = []
	for _index in Protocol.ROOM_CAPACITY - racers.size():
		seats.append(true)
	data["seats"] = seats
	data["cpu_picks"] = []
	var entries := build_entries(room)
	entries.shuffle()
	data["entries"] = _with_gates(entries)
	data["call_state"] = Protocol.FREE_STATE_RACING
	_launch_race(room, (data["entries"] as Array).duplicate(true), float(data["distance_m"]))


## フリーのルームのレースを片づけたあと：出た人は、ロビーへ戻る（☑は残す。待っている時間は、今から数え直す＝列の後ろへ）。ルームは空きに戻す。
func _free_race_over(room: int) -> void:
	var data: Dictionary = _rooms[room]
	var now := Time.get_ticks_msec()
	for peer_id: int in data["racers"]:
		if _peers.has(peer_id) and int(_peers[peer_id]["free_room"]) == room:
			_peers[peer_id]["free_room"] = 0
			if not (_peers[peer_id]["wishes"] as Array).is_empty():
				_peers[peer_id]["wait_since_msec"] = now
	data["racers"] = []
	data["order"] = []
	data["picks"] = {}
	data["seats"] = []
	data["entries"] = []
	data["call_state"] = Protocol.FREE_STATE_IDLE
	data["call_s"] = 0.0
	_announce_free()


## フリーのルームのレースの途中で、やめる・抜ける：その走者は、その個体のCPUトレーナーに任せて、ロビーへ戻る（待っている時間は、今から数え直す）。
func _free_quit_race(peer_id: int, room: int) -> void:
	var race := room_race(room)
	if race != null:
		race.call("release_remote_runner", peer_id)
		_log_event(room, "left", {"peer_id": peer_id, "name": str(_peers[peer_id]["name"]), "how": Protocol.NOTICE_LEFT, "handed_to_cpu": true})
	(_rooms[room]["order"] as Array).erase(peer_id)
	_peers[peer_id]["free_room"] = 0
	if not (_peers[peer_id]["wishes"] as Array).is_empty():
		_peers[peer_id]["wait_since_msec"] = Time.get_ticks_msec()


## オンラインフリー対戦のロビーにいる人の、レースの文（操作・画面ができた・見終わった・途中でやめる）。
## レースに出ていない・終わりぎわに届いたレースの文は、だまって捨てる。
func _free_race_message(peer_id: int, type: String, data: Dictionary) -> void:
	var room := int(_peers[peer_id]["free_room"])
	if room == 0 or room_race(room) == null or not (_rooms[room]["order"] as Array).has(peer_id):
		if not type in [Protocol.INPUT, Protocol.ACTION, Protocol.READY, Protocol.RACE_DONE, Protocol.BACK]:
			_refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)
		return
	match type:
		Protocol.INPUT: _race_input(peer_id, room, data)
		Protocol.ACTION: _race_action(peer_id, room, data)
		Protocol.READY: (_rooms[room]["ready"] as Dictionary)[peer_id] = true
		Protocol.RACE_DONE: (_rooms[room]["done"] as Dictionary)[peer_id] = true
		Protocol.BACK:
			_free_quit_race(peer_id, room)
			_announce_free()
		_: _refuse(peer_id, Protocol.ERROR_BAD_MESSAGE)


func _send_free_lobby(peer_id: int) -> void:
	var peer: Dictionary = _peers[peer_id]
	_send(peer_id, Protocol.message(Protocol.FREE_LOBBY, {
		"peer_id": peer_id, "pururin_id": str(peer["free_pick"]), "wishes": (peer["wishes"] as Array).duplicate(),
		"rooms": free_room_list(peer_id), "fill_wait_s": _fill_wait_s(), "answer_wait_s": _answer_wait_s(),
	}))


## オンラインフリー対戦のロビーのようすを、ロビーにいる全員に配る（列の何番目かは、人ごとに違う）。
func _announce_free() -> void:
	for peer_id: int in _peers:
		if bool(_peers[peer_id]["free"]):
			_send_free_lobby(peer_id)


# ---------------------------------------------------------------- 送る

## 部屋のできごと（入った・出た・主が替わった、など）を、部屋の全員に知らせる。
func _notify(room: int, kind: String, player_name: String, by: String = "") -> void:
	_send_room(room, Protocol.message(Protocol.NOTICE, {"kind": kind, "name": player_name, "by": by}))


## 部屋のようす（部屋の全員に配るもの）。パスワードそのものは、配らない（あるかどうかだけ）。
func _room_fields(room: int, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = _rooms[room]
	var fields := {
		"room_id": room, "room": str(data["name"]), "members": room_members(room), "host": int(data["host"]),
		"distance_m": float(data["distance_m"]), "field_size": field_size(room), "seats": data["seats"],
		"racers": data["racers"], "capacity": Protocol.ROOM_CAPACITY,
		"locked": not str(data["password"]).is_empty(), "racing": data["race"] != null, "description": str(data["description"]),
		"phase": str(data["phase"]), "entries": data["entries"], "cpus": room_cpus(room),
	}
	fields.merge(extra)
	return fields


## 部屋のようすを、部屋の全員に配る。部屋の主にだけ、パスワードそのもの（password）も付ける（確かめて、変えられるように）。
func _announce_room(room: int) -> void:
	# フリーのルームには、部屋の画面が無い（ようすは、ロビーの free_lobby で配る）。
	if not _rooms.has(room) or bool(_rooms[room].get("free", false)):
		return
	var fields := _room_fields(room)
	var text := Protocol.encode(Protocol.message(Protocol.ROOM, fields))
	var host := int(_rooms[room]["host"])
	for peer_id: int in _rooms[room]["order"]:
		if peer_id == host:
			_send(peer_id, Protocol.message(Protocol.ROOM, _room_fields(room, {"password": str(_rooms[room]["password"])})))
		else:
			_send_text(peer_id, text)


func _send_room(room: int, data: Dictionary) -> void:
	var text := Protocol.encode(data)
	for peer_id: int in _rooms[room]["order"]:
		_send_text(peer_id, text)


## レースに出る人にだけ送る（レースの始まり・状態・結果・片づけ）。待機室に残った人には、送らない。
func _send_racers(room: int, data: Dictionary) -> void:
	var text := Protocol.encode(data)
	for peer_id: int in present_racers(room):
		_send_text(peer_id, text)


## 部屋の一覧の所に入った人（部屋を出た人・出された人）に、今の一覧を送る。
func _send_lobby(peer_id: int) -> void:
	_send(peer_id, Protocol.message(Protocol.LOBBY, {"peer_id": peer_id, "max_rooms": OnlineConfig.max_rooms(), "rooms": room_list()}))


## 部屋の一覧が変わったことを、名乗っていて、部屋に入っていない人に配る。
func _announce_rooms() -> void:
	var text := Protocol.encode(Protocol.message(Protocol.ROOMS, {"rooms": room_list()}))
	for peer_id: int in _peers:
		if int(_peers[peer_id]["room"]) == 0 and not bool(_peers[peer_id]["free"]) and not str(_peers[peer_id]["name"]).is_empty():
			_send_text(peer_id, text)


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
