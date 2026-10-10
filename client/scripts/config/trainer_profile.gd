extends RefCounted
## ユーザー（トレーナー）の登録内容：名前と、画像。
## 決まり（名前の長さ、最初の名前、画像の大きさ）は res://data/config/trainer_profile.json。
## 登録した内容は、ユーザーの保存場所（user://）に置く。まだ登録していないときは、決まりの「最初の名前」と、画像なしで始まる。

const CONFIG_PATH := "res://data/config/trainer_profile.json"
const DEFAULT_SAVE_PATH := "user://trainer_profile.json"
const DEFAULT_ICON_PATH := "user://trainer_icon.png"
## 画像の種類。none＝なし、avatar＝用意してある人の絵（id が絵のID）、file＝自分で選んだ画像ファイル。
const ICON_KINDS := ["none", "avatar", "file"]
## 用意してある人の絵の、髪型の種類。
const HAIR_STYLES := ["short", "long", "spiky", "bob", "ponytail"]
## 用意してある人の絵の、体つき（顔の形・まゆ・肩幅などを変える）。
const BODIES := ["male", "female"]

## 保存する場所（テストでは、use_paths で別の場所に替える）。
static var _save_path: String = DEFAULT_SAVE_PATH
static var _icon_path: String = DEFAULT_ICON_PATH
static var last_error := ""
static var _config: Dictionary = {}
static var _data: Dictionary = {}
static var _loaded := false
static var _icon_texture: Texture2D


## 決まり。読めない・足りないときは、空を返して、last_error に理由を入れる。
static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		var errors := validate_config(parsed)
		if errors.is_empty():
			_config = parsed
		else:
			last_error = "; ".join(errors)
			push_error(last_error)
	return _config


static func validate_config(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("trainer_profile: オブジェクトが必要です")
		return errors
	for key: String in ["name_min_length", "name_max_length", "icon_size_px", "introduction_max_length"]:
		if not (data.get(key) is float or data.get(key) is int) or float(data[key]) < 1.0:
			errors.append("trainer_profile.%s: 1以上の数字が必要です" % key)
	if errors.is_empty() and int(data["name_min_length"]) > int(data["name_max_length"]):
		errors.append("trainer_profile.name_min_length: name_max_length 以下にしてください")
	if not data.get("default_introduction") is String or (errors.is_empty() and str(data["default_introduction"]).length() > int(data["introduction_max_length"])):
		errors.append("trainer_profile.default_introduction: 決まりの長さに収まる紹介文が必要です")
	# 用意してある人の絵（仮）。髪型と、髪・肌・服の色で描く。
	var avatars: Variant = data.get("avatars")
	if not avatars is Array or avatars.is_empty():
		errors.append("trainer_profile.avatars: 人の絵が1つ以上必要です")
	else:
		var ids := {}
		for index in avatars.size():
			var avatar: Variant = avatars[index]
			var label := "trainer_profile.avatars[%d]" % index
			if not avatar is Dictionary or str(avatar.get("id", "")).is_empty() or ids.has(avatar.get("id")):
				errors.append("%s.id: 空または重複です" % label)
				continue
			ids[avatar["id"]] = true
			if str(avatar.get("body", "")) not in BODIES:
				errors.append("%s.body: %s のどちらかが必要です" % [label, "・".join(BODIES)])
			if str(avatar.get("hair_style", "")) not in HAIR_STYLES:
				errors.append("%s.hair_style: %s のどれかが必要です" % [label, "・".join(HAIR_STYLES)])
			for key: String in ["hair_color", "skin_color", "shirt_color"]:
				if not avatar.get(key) is String or not Color.html_is_valid(avatar[key]):
					errors.append("%s.%s: 色が必要です" % [label, key])
	if not data.get("default_name") is String or (errors.is_empty() and not _length_ok(data, str(data["default_name"]))):
		errors.append("trainer_profile.default_name: 決まりの長さに収まる名前が必要です")
	return errors


static func _length_ok(rules: Dictionary, text: String) -> bool:
	return text.length() >= int(rules["name_min_length"]) and text.length() <= int(rules["name_max_length"])


## 保存する場所を替えて、読み直す（テスト用。本物の登録内容に触らないため）。
static func use_paths(save: String, icon_file: String) -> void:
	_save_path = save
	_icon_path = icon_file
	reload_profile()


## 保存してある内容を読み直す。
## （名前を reload にしない。スクリプトそのものを読み直すGodotの命令と重なって、外から呼ぶと、そちらが動く。）
static func reload_profile() -> void:
	_loaded = true
	_icon_texture = null
	_data = {"name": str(config()["default_name"]), "introduction": str(config()["default_introduction"]), "icon": {"kind": "none", "id": ""}}
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	# 保存した内容が壊れているときは、黙って使わず、知らせる（最初の内容で始める）。
	if not parsed is Dictionary or not name_problem(str(parsed.get("name", ""))).is_empty() or not parsed.get("icon") is Dictionary or str(parsed["icon"].get("kind", "")) not in ICON_KINDS or (str(parsed["icon"]["kind"]) == "avatar" and avatar_by_id(str(parsed["icon"].get("id", ""))).is_empty()):
		last_error = "トレーナーの登録内容を読めません: %s" % _save_path
		push_error(last_error)
		return
	# 紹介文は、あとから足した項目。前の版で保存した内容には無いので、そのときは、最初の紹介文にする。
	var saved_introduction: Variant = parsed.get("introduction", str(config()["default_introduction"]))
	if not saved_introduction is String or not introduction_problem(saved_introduction).is_empty():
		last_error = "トレーナーの登録内容を読めません: %s" % _save_path
		push_error(last_error)
		return
	_data = {"name": str(parsed["name"]), "introduction": str(saved_introduction), "icon": {"kind": str(parsed["icon"]["kind"]), "id": str(parsed["icon"].get("id", ""))}}


static func _ensure_loaded() -> void:
	if not _loaded:
		reload_profile()


## トレーナー名。
static func trainer_name() -> String:
	_ensure_loaded()
	return str(_data["name"])


## 名前として使えない理由（使えるなら空）。前後の空白は、数えない。
static func name_problem(text: String) -> String:
	var rules := config()
	var trimmed := text.strip_edges()
	if not _length_ok(rules, trimmed):
		return "名前は %d〜%d 文字にしてください" % [int(rules["name_min_length"]), int(rules["name_max_length"])]
	for index in trimmed.length():
		if trimmed.unicode_at(index) < 32:
			return "名前に、改行などは使えません"
	return ""


## トレーナーの紹介文。
static func introduction() -> String:
	_ensure_loaded()
	return str(_data["introduction"])


## 紹介文として使えない理由（使えるなら空）。空でもよい。改行は、空白に直して数える。
static func introduction_problem(text: String) -> String:
	var limit := int(config()["introduction_max_length"])
	if clean_introduction(text).length() > limit:
		return "紹介文は %d 文字までにしてください" % limit
	return ""


## 紹介文の、前後の空白を取り、改行を空白に直したもの。
static func clean_introduction(text: String) -> String:
	return text.replace("\r", "").replace("\n", " ").strip_edges()


## 紹介文を登録する。長すぎるなら、理由を返して、何も変えない。
static func set_introduction(text: String) -> String:
	_ensure_loaded()
	var problem := introduction_problem(text)
	if problem.is_empty():
		_data["introduction"] = clean_introduction(text)
		_save()
	return problem


## 名前を登録する。使えない名前なら、理由を返して、何も変えない。
static func set_trainer_name(text: String) -> String:
	_ensure_loaded()
	var problem := name_problem(text)
	if problem.is_empty():
		_data["name"] = text.strip_edges()
		_save()
	return problem


## 画像の登録内容（kind と id）。
static func icon() -> Dictionary:
	_ensure_loaded()
	return (_data["icon"] as Dictionary).duplicate()


## 用意してある人の絵の一覧。
static func avatars() -> Array:
	return config()["avatars"]


## 用意してある人の絵（id で探す）。無ければ空。
static func avatar_by_id(avatar_id: String) -> Dictionary:
	for avatar: Dictionary in avatars():
		if str(avatar["id"]) == avatar_id:
			return avatar
	return {}


## 画像を、用意してある人の絵にする。
static func set_icon_avatar(avatar_id: String) -> void:
	_ensure_loaded()
	assert(not avatar_by_id(avatar_id).is_empty(), "人の絵がありません: %s" % avatar_id)
	_data["icon"] = {"kind": "avatar", "id": avatar_id}
	_icon_texture = null
	_save()


## 画像を、なしにする。
static func clear_icon() -> void:
	_ensure_loaded()
	_data["icon"] = {"kind": "none", "id": ""}
	_icon_texture = null
	_save()


## 画像を、自分で選んだファイルにする。まん中を正方形に切り取り、決まりの大きさにして、保存場所へ写す。
## 読めないファイルなら、理由を返して、何も変えない。
static func set_icon_file(source_path: String) -> String:
	_ensure_loaded()
	var image: Image = Image.load_from_file(source_path) if FileAccess.file_exists(source_path) else null
	if image == null or image.is_empty():
		return "画像を読めません: %s" % source_path
	var side := mini(image.get_width(), image.get_height())
	var square := image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	var size_px := int(config()["icon_size_px"])
	square.resize(size_px, size_px, Image.INTERPOLATE_LANCZOS)
	if square.save_png(_icon_path) != OK:
		return "画像を保存できません: %s" % _icon_path
	_data["icon"] = {"kind": "file", "id": ""}
	_icon_texture = null
	_save()
	return ""


## 自分で選んだ画像（kind が file のとき）。それ以外は null。
static func icon_texture() -> Texture2D:
	_ensure_loaded()
	if str(_data["icon"]["kind"]) != "file":
		return null
	if _icon_texture == null:
		var image := Image.load_from_file(_icon_path)
		if image != null and not image.is_empty():
			_icon_texture = ImageTexture.create_from_image(image)
	return _icon_texture


static func _save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		last_error = "トレーナーの登録内容を保存できません: %s" % _save_path
		push_error(last_error)
		return
	file.store_string(JSON.stringify(_data, "  "))

