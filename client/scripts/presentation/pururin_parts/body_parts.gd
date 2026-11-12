extends RefCounted
## 体の一部（頭の上・左右・尾）の部品を作る。
## source.type が "builtin" なら、こちらで形を作る。"mesh" なら、用意されたメッシュを付ける。
## 体の一部は、あとでアクションごとに動かせるように、1つずつ別の節にして返す（節の原点が、付け根）。
## こちらで作る形は、頂点に色を持てる（色の濃さ＝アルファ。0なら体の色のまま）。

const Surface := preload("res://scripts/presentation/pururin_parts/pururin_surface.gd")
const PartAssets := preload("res://scripts/presentation/pururin_parts/part_assets.gd")
## こちらで作れる形（スロットごと）。
const BUILTIN_SHAPES := {
	"top": ["nub", "rocks", "flames", "sprout", "bubbles", "crystals", "horns", "ring", "ears", "antenna", "bow", "crown", "flower", "horn", "hat", "star_antenna", "witch_hat", "mushroom", "propeller"],
	"side": ["flipper", "rock", "flame", "leaf", "drop", "crystal", "bat_wing", "hand", "bow", "butterfly"],
	"tail": ["flipper", "rock", "flame", "leaf", "bubble", "crystal", "bow", "curl", "tuft", "star", "heart", "devil", "spiky"],
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
	"bubbles": ["size", "count", "spread", "seed"],
	"bubble": ["size", "count", "seed"],
	"drop": ["length", "width", "tilt_deg", "fan_deg"],
	"crystals": ["length", "width", "count", "spread", "seed"],
	"crystal": ["length", "width", "tilt_deg", "seed"],
	"horns": ["length", "width", "spread_deg", "curve"],
	"ring": ["radius", "thickness", "height", "tilt_deg"],
	"ears": ["length", "width", "spread", "tilt_deg", "point"],
	"antenna": ["length", "thickness", "ball", "curve"],
	"bow": ["size"],
	"crown": ["radius", "height", "points"],
	"bat_wing": ["length", "width", "count", "fan_deg", "tilt_deg", "roll_deg"],
	"hand": ["size", "tilt_deg"],
	"curl": ["length", "thickness", "turns"],
	"tuft": ["size", "count", "seed"],
	"flower": ["size", "petals"],
	"horn": ["length", "width"],
	"hat": ["radius", "height", "tilt_deg"],
	"star_antenna": ["length", "thickness", "curve", "star_size"],
	"witch_hat": ["radius", "height", "bend", "tilt_deg"],
	"mushroom": ["radius", "height"],
	"propeller": ["size", "blades"],
	"butterfly": ["size", "tilt_deg"],
	"star": ["size", "depth", "tilt_deg"],
	"heart": ["size", "depth", "tilt_deg"],
	"devil": ["length", "thickness", "tip_size"],
	"spiky": ["length", "thickness", "spikes"],
}
## 形ごとに、必ず要る色。
const REQUIRED_COLORS := {
	"rocks": ["color"],
	"rock": ["color"],
	"flames": ["tip_color"],
	"flame": ["tip_color"],
	"sprout": ["color"],
	"leaf": ["color"],
	"bubbles": ["color"],
	"bubble": ["color"],
	"drop": ["color"],
	"crystals": ["color"],
	"crystal": ["color"],
	"horns": ["color"],
	"ring": ["color"],
	"ears": ["color"],
	"antenna": ["color"],
	"bow": ["color"],
	"crown": ["color", "gem_color"],
	"bat_wing": ["color"],
	"tuft": ["color"],
	"flower": ["color", "center_color", "stem_color"],
	"horn": ["color"],
	"hat": ["color", "band_color"],
	"star_antenna": ["color"],
	"witch_hat": ["color", "band_color"],
	"mushroom": ["color", "spot_color", "stem_color"],
	"propeller": ["color", "hub_color"],
	"butterfly": ["color", "spot_color"],
	"star": ["color"],
	"heart": ["color"],
	"devil": ["color"],
	"spiky": ["color"],
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
			"bubbles": _add_bubbles(bits, shape, source)
			"crystals": _add_crystals(bits, shape, source)
			"horns": _add_horns(bits, source)
			"ring": _add_ring(bits, source)
			"ears": _add_ears(bits, shape, source)
			"antenna": _add_antenna(bits, source)
			"bow": _add_bow(bits, source, false)
			"crown": _add_crown(bits, shape, source)
			"flower": _add_flower(bits, source)
			"horn": _add_horn(bits, source)
			"hat": _add_hat(bits, source)
			"star_antenna": _add_star_antenna(bits, source)
			"witch_hat": _add_witch_hat(bits, source)
			"mushroom": _add_mushroom(bits, source)
			"propeller": _add_propeller(bits, source)
		node = _builtin_node(bits, body_material, str(source["shape"]) in ["rocks", "crystals"])
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
		var node := _attached(source, point, Basis(outward, Vector3.UP, backward), body_material, true)
		node.name = "Side%s" % ("R" if side > 0.0 else "L")
		nodes.append(node)
	return nodes


## 尾の部品。placement は、付ける高さ（height_ratio）。真後ろに付ける。
static func build_tail(shape: Dictionary, source: Dictionary, placement: Dictionary, body_material: Material) -> Array[Node3D]:
	var spot := Surface.anchor(shape, 180.0, float(placement["height_ratio"]))
	var node := _attached(source, spot[0], Basis(Vector3.BACK, Vector3.UP, Vector3.BACK.cross(Vector3.UP)), body_material, false)
	node.name = "Tail"
	return [node]


## 体の表面の点に付ける部品。basis の x が、体から外へ伸びる向き、y が上。on_side なら左右、でなければ尾。
static func _attached(source: Dictionary, point: Vector3, basis: Basis, body_material: Material, on_side: bool) -> Node3D:
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
		"bubble": _add_side_bubbles(bits, source)
		"drop": _add_drop_wing(bits, source)
		"crystal": _add_side_crystal(bits, source)
		"bat_wing": _add_bat_wing(bits, source)
		"hand": _add_hand(bits, source)
		"bow": _add_bow(bits, source, true)
		"curl": _add_curl(bits, source)
		"tuft": _add_tuft(bits, source)
		"butterfly": _add_butterfly(bits, source)
		"star": _add_attached_puffy(bits, source, _star_outline(float(source["size"])), on_side)
		"heart": _add_attached_puffy(bits, source, _heart_outline(float(source["size"])), on_side)
		"devil": _add_devil(bits, source)
		"spiky": _add_spiky(bits, source)
	node = _builtin_node(bits, body_material, str(source["shape"]) in ["rock", "crystal"])
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


## 水の泡（頭の上）：大きい玉1つと、まわりの小さい玉。体の丸みに沿って置く。
static func _add_bubbles(bits: Bits, shape: Dictionary, source: Dictionary) -> void:
	var size := float(source["size"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	_add_ellipsoid(bits, Vector3(0.0, size * 0.75, 0.0), Vector3.ONE * size, _tint(color, 0.8), Transform3D.IDENTITY)
	var count := int(source["count"])
	for index in count - 1:
		var angle := TAU * (float(index) + rng.randf_range(-0.2, 0.2)) / float(maxi(count - 1, 1)) + 0.4
		var distance := float(source["spread"]) * rng.randf_range(0.85, 1.15)
		var small := size * rng.randf_range(0.42, 0.72)
		# その場所の、体の表面の高さ（頭のてっぺんからの差）に合わせて、少し埋める。
		var drop := Surface.height_at_radius(shape, distance) - float(shape["height"])
		_add_ellipsoid(bits, Vector3(cos(angle) * distance, drop + small * 0.85, sin(angle) * distance), Vector3.ONE * small, _tint(color, 0.8), Transform3D.IDENTITY)


## しずくの羽（左右）：水のしずくの形を3枚、扇のように広げる。とがった先が体のほう、丸い先が外。先へ行くほど明るい。
static func _add_drop_wing(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var tilt := float(source["tilt_deg"])
	var fan := float(source["fan_deg"])
	var steps := 22
	for index in 3:
		var shrink := [1.0, 0.82, 0.66][index] as float
		var angle := tilt + fan * (1.0 - float(index))
		var centers: Array[Vector3] = []
		var radii: Array[float] = []
		var colors: Array[Color] = []
		for step in steps + 1:
			var t := float(step) / float(steps)
			centers.append(Vector3(length * shrink * t, 0.0, 0.0))
			# 体のほうは細くとがり、外の3割で丸く閉じる。
			var round_end := sqrt(maxf(1.0 - pow((t - 0.68) / 0.32, 2.0), 0.0))
			radii.append(width * shrink * (pow(t / 0.68, 1.1) if t < 0.68 else round_end))
			colors.append(_tint(color.lerp(color.lightened(0.45), t), 0.85))
		# 下の羽ほど、少し後ろへ流す。
		var sweep := Basis(Vector3.UP, deg_to_rad(-12.0 * float(index)))
		_add_tube(bits, centers, radii, 0.5, colors, Transform3D(Basis(Vector3.BACK, deg_to_rad(angle)) * sweep, Vector3(-0.02, 0.0, 0.01 * float(index))))


## 水の泡（尾）：外へ向かって、だんだん小さくなる玉を並べる。
static func _add_side_bubbles(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	var count := int(source["count"])
	for index in count:
		var t := float(index) / float(maxi(count - 1, 1))
		var small := size * lerpf(1.0, 0.45, t)
		var outward := size * (0.25 + 1.6 * t)
		var wobble := Vector3(0.0, size * rng.randf_range(-0.22, 0.42), size * rng.randf_range(-0.35, 0.35))
		_add_ellipsoid(bits, Vector3(outward, 0.0, 0.0) + wobble, Vector3.ONE * small, _tint(color, 0.8), Transform3D.IDENTITY)


## 地の結晶（頭の上）：まん中の大きい柱と、まわりの小さい柱。外へ少し傾けて立てる。
static func _add_crystals(bits: Bits, shape: Dictionary, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	_add_shard(bits, Vector3(0.0, -0.05, 0.0), Vector3.UP, length, width, color)
	var count := int(source["count"])
	for index in count - 1:
		var angle := TAU * (float(index) + rng.randf_range(-0.18, 0.18)) / float(maxi(count - 1, 1)) + 0.7
		var distance := float(source["spread"]) * rng.randf_range(0.85, 1.15)
		var small := length * rng.randf_range(0.42, 0.72)
		var drop := Surface.height_at_radius(shape, distance) - float(shape["height"])
		var base := Vector3(cos(angle) * distance, drop, sin(angle) * distance)
		# 外へ少し開くように、先を傾ける。
		var lean := (Vector3(cos(angle), 0.0, sin(angle)) * 0.45 + Vector3.UP).normalized()
		_add_shard(bits, base, lean, small, width * rng.randf_range(0.6, 0.85), color)


## 地の結晶（左右・尾）：外へ伸びる柱1本と、その根元の小さい柱。
static func _add_side_crystal(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	var tilt := deg_to_rad(float(source["tilt_deg"]))
	var main := Vector3(cos(tilt), sin(tilt), 0.0).normalized()
	_add_shard(bits, Vector3(-0.02, 0.0, 0.0), main, length, width, color)
	var aside := Vector3(cos(tilt - 0.5), sin(tilt - 0.5), rng.randf_range(-0.25, 0.25)).normalized()
	_add_shard(bits, Vector3(0.0, -width * 0.6, width * 0.5), aside, length * 0.55, width * 0.7, color)


## 結晶を1本。四角い柱が、先でとがる。base が根元、direction が伸びる向き。
static func _add_shard(bits: Bits, base: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	var up := direction.normalized()
	var side := (Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).cross(up).normalized()
	var other := up.cross(side).normalized()
	var first := bits.vertices.size()
	# 根元・途中・先の、3つの輪切り（先は1点にすぼめる）。
	var rings := [[0.0, 1.0], [0.55, 0.78], [1.0, 0.0]]
	var tint := _tint(color, 1.0)
	for ring: Array in rings:
		var at := base + up * (length * float(ring[0]))
		var radius := width * float(ring[1])
		for corner in 4:
			var angle := TAU * float(corner) / 4.0 + PI * 0.25
			var outward := (side * cos(angle) + other * sin(angle)).normalized()
			bits.vertices.append(at + outward * radius)
			bits.normals.append(outward if radius > 0.0001 else up)
			bits.colors.append(tint)
	for ring in rings.size() - 1:
		for corner in 4:
			var next := (corner + 1) % 4
			var a := first + ring * 4 + corner
			var b := first + ring * 4 + next
			var c := first + (ring + 1) * 4 + corner
			var d := first + (ring + 1) * 4 + next
			Surface.push_triangle(bits.indices, bits.vertices, bits.normals, a, b, c)
			Surface.push_triangle(bits.indices, bits.vertices, bits.normals, b, d, c)


## 角（頭の上）：左右に1本ずつ。根元が太く、外へ反りながら、先がとがる。
static func _add_horns(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var spread := float(source["spread_deg"])
	var curve := float(source["curve"])
	var color := Color(str(source["color"]))
	var steps := 16
	for side: float in [1.0, -1.0]:
		var centers: Array[Vector3] = []
		var radii: Array[float] = []
		var colors: Array[Color] = []
		for index in steps + 1:
			var t := float(index) / float(steps)
			# 上へ伸びながら、外へ反る。
			centers.append(Vector3(curve * t * t * side, length * t, 0.0))
			radii.append(width * pow(1.0 - t, 0.8))
			colors.append(_tint(color.darkened(0.12).lerp(color.lightened(0.22), t), 1.0))
		var lean := Basis(Vector3.BACK, deg_to_rad(-spread * side))
		_add_tube(bits, centers, radii, 0.9, colors, Transform3D(lean, Vector3(width * 0.7 * side, -0.06, 0.0)))


## 輪（頭の上）：頭の上に浮かぶ、細い輪。少し傾けて置く。
static func _add_ring(bits: Bits, source: Dictionary) -> void:
	var radius := float(source["radius"])
	var thickness := float(source["thickness"])
	var color := Color(str(source["color"]))
	var steps := 28
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	var tint := _tint(color, 1.0)
	for index in steps + 1:
		var angle := TAU * float(index) / float(steps)
		# 背骨はXY平面に置く（_add_tube は、XY平面の曲線に沿って輪切りを並べる）。
		centers.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
		radii.append(thickness)
		colors.append(tint)
	# 立った輪を寝かせてから、少し傾ける。
	var lay := Basis(Vector3.RIGHT, deg_to_rad(90.0))
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D(tilt * lay, Vector3(0.0, float(source["height"]), 0.0)))


## 耳（頭の上）：左右に1枚ずつ。平たく、前に内側の色。point が 1 なら先がとがる（ねこ）、0 なら先が丸い（うさぎ）。
static func _add_ears(bits: Bits, shape: Dictionary, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var spread := float(source["spread"])
	var point := float(source["point"])
	var inner := _tint(Color(str(source["color"])), 1.0)
	var drop := Surface.height_at_radius(shape, spread) - float(shape["height"])
	var steps := 18
	for side: float in [1.0, -1.0]:
		var centers: Array[Vector3] = []
		var inner_centers: Array[Vector3] = []
		var radii: Array[float] = []
		var inner_radii: Array[float] = []
		var colors: Array[Color] = []
		var inner_colors: Array[Color] = []
		for index in steps + 1:
			var t := float(index) / float(steps)
			centers.append(Vector3(0.0, -0.08 + (length + 0.08) * t, 0.0))
			inner_centers.append(Vector3(0.0, length * (0.12 + 0.8 * t), -width * 0.3))
			var rounded := sqrt(maxf(1.0 - pow(t, 2.5), 0.0))
			radii.append(width * lerpf(rounded, 1.0 - t, point))
			var inner_t := 0.12 + 0.8 * t
			inner_radii.append(width * 0.55 * lerpf(sqrt(maxf(1.0 - pow(inner_t, 2.5), 0.0)), 1.0 - inner_t, point))
			colors.append(_plain())
			inner_colors.append(inner)
		var xform := Transform3D(Basis(Vector3.BACK, deg_to_rad(-float(source["tilt_deg"]) * side)), Vector3(spread * side, drop, 0.0))
		_add_tube(bits, centers, radii, 0.35, colors, xform)
		_add_tube(bits, inner_centers, inner_radii, 0.25, inner_colors, xform)


## アンテナ（頭の上）：細い茎が曲がって、先に玉。
static func _add_antenna(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var thickness := float(source["thickness"])
	var curve := float(source["curve"])
	var steps := 14
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(curve * t * t, -0.08 + (length + 0.08) * t, 0.0))
		radii.append(thickness * lerpf(1.6, 1.0, smoothstep(0.0, 0.3, t)))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)
	var ball := float(source["ball"])
	_add_ellipsoid(bits, centers[steps] + Vector3(0.0, ball * 0.6, 0.0), Vector3.ONE * ball, _tint(Color(str(source["color"])), 1.0), Transform3D.IDENTITY)


## リボン：左右の輪と、まん中の結び目。attached なら、体の表面（尾）に付ける向き（輪が、外を向く面に並ぶ）。
static func _add_bow(bits: Bits, source: Dictionary, attached: bool) -> void:
	var size := float(source["size"])
	var tint := _tint(Color(str(source["color"])), 1.0)
	var knot := _tint(Color(str(source["color"])).darkened(0.15), 1.0)
	# 頭の上は、正面を向いた面（XY）に並べる。尾は、外（+X）を向いた面（ZY）に並べる。
	var lay := Basis(Vector3.UP, PI * 0.5) if attached else Basis.IDENTITY
	var lift := Vector3(size * 0.3, 0.0, 0.0) if attached else Vector3(0.0, size * 0.25, 0.0)
	for side: float in [1.0, -1.0]:
		var tilt := Basis(Vector3.BACK, deg_to_rad(18.0 * side))
		_add_ellipsoid(bits, Vector3.ZERO, Vector3(size * 0.55, size * 0.36, size * 0.16), tint, Transform3D(lay * tilt, lay * Vector3(size * 0.5 * side, 0.0, 0.0) + lift))
	_add_ellipsoid(bits, Vector3.ZERO, Vector3(size * 0.2, size * 0.22, size * 0.2), knot, Transform3D(lay, lift))


## 王冠（頭の上）：輪と、上へとがった柱。柱の先に、宝石の玉。
static func _add_crown(bits: Bits, shape: Dictionary, source: Dictionary) -> void:
	var radius := float(source["radius"])
	var height := float(source["height"])
	var color := Color(str(source["color"]))
	var gem := _tint(Color(str(source["gem_color"])), 1.0)
	var drop := Surface.height_at_radius(shape, radius) - float(shape["height"])
	var steps := 28
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var angle := TAU * float(index) / float(steps)
		centers.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
		radii.append(height * 0.22)
		colors.append(_tint(color, 1.0))
	_add_tube(bits, centers, radii, 1.4, colors, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, drop + height * 0.15, 0.0)))
	var points := int(source["points"])
	for index in points:
		var angle := TAU * float(index) / float(points)
		var base := Vector3(cos(angle) * radius, drop + height * 0.1, sin(angle) * radius)
		_add_shard(bits, base, Vector3.UP, height, height * 0.3, color)
		_add_ellipsoid(bits, base + Vector3(0.0, height, 0.0), Vector3.ONE * height * 0.16, gem, Transform3D.IDENTITY)


## こうもりの羽（左右・尾）：細くとがった膜を、扇のように何枚か重ねる。平たい面は、roll_deg で後ろへ向ける。
static func _add_bat_wing(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var roll := Basis(Vector3.RIGHT, deg_to_rad(float(source["roll_deg"])))
	var count := int(source["count"])
	for index in count:
		var shrink := 1.0 - 0.18 * float(index)
		# 上の羽ほど、先を上げる。
		var fan := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"]) + float(source["fan_deg"]) * (float(index) - float(count - 1) * 0.5)))
		_add_wing_blade(bits, length * shrink, width * shrink, color, Transform3D(fan * roll * ALONG_X, Vector3(0.0, 0.0, -0.01 * float(index))))


## 膜1枚。根元が広く、先が細くとがる。薄い。
static func _add_wing_blade(bits: Bits, length: float, width: float, color: Color, xform: Transform3D) -> void:
	var steps := 14
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(length * 0.1 * t * t, length * t, 0.0))
		radii.append(width * pow(1.0 - t, 0.7) * lerpf(0.7, 1.0, smoothstep(0.0, 0.2, t)))
		colors.append(_tint(color.darkened(0.1).lerp(color.lightened(0.1), t), 1.0))
	_add_tube(bits, centers, radii, 0.15, colors, xform)


## まるい手（左右）：体から少し出た、丸いふくらみ。体と同じ色。
static func _add_hand(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	_add_ellipsoid(bits, Vector3(size * 0.55, 0.0, 0.0), Vector3(size, size * 0.8, size * 0.85), _plain(), Transform3D(tilt, Vector3.ZERO))


## くるりんしっぽ：外へ出てから、上へ巻く。先ほど細い。体と同じ色。
static func _add_curl(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var thickness := float(source["thickness"])
	var turn := float(source["turns"]) * TAU
	var steps := 36
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		var swing := length * 0.35 * (1.0 - 0.7 * t)
		var angle := turn * t
		centers.append(Vector3(-0.03 + swing * sin(angle) + length * 0.25 * t, length * 0.35 - swing * cos(angle), 0.0))
		radii.append(thickness * lerpf(1.0, 0.45, t) * (sqrt(maxf(1.0 - pow(maxf(t - 0.92, 0.0) / 0.08, 2.0), 0.0)) if t > 0.92 else 1.0))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)


## ふさふさしっぽ：玉を何個か、かたまりにする。
static func _add_tuft(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var tint := _tint(Color(str(source["color"])), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source["seed"])
	_add_ellipsoid(bits, Vector3(size * 0.6, 0.0, 0.0), Vector3.ONE * size, tint, Transform3D.IDENTITY)
	var count := int(source["count"])
	for index in count - 1:
		var angle := TAU * float(index) / float(maxi(count - 1, 1)) + rng.randf_range(-0.3, 0.3)
		var small := size * rng.randf_range(0.55, 0.75)
		var at := Vector3(size * rng.randf_range(0.6, 1.0), sin(angle) * size * 0.7, cos(angle) * size * 0.7)
		_add_ellipsoid(bits, at, Vector3.ONE * small, tint, Transform3D.IDENTITY)


## 花（頭の上）：短い茎の先に、正面を向いた花びらと、まん中の玉。
static func _add_flower(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var lift := size * 1.1
	var stem := _tint(Color(str(source["stem_color"])), 1.0)
	var stem_centers: Array[Vector3] = [Vector3(0.0, -0.08, 0.0), Vector3(0.0, lift * 0.5, 0.0), Vector3(0.0, lift, 0.0)]
	var stem_radii: Array[float] = [size * 0.16, size * 0.12, size * 0.1]
	var stem_colors: Array[Color] = [stem, stem, stem]
	_add_tube(bits, stem_centers, stem_radii, 1.0, stem_colors, Transform3D.IDENTITY)
	# 少し上を向ける（前は -Z）。
	var face := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0.0, lift, 0.0))
	var petal := _tint(Color(str(source["color"])), 1.0)
	var petals := int(source["petals"])
	for index in petals:
		var angle := TAU * float(index) / float(petals) + PI * 0.5
		var around := Basis(Vector3.BACK, angle)
		_add_ellipsoid(bits, Vector3.ZERO, Vector3(size * 0.55, size * 0.34, size * 0.12), petal, face * Transform3D(around, around * Vector3(size * 0.58, 0.0, 0.0)))
	_add_ellipsoid(bits, Vector3(0.0, 0.0, -size * 0.06), Vector3(size * 0.36, size * 0.36, size * 0.2), _tint(Color(str(source["center_color"])), 1.0), face)


## 一本角（頭の上）：まっすぐ上へ伸びて、先がとがる。少し前へ傾ける。しま模様。
static func _add_horn(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var width := float(source["width"])
	var color := Color(str(source["color"]))
	var steps := 24
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(0.0, -0.06 + (length + 0.06) * t, 0.0))
		radii.append(width * pow(1.0 - t, 0.9))
		var stripe := 0.5 + 0.5 * sin(t * TAU * 3.5)
		colors.append(_tint(color.darkened(0.12 * stripe).lerp(color.lightened(0.25), t * 0.5), 1.0))
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(0.0, 0.0, -width * 0.4)))


## シルクハット（頭の上）：平たいつばと、筒の帽子。帽子の下のほうに、帯。
static func _add_hat(bits: Bits, source: Dictionary) -> void:
	var radius := float(source["radius"])
	var height := float(source["height"])
	var tilt := Transform3D(Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"]))), Vector3(0.0, -0.02, 0.0))
	var color := _tint(Color(str(source["color"])), 1.0)
	_add_ellipsoid(bits, Vector3.ZERO, Vector3(radius * 1.55, radius * 0.1, radius * 1.55), color, tilt)
	_add_cylinder(bits, 0.0, height, radius, color, tilt)
	_add_cylinder(bits, height * 0.08, height * 0.3, radius * 1.04, _tint(Color(str(source["band_color"])), 1.0), tilt)


## とんがり帽子（頭の上）：広いつばと、先が後ろへ折れる、とがった帽子。帽子の下に、帯。
static func _add_witch_hat(bits: Bits, source: Dictionary) -> void:
	var radius := float(source["radius"])
	var height := float(source["height"])
	var bend := float(source["bend"])
	var tilt := Transform3D(Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"]))), Vector3(0.0, -0.02, 0.0))
	var color := _tint(Color(str(source["color"])), 1.0)
	_add_ellipsoid(bits, Vector3.ZERO, Vector3(radius * 1.7, radius * 0.08, radius * 1.7), color, tilt)
	var steps := 18
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		# 上のほうほど、後ろ（+Z）へ曲がる。
		centers.append(Vector3(0.0, height * t, bend * pow(t, 2.5)))
		radii.append(radius * (1.0 - t))
		colors.append(color)
	_add_tube(bits, centers, radii, 1.0, colors, tilt)
	_add_cylinder(bits, 0.0, height * 0.14, radius * 0.92, _tint(Color(str(source["band_color"])), 1.0), tilt)


## きのこ（頭の上）：短い柄と、丸いかさ。かさに白い水玉。
static func _add_mushroom(bits: Bits, source: Dictionary) -> void:
	var radius := float(source["radius"])
	var height := float(source["height"])
	_add_cylinder(bits, -0.06, height, radius * 0.38, _tint(Color(str(source["stem_color"])), 1.0), Transform3D.IDENTITY)
	var cap := _tint(Color(str(source["color"])), 1.0)
	_add_ellipsoid(bits, Vector3(0.0, height, 0.0), Vector3(radius, radius * 0.72, radius), cap, Transform3D.IDENTITY)
	var spot := _tint(Color(str(source["spot_color"])), 1.0)
	for index in 6:
		var angle := TAU * float(index) / 6.0 + 0.3
		var up := 0.55 if index % 2 == 0 else 0.9
		var direction := Vector3(cos(angle) * sin(up), cos(up) * 0.72, sin(angle) * sin(up)).normalized()
		var point := Vector3(0.0, height, 0.0) + Vector3(direction.x * radius, direction.y * radius * 0.72 / 0.72, direction.z * radius) * 0.98
		var lay := Basis(Quaternion(Vector3.UP, direction))
		_add_ellipsoid(bits, Vector3.ZERO, Vector3(radius * 0.2, radius * 0.04, radius * 0.2), spot, Transform3D(lay, point))
	_add_ellipsoid(bits, Vector3(0.0, height * 1.0 + radius * 0.72, 0.0), Vector3(radius * 0.22, radius * 0.05, radius * 0.22), spot, Transform3D.IDENTITY)


## プロペラ（頭の上）：短い棒の先に、平たい羽根と、まん中の玉。
static func _add_propeller(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var color := _tint(Color(str(source["color"])), 1.0)
	_add_cylinder(bits, -0.06, size * 0.55, size * 0.07, _plain(), Transform3D.IDENTITY)
	var blades := int(source["blades"])
	for index in blades:
		var around := Basis(Vector3.UP, TAU * float(index) / float(blades))
		# 羽根は少しひねる。
		var twist := Basis(Vector3.RIGHT, deg_to_rad(18.0))
		_add_ellipsoid(bits, Vector3.ZERO, Vector3(size * 0.16, size * 0.025, size * 0.5), color, Transform3D(around * twist, around * Vector3(0.0, size * 0.6, size * 0.48)))
	_add_ellipsoid(bits, Vector3(0.0, size * 0.62, 0.0), Vector3(size * 0.13, size * 0.1, size * 0.13), _tint(Color(str(source["hub_color"])), 1.0), Transform3D.IDENTITY)


## 上下が閉じた筒（Y の向き）。
static func _add_cylinder(bits: Bits, bottom: float, top: float, radius: float, color: Color, xform: Transform3D) -> void:
	var edge := minf(radius * 0.08, (top - bottom) * 0.1)
	var centers: Array[Vector3] = [Vector3(0.0, bottom, 0.0), Vector3(0.0, bottom + 0.001, 0.0), Vector3(0.0, bottom + edge, 0.0), Vector3(0.0, top - edge, 0.0), Vector3(0.0, top - 0.001, 0.0), Vector3(0.0, top, 0.0)]
	var radii: Array[float] = [0.0, radius - edge, radius, radius, radius - edge, 0.0]
	var colors: Array[Color] = [color, color, color, color, color, color]
	_add_tube(bits, centers, radii, 1.0, colors, xform)


## 星のアンテナ（頭の上）：細い茎が曲がって、先に正面を向いた星。
static func _add_star_antenna(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var thickness := float(source["thickness"])
	var curve := float(source["curve"])
	var steps := 14
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(curve * t * t, -0.08 + (length + 0.08) * t, 0.0))
		radii.append(thickness * lerpf(1.6, 1.0, smoothstep(0.0, 0.3, t)))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)
	var star_size := float(source["star_size"])
	_add_puffy(bits, _star_outline(star_size), star_size * 0.35, Color(str(source["color"])), Transform3D(Basis.IDENTITY, centers[steps] + Vector3(0.0, star_size * 0.7, 0.0)))


## ちょうちょの羽（左右）：上の大きい羽と、下の小さい羽。正面から見える向き。羽のまん中に、丸い模様。
static func _add_butterfly(bits: Bits, source: Dictionary) -> void:
	var size := float(source["size"])
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	var wing := _tint(Color(str(source["color"])), 1.0)
	var spot := _tint(Color(str(source["spot_color"])), 1.0)
	var lobes := [[Vector3(size * 0.8, size * 0.42, 0.0), Vector2(size, size * 0.72), 35.0], [Vector3(size * 0.58, -size * 0.38, 0.0), Vector2(size * 0.66, size * 0.48), -30.0]]
	for lobe: Array in lobes:
		var turn := Basis(Vector3.BACK, deg_to_rad(float(lobe[2])))
		var xform := Transform3D(tilt * turn, tilt * (lobe[0] as Vector3))
		var radii: Vector2 = lobe[1]
		_add_ellipsoid(bits, Vector3.ZERO, Vector3(radii.x, radii.y, size * 0.06), wing, xform)
		_add_ellipsoid(bits, Vector3(radii.x * 0.15, 0.0, 0.0), Vector3(radii.x * 0.38, radii.y * 0.42, size * 0.08), spot, xform)


## 星・ハート（左右・尾）。左右は、正面から見える向き。尾は、後ろから見える向き。
static func _add_attached_puffy(bits: Bits, source: Dictionary, outline: PackedVector2Array, on_side: bool) -> void:
	var size := float(source["size"])
	var tilt := Basis(Vector3.BACK, deg_to_rad(float(source["tilt_deg"])))
	var lay := Basis.IDENTITY if on_side else Basis(Vector3.UP, PI * 0.5)
	_add_puffy(bits, outline, float(source["depth"]), Color(str(source["color"])), Transform3D(tilt * lay, tilt * Vector3(size * 0.75, 0.0, 0.0)))


## あくましっぽ：細いしっぽが外へ出てから上へ曲がり、先に、上を向いたとがった形（ハートの逆さ）。
static func _add_devil(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var thickness := float(source["thickness"])
	var steps := 20
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(-0.03 + length * 0.7 * sin(t * PI * 0.5), length * (1.0 - cos(t * PI * 0.5)) * 0.9, 0.0))
		radii.append(thickness * lerpf(1.0, 0.6, t))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)
	var tip_size := float(source["tip_size"])
	# ハートを逆さにして、とがった先を上へ。後ろから見える向き。
	var flip := Basis(Vector3.BACK, PI)
	_add_puffy(bits, _heart_outline(tip_size), tip_size * 0.3, Color(str(source["color"])), Transform3D(Basis(Vector3.UP, PI * 0.5) * flip, centers[steps] + Vector3(0.0, tip_size * 0.75, 0.0)))


## ドラゴンしっぽ：太い根元から外へ細くなるしっぽと、背中側に並んだとげ。
static func _add_spiky(bits: Bits, source: Dictionary) -> void:
	var length := float(source["length"])
	var thickness := float(source["thickness"])
	var steps := 24
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var colors: Array[Color] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		centers.append(Vector3(-0.03 + length * t, -length * 0.12 * sin(t * PI) + length * 0.18 * t * t, 0.0))
		radii.append(thickness * pow(1.0 - t, 0.75) + 0.004 * (1.0 - t))
		colors.append(_plain())
	_add_tube(bits, centers, radii, 1.0, colors, Transform3D.IDENTITY)
	var spikes := int(source["spikes"])
	var color := Color(str(source["color"]))
	for index in spikes:
		var t := (float(index) + 0.6) / (float(spikes) + 0.6)
		var at := int(round(t * float(steps)))
		var r := radii[at]
		_add_shard(bits, centers[at] + Vector3(0.0, r * 0.7, 0.0), Vector3(0.35, 1.0, 0.0).normalized(), thickness * 1.1 * (1.0 - t * 0.55), r * 0.45 + 0.006, color)


## 星の外周（XY 平面、上の角から）。
static func _star_outline(size: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in 10:
		var angle := PI * 0.5 + TAU * float(index) / 10.0
		var radius := size if index % 2 == 0 else size * 0.48
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
	return outline


## ハートの外周（XY 平面、とがった先が下）。まん中が原点の近くに来るように、少し下げる。
static func _heart_outline(size: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in 32:
		var t := TAU * float(index) / 32.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector2(x, y + 2.0) * (size / 17.0))
	return outline


## ふっくらした平たい形（星・ハート）。outline は XY 平面の外周。depth は、まん中の厚み（半分）。前後（±Z）にふくらむ。
static func _add_puffy(bits: Bits, outline: PackedVector2Array, depth: float, color: Color, xform: Transform3D) -> void:
	var tint := _tint(color, 1.0)
	var count := outline.size()
	var center := Vector2.ZERO
	for point: Vector2 in outline:
		center += point
	center /= float(count)
	# 外周から、まん中へ、だんだん小さく・厚くなる輪（大きさ、厚みの割合）。
	var layers := [[1.0, 0.0], [0.74, 0.7], [0.4, 0.94]]
	for face: float in [1.0, -1.0]:
		var first := bits.vertices.size()
		for layer: Array in layers:
			var scale := float(layer[0])
			var rise := float(layer[1])
			for point: Vector2 in outline:
				var flat := center + (point - center) * scale
				var out := (point - center).normalized() * (1.0 - rise)
				bits.vertices.append(xform * Vector3(flat.x, flat.y, depth * rise * face))
				bits.normals.append((xform.basis * Vector3(out.x, out.y, rise * face + 0.001 * face)).normalized())
				bits.colors.append(tint)
		var tip := bits.vertices.size()
		bits.vertices.append(xform * Vector3(center.x, center.y, depth * face))
		bits.normals.append((xform.basis * Vector3(0.0, 0.0, face)).normalized())
		bits.colors.append(tint)
		for layer in layers.size() - 1:
			for step in count:
				var next := (step + 1) % count
				var a := first + layer * count + step
				var b := first + layer * count + next
				var c := first + (layer + 1) * count + step
				var d := first + (layer + 1) * count + next
				Surface.push_triangle(bits.indices, bits.vertices, bits.normals, a, b, c)
				Surface.push_triangle(bits.indices, bits.vertices, bits.normals, b, d, c)
		var last := first + (layers.size() - 1) * count
		for step in count:
			Surface.push_triangle(bits.indices, bits.vertices, bits.normals, last + step, last + (step + 1) % count, tip)
