extends Control
## トレーナーの画像を出す部品。なし／用意してある人の絵／自分で選んだ画像ファイル、のどれか。
## 人の絵は、決まりの avatars に書いた画像ファイル。
## 何も指定しなければ、登録してある画像を出す。show_icon で、別の画像（登録前の、選びかけのもの）を出せる。

const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const COLOR_BACK := Color(1.0, 1.0, 1.0, 0.08)
const COLOR_EMPTY := Color(1.0, 1.0, 1.0, 0.28)
const FRAME_RADIUS_RATIO := 0.18
const FRAME_BORDER_RATIO := 0.06

var _kind := ""
var _id := ""
var _texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _kind.is_empty():
		show_registered()


## 登録してある画像を出す。
func show_registered() -> void:
	var icon := TrainerProfile.icon()
	show_icon(str(icon["kind"]), str(icon["id"]), TrainerProfile.icon_texture())


## 画像を出す。kind は none・avatar・file。avatar なら id に絵のID、file なら texture に絵。
func show_icon(kind: String, id: String = "", texture: Texture2D = null) -> void:
	_kind = kind
	_id = id
	# 人の絵も、読み込んだ絵をここで持つ。描くときだけ読むと、画面に出る前に絵が捨てられて、白い四角になる。
	_texture = avatar_texture(id) if kind == "avatar" else texture
	queue_redraw()


func shown_kind() -> String:
	return _kind


func shown_id() -> String:
	return _id


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 1.0:
		return
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var radius := side * FRAME_RADIUS_RATIO
	_draw_plate(rect, radius)
	match _kind:
		"file", "avatar":
			if _texture != null:
				# 画像も枠と同じ角丸にする。四角のまま置くと、角が枠の曲線からはみ出す。
				var border := side * FRAME_BORDER_RATIO
				_draw_textured_frame(_texture, rect.grow(-border), radius - border)
		_:
			# 画像なし：人の形の、かんたんな印（丸い頭と、肩）。
			var center := rect.get_center()
			draw_circle(center + Vector2(0.0, -side * 0.12), side * 0.17, COLOR_EMPTY)
			draw_arc(center + Vector2(0.0, side * 0.42), side * 0.3, PI * 1.12, PI * 1.88, 16, COLOR_EMPTY, side * 0.16)


func _draw_plate(rect: Rect2, radius: float) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = COLOR_BACK
	back.set_corner_radius_all(int(round(radius)))
	draw_style_box(back, rect)


## 画像を、枠と同じ角丸の中だけに描く。Godot 4.7 の draw_polygon（頂点・色・UV・texture）。
func _draw_textured_frame(texture: Texture2D, rect: Rect2, radius: float) -> void:
	var points := rounded_frame_points(rect, radius)
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	colors.resize(points.size())
	uvs.resize(points.size())
	for index in points.size():
		colors[index] = Color.WHITE
		uvs[index] = (points[index] - rect.position) / rect.size
	draw_polygon(points, colors, uvs, texture)


## 角丸の四角の外周。半径は枠の半径と揃える。
static func rounded_frame_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	var used := clampf(radius, 0.0, limit)
	if used <= 0.0:
		points.append(rect.position)
		points.append(Vector2(rect.end.x, rect.position.y))
		points.append(rect.end)
		points.append(Vector2(rect.position.x, rect.end.y))
		return points
	var centers: Array[Vector2] = [
		Vector2(rect.end.x - used, rect.position.y + used),
		Vector2(rect.end.x - used, rect.end.y - used),
		Vector2(rect.position.x + used, rect.end.y - used),
		Vector2(rect.position.x + used, rect.position.y + used),
	]
	var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	var steps := 6
	for corner in centers.size():
		for step in steps + 1:
			var angle := starts[corner] + (PI * 0.5) * float(step) / float(steps)
			var point := centers[corner] + Vector2(cos(angle), sin(angle)) * used
			if points.is_empty() or points[points.size() - 1].distance_squared_to(point) > 0.01:
				points.append(point)
	if points.size() > 1 and points[0].distance_squared_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points


## 用意してある人の絵（決まりの avatars の image_path）。
static func avatar_texture(avatar_id: String) -> Texture2D:
	var avatar := TrainerProfile.avatar_by_id(avatar_id)
	if avatar.is_empty():
		return null
	return load(str(avatar["image_path"])) as Texture2D
