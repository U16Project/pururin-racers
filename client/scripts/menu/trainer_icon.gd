extends Control
## トレーナーの画像を出す部品。なし／用意してある人の絵／自分で選んだ画像ファイル、のどれか。
## 人の絵は、仮のもの。髪型と、髪・肌・服の色（決まりの avatars）から、図形で描く。
## 何も指定しなければ、登録してある画像を出す。show_icon で、別の画像（登録前の、選びかけのもの）を出せる。

const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const COLOR_BACK := Color(1.0, 1.0, 1.0, 0.08)
const COLOR_EMPTY := Color(1.0, 1.0, 1.0, 0.28)

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
	_texture = texture
	queue_redraw()


func shown_kind() -> String:
	return _kind


func shown_id() -> String:
	return _id


func _draw() -> void:
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var back := StyleBoxFlat.new()
	back.bg_color = COLOR_BACK
	back.set_corner_radius_all(int(side * 0.18))
	draw_style_box(back, rect)
	match _kind:
		"file":
			if _texture != null:
				draw_texture_rect(_texture, rect.grow(-side * 0.06), false)
		"avatar":
			_draw_avatar(rect, TrainerProfile.avatar_by_id(_id))
		_:
			# 画像なし：人の形の、かんたんな印（丸い頭と、肩）。
			var center := rect.get_center()
			draw_circle(center + Vector2(0.0, -side * 0.12), side * 0.17, COLOR_EMPTY)
			draw_arc(center + Vector2(0.0, side * 0.42), side * 0.3, PI * 1.12, PI * 1.88, 16, COLOR_EMPTY, side * 0.16)


## 人の絵（仮）。肩から上を、図形で描く。位置と大きさは、枠の一辺を1とした割合。
func _draw_avatar(rect: Rect2, avatar: Dictionary) -> void:
	if avatar.is_empty():
		return
	var side := rect.size.x
	var at := func(x: float, y: float) -> Vector2: return rect.position + Vector2(x, y) * side
	var hair := Color(str(avatar["hair_color"]))
	var skin := Color(str(avatar["skin_color"]))
	var shirt := Color(str(avatar["shirt_color"]))
	var style := str(avatar["hair_style"])
	# 後ろの髪（長い髪、ボブ、ポニーテール）。
	if style == "long":
		draw_rect(Rect2(at.call(0.22, 0.42), Vector2(0.56, 0.42) * side), hair)
	elif style == "bob":
		draw_rect(Rect2(at.call(0.22, 0.42), Vector2(0.56, 0.2) * side), hair)
		draw_circle(at.call(0.27, 0.62), 0.05 * side, hair)
		draw_circle(at.call(0.73, 0.62), 0.05 * side, hair)
	elif style == "ponytail":
		draw_circle(at.call(0.79, 0.36), 0.1 * side, hair)
		draw_circle(at.call(0.84, 0.52), 0.07 * side, hair)
	# 男は、肩幅を広く・首を太く・あごをしっかり・まゆを太く・目を小さめにする。女は、まつ毛と、ほっぺの赤みを付ける。
	var male := str(avatar["body"]) == "male"
	# 肩と服（下の端で切る）。
	var shoulder_half := 0.47 if male else 0.37
	var shoulders := PackedVector2Array()
	for index in 17:
		var angle := PI + PI * float(index) / 16.0
		shoulders.append(at.call(0.5 + cos(angle) * shoulder_half, minf(1.02 + sin(angle) * (0.27 if male else 0.3), 0.97)))
	draw_colored_polygon(shoulders, shirt)
	# 首。
	var neck_half := 0.085 if male else 0.055
	draw_rect(Rect2(at.call(0.5 - neck_half, 0.6), Vector2(neck_half * 2.0, 0.17) * side), skin.darkened(0.12))
	# 髪（頭の上と横）→ 顔。
	draw_circle(at.call(0.5, 0.41), 0.27 * side, hair)
	if style == "spiky":
		for index in 5:
			var x := 0.28 + 0.11 * float(index)
			draw_colored_polygon(PackedVector2Array([at.call(x - 0.07, 0.24), at.call(x + 0.07, 0.24), at.call(x + 0.02, 0.07)]), hair)
	if male:
		# 上は丸く、下は角ばったあご。
		draw_circle(at.call(0.5, 0.44), 0.2 * side, skin)
		draw_colored_polygon(PackedVector2Array([at.call(0.3, 0.44), at.call(0.7, 0.44), at.call(0.68, 0.6), at.call(0.6, 0.69), at.call(0.4, 0.69), at.call(0.32, 0.6)]), skin)
	else:
		draw_circle(at.call(0.5, 0.47), 0.205 * side, skin)
	# 前髪。
	var fringe := PackedVector2Array()
	for index in 13:
		var angle := PI * 1.1 + PI * 0.8 * float(index) / 12.0
		fringe.append(at.call(0.5 + cos(angle) * 0.215, 0.44 + sin(angle) * 0.2))
	fringe.append(at.call(0.5, 0.33 if not male else 0.3))
	draw_colored_polygon(fringe, hair)
	# 目・まゆ・口。
	var dark := Color(0.14, 0.12, 0.16)
	var line := maxf(0.014 * side, 1.0)
	for direction: float in [-1.0, 1.0]:
		var eye: Vector2 = at.call(0.5 + direction * 0.085, 0.5)
		if male:
			draw_circle(eye, 0.019 * side, dark)
			# まゆは、太く、まっすぐ（外側を、ほんの少し下げる。怒った顔にしない）。
			draw_line(eye + Vector2(-direction * 0.04, -0.062) * side, eye + Vector2(direction * 0.05, -0.054) * side, hair.darkened(0.3), maxf(0.026 * side, 1.5))
		else:
			draw_circle(eye, 0.027 * side, dark)
			draw_circle(eye + Vector2(-0.008, -0.01) * side, 0.008 * side, Color.WHITE)
			draw_line(eye + Vector2(direction * 0.02, -0.022) * side, eye + Vector2(direction * 0.045, -0.04) * side, dark, line)
			draw_circle(at.call(0.5 + direction * 0.13, 0.565), 0.035 * side, Color(1.0, 0.5, 0.55, 0.45))
	if male:
		draw_arc(at.call(0.5, 0.565), 0.06 * side, PI * 0.25, PI * 0.75, 10, dark, line)
	else:
		draw_arc(at.call(0.5, 0.555), 0.045 * side, PI * 0.2, PI * 0.8, 10, dark, line)
