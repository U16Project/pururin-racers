extends RefCounted
## ユーザーが用意した部品を、置き場所（pururin_maker.json の parts_folder）から探して、部品の一覧の形にする。
## 置き方（フォルダの中）：
##   top/・side/・tail/ … 立体のファイル（.glb など）。ファイル名が部品の名前。
##   mark/              … 画像（.png など）。ファイル名が部品の名前。
##   face/<セットの名前>/ … 顔の画像。「表情_スロット.png」（例：normal_eyes.png、joy_mouth.png）。normal_eyes は必須。
## どの部品も、同じ名前の .json を横に置くと、名前（label）や作り方（source）・動かし方（motions）を上書きできる。
## 顔のセットは、フォルダの中の face.json で、名前（label）と画像の大きさ（image_sizes）を上書きできる。
## ここでは集めるだけ。部品として正しいかは、呼ぶ側（PururinLookConfig）が、組み込みの部品と同じ検査で確かめる。

const MakerConfig := preload("res://scripts/config/pururin_maker_config.gd")
const PururinBody := preload("res://scripts/presentation/pururin_body.gd")
const BODY_SLOTS := ["top", "side", "tail"]
const FOLDERS := ["top", "side", "tail", "mark", "face"]
## 部品のIDの頭。組み込みの部品と、名前がぶつからないように。
const ID_PREFIX := "user/"


## 置き場所のフォルダ（無ければ、中の種類のフォルダごと作る）と、使い方の説明書き。作れなければ、その理由。
static func make_folders() -> String:
	var root := folder()
	for name: String in FOLDERS:
		var error := DirAccess.make_dir_recursive_absolute(root.path_join(name))
		if error != OK:
			return "%s を作れません（%s）" % [root.path_join(name), error_string(error)]
	var readme_setting: Dictionary = MakerConfig.values()["parts_readme"]
	var readme := root.path_join(str(readme_setting["file_name"]))
	if not FileAccess.file_exists(readme):
		var file := FileAccess.open(readme, FileAccess.WRITE)
		if file == null:
			return "%s を作れません（%s）" % [readme, error_string(FileAccess.get_open_error())]
		file.store_string("\n".join(readme_setting["lines"]) + "\n")
	return ""


static func folder() -> String:
	return str(MakerConfig.values()["parts_folder"])


## 探した結果：{"parts": {ID: 部品}, "labels": {ID: 名前}, "face_sets": {ID: {"label", "base", "expressions"}}, "errors": [読めなかった理由]}。
static func scan(expression_names: Array) -> Dictionary:
	var result := {"parts": {}, "labels": {}, "face_sets": {}, "errors": []}
	var settings: Dictionary = MakerConfig.values()["user_parts"]
	var root := folder()
	for slot: String in BODY_SLOTS:
		for file: String in _files(root.path_join(slot), settings["mesh"]["extensions"]):
			var source := {"type": "mesh", "path": root.path_join(slot).path_join(file), "scale": settings["mesh"]["scale"], "material": settings["mesh"]["material"]}
			_add_part(result, "body_part", slot, root.path_join(slot), file, source)
	for file: String in _files(root.path_join("mark"), settings["image_extensions"]):
		_add_part(result, "decoration", "mark", root.path_join("mark"), file, {"type": "image", "path": root.path_join("mark").path_join(file)})
	for set_name: String in DirAccess.get_directories_at(root.path_join("face")):
		_add_face_set(result, root.path_join("face").path_join(set_name), set_name, settings, expression_names)
	return result


## 1つの部品を足す。横に同じ名前の .json があれば、それで上書きする。
static func _add_part(result: Dictionary, kind: String, slot: String, directory: String, file: String, source: Dictionary) -> void:
	var name := file.get_basename()
	var identifier := "%s%s/%s" % [ID_PREFIX, slot, name]
	var part := {"kind": kind, "slot": slot, "source": source}
	if kind == "body_part":
		part["motions"] = {}
	var label := name
	var extra_path := directory.path_join(name + ".json")
	if FileAccess.file_exists(extra_path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
		if not extra is Dictionary:
			result["errors"].append("%s: JSONとして読めません" % extra_path)
			return
		if extra.get("source") is Dictionary:
			source.merge(extra["source"], true)
		if extra.has("motions"):
			part["motions"] = extra["motions"]
		label = str(extra.get("label", name))
	result["parts"][identifier] = part
	result["labels"][identifier] = label


## 顔のセットを1つ足す。表情ごと・スロットごとに、画像を1つの部品にする。
static func _add_face_set(result: Dictionary, directory: String, set_name: String, settings: Dictionary, expression_names: Array) -> void:
	var label := set_name
	var sizes: Dictionary = settings["image_sizes"].duplicate()
	var extra_path := directory.path_join("face.json")
	if FileAccess.file_exists(extra_path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
		if not extra is Dictionary:
			result["errors"].append("%s: JSONとして読めません" % extra_path)
			return
		label = str(extra.get("label", set_name))
		if extra.get("image_sizes") is Dictionary:
			sizes.merge(extra["image_sizes"], true)
	var expressions := {}
	var parts := {}
	for file: String in _files(directory, settings["image_extensions"]):
		var stem := file.get_basename()
		var slot := stem.get_slice("_", stem.get_slice_count("_") - 1)
		var expression := stem.trim_suffix("_" + slot)
		if expression not in expression_names or slot not in MakerConfig.IMAGE_FACE_SLOTS:
			result["errors"].append("%s: ファイル名は「表情_スロット」にします（表情は %s、スロットは %s）" % [directory.path_join(file), "・".join(expression_names), "・".join(MakerConfig.IMAGE_FACE_SLOTS)])
			continue
		var size: Variant = sizes.get(slot)
		if not size is Array or size.size() != 2:
			result["errors"].append("%s: image_sizes.%s は [横, 縦] にします" % [extra_path, slot])
			continue
		var identifier := "%sface/%s/%s/%s" % [ID_PREFIX, set_name, expression, slot]
		parts[identifier] = {"kind": "face", "slot": slot, "source": {"type": "image", "path": directory.path_join(file), "width": size[0], "height": size[1]}}
		if not expressions.has(expression):
			expressions[expression] = {}
		expressions[expression][slot] = identifier
	# ノーマルの目が無いセットは、使えない（ほかの表情で無い部品は、ノーマルを出すため）。
	if not expressions.get(PururinBody.NORMAL, {}).has("eyes"):
		result["errors"].append("%s: %s_eyes の画像が必要です" % [directory, PururinBody.NORMAL])
		return
	result["parts"].merge(parts)
	result["face_sets"]["%s%s" % [ID_PREFIX, set_name]] = {"label": label, "base": str(settings["face_base"]), "expressions": expressions}


## フォルダの中の、拡張子が合うファイル（名前の順）。フォルダが無ければ空。
static func _files(directory: String, extensions: Array) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory):
		return found
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension().to_lower() in extensions:
			found.append(file)
	found.sort()
	return found
