extends RefCounted
## 絵の部品で組み立てる操作盤（PartsRaceHud）の、部品の一覧。正本は res://data/config/heart_hud_parts.json。
## 部品の絵は、どれも同じ大きさ（canvas）の透明なPNGで、下絵と同じ位置に描く（位置合わせはいらない）。
## layers は、下から順に重ねる絵。fill の付いた絵は、値の割合だけ見せる（fills の決まりで）。
## each の付いた絵は、ノッチ・ブーストの1つずつの絵（ファイル名の {n} が 1, 2, …）。
## font は、文字に使う字のファイル（無ければ、ゲームの字を太らせて使う）。
## texts は、こちらのコードで書く文字（下の線の左はし、または align が center ならまん中）。
## 部品の一覧の詳しい説明は docs/操作盤の部品一覧.md。

const CONFIG_PATH := "res://data/config/heart_hud_parts.json"
## fill の向き（Godot の TextureProgressBar の向き）。
const FILL_MODES := {
	"clockwise": TextureProgressBar.FILL_CLOCKWISE,
	"counter_clockwise": TextureProgressBar.FILL_COUNTER_CLOCKWISE,
	"bottom_to_top": TextureProgressBar.FILL_BOTTOM_TO_TOP,
	"left_to_right": TextureProgressBar.FILL_LEFT_TO_RIGHT,
}
## 弧の向き（中心と角度が要る）。
const RADIAL_MODES := ["clockwise", "counter_clockwise"]
## 操作盤が値を入れられる fill の名前と、each の名前と、tint・fade の名前。
const FILL_NAMES := ["speed", "stamina", "stamina_debt", "aero_total", "aero_green", "heart", "dash", "boost_running"]
const EACH_NAMES := ["notch", "boost"]
const TINT_NAMES := ["heart"]
const FADE_NAMES := ["beat"]
## 文字の色の名前。
const TEXT_COLORS := ["white", "text", "gold"]

static var last_error := ""
static var _config: Dictionary = {}


## 一覧。読めない・足りないときは、空を返して、last_error に理由を入れる。
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


static func _is_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int)


static func validate_config(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("heart_hud_parts: オブジェクトが必要です")
		return errors
	if not str(data.get("image_dir", "")).begins_with("res://"):
		errors.append("heart_hud_parts.image_dir: res:// で始まる場所が必要です")
	if data.has("font") and not str(data["font"]).begins_with("res://"):
		errors.append("heart_hud_parts.font: res:// で始まる字のファイルが必要です")
	if not _is_point(data.get("canvas")) or float(data["canvas"][0]) < 1.0 or float(data["canvas"][1]) < 1.0:
		errors.append("heart_hud_parts.canvas: [横, 縦] が必要です")
	var fills: Variant = data.get("fills")
	if not fills is Dictionary:
		errors.append("heart_hud_parts.fills: オブジェクトが必要です")
		fills = {}
	for name: String in fills:
		var fill: Variant = fills[name]
		var label := "heart_hud_parts.fills.%s" % name
		if not name in FILL_NAMES:
			errors.append("%s: 知らない名前です（%s）" % [label, ", ".join(FILL_NAMES)])
		if not fill is Dictionary or not FILL_MODES.has(str(fill.get("mode", ""))):
			errors.append("%s.mode: %s のどれかが必要です" % [label, ", ".join(FILL_MODES.keys())])
			continue
		if str(fill["mode"]) in RADIAL_MODES:
			if not _is_point(fill.get("center")):
				errors.append("%s.center: 弧のまん中 [x, y] が必要です" % label)
			for key: String in ["start_deg", "sweep_deg"]:
				if not (fill.get(key) is float or fill.get(key) is int):
					errors.append("%s.%s: 数字が必要です" % [label, key])
		if fill.has("full_value") and (not (fill["full_value"] is float or fill["full_value"] is int) or float(fill["full_value"]) <= 0.0):
			errors.append("%s.full_value: 0より大きい数字が必要です" % label)
	var layers: Variant = data.get("layers")
	if not layers is Array or layers.is_empty():
		errors.append("heart_hud_parts.layers: 絵が1つ以上必要です")
	else:
		for index in layers.size():
			var layer: Variant = layers[index]
			var label := "heart_hud_parts.layers[%d]" % index
			if not layer is Dictionary or not str(layer.get("file", "")).ends_with(".png"):
				errors.append("%s.file: .png のファイル名が必要です" % label)
				continue
			if layer.has("fill") and not (fills as Dictionary).has(str(layer["fill"])):
				errors.append("%s.fill: fills に無い名前です（%s）" % [label, str(layer["fill"])])
			if layer.has("each"):
				if not str(layer["each"]) in EACH_NAMES:
					errors.append("%s.each: %s のどれかが必要です" % [label, ", ".join(EACH_NAMES)])
				if not str(layer["file"]).contains("{n}"):
					errors.append("%s.file: each の絵のファイル名には {n} が必要です" % label)
			if layer.has("tint") and not str(layer["tint"]) in TINT_NAMES:
				errors.append("%s.tint: %s のどれかが必要です" % [label, ", ".join(TINT_NAMES)])
			if layer.has("fade") and not str(layer["fade"]) in FADE_NAMES:
				errors.append("%s.fade: %s のどれかが必要です" % [label, ", ".join(FADE_NAMES)])
	var texts: Variant = data.get("texts")
	if not texts is Array:
		errors.append("heart_hud_parts.texts: 配列が必要です")
	else:
		for index in texts.size():
			var text: Variant = texts[index]
			var label := "heart_hud_parts.texts[%d]" % index
			if not text is Dictionary or not _is_point(text.get("at")) or not text.get("runs") is Array or text["runs"].is_empty():
				errors.append("%s: at [x, y] と runs が必要です" % label)
				continue
			if text.has("align") and not str(text["align"]) in ["left", "center"]:
				errors.append("%s.align: left か center が必要です" % label)
			for run: Variant in text["runs"]:
				if not run is Array or not run.size() in [3, 4, 5] or (run.size() >= 4 and not _is_point(run[3])) or (run.size() == 5 and not (run[4] is float or run[4] is int)) or not run[0] is String or not (run[1] is float or run[1] is int) or not str(run[2]) in TEXT_COLORS:
					errors.append("%s.runs: [文字, 大きさ, 色（%s）, ずらし [横, 縦], 横の縮め具合]（後ろの2つはなくてもよい）が必要です" % [label, ", ".join(TEXT_COLORS)])
					break
	for key: String in ["attribute_mark", "style_mark"]:
		var mark: Variant = data.get(key)
		var point_key := "center" if key == "attribute_mark" else "center_left"
		if not mark is Dictionary or not _is_point(mark.get(point_key)):
			errors.append("heart_hud_parts.%s.%s: [x, y] が必要です" % [key, point_key])
	return errors


## 絵のファイル名の並び（each の絵は、数ぶん広げる）。notch_count・boost_count は、ゲームの設定の数。
static func image_files(data: Dictionary, notch_count: int, boost_count: int) -> PackedStringArray:
	var files := PackedStringArray()
	for layer: Dictionary in data["layers"]:
		if layer.has("each"):
			var count := notch_count if str(layer["each"]) == "notch" else boost_count
			for n in range(1, count + 1):
				files.append(str(layer["file"]).replace("{n}", str(n)))
		else:
			files.append(str(layer["file"]))
	return files


## まだ無い絵のファイル名（素材の側が、あと何を描けばよいか）。
static func missing_images(data: Dictionary, notch_count: int, boost_count: int) -> PackedStringArray:
	var missing := PackedStringArray()
	for file in image_files(data, notch_count, boost_count):
		if not ResourceLoader.exists(str(data["image_dir"]).path_join(file)) and not FileAccess.file_exists(str(data["image_dir"]).path_join(file)):
			missing.append(file)
	return missing
