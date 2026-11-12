extends RefCounted
## ユーザーが用意した部品を、置き場所（pururin_maker.json の parts_folder）から探して、部品の一覧の形にする。
## 置き方（フォルダの中）：
##   top/・side/・tail/ … 立体のファイル（.glb など）。ファイル名が部品の名前。
##   mark/              … 画像（.png など）。ファイル名が部品の名前。
##   eyes/・brows/・mouth/・cheeks/<部品の名前>/ … 顔の部品1つ。表情ごとの画像「表情.png」（例：normal.png、joy.png）。normal は必須。
## 頭・横・しっぽ・マークは、同じ名前の .json を横に置くと、名前（label）や作り方（source）・動かし方（motions）を上書きできる。
## 顔の部品は、フォルダの中の part.json で、名前（label）と画像の大きさ（size：[横, 縦]）を上書きできる。
## ここでは集めるだけ。部品として正しいかは、呼ぶ側（PururinLookConfig）が、組み込みの部品と同じ検査で確かめる。

const MakerConfig := preload("res://scripts/config/pururin_maker_config.gd")
const PururinBody := preload("res://scripts/presentation/pururin_body.gd")
const BODY_SLOTS := ["top", "side", "tail"]
const FOLDERS := ["top", "side", "tail", "mark", "eyes", "brows", "mouth", "cheeks"]
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


## 探した結果：{"parts": {ID: 部品}, "labels": {ID: 名前}, "face_parts": {場所: {ID: {"label", "expressions"}}}, "errors": [読めなかった理由]}。
static func scan(expression_names: Array) -> Dictionary:
	var result := {"parts": {}, "labels": {}, "face_parts": {}, "errors": []}
	var settings: Dictionary = MakerConfig.values()["user_parts"]
	var root := folder()
	for slot: String in BODY_SLOTS:
		for file: String in _files(root.path_join(slot), settings["mesh"]["extensions"]):
			var source := {"type": "mesh", "path": root.path_join(slot).path_join(file), "scale": settings["mesh"]["scale"], "material": settings["mesh"]["material"]}
			_add_part(result, "body_part", slot, root.path_join(slot), file, source)
	for file: String in _files(root.path_join("mark"), settings["image_extensions"]):
		_add_part(result, "decoration", "mark", root.path_join("mark"), file, {"type": "image", "path": root.path_join("mark").path_join(file)})
	for slot: String in MakerConfig.IMAGE_FACE_SLOTS:
		result["face_parts"][slot] = {}
		var slot_folder := root.path_join(slot)
		if not DirAccess.dir_exists_absolute(slot_folder):
			continue
		for name: String in DirAccess.get_directories_at(slot_folder):
			_add_face_part(result, slot, slot_folder.path_join(name), name, settings, expression_names)
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


## 顔の部品を1つ足す。表情ごとの画像を、それぞれ1つの絵の部品にする。
static func _add_face_part(result: Dictionary, slot: String, directory: String, name: String, settings: Dictionary, expression_names: Array) -> void:
	var label := name
	var size: Variant = settings["image_sizes"][slot]
	var extra_path := directory.path_join("part.json")
	if FileAccess.file_exists(extra_path):
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
		if not extra is Dictionary:
			result["errors"].append("%s: JSONとして読めません" % extra_path)
			return
		label = str(extra.get("label", name))
		size = extra.get("size", size)
	if not size is Array or size.size() != 2:
		result["errors"].append("%s: size は [横, 縦] にします" % extra_path)
		return
	var family_id := "%s%s/%s" % [ID_PREFIX, slot, name]
	var expressions := {}
	var parts := {}
	for file: String in _files(directory, settings["image_extensions"]):
		var expression := file.get_basename()
		if expression not in expression_names:
			result["errors"].append("%s: ファイル名は表情の名前にします（%s）" % [directory.path_join(file), "・".join(expression_names)])
			continue
		var identifier := "%s/%s" % [family_id, expression]
		parts[identifier] = {"kind": "face", "slot": slot, "source": {"type": "image", "path": directory.path_join(file), "width": size[0], "height": size[1]}}
		expressions[expression] = identifier
	# ノーマルの絵が無い部品は、使えない（絵の無い表情では、ノーマルを出すため）。
	if not expressions.has(PururinBody.NORMAL):
		result["errors"].append("%s: %s の画像が必要です" % [directory, PururinBody.NORMAL])
		return
	result["parts"].merge(parts)
	result["face_parts"][slot][family_id] = {"label": label, "expressions": expressions}


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
