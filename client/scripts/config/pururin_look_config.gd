extends RefCounted
## ぷるりんの見た目の設定。部品の一覧（pururin_parts.json）と、個体ごとの見た目（pururin_looks.json）を読み、検査する。
## 設定に誤り（知らない部品、無いファイル、足りない数字、ノーマルの顔が無い、など）があれば、
## 別の形に替えずに、読み込みを失敗にする（last_error に理由を入れ、values() は空を返す）。
## 体の色（第一カラー）は、個体の属性の選択肢（pururin_stats.json の primary_colors）から、番号で選ぶ。
## values() と look_for() が返す見た目は、番号を色に直したもの（primary_color と outline_color が入っている）。

const PARTS_PATH := "res://data/config/pururin_parts.json"
const LOOKS_PATH := "res://data/config/pururin_looks.json"
const BodyParts := preload("res://scripts/presentation/pururin_parts/body_parts.gd")
const FaceParts := preload("res://scripts/presentation/pururin_parts/face_parts.gd")
const PartAssets := preload("res://scripts/presentation/pururin_parts/part_assets.gd")
const PururinBody := preload("res://scripts/presentation/pururin_body.gd")
const Builder := preload("res://scripts/presentation/pururin_body_builder.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
## 部品の種類と、その種類が使えるスロット。
const SLOTS_BY_KIND := {"body_part": ["top", "side", "tail"], "face": ["eyes", "brows", "mouth", "cheeks", "effect"], "decoration": ["mark"]}
## 個体の設定の、体の一部の項目と、そこに入れられる部品のスロット。
const LOOK_BODY_PART_SLOTS := {"top": "top", "sides": "side", "tail": "tail"}
const LOOK_KEYS := ["body", "body_texture", "finish", "body_motion", "primary_color_index", "secondary_color", "secondary_top_ratio", "outline_width", "top", "sides", "tail", "face", "marks"]
const FACE_NUMBER_KEYS := ["eye_yaw_deg", "eye_height_ratio", "eye_tilt_deg", "eye_lashes", "mouth_height_ratio", "cheek_yaw_deg", "cheek_height_ratio"]

static var _cached: Dictionary = {}
static var _attempted := false
static var last_error := ""


## 2つの設定ファイルを読んで、検査する。成功なら {"parts": …, "finishes": …, "expression_names": …, "showcase": …, "looks": …}、失敗なら {"error": 理由}。
static func load_files(parts_path: String = PARTS_PATH, looks_path: String = LOOKS_PATH) -> Dictionary:
	var parts_file := _read_json(parts_path)
	if parts_file.has("error"):
		return parts_file
	var looks_file := _read_json(looks_path)
	if looks_file.has("error"):
		return looks_file
	var errors := validate(parts_file["data"], looks_file["data"])
	if not errors.is_empty():
		return {"error": "; ".join(errors)}
	return {
		"parts": parts_file["data"]["parts"],
		"finishes": parts_file["data"]["finishes"],
		"action_names": parts_file["data"]["action_names"],
		"body_motions": parts_file["data"]["body_motions"],
		"expression_names": looks_file["data"]["expression_names"],
		"showcase": looks_file["data"]["showcase"],
		"looks": looks_file["data"]["looks"],
	}


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません" % path}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"error": "%s: JSONとして読めません" % path}
	return {"data": parser.data}


## ゲームの設定。個体一覧・属性の設定と突き合わせて検査し、第一カラーの番号を色に直したものを返す。
static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var result := load_files()
		if not result.has("error"):
			var roster: Array = PururinRosterConfig.values().get("roster", [])
			var attributes: Dictionary = PururinStatsConfig.values().get("attributes", {})
			var errors := validate_for_roster(result["looks"], roster, attributes)
			if errors.is_empty():
				for pururin: Dictionary in roster:
					var id := str(pururin["id"])
					result["looks"][id] = resolved_look(result["looks"][id], attributes[str(pururin["attribute"])]["primary_colors"])
			else:
				result = {"error": "; ".join(errors)}
		if result.has("error"):
			last_error = str(result["error"])
			push_error(last_error)
		else:
			_cached = result
	return _cached


static func parts() -> Dictionary:
	return values().get("parts", {})


## 質感の一覧。
static func finishes() -> Dictionary:
	return values().get("finishes", {})


## レース選択画面で体を回すときの決まり（turn_seconds＝1回転の秒数、expressions＝順に出す表情）。
static func showcase() -> Dictionary:
	return values().get("showcase", {})


## 個体の見た目（第一カラーの番号を、色に直したもの）。設定に無い個体なら、空。
static func look_for(pururin_id: String) -> Dictionary:
	return values().get("looks", {}).get(pururin_id, {})


## 個体の色（第一カラー）。操作盤・順位表などの丸にも、この色を使う。
## 見た目の設定に無い個体は、設定の誤りとして知らせる（別の色に替えて、黙って進めない）。
static func primary_color_for(pururin_id: String) -> Color:
	var look := look_for(pururin_id)
	if look.is_empty():
		push_error("見た目の設定に、個体がありません: %s" % pururin_id)
		return Color.MAGENTA
	return Color(str(look["primary_color"]))


## 第一カラーの番号を、選択肢（色と、ふちの線の色の組の並び）から選んで、色に直した見た目を返す。
static func resolved_look(look: Dictionary, primary_colors: Array) -> Dictionary:
	var choice: Dictionary = primary_colors[int(look["primary_color_index"])]
	var resolved := look.duplicate(true)
	resolved["primary_color"] = str(choice["color"])
	resolved["outline_color"] = str(choice["outline"])
	return resolved


## 個体一覧との突き合わせ。全員に見た目があること、一覧に無い個体の見た目が無いこと、
## 第一カラーの番号が、その属性の選択肢の中にあること。
static func validate_for_roster(looks: Dictionary, roster: Array, attributes: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for pururin: Dictionary in roster:
		var id := str(pururin["id"])
		ids[id] = true
		if not looks.has(id):
			errors.append("looks.%s: 個体一覧にある個体の見た目がありません" % id)
			continue
		var choices: Array = attributes[str(pururin["attribute"])]["primary_colors"]
		var index := int(looks[id]["primary_color_index"])
		if index >= choices.size():
			errors.append("looks.%s.primary_color_index: 属性 %s の第一カラーは %d 色です（0〜%d）" % [id, pururin["attribute"], choices.size(), choices.size() - 1])
	for id: String in looks:
		if not ids.has(id):
			errors.append("looks.%s: 個体一覧に無い個体です" % id)
	return errors


## 設定の検査。誤りの一覧を返す（空なら正しい）。
static func validate(parts_data: Variant, looks_data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not parts_data is Dictionary or not parts_data.get("parts") is Dictionary:
		errors.append("parts: 部品の一覧（オブジェクト）が必要です")
		return errors
	if not looks_data is Dictionary or not looks_data.get("looks") is Dictionary:
		errors.append("looks: 個体ごとの見た目（オブジェクト）が必要です")
		return errors
	if not parts_data.get("finishes") is Dictionary:
		errors.append("finishes: 質感の一覧（オブジェクト）が必要です")
		return errors
	# アクションの名前の一覧（あとから足せる）。部品の動かし方に書くアクションは、この一覧にある名前だけ。
	var action_names: Variant = parts_data.get("action_names")
	if not action_names is Array:
		errors.append("action_names: アクションの名前の一覧が必要です")
		return errors
	var part_list: Dictionary = parts_data["parts"]
	for part_id: String in part_list:
		_validate_part(part_id, part_list[part_id], action_names, errors)
	var finish_list: Dictionary = parts_data["finishes"]
	for finish_id: String in finish_list:
		_validate_finish("finishes.%s" % finish_id, finish_list[finish_id], errors)
	# 体全体の動かし方の一覧。
	var body_motion_list: Variant = parts_data.get("body_motions")
	if not body_motion_list is Dictionary:
		errors.append("body_motions: 体全体の動かし方の一覧（オブジェクト）が必要です")
		return errors
	for motion_id: String in body_motion_list:
		_validate_body_motion("body_motions.%s" % motion_id, body_motion_list[motion_id], action_names, errors)
	if not errors.is_empty():
		return errors
	# 表情の名前の一覧（あとから足せる）。個体の設定に書く表情は、この一覧にある名前だけ（書き間違いを見つけるため）。
	var expression_names: Variant = looks_data.get("expression_names")
	if not expression_names is Array or PururinBody.NORMAL not in expression_names:
		errors.append("expression_names: 表情の名前の一覧（%s を含む）が必要です" % PururinBody.NORMAL)
		return errors
	# レース選択画面で体を回すときの決まり（1回転の秒数と、順に出す表情）。
	var showcase: Variant = looks_data.get("showcase")
	if not showcase is Dictionary or not _is_number(showcase.get("turn_seconds")) or float(showcase["turn_seconds"]) <= 0.0:
		errors.append("showcase.turn_seconds: 0より大きい数字が必要です")
	elif not showcase.get("expressions") is Array or showcase["expressions"].is_empty():
		errors.append("showcase.expressions: 順に出す表情の名前が1つ以上必要です")
	else:
		for name: Variant in showcase["expressions"]:
			if name not in expression_names:
				errors.append("showcase.expressions: 表情の名前の一覧（expression_names）にありません: %s" % name)
	for pururin_id: String in looks_data["looks"]:
		_validate_look("looks.%s" % pururin_id, looks_data["looks"][pururin_id], part_list, finish_list, body_motion_list, expression_names, errors)
	return errors


## 体全体の動かし方の検査。actions（アクションごとの動かし方）、one_shots（1回だけの動き）、steer_lean_deg。
static func _validate_body_motion(label: String, body_motion: Variant, action_names: Array, errors: PackedStringArray) -> void:
	if not body_motion is Dictionary:
		errors.append("%s: オブジェクトが必要です" % label)
		return
	for key: String in body_motion:
		if key not in ["actions", "one_shots", "steer_lean_deg"]:
			errors.append("%s.%s: 未知の項目です" % [label, key])
	_require_number(body_motion, "steer_lean_deg", label, errors)
	_validate_motions("%s.actions" % label, body_motion.get("actions"), action_names, errors)
	var one_shots: Variant = body_motion.get("one_shots")
	if not one_shots is Dictionary:
		errors.append("%s.one_shots: 1回だけの動きの一覧（オブジェクト。無ければ空）が必要です" % label)
		return
	for name: String in one_shots:
		var one_shot: Variant = one_shots[name]
		var one_label := "%s.one_shots.%s" % [label, name]
		if not one_shot is Dictionary or not _is_number(one_shot.get("seconds")) or float(one_shot["seconds"]) <= 0.0:
			errors.append("%s.seconds: 0より大きい数字が必要です" % one_label)
			continue
		_validate_motion_list("%s.motions" % one_label, one_shot.get("motions"), errors)


static func _validate_finish(label: String, finish: Variant, errors: PackedStringArray) -> void:
	if not finish is Dictionary:
		errors.append("%s: オブジェクトが必要です" % label)
		return
	for key: String in Builder.FINISH_NUMBER_KEYS:
		_require_number(finish, key, label, errors)
	for key: String in Builder.FINISH_COLOR_KEYS:
		_require_color(finish, key, label, errors)
	for key: String in finish:
		if key not in Builder.FINISH_NUMBER_KEYS and key not in Builder.FINISH_COLOR_KEYS:
			errors.append("%s.%s: 未知の項目です" % [label, key])


static func _validate_part(part_id: String, part: Variant, action_names: Array, errors: PackedStringArray) -> void:
	var label := "parts.%s" % part_id
	if not part is Dictionary:
		errors.append("%s: オブジェクトが必要です" % label)
		return
	var kind := str(part.get("kind", ""))
	var slot := str(part.get("slot", ""))
	if not SLOTS_BY_KIND.has(kind):
		errors.append("%s.kind: body_part・face・decoration のどれかが必要です" % label)
		return
	if slot not in SLOTS_BY_KIND[kind]:
		errors.append("%s.slot: %s で使えるのは %s です" % [label, kind, ", ".join(SLOTS_BY_KIND[kind])])
		return
	# 体の一部は、アクションごとの動かし方（空でもよい）を持つ。
	if kind == "body_part":
		_validate_motions("%s.motions" % label, part.get("motions"), action_names, errors)
	_validate_source(label, slot, kind, part.get("source"), errors)


## 動かし方の検査。アクションの名前 → 動かし方の並び。
static func _validate_motions(label: String, motions: Variant, action_names: Array, errors: PackedStringArray) -> void:
	if not motions is Dictionary:
		errors.append("%s: アクションごとの動かし方（オブジェクト。無ければ空）が必要です" % label)
		return
	for action: String in motions:
		if action not in action_names:
			errors.append("%s.%s: アクションの名前の一覧（action_names）にありません" % [label, action])
			continue
		_validate_motion_list("%s.%s" % [label, action], motions[action], errors)


## 動かし方の並びの検査。
static func _validate_motion_list(label: String, motions: Variant, errors: PackedStringArray) -> void:
	if not motions is Array:
		errors.append("%s: 動かし方の並びが必要です" % label)
		return
	for index in (motions as Array).size():
		var motion: Variant = motions[index]
		var motion_label := "%s[%d]" % [label, index]
		if not motion is Dictionary or not PururinBody.MOTION_TYPES.has(str(motion.get("type", ""))):
			errors.append("%s.type: %s のどれかが必要です" % [motion_label, "・".join(PururinBody.MOTION_TYPES.keys())])
			continue
		var rule: Dictionary = PururinBody.MOTION_TYPES[str(motion["type"])]
		for key: String in rule["numbers"]:
			_require_number(motion, key, motion_label, errors)
		if bool(rule["axis"]) and not PururinBody.AXES.has(str(motion.get("axis", ""))):
			errors.append("%s.axis: x・y・z のどれかが必要です" % motion_label)
		if motion.has("phase") and not _is_number(motion["phase"]):
			errors.append("%s.phase: 数字が必要です" % motion_label)
		for key: String in motion:
			if key not in ["type", "phase"] and key not in rule["numbers"] and not (key == "axis" and bool(rule["axis"])):
				errors.append("%s.%s: 未知の項目です" % [motion_label, key])


static func _validate_source(label: String, slot: String, kind: String, source: Variant, errors: PackedStringArray) -> void:
	if not source is Dictionary:
		errors.append("%s.source: オブジェクトが必要です" % label)
		return
	match str(source.get("type", "")):
		"builtin":
			var shapes: Array = (BodyParts.BUILTIN_SHAPES if kind == "body_part" else FaceParts.BUILTIN_SHAPES)[slot]
			var shape := str(source.get("shape", ""))
			if shape not in shapes:
				errors.append("%s.source.shape: %s に使える形は %s です" % [label, slot, ", ".join(shapes)])
				return
			if kind == "body_part":
				for key: String in BodyParts.REQUIRED_PARAMS[shape]:
					_require_number(source, key, "%s.source" % label, errors)
				for key: String in BodyParts.REQUIRED_COLORS.get(shape, []):
					_require_color(source, key, "%s.source" % label, errors)
			else:
				for key: String in FaceParts.REQUIRED_PARAMS[shape]:
					_require_number(source, key, "%s.source" % label, errors)
				for key: String in FaceParts.REQUIRED_COLORS.get(shape, []):
					_require_color(source, key, "%s.source" % label, errors)
		"mesh":
			if kind != "body_part":
				errors.append("%s.source.type: メッシュを使えるのは、体の一部（body_part）だけです" % label)
				return
			_validate_mesh_source("%s.source" % label, source, errors)
		"image":
			if kind == "body_part":
				errors.append("%s.source.type: 画像を使えるのは、顔とマークだけです" % label)
				return
			_require_file(source, "path", "%s.source" % label, errors)
			if slot != "mark":
				_require_number(source, "width", "%s.source" % label, errors)
				_require_number(source, "height", "%s.source" % label, errors)
		_:
			errors.append("%s.source.type: builtin・mesh・image のどれかが必要です" % label)


static func _validate_mesh_source(label: String, source: Dictionary, errors: PackedStringArray) -> void:
	_require_file(source, "path", label, errors)
	_require_number(source, "scale", label, errors)
	if str(source.get("material", "")) not in ["body", "own"]:
		errors.append("%s.material: body（体と同じ素材）か own（メッシュの素材のまま）が必要です" % label)


static func _validate_look(label: String, look: Variant, part_list: Dictionary, finish_list: Dictionary, body_motion_list: Dictionary, expression_names: Array, errors: PackedStringArray) -> void:
	if not look is Dictionary:
		errors.append("%s: オブジェクトが必要です" % label)
		return
	for key: String in LOOK_KEYS:
		if not look.has(key):
			errors.append("%s.%s: 必要な項目がありません" % [label, key])
	for key: String in look:
		if key not in LOOK_KEYS:
			errors.append("%s.%s: 未知の項目です" % [label, key])
	if not errors.is_empty():
		return
	# 体
	var body: Variant = look["body"]
	if not body is Dictionary:
		errors.append("%s.body: オブジェクトが必要です" % label)
		return
	_require_number(body, "height", "%s.body" % label, errors)
	_require_number(body, "base_height", "%s.body" % label, errors)
	match str(body.get("type", "")):
		"builtin":
			if str(body.get("shape", "")) != "dome":
				errors.append("%s.body.shape: こちらで作れる体の形は dome です" % label)
		"mesh":
			_validate_mesh_source("%s.body" % label, body, errors)
		_:
			errors.append("%s.body.type: builtin か mesh が必要です" % label)
	if look["body_texture"] != null and not PartAssets.exists(str(look["body_texture"])):
		errors.append("%s.body_texture: ファイルがありません: %s" % [label, look["body_texture"]])
	if not finish_list.has(str(look["finish"])):
		errors.append("%s.finish: 質感の一覧にありません: %s" % [label, look["finish"]])
	# 体全体の動かし方（一覧の名前）と、その個体の、動きの大きさ・速さの倍率。
	var body_motion: Variant = look["body_motion"]
	if not body_motion is Dictionary or not body_motion_list.has(str(body_motion.get("set", ""))):
		errors.append("%s.body_motion.set: 体全体の動かし方の一覧（body_motions）にある名前が必要です" % label)
	else:
		_require_number(body_motion, "amount", "%s.body_motion" % label, errors)
		_require_number(body_motion, "speed", "%s.body_motion" % label, errors)
	var color_index: Variant = look["primary_color_index"]
	if not _is_number(color_index) or float(color_index) != floorf(float(color_index)) or int(color_index) < 0:
		errors.append("%s.primary_color_index: 0以上の整数（属性の第一カラーの、何番目か）が必要です" % label)
	_require_color(look, "secondary_color", label, errors)
	_require_number(look, "secondary_top_ratio", label, errors)
	_require_number(look, "outline_width", label, errors)
	# 体の一部（無しにするときは null）
	for key: String in LOOK_BODY_PART_SLOTS:
		var placement: Variant = look[key]
		if placement == null:
			continue
		if not placement is Dictionary or not placement.get("params") is Dictionary:
			errors.append("%s.%s: part と params（オブジェクト）が必要です（付けないときは null）" % [label, key])
			continue
		var before := errors.size()
		_require_part(placement, LOOK_BODY_PART_SLOTS[key], part_list, "%s.%s" % [label, key], errors)
		if errors.size() == before:
			# 個体ごとの上書き（params）を混ぜたあとの作り方も、部品と同じ検査にかける。
			var part: Dictionary = part_list[str(placement["part"])]
			_validate_source("%s.%s.params" % [label, key], str(part["slot"]), "body_part", Builder.merged_source(part, placement), errors)
		if key != "top":
			_require_number(placement, "height_ratio", "%s.%s" % [label, key], errors)
		if key == "sides":
			_require_number(placement, "yaw_deg", "%s.%s" % [label, key], errors)
	_validate_face("%s.face" % label, look["face"], part_list, expression_names, errors)
	# マーク
	if not look["marks"] is Array:
		errors.append("%s.marks: 並び（無ければ空）が必要です" % label)
		return
	for index in (look["marks"] as Array).size():
		var mark: Variant = look["marks"][index]
		var mark_label := "%s.marks[%d]" % [label, index]
		if not mark is Dictionary:
			errors.append("%s: オブジェクトが必要です" % mark_label)
			continue
		_require_part(mark, "mark", part_list, mark_label, errors)
		for key: String in ["yaw_deg", "height_ratio", "size"]:
			_require_number(mark, key, mark_label, errors)
		_require_color(mark, "color", mark_label, errors)


static func _validate_face(label: String, face: Variant, part_list: Dictionary, expression_names: Array, errors: PackedStringArray) -> void:
	if not face is Dictionary:
		errors.append("%s: オブジェクトが必要です" % label)
		return
	for key: String in FACE_NUMBER_KEYS:
		_require_number(face, key, label, errors)
	var eye_size: Variant = face.get("eye_size")
	if not eye_size is Array or eye_size.size() != 2 or not _is_number(eye_size[0]) or not _is_number(eye_size[1]):
		errors.append("%s.eye_size: [横の半分, 縦の半分] の2つの数字が必要です" % label)
	var eye_colors: Variant = face.get("eye_colors")
	if not eye_colors is Array or eye_colors.size() != 2 or not Color.html_is_valid(str(eye_colors[0])) or not Color.html_is_valid(str(eye_colors[1])):
		errors.append("%s.eye_colors: [暗い色, 明るい色] の2つの色が必要です" % label)
	_require_color(face, "cheek_color", label, errors)
	var expressions: Variant = face.get("expressions")
	if not expressions is Dictionary:
		errors.append("%s.expressions: 表情ごとの部品（オブジェクト）が必要です" % label)
		return
	# ノーマルは必須。ほかの表情で部品が無いスロットは、ノーマルを出すので、ノーマルには目が要る。
	if not expressions.get(PururinBody.NORMAL) is Dictionary or expressions[PururinBody.NORMAL].get("eyes") == null:
		errors.append("%s.expressions.%s: ノーマルの表情（少なくとも eyes）が必要です" % [label, PururinBody.NORMAL])
	for expression: String in expressions:
		if expression not in expression_names:
			errors.append("%s.expressions.%s: 表情の名前の一覧（expression_names）にありません" % [label, expression])
			continue
		var slots: Variant = expressions[expression]
		if not slots is Dictionary:
			errors.append("%s.expressions.%s: オブジェクトが必要です" % [label, expression])
			continue
		for slot: String in slots:
			if slot not in PururinBody.FACE_SLOTS:
				errors.append("%s.expressions.%s.%s: 顔のスロットは %s です" % [label, expression, slot, ", ".join(PururinBody.FACE_SLOTS)])
				continue
			# null は、「この表情では、このスロットに何も出さない」。
			if slots[slot] == null:
				continue
			var part_id := str(slots[slot])
			if not part_list.has(part_id) or str(part_list[part_id]["slot"]) != slot:
				errors.append("%s.expressions.%s.%s: %s 用の部品が、部品の一覧にありません: %s" % [label, expression, slot, slot, part_id])


static func _require_part(holder: Dictionary, slot: String, part_list: Dictionary, label: String, errors: PackedStringArray) -> void:
	var part_id := str(holder.get("part", ""))
	if not part_list.has(part_id):
		errors.append("%s.part: 部品の一覧にありません: %s" % [label, part_id])
	elif str(part_list[part_id]["slot"]) != slot:
		errors.append("%s.part: %s は、%s 用の部品ではありません" % [label, part_id, slot])


static func _require_number(holder: Dictionary, key: String, label: String, errors: PackedStringArray) -> void:
	if not _is_number(holder.get(key)):
		errors.append("%s.%s: 数字が必要です" % [label, key])


static func _require_color(holder: Dictionary, key: String, label: String, errors: PackedStringArray) -> void:
	if not holder.get(key) is String or not Color.html_is_valid(str(holder[key])):
		errors.append("%s.%s: 色（#RRGGBB か #RRGGBBAA）が必要です" % [label, key])


static func _require_file(holder: Dictionary, key: String, label: String, errors: PackedStringArray) -> void:
	if not holder.get(key) is String or not PartAssets.exists(str(holder[key])):
		errors.append("%s.%s: ファイルがありません: %s" % [label, key, holder.get(key)])


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
