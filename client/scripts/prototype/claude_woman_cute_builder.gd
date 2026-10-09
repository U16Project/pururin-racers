extends RefCounted
## レース本編には接続しない、成人女性の「ぷるりん風のかわいさ」を取り入れた試作。
## ぷるりんの見た目（client/scripts/presentation/pururin_body_builder.gd）が可愛く見える理由は、
## 1) どの部品にも濃い色の輪郭線（裏向きだけ描く、少し膨らませた同じ形）を付けていること、
## 2) つやのある塗り（粗さを低くして、ふちを白く光らせる）を使っていること。
## この2つを、同じやり方でそのまま借りる。顔は、丸い目・頬・口だけの簡単なものにする。
## 体（脚・スカート・胴・首・頭・腕）は、断面を軸まわりに回した回転体。髪は、通り道に沿って
## 太さを変えた押し出し。どちらも、Godotの球・円柱などの部品は使わない。
## 高さは実物大（約1.7m）。足元が原点、正面はマイナスZ（レース場の他の部品と同じ向き）。

const SKIN := Color("#ffd9bd")
const HAIR := Color("#3d6fe0")
const HAIR_DARK := Color("#2d54bd")
const DRESS := Color("#ffffff")
const ACCENT := Color("#2bc9bd")
const TIGHTS := Color("#9a7ef0")
const SHOE := Color("#ff7fc8")
const IRIS := Color("#d94f84")
const BLUSH := Color("#ff9fb0", 0.6)
const MOUTH := Color("#c9476f")
## 輪郭線の色と、輪郭線の太さ（部位の大きさに合わせて、2段階で使い分ける）。
const OUTLINE_COLOR := Color("#20233a")
const OUTLINE_WIDE := 0.0075
const OUTLINE_THIN := 0.004

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
const Y_CHEEK := 1.55
const Y_TEMPLE := 1.615
const Y_CROWN := 1.675
const Y_HAIR_TOP := 1.72
## 顔の正面（マイナスZ側）の半径（頭を少し大きめにして、かわいい比率にする）。
const FACE_RADIUS := 0.100

## ぷるりんと同じ、裏向きだけ描いて膨らませる輪郭線シェーダー（pururin_body_builder.gd の OUTLINE_SHADER と同じ仕組み）。
const OUTLINE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.1, 0.1, 0.2, 1.0);
uniform float outline_width = 0.006;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""

static var _outline_shader: Shader


static func build() -> Node3D:
	var woman := Node3D.new()
	woman.name = "ClaudeWomanCute"
	woman.set_meta("prototype_only", true)

	_add_legs(woman)
	_add_shoes(woman)
	_add_skirt(woman)
	_add_torso(woman)
	_add_neck(woman)
	_add_arms(woman)
	_add_head(woman)
	_add_hair(woman)
	_add_face(woman)
	return woman


# ---------------------------------------------------------------- 脚・くつ

static func _add_legs(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.052, Y_ANKLE), Vector2(0.064, Y_CALF), Vector2(0.072, Y_CALF + 0.07),
		Vector2(0.062, Y_KNEE), Vector2(0.070, Y_THIGH), Vector2(0.080, Y_THIGH + 0.10),
		Vector2(0.090, Y_HIP_JOINT),
	])
	for side: float in [-1.0, 1.0]:
		_add_lathe(parent, "Leg%s" % ("Left" if side < 0.0 else "Right"), profile, TIGHTS,
			Vector3(side * 0.088, 0.0, 0.0), Vector3(0.0, 0.0, deg_to_rad(side * 1.5)), 10, OUTLINE_THIN)


static func _add_shoes(parent: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_add_pair(parent, "Shoe%s" % ("Left" if side < 0.0 else "Right"), _shoe_mesh(side > 0.0), SHOE,
			Transform3D(Basis.IDENTITY, Vector3(side * 0.088, Y_SOLE, -0.015)), OUTLINE_THIN)


# ---------------------------------------------------------------- 胴・スカート・首

static func _add_skirt(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.118, Y_WAIST), Vector2(0.155, Y_WAIST - 0.05), Vector2(0.170, Y_SKIRT_HIP),
		Vector2(0.160, Y_SKIRT_HIP - 0.14), Vector2(0.152, Y_SKIRT_HEM + 0.05), Vector2(0.155, Y_SKIRT_HEM),
	])
	_add_lathe(parent, "Skirt", profile, ACCENT, Vector3.ZERO, Vector3.ZERO, 12, OUTLINE_WIDE)
	var band := PackedVector2Array([
		Vector2(0.162, Y_SKIRT_HIP + 0.045), Vector2(0.172, Y_SKIRT_HIP), Vector2(0.162, Y_SKIRT_HIP - 0.07),
	])
	_add_lathe(parent, "WaistBand", band, DRESS, Vector3.ZERO, Vector3.ZERO, 12, 0.0)


static func _add_torso(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.120, Y_WAIST), Vector2(0.140, Y_WAIST + 0.09), Vector2(0.158, Y_BUST),
		Vector2(0.152, Y_BUST + 0.045), Vector2(0.140, Y_SHOULDER - 0.02), Vector2(0.097, Y_SHOULDER),
	])
	_add_lathe(parent, "Torso", profile, DRESS, Vector3.ZERO, Vector3.ZERO, 12, OUTLINE_WIDE)
	_add_flat_fan(parent, "ChestPanel", [
		Vector3(0.0, Y_BUST - 0.03, -0.156),
		Vector3(-0.028, Y_SHOULDER - 0.01, -0.151), Vector3(-0.022, Y_BUST - 0.10, -0.151),
		Vector3(0.022, Y_BUST - 0.10, -0.151), Vector3(0.028, Y_SHOULDER - 0.01, -0.151),
	], ACCENT)


static func _add_neck(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.046, Y_SHOULDER), Vector2(0.052, Y_SHOULDER + 0.04), Vector2(0.050, Y_NECK_TOP),
		Vector2(0.052, Y_CHIN),
	])
	_add_lathe(parent, "Neck", profile, SKIN, Vector3.ZERO, Vector3.ZERO, 10, 0.0)


# ---------------------------------------------------------------- 腕

## 腕は曲げず、肩からまっすぐ下ろし、先を丸く閉じる（かんたんな立ち姿で十分かわいく見える）。
static func _add_arms(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.048, 0.0), Vector2(0.052, 0.05), Vector2(0.042, 0.42),
		Vector2(0.032, 0.58), Vector2(0.020, 0.64), Vector2(0.0, 0.66),
	])
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.165, Y_SHOULDER - 0.01, -0.005)
		var dir := Vector3(side * 0.05, -1.0, 0.0).normalized()
		_add_lathe_oriented(parent, "Arm%s" % ("Left" if side < 0.0 else "Right"), profile, SKIN, shoulder, dir, 8, OUTLINE_THIN)


# ---------------------------------------------------------------- 頭・髪・顔

static func _add_head(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.052, Y_CHIN), Vector2(0.082, Y_CHIN + 0.028), Vector2(FACE_RADIUS, Y_CHEEK),
		Vector2(0.096, Y_TEMPLE), Vector2(0.070, Y_CROWN), Vector2(0.030, Y_CROWN + 0.03),
		Vector2(0.0, Y_HAIR_TOP - 0.05),
	])
	_add_lathe(parent, "Head", profile, SKIN, Vector3.ZERO, Vector3.ZERO, 16, OUTLINE_WIDE)


## 髪は、頭を覆う丸い帽子に、額のアーチと、横の房を2本だけ重ねる（簡単だが、丸みでかわいく見える）。
static func _add_hair(parent: Node3D) -> void:
	var cap := PackedVector2Array([
		Vector2(0.090, Y_CHEEK - 0.01), Vector2(0.106, Y_TEMPLE - 0.01), Vector2(0.115, Y_TEMPLE + 0.03),
		Vector2(0.118, Y_CROWN - 0.01), Vector2(0.100, Y_CROWN + 0.03), Vector2(0.058, Y_HAIR_TOP - 0.015),
		Vector2(0.0, Y_HAIR_TOP + 0.02),
	])
	_add_lathe(parent, "HairCap", cap, HAIR, Vector3.ZERO, Vector3.ZERO, 16, OUTLINE_WIDE)

	_add_sweep(parent, "HairFringe", [
		Vector3(-0.082, Y_TEMPLE - 0.01, -0.072),
		Vector3(-0.050, Y_CHEEK + 0.055, -0.094),
		Vector3(-0.016, Y_CHEEK + 0.035, -0.101),
		Vector3(0.018, Y_CHEEK + 0.042, -0.099),
		Vector3(0.052, Y_CHEEK + 0.058, -0.092),
		Vector3(0.084, Y_TEMPLE - 0.01, -0.070),
	], [0.022, 0.032, 0.034, 0.034, 0.032, 0.022], HAIR, 8, OUTLINE_THIN)

	for side: float in [-1.0, 1.0]:
		var tag := "Left" if side < 0.0 else "Right"
		_add_sweep(parent, "HairSide%s" % tag, [
			Vector3(side * 0.106, Y_TEMPLE - 0.005, -0.010),
			Vector3(side * 0.124, Y_CHEEK - 0.02, -0.015),
			Vector3(side * 0.116, Y_CHIN - 0.06, -0.005),
			Vector3(side * 0.094, Y_CHIN - 0.18, 0.010),
			Vector3(side * 0.070, Y_CHIN - 0.27, 0.020),
		], [0.030, 0.028, 0.023, 0.016, 0.0], HAIR_DARK, 8, OUTLINE_THIN)


## ぷるりんと同じ考え方で、目は「白目＋大きいいろめ＋小さいハイライト」の3枚だけ。輪郭線は付けない
## （ぷるりんの顔も、体の輪郭線だけで、顔のパーツには付けていない）。
static func _add_face(parent: Node3D) -> void:
	var eye_x := 0.046
	var eye_y := Y_CHEEK + 0.018
	var eye_z := -FACE_RADIUS - 0.002
	for side: float in [-1.0, 1.0]:
		var tag := "Left" if side < 0.0 else "Right"
		var center := Vector3(side * eye_x, eye_y, eye_z)
		_add_disc(parent, "Eye%s" % tag, center, Vector3.BACK, Vector3.UP, 0.030, 0.034, DRESS)
		_add_disc(parent, "Iris%s" % tag, center + Vector3(0.0, -0.003, -0.005), Vector3.BACK, Vector3.UP, 0.021, 0.025, IRIS)
		_add_disc(parent, "Pupil%s" % tag, center + Vector3(0.0, -0.005, -0.008), Vector3.BACK, Vector3.UP, 0.008, 0.010, OUTLINE_COLOR)
		_add_disc(parent, "Highlight%s" % tag, center + Vector3(side * 0.008, 0.009, -0.010), Vector3.BACK, Vector3.UP, 0.006, 0.007, DRESS)
	_add_disc(parent, "Mouth", Vector3(0.0, Y_CHIN + 0.028, -FACE_RADIUS + 0.004), Vector3.BACK, Vector3.UP, 0.016, 0.008, MOUTH, 8)
	for side: float in [-1.0, 1.0]:
		_add_disc(parent, "Blush%s" % ("Left" if side < 0.0 else "Right"), Vector3(side * 0.070, Y_CHEEK - 0.010, -FACE_RADIUS + 0.014), Vector3.BACK, Vector3.UP, 0.020, 0.013, BLUSH, 8)


# ---------------------------------------------------------------- 小道具（頂点・三角形を自分で組み立てる）

static func _basis_with_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var reference := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _add_sweep(parent: Node3D, name: String, points: Array, radii: Array, color: Color, sides: int = 8, outline_width: float = OUTLINE_THIN) -> void:
	_add_pair(parent, name, _sweep_mesh(points, radii, sides), color, Transform3D.IDENTITY, outline_width)


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
	if float(radii[0]) > 0.001:
		_cap_ring(vertices, normals, indices, points[0], 0, sides, true)
	if float(radii[count - 1]) > 0.001:
		_cap_ring(vertices, normals, indices, points[count - 1], (count - 1) * sides, sides, false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _cap_ring(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, center: Vector3, ring_start: int, sides: int, flip: bool) -> void:
	var center_index := vertices.size()
	vertices.append(center)
	normals.append(Vector3.UP)
	for segment in sides:
		var a := ring_start + segment
		var b := ring_start + (segment + 1) % sides
		if flip:
			indices.append_array(PackedInt32Array([center_index, b, a]))
		else:
			indices.append_array(PackedInt32Array([center_index, a, b]))


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
	_add_mesh(parent, name, mesh, _fill_material(color), Transform3D(Basis.IDENTITY, Vector3.ZERO))


static func _add_lathe_oriented(parent: Node3D, name: String, profile: PackedVector2Array, color: Color, origin: Vector3, dir: Vector3, segments: int = 10, outline_width: float = OUTLINE_THIN) -> void:
	_add_pair(parent, name, _lathe_mesh(profile, segments), color, Transform3D(_basis_with_y(dir), origin), outline_width)


static func _add_lathe(parent: Node3D, name: String, profile: PackedVector2Array, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO, segments: int = 10, outline_width: float = OUTLINE_THIN) -> void:
	_add_pair(parent, name, _lathe_mesh(profile, segments), color, Transform3D(Basis.from_euler(rotation), position), outline_width)


## 片面だけの、平らな扇形の飾り（最初の点を扇の要にする。輪郭線は付けない小さい飾り）。
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
	var material := _fill_material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, name, mesh, material, Transform3D(Basis.IDENTITY, Vector3.ZERO))


## 色を塗った本体と、その裏向き・少し膨らませた輪郭線を、同じ場所に重ねて置く
## （ぷるりんの体と同じ仕組み。outline_width が0なら、輪郭線は付けない）。
static func _add_pair(parent: Node3D, name: String, mesh: ArrayMesh, color: Color, transform: Transform3D, outline_width: float) -> void:
	_add_mesh(parent, name, mesh, _fill_material(color), transform)
	if outline_width > 0.0:
		_add_mesh(parent, name + "Outline", mesh, _outline_material(outline_width), transform)


static func _add_mesh(parent: Node3D, name: String, mesh: Mesh, material: Material, transform: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.transform = transform
	parent.add_child(node)
	return node


## ぷるりんと同じ、つやのある塗り（粗さを低く、ふちをうっすら光らせる）。
static func _fill_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.22
	material.metallic_specular = 0.55
	material.rim_enabled = true
	material.rim = 0.28
	material.rim_tint = 0.35
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _outline_material(width: float) -> ShaderMaterial:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _outline_shader
	material.set_shader_parameter("outline_color", OUTLINE_COLOR)
	material.set_shader_parameter("outline_width", width)
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
		Vector3(-0.032, 0.00, -0.058), Vector3(0.032, 0.00, -0.058), Vector3(-0.028, 0.00, 0.052), Vector3(0.028, 0.00, 0.052),
		Vector3(-0.026, 0.026, -0.047), Vector3(0.026, 0.026, -0.047), Vector3(-0.020, 0.036, 0.019), Vector3(0.020, 0.036, 0.019),
		Vector3(0.011 * side, 0.052, 0.046), Vector3(-0.011 * side, 0.052, 0.046),
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
