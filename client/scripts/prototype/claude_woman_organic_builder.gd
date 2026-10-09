extends RefCounted
## レース本編には接続しない、成人女性の試作（3回目のやり直し）。
## ぷるりんの、ひれ・葉っぱ・炎の作り方（client/scripts/presentation/pururin_parts/body_parts.gd の
## _add_tube・_add_flame_tongue・_add_leaf_blade）を、同じやり方でそのまま借りる。
## 要点は2つ。1) 太さは、数点を直線でつながず、なめらかな式（smoothstep）で変える。
## 2) 断面は、まん丸ではなく、前後を少しつぶした楕円にする（depth_ratio）。
## これで、「輪切りの段差が目立つマネキン」ではなく、ゆるい丸みの形になる。
## 髪の横の房は、葉っぱと同じ、曲がって先が細くなる「1枚のつぶした筒」として作る。
## 高さは実物大（約1.7m）。足元が原点、正面はマイナスZ（レース場の他の部品と同じ向き）。

const SKIN := Color("#ffd9bd")
const HAIR := Color("#3d6fe0")
const HAIR_DARK := Color("#2d54bd")
const DRESS := Color("#ffffff")
const ACCENT := Color("#2bc9bd")
const TIGHTS := Color("#9a7ef0")
const SHOE := Color("#ff7fc8")
const IRIS := Color("#d94f84")
const BLUSH := Color("#ff9fb0")
const MOUTH := Color("#c9476f")

## 輪切り1つぶんの点の数（ぷるりんの部品と同じ、20）。
const AROUND := 20


static func build() -> Node3D:
	var woman := Node3D.new()
	woman.name = "ClaudeWomanOrganic"
	woman.set_meta("prototype_only", true)

	_add_legs(woman)
	_add_shoes(woman)
	_add_lower_body(woman)
	_add_arms(woman)
	_add_head(woman)
	_add_hair(woman)
	_add_face(woman)
	return woman


# ---------------------------------------------------------------- 脚・くつ

## 足首→ふくらはぎ→ひざ→ももの、なめらかな太さの変化。t は 0（足首）〜1（腰のつけ根）。
static func _leg_radius(t: float) -> float:
	var ankle_to_calf := _smooth_lerp(0.050, 0.070, _ease(t, 0.0, 0.16))
	var calf_to_knee := _smooth_lerp(0.070, 0.058, _ease(t, 0.16, 0.40))
	var knee_to_thigh := _smooth_lerp(0.058, 0.082, _ease(t, 0.40, 0.70))
	var thigh_to_hip := _smooth_lerp(0.082, 0.092, _ease(t, 0.70, 1.0))
	return ankle_to_calf + calf_to_knee - 0.070 + knee_to_thigh - 0.058 + thigh_to_hip - 0.082


static func _add_legs(parent: Node3D) -> void:
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		centers.append(Vector3(0.0, lerpf(0.09, 0.84, t), 0.0))
		radii.append(_leg_radius(t))
	for side: float in [-1.0, 1.0]:
		var xform := Transform3D(Basis(Vector3.BACK, deg_to_rad(side * 1.2)), Vector3(side * 0.088, 0.0, 0.0))
		_add_tube(parent, "Leg%s" % ("Left" if side < 0.0 else "Right"), centers, radii, 0.82, TIGHTS, xform, true)


static func _add_shoes(parent: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_add_mesh(parent, "Shoe%s" % ("Left" if side < 0.0 else "Right"), _shoe_mesh(side > 0.0), _material(SHOE),
			Transform3D(Basis.IDENTITY, Vector3(side * 0.088, 0.0, -0.015)))


# ---------------------------------------------------------------- 胴（スカートから肩まで、ひとつながり）

## スカートの裾(t=0)から、肩(t=1)までの、なめらかな太さの変化。くびれを1つ作る（腰のあたり）。
static func _torso_radius(t: float) -> float:
	var hem_to_hip := _smooth_lerp(0.155, 0.170, _ease(t, 0.0, 0.22))
	var hip_to_waist := _smooth_lerp(0.170, 0.118, _ease(t, 0.22, 0.46))
	var waist_to_bust := _smooth_lerp(0.118, 0.158, _ease(t, 0.46, 0.74))
	var bust_to_shoulder := _smooth_lerp(0.158, 0.097, _ease(t, 0.74, 1.0))
	return hem_to_hip + hip_to_waist - 0.170 + waist_to_bust - 0.118 + bust_to_shoulder - 0.158


## 0=裾（スカートの下）、1=肩の、高さに直す。
static func _torso_height(t: float) -> float:
	return lerpf(0.58, 1.37, t)


## スカートから肩までを、ひとつの色（服の色）でつなぐ。装飾は付けない、単純な「人形」の体。
static func _add_lower_body(parent: Node3D) -> void:
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 30
	for i in steps + 1:
		var t := float(i) / float(steps)
		centers.append(Vector3(0.0, _torso_height(t), 0.0))
		radii.append(_torso_radius(t))
	_add_tube(parent, "Body", centers, radii, 0.80, DRESS, Transform3D.IDENTITY, true)
	# 首（短い、まっすぐの筒）。
	var neck_centers: Array[Vector3] = [Vector3(0.0, 1.36, 0.0), Vector3(0.0, 1.41, 0.0), Vector3(0.0, 1.47, 0.0)]
	var neck_radii: Array[float] = [0.044, 0.050, 0.052]
	_add_tube(parent, "Neck", neck_centers, neck_radii, 0.85, SKIN, Transform3D.IDENTITY, false)


# ---------------------------------------------------------------- 腕

## ぷるりんの「水の突起」と同じ式（根元から、曲がりながら伸びて、先がすぼまる）。
static func _add_arms(parent: Node3D) -> void:
	var steps := 22
	for side: float in [-1.0, 1.0]:
		var centers: Array[Vector3] = []
		var radii: Array[float] = []
		for i in steps + 1:
			var t := float(i) / float(steps)
			# 肩から、少し外へ曲がりながら下りる（lean）。
			centers.append(Vector3(side * 0.10 * t * t, -0.66 * sin(t * PI * 0.5), 0.02 * sin(t * PI)))
			var upper := _smooth_lerp(0.050, 0.044, _ease(t, 0.0, 0.55))
			var taper := _smooth_lerp(0.044, 0.0, _ease(t, 0.55, 1.0))
			radii.append(upper + taper - 0.044)
		var xform := Transform3D(Basis.IDENTITY, Vector3(side * 0.165, 1.36, -0.005))
		_add_tube(parent, "Arm%s" % ("Left" if side < 0.0 else "Right"), centers, radii, 0.85, SKIN, xform, true)


# ---------------------------------------------------------------- 頭

static func _head_radius(t: float) -> float:
	var chin_to_jaw := _smooth_lerp(0.050, 0.082, _ease(t, 0.0, 0.14))
	var jaw_to_cheek := _smooth_lerp(0.082, 0.100, _ease(t, 0.14, 0.34))
	var cheek_to_temple := _smooth_lerp(0.100, 0.096, _ease(t, 0.34, 0.55))
	var temple_to_crown := _smooth_lerp(0.096, 0.0, _ease(t, 0.55, 1.0))
	return chin_to_jaw + jaw_to_cheek - 0.082 + cheek_to_temple - 0.100 + temple_to_crown - 0.096


static func _add_head(parent: Node3D) -> void:
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 26
	for i in steps + 1:
		var t := float(i) / float(steps)
		centers.append(Vector3(0.0, lerpf(1.47, 1.70, t), 0.0))
		radii.append(_head_radius(t))
	_add_tube(parent, "Head", centers, radii, 0.92, SKIN, Transform3D.IDENTITY, false)


# ---------------------------------------------------------------- 髪

## 頭をおおう、丸い帽子ひとつだけ（房は作らない）。目より上（y=1.59あたり）から始めて、
## 顔には絶対にかからないようにする。最初のバグは、この開始の高さが低すぎて、
## 顔ごとおおう「ずきん」になっていたこと。
static func _hair_cap_radius(t: float) -> float:
	var grow := _smooth_lerp(0.0, 0.106, _ease(t, 0.0, 0.22))
	var hold := _smooth_lerp(0.106, 0.108, _ease(t, 0.22, 0.55))
	var shrink := _smooth_lerp(0.108, 0.0, _ease(t, 0.55, 1.0))
	return grow + hold - 0.106 + shrink - 0.108


## 帽子の、いちばん下（前の縁）の高さ。目の高さ（1.565あたり）より、はっきり上にする。
const HAIR_CAP_BOTTOM_Y := 1.595
const HAIR_CAP_TOP_Y := 1.705


static func _add_hair(parent: Node3D) -> void:
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		centers.append(Vector3(0.0, lerpf(HAIR_CAP_BOTTOM_Y, HAIR_CAP_TOP_Y, t), 0.0))
		radii.append(_hair_cap_radius(t))
	_add_tube(parent, "HairCap", centers, radii, 0.95, HAIR, Transform3D.IDENTITY, false)


## 葉っぱ1枚（pururinの _add_leaf_blade と同じ式）。付け根が細く、まん中が広く、先がとがって曲がる。
static func _add_leaf_blade(parent: Node3D, name: String, length: float, width: float, bend: float, color: Color, xform: Transform3D) -> void:
	var steps := 18
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		centers.append(Vector3(bend * t * t, -length * t, 0.0))
		radii.append(maxf(width * sin(PI * pow(t, 0.7)), width * 0.1 * (1.0 - t)))
	_add_tube(parent, name, centers, radii, 0.3, color, xform, true)


# ---------------------------------------------------------------- 顔（板を重ねず、1枚の絵をテクスチャとして貼る）

## 顔の絵の大きさ（m）と、頭に貼る場所（中心の高さ・前への出っぱり）。
const FACE_PLANE_SIZE := Vector2(0.22, 0.145)
const FACE_PLANE_CENTER_Y := 1.555
const FACE_PLANE_Z := -0.100
## 絵の解像度（ピクセル）。
const FACE_TEXTURE_SIZE := Vector2i(352, 232)


static func _add_face(parent: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = FACE_PLANE_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_texture = _face_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.4
	_add_mesh(parent, "Face", quad, material, Transform3D(Basis.IDENTITY, Vector3(0.0, FACE_PLANE_CENTER_Y, FACE_PLANE_Z)))


## 顔の絵（目2つ・口・ほお）を、1枚の透明な画像として、1ピクセルずつ描く。
static func _face_texture() -> ImageTexture:
	var w := FACE_TEXTURE_SIZE.x
	var h := FACE_TEXTURE_SIZE.y
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var eye_centers := [Vector2(w * 0.375, h * 0.44), Vector2(w * 0.625, h * 0.44)]
	var mouth_center := Vector2(w * 0.5, h * 0.70)
	var blush_centers := [Vector2(w * 0.175, h * 0.58), Vector2(w * 0.825, h * 0.58)]
	var white := Color("#ffffff")
	var iris := IRIS
	var pupil := Color("#231c33")
	var mouth := MOUTH
	var blush := Color(BLUSH, 0.55)
	for y in h:
		for x in w:
			var here := Vector2(x, y)
			var pixel := Color(0.0, 0.0, 0.0, 0.0)
			for eye: Vector2 in eye_centers:
				var local := (here - eye) / Vector2(30.0, 33.0)
				var dist := local.length()
				if dist < 1.0:
					pixel = white
					var iris_local := (here - eye - Vector2(0.0, 4.0)) / Vector2(21.0, 24.0)
					if iris_local.length() < 1.0:
						pixel = iris
						var pupil_local := (here - eye - Vector2(0.0, 7.0)) / Vector2(9.0, 10.5)
						if pupil_local.length() < 1.0:
							pixel = pupil
						var shine_local := (here - eye - Vector2(7.0, -9.0)) / Vector2(6.0, 7.0)
						if shine_local.length() < 1.0:
							pixel = white
			var mouth_local := (here - mouth_center) / Vector2(26.0, 13.0)
			if mouth_local.length() < 1.0 and pixel.a < 0.5:
				pixel = mouth
			for cheek: Vector2 in blush_centers:
				var cheek_local := (here - cheek) / Vector2(32.0, 21.0)
				if cheek_local.length() < 1.0 and pixel.a < 0.5:
					pixel = blush
			image.set_pixel(x, y, pixel)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------- 小道具（曲線・断面づくり。pururinの body_parts.gd と同じ構造）

## key1→key2 のあいだを、滑らかに（start, end）へ繋ぐための、0〜1のなめらかな進み具合。
static func _ease(t: float, start: float, end: float) -> float:
	if end <= start:
		return 1.0 if t >= end else 0.0
	return smoothstep(start, end, t)


## 2つの値を、0〜1の進み具合（すでになめらかな値）で混ぜる。
static func _smooth_lerp(from_value: float, to_value: float, eased: float) -> float:
	return lerpf(from_value, to_value, eased)


## +Y を dir に向けた、正規直交の向き（基底）。
static func _basis_with_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var reference := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## 背骨（centers）に沿って、楕円の輪切り（radii）を並べた形。depth_ratio は、奥行き（前後）の、横に対する比
## （1.0で真円、小さいほど前後がつぶれた、ひれ・葉っぱのような形になる）。colors は、輪ごとの色（省略なら単色）。
## cap_ends が true で、両端の半径が0でなければ、先を平らな多角形で閉じる。
static func _add_tube(parent: Node3D, name: String, centers: Array, radii: Array, depth_ratio: float, color: Color, xform: Transform3D, cap_ends: bool, colors: Array = []) -> void:
	var count := centers.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var vcolors := PackedColorArray()
	var use_colors := not colors.is_empty()
	for i in count:
		var point: Vector3 = centers[i]
		var radius: float = radii[i]
		var tangent: Vector3
		if i == 0:
			tangent = ((centers[1] as Vector3) - point).normalized()
		elif i == count - 1:
			tangent = (point - (centers[i - 1] as Vector3)).normalized()
		else:
			tangent = ((centers[i + 1] as Vector3) - (centers[i - 1] as Vector3)).normalized()
		var basis := _basis_with_y(tangent)
		for segment in AROUND:
			var angle := TAU * float(segment) / float(AROUND)
			var outward := basis.x * cos(angle) + basis.z * sin(angle) * depth_ratio
			vertices.append(point + outward * radius)
			normals.append((basis.x * cos(angle) + basis.z * sin(angle) / depth_ratio).normalized())
			var picked: Color = colors[i] if use_colors else color
			vcolors.append(picked.srgb_to_linear())
	var indices := PackedInt32Array()
	for ring in count - 1:
		for segment in AROUND:
			var a := ring * AROUND + segment
			var b := ring * AROUND + (segment + 1) % AROUND
			var c := (ring + 1) * AROUND + segment
			var d := (ring + 1) * AROUND + (segment + 1) % AROUND
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	if cap_ends and float(radii[0]) > 0.0015:
		_cap_ring(vertices, normals, vcolors, indices, centers[0], -( (centers[1] as Vector3) - (centers[0] as Vector3) ).normalized(), 0, (color if not use_colors else colors[0]).srgb_to_linear(), true)
	if cap_ends and float(radii[count - 1]) > 0.0015:
		var last_tangent: Vector3 = ((centers[count - 1] as Vector3) - (centers[count - 2] as Vector3)).normalized()
		_cap_ring(vertices, normals, vcolors, indices, centers[count - 1], last_tangent, (count - 1) * AROUND, (color if not use_colors else colors[count - 1]).srgb_to_linear(), false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vcolors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	_add_mesh(parent, name, mesh, material, xform)


static func _cap_ring(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, center: Vector3, outward: Vector3, ring_start: int, color: Color, flip: bool) -> void:
	var center_index := vertices.size()
	vertices.append(center)
	normals.append(outward)
	colors.append(color)
	for segment in AROUND:
		var a := ring_start + segment
		var b := ring_start + (segment + 1) % AROUND
		if flip:
			indices.append_array(PackedInt32Array([center_index, b, a]))
		else:
			indices.append_array(PackedInt32Array([center_index, a, b]))


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
	_add_mesh(parent, name, mesh, material, Transform3D.IDENTITY)


static func _add_mesh(parent: Node3D, name: String, mesh: Mesh, material: Material, transform: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.transform = transform
	parent.add_child(node)
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28
	material.metallic_specular = 0.35
	material.rim_enabled = true
	material.rim = 0.12
	material.rim_tint = 0.4
	return material


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
