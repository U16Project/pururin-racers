extends RefCounted
## コース脇の目印。一定間隔の距離標識（残り距離）。
## 距離標識は、内側の柵の上に掲げる、紺の板（金のふち、白い数字）。大きい標識は、赤い板。
## 板は、コースの上にはみ出さないように、柵の線から芝のほうへずらして立てる。
## 置く距離と標識の数字は静的関数で決め、ここのノードの寿命は配置先Pathが持つ。

const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const Parts := preload("res://scripts/presentation/venue_parts.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")

## 標識は、柵の上（コース幅15mの端の、少し外）。
const SIGN_SIDE_OFFSET_M := Parts.FENCE_SIDE_OFFSET_M
## 地面の高さ（シーンの Ground と同じ）。目印は、ここに接して立てる。
const GROUND_Y_M := -0.05
## 標識の板の大きさ（横×縦）。残りがLARGE_SIGN_REMAINING_Mの標識は、ひと回り大きい。
const SIGN_SIZE_M := Vector2(1.4, 1.0)
const SIGN_LARGE_SIZE_M := Vector2(1.9, 1.35)
## 板の下のふちと、柵の上とのすき間。
const SIGN_GAP_ABOVE_FENCE_M := 0.2
const SIGN_FRAME_M := 0.07
## 板の上に載せる、金の横木の、板からのはみ出し（左右それぞれ）と、厚み。
const SIGN_CAP_OVERHANG_M := 0.12
const SIGN_CAP_THICKNESS_M := 0.1
const SIGN_KNOB_RADIUS_M := 0.11
## 板の、コース側の端と、コースの端とのすき間。
const SIGN_TRACK_EDGE_MARGIN_M := 0.05
## 板を支える、2本の柱の太さ。
const SIGN_POST_THICKNESS_M := 0.1
const SIGN_FONT_SIZE := 64
const SIGN_FONT_PATH := "res://fonts/NotoSansCJK-Regular.ttc"
## 数字の高さ（フォントの大きさに対する割合。Noto Sans CJKの数字）。
const SIGN_DIGIT_HEIGHT_EM := 0.733
## 数字の高さは、板の縦の約5.5割。
const SIGN_DIGIT_HEIGHT_RATIO := 0.55
## 数字の横幅を、少し狭くする。
const SIGN_NUMBER_WIDTH_SCALE := 0.8
## 末尾の「00」の大きさ（主な数字に対する割合）。
const SIGN_SUFFIX_SCALE := 0.6
## 数字の太さ（同じ色の縁取りの太さ）。
const SIGN_NUMBER_OUTLINE := 8
## フォントの1文字の幅（フォントサイズに対する割合の目安）。
const SIGN_GLYPH_WIDTH_RATIO := 0.55
## 残りがこの距離の標識は、ひと回り大きくする。
const LARGE_SIGN_REMAINING_M := [500, 200, 100]
const COLOR_SIGN_FACE := Parts.COLOR_NAVY
const COLOR_SIGN_FACE_LARGE := Parts.COLOR_CRIMSON
const COLOR_SIGN_FRAME := Parts.COLOR_GOLD
const COLOR_SIGN_NUMBER := Parts.COLOR_WHITE
const COLOR_SIGN_POST := Parts.COLOR_WOOD

var _root: Node3D


## スタート(0m)の次から、ゴールまでに収まる間隔ごとの距離。残りが max_remaining_m より長い所には、立てない
## （同じ場所を2回通るレースで、1周目用と2周目用の標識が並ばないように）。
static func marker_distances(total_m: float, interval_m: float, max_remaining_m: float) -> Array[float]:
	var result: Array[float] = []
	if interval_m <= 0.0:
		return result
	var index := 1
	while float(index) * interval_m < total_m - 0.001:
		if total_m - float(index) * interval_m <= max_remaining_m + 0.001:
			result.append(float(index) * interval_m)
		index += 1
	return result


## 標識の数字を、大きく見せる部分と、小さく見せる末尾の「00」に分ける。100の倍数でなければ分けない。
static func sign_number_parts(remaining_m: int) -> Array[String]:
	if remaining_m >= 100 and remaining_m % 100 == 0:
		return [str(remaining_m / 100), "00"]
	return [str(remaining_m), ""]


## 標識の数字。ゴールまでの残り距離（m）。
static func sign_number(total_m: float, distance_m: float) -> int:
	return int(roundf(total_m - distance_m))


static func is_large_sign(remaining_m: int) -> bool:
	return remaining_m in LARGE_SIGN_REMAINING_M


## 板の、横幅の半分（金のふちと、上の横木のはみ出しをふくむ）。
static func sign_half_width_m(size: Vector2) -> float:
	return size.x * 0.5 + SIGN_FRAME_M + SIGN_CAP_OVERHANG_M


## 板を、柵の線から、コースの内側（芝のほう）へずらす量。板が、コースの上にはみ出さないようにする。
static func sign_side_shift_m(size: Vector2) -> float:
	var room := SIGN_SIDE_OFFSET_M - M2TrackMath.HALF_WIDTH_M - SIGN_TRACK_EDGE_MARGIN_M
	return maxf(sign_half_width_m(size) - room, 0.0)


## 板のまん中の高さ（地面から）。板の下のふちが、柵の上に来る。
static func sign_center_height_m(size: Vector2) -> float:
	return Parts.FENCE_HEIGHT_M + SIGN_GAP_ABOVE_FENCE_M + SIGN_FRAME_M + size.y * 0.5


func place(track: Path3D, route: Dictionary, race_distance_m: float, lap_length_m: float, sign_interval_m: float, sign_max_remaining_m: float) -> void:
	if track == null or track.curve == null or route.is_empty():
		return
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_root.name = "CourseMarkers"
	track.add_child(_root)
	_place_signs(track, route, race_distance_m, lap_length_m, sign_interval_m, sign_max_remaining_m)


## コースの内側（周回の中心側）の向き。標識はこちら側に立てる。
static func inner_side(position: Vector3, travel: Vector3, center: Vector3) -> Vector3:
	var right := Vector3(-travel.z, 0.0, travel.x).normalized()
	var to_center := center - position
	to_center.y = 0.0
	return right if right.dot(to_center) >= 0.0 else -right


func _course_center(track: Path3D) -> Vector3:
	var points := track.curve.get_baked_points()
	var sum := Vector3.ZERO
	for point in points:
		sum += point
	return sum / maxf(float(points.size()), 1.0)


func _place_signs(track: Path3D, route: Dictionary, race_distance_m: float, lap_length_m: float, interval_m: float, max_remaining_m: float) -> void:
	var center := _course_center(track)
	for distance in marker_distances(race_distance_m, interval_m, max_remaining_m):
		var pose := M5CourseBuilder.route_pose(track.curve, route, distance, lap_length_m)
		if pose.is_empty():
			continue
		var travel: Vector3 = pose["travel"]
		var right := inner_side(pose["position"], travel, center)
		var remaining := sign_number(race_distance_m, distance)
		var large := is_large_sign(remaining)
		var size := SIGN_SIZE_M if not large else SIGN_LARGE_SIZE_M
		var center_height := sign_center_height_m(size)
		var node := Node3D.new()
		node.name = "Sign%d" % remaining
		_root.add_child(node)
		# 板の表（+Z）を、向かってくる走者の側（進行方向の逆）へ向ける。柵の線の上に立てる。
		node.transform = Transform3D(
			Basis.looking_at(travel, Vector3.UP),
			pose["position"] + right * SIGN_SIDE_OFFSET_M + Vector3.UP * GROUND_Y_M
		)
		var top := center_height + size.y * 0.5 + SIGN_FRAME_M
		# 板は、柵の線から、コースの内側（芝のほう）へずらす。柱は2本。1本は柵の線の上、もう1本は芝の上。
		var shift := sign_side_shift_m(size)
		var board := Node3D.new()
		board.name = "Board"
		board.position = Vector3(signf(right.dot(node.basis.x)) * shift, 0.0, 0.0)
		node.add_child(board)
		for leg: float in ([-shift, shift] if shift > 0.0 else [0.0]):
			_add_box(board, Vector3(SIGN_POST_THICKNESS_M, top, SIGN_POST_THICKNESS_M), Vector3(leg, top * 0.5, -0.08), COLOR_SIGN_POST)
		_add_box(board, Vector3(size.x + SIGN_FRAME_M * 2.0, size.y + SIGN_FRAME_M * 2.0, 0.05), Vector3(0.0, center_height, 0.0), COLOR_SIGN_FRAME)
		_add_box(board, Vector3(size.x, size.y, 0.05), Vector3(0.0, center_height, 0.012), COLOR_SIGN_FACE if not large else COLOR_SIGN_FACE_LARGE)
		# 板の上に、金の横木と、丸い飾り。
		_add_box(board, Vector3(sign_half_width_m(size) * 2.0, SIGN_CAP_THICKNESS_M, 0.14), Vector3(0.0, top + SIGN_CAP_THICKNESS_M * 0.5, -0.02), COLOR_SIGN_FRAME)
		Parts.mesh(board, Parts.sphere_mesh(SIGN_KNOB_RADIUS_M, 12), Parts.gold(), Vector3(0.0, top + SIGN_CAP_THICKNESS_M + SIGN_KNOB_RADIUS_M * 0.8, -0.02))
		_add_number(board, remaining, size, center_height)


func _add_box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)


## 数字は、主な部分（例：「19」）を大きく、末尾の「00」を小さく、ベースライン（文字の下の線）をそろえ、
## 数字全体を板の中央（左右・上下とも）に置く。
func _add_number(parent: Node3D, remaining: int, size: Vector2, center_height: float) -> void:
	var parts := sign_number_parts(remaining)
	var font := _sign_font()
	var main_pixel := size.y * SIGN_DIGIT_HEIGHT_RATIO / (SIGN_DIGIT_HEIGHT_EM * float(SIGN_FONT_SIZE))
	var suffix_pixel := main_pixel * SIGN_SUFFIX_SCALE
	var main_width := float(parts[0].length()) * SIGN_GLYPH_WIDTH_RATIO * float(SIGN_FONT_SIZE) * main_pixel * SIGN_NUMBER_WIDTH_SCALE
	var suffix_width := float(parts[1].length()) * SIGN_GLYPH_WIDTH_RATIO * float(SIGN_FONT_SIZE) * suffix_pixel * SIGN_NUMBER_WIDTH_SCALE
	var left := -(main_width + suffix_width) * 0.5
	# ベースラインの高さ。数字の高さ（主な部分）が、板の中央に来るようにする。
	var baseline := center_height - SIGN_DIGIT_HEIGHT_EM * float(SIGN_FONT_SIZE) * main_pixel * 0.5
	# ラベルの下端からベースラインまでは、フォントの下側の余白（descent）ぶん。ラベルの大きさ（pixel_size）に比例する。
	var descent := font.get_descent(SIGN_FONT_SIZE) if font != null else 0.0
	_add_label(parent, parts[0], font, main_pixel, Vector3(left, baseline - descent * main_pixel, 0.045))
	if not parts[1].is_empty():
		_add_label(parent, parts[1], font, suffix_pixel, Vector3(left + main_width, baseline - descent * suffix_pixel, 0.045))


func _sign_font() -> Font:
	return load(SIGN_FONT_PATH) as Font


func _add_label(parent: Node3D, text: String, font: Font, pixel_size: float, position: Vector3) -> void:
	var label := Label3D.new()
	if font != null:
		label.font = font
	label.text = text
	label.font_size = SIGN_FONT_SIZE
	label.pixel_size = pixel_size
	label.modulate = COLOR_SIGN_NUMBER
	label.outline_size = SIGN_NUMBER_OUTLINE
	label.outline_modulate = COLOR_SIGN_NUMBER
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.position = position
	label.scale = Vector3(SIGN_NUMBER_WIDTH_SCALE, 1.0, 1.0)
	parent.add_child(label)
