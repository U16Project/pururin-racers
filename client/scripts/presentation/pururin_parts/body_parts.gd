extends RefCounted
## 体の一部（頭の上・左右・尾）の部品を作る。
## source.type が "builtin" なら、こちらで形を作る。"mesh" なら、用意されたメッシュを付ける。
## 体の一部は、あとでアクションごとに動かせるように、1つずつ別の節にして返す（節の原点が、付け根）。
## こちらで作る形は、頂点に色を持てる（色の濃さ＝アルファ。0なら体の色のまま）。

const Surface := preload("res://scripts/presentation/pururin_parts/pururin_surface.gd")
const PartAssets := preload("res://scripts/presentation/pururin_parts/part_assets.gd")
## こちらで作れる形（スロットごと）。
const BUILTIN_SHAPES := {
	"top": ["nub", "rocks", "flames", "sprout"],
	"side": ["flipper", "rock", "flame", "leaf"],
	"tail": ["flipper", "rock", "flame", "leaf"],
}
## 形ごとに、必ず要る数字。
const REQUIRED_PARAMS := {
	"nub": ["height", "lean", "base_radius", "tip_radius"],
	"flipper": ["length", "tilt_deg"],
	"rocks": ["size", "count", "spread", "seed"],
	"rock": ["size", "seed"],
	"flames": ["length", "width", "lean", "side_scale"],
	"flame": ["length", "width", "lean", "tilt_deg", "roll_deg"],
	"sprout": ["length", "width", "spread_deg"],
	"leaf": ["length", "width", "tilt_deg", "roll_deg", "sweep_deg", "feathers"],
}
## 形ごとに、必ず要る色。
const REQUIRED_COLORS := {
	"rocks": ["color"],
	"rock": ["color"],
	"flames": ["tip_color"],
	"flame": ["tip_color"],
	"sprout": ["color"],
	"leaf": ["color"],
}
## メッシュの部品に、必ず要る項目。material は "body"（体と同じ素材で塗る）か "own"（メッシュの素材のまま）。
const REQUIRED_MESH_PARAMS := ["path", "scale", "material"]
## 筒の形の、輪切り1つぶんの点の数。
const AROUND := 20
## 「上へ伸びる形」を「外（+X）へ伸びる形」に寝かせる向き（幅は前後、厚みは上下になる）。
const ALONG_X := Basis(Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))


## 形を1つのメッシュにまとめるための入れ物。
class Bits:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


## 頭の上の部品。source は、部品の作り方（個体ごとの上書きを混ぜたあと）。節の原点は、頭のてっぺん。
static func build_top(shape: Dictionary, source: Dictionary, body_material: Material) -> Array[Node3D]:
	var node: Node3D
	if str(source["type"]) == "mesh":
		node = _mesh_node(source, body_material)
	else:
		var bits := Bits.new()
		match str(source["shape"]):
			"nub": _add_nub(bits, source)
			"rocks": _add_rocks(bits, shape, source)
			"flames": _add_flames(bits, source)
			"sprout": _add_sprout(bits, source)
		node = _builtin_node(bits, body_material, str(source["shape"]) == "rocks")
	node.position = Vector3(0.0, float(shape["height"]), 0.0)
	node.name = "Top"
	return [node]


## 左右の部品（右と左の2つ）。placement は、付ける場所（yaw_deg、height_ratio）。
static func build_sides(shape: Dictionary, source: Dictionary, placement: Dictionary, body_material: Material) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for side: float in [1.0, -1.0]:
		var spot := Surface.anchor(shape, float(placement["yaw_deg"]) * side, float(placement["height_ratio"]))
		var point: Vector3 = spot[0]
		var outward := Vector3(point.x, 0.0, point.z).normalized()
		# 左は、右を鏡に映した形にする（部品の中の +Z は、右も左も、体の後ろ向き）。
		var backward := outward.cross(Vector3.UP).normalized() * side
		var node := _attached(source, point, Basis(outward, Vector3.UP, backward), body_material)
		node.name = "Side%s" % ("R" if side > 0.0 else "L")
		nodes.append(node)
	return nodes


## 尾の部品。placement は、付ける高さ（height_ratio）。真後ろに付ける。
static func build_tail(shape: Dictionary, source: Dictionary, placement: Dictionary, body_material: Material) -> Array[Node3D]:
	var spot := Surface.anchor(shape, 180.0, float(placement["height_ratio"]))
	var node := _attached(source, spot[0], Basis(Vector3.BACK, Vector3.UP, Vector3.BACK.cross(Vector3.UP)), body_material)
	node.name = "Tail"
	return [node]


## 体の表面の点に付ける部品。basis の x が、体から外へ伸びる向き、y が上。
static func _attached(source: Dictionary, point: Vector3, basis: Basis, body_material: Material) -> Node3D:
	var node: Node3D
	if str(source["type"]) == "mesh":
		node = _mesh_node(source, body_material)
		node.transform = Transform3D(basis * node.transform.basis, point)
		return node
	var bits := Bits.new()
	match str(source["shape"]):
		"flipper": _add_flipper(bits, source)
		"rock": _add_side_rocks(bits, source)
		"flame": _add_side_flame(bits, source)
		"leaf": _add_leaves(bits, source)
	node = _builtin_node(bits, body_material, str(source["shape"]) == "rock")
	node.transform = Transform3D(basis, point)
	return node


## こちらで作った形の節。体と同じ素材で塗り、頂点の色を使う。faceted なら、面をカクカクに見せる。
static func _builtin_node(bits: Bits, body_material: Material, faceted: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Surface.mesh_from(bits.vertices, bits.normals, bits.indices, bits.colors)
	node.material_override = body_material
	node.set_instance_shader_parameter("vertex_tint", 1.0)
	node.set_instance_shader_parameter("flat_shade", 1.0 if faceted else 0.0)
	return node


## 用意されたメッシュの部品。大きさを合わせ、指定があれば、体と同じ素材で塗る。
static func _mesh_node(source: Dictionary, body_material: Material) -> Node3D:
	var node := PartAssets.instantiate_mesh(str(source["path"]))
	assert(node != null, "部品のメッシュを読めません: %s" % source["path"])
	node.scale = Vector3.ONE * float(source["scale"])
	if str(source["material"]) == "body":
		for child in node.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).material_override = body_material
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_override = body_material
	return node


## 頂点に持たせる色。amount は、体の色の代わりに、この色をどれだけ出すか（0＝体の色のまま）。
static func _tint(color: Color, amount: float) -> Color:
	var linear := color.srgb_to_linear()
	return Color(linear.r, linear.g, linear.b, amount)


## 体の色のまま（色を付けない）。
static func _plain() -> Color:
	return Color(1.0, 1.0, 1.0, 0.0)


## 水の突起。根元が太く、途中でくびれて、先が丸くふくらむ。
static func _add_nub(bits: Bits, source: Dictionary) -> void:
	var height := float(source["height"])
	var lean := float(source["lean"])
	var base_radius := float(source["base_radius"])
	var tip_radius := float(source["tip_radius"])
	var steps := 26
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		# 根元は体に少し埋める。上へ伸びながら、横へ曲がる。
		centers.append(Vector3(lean * t * t, -0.1 + height * sin(t * PI * 0.5), 0.0))
		# 根元は、体へなだらかにつながるように広げる。
		var neck := lerpf(base_radius * 1.5, base_radius * 0.55, smoothstep(0.0, 0.45, t))
		var bulb := (tip_radius - base_radius * 0.55) * smoothstep(0.45, 0.85, t)
		# 先端は丸く閉じる。
		radii.append((neck + bulb) * sqrt(maxf(1.0 - pow(maxf(t - 0.8, 0.0) / 0.2, 2.0), 0.0)))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)


## 水のヒレ：平たい楕円。体に少し埋めて、先を上げ下げする。
static func _add_flipper(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	_add_ellipsoid(bits, Vector3(length * 0.45, 0.0, 0.0), Vector3(length * 0.5, length * 0.17, length * 0.36), _plain(), Transform3D(tilt, Vector3.ZERO))


## 地の岩（頭の上）：大きい岩1つと、まわりの小さい岩。体の丸みに沿って置く。
static func _add_rocks(bits: Bits, shape: Dictionary, source: Dictionary) -> void:
	var size := float(source["size"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	_add_rock(bits, Vector3(0.0, size * 0.35, 0.0), Vector3(size, size * 1.15, size), rng, color)
	var count := int(source["count"])
	for index in count - 1:
		var angle := TAU * (float(index) + rng.randf_range(-0.2, 0.2)) / float(maxi(count - 1, 1)) + 0.6
		var distance := float(source["spread"]) * rng.randf_range(0.85, 1.15)
		var small := size * rng.randf_range(0.45, 0.7)
		# その場所の、体の表面の高さ（頭のてっぺんからの差）に合わせて、少し埋める。
		var drop := Surface.height_at_radius(shape, distance) - float(shape["height"])
		_add_rock(bits, Vector3(cos(angle) * distance, drop + small * 0.3, sin(angle) * distance), Vector3(small, small * rng.randf_range(0.8, 1.2), small), rng, color)


## 地の岩（左右・尾）：大きい岩と小さい岩を、1つずつ。
static func _add_side_rocks(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	_add_rock(bits, Vector3(size * 0.3, 0.0, 0.0), Vector3(size, size * 0.9, size * 1.1), rng, color)
	_add_rock(bits, Vector3(size * 0.15, size * 0.55, size * 0.75), Vector3.ONE * size * 0.55, rng, color)


## 火の炎（頭の上）：まん中の大きい炎と、左右の小さい炎。
static func _add_flames(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var lean := float(source["lean"])
	var tip := Color(str(source["tip_color"]))
	_add_flame_tongue(bits, length, width, lean, 0.75, tip, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.1, 0.0)))
	var side_scale := float(source["side_scale"])
	if side_scale <= 0.0:
		return
	for side: float in [1.0, -1.0]:
		var lean_out := Basis(Vector3.BACK, deg_to_rad(-30.0 * side))
		_add_flame_tongue(bits, length * side_scale, width * side_scale, -lean * side_scale * side, 0.75, tip, Transform3D(lean_out, Vector3(width * 0.75 * side, -0.12, 0.0)))


## 火の炎（左右・尾）：外へ伸びて、後ろへ流れる。tilt_deg で先を上げ、roll_deg で平たい面を後ろへ向ける。
static func _add_side_flame(bits: Bits, source: Dictionary) -> void:
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	var roll := Basis(Vector3.RIGHT, deg_to_rad(float(source["roll_deg"])))
	_add_flame_tongue(bits, float(source["length"]), float(source["width"]), float(source["lean"]), 0.5, Color(str(source["tip_color"])), Transform3D(tilt * roll * ALONG_X, Vector3.ZERO))


## 炎1つ。下がふくらんで、先がとがって曲がる。先へ行くほど、tip の色になる。
static func _add_flame_tongue(bits: Bits, length: float, width: float, lean: float, depth_ratio: float, tip: Color, xform: Transform3D) -> void:
	var steps := 22
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		# いったん反対へふくらんでから、先が横へ曲がる。
		centers.append(Vector3(lean * (pow(t, 2.2) - 0.45 * sin(t * PI)), length * t, 0.0))
		var swell := lerpf(0.7, 1.0, smoothstep(0.0, 0.28, t))
		var taper := pow(1.0 - smoothstep(0.28, 1.0, t), 0.85)
		radii.append(width * swell * (taper if t > 0.28 else 1.0))
		colors.append(_tint(tip, smoothstep(0.15, 0.9, t) * 0.92))
	_add_tube(bits, centers, radii, depth_ratio, colors, xform)


## 風の芽（頭の上）：短い茎と、左右に開いた2枚の葉。
static func _add_sprout(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var stem_top := 0.07
	var stem_centers: Array[Vector3] = [Vector3(0.0, -0.1, 0.0), Vector3(0.0, stem_top * 0.5, 0.0), Vector3(0.0, stem_top + 0.02, 0.0)]
	var stem_radii: Array[float] = [0.032, 0.026, 0.0]
	var stem_color := _tint(color.darkened(0.18), 1.0)
	var stem_colors: Array[Color] = [stem_color, stem_color, stem_color]
	_add_tube(bits, stem_centers, stem_radii, 1.0, stem_colors, Transform3D.IDENTITY)
	for side: float in [1.0, -1.0]:
		var spread := Basis(Vector3.BACK, deg_to_rad(-float(source["spread_deg"]) * side))
		_add_leaf_blade(bits, length, width, length * 0.28 * side, color, Transform3D(spread, Vector3(0.0, stem_top, 0.0)))


## 風の葉（左右・尾）：羽のように、何枚か重ねる。2枚目からは、少し小さく、後ろへ開く。
static func _add_leaves(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	# 平たい面を、後ろへ向ける量。
	var roll := Basis(Vector3.RIGHT, deg_to_rad(float(source["roll_deg"])))
	for index in int(source["feathers"]):
		var shrink := 1.0 - 0.2 * float(index)
		# 上（+Y）を軸に、先を後ろ（+Z）へ回す。
		var sweep := Basis(Vector3.UP, deg_to_rad(-float(source["sweep_deg"]) * float(index)))
		_add_leaf_blade(bits, length * shrink, width * shrink, length * 0.12, color, Transform3D(tilt * sweep * roll * ALONG_X, Vector3(0.0, -0.012 * float(index), 0.0)))


## 葉1枚。付け根が細く、まん中が広く、先がとがる。薄い。bend は、先の曲がり。
static func _add_leaf_blade(bits: Bits, length: float, width: float, bend: float, color: Color, xform: Transform3D) -> void:
	var steps := 18
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(bend * t * t, length * t, 0.0))
		radii.append(maxf(width * sin(PI * pow(t, 0.7)), width * 0.14 * (1.0 - t)))
		colors.append(_tint(color.darkened(0.18).lerp(color.lightened(0.18), t), 1.0))
	_add_tube(bits, centers, radii, 0.2, colors, xform)


## 背骨（XY平面の曲線）に沿って、楕円の輪切りを並べた形を足す。
## radii は、背骨に直角な横の半径。depth_ratio は、奥行き（Z）の、横に対する比。
static func _add_tube(bits: Bits, centers: Array[Vector3], radii: Array[float], depth_ratio: float, colors: Array[Color], xform: Transform3D) -> void:
	var last := centers.size() - 1
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	for index in last + 1:
		var tangent := (centers[mini(index + 1, last)] - centers[maxi(index - 1, 0)]).normalized()
		var side := Vector3(-tangent.y, tangent.x, 0.0).normalized()
		for step in AROUND:
			var angle := TAU * float(step) / float(AROUND)
			points.append(centers[index] + (side * cos(angle) + Vector3.BACK * sin(angle) * depth_ratio) * radii[index])
			# 閉じた先端は、背骨の向き。それ以外は、楕円の外向き。
			normals.append(tangent if index == last else (side * cos(angle) + Vector3.BACK * sin(angle) / depth_ratio).normalized())
			tints.append(colors[index])
	_add_rings(bits, points, normals, tints, last + 1, AROUND, xform)


## 楕円の玉を足す。
static func _add_ellipsoid(bits: Bits, center: Vector3, radii: Vector3, color: Color, xform: Transform3D) -> void:
	var rings := 12
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	for ring in rings + 1:
		var theta := PI * float(ring) / float(rings)
		for step in AROUND:
			var phi := TAU * float(step) / float(AROUND)
			var unit := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			points.append(center + unit * radii)
			normals.append((unit / radii).normalized())
			tints.append(color)
	_add_rings(bits, points, normals, tints, rings + 1, AROUND, xform)


## 輪を並べた点（1つの輪に around 個）を、向きと位置を合わせて足し、輪どうしを面でつなぐ。
static func _add_rings(bits: Bits, points: PackedVector3Array, normals: PackedVector3Array, tints: PackedColorArray, rings: int, around: int, xform: Transform3D) -> void:
	var first := bits.vertices.size()
	for index in points.size():
		bits.vertices.append(xform * points[index])
		bits.normals.append((xform.basis * normals[index]).normalized())
		bits.colors.append(tints[index])
	for ring in rings - 1:
		for step in around:
			var next := (step + 1) % around
			var a := first + ring * around + step
			var b := first + ring * around + next
			var c := first + (ring + 1) * around + step
			var d := first + (ring + 1) * around + next
			Surface.push_triangle(bits.indices, bits.vertices, bits.normals, a, b, c)
			Surface.push_triangle(bits.indices, bits.vertices, bits.normals, b, d, c)


## 岩1つ。20面のかたまりの角を、ばらばらに出し入れして、ごつごつさせる（seed が同じなら、同じ形）。
static func _add_rock(bits: Bits, center: Vector3, size: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var golden := (1.0 + sqrt(5.0)) * 0.5
	var corners := [
		Vector3(-1, golden, 0), Vector3(1, golden, 0), Vector3(-1, -golden, 0), Vector3(1, -golden, 0),
		Vector3(0, -1, golden), Vector3(0, 1, golden), Vector3(0, -1, -golden), Vector3(0, 1, -golden),
		Vector3(golden, 0, -1), Vector3(golden, 0, 1), Vector3(-golden, 0, -1), Vector3(-golden, 0, 1),
	]
	var faces := [
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
	]
	var first := bits.vertices.size()
	for corner: Vector3 in corners:
		var direction := corner.normalized()
		bits.vertices.append(center + direction * size * rng.randf_range(0.72, 1.12))
		bits.normals.append(direction)
		# 角ごとに、少し明るさを変える。
		var shade := rng.randf_range(-0.14, 0.1)
		bits.colors.append(_tint(color.lightened(shade) if shade > 0.0 else color.darkened(-shade), 1.0))
	for index in range(0, faces.size(), 3):
		Surface.push_triangle(bits.indices, bits.vertices, bits.normals, first + faces[index], first + faces[index + 1], first + faces[index + 2])
