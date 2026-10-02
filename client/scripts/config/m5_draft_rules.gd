extends RefCounted
## M5 の直接／連鎖ドラフト規則。shared の正本をクライアント同梱用に写した JSON を読む。

const PATH := "res://data/config/m5_draft_rules.json"
const NUMBER_RANGES := {
	"schema_version": [1.0, 1.0],
	"assist_max_kmh": [0.0, 90.0],
	"forward_min_m": [0.001, 1000.0],
	"forward_max_m": [0.001, 1000.0],
	"lateral_range_m": [0.001, 1000.0],
	"lateral_falloff_exponent": [0.001, 10.0],
	"chain_attenuation": [0.0, 1.0],
	"wake_base_p": [0.0, 1.0],
	"wake_speed_reference_kmh": [0.001, 300.0],
	"wake_speed_gain_p": [0.0, 1.0],
}

static var _cached: Dictionary = {}
static var _attempted := false
static var last_error := ""


static func load_file(path: String = PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません (%s)" % [path, FileAccess.get_open_error()]}
	return parse_text(file.get_as_text(), path)


static func parse_text(content: String, source: String = PATH) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"error": "%s:%d: %s" % [source, parser.get_error_line(), parser.get_error_message()]}
	var errors := validate(parser.data)
	if not errors.is_empty():
		return {"error": "%s: %s" % [source, "; ".join(errors)]}
	return {"data": parser.data}


static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["ルートはオブジェクトである必要があります"])
	for key in NUMBER_RANGES:
		var value: Variant = data.get(key)
		var limits: Array = NUMBER_RANGES[key]
		if not (value is float or value is int):
			errors.append("%s: 数値が必須です" % key)
		elif not is_finite(float(value)) or value < limits[0] or value > limits[1]:
			errors.append("%s: 範囲 %s〜%s 外です" % [key, limits[0], limits[1]])
	for key in data:
		if not NUMBER_RANGES.has(key):
			errors.append("%s: 未知の設定項目です" % key)
	if not errors.is_empty():
		return errors
	if float(data.forward_min_m) > float(data.forward_max_m):
		errors.append("forward_min_m: forward_max_m 以下にしてください")
	return errors


static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var result := load_file()
		if result.has("error"):
			last_error = result.error
			push_error(last_error)
		else:
			_cached = result.data
			_cached.make_read_only()
	return _cached


static func number(key: String) -> float:
	var data := values()
	assert(not data.is_empty(), last_error)
	return float(data[key])


## wake の基準速度時に、1走者が真後ろへ作る影響量。
## 上限ではなく、HUD表示とローカル応答曲線の単位を揃える基準値。
static func wake_reference_p() -> float:
	return maxf(number("wake_base_p") + number("wake_speed_gain_p"), 0.0001)
