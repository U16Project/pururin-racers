extends RefCounted
## オンライン対戦の設定（つなぐ先のサーバーなど）。初期値は data/config/online.json だけに置く。

const CONFIG_PATH := "res://data/config/online.json"
const Protocol := preload("res://scripts/online/online_protocol.gd")
## サーバーの計算の回数（1秒あたり）として受け付ける範囲。
const SERVER_MAX_FPS_RANGE := Vector2(10.0, 120.0)
## 整数の設定と、受け付ける範囲。max_rooms＝同時に作れる部屋の数、chat_max_length＝部屋のひとことの字数。
## result_linger_s＝結果が出たあと、サーバーがレースを走らせ続ける秒数（過ぎたら、レースを片づけて、全員を部屋へ戻す）。
## free_fill_wait_s＝オンラインフリー対戦のルームが、人を呼び始めてから、レースを始めるまでに待つ秒数の上限（足りない枠はCPU）。
## free_result_keep＝オンラインフリー対戦のルームごとに残す、過去の結果のレースの数。
## free_answer_wait_s＝呼ばれた人の、返事を待つ秒数の上限（返事がなければ、そのルームのエントリーを取り消す）。
const WHOLE_NUMBER_RANGES := {"max_rooms": Vector2(1.0, 100.0), "chat_max_length": Vector2(1.0, 200.0), "result_linger_s": Vector2(0.0, 120.0), "log_keep_days": Vector2(1.0, 365.0), "free_fill_wait_s": Vector2(1.0, 300.0), "free_answer_wait_s": Vector2(1.0, 120.0), "free_result_keep": Vector2(1.0, 200.0)}
## オンラインフリー対戦のルームの、名前・札・縛りの文・紹介文の長さの上限と、IDに使える文字、画像のファイル名に使える文字。
const FREE_ROOM_NAME_MAX_LENGTH := 16
const FREE_ROOM_TAG_MAX_LENGTH := 8
const FREE_ROOM_RULE_MAX_LENGTH := 24
const FREE_ROOM_INTRO_MAX_LENGTH := 300
const FREE_ROOM_ID_PATTERN := "^[a-z0-9_]{1,24}$"
const FREE_ROOM_IMAGE_PATTERN := "^[a-z0-9_]{1,40}\\.(jpg|png)$"
## 1つのルームで同時に走らせるレースの数の範囲。
const FREE_ROOM_MAX_RACES_RANGE := Vector2(1.0, 50.0)
## 大会の時刻の書き方（日本の時間。例 "2026-10-25 07:00"）と、日本の時間の、世界の基準の時間からのずれ（秒）。
const SCHEDULE_PATTERN := "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$"
const JST_OFFSET_S := 9 * 3600
const FREE_ROOM_TEXT_LIMITS := {"tag": FREE_ROOM_TAG_MAX_LENGTH, "rule": FREE_ROOM_RULE_MAX_LENGTH, "intro": FREE_ROOM_INTRO_MAX_LENGTH}
## つなぐ先として受け付ける書き出し（暗号なし・暗号あり）。
const URL_PREFIXES := ["ws://", "wss://"]

static var last_error := ""
static var _config: Dictionary = {}


static func values() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		var errors := validate(parsed)
		if errors.is_empty():
			_config = parsed
		else:
			last_error = "; ".join(errors)
			push_error(last_error)
	return _config


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("online: オブジェクトが必要です")
		return errors
	if not data.get("server_url") is String or not is_server_url(str(data["server_url"])):
		errors.append("online.server_url: ws:// か wss:// で始まるURLが必要です")
	if not (data.get("connect_timeout_s") is float or data.get("connect_timeout_s") is int) or float(data["connect_timeout_s"]) <= 0.0:
		errors.append("online.connect_timeout_s: 0より大きい数字が必要です")
	var room: Variant = data.get("default_room")
	if not room is String or str(room).strip_edges().is_empty() or str(room).length() > Protocol.ROOM_NAME_MAX_LENGTH:
		errors.append("online.default_room: 1〜%d字の部屋の名前が必要です" % Protocol.ROOM_NAME_MAX_LENGTH)
	for key: String in WHOLE_NUMBER_RANGES:
		var number: Variant = data.get(key)
		var limits: Vector2 = WHOLE_NUMBER_RANGES[key]
		if not (number is float or number is int) or float(number) != floorf(float(number)) or float(number) < limits.x or float(number) > limits.y:
			errors.append("online.%s: %d〜%d の整数が必要です" % [key, int(limits.x), int(limits.y)])
	errors.append_array(validate_free_tickets(data.get("free_tickets")))
	errors.append_array(validate_free_rooms(data.get("free_rooms"), data.get("free_tickets")))
	var fps: Variant = data.get("server_max_fps")
	if not (fps is float or fps is int) or float(fps) != floorf(float(fps)) or float(fps) < SERVER_MAX_FPS_RANGE.x or float(fps) > SERVER_MAX_FPS_RANGE.y:
		errors.append("online.server_max_fps: %d〜%d の整数が必要です" % [int(SERVER_MAX_FPS_RANGE.x), int(SERVER_MAX_FPS_RANGE.y)])
	return errors


## オンラインフリー対戦のルームの並び。1つぶん：id（重ならない）、name、distance_m（レースで選べる距離）、
## tag（種類の札の文字）・tag_color（札の色。#rrggbb）、rule（縛りの文）、intro（紹介文）、
## image（ルームの画像のファイル名。サーバーの data/free_room_images/ に置く）、max_races（同時に走らせるレースの数の上限）。
## あれば：needs_ticket（出るのに要るチケットのID）、gives_ticket（1位になった人のぷるりんに渡すチケットのID）。どちらも free_tickets にあること。
## あれば：final（本戦。{"start_at"＝開始の時刻（日本の時間）、"max_players"＝エントリーの上限、"answer_wait_s"＝呼び出しに答える秒数（過ぎたら失格）}）。
## 本戦は、開始の時刻にエントリーした全員を呼び、入ると答えた人を8人ずつの準決勝に分け、各1位（CPUが1位なら、いちばん上の人間）で決勝をする。8人以下なら、すぐ決勝。
## 本戦には、open_at・close_at は書かない（開始の時刻まで、いつでもエントリーできる）。
## あれば：open_at・close_at（受付の開始と終了。日本の時間で "2026-10-25 07:00"。2つそろって、終了は開始より後）。無ければ、いつでも開いている。
static func validate_free_rooms(rooms: Variant, tickets: Variant = []) -> PackedStringArray:
	var errors := PackedStringArray()
	if not rooms is Array or (rooms as Array).is_empty():
		errors.append("online.free_rooms: ルームが1つ以上必要です")
		return errors
	var pattern := RegEx.create_from_string(FREE_ROOM_ID_PATTERN)
	var ids := {}
	for index in (rooms as Array).size():
		var room: Variant = rooms[index]
		var label := "online.free_rooms[%d]" % index
		if not room is Dictionary:
			errors.append("%s: オブジェクトが必要です" % label)
			continue
		var id := str(room.get("id", ""))
		if pattern.search(id) == null or ids.has(id):
			errors.append("%s.id: 重ならない、英小文字・数字・_ のIDが必要です" % label)
		ids[id] = true
		var name: Variant = room.get("name")
		if not name is String or str(name).strip_edges().is_empty() or str(name).length() > FREE_ROOM_NAME_MAX_LENGTH:
			errors.append("%s.name: 1〜%d字の名前が必要です" % [label, FREE_ROOM_NAME_MAX_LENGTH])
		var distance: Variant = room.get("distance_m")
		if not (distance is float or distance is int) or not preload("res://scripts/race_session.gd").supported_distances_m().has(float(distance)):
			errors.append("%s.distance_m: レースで選べる距離（%s）が必要です" % [label, str(preload("res://scripts/race_session.gd").supported_distances_m())])
		for text_key: String in FREE_ROOM_TEXT_LIMITS:
			var text: Variant = room.get(text_key)
			if not text is String or str(text).strip_edges().is_empty() or str(text).length() > int(FREE_ROOM_TEXT_LIMITS[text_key]):
				errors.append("%s.%s: 1〜%d字の文が必要です" % [label, text_key, int(FREE_ROOM_TEXT_LIMITS[text_key])])
		var color: Variant = room.get("tag_color")
		if not color is String or not str(color).begins_with("#") or str(color).length() != 7 or not Color.html_is_valid(str(color)):
			errors.append("%s.tag_color: #rrggbb の形の色が必要です" % label)
		if not room.get("image") is String or RegEx.create_from_string(FREE_ROOM_IMAGE_PATTERN).search(str(room["image"])) == null:
			errors.append("%s.image: 英小文字・数字・_ の名前の .jpg か .png が必要です" % label)
		if room.has("final"):
			errors.append_array(_validate_final(room["final"], label))
			if room.has("open_at") or room.has("close_at"):
				errors.append("%s: 本戦（final）には、open_at・close_at は書きません" % label)
		if room.has("open_at") or room.has("close_at"):
			var open_unix := schedule_unix(room.get("open_at"))
			var close_unix := schedule_unix(room.get("close_at"))
			if open_unix < 0 or close_unix < 0 or close_unix <= open_unix:
				errors.append("%s.open_at・close_at: \"2026-10-25 07:00\" の形の時刻が2つ、終了が開始より後で必要です" % label)
		for ticket_key: String in ["needs_ticket", "gives_ticket"]:
			if room.has(ticket_key) and (not room[ticket_key] is String or not _ticket_ids(tickets).has(str(room[ticket_key]))):
				errors.append("%s.%s: free_tickets にあるチケットのIDが必要です" % [label, ticket_key])
		var races: Variant = room.get("max_races")
		if not (races is float or races is int) or float(races) != floorf(float(races)) or float(races) < FREE_ROOM_MAX_RACES_RANGE.x or float(races) > FREE_ROOM_MAX_RACES_RANGE.y:
			errors.append("%s.max_races: %d〜%d の整数が必要です" % [label, int(FREE_ROOM_MAX_RACES_RANGE.x), int(FREE_ROOM_MAX_RACES_RANGE.y)])
	return errors


static func _validate_final(final: Variant, label: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not final is Dictionary or schedule_unix(final.get("start_at")) < 0:
		errors.append("%s.final.start_at: \"2026-10-25 08:05\" の形の開始の時刻が必要です" % label)
		return errors
	for key: String in FINAL_RANGES:
		var number: Variant = final.get(key)
		var limits: Vector2 = FINAL_RANGES[key]
		if not (number is float or number is int) or float(number) != floorf(float(number)) or float(number) < limits.x or float(number) > limits.y:
			errors.append("%s.final.%s: %d〜%d の整数が必要です" % [label, key, int(limits.x), int(limits.y)])
	return errors


## 本戦の数の範囲：max_players＝エントリーの上限、answer_wait_s＝呼び出しに答える秒数。
const FINAL_RANGES := {"max_players": Vector2(2.0, 512.0), "answer_wait_s": Vector2(10.0, 300.0)}


## オンラインフリー対戦のチケットの並び。1つぶん：id（重ならない。英小文字・数字・_）、name（16字まで）、あれば expires_at（期限。日本の時間）。
## チケットは、ルームの1位のぷるりんに渡し（gives_ticket）、持っているぷるりんだけが出られるルーム（needs_ticket）に入れる。使ってもなくならない。
static func validate_free_tickets(tickets: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not tickets is Array:
		errors.append("online.free_tickets: 並び（無ければ空の並び）が必要です")
		return errors
	var pattern := RegEx.create_from_string(FREE_ROOM_ID_PATTERN)
	var ids := {}
	for index in (tickets as Array).size():
		var ticket: Variant = tickets[index]
		var label := "online.free_tickets[%d]" % index
		if not ticket is Dictionary or pattern.search(str(ticket.get("id", ""))) == null or ids.has(str(ticket.get("id", ""))):
			errors.append("%s.id: 重ならない、英小文字・数字・_ のIDが必要です" % label)
			continue
		ids[str(ticket["id"])] = true
		if not ticket.get("name") is String or str(ticket["name"]).strip_edges().is_empty() or str(ticket["name"]).length() > FREE_ROOM_NAME_MAX_LENGTH:
			errors.append("%s.name: 1〜%d字の名前が必要です" % [label, FREE_ROOM_NAME_MAX_LENGTH])
		if ticket.has("expires_at") and schedule_unix(ticket["expires_at"]) < 0:
			errors.append("%s.expires_at: \"2026-10-25 07:00\" の形の時刻が必要です" % label)
	return errors


static func _ticket_ids(tickets: Variant) -> Array:
	var ids: Array = []
	if tickets is Array:
		for ticket: Variant in tickets:
			if ticket is Dictionary:
				ids.append(str(ticket.get("id", "")))
	return ids


## 大会の時刻（日本の時間 "2026-10-25 07:00"）を、世界の基準の秒（unix）にする。形が違えば -1。
static func schedule_unix(value: Variant) -> int:
	if not value is String or RegEx.create_from_string(SCHEDULE_PATTERN).search(str(value)) == null:
		return -1
	var text := str(value)
	var parts := {"year": int(text.substr(0, 4)), "month": int(text.substr(5, 2)), "day": int(text.substr(8, 2)), "hour": int(text.substr(11, 2)), "minute": int(text.substr(14, 2)), "second": 0}
	if int(parts["month"]) < 1 or int(parts["month"]) > 12 or int(parts["day"]) < 1 or int(parts["day"]) > 31 or int(parts["hour"]) > 23 or int(parts["minute"]) > 59:
		return -1
	return Time.get_unix_time_from_datetime_dict(parts) - JST_OFFSET_S


## チケットの期限（unix。無ければ0）。
static func free_ticket_expires(ticket_id: String) -> int:
	for ticket: Dictionary in values()["free_tickets"]:
		if str(ticket["id"]) == ticket_id and ticket.has("expires_at"):
			return schedule_unix(ticket["expires_at"])
	return 0


## チケットの名前（無いIDなら空）。
static func free_ticket_name(ticket_id: String) -> String:
	for ticket: Dictionary in values()["free_tickets"]:
		if str(ticket["id"]) == ticket_id:
			return str(ticket["name"])
	return ""


## オンラインフリー対戦のルームの並び（1つぶんの中身は、validate_free_rooms のとおり）。
static func free_rooms() -> Array:
	return values()["free_rooms"]


## オンラインフリー対戦のルームが、人を呼び始めてから、レースを始めるまでに待つ秒数の上限。
static func free_fill_wait_s() -> float:
	return float(values()["free_fill_wait_s"])


## ルームごとに残す、過去の結果のレースの数。
static func free_result_keep() -> int:
	return int(values()["free_result_keep"])


## 呼ばれた人の、返事を待つ秒数の上限。
static func free_answer_wait_s() -> float:
	return float(values()["free_answer_wait_s"])


## つなぐ先として使える形か（ws:// か wss:// で始まり、そのあとに何か書いてある）。
static func is_server_url(url: String) -> bool:
	for prefix: String in URL_PREFIXES:
		if url.begins_with(prefix) and url.length() > prefix.length():
			return true
	return false


static func server_url() -> String:
	return str(values()["server_url"])


## サーバーの計算の回数の上限（1秒あたり）。画面が無いので、決めないと、力のかぎり回り続ける。
## 少ないほど、サーバーは軽い。レースの計算は「前の計算から何秒たったか」で進めるので、回数を変えても、レースの長さは変わらない。
static func server_max_fps() -> int:
	return int(values()["server_max_fps"])


## 同時に作れる部屋の数の上限。
static func max_rooms() -> int:
	return int(values()["max_rooms"])


## 結果が出たあと、サーバーがレースを走らせ続ける秒数。
static func result_linger_s() -> float:
	return float(values()["result_linger_s"])


## オンラインのレースの記録を、何日残すか（古いものは、サーバーが消す）。
static func log_keep_days() -> int:
	return int(values()["log_keep_days"])


## 部屋のひとことの、字数の上限。
static func chat_max_length() -> int:
	return int(values()["chat_max_length"])


## 部屋を作る画面に、最初から入れておく部屋の名前（文字が打ちにくい端末でも、そのまま作れるように）。
static func default_room() -> String:
	return str(values()["default_room"])


static func connect_timeout_s() -> float:
	return float(values()["connect_timeout_s"])
