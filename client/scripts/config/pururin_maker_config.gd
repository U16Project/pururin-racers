extends RefCounted
## ぷるりん作成コーナーの設定（data/config/pururin_maker.json）。
## 作ったぷるりんの保存場所、ユーザーが用意した部品の置き場所と、その初期の大きさ、
## 新しく付ける部品の置き方、マークの色、下の色（色と高さ）、顔のセット、画面に出す名前。
## 誤りがあれば、読み込みを失敗にする（last_error に理由を入れ、values() は空を返す）。

const PATH := "res://data/config/pururin_maker.json"
const KEYS := ["schema_version", "save_folder", "parts_folder", "id_prefix", "base_pururin", "name_max_length", "placements", "mark_spots", "mark_colors", "secondary_colors", "secondary_heights", "user_parts", "face_sets", "labels", "parts_readme"]
## 顔のスロットのうち、ユーザーが画像で用意できるもの（ファイル名の「表情_スロット」のスロット）。
const IMAGE_FACE_SLOTS := ["eyes", "brows", "mouth", "cheeks", "effect"]

static var _cached: Dictionary = {}
static var _attempted := false
static var last_error := ""


static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var file := FileAccess.open(PATH, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		var errors := validate(data)
		if errors.is_empty():
			_cached = data
		else:
			last_error = "%s: %s" % [PATH, "; ".join(errors)]
			push_error(last_error)
	return _cached


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["JSONのオブジェクトが必要です"])
	for key: String in KEYS:
		if not data.has(key):
			errors.append("%s: 必要な項目がありません" % key)
	for key: String in data:
		if key not in KEYS:
			errors.append("%s: 未知の項目です" % key)
	if not errors.is_empty():
		return errors
	for key: String in ["save_folder", "parts_folder", "id_prefix", "base_pururin"]:
		if not data[key] is String or str(data[key]).is_empty():
			errors.append("%s: 文字が必要です" % key)
	if not _is_number(data["name_max_length"]) or int(data["name_max_length"]) < 1:
		errors.append("name_max_length: 1以上の数字が必要です")
	var placements: Variant = data["placements"]
	if not placements is Dictionary or not placements.get("sides") is Dictionary or not placements.get("tail") is Dictionary:
		errors.append("placements: sides と tail の置き方が必要です")
	else:
		for key: String in ["yaw_deg", "height_ratio"]:
			if not _is_number(placements["sides"].get(key)):
				errors.append("placements.sides.%s: 数字が必要です" % key)
		if not _is_number(placements["tail"].get("height_ratio")):
			errors.append("placements.tail.height_ratio: 数字が必要です")
	if not data["mark_spots"] is Array or data["mark_spots"].is_empty():
		errors.append("mark_spots: マークの場所が1つ以上必要です")
	else:
		for index in (data["mark_spots"] as Array).size():
			var spot: Variant = data["mark_spots"][index]
			if not spot is Dictionary or not spot.get("label") is String:
				errors.append("mark_spots[%d].label: 文字が必要です" % index)
				continue
			for key: String in ["yaw_deg", "height_ratio", "size"]:
				if not _is_number(spot.get(key)):
					errors.append("mark_spots[%d].%s: 数字が必要です" % [index, key])
	if not data["mark_colors"] is Array or data["mark_colors"].is_empty():
		errors.append("mark_colors: 色が1つ以上必要です")
	else:
		for color: Variant in data["mark_colors"]:
			if not color is String or not Color.html_is_valid(str(color)):
				errors.append("mark_colors: 色（#RRGGBB）が必要です: %s" % color)
	if not data["secondary_colors"] is Array or data["secondary_colors"].is_empty():
		errors.append("secondary_colors: 色が1つ以上必要です")
	else:
		for color: Variant in data["secondary_colors"]:
			if not color is String or not Color.html_is_valid(str(color)):
				errors.append("secondary_colors: 色（#RRGGBB）が必要です: %s" % color)
	if not data["secondary_heights"] is Array or data["secondary_heights"].is_empty():
		errors.append("secondary_heights: 高さの選択肢が1つ以上必要です")
	else:
		for index in (data["secondary_heights"] as Array).size():
			var height: Variant = data["secondary_heights"][index]
			if not height is Dictionary or not height.get("label") is String or not _is_number(height.get("ratio")) or float(height["ratio"]) < 0.0 or float(height["ratio"]) > 1.0:
				errors.append("secondary_heights[%d]: label（文字）と ratio（0〜1）が必要です" % index)
	_validate_user_parts(data["user_parts"], errors)
	if not data["face_sets"] is Dictionary:
		errors.append("face_sets: オブジェクトが必要です")
	else:
		for set_id: String in data["face_sets"]:
			var face_set: Variant = data["face_sets"][set_id]
			if not face_set is Dictionary or not face_set.get("label") is String or not face_set.get("base") is String or not face_set.get("expressions") is Dictionary:
				errors.append("face_sets.%s: label・base・expressions が必要です" % set_id)
	var readme: Variant = data["parts_readme"]
	if not readme is Dictionary or not readme.get("file_name") is String or not readme.get("lines") is Array:
		errors.append("parts_readme: file_name（置くときの名前）と lines（文の並び）が必要です")
	var labels: Variant = data["labels"]
	if not labels is Dictionary or not labels.get("parts") is Dictionary or not labels.get("finishes") is Dictionary or not labels.get("expressions") is Dictionary or not labels.get("stat_descriptions") is Dictionary:
		errors.append("labels: parts・finishes・expressions の名前の一覧と、stat_descriptions（能力の説明）が必要です")
	return errors


static func _validate_user_parts(user_parts: Variant, errors: PackedStringArray) -> void:
	if not user_parts is Dictionary:
		errors.append("user_parts: オブジェクトが必要です")
		return
	var mesh: Variant = user_parts.get("mesh")
	if not mesh is Dictionary or not _is_number(mesh.get("scale")) or str(mesh.get("material", "")) not in ["body", "own"] or not mesh.get("extensions") is Array:
		errors.append("user_parts.mesh: scale・material（body か own）・extensions が必要です")
	if not user_parts.get("image_extensions") is Array:
		errors.append("user_parts.image_extensions: 拡張子の並びが必要です")
	var sizes: Variant = user_parts.get("image_sizes")
	if not sizes is Dictionary:
		errors.append("user_parts.image_sizes: オブジェクトが必要です")
	else:
		for slot: String in IMAGE_FACE_SLOTS:
			var size: Variant = sizes.get(slot)
			if not size is Array or size.size() != 2 or not _is_number(size[0]) or not _is_number(size[1]):
				errors.append("user_parts.image_sizes.%s: [横, 縦] の2つの数字が必要です" % slot)
	if not _is_number(user_parts.get("mark_size")):
		errors.append("user_parts.mark_size: 数字が必要です")
	if not user_parts.get("face_base") is String:
		errors.append("user_parts.face_base: 顔の置き方を借りる個体のIDが必要です")


## 部品・質感・表情の、画面に出す名前。無ければ、IDのまま。
static func label(kind: String, identifier: String) -> String:
	return str(values().get("labels", {}).get(kind, {}).get(identifier, identifier))


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
