extends RefCounted
## 自分のぷるりん（この機械に保存する）。ぷるりんの一覧（data/config/pururin_roster.json）の1体ずつを、自分のものとして写し、
## アプリが自動で作る長いID（uid）と合言葉（secret）を付ける。プレイヤーは何もしない。
## 合言葉は、サーバーにだけ送る（ほかの人の機械には送らない）。サーバーは、チケットを渡すときと使うときに、uid と合言葉を確かめる。
## チケット（サーバーからもらったもの）も、ぷるりんごとに覚えておく（表示とカードの錠のため。正しいかは、サーバーが確かめる）。
## 配合を変える画面ができたら、変えたときに uid と合言葉を作り直す（別のぷるりんとして扱う）。
## 機械を替えたり、保存を消したりすると、ぷるりんとチケットは引き継げない。

const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const DEFAULT_SAVE_PATH := "user://owned_pururins.json"
## uid と合言葉の長さ（作るときの、でたらめな文字の元の長さ。16進の文字では、この2倍）。
const UID_BYTES := 16
const SECRET_BYTES := 32

static var _save_path := DEFAULT_SAVE_PATH
static var _loaded := false
## 一覧のぷるりんのID → {"uid", "secret", "tickets": {チケットのID: {"name", "expires_unix"（期限。無ければ0）}}}。
static var _owned := {}


## 保存する場所を替えて、読み直す（テスト用。本物のぷるりんに触らないため）。
static func use_path(path: String) -> void:
	_save_path = path
	_loaded = false


## 一覧のぷるりんの、自分の写し。まだ無ければ、uid と合言葉を作って保存する。
static func entry_for(pururin_id: String) -> Dictionary:
	_load()
	if not _owned.has(pururin_id):
		_owned[pururin_id] = {"uid": _random_hex(UID_BYTES), "secret": _random_hex(SECRET_BYTES), "tickets": {}}
		_save()
	return _owned[pururin_id]


static func uid(pururin_id: String) -> String:
	return str(entry_for(pururin_id)["uid"])


static func secret(pururin_id: String) -> String:
	return str(entry_for(pururin_id)["secret"])


## そのぷるりんが、今使えるチケット（チケットのID → 名前）。期限を過ぎたものは入れない。now_unix は、今の時刻（サーバーの時計に合わせたもの）。
static func tickets(pururin_id: String, now_unix: int) -> Dictionary:
	var usable := {}
	var owned: Dictionary = entry_for(pururin_id)["tickets"]
	for ticket_id: String in owned:
		var ticket: Dictionary = owned[ticket_id]
		if int(ticket["expires_unix"]) == 0 or now_unix < int(ticket["expires_unix"]):
			usable[ticket_id] = str(ticket["name"])
	return usable


## どれかのぷるりんが、そのチケットを（期限の前に）持っているか。
static func any_has_ticket(ticket_id: String, now_unix: int) -> bool:
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		if tickets(str(pururin["id"]), now_unix).has(ticket_id):
			return true
	return false


## サーバーからもらったチケットを覚える（uid で、どのぷるりんかを探す）。見つからなければ false。expires_unix は期限（無ければ0）。
static func add_ticket(owned_uid: String, ticket_id: String, ticket_name: String, expires_unix: int) -> bool:
	_load()
	for pururin_id: String in _owned:
		if str(_owned[pururin_id]["uid"]) == owned_uid:
			(_owned[pururin_id]["tickets"] as Dictionary)[ticket_id] = {"name": ticket_name, "expires_unix": expires_unix}
			_save()
			return true
	return false


static func _random_hex(byte_count: int) -> String:
	return Crypto.new().generate_random_bytes(byte_count).hex_encode()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_owned = {}
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not parsed is Dictionary:
		push_error("自分のぷるりんの保存が読めません: %s" % _save_path)
		return
	for pururin_id: String in parsed:
		var entry: Variant = parsed[pururin_id]
		if entry is Dictionary and entry.get("uid") is String and entry.get("secret") is String and entry.get("tickets") is Dictionary:
			_owned[pururin_id] = entry


static func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_error("自分のぷるりんを保存できません: %s" % _save_path)
		return
	file.store_string(JSON.stringify(_owned, "  "))
