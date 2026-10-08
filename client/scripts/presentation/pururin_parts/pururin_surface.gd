extends RefCounted
## ぷるりんの体（ドーム形）の表面の計算と、表面に沿わせた薄い面（顔・マーク）の作り方。
## shape は、体の形の数字：height（地面から頭のてっぺんまで）、base_height（一番ふくらんだ所の、地面からの高さ）。
## 体の横幅は、全員同じ（一番太い所が半径 BODY_RADIUS）。

## 体の横の半径（m）。当たり判定の直径1.5mと同じ。個体では変えない。
const BODY_RADIUS := 0.75
const RINGS := 30
const SEGMENTS := 56
## 顔や模様を、体の表面から浮かせる量（重なってちらつかないように、重ねる順に少しずつ増やす）。
const PATCH_OFFSET := 0.004

## 作ったメッシュの覚え書き（同じ見た目の体を、何度も組み立てるとき用）。
static var _dome_cache := {}
static var _patch_cache := {}


## 体の表面の点。theta は、てっぺん(0)から足元(PI)まで。phi は、正面(0)から体の右回り。足元が原点、正面は −Z。
static func surface_point(shape: Dictionary, theta: float, phi: float) -> Vector3:
	var base := float(shape["base_height"])
	var top := float(shape["height"]) - base
	var s := sin(theta)
	var c := cos(theta)
	# 上半分はドーム、下半分は、横に広いまま、地面の近くで平らにつぶす。
	var r := BODY_RADIUS * (pow(s, 0.9) if c >= 0.0 else pow(s, 0.5))
	var y := base + (top * c if c >= 0.0 else base * c)
	return Vector3(r * sin(phi), y, -r * cos(phi))


## 体の表面の、外向きの向き。
static func surface_normal(shape: Dictionary, theta: float, phi: float) -> Vector3:
	var safe_theta := clampf(theta, 0.02, PI - 0.02)
	var step := 0.002
	var along_phi := surface_point(shape, safe_theta, phi + step) - surface_point(shape, safe_theta, phi - step)
	var along_theta := surface_point(shape, safe_theta + step, phi) - surface_point(shape, safe_theta - step, phi)
	var normal := along_phi.cross(along_theta).normalized()
	var outward := surface_point(shape, safe_theta, phi) - center(shape)
	return normal if normal.dot(outward) >= 0.0 else -normal


## 体の中の、基準にする点（表面へ寄せる計算に使う）。
static func center(shape: Dictionary) -> Vector3:
	return Vector3(0.0, float(shape["base_height"]) + (float(shape["height"]) - float(shape["base_height"])) * 0.2, 0.0)


## 高さの割合（0＝足元、1＝てっぺん）から、theta を求める。
static func theta_for_height(shape: Dictionary, height_ratio: float) -> float:
	var target := float(shape["height"]) * clampf(height_ratio, 0.0, 1.0)
	var low := 0.0
	var high := PI
	for _step in 24:
		var middle := (low + high) * 0.5
		if surface_point(shape, middle, 0.0).y > target:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## 体の中心の軸から radius（m）離れた所の、体の上側の表面の高さ（地面から）。
static func height_at_radius(shape: Dictionary, radius: float) -> float:
	var low := 0.0
	var high := PI * 0.5
	for _step in 24:
		var middle := (low + high) * 0.5
		if Vector2(surface_point(shape, middle, 0.0).x, surface_point(shape, middle, 0.0).z).length() < radius:
			low = middle
		else:
			high = middle
	return surface_point(shape, (low + high) * 0.5, 0.0).y


## 表面の、正面からの角度（yaw_deg。＋で体の右）と高さの割合の場所。[点, 外向きの向き] を返す。
static func anchor(shape: Dictionary, yaw_deg: float, height_ratio: float) -> Array:
	var theta := theta_for_height(shape, height_ratio)
	var phi := deg_to_rad(yaw_deg)
	return [surface_point(shape, theta, phi), surface_normal(shape, theta, phi)]


## 体のドームのメッシュ。テクスチャを巻き付けられるように、UV（横＝正面から一周、縦＝てっぺんから足元）も付ける。
static func dome_mesh(shape: Dictionary) -> ArrayMesh:
	var key := [float(shape["height"]), float(shape["base_height"])]
	if not _dome_cache.has(key):
		_dome_cache[key] = _build_dome_mesh(shape)
	return _dome_cache[key]


static func _build_dome_mesh(shape: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# 絵のつなぎ目（真後ろ）で、絵の左端と右端が別の頂点になるように、1列多く作る。
	for ring in RINGS + 1:
		var theta := PI * float(ring) / float(RINGS)
		for segment in SEGMENTS + 1:
			var phi := -PI + TAU * float(segment) / float(SEGMENTS)
			vertices.append(surface_point(shape, theta, phi))
			if ring == 0:
				normals.append(Vector3.UP)
			elif ring == RINGS:
				normals.append(Vector3.DOWN)
			else:
				normals.append(surface_normal(shape, theta, phi))
			uvs.append(Vector2(float(segment) / float(SEGMENTS), float(ring) / float(RINGS)))
	var indices := PackedInt32Array()
	var row := SEGMENTS + 1
	for ring in RINGS:
		for segment in SEGMENTS:
			var a := ring * row + segment
			var b := ring * row + segment + 1
			var c := (ring + 1) * row + segment
			var d := (ring + 1) * row + segment + 1
			push_triangle(indices, vertices, normals, a, b, c)
			push_triangle(indices, vertices, normals, b, d, c)
	return mesh_from(vertices, normals, indices, PackedColorArray(), uvs)


## 平面に描いた形（三角形の並び。単位はm。x＝体の右、y＝上）を、体の表面に沿わせた面にする。
## 置く場所は、正面からの角度（yaw_deg）と高さの割合。color_for は、平面の位置から色を決める。
## uv_rect を渡すと、その範囲（平面上の四角）を絵の全体として、UVを付ける（画像を貼るとき）。
static func patch_mesh(shape: Dictionary, triangles: PackedVector2Array, yaw_deg: float, height_ratio: float, offset: float, color_for: Callable, uv_rect: Rect2 = Rect2()) -> ArrayMesh:
	var arrays := patch_arrays(shape, triangles, yaw_deg, height_ratio, offset, color_for, uv_rect)
	return triangle_mesh(arrays[0], arrays[1], arrays[2], arrays[3])


## patch_mesh の中身（[頂点, 向き, 色, UV]。三角形ごとに3点ずつ）。何枚かを1つのメッシュにまとめるときは、これを使う。
static func patch_arrays(shape: Dictionary, triangles: PackedVector2Array, yaw_deg: float, height_ratio: float, offset: float, color_for: Callable, uv_rect: Rect2 = Rect2()) -> Array:
	var colors := PackedColorArray()
	for point in triangles:
		colors.append(color_for.call(point))
	# 同じ形・同じ場所・同じ色の面は、1回だけ作る（表面へ沿わせる計算が重いため）。
	var key := [float(shape["height"]), float(shape["base_height"]), triangles, yaw_deg, height_ratio, offset, colors, uv_rect]
	if _patch_cache.has(key):
		return _patch_cache[key]
	var phi := deg_to_rad(yaw_deg)
	var theta := theta_for_height(shape, height_ratio)
	var origin := surface_point(shape, theta, phi)
	var right := (surface_point(shape, theta, phi + 0.002) - surface_point(shape, theta, phi - 0.002)).normalized()
	var up := (surface_point(shape, theta - 0.002, phi) - surface_point(shape, theta + 0.002, phi)).normalized()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# 同じ点は何度も出てくるので、沿わせた結果を覚えておく。
	var projected_points := {}
	for point in triangles:
		if not projected_points.has(point):
			projected_points[point] = project_to_surface(shape, origin + right * point.x + up * point.y)
		var projected: Array = projected_points[point]
		vertices.append(projected[0] + projected[1] * offset)
		normals.append(projected[1])
		if uv_rect.has_area():
			uvs.append(Vector2((point.x - uv_rect.position.x) / uv_rect.size.x, 1.0 - (point.y - uv_rect.position.y) / uv_rect.size.y))
	var arrays := [vertices, normals, colors, uvs]
	_patch_cache[key] = arrays
	return arrays


## 三角形ごとに3点ずつ並んだ頂点から、メッシュを作る。
static func triangle_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var indices := PackedInt32Array()
	for index in range(0, vertices.size(), 3):
		push_triangle(indices, vertices, normals, index, index + 1, index + 2)
	return mesh_from(vertices, normals, indices, colors, uvs)


## 体の近くの点を、体の表面へ寄せる。[表面の点, 外向きの向き] を返す。
static func project_to_surface(shape: Dictionary, point: Vector3) -> Array:
	var middle_point := center(shape)
	var direction := point - middle_point
	var phi := atan2(direction.x, -direction.z)
	var elevation := atan2(direction.y, Vector2(direction.x, direction.z).length())
	var low := 0.0
	var high := PI
	for _step in 24:
		var middle := (low + high) * 0.5
		var candidate := surface_point(shape, middle, phi) - middle_point
		if atan2(candidate.y, Vector2(candidate.x, candidate.z).length()) > elevation:
			low = middle
		else:
			high = middle
	var theta := (low + high) * 0.5
	return [surface_point(shape, theta, phi), surface_normal(shape, theta, phi)]


## 楕円を、三角形の並びにする（中心から輪を重ねて、曲がった表面に沿いやすくする）。
static func ellipse_triangles(center_point: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	var rings := 4
	var around := 24
	for ring in rings:
		var inner := float(ring) / float(rings)
		var outer := float(ring + 1) / float(rings)
		for step in around:
			var a0 := TAU * float(step) / float(around)
			var a1 := TAU * float(step + 1) / float(around)
			var p00 := center_point + Vector2(cos(a0) * half_width, sin(a0) * half_height) * inner
			var p01 := center_point + Vector2(cos(a1) * half_width, sin(a1) * half_height) * inner
			var p10 := center_point + Vector2(cos(a0) * half_width, sin(a0) * half_height) * outer
			var p11 := center_point + Vector2(cos(a1) * half_width, sin(a1) * half_height) * outer
			triangles.append_array(PackedVector2Array([p00, p10, p11, p00, p11, p01]))
	return triangles


## 四角を、細かい三角形の並びにする（画像を貼る面。曲がった表面に沿いやすくする）。
static func rect_triangles(rect: Rect2, columns: int = 12, rows: int = 8) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	for row in rows:
		for column in columns:
			var p00 := rect.position + Vector2(rect.size.x * float(column) / float(columns), rect.size.y * float(row) / float(rows))
			var p10 := rect.position + Vector2(rect.size.x * float(column + 1) / float(columns), rect.size.y * float(row) / float(rows))
			var p01 := rect.position + Vector2(rect.size.x * float(column) / float(columns), rect.size.y * float(row + 1) / float(rows))
			var p11 := rect.position + Vector2(rect.size.x * float(column + 1) / float(columns), rect.size.y * float(row + 1) / float(rows))
			triangles.append_array(PackedVector2Array([p00, p10, p11, p00, p11, p01]))
	return triangles


## 折れ線を、細い帯の三角形の並びにする。
static func stroke_triangles(points: PackedVector2Array, thickness: float) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	for index in points.size() - 1:
		var direction := (points[index + 1] - points[index]).normalized()
		var side := Vector2(-direction.y, direction.x) * thickness
		triangles.append_array(PackedVector2Array([
			points[index] + side, points[index] - side, points[index + 1] - side,
			points[index] + side, points[index + 1] - side, points[index + 1] + side,
		]))
	return triangles


## 三角形を足す。面の表が、外向き（頂点の向き）になるように、頂点の順番をそろえる。
static func push_triangle(indices: PackedInt32Array, vertices: PackedVector3Array, normals: PackedVector3Array, a: int, b: int, c: int) -> void:
	var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	if face.length_squared() < 1e-12:
		return
	if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
		indices.append_array(PackedInt32Array([a, c, b]))
	else:
		indices.append_array(PackedInt32Array([a, b, c]))


static func mesh_from(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray = PackedColorArray(), uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
