extends SceneTree
## 絵の部品の操作盤（PartsRaceHud）を、見本の値（下絵と同じ値）で、canvas の大きさのまま撮って PNG に保存する（描いた絵を確かめる道具）。
## 下絵を渡すと、下絵と点ごとに比べて、ずれの地図（下絵｜撮った絵｜ずれ の3枚並び）を保存し、部品ごとのずれの大きさを表示する。
## 仕上がりは、目で見て決めずに、このずれで確かめる。
## 使い方（client で）:
##   ../tools/godot/Godot_v4.7-stable_linux.x86_64 --path . -s res://scripts/debug/parts_hud_preview.gd -- 保存先.png [絵の置き場] [下絵.png]
## 絵の置き場を省く（または - にする）と、部品の一覧（heart_hud_parts.json）の image_dir。まだ無い絵は、名前を表示する。

const PartsRaceHud := preload("res://scripts/presentation/parts_race_hud.gd")
const PartsConfig := preload("res://scripts/config/heart_hud_parts_config.gd")
## 見本の値（下絵と同じ）。
const SAMPLE_STATE := {
	"speed_kmh": 63.0, "notch": 6, "notch_max": 6, "heart_bpm": 143.0, "fuel_ratio": 0.69, "air_green": 0.3, "air_blue": 0.38,
	"boost_uses_left": 3, "boost_max_uses": 3, "boost_ratio": 0.0, "dash_ratio": 0.6, "player_name": "アカネ", "trainer_name": "U16",
	"attribute_id": "fire", "attribute_color": Color("ff3b6b"), "style_group_count": 4, "style_group_index": 1,
}
const BACKGROUND := Color("2e3b4b")
## ずれの地図で、どれだけのずれ（0〜1）を真っ赤にするか。部品ごとのずれの表示で、何件まで出すか。
const DIFF_FULL := 0.5
const REPORT_COUNT := 12

var _frames := 0
var _view: SubViewport
var _hud: Control
var _out := ""
var _reference := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("保存先の PNG を指定してください（-- 保存先.png [絵の置き場] [下絵.png]）")
		quit(1)
		return
	_out = args[0]
	if args.size() >= 3:
		_reference = args[2]
	var config := PartsConfig.config()
	if config.is_empty():
		quit(1)
		return
	var canvas := Vector2i(int(config["canvas"][0]), int(config["canvas"][1]))
	_view = SubViewport.new()
	_view.size = canvas
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(canvas)
	_view.add_child(background)
	_hud = PartsRaceHud.new()
	if args.size() >= 2 and args[1] != "-":
		_hud.image_dir_override = args[1]
	_view.add_child(_hud)
	_hud.set_scale_factor(2.0)
	_hud.update_state(SAMPLE_STATE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	var shot := _view.get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	shot.save_png(_out)
	print("保存しました: ", _out)
	if not _hud.missing_images.is_empty():
		print("まだ無い絵: ", ", ".join(_hud.missing_images))
	if not _reference.is_empty():
		_compare(shot)
	return true


## 2つの絵の、その点のずれ（0〜1。赤・緑・青のうち、いちばん大きい差）。
static func pixel_difference(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


## 下絵と比べる：ずれの地図を保存し、全体と、部品ごと（部品の置き場所の四角の中）のずれの平均を表示する。
func _compare(shot: Image) -> void:
	var reference := Image.load_from_file(_reference)
	if reference == null:
		push_error("下絵を読めません: %s" % _reference)
		return
	reference.convert(Image.FORMAT_RGB8)
	if reference.get_size() != shot.get_size():
		reference.resize(shot.get_width(), shot.get_height(), Image.INTERPOLATE_BILINEAR)
	var width := shot.get_width()
	var height := shot.get_height()
	var heat := Image.create(width, height, false, Image.FORMAT_RGB8)
	var differences := PackedFloat32Array()
	differences.resize(width * height)
	var total := 0.0
	for y in height:
		for x in width:
			var difference := pixel_difference(shot.get_pixel(x, y), reference.get_pixel(x, y))
			differences[y * width + x] = difference
			total += difference
			var strength := clampf(difference / DIFF_FULL, 0.0, 1.0)
			heat.set_pixel(x, y, Color(strength, 0.0, 0.0).lerp(Color.WHITE, 0.0) if strength > 0.04 else reference.get_pixel(x, y).darkened(0.7))
	var sheet := Image.create(width * 3, height, false, Image.FORMAT_RGB8)
	sheet.blit_rect(reference, Rect2i(Vector2i.ZERO, reference.get_size()), Vector2i.ZERO)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(width, 0))
	sheet.blit_rect(heat, Rect2i(Vector2i.ZERO, heat.get_size()), Vector2i(width * 2, 0))
	var sheet_path := _out.get_basename() + "_diff.png"
	sheet.save_png(sheet_path)
	print("ずれの地図を保存しました（下絵｜撮った絵｜ずれ）: ", sheet_path)
	print("全体のずれの平均: %.4f" % (total / float(width * height)))
	# 部品ごと：置き場所の四角の中の、ずれの平均。大きい順。
	var rows: Array = []
	for node: Node in _hud.get_node("Stage").get_children():
		var part := node as Control
		if part == null or part.name == "Texts":
			continue
		var rect := Rect2i(Vector2i(part.position), Vector2i(part.size)).intersection(Rect2i(0, 0, width, height))
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var sum := 0.0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				sum += differences[y * width + x]
		rows.append([sum / float(rect.size.x * rect.size.y), str(part.name), rect])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("部品ごとのずれの平均（大きい順）:")
	for index in mini(REPORT_COUNT, rows.size()):
		print("  %.4f  %s  %s" % [float(rows[index][0]), rows[index][1], str(rows[index][2])])
