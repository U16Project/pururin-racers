extends RefCounted
## レース本編には接続しない、成人女性の「立ち姿のシルエット」試作。顔・髪の房・小物は作らず、
## 体の輪郭（脚・スカート・胴・首・頭・腕）だけを、ひとつの色で作る。
## 体は、断面(x=半径, y=高さ)を軸まわりに回した回転体（Godotの球・円柱などの部品は使わない）。
## 高さは実物大（約1.7m）。足元が原点、正面はマイナスZ（レース場の他の部品と同じ向き）。

const SILHOUETTE := Color("#283049")

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


static func build() -> Node3D:
	var woman := Node3D.new()
	woman.name = "ClaudeWomanSilhouette"
	woman.set_meta("prototype_only", true)
	var material := _material()

	_add_legs(woman, material)
	_add_skirt(woman, material)
	_add_torso(woman, material)
	_add_neck(woman, material)
	_add_arms(woman, material)
	_add_head(woman, material)
	_add_hair(woman, material)
	return woman


static func _add_legs(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.050, Y_ANKLE), Vector2(0.062, Y_CALF), Vector2(0.070, Y_CALF + 0.07),
		Vector2(0.060, Y_KNEE), Vector2(0.068, Y_THIGH), Vector2(0.078, Y_THIGH + 0.10),
		Vector2(0.088, Y_HIP_JOINT),
	])
	for side: float in [-1.0, 1.0]:
		_add_lathe(parent, "Leg%s" % ("Left" if side < 0.0 else "Right"), profile, material,
			Vector3(side * 0.085, 0.0, 0.0), Vector3(0.0, 0.0, deg_to_rad(side * 1.5)))


static func _add_skirt(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.115, Y_WAIST), Vector2(0.150, Y_WAIST - 0.05), Vector2(0.165, Y_SKIRT_HIP),
		Vector2(0.155, Y_SKIRT_HIP - 0.14), Vector2(0.148, Y_SKIRT_HEM + 0.05), Vector2(0.150, Y_SKIRT_HEM),
	])
	_add_lathe(parent, "Skirt", profile, material, Vector3.ZERO)


static func _add_torso(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.118, Y_WAIST), Vector2(0.138, Y_WAIST + 0.09), Vector2(0.155, Y_BUST),
		Vector2(0.150, Y_BUST + 0.045), Vector2(0.138, Y_SHOULDER - 0.02), Vector2(0.095, Y_SHOULDER),
	])
	_add_lathe(parent, "Torso", profile, material, Vector3.ZERO)


static func _add_neck(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.044, Y_SHOULDER), Vector2(0.050, Y_SHOULDER + 0.04), Vector2(0.048, Y_NECK_TOP),
		Vector2(0.050, Y_CHIN),
	])
	_add_lathe(parent, "Neck", profile, material, Vector3.ZERO)


## 腕は曲げず、肩からまっすぐ下ろし、先を丸く閉じる（立ち姿なので、これでシルエットとして十分読める）。
static func _add_arms(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.046, 0.0), Vector2(0.050, 0.05), Vector2(0.040, 0.42),
		Vector2(0.030, 0.58), Vector2(0.018, 0.64), Vector2(0.0, 0.66),
	])
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.160, Y_SHOULDER - 0.01, -0.005)
		# わずかに外側へ（0.03/0.66）傾けて、二の腕が胴に重ならないようにする。
		var dir := Vector3(side * 0.03, -1.0, 0.0).normalized()
		_add_lathe_oriented(parent, "Arm%s" % ("Left" if side < 0.0 else "Right"), profile, material, shoulder, dir, 8)


static func _add_head(parent: Node3D, material: Material) -> void:
	var profile := PackedVector2Array([
		Vector2(0.050, Y_CHIN), Vector2(0.078, Y_CHIN + 0.025), Vector2(0.092, Y_CHEEK),
		Vector2(0.090, Y_TEMPLE), Vector2(0.066, Y_CROWN), Vector2(0.028, Y_CROWN + 0.03),
		Vector2(0.0, Y_HAIR_TOP - 0.05),
	])
	_add_lathe(parent, "Head", profile, material, Vector3.ZERO, Vector3.ZERO, 14)


## 髪は、房に分けず、頭をまるごと覆う丸い帽子（回転体）ひとつだけにする。シルエットの輪郭だけ、
## 肩のあたりまで裾を伸ばして、簡単なロングヘアの形にする。
static func _add_hair(parent: Node3D, material: Material) -> void:
	var cap := PackedVector2Array([
		Vector2(0.080, Y_SHOULDER + 0.03), Vector2(0.095, Y_CHEEK + 0.03), Vector2(0.105, Y_TEMPLE),
		Vector2(0.112, Y_CROWN - 0.01), Vector2(0.095, Y_CROWN + 0.03), Vector2(0.055, Y_HAIR_TOP - 0.015),
		Vector2(0.0, Y_HAIR_TOP + 0.015),
	])
	_add_lathe(parent, "Hair", cap, material, Vector3.ZERO, Vector3.ZERO, 16)


# ---------------------------------------------------------------- 小道具

static func _basis_with_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var reference := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func _add_lathe_oriented(parent: Node3D, name: String, profile: PackedVector2Array, material: Material, origin: Vector3, dir: Vector3, segments: int = 10) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = _lathe_mesh(profile, segments)
	node.material_override = material
	node.transform = Transform3D(_basis_with_y(dir), origin)
	parent.add_child(node)


static func _add_lathe(parent: Node3D, name: String, profile: PackedVector2Array, material: Material, position: Vector3, rotation: Vector3 = Vector3.ZERO, segments: int = 10) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = _lathe_mesh(profile, segments)
	node.material_override = material
	node.position = position
	node.rotation = rotation
	parent.add_child(node)


static func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = SILHOUETTE
	material.roughness = 0.85
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
