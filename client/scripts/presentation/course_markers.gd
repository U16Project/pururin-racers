extends RefCounted
## コース脇の目印。標識と標識の中間のコーン（スピード感）と、一定間隔の距離標識（残り距離）。
## 置く距離と標識の数字は静的関数で決め、ここのノードの寿命は配置先Pathが持つ。

const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")

## コース幅15mの端（7.5m）の外側。
const CONE_SIDE_OFFSET_M := 8.6
const SIGN_SIDE_OFFSET_M := 9.2
const CONE_HEIGHT_M := 0.6
const CONE_BOTTOM_RADIUS_M := 0.22
const CONE_TOP_RADIUS_M := 0.04
## 地面の高さ（シーンの Ground と同じ）。目印は、ここに接して立てる。
const GROUND_Y_M := -0.05
## 標識の板の大きさ（横×縦）。残りがLARGE_SIGN_REMAINING_Mの標識は、ひと回り大きい。
const SIGN_SIZE_M := Vector2(1.4, 1.0)
const SIGN_LARGE_SIZE_M := Vector2(1.9, 1.35)
const SIGN_CENTER_HEIGHT_M := 2.0
const SIGN_FRAME_M := 0.07
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
const COLOR_CONE := Color(1.0, 0.45, 0.1, 1.0)
const COLOR_SIGN_FACE := Color(0.98, 0.98, 0.98, 1.0)
const COLOR_SIGN_FRAME := Color(0.7, 0.05, 0.08, 1.0)
const COLOR_SIGN_NUMBER := Color(0.85, 0.05, 0.08, 1.0)
const COLOR_SIGN_POST := Color(0.55, 0.57, 0.6, 1.0)

var _root: Node3D


## スタート(0m)の次から、ゴールまでに収まる間隔ごとの距離。
static func marker_distances(total_m: float, interval_m: float) -> Array[float]:
	var result: Array[float] = []
	if interval_m <= 0.0:
		return result
	var index := 1
	while float(index) * interval_m < total_m - 0.001:
		result.append(float(index) * interval_m)
		index += 1
	return result


## 標識と標識の中間の距離（スタートと最初の標識の中間から）。ゴールまでに収まるもの。
static func midpoint_distances(total_m: float, interval_m: float) -> Array[float]:
	var result: Array[float] = []
	if interval_m <= 0.0:
		return result
	var index := 0
	while (float(index) + 0.5) * interval_m < total_m - 0.001:
		result.append((float(index) + 0.5) * interval_m)
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


func place(track: Path3D, route: Dictionary, race_distance_m: float, lap_length_m: float, sign_interval_m: float) -> void:
	if track == null or track.curve == null or route.is_empty():
		return
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_root.name = "CourseMarkers"
	track.add_child(_root)
	_place_cones(track, route, race_distance_m, lap_length_m, sign_interval_m)
	_place_signs(track, route, race_distance_m, lap_length_m, sign_interval_m)


func _place_cones(track: Path3D, route: Dictionary, race_distance_m: float, lap_length_m: float, interval_m: float) -> void:
	var distances := midpoint_distances(race_distance_m, interval_m)
	if distances.is_empty():
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = CONE_TOP_RADIUS_M
	mesh.bottom_radius = CONE_BOTTOM_RADIUS_M
	mesh.height = CONE_HEIGHT_M
	mesh.radial_segments = 12
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_CONE
	material.roughness = 0.7
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = distances.size() * 2
	var slot := 0
	for distance in distances:
		var pose := M5CourseBuilder.route_pose(track.curve, route, distance, lap_length_m)
		if pose.is_empty():
			continue
		var travel: Vector3 = pose["travel"]
		var right := Vector3(-travel.z, 0.0, travel.x).normalized()
		var base: Vector3 = pose["position"] + Vector3.UP * (GROUND_Y_M + CONE_HEIGHT_M * 0.5)
		multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY, base + right * CONE_SIDE_OFFSET_M))
		multi.set_instance_transform(slot + 1, Transform3D(Basis.IDENTITY, base - right * CONE_SIDE_OFFSET_M))
		slot += 2
	multi.visible_instance_count = slot
	var instance := MultiMeshInstance3D.new()
	instance.name = "Cones"
	instance.multimesh = multi
	_root.add_child(instance)


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


func _place_signs(track: Path3D, route: Dictionary, race_distance_m: float, lap_length_m: float, interval_m: float) -> void:
	var center := _course_center(track)
	for distance in marker_distances(race_distance_m, interval_m):
		var pose := M5CourseBuilder.route_pose(track.curve, route, distance, lap_length_m)
		if pose.is_empty():
			continue
		var travel: Vector3 = pose["travel"]
		var right := inner_side(pose["position"], travel, center)
		var remaining := sign_number(race_distance_m, distance)
		var size := SIGN_SIZE_M if not is_large_sign(remaining) else SIGN_LARGE_SIZE_M
		var node := Node3D.new()
		node.name = "Sign%d" % remaining
		_root.add_child(node)
		# 板の表（+Z）を、向かってくる走者の側（進行方向の逆）へ向ける。
		node.transform = Transform3D(
			Basis.looking_at(travel, Vector3.UP),
			pose["position"] + right * SIGN_SIDE_OFFSET_M + Vector3.UP * GROUND_Y_M
		)
		_add_box(node, Vector3(0.1, SIGN_CENTER_HEIGHT_M, 0.1), Vector3(0.0, SIGN_CENTER_HEIGHT_M * 0.5, -0.07), COLOR_SIGN_POST)
		_add_box(node, Vector3(size.x + SIGN_FRAME_M * 2.0, size.y + SIGN_FRAME_M * 2.0, 0.05), Vector3(0.0, SIGN_CENTER_HEIGHT_M, 0.0), COLOR_SIGN_FRAME)
		_add_box(node, Vector3(size.x, size.y, 0.05), Vector3(0.0, SIGN_CENTER_HEIGHT_M, 0.012), COLOR_SIGN_FACE)
		_add_number(node, remaining, size)


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
func _add_number(parent: Node3D, remaining: int, size: Vector2) -> void:
	var parts := sign_number_parts(remaining)
	var font := _sign_font()
	var main_pixel := size.y * SIGN_DIGIT_HEIGHT_RATIO / (SIGN_DIGIT_HEIGHT_EM * float(SIGN_FONT_SIZE))
	var suffix_pixel := main_pixel * SIGN_SUFFIX_SCALE
	var main_width := float(parts[0].length()) * SIGN_GLYPH_WIDTH_RATIO * float(SIGN_FONT_SIZE) * main_pixel * SIGN_NUMBER_WIDTH_SCALE
	var suffix_width := float(parts[1].length()) * SIGN_GLYPH_WIDTH_RATIO * float(SIGN_FONT_SIZE) * suffix_pixel * SIGN_NUMBER_WIDTH_SCALE
	var left := -(main_width + suffix_width) * 0.5
	# ベースラインの高さ。数字の高さ（主な部分）が、板の中央に来るようにする。
	var baseline := SIGN_CENTER_HEIGHT_M - SIGN_DIGIT_HEIGHT_EM * float(SIGN_FONT_SIZE) * main_pixel * 0.5
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
