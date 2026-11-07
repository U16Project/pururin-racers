extends RefCounted
## オンライン個体の登録。各サーバー・部屋・レース・画面が独立した scope を所有する。
const Validate := preload("res://scripts/online/online_custom_validation.gd")
const Looks := preload("res://scripts/config/pururin_look_config.gd")
const Stats := preload("res://scripts/config/pururin_stats_config.gd")
const Trainers := preload("res://scripts/config/cpu_trainers_config.gd")
const Maker := preload("res://scripts/config/pururin_maker_config.gd")
const Check := preload("res://scripts/online/online_part_validation.gd")
static var _records := {}
static var _scopes := {}
static var _mine := {}
static var _bodies: Array = []
static var _cache_checked := {}

static func content_id(custom: Dictionary, owner: String = "") -> String:
	return "c-" + (_canonical(custom) + ":" + owner).sha256_text()

static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var ordered: Array = value.keys()
		ordered.sort()
		var items: Array[String] = []
		for key: String in ordered:
			items.append(JSON.stringify(key) + ":" + _canonical(value[key]))
		return "{" + ",".join(items) + "}"
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value:
			items.append(_canonical(item))
		return "[" + ",".join(items) + "]"
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return JSON.stringify(int(value))
	return JSON.stringify(value)

static func register(custom: Dictionary, scope: String, id: String = "", mine: bool = false) -> String:
	if id.is_empty():
		id = content_id(custom)
	if not _scopes.has(scope):
		_scopes[scope] = {}
	_scopes[scope][id] = true
	if mine:
		(_mine.get_or_add(id, {}) as Dictionary)[scope] = true
	if not _records.has(id):
		_records[id] = custom.duplicate(true)
		_changed(id)
	return id

## スコープを一度で置き換える。別スコープで使用中の個体には触らない。
static func replace_scope(scope: String, records: Dictionary, mine_ids: Dictionary = {}) -> void:
	_release_mine(scope)
	_scopes[scope] = {}
	for id: String in records:
		register(records[id], scope, id, mine_ids.has(id))
	_collect()

static func release(scope: String) -> void:
	_scopes.erase(scope)
	_release_mine(scope)
	_collect()

static func _release_mine(scope: String) -> void:
	for id: String in _mine.keys():
		_mine[id].erase(scope)
		if _mine[id].is_empty():
			_mine.erase(id)

static func _collect() -> void:
	var used := {}
	for ids: Dictionary in _scopes.values():
		used.merge(ids)
	for id: String in _records.keys():
		if not used.has(id):
			for part: Dictionary in _records[id]["parts"].values():
				var path := cache_path(part["source"])
				_cache_checked.erase(path)
				load("res://scripts/presentation/pururin_parts/part_assets.gd").forget(path)
			_records.erase(id)
			_mine.erase(id)
			_changed(id)

static func custom_for(id: String) -> Dictionary:
	return _records.get(id, {})

static func pururin_by_id(id: String) -> Dictionary:
	if not _records.has(id):
		return {}
	var result: Dictionary = _records[id].duplicate(true)
	result.erase("look")
	result.erase("parts")
	result.merge({"id": id, "control_kind": "player", "trainer_name": str(Trainers.by_id(str(result["trainer_id"])).get("name", ""))})
	return result

static func look_for(id: String) -> Dictionary:
	if not _records.has(id):
		return {}
	var custom: Dictionary = _records[id]
	var look: Dictionary = custom["look"].duplicate(true)
	var hide: bool = load("res://scripts/online/online_parts_settings.gd").hidden() and not _mine.has(id)
	var parts := {}
	for part_id: String in custom["parts"]:
		var part: Dictionary = custom["parts"][part_id].duplicate(true)
		var source: Dictionary = part["source"]
		if not hide and cached(source):
			source["path"] = cache_path(source)
			parts[id + "/" + part_id] = part
	for slot: String in ["top", "sides", "tail"]:
		if look[slot] != null and str(look[slot]["part"]).begins_with("user/"):
			var name := id + "/" + str(look[slot]["part"])
			if parts.has(name):
				look[slot]["part"] = name
			else:
				look[slot] = null
	var marks: Array = []
	for mark: Dictionary in look["marks"]:
		if str(mark["part"]).begins_with("user/"):
			var name := id + "/" + str(mark["part"])
			if not parts.has(name):
				continue
			mark["part"] = name
		marks.append(mark)
	look["marks"] = marks
	var fallback: Dictionary = Looks.look_for(str(Maker.values()["base_pururin"]))["face"]
	var missing_face := false
	for slots: Dictionary in look["face"]["expressions"].values():
		for part: Variant in slots.values():
			if part != null and str(part).begins_with("user/") and not parts.has(id + "/" + str(part)):
				missing_face = true
	if missing_face:
		# 顔の寸法も含めて元の顔を代わりにし、届いた表情の部品だけはその上に付ける。
		var expressions: Dictionary = look["face"]["expressions"]
		look["face"] = fallback.duplicate(true)
		for expression: String in expressions:
			for slot: String in expressions[expression]:
				var part: Variant = expressions[expression][slot]
				if part != null and str(part).begins_with("user/") and parts.has(id + "/" + str(part)):
					if not look["face"]["expressions"].has(expression):
						look["face"]["expressions"][expression] = {}
					look["face"]["expressions"][expression][slot] = id + "/" + str(part)
	else:
		for slots: Dictionary in look["face"]["expressions"].values():
			for slot: String in slots:
				if slots[slot] != null and str(slots[slot]).begins_with("user/"):
					slots[slot] = id + "/" + str(slots[slot])
	look["_online_parts"] = parts
	look["_online_id"] = id
	return Looks.resolved_look(look, Stats.values()["attributes"][custom["attribute"]]["primary_colors"])

static func cache_path(source: Dictionary) -> String:
	return "user://online_parts_cache/" + str(source["hash"]) + "." + str(source["ext"])

static func cached(source: Dictionary) -> bool:
	var path := cache_path(source)
	if not FileAccess.file_exists(path):
		_cache_checked.erase(path)
		return false
	var stamp := "%s:%s" % [FileAccess.get_modified_time(path), FileAccess.open(path, FileAccess.READ).get_length()]
	if _cache_checked.get(path) == stamp:
		return true
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() != int(source["bytes"]) or Check.sha(data) != source["hash"] or not Check.check(data, str(source["ext"]), true).is_empty():
		return false
	_cache_checked[path] = stamp
	return true

static func _changed(id: String) -> void:
	load("res://scripts/cpu_brain/brain_observe.gd").forget(id)
	load("res://scripts/presentation/pururin_portrait_cache.gd").forget(id)

static func watch(body: Node3D, id: String) -> void:
	_bodies = _bodies.filter(func(item: Dictionary) -> bool: return item["body"].get_ref() != null)
	_bodies.append({"body": weakref(body), "id": id})

static func refresh(hash_value: String = "") -> void:
	_cache_checked.clear()
	var affected := {}
	for id: String in _records:
		if hash_value.is_empty():
			affected[id] = true
		else:
			for part: Dictionary in _records[id]["parts"].values():
				if part["source"]["hash"] == hash_value:
					affected[id] = true
	for id: String in affected:
		_changed(id)
	var live: Array = []
	for item: Dictionary in _bodies:
		var body: Node3D = item["body"].get_ref()
		if body == null or body.is_queued_for_deletion() or body.get_parent() == null or not _records.has(item["id"]):
			continue
		if not affected.has(item["id"]):
			live.append(item)
			continue
		var expression: String = body.call("expression")
		var action: String = body.call("action")
		# 走者などの Body への参照を保ち、同じ節の中身を組み立て直す。
		for child in body.get_children():
			body.remove_child(child)
			child.queue_free()
		body.set_script(null)
		body.set_script(load("res://scripts/presentation/pururin_body.gd"))
		load("res://scripts/presentation/pururin_body_builder.gd").build(look_for(item["id"]), Looks.values(), false, body)
		body.call("set_expression", expression)
		body.call("set_action", action)
		live.append(item)
	_bodies = live
