extends RefCounted
## ネットから受け付ける作成個体のホワイトリスト。ファイルは開かない。
const Roster := preload("res://scripts/config/pururin_roster_config.gd")
const Looks := preload("res://scripts/config/pururin_look_config.gd")
const Stats := preload("res://scripts/config/pururin_stats_config.gd")
const Trainers := preload("res://scripts/config/cpu_trainers_config.gd")
const Maker := preload("res://scripts/config/pururin_maker_config.gd")
const Body := preload("res://scripts/presentation/pururin_body.gd")
const Check := preload("res://scripts/online/online_part_validation.gd")
const Config := preload("res://scripts/config/online_config.gd")
const FIELDS := ["display_name", "attribute", "running_style", "allocation", "trainer_id", "look", "parts"]
## m・倍率は体の幅1.5mに対して過大にならない範囲。角度は1回転以内。
const NUMBER_RANGES := {
	"height": Vector2(0.01, 2), "base_height": Vector2(0.01, 2),
	"amount": Vector2(0, 3), "speed": Vector2(0.01, 3),
	"secondary_top_ratio": Vector2(0, 1), "outline_width": Vector2(0, 0.1),
	"height_ratio": Vector2(0, 1), "yaw_deg": Vector2(-180, 180), "size": Vector2(0.01, 1.5),
	"eye_yaw_deg": Vector2(-180, 180), "eye_height_ratio": Vector2(0, 1), "eye_tilt_deg": Vector2(-180, 180),
	"eye_lashes": Vector2(0, 8), "mouth_height_ratio": Vector2(0, 1), "cheek_yaw_deg": Vector2(-180, 180), "cheek_height_ratio": Vector2(0, 1),
}
static var _builtin := {}
static var _base_looks := {}

static func builtin() -> Dictionary:
	if _builtin.is_empty():
		_builtin = JSON.parse_string(FileAccess.get_file_as_string(Looks.PARTS_PATH))
		_base_looks = JSON.parse_string(FileAccess.get_file_as_string(Looks.LOOKS_PATH))
	return _builtin

static func validate(custom: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not keys(custom, FIELDS, true):
		return PackedStringArray(["custom_fields"])
	if JSON.stringify(custom).to_utf8_buffer().size() > int(Config.custom_limits()["custom_json_bytes"]):
		return PackedStringArray(["custom_json_bytes"])
	for field: String in ["display_name", "attribute", "running_style", "trainer_id"]:
		if not custom[field] is String:
			errors.append(field + ":string")
	if not errors.is_empty():
		return errors
	var record: Dictionary = custom.duplicate(true)
	record.erase("look")
	record.erase("parts")
	record.merge({"id": "custom", "control_kind": "player", "trainer_name": str(Trainers.by_id(str(custom["trainer_id"])).get("name", ""))})
	Roster._validate_pururin(record, 0, Stats.values()["attributes"], Stats.values()["running_styles"], {}, errors)
	if str(custom["display_name"]).length() > int(Maker.values()["name_max_length"]):
		errors.append("name_length")
	if not custom["parts"] is Dictionary or custom["parts"].size() > int(Config.custom_limits()["parts"]):
		errors.append("parts_count")
		return errors
	var config := builtin()
	var parts: Dictionary = config["parts"].duplicate(true)
	var total := 0
	for id: String in custom["parts"]:
		var part: Variant = custom["parts"][id]
		if not id.begins_with("user/") or id.length() > 160 or not keys(part, ["kind", "slot", "source", "motions"]):
			errors.append("part_fields")
			continue
		var kind := str(part.get("kind", ""))
		var slot := str(part.get("slot", ""))
		if not Looks.SLOTS_BY_KIND.has(kind) or slot not in Looks.SLOTS_BY_KIND[kind]:
			errors.append("part_slot")
			continue
		var mesh := kind == "body_part"
		var source: Variant = part.get("source")
		var allowed := ["type", "hash", "ext", "bytes", "scale", "material"] if mesh else (["type", "hash", "ext", "bytes"] if slot == "mark" else ["type", "hash", "ext", "bytes", "width", "height"])
		if not keys(source, allowed, true):
			errors.append("source_fields")
			continue
		if not source["hash"] is String or RegEx.create_from_string("^[0-9a-f]{64}$").search(str(source["hash"])) == null or not Check.whole(source["bytes"]):
			errors.append("asset_declaration")
			continue
		if source["type"] != ("mesh" if mesh else "image") or source["ext"] != ("glb" if mesh else "png") or int(source["bytes"]) < 1 or int(source["bytes"]) > int(Config.custom_limits()["mesh_bytes" if mesh else "image_bytes"]):
			errors.append("asset_limit")
		total += int(source["bytes"])
		if mesh:
			if not number(source["scale"], 0.01, 4) or source["material"] not in ["body", "own"]:
				errors.append("mesh_scale_material")
			var motions: Variant = part.get("motions")
			Looks._validate_motions(id, motions, config["action_names"], errors)
			if motions is Dictionary:
				for action: String in motions:
					if not motions[action] is Array or motions[action].size() > int(Config.custom_limits()["motions_per_action"]):
						errors.append("motion_count")
						continue
					for motion: Variant in motions[action]:
						if motion is Dictionary:
							for key: String in motion:
								if key in ["type", "axis"]:
									continue
								var bound := 180.0 if key == "angle_deg" else (10.0 if key in ["hz", "phase"] else 2.0)
								if not number(motion[key], -bound, bound):
									errors.append("motion_range")
		elif part.has("motions") or (slot != "mark" and (not number(source["width"], 0.01, 1.5) or not number(source["height"], 0.01, 1.5))):
			errors.append("face_size_or_motions")
		# 既存の look 検査には安全な同スロットの定義を渡し、ローカルのファイルは見に行かせない。
		for candidate: Dictionary in config["parts"].values():
			if candidate["slot"] == slot and candidate["kind"] == kind and candidate["source"]["type"] == "builtin":
				parts[id] = candidate
				break
	if total > int(Config.custom_limits()["pururin_bytes"]):
		errors.append("pururin_bytes")
	if not errors.is_empty():
		return errors
	var look: Variant = custom["look"]
	if not keys(look, Looks.LOOK_KEYS, true) or _has_path(look):
		return PackedStringArray(["look_fields_or_path"])
	if not keys(look["body"], ["type", "shape", "height", "base_height"], true) or look["body"].get("type") != "builtin" or look["body"].get("shape") != "dome" or look["body_texture"] != null:
		return PackedStringArray(["body_builtin_only"])
	if not keys(look["body_motion"], ["set", "amount", "speed"], true):
		return PackedStringArray(["body_motion_fields"])
	for slot: String in ["top", "sides", "tail"]:
		var placement: Variant = look[slot]
		if placement == null:
			continue
		var allowed := ["part", "params"] + (["height_ratio", "yaw_deg"] if slot == "sides" else (["height_ratio"] if slot == "tail" else []))
		if not keys(placement, allowed, true) or not placement["params"] is Dictionary:
			errors.append("placement_fields")
			continue
		if not allowed_params(str(placement["part"]), placement["params"]):
			errors.append("params")
	var face_keys: Array = Looks.FACE_NUMBER_KEYS + ["eye_size", "eye_colors", "cheek_color", "expressions"]
	if not keys(look["face"], face_keys, true) or not look["marks"] is Array or look["marks"].size() > Maker.values()["mark_spots"].size():
		return PackedStringArray(["face_or_mark_fields"])
	for mark: Variant in look["marks"]:
		if not keys(mark, ["part", "yaw_deg", "height_ratio", "size", "color"], true):
			errors.append("mark_fields")
	if not errors.is_empty():
		return errors
	_numeric_ranges(look, errors)
	Looks._validate_look("custom.look", look, parts, config["finishes"], config["body_motions"], _base_looks["expression_names"], errors)
	if not errors.is_empty():
		return errors
	if float(look["body"]["base_height"]) > float(look["body"]["height"]):
		errors.append("body_base_height")
	var colors: Array = Stats.primary_colors(str(custom["attribute"]))
	if int(look["primary_color_index"]) >= colors.size():
		errors.append("primary_color_index")
	if not Check.whole(look["face"]["eye_lashes"]):
		errors.append("eye_lashes_integer")
	var used := used_parts(look)
	for id: String in custom["parts"]:
		if not used.has(id):
			errors.append("unused_part")
	return errors

static func allowed_params(part: String, params: Dictionary) -> bool:
	if params.is_empty():
		return true
	if part.begins_with("user/"):
		return false
	builtin()
	for original: Dictionary in _base_looks["looks"].values():
		for slot: String in ["top", "sides", "tail"]:
			var placement: Variant = original[slot]
			if placement is Dictionary and placement["part"] == part and placement["params"] == params:
				return true
	return false

static func used_parts(look: Dictionary) -> Dictionary:
	var used := {}
	for slot: String in ["top", "sides", "tail"]:
		if look[slot] != null:
			used[str(look[slot]["part"])] = true
	for mark: Dictionary in look["marks"]:
		used[str(mark["part"])] = true
	for slots: Dictionary in look["face"]["expressions"].values():
		for part: Variant in slots.values():
			if part != null:
				used[str(part)] = true
	return used

static func _numeric_ranges(value: Variant, errors: PackedStringArray, key: String = "") -> void:
	if value is Dictionary:
		for k: String in value:
			if k != "params": # 組み込み params は元の設定との完全一致で検査済み。
				_numeric_ranges(value[k], errors, k)
	elif value is Array:
		for item: Variant in value:
			_numeric_ranges(item, errors, key)
	elif NUMBER_RANGES.has(key):
		var bounds: Vector2 = NUMBER_RANGES[key]
		if not number(value, bounds.x, bounds.y):
			errors.append("range:" + key)
	elif key == "eye_size" and not number(value, 0.01, 0.75):
		errors.append("eye_size_range")

static func keys(value: Variant, allowed: Array, required: bool = false) -> bool:
	if not value is Dictionary or (required and not value.has_all(allowed)):
		return false
	for key: Variant in value:
		if not key is String or key not in allowed:
			return false
	return true

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _has_path(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return true
	if value is Dictionary:
		for key: String in value:
			if key == "path" or _has_path(value[key], depth + 1):
				return true
	elif value is Array:
		for item: Variant in value:
			if _has_path(item, depth + 1):
				return true
	return false
