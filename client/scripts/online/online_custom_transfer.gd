extends RefCounted
## 1接続分の送受信。操作は即送信し、部品は空いているときに1コマ1切れ端。
const Protocol := preload("res://scripts/online/online_protocol.gd")
const Config := preload("res://scripts/config/online_config.gd")
const Registry := preload("res://scripts/online/online_custom_pururins.gd")
const Validation := preload("res://scripts/online/online_custom_validation.gd")
const Sender := preload("res://scripts/online/online_custom_sender.gd")
const Store := preload("res://scripts/online/online_asset_store.gd")
const Settings := preload("res://scripts/online/online_parts_settings.gd")
var owner: Node
var peer_id := 0
var _scopes := {}
var _own_ids := {}
var _uploads := {}
var _commands := {}
var _wanted := {}
var _requested := {}
var _download := Store.new()
var last_error := ""

func _init(client: Node) -> void:
	owner = client

func _scope(label: String) -> String:
	return "client:%d:%s" % [owner.get_instance_id(), label]

func reset() -> void:
	for label: String in _scopes:
		Registry.release(_scope(label))
	_scopes.clear()
	_own_ids.clear()
	_uploads.clear()
	_commands.clear()
	_wanted.clear()
	_requested.clear()
	_download.assets.clear()
	_download.pending.clear()
	peer_id = 0
	last_error = ""

func has_pending_pick() -> bool:
	return _commands.has(Protocol.PICK + ":")

func local_id(id: String) -> String:
	return str(_own_ids.get(id, id))

func send_custom(type: String, fields: Dictionary) -> bool:
	var id := str(fields.get("pururin_id", ""))
	var prepared := Sender.prepare(id)
	if prepared.has("error"):
		fail(str(prepared["error"]), str(fields.get("room_id", "")))
		return false
	if type == Protocol.PICK:
		owner._send_now(Protocol.CONFIRM, {"on": false})
	var custom: Dictionary = prepared["custom"]
	var remote_id := Registry.content_id(custom, str(peer_id))
	_own_ids[remote_id] = id
	var command := fields.duplicate(true)
	command.erase("pururin_id")
	command["custom"] = custom
	var waiting := {}
	for hash_value: String in prepared["files"]:
		var file: Dictionary = prepared["files"][hash_value]
		waiting[hash_value] = true
		if not _uploads.has(hash_value):
			_uploads[hash_value] = {"data": file["data"], "ext": file["ext"], "index": 0, "until": Time.get_ticks_msec() + int(Config.custom_limits()["transfer_timeout_s"]) * 1000}
		# 自分の姿は受信待ちにせず、検査した同じファイルをキャッシュへ置く。
		if not _save_cache(hash_value, str(file["ext"]), file["data"]):
			_prune_uploads()
			fail("オンラインの部品を、この機械に保存できません。", str(fields.get("room_id", "")))
			return false
	_commands[type + ":" + str(fields.get("room_id", ""))] = {"type": type, "fields": command, "waiting": waiting}
	_flush_commands()
	return true

func fail(reason: String, room: String = "") -> void:
	last_error = reason
	owner.message_received.emit(Protocol.message(Protocol.ERROR, {"code": Protocol.ERROR_CUSTOM, "reason": reason, "room_id": room}))

func _flush_commands() -> void:
	for key: String in _commands.keys():
		var command: Dictionary = _commands[key]
		if command["waiting"].is_empty():
			owner._send_now(str(command["type"]), command["fields"])
			_commands.erase(key)

func before_send(type: String, fields: Dictionary = {}) -> void:
	last_error = ""
	if type in [Protocol.PICK, Protocol.FREE_ENTRY]:
		_commands.erase(type + ":" + str(fields.get("room_id", "")))
	if type == Protocol.FREE_CANCEL:
		_commands.erase(Protocol.FREE_ENTRY + ":" + str(fields.get("room_id", "")))
	for key: String in _commands.keys():
		if (type == Protocol.FREE_LEAVE and _commands[key]["type"] == Protocol.FREE_ENTRY) or (type in [Protocol.LEAVE, Protocol.BACK] and _commands[key]["type"] == Protocol.PICK):
			_commands.erase(key)
	_prune_uploads()
	if type in [Protocol.FREE_ENTER, Protocol.FREE_LEAVE, Protocol.LEAVE]:
		_release("race")
	if type == Protocol.FREE_LEAVE:
		_release("free")
		_release("view")

func _prune_uploads() -> void:
	var needed := {}
	for command: Dictionary in _commands.values():
		needed.merge(command["waiting"])
	for hash_value: String in _uploads.keys():
		if not needed.has(hash_value):
			_uploads.erase(hash_value)

func _release(label: String) -> void:
	_scopes.erase(label)
	Registry.release(_scope(label))

func receive(data: Dictionary) -> bool:
	var type := str(data["t"])
	if type in [Protocol.LOBBY, Protocol.WELCOME, Protocol.FREE_LOBBY]:
		peer_id = int(data["peer_id"])
	if type == Protocol.ASSET_OK:
		var hash_value := str(data.get("hash", ""))
		_uploads.erase(hash_value)
		for command: Dictionary in _commands.values():
			command["waiting"].erase(hash_value)
		_flush_commands()
		return true
	if type == Protocol.ASSET_ERROR:
		var hash_value := str(data.get("hash", ""))
		if _uploads.has(hash_value):
			_uploads.erase(hash_value)
			for key: String in _commands.keys():
				if _commands[key]["waiting"].has(hash_value):
					var room := str(_commands[key]["fields"].get("room_id", ""))
					_commands.erase(key)
					fail("部品を送れませんでした：" + str(data.get("reason", "")), room)
		_prune_uploads()
		_requested.erase(hash_value)
		return true
	if type == Protocol.ASSET_DATA:
		_receive_asset(data)
		return true
	if type == Protocol.LOBBY:
		_release("room")
		_release("race")
	if type in [Protocol.ROOM, Protocol.WELCOME] and not bool(data.get("racing", false)) and str(data.get("phase", "")) == Protocol.PHASE_LOBBY:
		_release("race")
	var labels := {Protocol.ROOM: "room", Protocol.WELCOME: "room", Protocol.FREE_LOBBY: "free", Protocol.FREE_ROOM: "view", Protocol.FREE_OFFER: "offer", Protocol.RACE_START: "race"}
	if labels.has(type):
		var records := {}
		var mine := {}
		if not _read_customs(data, records, mine):
			fail("サーバーから届いた作成個体が不正です。")
			return false
		var label: String = labels[type]
		_scopes[label] = records
		Registry.replace_scope(_scope(label), records, mine)
		if type == Protocol.RACE_START:
			_release("offer")
	if type == Protocol.FREE_OFFER_END:
		_release("offer")
	_rebuild_wanted()
	return true

func _read_customs(value: Variant, records: Dictionary, mine: Dictionary) -> bool:
	if value is Dictionary:
		var id := str(value.get("pururin_id", value.get("id", "")))
		if value.has("custom"):
			var custom: Variant = value["custom"]
			if not custom is Dictionary or (Registry.custom_for(id) != custom and not Validation.validate(custom).is_empty()):
				return false
			var own_peer := int(value.get("peer_id", peer_id))
			if id != Registry.content_id(custom, str(own_peer)):
				return false
			records[id] = custom
			if own_peer == peer_id:
				mine[id] = true
		for key: String in value:
			if key != "custom" and not _read_customs(value[key], records, mine):
				return false
	elif value is Array:
		for item: Variant in value:
			if not _read_customs(item, records, mine):
				return false
	return true

func _rebuild_wanted() -> void:
	_wanted = {}
	for records: Dictionary in _scopes.values():
		for id: String in records:
			if Settings.hidden() and not _own_ids.has(id):
				continue
			for part: Dictionary in records[id]["parts"].values():
				var source: Dictionary = part["source"]
				if not Registry.cached(source):
					_wanted[source["hash"]] = source

func _receive_asset(data: Dictionary) -> void:
	var hash_value := str(data.get("hash", ""))
	if not _requested.has(hash_value) or not _wanted.has(hash_value):
		return
	var expected: Dictionary = _wanted[hash_value]
	if data.get("ext") != expected["ext"] or data.get("bytes") != expected["bytes"]:
		_download.drop(peer_id)
		_requested.erase(hash_value)
		return
	var reply := _download.put_chunk(peer_id, data)
	if str(reply.get("t", "")) == Protocol.ASSET_ERROR:
		_requested.erase(hash_value)
		return
	if str(reply.get("t", "")) == Protocol.ASSET_OK:
		var asset: Dictionary = _download.assets[hash_value]
		if load("res://scripts/online/online_part_validation.gd").check(asset["data"], str(asset["ext"]), true).is_empty():
			_save_cache(hash_value, str(asset["ext"]), asset["data"])
		_download.assets.erase(hash_value)
		_requested.erase(hash_value)
		Registry.refresh(hash_value)
		_rebuild_wanted()

func _save_cache(hash_value: String, ext: String, data: PackedByteArray) -> bool:
	var directory := "user://online_parts_cache"
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var path := directory.path_join(hash_value + "." + ext)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	var result := file.get_error() == OK
	file.close()
	return result

func tick(socket: WebSocketPeer) -> void:
	var now := Time.get_ticks_msec()
	for hash_value: String in _uploads.keys():
		if now >= int(_uploads[hash_value]["until"]):
			receive(Protocol.message(Protocol.ASSET_ERROR, {"hash": hash_value, "reason": "transfer_timeout"}))
	_download.collect({}, now)
	for hash_value: String in _requested.keys():
		if now >= int(_requested[hash_value]):
			_requested.erase(hash_value)
	# 設定を変えた直後も、未取得の相手の部品を探す。
	_rebuild_wanted()
	if socket.get_current_outbound_buffered_amount() > 0:
		return
	if not _uploads.is_empty():
		var hash_value: String = _uploads.keys()[0]
		var upload: Dictionary = _uploads[hash_value]
		var index := int(upload["index"])
		var count := ceili(float((upload["data"] as PackedByteArray).size()) / int(Config.custom_limits()["chunk_bytes"]))
		if index < count:
			var packet := Store.chunk(hash_value, str(upload["ext"]), upload["data"], index, Protocol.ASSET_PUT)
			owner._send_now(Protocol.ASSET_PUT, packet)
			upload["index"] = index + 1
		return
	var reserved := 0
	for hash_value: String in _requested:
		reserved += int(_wanted.get(hash_value, {}).get("bytes", 0))
	for hash_value: String in _wanted:
		var size := int(_wanted[hash_value]["bytes"])
		if _requested.has(hash_value) or _requested.size() >= int(Config.custom_limits()["pending_count"]) or reserved + size > int(Config.custom_limits()["pending_bytes"]):
			continue
		_requested[hash_value] = now + int(Config.custom_limits()["transfer_timeout_s"]) * 1000
		owner._send_now(Protocol.ASSET_GET, {"hash": hash_value})
		break
