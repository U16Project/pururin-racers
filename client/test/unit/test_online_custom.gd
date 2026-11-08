extends GutTest
const Validation := preload("res://scripts/online/online_custom_validation.gd")
const Custom := preload("res://scripts/online/online_custom_pururins.gd")
const Store := preload("res://scripts/online/online_asset_store.gd")
const Server := preload("res://scripts/online/online_server.gd")
const Config := preload("res://scripts/config/online_config.gd")
const Roster := preload("res://scripts/config/pururin_roster_config.gd")
const Looks := preload("res://scripts/config/pururin_look_config.gd")
const Maker := preload("res://scripts/config/pururin_maker_config.gd")

func _custom() -> Dictionary:
	var id := str(Maker.values()["base_pururin"])
	var record := Roster.pururin_by_id(id)
	var result := {"parts": {}}
	for key: String in ["display_name", "attribute", "running_style", "allocation", "trainer_id"]:
		result[key] = record[key]
	var look := Looks.look_for(id).duplicate(true)
	look.erase("primary_color")
	look.erase("outline_color")
	result["look"] = look
	return result

func test_base_maker_copy_is_accepted() -> void:
	assert_eq(Validation.validate(_custom()), PackedStringArray())
	assert_eq(Config.validate(Config.values()), PackedStringArray())

const Check := preload("res://scripts/online/online_part_validation.gd")
const Protocol := preload("res://scripts/online/online_protocol.gd")
const Settings := preload("res://scripts/online/online_parts_settings.gd")
const Builder := preload("res://scripts/presentation/pururin_body_builder.gd")
const Owned := preload("res://scripts/config/owned_pururins.gd")
const Mine := preload("res://scripts/config/my_pururins.gd")
const Sender := preload("res://scripts/online/online_custom_sender.gd")
const Log := preload("res://scripts/online/online_race_log.gd")
const OPTIONS := "user://test_online_custom_settings.json"
const OWNED := "user://test_online_custom_owned.json"
const FOLDER := "user://test_online_custom_pururins"
var _files: Array[String] = []

func before_each() -> void:
	Settings.use_path(OPTIONS)
	Owned.use_path(OWNED)
	Mine.use_folder(FOLDER)

func after_each() -> void:
	await wait_process_frames(2)
	Custom.release("test:first")
	Custom.release("test:second")
	Settings.use_path(Settings.DEFAULT_PATH)
	Owned.use_path(Owned.DEFAULT_SAVE_PATH)
	Mine.use_folder("")
	for path: String in _files + [OPTIONS, OWNED]:
		DirAccess.remove_absolute(path)
	_files.clear()
	if DirAccess.dir_exists_absolute(FOLDER):
		for file: String in DirAccess.get_files_at(FOLDER):
			DirAccess.remove_absolute(FOLDER.path_join(file))
		DirAccess.remove_absolute(FOLDER)

func _png(side: int = 4) -> PackedByteArray:
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	return image.save_png_to_buffer()

func _glb(triangles: int = 1, change: Dictionary = {}) -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(triangles * 3 * 12)
	var doc := {"asset": {"version": "2.0"}, "buffers": [{"byteLength": pixels.size()}], "bufferViews": [{"buffer": 0, "byteLength": pixels.size()}], "accessors": [{"bufferView": 0, "componentType": 5126, "type": "VEC3", "count": triangles * 3, "min": [0, 0, 0], "max": [0, 0, 0]}], "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}], "nodes": [{"mesh": 0}], "scenes": [{"nodes": [0]}], "scene": 0}
	if change.has("_test_image"):
		var image: PackedByteArray = change["_test_image"]
		var start := pixels.size()
		pixels.append_array(image)
		while pixels.size() % 4 != 0:
			pixels.append(0)
		doc["buffers"][0]["byteLength"] = pixels.size()
		doc["bufferViews"].append({"buffer": 0, "byteOffset": start, "byteLength": image.size()})
		doc["images"] = [{"bufferView": 1, "mimeType": "image/png"}]
		change = change.duplicate()
		change.erase("_test_image")
	doc.merge(change, true)
	var text := JSON.stringify(doc).to_utf8_buffer()
	while text.size() % 4 != 0:
		text.append(32)
	var data := PackedByteArray()
	data.resize(28 + text.size() + pixels.size())
	data.encode_u32(0, 0x46546c67)
	data.encode_u32(4, 2)
	data.encode_u32(8, data.size())
	data.encode_u32(12, text.size())
	data.encode_u32(16, 0x4e4f534a)
	for i in text.size():
		data[20 + i] = text[i]
	data.encode_u32(20 + text.size(), pixels.size())
	data.encode_u32(24 + text.size(), 0x004e4942)
	for i in pixels.size():
		data[28 + text.size() + i] = pixels[i]
	return data

func _part(custom: Dictionary, bytes: PackedByteArray, slot: String = "top") -> Dictionary:
	var mesh := slot == "top"
	var source := {"type": "mesh" if mesh else "image", "hash": Check.sha(bytes), "ext": "glb" if mesh else "png", "bytes": bytes.size()}
	var id := "user/" + slot + "/same-name"
	var definition := {"kind": "body_part" if mesh else "face", "slot": slot, "source": source}
	if mesh:
		source.merge({"scale": 1.0, "material": "body"})
		definition["motions"] = {}
		custom["look"]["top"] = {"part": id, "params": {}}
	else:
		source.merge({"width": 0.4, "height": 0.19})
		custom["look"]["face"]["expressions"]["normal"][slot] = id
	custom["parts"][id] = definition
	return source

func _cache(source: Dictionary, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute("user://online_parts_cache")
	var path := Custom.cache_path(source)
	_files.append(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _chunk(data: PackedByteArray, index: int, ext: String = "glb", hash_value: String = "") -> Dictionary:
	return Protocol.message(Protocol.ASSET_PUT, Store.chunk(Check.sha(data) if hash_value.is_empty() else hash_value, ext, data, index, Protocol.ASSET_PUT))

func _upload(store: RefCounted, data: PackedByteArray, ext: String = "glb", peer: int = 1) -> Dictionary:
	var count := ceili(float(data.size()) / int(Config.custom_limits()["chunk_bytes"]))
	var reply := {}
	for i in count:
		reply = store.put_chunk(peer, _chunk(data, i, ext))
	return reply

func test_unknown_fields_and_path_are_rejected_everywhere() -> void:
	var custom := _custom()
	custom["unknown"] = true
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["look"]["body"]["path"] = "res://secret"
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	var source := _part(custom, _glb())
	source["path"] = "user://parts/a.glb"
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["look"]["face"]["unknown"] = 0
	assert_false(Validation.validate(custom).is_empty())

func test_ability_name_trainer_and_color_bounds() -> void:
	for key: String in ["attribute", "running_style", "trainer_id"]:
		var custom := _custom()
		custom[key] = "unknown"
		assert_false(Validation.validate(custom).is_empty(), key)
	var custom := _custom()
	custom["display_name"] = "あ".repeat(int(Maker.values()["name_max_length"]) + 1)
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["allocation"] = custom["allocation"].duplicate()
	var key: String = custom["allocation"].keys()[0]
	custom["allocation"][key] = 0
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["look"]["primary_color_index"] = preload("res://scripts/config/pururin_stats_config.gd").primary_colors(str(custom["attribute"])).size()
	assert_false(Validation.validate(custom).is_empty())

func test_numbers_are_finite_bounded_and_shapes_are_builtin_only() -> void:
	for key: String in ["height", "base_height"]:
		var custom := _custom()
		custom["look"]["body"][key] = Validation.NUMBER_RANGES[key].y + 1
		assert_false(Validation.validate(custom).is_empty())
	var custom := _custom()
	custom["look"]["secondary_top_ratio"] = INF
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["look"]["body"]["type"] = "mesh"
	assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	custom["look"]["body_texture"] = "res://texture.png"
	assert_false(Validation.validate(custom).is_empty())

func test_only_actual_builtin_part_params_pairs_are_accepted() -> void:
	var accepted := 0
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Looks.LOOKS_PATH))["looks"]
	for look: Dictionary in looks.values():
		for slot: String in ["top", "sides", "tail"]:
			if look[slot] != null:
				assert_true(Validation.allowed_params(str(look[slot]["part"]), look[slot]["params"]))
				accepted += 1
	assert_gt(accepted, 0)
	assert_false(Validation.allowed_params("user/top/hat", {"scale": 1}))
	assert_false(Validation.allowed_params("unknown", {"scale": 1}))
	var custom := _custom()
	custom["look"]["top"]["params"]["length"] = 999
	assert_false(Validation.validate(custom).is_empty())

func test_unknown_parts_wrong_kind_slot_and_source_are_rejected() -> void:
	var custom := _custom()
	custom["look"]["top"] = {"part": "not_in_the_server_catalogue", "params": {}}
	assert_false(Validation.validate(custom).is_empty())
	for field: String in ["kind", "slot"]:
		custom = _custom()
		_part(custom, _glb())
		custom["parts"].values()[0][field] = "invalid"
		assert_false(Validation.validate(custom).is_empty())
	custom = _custom()
	var source := _part(custom, _glb())
	source["type"] = "image"
	assert_false(Validation.validate(custom).is_empty())

func test_custom_motions_have_count_numeric_and_field_limits() -> void:
	var custom := _custom()
	_part(custom, _glb())
	var part: Dictionary = custom["parts"].values()[0]
	var action: String = Validation.builtin()["action_names"][0]
	part["motions"][action] = [{"type": "sway", "angle_deg": 10, "hz": 1, "axis": "x"}]
	assert_eq(Validation.validate(custom), PackedStringArray())
	part["motions"][action][0]["hz"] = 11
	assert_false(Validation.validate(custom).is_empty())
	part["motions"][action][0]["hz"] = 1
	part["motions"][action][0]["unknown"] = 1
	assert_false(Validation.validate(custom).is_empty())
	part["motions"][action] = []
	for i in int(Config.custom_limits()["motions_per_action"]) + 1:
		part["motions"][action].append({"type": "lift", "height": 0.1})
	assert_false(Validation.validate(custom).is_empty())

func test_png_header_dimensions_truncation_and_byte_limit() -> void:
	assert_eq(Check.check(_png(), "png", true), "")
	assert_false(Check.check(_png(int(Config.custom_limits()["image_side_px"]) + 1), "png").is_empty())
	assert_false(Check.check(_png().slice(0, 25), "png").is_empty())
	var data := _png()
	data.resize(int(Config.custom_limits()["image_bytes"]) + 1)
	assert_eq(Check.check(data, "png"), "image_bytes")

func test_glb_headers_external_uri_embedded_images_counts_and_cycles() -> void:
	assert_eq(Check.check(_glb(), "glb", true), "")
	assert_false(Check.check(_glb().slice(0, 25), "glb").is_empty())
	assert_false(Check.check(_glb(1, {"buffers": [{"byteLength": 36, "uri": "https://example.test/a.bin"}]}), "glb").is_empty())
	assert_false(Check.check(_glb(1, {"images": [{"uri": "data:image/png;base64,any"}]}), "glb").is_empty())
	assert_false(Check.check(_glb(1, {"nodes": [{"mesh": 0, "children": [0]}]}), "glb").is_empty())
	assert_eq(Check.check(_glb(1, {"_test_image": _png()}), "glb"), "")
	assert_false(Check.check(_glb(1, {"_test_image": _png(int(Config.custom_limits()["image_side_px"]) + 1)}), "glb").is_empty())
	assert_false(Check.check(_glb(int(Config.custom_limits()["triangles"]) + 1), "glb").is_empty())
	var nodes: Array = []
	for i in int(Config.custom_limits()["nodes"]) + 1:
		nodes.append({})
	assert_false(Check.check(_glb(1, {"nodes": nodes}), "glb").is_empty())

func test_chunks_can_arrive_out_of_order_and_are_verified() -> void:
	var store := Store.new()
	var data := _glb(ceili(float(Config.custom_limits()["chunk_bytes"]) / 36) + 1)
	var count := ceili(float(data.size()) / int(Config.custom_limits()["chunk_bytes"]))
	var reply := {}
	for i in range(count - 1, -1, -1):
		reply = store.put_chunk(1, _chunk(data, i))
	assert_eq(reply["t"], Protocol.ASSET_OK)
	assert_eq(store.assets[Check.sha(data)]["data"], data)
	var custom := _custom()
	_part(custom, data)
	assert_false(store.missing(custom))
	custom["parts"].values()[0]["source"]["bytes"] += 1
	assert_true(store.missing(custom))

func test_duplicate_negative_fractional_and_mismatched_chunks_are_discarded() -> void:
	var data := _glb(ceili(float(Config.custom_limits()["chunk_bytes"]) / 36) + 1)
	var store := Store.new()
	assert_true(store.put_chunk(1, _chunk(data, 0)).is_empty())
	assert_eq(store.put_chunk(1, _chunk(data, 0))["reason"], "duplicate_or_mismatch")
	assert_true(store.pending.is_empty())
	for value: Variant in [-1, 0.5, ceili(float(data.size()) / int(Config.custom_limits()["chunk_bytes"]))]:
		var message := _chunk(data, 0)
		message["index"] = value
		assert_eq(store.put_chunk(1, message)["t"], Protocol.ASSET_ERROR)
	var message := _chunk(data, 0)
	message["count"] += 1
	assert_eq(store.put_chunk(1, message)["t"], Protocol.ASSET_ERROR)

func test_wrong_hash_extension_bytes_and_base64_never_enter_the_store() -> void:
	var store := Store.new()
	var data := _png()
	var message := _chunk(data, 0, "png", "0".repeat(64))
	assert_eq(store.put_chunk(1, message)["reason"], "hash_or_bytes")
	message = _chunk(data, 0, "glb")
	assert_eq(store.put_chunk(1, message)["t"], Protocol.ASSET_ERROR)
	message = _chunk(data, 0, "png")
	message["bytes"] += 1
	assert_eq(store.put_chunk(1, message)["t"], Protocol.ASSET_ERROR)
	message = _chunk(data, 0, "png")
	message["data"] = "not-base64"
	assert_eq(store.put_chunk(1, message)["t"], Protocol.ASSET_ERROR)
	assert_true(store.assets.is_empty())

func test_pending_budget_timeout_and_disconnect_cleanup() -> void:
	var store := Store.new()
	var size := int(Config.custom_limits()["mesh_bytes"])
	var data := PackedByteArray()
	data.resize(size)
	var accepted := mini(int(Config.custom_limits()["pending_count"]), int(Config.custom_limits()["pending_bytes"]) / size)
	for i in accepted:
		assert_true(store.put_chunk(1, _chunk(data, 0, "glb", str(i).sha256_text()), 100).is_empty())
	assert_eq(store.put_chunk(1, _chunk(data, 0, "glb", "extra".sha256_text()), 100)["reason"], "transfer_budget")
	assert_eq(store.collect({}, 100 + int(Config.custom_limits()["transfer_timeout_s"]) * 1000).size(), accepted)
	assert_true(store.pending.is_empty())
	store.put_chunk(1, _chunk(data, 0, "glb", "a".sha256_text()), 100)
	store.put_chunk(2, _chunk(data, 0, "glb", "b".sha256_text()), 100)
	store.drop(1)
	assert_eq(store.pending.size(), 1)
	assert_eq(store.pending.values()[0]["peer"], 2)

func test_assets_live_while_any_entry_uses_them_and_staging_expires() -> void:
	var store := Store.new()
	var data := _png()
	assert_eq(_upload(store, data, "png")["t"], Protocol.ASSET_OK)
	var hash_value := Check.sha(data)
	store.collect({hash_value: true})
	store.drop(1)
	assert_true(store.assets.has(hash_value))
	store.collect({})
	assert_false(store.assets.has(hash_value))
	_upload(store, data, "png")
	store.collect({}, Time.get_ticks_msec() + int(Config.custom_limits()["transfer_timeout_s"]) * 1000)
	assert_true(store.assets.is_empty())

func test_same_named_user_parts_are_namespaced_by_online_individual() -> void:
	var first := _custom()
	var data := _glb()
	var source := _part(first, data)
	_cache(source, data)
	var second := first.duplicate(true)
	second["display_name"] = "ふたりめ"
	var a := Custom.register(first, "test:first")
	var b := Custom.register(second, "test:second")
	var look_a := Looks.look_for(a)
	var look_b := Looks.look_for(b)
	assert_ne(look_a["top"]["part"], look_b["top"]["part"])
	assert_true(look_a["_online_parts"].has(look_a["top"]["part"]))
	assert_false(Looks.parts().has(look_a["top"]["part"]))
	assert_ne(a, Custom.content_id(first, "other-owner"))

func test_releasing_one_race_keeps_shared_and_other_race_registrations() -> void:
	var first := _custom()
	var second := _custom()
	second["display_name"] = "ふたりめ"
	var a := Custom.register(first, "test:first")
	Custom.register(first, "test:second")
	var b := Custom.register(second, "test:second")
	Custom.release("test:first")
	assert_false(Roster.pururin_by_id(a).is_empty())
	assert_false(Roster.pururin_by_id(b).is_empty())
	Custom.replace_scope("test:second", {b: second})
	assert_true(Custom.custom_for(a).is_empty())
	assert_false(Custom.custom_for(b).is_empty())
	Custom.release("test:second")
	assert_true(Custom.custom_for(b).is_empty())

func test_missing_parts_are_omitted_and_custom_face_uses_maker_base() -> void:
	var custom := _custom()
	_part(custom, _glb())
	_part(custom, _png(), "eyes")
	var id := Custom.register(custom, "test:first")
	var look := Looks.look_for(id)
	assert_null(look["top"])
	assert_eq(look["face"], Looks.look_for(str(Maker.values()["base_pururin"]))["face"])

func test_hide_remote_parts_is_persistent_and_never_hides_own_parts() -> void:
	assert_eq(Settings.hidden(), bool(Config.values()["hide_remote_parts"]))
	var custom := _custom()
	var data := _glb()
	_cache(_part(custom, data), data)
	var a := Custom.register(custom, "test:first", Custom.content_id(custom, "a"), true)
	var b := Custom.register(custom, "test:second", Custom.content_id(custom, "b"))
	Settings.set_hidden(true)
	Settings.use_path(OPTIONS)
	assert_true(Settings.hidden())
	assert_not_null(Looks.look_for(a)["top"])
	assert_null(Looks.look_for(b)["top"])

func test_arriving_asset_rebuilds_the_existing_body_reference() -> void:
	var custom := _custom()
	var data := _glb()
	var source := _part(custom, data)
	var id := Custom.register(custom, "test:first")
	var body := Builder.build(Looks.look_for(id), Looks.values())
	add_child_autofree(body)
	var before := body.get_child_count()
	body.call("set_expression", "joy")
	_cache(source, data)
	Custom.refresh()
	assert_eq(body.get_parent(), self)
	assert_eq(body.call("expression"), "joy")
	assert_gt(body.get_child_count(), before)

func _saved(custom: Dictionary) -> Dictionary:
	var entry := custom.duplicate(true)
	entry.erase("parts")
	entry.merge({"schema_version": Mine.SCHEMA_VERSION, "id": str(Maker.values()["id_prefix"]) + "online-test"})
	return entry

func test_uid_and_secret_survive_reload_and_rotate_only_when_abilities_change() -> void:
	var entry := _saved(_custom())
	assert_eq(Mine.save(entry), "")
	var id := str(entry["id"])
	var uid := Owned.uid(id)
	var secret := Owned.secret(id)
	Owned.use_path(OWNED)
	assert_eq(Owned.uid(id), uid)
	entry["display_name"] = "名前変更"
	assert_eq(Mine.save(entry), "")
	assert_eq(Owned.uid(id), uid)
	var attrs: Array = preload("res://scripts/config/pururin_stats_config.gd").values()["attributes"].keys()
	entry["attribute"] = attrs[(attrs.find(entry["attribute"]) + 1) % attrs.size()]
	entry["look"]["primary_color_index"] = 0
	assert_eq(Mine.save(entry), "")
	assert_ne(Owned.uid(id), uid)
	assert_ne(Owned.secret(id), secret)

func test_custom_ticket_is_seen_by_any_has_ticket() -> void:
	var entry := _saved(_custom())
	assert_eq(Mine.save(entry), "")
	var ticket: Dictionary = Config.values()["free_tickets"][0]
	assert_true(Owned.add_ticket(Owned.uid(entry["id"]), ticket["id"], ticket["name"], 0))
	assert_true(Owned.any_has_ticket(ticket["id"], 1))

func test_sender_removes_paths_and_refuses_unsupported_files() -> void:
	var entry := _saved(_custom())
	assert_eq(Mine.save(entry), "")
	var result := Sender.prepare(entry["id"])
	assert_false(result.has("error"))
	assert_eq(Validation.validate(result["custom"]), PackedStringArray())
	assert_false(JSON.stringify(result["custom"]).contains('"path"'))

func test_protocol_rejects_oversized_utf8_and_invalid_envelopes_before_use() -> void:
	var size := int(Config.custom_limits()["message_bytes"])
	assert_true(Protocol.decode('{"t":"hello","v":10,"name":"' + "あ".repeat(size / 3 + 1) + '"}').is_empty())
	assert_true(Protocol.decode('{"t":{},"v":10}').is_empty())
	assert_true(Protocol.decode('{"t":"hello","v":{}}').is_empty())

func test_log_contains_ability_name_and_hashes_but_no_files_or_secrets() -> void:
	var custom := _custom()
	var source := _part(custom, _glb())
	var log := Log.new()
	log.start({"distance_m": preload("res://scripts/race_session.gd").DEFAULT_DISTANCE_M, "entries": [{"id": Custom.content_id(custom), "custom": custom}]})
	var header: Dictionary = log.get("_header")
	var snapshot: Dictionary = header["entries"][0]["custom"]
	assert_eq(snapshot["display_name"], custom["display_name"])
	assert_eq(snapshot["allocation"], custom["allocation"])
	assert_eq(snapshot["part_hashes"], [source["hash"]])
	assert_false(snapshot.has("look"))
	assert_false(snapshot.has("parts"))
	assert_false(JSON.stringify(header).contains("secret"))

class MessageServer:
	extends "res://scripts/online/online_server.gd"
	var sent := {}
	func _process(_delta: float) -> void:
		pass
	func _send_text(peer: int, text: String) -> void:
		(sent.get_or_add(peer, []) as Array).append(preload("res://scripts/online/online_protocol.gd").decode(text))
	func add_peer(id: int) -> void:
		_peers[id] = {"socket": WebSocketPeer.new(), "name": "", "room": 0, "introduction": "", "icon": clean_icon({}), "free": false, "entries": [], "offer": "", "offer_until_msec": 0, "free_room": 0, "returning": false, "viewing": "", "final_room": "", "rest_until_msec": 0}
	func latest(peer: int, type: String) -> Dictionary:
		var result := {}
		for message: Dictionary in sent.get(peer, []):
			if message["t"] == type:
				result = message
		return result

class MessageClient:
	extends "res://scripts/online/online_client.gd"
	var number := 0
	var server: Node
	var inbox: Array = []
	func _process(_delta: float) -> void:
		pass
	func is_open() -> bool:
		return true
	func _send_now(type: String, fields: Dictionary = {}) -> bool:
		server._receive(number, preload("res://scripts/online/online_protocol.gd").encode(preload("res://scripts/online/online_protocol.gd").message(type, fields)))
		return true
	func deliver() -> void:
		var messages: Array = server.sent.get(number, [])
		while not messages.is_empty():
			var data: Dictionary = messages.pop_front()
			if _custom.receive(data):
				inbox.append(data)

func _server() -> Node:
	var server := MessageServer.new()
	server.listen_on_ready = false
	server.tickets_path = "user://test_online_custom_tickets.json"
	server.results_path = "user://test_online_custom_results.json"
	_files.append(server.tickets_path)
	_files.append(server.results_path)
	add_child_autofree(server)
	return server

func _client(server: Node, peer: int) -> Node:
	server.add_peer(peer)
	var client := MessageClient.new()
	client.number = peer
	client.server = server
	add_child_autofree(client)
	client.hello("テスト%d" % peer)
	client.deliver()
	return client

func _friend_pick(server: Node, client: Node) -> int:
	client.send(Protocol.CREATE, {"room_name": "テスト"})
	var room := int(server.get("_peers")[client.number]["room"])
	client.send(Protocol.RACE_OPEN)
	client.send(Protocol.SETTINGS, {"seats": [true, false, false, false, false, false, false]})
	client.send(Protocol.PICK_OPEN)
	client.deliver()
	return room

func test_server_accepts_custom_pick_and_entry_and_sends_complete_definitions() -> void:
	var server := _server()
	var client := _client(server, 1)
	var room := _friend_pick(server, client)
	var custom := _custom()
	client.send(Protocol.PICK, {"custom": custom})
	var data: Dictionary = server.latest(1, Protocol.ROOM)
	var id := Custom.content_id(custom, "1")
	assert_eq(data["members"][0]["pururin_id"], id)
	assert_eq(data["members"][0]["custom"], custom)
	assert_eq(Roster.pururin_by_id(id)["allocation"], custom["allocation"])
	var entries: Array = server.build_entries(room)
	assert_eq(entries[0]["custom"], custom)
	client.send(Protocol.FREE_ENTER)
	var free_id: String = Config.free_rooms()[0]["id"]
	client.send(Protocol.FREE_ENTRY, {"room_id": free_id, "custom": custom, "uid": "1".repeat(32), "secret": "2".repeat(64)})
	data = server.latest(1, Protocol.FREE_LOBBY)
	assert_eq(data["entries"][0]["custom"], custom)
	client.send(Protocol.FREE_VIEW, {"room_id": free_id})
	data = server.latest(1, Protocol.FREE_ROOM)
	assert_eq(data["entrants"][0]["custom"], custom)
	assert_eq(int(data["entrants"][0]["peer_id"]), 1)
	server._free_call(Time.get_ticks_msec())
	assert_eq(server.latest(1, Protocol.FREE_OFFER)["custom"], custom)
	assert_false(JSON.stringify(server.latest(1, Protocol.FREE_OFFER)).contains("secret"))

func test_server_refuses_missing_assets_and_custom_or_local_ids_for_cpu() -> void:
	var server := _server()
	var client := _client(server, 1)
	_friend_pick(server, client)
	var custom := _custom()
	_part(custom, _glb())
	client.send(Protocol.PICK, {"custom": custom})
	assert_eq(server.latest(1, Protocol.ERROR)["code"], Protocol.ERROR_ASSETS_MISSING)
	custom = _custom()
	client.send(Protocol.PICK, {"custom": custom})
	var id := Custom.content_id(custom, "1")
	for value: String in [id, str(Maker.values()["id_prefix"]) + "test"]:
		client.send(Protocol.CPU_PICK, {"index": 0, "pururin_id": value})
		assert_eq(server.latest(1, Protocol.ERROR)["code"], Protocol.ERROR_BAD_MESSAGE)
	client.send(Protocol.PICK, {"pururin_id": id})
	assert_eq(server.latest(1, Protocol.ERROR)["code"], Protocol.ERROR_BAD_MESSAGE)

func test_sender_uploads_before_pick_and_reports_invalid_source_to_the_player() -> void:
	var server := _server()
	var client := _client(server, 1)
	_friend_pick(server, client)
	var custom := _custom()
	var bytes := _glb(ceili(float(Config.custom_limits()["chunk_bytes"]) / 36) + 1)
	var source := _part(custom, bytes)
	var part_id: String = custom["parts"].keys()[0]
	var local_path := FOLDER.path_join("part.glb")
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	Looks.parts()[part_id] = {"kind": "body_part", "slot": "top", "motions": {}, "source": {"type": "mesh", "path": local_path, "scale": 1, "material": "body"}}
	var entry := _saved(custom)
	assert_eq(Mine.save(entry), "")
	var room := int(server.get("_peers")[1]["room"])
	var before: String = server.get("_rooms")[room]["picks"][1]
	assert_true(client.send(Protocol.PICK, {"pururin_id": entry["id"]}))
	assert_eq(server.get("_rooms")[room]["picks"][1], before)
	var socket := WebSocketPeer.new()
	for i in ceili(float(bytes.size()) / int(Config.custom_limits()["chunk_bytes"])):
		client.get("_custom").tick(socket)
		client.deliver()
	var id := str(server.get("_rooms")[room]["picks"][1])
	assert_true(id.begins_with("c-"))
	assert_eq(client.local_id(id), entry["id"])
	assert_true(server.get("_assets").assets.has(source["hash"]))
	_files.append(Custom.cache_path(source))
	Looks.parts()[part_id]["source"]["path"] = local_path.trim_suffix("glb") + "gltf"
	assert_false(client.send(Protocol.PICK, {"pururin_id": entry["id"]}))
	assert_true(client.last_error.contains("PNG・GLB"))
	Looks.parts().erase(part_id)

func test_receiver_verifies_caches_and_skips_a_second_download() -> void:
	var server := _server()
	var client := _client(server, 2)
	var custom := _custom()
	var bytes := _glb()
	var source := _part(custom, bytes)
	var path := Custom.cache_path(source)
	DirAccess.remove_absolute(path)
	_files.append(path)
	var id := Custom.content_id(custom, "1")
	var message := Protocol.message(Protocol.RACE_START, {"entries": [{"id": id, "peer_id": 1, "custom": custom}]})
	assert_true(client.get("_custom").receive(message))
	assert_null(Looks.look_for(id)["top"])
	var socket := WebSocketPeer.new()
	# asset_get を受け付けるには、名乗っていてサーバーにその部品がある。
	_upload(server.get("_assets"), bytes)
	client.get("_custom").tick(socket)
	assert_true(server.get("_asset_downloads")[2].has(source["hash"]))
	var packet := Protocol.message(Protocol.ASSET_DATA, Store.chunk(source["hash"], "glb", bytes, 0, Protocol.ASSET_DATA))
	client.get("_custom").receive(packet)
	assert_true(FileAccess.file_exists(path))
	assert_eq(FileAccess.get_file_as_bytes(path), bytes)
	assert_not_null(Looks.look_for(id)["top"])
	server.get("_asset_downloads").clear()
	client.get("_custom").receive(message)
	client.get("_custom").tick(socket)
	assert_true(server.get("_asset_downloads").is_empty())

func test_custom_ticket_survives_server_reload_and_rejects_changed_abilities() -> void:
	var server := _server()
	var client := _client(server, 1)
	client.send(Protocol.FREE_ENTER)
	var giver := ""
	var ticket := ""
	var required := ""
	for spec: Dictionary in Config.free_rooms():
		if spec.has("gives_ticket"):
			giver = spec["id"]
			ticket = spec["gives_ticket"]
	for spec: Dictionary in Config.free_rooms():
		if spec.get("needs_ticket", "") == ticket:
			required = spec["id"]
	assert_false(giver.is_empty())
	var custom := _custom()
	var uid := "a".repeat(32)
	var secret := "b".repeat(64)
	client.send(Protocol.FREE_ENTRY, {"room_id": giver, "custom": custom, "uid": uid, "secret": secret})
	var room: int = server._free_make_race(giver)
	var id := Custom.content_id(custom, "1")
	server.get("_rooms")[room]["entries"] = [{"id": id, "runner_id": id, "peer_id": 1, "player": true}]
	server._free_give_ticket(room, [{"id": id, "place": 1}])
	assert_eq(server.get("_tickets")[uid]["pururin_id"], "custom")
	server.get("_tickets").clear()
	server.load_tickets()
	assert_true(server.has_ticket(uid, secret.sha256_text(), id, ticket))
	# 再接続では出走IDが変わっても、uid と能力で同じチケットを使える。
	var other := _client(server, 2)
	other.send(Protocol.FREE_ENTER)
	other.send(Protocol.FREE_ENTRY, {"room_id": required, "custom": custom, "uid": uid, "secret": secret})
	assert_eq(server.get("_peers")[2]["entries"].size(), 1)
	custom = custom.duplicate(true)
	var attrs: Array = preload("res://scripts/config/pururin_stats_config.gd").values()["attributes"].keys()
	custom["attribute"] = attrs[(attrs.find(custom["attribute"]) + 1) % attrs.size()]
	custom["look"]["primary_color_index"] = 0
	other.send(Protocol.FREE_ENTRY, {"room_id": required, "custom": custom, "uid": uid, "secret": secret})
	assert_eq(server.latest(2, Protocol.ERROR)["code"], Protocol.ERROR_NO_TICKET)
	other.send(Protocol.FREE_ENTRY, {"room_id": required, "custom": _custom(), "uid": uid, "secret": "c".repeat(64)})
	assert_eq(server.latest(2, Protocol.ERROR)["code"], Protocol.ERROR_NO_TICKET)

func test_server_gc_keeps_the_other_race_and_releases_finished_only_assets() -> void:
	var server := _server()
	var first := _custom()
	var second := _custom()
	second["display_name"] = "ふたりめ"
	var a := Custom.content_id(first, "1")
	var b := Custom.content_id(second, "2")
	server.get("_customs")[a] = first
	server.get("_customs")[b] = second
	var free_id: String = Config.free_rooms()[0]["id"]
	var room_a: int = server._free_make_race(free_id)
	var room_b: int = server._free_make_race(free_id)
	server.get("_rooms")[room_a]["entries"] = [{"id": a}]
	server.get("_rooms")[room_b]["entries"] = [{"id": b}]
	server._sync_customs()
	server._free_drop_race(room_a)
	server._sync_customs()
	assert_true(Custom.custom_for(a).is_empty())
	assert_false(Custom.custom_for(b).is_empty())
	server._free_drop_race(room_b)
	server._sync_customs()
	assert_true(Custom.custom_for(b).is_empty())

func test_per_pururin_and_server_memory_limits_are_checked_from_config() -> void:
	var custom := _custom()
	var count := int(Config.custom_limits()["pururin_bytes"]) / int(Config.custom_limits()["mesh_bytes"]) + 1
	for i in count:
		var source := _part(custom, _glb())
		source["bytes"] = int(Config.custom_limits()["mesh_bytes"])
		var id: String = custom["parts"].keys()[0]
		var part: Dictionary = custom["parts"][id].duplicate(true)
		custom["parts"]["user/top/extra%d" % i] = part
	assert_true(Validation.validate(custom).has("pururin_bytes"))
	var store := Store.new()
	store.assets["reserved"] = {"peer": 2, "bytes": int(Config.custom_limits()["server_bytes"]), "used": true}
	assert_eq(store.put_chunk(1, _chunk(_png(), 0, "png"))["reason"], "transfer_budget")

func test_finishing_same_hash_for_two_uploaders_drops_the_other_partial_copy() -> void:
	var bytes := _glb(ceili(float(Config.custom_limits()["chunk_bytes"]) / 36) + 1)
	var store := Store.new()
	store.put_chunk(1, _chunk(bytes, 0))
	store.put_chunk(2, _chunk(bytes, 0))
	assert_eq(_upload(store, bytes, "glb", 3)["t"], Protocol.ASSET_OK)
	assert_eq(store.put_chunk(2, _chunk(bytes, 1))["t"], Protocol.ASSET_OK)
	assert_false(store.pending.has("2/" + Check.sha(bytes)))

func test_leaving_or_choosing_builtin_cancels_a_queued_custom_pick() -> void:
	var server := _server()
	var client := _client(server, 1)
	_friend_pick(server, client)
	var custom := _custom()
	var bytes := _glb()
	var source := _part(custom, bytes)
	var part_id: String = custom["parts"].keys()[0]
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var local_path := FOLDER.path_join("part.glb")
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	Looks.parts()[part_id] = {"kind": "body_part", "slot": "top", "motions": {}, "source": {"type": "mesh", "path": local_path, "scale": 1, "material": "body"}}
	var entry := _saved(custom)
	assert_eq(Mine.save(entry), "")
	client.send(Protocol.PICK, {"pururin_id": entry["id"]})
	assert_false(client.get("_custom").get("_commands").is_empty())
	assert_false(client.send(Protocol.CONFIRM, {"on": true}))
	client.send(Protocol.PICK, {"pururin_id": Roster.values()["roster"][0]["id"]})
	assert_true(client.get("_custom").get("_commands").is_empty())
	assert_true(client.get("_custom").get("_uploads").is_empty())
	client.send(Protocol.PICK, {"pururin_id": entry["id"]})
	client.send(Protocol.LEAVE)
	assert_true(client.get("_custom").get("_commands").is_empty())
	_files.append(Custom.cache_path(source))
	Looks.parts().erase(part_id)

func test_picker_lists_created_individuals_after_the_roster_and_cpu_never_does() -> void:
	var entry := _saved(_custom())
	assert_eq(Mine.save(entry), "")
	var lobby := preload("res://scripts/online_free_lobby.gd").new()
	var ids: Array = lobby._roster_ids()
	assert_eq(ids.back(), entry["id"])
	assert_eq(ids.size(), Roster.values()["roster"].size() + Mine.ids().size())
	lobby.free()
	var picker := preload("res://scripts/online/online_pururin_picker.gd").new()
	add_child_autofree(picker)
	picker.open_choices("自分", entry["id"], {})
	assert_not_null(picker.tile_for(entry["id"]))
	picker.cpu_only = true
	picker.open_choices("CPU", str(Roster.values()["roster"][0]["id"]), {})
	assert_null(picker.tile_for(entry["id"]))
	assert_eq(picker.tiles().size(), Roster.values()["roster"].size())
	picker.queue_free()
	await wait_process_frames(2)

func test_options_adds_a_persistent_toggle_in_the_keyboard_focus_order() -> void:
	var screen := preload("res://scenes/options.tscn").instantiate()
	add_child_autofree(screen)
	var toggle: CheckButton = screen.find_child("HideRemoteParts", true, false)
	assert_not_null(toggle)
	assert_eq(toggle.button_pressed, bool(Config.values()["hide_remote_parts"]))
	toggle.button_pressed = not toggle.button_pressed
	assert_eq(Settings.hidden(), toggle.button_pressed)
	var mode: Control = screen.get("_screen_mode_row")
	var guide: Control = screen.get("_guide_button")
	assert_eq(mode.get_node(mode.focus_neighbor_bottom), toggle)
	assert_eq(toggle.get_node(toggle.focus_neighbor_bottom), guide)
	screen.queue_free()
	await wait_process_frames(2)

func test_server_race_uses_custom_abilities_without_reading_custom_meshes() -> void:
	var race_session := preload("res://scripts/race_session.gd")
	var course_only := race_session.is_course_only()
	var server := _server()
	var client := _client(server, 1)
	var room := _friend_pick(server, client)
	var custom := _custom()
	var bytes := _glb()
	var source := _part(custom, bytes)
	_upload(server.get("_assets"), bytes)
	# キャッシュが無くても、サーバーの走者は安全な組み込みの姿で作れる。
	DirAccess.remove_absolute(Custom.cache_path(source))
	client.send(Protocol.PICK, {"custom": custom})
	var entries: Array = server.build_entries(room)
	server.get("_rooms")[room]["entries"] = entries
	server._launch_race(room, entries, race_session.DEFAULT_DISTANCE_M)
	var race: Node = server.room_race(room)
	assert_not_null(race)
	var runners: Array = race.get("_runners")
	assert_eq(runners.size(), entries.size())
	assert_eq(runners[0].get("_pururin")["allocation"], custom["allocation"])
	assert_false(FileAccess.file_exists(Custom.cache_path(source)))
	server._end_race(room)
	server.stop()
	race_session.set_course_only(course_only)
	await wait_process_frames(2)

func test_bad_download_is_not_saved_and_releasing_owner_drops_only_its_hide_exception() -> void:
	var server := _server()
	var client := _client(server, 2)
	var custom := _custom()
	var data := _glb()
	var source := _part(custom, data)
	var path := Custom.cache_path(source)
	DirAccess.remove_absolute(path)
	_files.append(path)
	var id := Custom.content_id(custom, "1")
	client.get("_custom").receive(Protocol.message(Protocol.RACE_START, {"entries": [{"id": id, "peer_id": 1, "custom": custom}]}))
	client.get("_custom").get("_requested")[source["hash"]] = Time.get_ticks_msec() + int(Config.custom_limits()["transfer_timeout_s"]) * 1000
	data[data.size() - 1] ^= 1
	client.get("_custom").receive(Protocol.message(Protocol.ASSET_DATA, Store.chunk(source["hash"], "glb", data, 0, Protocol.ASSET_DATA)))
	assert_false(FileAccess.file_exists(path))
	data = _glb()
	_cache(source, data)
	Custom.register(custom, "test:first", id, true)
	Custom.register(custom, "test:second", id)
	Settings.set_hidden(true)
	assert_not_null(Looks.look_for(id)["top"])
	Custom.release("test:first")
	assert_null(Looks.look_for(id)["top"])
