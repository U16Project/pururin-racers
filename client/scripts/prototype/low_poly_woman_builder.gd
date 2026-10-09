extends RefCounted
## レース本編には接続しない、Godot 内だけで組み立てる成人女性のローポリ試作。
## 体の主要部は、円柱や箱を重ねず、輪郭を持つ回転メッシュで作る。

const SKIN := Color("#f6c6b0")
const HAIR := Color("#3155b3")
const WHITE := Color("#eaf7fb")
const TEAL := Color("#129b9b")
const PURPLE := Color("#8254d9")
const PINK := Color("#e45bcd")
const GOLD := Color("#e7ce46")
const DARK := Color("#202846")


static func build() -> Node3D:
	var woman := Node3D.new()
	woman.name = "LowPolyWoman"
	woman.set_meta("prototype_only", true)

	# 足元を原点に、頭頂まで約6.2mの、ややデフォルメした成人女性の比率にする。
	_add_lathe(woman, "LeftLeg", PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.20, 0.08), Vector2(0.18, 1.28), Vector2(0.25, 1.76), Vector2(0.20, 1.92),
	]), PURPLE, Vector3(-0.27, 0.44, 0.0), Vector3(0.0, 0.0, deg_to_rad(2.0)))
	_add_lathe(woman, "RightLeg", PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.20, 0.08), Vector2(0.18, 1.28), Vector2(0.25, 1.76), Vector2(0.20, 1.92),
	]), PURPLE, Vector3(0.27, 0.44, 0.0), Vector3(0.0, 0.0, deg_to_rad(-2.0)))
	_add_shoe(woman, "LeftShoe", Vector3(-0.27, 0.07, -0.08), false)
	_add_shoe(woman, "RightShoe", Vector3(0.27, 0.07, -0.08), true)

	# スカートは腰から裾まで広がる8角形の面。胴と別にすることで腰のくびれを残す。
	_add_lathe(woman, "Skirt", PackedVector2Array([
		Vector2(0.42, 0.0), Vector2(0.76, 0.10), Vector2(0.70, 1.05), Vector2(0.43, 1.20),
	]), Color("#65707d"), Vector3(0.0, 2.15, 0.0))
	_add_lathe(woman, "TealWaistPanel", PackedVector2Array([
		Vector2(0.38, 0.0), Vector2(0.46, 0.08), Vector2(0.42, 0.62), Vector2(0.34, 0.72),
	]), TEAL, Vector3(0.0, 3.12, -0.02))

	# 肩から腰へ絞る胴。白い前身頃と青緑の脇を、別の低ポリ面で見せる。
	_add_lathe(woman, "Torso", PackedVector2Array([
		Vector2(0.34, 0.0), Vector2(0.42, 0.12), Vector2(0.49, 0.68), Vector2(0.62, 1.20), Vector2(0.54, 1.38),
	]), WHITE, Vector3(0.0, 3.22, 0.0))
	_add_lathe(woman, "Collar", PackedVector2Array([
		Vector2(0.35, 0.0), Vector2(0.39, 0.05), Vector2(0.38, 0.28), Vector2(0.32, 0.34),
	]), WHITE, Vector3(0.0, 4.51, 0.0))
	_add_lathe(woman, "Neck", PackedVector2Array([
		Vector2(0.16, 0.0), Vector2(0.20, 0.04), Vector2(0.19, 0.30), Vector2(0.16, 0.35),
	]), SKIN, Vector3(0.0, 4.72, 0.0))
	_add_chest_gem(woman)

	_add_arm(woman, "LeftArm", Vector3(-0.64, 4.35, 0.0), 18.0)
	_add_arm(woman, "RightArm", Vector3(0.64, 4.35, 0.0), -18.0)

	_add_lathe(woman, "Head", PackedVector2Array([
		Vector2(0.16, 0.0), Vector2(0.46, 0.10), Vector2(0.64, 0.42), Vector2(0.70, 0.84), Vector2(0.61, 1.24), Vector2(0.39, 1.48), Vector2(0.12, 1.57),
	]), SKIN, Vector3(0.0, 4.98, 0.0), Vector3(0.0, deg_to_rad(-8.0), 0.0), 12)
	_add_hair(woman)
	_add_face(woman)
	return woman


static func _add_arm(parent: Node3D, name: String, position: Vector3, outward_angle_deg: float) -> void:
	var arm := Node3D.new()
	arm.name = name
	arm.position = position
	# 回転メッシュの +Y を、肩から斜め下へ向ける。左右とも肩から手袋まで連続させる。
	arm.rotation.z = deg_to_rad(180.0 - outward_angle_deg)
	parent.add_child(arm)
	_add_lathe(arm, "Upper", PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.18, 0.06), Vector2(0.16, 0.78), Vector2(0.13, 0.92),
	]), SKIN, Vector3.ZERO, Vector3.ZERO, 7)
	_add_lathe(arm, "Glove", PackedVector2Array([
		Vector2(0.10, 0.0), Vector2(0.15, 0.05), Vector2(0.15, 0.42), Vector2(0.11, 0.56),
	]), WHITE, Vector3(0.0, 0.92, 0.0), Vector3.ZERO, 7)


static func _add_hair(parent: Node3D) -> void:
	# 髪帽子と、前髪・横髪・後ろ髪を別の束にして、青い一塊に見せない。
	_add_lathe(parent, "HairCap", PackedVector2Array([
		Vector2(0.20, 0.00), Vector2(0.53, 0.08), Vector2(0.75, 0.50), Vector2(0.66, 1.06), Vector2(0.38, 1.32), Vector2(0.08, 1.38),
	]), HAIR, Vector3(0.0, 5.18, 0.05), Vector3(0.0, deg_to_rad(-8.0), 0.0), 10)
	var bangs := [
		["HairBangLeft", Vector3(-0.34, 5.57, -0.57), -13.0, 0.76],
		["HairBangCenter", Vector3(-0.08, 5.67, -0.67), -3.0, 0.82],
		["HairBangRight", Vector3(0.22, 5.62, -0.62), 10.0, 0.72],
		["HairSideLeft", Vector3(-0.67, 5.28, -0.15), 24.0, 1.05],
		["HairSideRight", Vector3(0.67, 5.30, -0.08), -25.0, 1.00],
		["HairBackLeft", Vector3(-0.47, 5.14, 0.38), 12.0, 0.95],
		["HairBackRight", Vector3(0.47, 5.14, 0.38), -12.0, 0.95],
	]
	for strand: Array in bangs:
		_add_lathe(parent, str(strand[0]), PackedVector2Array([
			Vector2(0.12, 0.0), Vector2(0.19, 0.10), Vector2(0.14, float(strand[3]) * 0.72), Vector2(0.035, float(strand[3])),
		]), HAIR, strand[1], Vector3(0.0, 0.0, deg_to_rad(float(strand[2]))), 5)


static func _add_face(parent: Node3D) -> void:
	_add_ellipsoid(parent, "LeftEye", Vector3(-0.25, 5.66, -0.63), Vector3(0.19, 0.27, 0.055), WHITE)
	_add_ellipsoid(parent, "RightEye", Vector3(0.25, 5.66, -0.63), Vector3(0.19, 0.27, 0.055), WHITE)
	_add_ellipsoid(parent, "LeftIris", Vector3(-0.25, 5.64, -0.69), Vector3(0.105, 0.15, 0.035), Color("#bd477e"))
	_add_ellipsoid(parent, "RightIris", Vector3(0.25, 5.64, -0.69), Vector3(0.105, 0.15, 0.035), Color("#bd477e"))
	_add_ellipsoid(parent, "LeftPupil", Vector3(-0.25, 5.63, -0.72), Vector3(0.046, 0.078, 0.018), DARK)
	_add_ellipsoid(parent, "RightPupil", Vector3(0.25, 5.63, -0.72), Vector3(0.046, 0.078, 0.018), DARK)
	_add_ellipsoid(parent, "Mouth", Vector3(0.0, 5.22, -0.68), Vector3(0.16, 0.045, 0.022), PINK)


static func _add_chest_gem(parent: Node3D) -> void:
	_add_ellipsoid(parent, "ChestGemFrame", Vector3(0.0, 4.15, -0.50), Vector3(0.25, 0.31, 0.055), GOLD)
	_add_ellipsoid(parent, "ChestGem", Vector3(0.0, 4.15, -0.55), Vector3(0.19, 0.24, 0.05), PINK)


static func _add_shoe(parent: Node3D, name: String, position: Vector3, mirrored: bool) -> void:
	var mesh := _shoe_mesh(mirrored)
	_add_mesh(parent, name, mesh, _material(PINK), position)


static func _add_ellipsoid(parent: Node3D, name: String, position: Vector3, scale: Vector3, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 7
	sphere.radius = 1.0
	sphere.height = 2.0
	_add_mesh(parent, name, sphere, _material(color), position, Vector3.ZERO, scale)


static func _add_lathe(parent: Node3D, name: String, profile: PackedVector2Array, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO, segments: int = 8) -> void:
	_add_mesh(parent, name, _lathe_mesh(profile, segments), _material(color), position, rotation)


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
	material.roughness = 0.78
	material.metallic_specular = 0.28
	return material


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
		Vector3(-0.28, 0.00, -0.36), Vector3(0.28, 0.00, -0.36), Vector3(-0.24, 0.00, 0.38), Vector3(0.24, 0.00, 0.38),
		Vector3(-0.22, 0.23, -0.30), Vector3(0.22, 0.23, -0.30), Vector3(-0.17, 0.32, 0.14), Vector3(0.17, 0.32, 0.14),
		Vector3(0.08 * side, 0.46, 0.34), Vector3(-0.08 * side, 0.46, 0.34),
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
