extends RefCounted
## レース場の部品（柵・門・ゲート・看板・観客席など）を作るときの、共通の小道具。
## 色、単純な形、同じ形をたくさん置く仕組み、旗の絵、小旗のひも。

const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")

const FONT_PATH := "res://fonts/NotoSansCJK-Regular.ttc"
## 数字の高さ（フォントの大きさに対する割合。Noto Sans CJKの数字）。
const DIGIT_HEIGHT_EM := 0.733
## コースの中心線から、柵までの距離（コース幅15mの端の、少し外）。
const FENCE_SIDE_OFFSET_M := 8.2
## 柵の、柱の高さ（地面から）。
const FENCE_HEIGHT_M := 1.2
## 地面と、コースの面の高さ（シーンの Ground と TrackRibbon と同じ）。
const GROUND_Y_M := -0.05
const TRACK_TOP_Y_M := 0.12

const COLOR_WOOD := Color(0.46, 0.31, 0.2)
const COLOR_WOOD_DARK := Color(0.4, 0.27, 0.17)
const COLOR_GOLD := Color(0.96, 0.78, 0.25)
const COLOR_WHITE := Color(0.97, 0.96, 0.93)
const COLOR_BLACK := Color(0.1, 0.11, 0.14)
const COLOR_NAVY := Color(0.14, 0.24, 0.55)
const COLOR_CRIMSON := Color(0.78, 0.14, 0.18)
const COLOR_STONE := Color(0.86, 0.81, 0.72)
## 小旗のひもの、旗の色の並び。
const BUNTING_COLORS := [
	Color(0.9, 0.2, 0.22), Color(0.98, 0.84, 0.22), Color(0.2, 0.45, 0.88),
	Color(0.97, 0.97, 0.95), Color(0.3, 0.72, 0.42), Color(0.96, 0.56, 0.72),
]
const BUNTING_FLAG_WIDTH_M := 0.62
const BUNTING_FLAG_DROP_M := 0.62
## 紋章の旗の絵の大きさ（ピクセル）。
const BANNER_TEXTURE_SIZE := Vector2i(96, 225)
## 紋章に並べる属性（上・左・右・下）。
const BANNER_ATTRIBUTES := ["fire", "water", "wind", "earth"]

## 色 → その色の旗の素材（同じ色の旗は、1つの素材を使い回す）。
static var _banner_materials := {}


static func material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


## 金色の、つやのある素材。
static func gold() -> StandardMaterial3D:
	return material(COLOR_GOLD, 0.35)


static func mesh(parent: Node3D, shape: Mesh, surface: Material, position: Vector3, rotation_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = surface
	node.position = position
	node.rotation_degrees = rotation_deg
	node.scale = scale
	parent.add_child(node)
	return node


static func box(parent: Node3D, size: Vector3, position: Vector3, surface: Material, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, surface, position, rotation_deg)


static func cylinder_mesh(top_radius: float, bottom_radius: float, height: float, segments: int = 16) -> CylinderMesh:
	var shape := CylinderMesh.new()
	shape.top_radius = top_radius
	shape.bottom_radius = bottom_radius
	shape.height = height
	shape.radial_segments = segments
	shape.rings = 1
	return shape


## 筒（上が細いと、すい）。foot は、底のまん中。
static func cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, foot: Vector3, surface: Material, segments: int = 16) -> MeshInstance3D:
	return mesh(parent, cylinder_mesh(top_radius, bottom_radius, height, segments), surface, foot + Vector3(0.0, height * 0.5, 0.0))


static func sphere_mesh(radius: float, segments: int = 16) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = segments
	shape.rings = maxi(segments / 2, 3)
	return shape


## 同じ形を、たくさん置く。colors が空なら、surface の色のまま。surface が無ければ、個々の色で塗る。
static func multi(parent: Node3D, shape: Mesh, transforms: Array, colors: Array = [], surface: Material = null, shadows: bool = true) -> MultiMeshInstance3D:
	var data := MultiMesh.new()
	data.transform_format = MultiMesh.TRANSFORM_3D
	data.use_colors = not colors.is_empty()
	data.mesh = shape
	data.instance_count = transforms.size()
	for i in transforms.size():
		data.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			data.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = data
	if surface == null:
		var tinted := StandardMaterial3D.new()
		tinted.vertex_color_use_as_albedo = true
		tinted.roughness = 1.0
		surface = tinted
	node.material_override = surface
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## 色つきの三角を、まとめて1つの形にする（両面）。
static func colored_triangles(parent: Node3D, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.roughness = 1.0
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = surface
	parent.add_child(node)
	return node


## 小旗の数。ひもの長さを、旗の幅で割る。
static func bunting_flag_count(span_m: float) -> int:
	return maxi(int(span_m / BUNTING_FLAG_WIDTH_M), 1)


## 2点のあいだに、たるんだひもに沿って、三角の小旗を並べる。sag は、まん中のたるみ（m）。
static func bunting(parent: Node3D, from: Vector3, to: Vector3, sag: float) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var count := bunting_flag_count(from.distance_to(to))
	var face := (to - from).normalized().cross(Vector3.UP).normalized()
	for i in count:
		var t0 := float(i) / float(count)
		var t1 := float(i + 1) / float(count)
		var a := from.lerp(to, t0) - Vector3(0.0, sag * 4.0 * t0 * (1.0 - t0), 0.0)
		var b := from.lerp(to, t1) - Vector3(0.0, sag * 4.0 * t1 * (1.0 - t1), 0.0)
		vertices.append_array([a, b, (a + b) * 0.5 - Vector3(0.0, BUNTING_FLAG_DROP_M, 0.0)])
		for _k in 3:
			colors.append(BUNTING_COLORS[i % BUNTING_COLORS.size()])
			normals.append(face)
	return colored_triangles(parent, vertices, normals, colors)


## 属性の色（設定の色）。
static func attribute_color(attribute: String) -> Color:
	return Color(str(PururinStatsConfig.values()["attributes"][attribute]["color"]))


## 紋章の旗の絵（白い丸の中に、四属性の4色の丸）。下は、二またに切れている。
static func banner_image(color: Color) -> Image:
	var width := BANNER_TEXTURE_SIZE.x
	var height := BANNER_TEXTURE_SIZE.y
	# 寸法は、横幅128ピクセルのときの値で書いてある。
	var unit := float(width) / 128.0
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var middle := Vector2(width * 0.5, height * 0.373)
	var ring := 50.0 * unit
	var dots := [
		[middle + Vector2(0.0, -26.0) * unit, attribute_color(BANNER_ATTRIBUTES[0])],
		[middle + Vector2(-24.0, 0.0) * unit, attribute_color(BANNER_ATTRIBUTES[1])],
		[middle + Vector2(24.0, 0.0) * unit, attribute_color(BANNER_ATTRIBUTES[2])],
		[middle + Vector2(0.0, 26.0) * unit, attribute_color(BANNER_ATTRIBUTES[3])],
	]
	var edge := 7.0 * unit
	for y in height:
		for x in width:
			# 下のふち。まん中ほど、上へ切れこむ。
			var cut := float(height) - ring + absf(float(x) - width * 0.5) * ring / (width * 0.5)
			if float(y) > cut:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var pixel := color
			if float(x) < edge or float(x) >= float(width) - edge or float(y) < edge or float(y) > cut - edge:
				pixel = COLOR_GOLD
			var here := Vector2(float(x), float(y))
			var from_middle := here.distance_to(middle)
			if from_middle < ring:
				pixel = COLOR_WHITE
			if absf(from_middle - ring) < 3.0 * unit:
				pixel = COLOR_GOLD
			for dot: Array in dots:
				if here.distance_to(dot[0]) < 17.0 * unit:
					pixel = dot[1]
			image.set_pixel(x, y, pixel)
	image.generate_mipmaps()
	return image


## 紋章の旗を1枚、上のふちのまん中が top に来るように下げる。facing は、布の表の向き。
static func banner(parent: Node3D, top: Vector3, color: Color, width: float, height: float, facing: Vector3) -> MeshInstance3D:
	var key := color.to_html()
	if not _banner_materials.has(key):
		var surface := StandardMaterial3D.new()
		surface.albedo_texture = ImageTexture.create_from_image(banner_image(color))
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.roughness = 1.0
		_banner_materials[key] = surface
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = _banner_materials[key]
	# QuadMesh の表は +Z。
	node.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), top + Vector3(0.0, -height * 0.5, 0.0))
	parent.add_child(node)
	return node


## 2色の市松の絵。
static func checker_texture(columns: int, rows: int, first: Color, second: Color) -> ImageTexture:
	var image := Image.create(columns, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		for x in columns:
			image.set_pixel(x, y, first if (x + y) % 2 == 0 else second)
	return ImageTexture.create_from_image(image)


## 絵を、ぼかさずに貼る素材（市松など）。
static func crisp_texture_material(texture: Texture2D) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_texture = texture
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.roughness = 1.0
	return surface


## 板に書く文字。digit_height_m は、数字や大文字の高さ（m）。同じ色の縁取りで、太く見せる。
static func label(parent: Node3D, text: String, digit_height_m: float, color: Color, position: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> Label3D:
	var font_size := 128
	var node := Label3D.new()
	node.text = text
	node.font = load(FONT_PATH) as Font
	node.font_size = font_size
	node.pixel_size = digit_height_m / (DIGIT_HEIGHT_EM * float(font_size))
	node.outline_size = 14
	node.modulate = color
	node.outline_modulate = color
	node.shaded = false
	node.double_sided = false
	node.position = position
	node.rotation_degrees = rotation_deg
	parent.add_child(node)
	return node


## コースの上の1点を基準にした、置き場所。x＝外側、y＝上、z＝進む向きの逆（手前）。
static func frame_at(position: Vector3, travel: Vector3) -> Transform3D:
	var forward := Vector3(travel.x, 0.0, travel.z).normalized()
	var outward := Vector3(-forward.z, 0.0, forward.x)
	return Transform3D(Basis(outward, Vector3.UP, -forward), position)
