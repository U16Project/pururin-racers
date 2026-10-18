extends Control
## 絵の部品で組み立てる、左上の操作盤（ハート型）。見た目は、素材の側が描いた部品の絵（透明なPNG）だけで決まる。
## こちらは、部品を下から重ねて置き、増減する部品を値の割合だけ見せ（Godot の TextureProgressBar）、数字と名前を書く。
## 部品の一覧・置き方・文字の位置は res://data/config/heart_hud_parts.json（読み込みは HeartHudPartsConfig）。
## 絵はどれも同じ大きさ（canvas）で、下絵と同じ位置に描かれている。読み込むときに、透明な所を切り落として軽くする。
## 値を受け取るのは update_state（レースの操作盤の値。丸い操作盤 RoundRaceHud と同じ）。
## 大きさは set_scale_factor（1＝canvas の半分）。

const PartsConfig := preload("res://scripts/config/heart_hud_parts_config.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const HudPainter := preload("res://scripts/presentation/hud_painter.gd")
const FitText := preload("res://scripts/presentation/fit_text.gd")

## 文字：少し右へ傾ける（高さ1あたりの横のずれ）、ふちの太さ、色。
const TEXT_SLANT := 0.18
const OUTLINE_SIZE := 14
const COLOR_OUTLINE := Color(0.02, 0.03, 0.06, 0.95)
const TEXT_COLORS := {
	"white": Color.WHITE,
	"text": Color(0.95, 0.97, 1.0, 1.0),
	"gold": Color(1.0, 0.9, 0.12, 1.0),
}

## 心拍の水の色：低いうちは水色。ふつうの上限の手前から黄、上限を超えると赤。
const COLOR_HEART_LOW := Color(0.2, 0.92, 1.0, 1.0)
const COLOR_HEART_MID := RaceHud.COLOR_WARN
const COLOR_HEART_HIGH := RaceHud.COLOR_DANGER
const HEART_WARN_FROM_BPM := 40.0
const HEART_WARN_AT_BPM := 20.0
## 鼓動の光：音が鳴った瞬間が1、そこからすっと消える（鼓動1回のうち、最初のどれだけ光るか）。
const HEART_BEAT_PART := 0.4

var _state := {
	"speed_kmh": 0.0, "notch": 1, "notch_max": 6, "heart_bpm": 100.0, "heart_beat_phase": 1.0, "heart_min_bpm": 100.0, "heart_normal_max_bpm": 200.0, "heart_max_bpm": 230.0,
	"fuel_ratio": 1.0, "air_green": 0.0, "air_blue": 0.0, "boost_ratio": 0.0, "dash_ratio": 0.0, "boost_uses_left": 0, "boost_max_uses": 3,
	"player_name": "", "trainer_name": "", "attribute_id": "", "attribute_color": Color.WHITE,
	"style_group_count": 0, "style_group_index": 0, "style_rank_bonus": 0,
}
var _config: Dictionary = {}
var _canvas := Vector2.ONE
var _scale := 1.0
## 部品の絵を乗せる台（canvas の大きさ。set_scale_factor で、まとめて縮める）と、文字を書く面。
var _stage: Control
var _text_layer: Control
## fill の名前 → その絵（TextureProgressBar）。each の名前 → その絵の並び（1, 2, … の順）。
var _fills := {}
var _each := {}
## tint の名前 → 色を変える絵。fade の名前 → 濃さを変える絵。
var _tints := {}
var _fades := {}
## 組み立てたときの、ノッチの数とブーストの回数（変わったら組み立て直す）。
var _built_counts := Vector2i(-1, -1)
var _painter := HudPainter.new()
var _bold: FontVariation
## まだ無い絵（組み立てたときに、見つからなかったファイル名）。
var missing_images := PackedStringArray()
## 絵の置き場を、一覧（image_dir）とは別の場所にする（試しの絵で確かめるとき。_ready の前に入れる）。空なら一覧のまま。
var image_dir_override := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_config = PartsConfig.config().duplicate(true)
	if _config.is_empty():
		return
	if not image_dir_override.is_empty():
		_config["image_dir"] = image_dir_override
	_canvas = Vector2(float(_config["canvas"][0]), float(_config["canvas"][1]))
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 絵は大きく描いてあり、縮めて出すので、縮小用の絵（ミップマップ）を使って、ふちのギザギザを防ぐ。
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.size = _canvas
	add_child(_stage)
	_build()
	set_scale_factor(_scale)
	# 準備より先に届いていた値を、入れる。
	_apply()


## 全体の大きさを変える（1＝canvas の半分）。
func set_scale_factor(value: float) -> void:
	_scale = value
	custom_minimum_size = _canvas * 0.5 * _scale
	size = custom_minimum_size
	if _stage != null:
		_stage.scale = Vector2.ONE * _scale * 0.5


func update_state(values: Dictionary) -> void:
	for key in values:
		_state[key] = values[key]
	if _stage == null:
		return
	if Vector2i(int(_state["notch_max"]), int(_state["boost_max_uses"])) != _built_counts:
		_build()
	_apply()


## 心拍の水の色。低いうちは水色、ふつうの上限に近づくと黄、超えると赤。
static func heart_water_color(bpm: float, normal_max_bpm: float, max_bpm: float) -> Color:
	var warn_from := normal_max_bpm - HEART_WARN_FROM_BPM
	var warn_at := normal_max_bpm - HEART_WARN_AT_BPM
	if bpm <= warn_from:
		return COLOR_HEART_LOW
	if bpm <= warn_at:
		return COLOR_HEART_LOW.lerp(COLOR_HEART_MID, inverse_lerp(warn_from, warn_at, bpm))
	if bpm <= normal_max_bpm:
		return COLOR_HEART_MID.lerp(COLOR_HEART_HIGH, inverse_lerp(warn_at, normal_max_bpm, bpm) * 0.5)
	return COLOR_HEART_MID.lerp(COLOR_HEART_HIGH, 0.5 + 0.5 * clampf(inverse_lerp(normal_max_bpm, max_bpm, bpm), 0.0, 1.0))


## 心拍の水の高さ（0〜1）。最低で0、過熱の上限で1。
static func heart_fill(bpm: float, min_bpm: float, max_bpm: float) -> float:
	return clampf(inverse_lerp(min_bpm, max_bpm, bpm), 0.0, 1.0)


## 絵を読み込む。読み込みの準備（インポート）が済んでいればそれを、まだなら、ファイルから直接読む。無ければ null。
static func load_image_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null


## 絵の、透明でない所だけを切り出した絵と、その位置（canvas の座標）。全部透明なら、大きさ0。
## keep_point を渡すと、その点も入るように切り出す（弧のまん中。Godot の弧の部品は、まん中が絵の外だと、絵のはしへ寄せてしまうため）。
static func trimmed(texture: Texture2D, keep_point: Variant = null) -> Array:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return [null, Rect2i()]
	if keep_point is Vector2:
		used = used.merge(Rect2i(Vector2i(keep_point), Vector2i.ONE)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used)
	return [atlas, used]


## 部品を、下から順に置き直す。
func _build() -> void:
	for child in _stage.get_children():
		child.queue_free()
	_fills.clear()
	_each.clear()
	_tints.clear()
	_fades.clear()
	var notch_count := int(_state["notch_max"])
	var boost_count := int(_state["boost_max_uses"])
	_built_counts = Vector2i(notch_count, boost_count)
	missing_images = PartsConfig.missing_images(_config, notch_count, boost_count)
	if not missing_images.is_empty():
		push_error("操作盤の部品の絵がありません（%s）: %s" % [str(_config["image_dir"]), ", ".join(missing_images)])
	for layer: Dictionary in _config["layers"]:
		var count := 1
		if layer.has("each"):
			count = notch_count if str(layer["each"]) == "notch" else boost_count
		var nodes: Array = []
		for n in range(1, count + 1):
			var file := str(layer["file"]).replace("{n}", str(n))
			var node := _make_layer(file, layer)
			if node != null:
				_stage.add_child(node)
			nodes.append(node)
		if layer.has("each"):
			_each[str(layer["each"])] = nodes
		elif layer.has("fill"):
			_fills[str(layer["fill"])] = nodes[0]
		if layer.has("tint") and nodes[0] != null:
			_tints[str(layer["tint"])] = nodes[0]
		if layer.has("fade") and nodes[0] != null:
			_fades[str(layer["fade"])] = nodes[0]
	_text_layer = Control.new()
	_text_layer.name = "Texts"
	_text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_layer.size = _canvas
	_text_layer.draw.connect(_draw_texts)
	_stage.add_child(_text_layer)


## 1枚の部品を置く。fill の付いた絵は、値の割合だけ見せる部品（TextureProgressBar）にする。絵が無ければ null。
func _make_layer(file: String, layer: Dictionary) -> Control:
	var texture := load_image_texture(str(_config["image_dir"]).path_join(file))
	if texture == null:
		return null
	var keep: Variant = null
	if layer.has("fill"):
		var spec: Dictionary = _config["fills"][str(layer["fill"])]
		if str(spec["mode"]) in PartsConfig.RADIAL_MODES:
			keep = Vector2(float(spec["center"][0]), float(spec["center"][1]))
	var cut := trimmed(texture, keep)
	if cut[0] == null:
		return null
	var rect: Rect2i = cut[1]
	var node: Control
	if layer.has("fill"):
		var fill: Dictionary = _config["fills"][str(layer["fill"])]
		var bar := TextureProgressBar.new()
		bar.texture_progress = cut[0]
		bar.fill_mode = PartsConfig.FILL_MODES[str(fill["mode"])]
		if str(fill["mode"]) in PartsConfig.RADIAL_MODES:
			bar.radial_initial_angle = float(fill["start_deg"])
			bar.radial_fill_degrees = float(fill["sweep_deg"])
			var center := Vector2(float(fill["center"][0]), float(fill["center"][1]))
			bar.radial_center_offset = center - Vector2(rect.position) - Vector2(rect.size) * 0.5
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = 0.0
		node = bar
	else:
		var picture := TextureRect.new()
		picture.texture = cut[0]
		node = picture
	node.name = file.get_basename()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(rect.position)
	node.size = Vector2(rect.size)
	return node


## 増減する部品の、今の割合（0〜1）。
func fill_ratio(name: String) -> float:
	match name:
		"speed":
			var full := float(_config["fills"]["speed"].get("full_value", 1.0))
			return clampf(float(_state["speed_kmh"]) / full, 0.0, 1.0)
		"stamina":
			return clampf(float(_state["fuel_ratio"]), 0.0, 1.0)
		"stamina_debt":
			return clampf(-float(_state["fuel_ratio"]), 0.0, 1.0)
		"aero_total":
			return clampf(float(_state["air_green"]) + float(_state["air_blue"]), 0.0, 1.0)
		"aero_green":
			return clampf(float(_state["air_green"]), 0.0, 1.0)
		"heart":
			return heart_fill(float(_state["heart_bpm"]), float(_state["heart_min_bpm"]), float(_state["heart_max_bpm"]))
		"dash":
			return clampf(float(_state["dash_ratio"]), 0.0, 1.0)
	return 0.0


## ノッチ・ブーストの1つずつの絵の、見せ方（0＝見せない、1＝全部、間＝その割合だけ下から）。n は1から。
func each_ratio(name: String, n: int) -> float:
	if name == "notch":
		return 1.0 if n <= clampi(int(_state["notch"]), 1, int(_state["notch_max"])) else 0.0
	var left := clampi(int(_state["boost_uses_left"]), 0, int(_state["boost_max_uses"]))
	if n <= left:
		return 1.0
	if n == left + 1:
		return clampf(float(_state["boost_ratio"]), 0.0, 1.0)
	return 0.0


## 値を、部品に入れる。
func _apply() -> void:
	for name: String in _fills:
		if _fills[name] != null:
			(_fills[name] as TextureProgressBar).value = fill_ratio(name)
	for name: String in _each:
		var nodes: Array = _each[name]
		for index in nodes.size():
			var node: Control = nodes[index]
			if node == null:
				continue
			var ratio := each_ratio(name, index + 1)
			if node is TextureProgressBar:
				(node as TextureProgressBar).value = ratio
			else:
				node.visible = ratio >= 1.0
	if _tints.has("heart"):
		var water := heart_water_color(float(_state["heart_bpm"]), float(_state["heart_normal_max_bpm"]), float(_state["heart_max_bpm"]))
		var node: Control = _tints["heart"]
		if node is TextureProgressBar:
			(node as TextureProgressBar).tint_progress = water
		else:
			node.modulate = water
	if _fades.has("beat"):
		var fade := clampf(1.0 - float(_state["heart_beat_phase"]) / HEART_BEAT_PART, 0.0, 1.0)
		(_fades["beat"] as Control).modulate.a = fade * fade
	_text_layer.queue_redraw()


## 文字の中の {名前} を、今の値に置き換える。
func fill_text(template: String) -> String:
	var trainer := str(_state["trainer_name"])
	return template.format({
		"name": str(_state["player_name"]),
		"trainer": "（%s）" % trainer if not trainer.is_empty() else "",
		"aero": "%d" % int(round(fill_ratio("aero_total") * 100.0)),
		"speed": "%d" % int(round(float(_state["speed_kmh"]))),
		"notch": "%d" % clampi(int(_state["notch"]), 1, int(_state["notch_max"])),
		"stamina": "%d" % int(round(float(_state["fuel_ratio"]) * 100.0)),
		"bpm": "%d" % int(round(float(_state["heart_bpm"]))),
		"boost": "%d" % int(_state["boost_uses_left"]),
	})


## 文字・属性の印・脚質の印を書く（文字の面の draw）。
func _draw_texts() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	if _bold == null:
		_bold = _text_font(font)
	_painter.begin(_text_layer)
	for text: Dictionary in _config["texts"]:
		_draw_text(text)
	var attribute := str(_state["attribute_id"])
	if not attribute.is_empty():
		var mark: Dictionary = _config["attribute_mark"]
		PururinDetail.draw_attribute_mark(_painter, Vector2(float(mark["center"][0]), float(mark["center"][1])), float(mark.get("size", 60.0)), attribute, _state["attribute_color"])
	if int(_state["style_group_count"]) > 0:
		var style: Dictionary = _config["style_mark"]
		RaceHud.draw_style_chevrons(_painter, Vector2(float(style["center_left"][0]), float(style["center_left"][1])), RaceHud.style_state_color(int(_state["style_rank_bonus"])), int(_state["style_group_count"]), int(_state["style_group_index"]), float(style.get("scale", 1.0)))
	_painter.flush()


## 文字に使う字。一覧に字のファイル（font）があれば、それ（無い字は、ゲームの字で書く）。無ければ、ゲームの字を太らせて使う。
func _text_font(game_font: Font) -> FontVariation:
	var variation := FontVariation.new()
	var path := str(_config.get("font", ""))
	if path.is_empty():
		variation.base_font = game_font
		variation.variation_embolden = 1.2
		return variation
	var file: Font = load(path) as Font if ResourceLoader.exists(path) else null
	if file == null:
		var dynamic := FontFile.new()
		if dynamic.load_dynamic_font(path) != OK:
			push_error("操作盤の字のファイルを読めません: %s" % path)
			variation.base_font = game_font
			variation.variation_embolden = 1.2
			return variation
		file = dynamic
	file.fallbacks = [game_font]
	variation.base_font = file
	return variation


## 1つの文字の並び。fit_width があれば、全部をつなげて、その幅に収める（長い名前）。
## run の4つ目 [横, 縦] は、前の文字の終わりからの、ずらし（下絵どおりの間かく）。5つ目は、横の縮め具合（1でそのまま）。
func _draw_text(text: Dictionary) -> void:
	var runs: Array = []
	for run: Array in text["runs"]:
		var offset := Vector2(float(run[3][0]), float(run[3][1])) if run.size() >= 4 else Vector2.ZERO
		var narrow := float(run[4]) if run.size() >= 5 else 1.0
		runs.append([fill_text(str(run[0])), int(run[1]), TEXT_COLORS[str(run[2])], offset, narrow])
	var at := Vector2(float(text["at"][0]), float(text["at"][1]))
	var x_scale := 1.0
	if text.has("fit_width"):
		var joined := ""
		for run: Array in runs:
			joined += str(run[0])
		var fitted := FitText.fit(_bold, joined, float(text["fit_width"]), int(runs[0][1]))
		runs = [[str(fitted["text"]), int(fitted["font_size"]), runs[0][2], Vector2.ZERO, 1.0]]
		x_scale = float(fitted["x_scale"])
	var total := 0.0
	for run: Array in runs:
		total += _bold.get_string_size(str(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(run[1])).x * x_scale * float(run[4]) + (run[3] as Vector2).x
	var x := at.x - (total * 0.5 if str(text.get("align", "left")) == "center" else 0.0)
	for run: Array in runs:
		var offset: Vector2 = run[3]
		x += offset.x
		var narrow := x_scale * float(run[4])
		var place := Transform2D(Vector2(narrow, 0.0), Vector2(-TEXT_SLANT, 1.0), Vector2(x, at.y + offset.y))
		_painter.glyphs.add(_bold, str(run[0]), int(run[1]), Vector2.ZERO, run[2], OUTLINE_SIZE, COLOR_OUTLINE, place)
		x += _bold.get_string_size(str(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(run[1])).x * narrow
