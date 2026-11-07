extends RefCounted
## 切れ端の再構成とメモリの上限。GLTFDocument や画像デコーダーは使わない。
const Config := preload("res://scripts/config/online_config.gd")
const Check := preload("res://scripts/online/online_part_validation.gd")
const Validate := preload("res://scripts/online/online_custom_validation.gd")
var assets := {}
var pending := {}

func put_chunk(peer: int, message: Dictionary, now: int = Time.get_ticks_msec()) -> Dictionary:
	var hash_value := str(message.get("hash", ""))
	var key := "%d/%s" % [peer, hash_value]
	var reason := _accept(peer, key, message, now)
	if not reason.is_empty():
		pending.erase(key)
		return {"t": "asset_error", "hash": hash_value, "reason": reason}
	if not pending.has(key): # 既に完成した同一内容。
		return {"t": "asset_ok", "hash": hash_value}
	var transfer: Dictionary = pending[key]
	if transfer["chunks"].size() != int(transfer["count"]):
		return {}
	var data := PackedByteArray()
	for index in int(transfer["count"]):
		data.append_array(transfer["chunks"][index])
	pending.erase(key)
	if data.size() != int(transfer["bytes"]) or Check.sha(data) != hash_value:
		return {"t": "asset_error", "hash": hash_value, "reason": "hash_or_bytes"}
	reason = Check.check(data, str(transfer["ext"]))
	if not reason.is_empty():
		return {"t": "asset_error", "hash": hash_value, "reason": reason}
	assets[hash_value] = {"data": data, "bytes": data.size(), "ext": transfer["ext"], "peer": peer, "until": now + int(Config.custom_limits()["transfer_timeout_s"]) * 1000, "used": false}
	return {"t": "asset_ok", "hash": hash_value}

func _accept(peer: int, key: String, message: Dictionary, now: int) -> String:
	if not Validate.keys(message, ["v", "t", "hash", "ext", "bytes", "index", "count", "data"], true):
		return "chunk_fields"
	if not message["hash"] is String or RegEx.create_from_string("^[0-9a-f]{64}$").search(message["hash"]) == null or message["ext"] not in ["png", "glb"]:
		return "asset_declaration"
	for field: String in ["bytes", "index", "count"]:
		if not Check.whole(message[field]):
			return "chunk_index_count"
	var limits := Config.custom_limits()
	var size := int(message["bytes"])
	var chunk_size := int(limits["chunk_bytes"])
	var count := int(message["count"])
	var index := int(message["index"])
	if size < 1 or size > int(limits["mesh_bytes"] if message["ext"] == "glb" else limits["image_bytes"]) or count != ceili(float(size) / chunk_size) or index >= count:
		return "chunk_limit"
	if not message["data"] is String or message["data"].length() > ceili(float(chunk_size) / 3) * 4:
		return "chunk_data"
	if message["data"].length() % 4 != 0 or RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(message["data"]) == null:
		return "chunk_data"
	var bytes := Marshalls.base64_to_raw(message["data"])
	if Marshalls.raw_to_base64(bytes) != message["data"] or bytes.size() != mini(chunk_size, size - index * chunk_size):
		return "chunk_data"
	var hash_value: String = message["hash"]
	if assets.has(hash_value):
		var asset: Dictionary = assets[hash_value]
		pending.erase(key)
		return "" if asset["ext"] == message["ext"] and int(asset["bytes"]) == size else "asset_declaration"
	if not pending.has(key):
		var peer_bytes := 0
		var peer_count := 0
		var staged_count := 0
		var all_bytes := 0
		for asset: Dictionary in assets.values():
			all_bytes += int(asset["bytes"])
			if int(asset["peer"]) == peer and not bool(asset["used"]):
				peer_bytes += int(asset["bytes"])
				staged_count += 1
		for transfer: Dictionary in pending.values():
			all_bytes += int(transfer["bytes"])
			if int(transfer["peer"]) == peer:
				peer_bytes += int(transfer["bytes"])
				peer_count += 1
		if peer_bytes + size > int(limits["pending_bytes"]) or peer_count >= int(limits["pending_count"]) or staged_count >= int(limits["parts"]) or all_bytes + size > int(limits["server_bytes"]):
			return "transfer_budget"
		pending[key] = {"peer": peer, "hash": hash_value, "ext": message["ext"], "bytes": size, "count": count, "chunks": {}, "until": now + int(limits["transfer_timeout_s"]) * 1000}
	var transfer: Dictionary = pending[key]
	if now >= int(transfer["until"]):
		return "transfer_timeout"
	if transfer["ext"] != message["ext"] or int(transfer["bytes"]) != size or int(transfer["count"]) != count or transfer["chunks"].has(index):
		return "duplicate_or_mismatch"
	transfer["chunks"][index] = bytes
	return ""

func missing(custom: Dictionary) -> bool:
	for part: Dictionary in custom["parts"].values():
		var source: Dictionary = part["source"]
		var asset: Dictionary = assets.get(source["hash"], {})
		if asset.is_empty() or asset["ext"] != source["ext"] or int(asset["bytes"]) != int(source["bytes"]):
			return true
	return false

func collect(hashes: Dictionary, now: int = Time.get_ticks_msec()) -> Array:
	var errors: Array = []
	for key: String in pending.keys():
		var transfer: Dictionary = pending[key]
		if now >= int(transfer["until"]):
			errors.append({"peer": transfer["peer"], "hash": transfer["hash"], "reason": "transfer_timeout"})
			pending.erase(key)
	for hash_value: String in assets.keys():
		var asset: Dictionary = assets[hash_value]
		if hashes.has(hash_value):
			asset["used"] = true
		elif bool(asset["used"]) or now >= int(asset["until"]):
			assets.erase(hash_value)
	return errors

func drop(peer: int) -> void:
	for key: String in pending.keys():
		if int(pending[key]["peer"]) == peer:
			pending.erase(key)
	for hash_value: String in assets.keys():
		if int(assets[hash_value]["peer"]) == peer and not bool(assets[hash_value]["used"]):
			assets.erase(hash_value)

static func chunk(hash_value: String, ext: String, data: PackedByteArray, index: int, type: String) -> Dictionary:
	var size := int(Config.custom_limits()["chunk_bytes"])
	return {"t": type, "hash": hash_value, "ext": ext, "bytes": data.size(), "index": index, "count": ceili(float(data.size()) / size), "data": Marshalls.raw_to_base64(data.slice(index * size, mini((index + 1) * size, data.size())))}
