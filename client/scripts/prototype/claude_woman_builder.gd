extends RefCounted
## レース本編には接続しない、Claude による成人女性のローポリ試作（Codex版とは別ファイル）。
## すべての部位を、Godotの球・円柱などの部品(プリミティブ)に頼らず、頂点と三角形を自分で計算して作る。
## 体（脚・胴・首・頭）は、断面(x=半径, y=高さ)を軸まわりに回した回転体。
## 髪は、通り道（点の並び）に沿って太さを変えながら断面を押し出した、1本のつながった形（スイープ）。
## 目・口・宝石は、向きを決めた平らな多角形（ディスク）。
## 高さは実物大（約1.7m）。足元が原点、正面はマイナスZ（レース場の他の部品と同じ向き）。

const SKIN := Color("#f6c6b0")
const HAIR := Color("#2f4fb0")
const HAIR_DARK := Color("#24398a")
const WHITE := Color("#eef6fb")
const GREY := Color("#6b7686")
const TEAL := Color("#1a9b96")
const PURPLE := Color("#7a5ad1")
const PINK := Color("#e36bc9")
const GOLD := Color("#e8ce52")
const DARK := Color("#232a4a")
const BROW := Color("#3a4a8f")

## 体の節目の高さ（m）。脚・胴・首・頭は、ここに合わせて断面を積む。
const Y_SOLE := 0.0
const Y_ANKLE := 0.09
const Y_CALF := 0.30
const Y_KNEE := 0.46
const Y_THIGH := 0.66
const Y_HIP_JOINT := 0.84
const Y_SKIRT_HEM := 0.58
const Y_SKIRT_HIP := 0.90
const Y_WAIST := 1.08
const Y_BUST := 1.30
const Y_SHOULDER := 1.37
const Y_NECK_TOP := 1.45
const Y_CHIN := 1.47
const Y_CHEEK := 1.54
const Y_TEMPLE := 1.60
const Y_CROWN := 1.655
const Y_HAIR_TOP := 1.70
## 顔の正面（マイナスZ側）の半径のだいたいの目安。顔のパーツは、この面の少し外に置く。
const FACE_RADIUS := 0.092


static func build() -> Node3D:
	var woman := Node3D.new()
	woman.name = "ClaudeWoman"
	woman.set_meta("prototype_only", true)

	_add_legs(woman)
	_add_shoes(woman)
	_add_skirt(woman)
	_add_torso(woman)
	_add_neck(woman)
	_add_chest_gem(woman)
	_add_arms(woman)
	_add_head(woman)
	_add_hair(woman)
	_add_face(woman)
	return woman


# ---------------------------------------------------------------- 脚・くつ

static func _add_legs(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.050, Y_ANKLE), Vector2(0.062, Y_CALF), Vector2(0.070, Y_CALF + 0.07),
		Vector2(0.060, Y_KNEE), Vector2(0.068, Y_THIGH), Vector2(0.078, Y_THIGH + 0.10),
		Vector2(0.088, Y_HIP_JOINT),
	])
	for side: float in [-1.0, 1.0]:
		_add_lathe(parent, "Leg%s" % ("Left" if side < 0.0 else "Right"), profile, PURPLE,
			Vector3(side * 0.085, 0.0, 0.0), Vector3(0.0, 0.0, deg_to_rad(side * 1.5)))


static func _add_shoes(parent: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_add_mesh(parent, "Shoe%s" % ("Left" if side < 0.0 else "Right"), _shoe_mesh(side > 0.0), _material(PINK),
			Vector3(side * 0.085, Y_SOLE, -0.015))


# ---------------------------------------------------------------- 胴・スカート・首

static func _add_skirt(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.115, Y_WAIST), Vector2(0.150, Y_WAIST - 0.05), Vector2(0.165, Y_SKIRT_HIP),
		Vector2(0.155, Y_SKIRT_HIP - 0.14), Vector2(0.148, Y_SKIRT_HEM + 0.05), Vector2(0.150, Y_SKIRT_HEM),
	])
	_add_lathe(parent, "Skirt", profile, GREY, Vector3.ZERO)
	# 腰の帯（青緑）。スカートの少し外側に、薄い輪として重ねる。
	var band := PackedVector2Array([
		Vector2(0.158, Y_SKIRT_HIP + 0.05), Vector2(0.168, Y_SKIRT_HIP), Vector2(0.158, Y_SKIRT_HIP - 0.07),
	])
	_add_lathe(parent, "WaistBand", band, TEAL, Vector3.ZERO)


static func _add_torso(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.118, Y_WAIST), Vector2(0.138, Y_WAIST + 0.09), Vector2(0.155, Y_BUST),
		Vector2(0.150, Y_BUST + 0.045), Vector2(0.138, Y_SHOULDER - 0.02), Vector2(0.095, Y_SHOULDER),
	])
	_add_lathe(parent, "Torso", profile, WHITE, Vector3.ZERO)
	# 胸もとの青緑のV字飾り（前面だけの、平らな多角形）。
	_add_flat_fan(parent, "ChestPanel", [
		Vector3(0.0, Y_BUST - 0.03, -0.153),
		Vector3(-0.028, Y_SHOULDER - 0.01, -0.148), Vector3(-0.022, Y_BUST - 0.10, -0.148),
		Vector3(0.022, Y_BUST - 0.10, -0.148), Vector3(0.028, Y_SHOULDER - 0.01, -0.148),
	], TEAL)


static func _add_neck(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.044, Y_SHOULDER), Vector2(0.050, Y_SHOULDER + 0.04), Vector2(0.048, Y_NECK_TOP),
		Vector2(0.050, Y_CHIN),
	])
	_add_lathe(parent, "Neck", profile, SKIN, Vector3.ZERO)
	# えり（白）。首のつけ根に、細い輪。
	var collar := PackedVector2Array([
		Vector2(0.056, Y_SHOULDER + 0.01), Vector2(0.062, Y_SHOULDER + 0.055), Vector2(0.054, Y_SHOULDER + 0.09),
	])
	_add_lathe(parent, "Collar", collar, WHITE, Vector3.ZERO)


static func _add_chest_gem(parent: Node3D) -> void:
	var center := Vector3(0.0, Y_BUST - 0.04, -0.157)
	_add_disc(parent, "ChestGemFrame", center, Vector3.BACK, Vector3.UP, 0.026, 0.032, GOLD, 12)
	_add_disc(parent, "ChestGem", center + Vector3(0.0, 0.0, -0.004), Vector3.BACK, Vector3.UP, 0.018, 0.023, PINK, 12)


# ---------------------------------------------------------------- 腕

## 肩のつけ根（胴の外側）から、ひじで少し内側へ曲げ、手首で白い手袋にする。
## 関節の点（肩・ひじ・手首）を、ワールド座標で直接決めてから、その2点を結ぶ向きで回転体を置く
## （オイラー角の組み合わせだと、狙った向きにならないことがあるため）。
static func _add_arms(parent: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		var tag := "Left" if side < 0.0 else "Right"
		var shoulder := Vector3(side * 0.160, Y_SHOULDER - 0.01, -0.01)
		var upper_dir := Vector3(side * 0.32, -1.0, 0.08).normalized()
		var elbow := shoulder + upper_dir * 0.27
		_add_lathe_oriented(parent, "Upper%s" % tag, PackedVector2Array([
			Vector2(0.046, 0.0), Vector2(0.050, 0.04), Vector2(0.044, 0.20), Vector2(0.038, 0.27),
		]), SKIN, shoulder, upper_dir, 8)

		var forearm_dir := Vector3(side * -0.14, -1.0, 0.16).normalized()
		var wrist := elbow + forearm_dir * 0.20
		_add_lathe_oriented(parent, "Lower%s" % tag, PackedVector2Array([
			Vector2(0.037, 0.0), Vector2(0.034, 0.10), Vector2(0.029, 0.20),
		]), SKIN, elbow, forearm_dir, 8)
		_add_lathe_oriented(parent, "Glove%s" % tag, PackedVector2Array([
			Vector2(0.030, 0.19), Vector2(0.038, 0.225), Vector2(0.034, 0.27), Vector2(0.028, 0.30),
		]), WHITE, elbow, forearm_dir, 8)
		# 手の先は、細く閉じていくスイープで、握りこぶしのような丸みにする。
		_add_sweep(parent, "Hand%s" % tag, [
			wrist + forearm_dir * 0.02, wrist + forearm_dir * 0.07, wrist + forearm_dir * 0.10,
		], [0.028, 0.030, 0.0], WHITE, 8)


# ---------------------------------------------------------------- 頭・髪・顔

static func _add_head(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.050, Y_CHIN), Vector2(0.078, Y_CHIN + 0.025), Vector2(FACE_RADIUS, Y_CHEEK),
		Vector2(0.090, Y_TEMPLE), Vector2(0.066, Y_CROWN), Vector2(0.028, Y_CROWN + 0.03),
		Vector2(0.0, Y_HAIR_TOP - 0.05),
	])
	_add_lathe(parent, "Head", profile, SKIN, Vector3.ZERO, Vector3.ZERO, 14)


## 髪は、頭を覆う丸い帽子（回転体）に、額にかかる前髪のアーチ・横の房・後ろの房を、
## それぞれ1本のスイープ（通り道に沿って太さを変えた押し出し）として重ねる。
static func _add_hair(parent: Node3D) -> void:
	var cap := PackedVector2Array([
		Vector2(0.085, Y_CHEEK + 0.05), Vector2(0.100, Y_TEMPLE - 0.01), Vector2(0.108, Y_TEMPLE + 0.03),
		Vector2(0.112, Y_CROWN - 0.01), Vector2(0.095, Y_CROWN + 0.03), Vector2(0.055, Y_HAIR_TOP - 0.015),
		Vector2(0.0, Y_HAIR_TOP + 0.015),
	])
	_add_lathe(parent, "HairCap", cap, HAIR, Vector3.ZERO, Vector3.ZERO, 16)

	# 前髪（左のこめかみから右のこめかみへ、額の上をアーチでつなぐ、1本のスイープ）。
	_add_sweep(parent, "HairFringe", [
		Vector3(-0.078, Y_TEMPLE - 0.02, -0.068),
		Vector3(-0.048, Y_CHEEK + 0.050, -0.088),
		Vector3(-0.015, Y_CHEEK + 0.030, -0.095),
		Vector3(0.018, Y_CHEEK + 0.038, -0.093),
		Vector3(0.050, Y_CHEEK + 0.055, -0.086),
		Vector3(0.080, Y_TEMPLE - 0.02, -0.066),
	], [0.020, 0.030, 0.032, 0.032, 0.030, 0.020], HAIR, 7)
	# 分け目の、少し長く流れる房（絵の特徴である、片側へ寄った房）。
	_add_sweep(parent, "HairSweep", [
		Vector3(0.020, Y_CROWN + 0.01, -0.072),
		Vector3(0.058, Y_TEMPLE + 0.01, -0.082),
		Vector3(0.082, Y_CHEEK + 0.015, -0.078),
		Vector3(0.088, Y_CHEEK - 0.040, -0.064),
	], [0.026, 0.024, 0.018, 0.0], HAIR, 7)

	# 横の房（左右対称。耳の上から、肩の少し下まで）。
	for side: float in [-1.0, 1.0]:
		var tag := "Left" if side < 0.0 else "Right"
		_add_sweep(parent, "HairSide%s" % tag, [
			Vector3(side * 0.100, Y_TEMPLE - 0.01, -0.010),
			Vector3(side * 0.118, Y_CHEEK - 0.02, -0.015),
			Vector3(side * 0.112, Y_CHIN - 0.06, -0.005),
			Vector3(side * 0.092, Y_CHIN - 0.18, 0.010),
			Vector3(side * 0.070, Y_CHIN - 0.27, 0.020),
		], [0.028, 0.026, 0.022, 0.016, 0.0], HAIR, 7)

	# 後ろ髪（うなじまで垂れる、ひとつながりの房。前からは見えない）。
	_add_sweep(parent, "HairBack", [
		Vector3(0.0, Y_TEMPLE + 0.02, 0.098),
		Vector3(0.0, Y_CHEEK - 0.03, 0.112),
		Vector3(0.0, Y_CHIN - 0.08, 0.100),
		Vector3(0.0, Y_CHIN - 0.22, 0.078),
	], [0.046, 0.044, 0.034, 0.0], HAIR_DARK, 7)


static func _add_face(parent: Node3D) -> void:
	var eye_x := 0.044
	var eye_y := Y_CHEEK + 0.012
	var eye_z := -FACE_RADIUS - 0.002
	for side: float in [-1.0, 1.0]:
		var tag := "Left" if side < 0.0 else "Right"
		var ex := side * eye_x
		var center := Vector3(ex, eye_y, eye_z)
		_add_disc(parent, "Eye%s" % tag, center, Vector3.BACK, Vector3.UP, 0.026, 0.030, WHITE, 10)
		_add_disc(parent, "Iris%s" % tag, center + Vector3(0.0, -0.002, -0.004), Vector3.BACK, Vector3.UP, 0.015, 0.019, Color("#b23f73"), 10)
		_add_disc(parent, "Pupil%s" % tag, center + Vector3(0.0, -0.004, -0.007), Vector3.BACK, Vector3.UP, 0.0065, 0.0095, DARK, 8)
		_add_disc(parent, "Highlight%s" % tag, center + Vector3(side * 0.006, 0.007, -0.009), Vector3.BACK, Vector3.UP, 0.004, 0.005, WHITE, 6)
		_add_disc(parent, "Brow%s" % tag, center + Vector3(0.0, 0.028, 0.012), Vector3.BACK, Vector3.UP, 0.024, 0.006, BROW, 6)
	_add_disc(parent, "Mouth", Vector3(0.0, Y_CHIN + 0.025, -FACE_RADIUS + 0.001), Vector3.BACK, Vector3.UP, 0.017, 0.0055, Color("#c9607f"), 8)
	for side: float in [-1.0, 1.0]:
		_add_disc(parent, "Blush%s" % ("Left" if side < 0.0 else "Right"), Vector3(side * 0.066, Y_CHEEK - 0.012, -FACE_RADIUS + 0.008), Vector3.BACK, Vector3.UP, 0.018, 0.012, Color("#f4a8a0", 0.55), 8)


# ---------------------------------------------------------------- 小道具（頂点・三角形を自分で組み立てる）

## +Y を dir に向けた、正規直交の向き（基底）を作る。dir だけから一意に決まるように、
## 参照軸（だいたい奥向き）を1つ決め、それと dir の外積から横軸を作る。
static func _basis_with_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var reference := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## 通り道（points）に沿って、太さ（radii。points と同じ数）を変えながら押し出した、1本のつながった形。
## 両端は、半径0の点で閉じれば、とがって終わる。閉じない場合は、底を多角形でふさぐ。
static func _add_sweep(parent: Node3D, name: String, points: Array, radii: Array, color: Color, sides: int = 8) -> void:
	_add_mesh(parent, name, _sweep_mesh(points, radii, sides), _material(color), Vector3.ZERO)


static func _sweep_mesh(points: Array, radii: Array, sides: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := points.size()
	for i in count:
		var point: Vector3 = points[i]
		var radius: float = radii[i]
		var tangent: Vector3
		if i == 0:
			tangent = ((points[1] as Vector3) - point).normalized()
		elif i == count - 1:
			tangent = (point - (points[i - 1] as Vector3)).normalized()
		else:
			tangent = ((points[i + 1] as Vector3) - (points[i - 1] as Vector3)).normalized()
		var basis := _basis_with_y(tangent)
		for segment in sides:
			var angle := TAU * float(segment) / float(sides)
			var outward := basis.x * cos(angle) + basis.z * sin(angle)
			vertices.append(point + outward * radius)
			normals.append(outward)
	for ring in count - 1:
		for segment in sides:
			var a := ring * sides + segment
			var b := ring * sides + (segment + 1) % sides
			var c := (ring + 1) * sides + segment
			var d := (ring + 1) * sides + (segment + 1) % sides
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	# 端の半径が0でなければ、そこに中心点を置いて、多角形としてふさぐ。
	if float(radii[0]) > 0.001:
		_cap_ring(vertices, normals, indices, points[0], (points[1] as Vector3 - (points[0] as Vector3)).normalized() * -1.0, 0, sides, true)
	if float(radii[count - 1]) > 0.001:
		var last_ring_start := (count - 1) * sides
		var tangent_end: Vector3 = ((points[count - 1] as Vector3) - (points[count - 2] as Vector3)).normalized()
		_cap_ring(vertices, normals, indices, points[count - 1], tangent_end, last_ring_start, sides, false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 筒の端の輪（ring_start から sides 個の頂点）を、中心点との扇形の三角形でふさぐ。
static func _cap_ring(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, center: Vector3, outward: Vector3, ring_start: int, sides: int, flip: bool) -> void:
	var center_index := vertices.size()
	vertices.append(center)
	normals.append(outward)
	for segment in sides:
		var a := ring_start + segment
		var b := ring_start + (segment + 1) % sides
		if flip:
			indices.append_array(PackedInt32Array([center_index, b, a]))
		else:
			indices.append_array(PackedInt32Array([center_index, a, b]))


## 向きを決めた、平らな多角形（中心から扇に張った円板やだ円板）。目・口・宝石などに使う。
static func _add_disc(parent: Node3D, name: String, center: Vector3, face_dir: Vector3, up_hint: Vector3, radius_x: float, radius_y: float, color: Color, sides: int = 12) -> void:
	var normal := face_dir.normalized()
	var right := up_hint.cross(normal)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT.cross(normal)
	right = right.normalized()
	var up := normal.cross(right).normalized()
	var vertices := PackedVector3Array([center])
	var normals := PackedVector3Array([normal])
	for segment in sides + 1:
		var angle := TAU * float(segment) / float(sides)
		vertices.append(center + right * cos(angle) * radius_x + up * sin(angle) * radius_y)
		normals.append(normal)
	var indices := PackedInt32Array()
	for segment in sides:
		indices.append_array(PackedInt32Array([0, segment + 1, segment + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_add_mesh(parent, name, mesh, _material(color), Vector3.ZERO)


## 回転体を、position を原点に、+Y が dir を向くように置く（肩からひじ、ひじから手首など）。
static func _add_lathe_oriented(parent: Node3D, name: String, profile: PackedVector2Array, color: Color, origin: Vector3, dir: Vector3, segments: int = 10) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = _lathe_mesh(profile, segments)
	node.material_override = _material(color)
	node.transform = Transform3D(_basis_with_y(dir), origin)
	parent.add_child(node)


static func _add_lathe(parent: Node3D, name: String, profile: PackedVector2Array, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO, segments: int = 10) -> void:
	_add_mesh(parent, name, _lathe_mesh(profile, segments), _material(color), position, rotation)


## 片面だけの、平らな扇形の飾り（最初の点を扇の要にする）。
static func _add_flat_fan(parent: Node3D, name: String, points: Array, color: Color) -> void:
	var vertices := PackedVector3Array(points)
	var normals := PackedVector3Array()
	for _v in vertices:
		normals.append(Vector3(0.0, 0.08, -1.0).normalized())
	var indices := PackedInt32Array()
	for i in range(1, vertices.size() - 1):
		indices.append_array(PackedInt32Array([0, i, i + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, name, mesh, material, Vector3.ZERO)


static func _add_mesh(parent: Node3D, name: String, mesh: Mesh, material: Material, position: Vector3, rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation = rotation
	node.scale = scale
	parent.add_child(node)
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	material.metallic_specular = 0.25
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## 回転体（断面 profile(x=半径, y=高さ) を、y軸のまわりに回した形）。頂点・法線・三角形を直接組み立てる。
static func _lathe_mesh(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var ring_size := segments + 1
	for ring in profile.size():
		var radius := profile[ring].x
		var height := profile[ring].y
		var before := profile[maxi(ring - 1, 0)]
		var after := profile[mini(ring + 1, profile.size() - 1)]
		var slope := (after.x - before.x) / maxf(after.y - before.y, 0.001)
		for segment in ring_size:
			var angle := TAU * float(segment) / float(segments)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			vertices.append(radial * radius + Vector3.UP * height)
			normals.append((radial - Vector3.UP * slope).normalized())
	for ring in profile.size() - 1:
		for segment in segments:
			var a := ring * ring_size + segment
			var b := a + 1
			var c := (ring + 1) * ring_size + segment
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _shoe_mesh(mirrored: bool) -> ArrayMesh:
	var side := -1.0 if mirrored else 1.0
	var vertices := PackedVector3Array([
		Vector3(-0.030, 0.00, -0.055), Vector3(0.030, 0.00, -0.055), Vector3(-0.026, 0.00, 0.050), Vector3(0.026, 0.00, 0.050),
		Vector3(-0.024, 0.025, -0.045), Vector3(0.024, 0.025, -0.045), Vector3(-0.019, 0.034, 0.018), Vector3(0.019, 0.034, 0.018),
		Vector3(0.010 * side, 0.050, 0.044), Vector3(-0.010 * side, 0.050, 0.044),
	])
	var indices := PackedInt32Array([
		0, 2, 1, 1, 2, 3, 0, 1, 4, 1, 5, 4, 1, 3, 5, 3, 7, 5,
		3, 2, 7, 2, 6, 7, 2, 0, 6, 0, 4, 6, 4, 5, 6, 5, 7, 6,
		2, 8, 3, 2, 9, 8,
	])
	var normals := PackedVector3Array()
	for vertex in vertices:
		normals.append(Vector3(vertex.x, 0.45, vertex.z).normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
