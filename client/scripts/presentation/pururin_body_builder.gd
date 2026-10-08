extends RefCounted
## ぷるりんの体を、見た目の設定（look）と部品の一覧（parts）から組み立てる。
## 体はドーム形（または用意されたメッシュ）、体の一部（頭の上・左右・尾）、顔（目・口・ほっぺ）、マーク。
## どの部品も、こちらで作った形か、用意されたファイルかを、設定で選ぶ。足元が原点、正面は −Z。
## 設定の中身が正しいことは、読み込みのとき（PururinLookConfig）に検査してある前提。

const Surface := preload("res://scripts/presentation/pururin_parts/pururin_surface.gd")
const BodyParts := preload("res://scripts/presentation/pururin_parts/body_parts.gd")
const FaceParts := preload("res://scripts/presentation/pururin_parts/face_parts.gd")
const PartAssets := preload("res://scripts/presentation/pururin_parts/part_assets.gd")
const PururinBody := preload("res://scripts/presentation/pururin_body.gd")

const BODY_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 primary : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 secondary : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 第二カラーを塗る高さ（体の下から。0なら塗らない）。
uniform float secondary_top = 0.0;
uniform float body_height = 1.0;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 体に巻き付ける絵。use_texture が 1 のとき、色の代わりに使う。
uniform sampler2D body_texture : source_color, filter_linear_mipmap;
uniform float use_texture = 0.0;
// 質感（設定の finishes から入れる）。
uniform float roughness = 0.2;
uniform float specular = 0.5;
uniform float clearcoat = 0.0;
uniform float clearcoat_roughness = 0.1;
uniform float rim_strength = 0.4;
uniform float rim_power = 2.4;
uniform float self_light = 0.1;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float core_strength = 0.0;
uniform float grain = 0.0;
// 接触の演出などで、白く光らせる量。
uniform float glow = 0.0;
// 部品ごとの値。part_y と part_y_axis は、部品の中の点を「体の足元からの高さ」に直すためのもの。
instance uniform float part_y = 0.0;
instance uniform vec3 part_y_axis = vec3(0.0, 1.0, 0.0);
// 第二カラーを塗るか（体の本体だけ 1。頭の上・左右・尾の部品は 0）。
instance uniform float secondary_band = 1.0;
// 頂点の色を使うか（こちらで作った部品だけ 1）。
instance uniform float vertex_tint = 0.0;
// 面をカクカクに見せるか（岩だけ 1）。
instance uniform float flat_shade = 0.0;
varying float body_y;
varying vec3 part_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// なめらかな、ざらざらの模様（0〜1）。
float speckle(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(cell), hash(cell + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(cell + vec3(0.0, 1.0, 0.0)), hash(cell + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(cell + vec3(0.0, 0.0, 1.0)), hash(cell + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(cell + vec3(0.0, 1.0, 1.0)), hash(cell + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void vertex() {
	body_y = part_y + dot(part_y_axis, VERTEX);
	part_position = VERTEX;
}

void fragment() {
	float band = (1.0 - smoothstep(secondary_top - 0.012, secondary_top + 0.012, body_y)) * step(0.0001, secondary_top) * secondary_band;
	vec3 base = mix(primary.rgb, secondary.rgb, band);
	base = mix(base, texture(body_texture, UV).rgb, use_texture);
	base = mix(base, COLOR.rgb, COLOR.a * vertex_tint);
	base *= 1.0 - grain * (speckle(part_position * 11.0) * 0.6 + speckle(part_position * 29.0) * 0.4);
	// 上を少し明るく、下を少し濃く。
	base *= mix(0.84, 1.08, clamp(body_y / body_height, 0.0, 1.0));
	if (flat_shade > 0.5) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	EMISSION = rim_color.rgb * pow(1.0 - facing, rim_power) * rim_strength + base * self_light + core_color.rgb * pow(facing, 1.5) * core_strength + vec3(glow);
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.1, 0.3, 0.7, 1.0);
uniform float outline_width = 0.014;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""


static var _shaders := {}

## 質感（finishes）の項目。数字と、色。
const FINISH_NUMBER_KEYS := ["roughness", "specular", "clearcoat", "clearcoat_roughness", "rim_strength", "rim_power", "self_light", "core_strength", "grain"]
const FINISH_COLOR_KEYS := ["core_color"]


## look（個体の見た目）と、config（読み込んだ見た目の設定。parts＝部品の一覧、finishes＝質感の一覧、body_motions＝体全体の動かし方の一覧）から、体を組み立てる。
## look は、第一カラーの番号を色に直したもの（PururinLookConfig.look_for() か resolved_look() の結果）。
static func build(look: Dictionary, config: Dictionary) -> Node3D:
	var parts: Dictionary = config["parts"]
	var root: Node3D = PururinBody.new()
	root.name = "PururinBody"
	var body: Dictionary = look["body"]
	var shape := {"height": float(body["height"]), "base_height": float(body["base_height"])}
	var material := _body_material(look, shape, config["finishes"][str(look["finish"])])
	root.call("set_body_material", material)
	var dome := _body_node(body, shape, material)
	root.add_child(dome)
	_bind_body_height(root, dome)
	# 体の一部（頭の上・左右・尾）。あとでアクションごとに動かせるように、節を覚えておく。
	for slot: String in ["top", "sides", "tail"]:
		if look[slot] == null:
			continue
		var placement: Dictionary = look[slot]
		var part: Dictionary = parts[str(placement["part"])]
		var source := merged_source(part, placement)
		var nodes: Array[Node3D]
		match slot:
			"top": nodes = BodyParts.build_top(shape, source, material)
			"sides": nodes = BodyParts.build_sides(shape, source, placement, material)
			"tail": nodes = BodyParts.build_tail(shape, source, placement, material)
		for node in nodes:
			root.add_child(node)
			_bind_body_height(root, node)
			# 第二カラーは、体の本体だけに塗る（部品には塗らない）。
			for mesh: MeshInstance3D in _meshes_in(node):
				mesh.set_instance_shader_parameter("secondary_band", 0.0)
			root.call("register_body_part", node, part["motions"])
	# 顔。表情の名前ごとに、書かれているスロットの部品の作り方を登録する（作るのは、その表情を最初に出すとき）。
	# スロットに null と書いた表情は、そのスロットに何も出さない。
	var face := _face_values(look["face"])
	var expressions: Dictionary = look["face"]["expressions"]
	for expression: String in expressions:
		var slots: Dictionary = expressions[expression]
		for slot: String in slots:
			var source: Variant = null if slots[slot] == null else parts[str(slots[slot])]["source"]
			var node_name := "Face_%s_%s" % [expression, slot]
			root.call("register_face", expression, slot, func() -> Array:
				return [] if source == null else [FaceParts.build(slot, shape, source, face, node_name)])
	# マーク（変わらない飾り）。
	var marks: Array = look["marks"]
	for index in marks.size():
		var placed: Dictionary = (marks[index] as Dictionary).duplicate()
		placed["color"] = Color(str(placed["color"]))
		root.add_child(FaceParts.build_mark(shape, parts[str(placed["part"])]["source"], placed, "Mark%d" % index))
	# 体全体の動かし方（個体ごとに、動きの大きさと速さの倍率を持つ）。
	var body_motion: Dictionary = look["body_motion"]
	root.call("set_body_motion", config["body_motions"][str(body_motion["set"])], float(body_motion["amount"]), float(body_motion["speed"]))
	root.call("set_expression", PururinBody.NORMAL)
	return root


## 部品の作り方に、個体ごとの上書き（params）を混ぜる。
static func merged_source(part: Dictionary, placement: Dictionary) -> Dictionary:
	var source: Dictionary = (part["source"] as Dictionary).duplicate()
	source.merge(placement["params"], true)
	return source


## 部品の中のメッシュに、「部品の中の点 → 体の足元からの高さ」の直し方を教える
## （体の色の明るさと、第二カラーを塗る高さが、部品でも体と同じ高さでそろう）。
static func _bind_body_height(root: Node3D, part: Node3D) -> void:
	for mesh: MeshInstance3D in _meshes_in(part):
		var in_body := mesh.transform
		var parent := mesh.get_parent() as Node3D
		while parent != null and parent != root:
			in_body = parent.transform * in_body
			parent = parent.get_parent() as Node3D
		mesh.set_instance_shader_parameter("part_y", in_body.origin.y)
		mesh.set_instance_shader_parameter("part_y_axis", Vector3(in_body.basis.x.y, in_body.basis.y.y, in_body.basis.z.y))


## 部品の中の、メッシュの節（部品そのものも含む）。
static func _meshes_in(part: Node3D) -> Array:
	var meshes := part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D:
		meshes.append(part)
	return meshes


## 体の本体。こちらで作るドームか、用意されたメッシュ。
static func _body_node(body: Dictionary, shape: Dictionary, material: Material) -> Node3D:
	if str(body["type"]) == "mesh":
		var node := PartAssets.instantiate_mesh(str(body["path"]))
		assert(node != null, "体のメッシュを読めません: %s" % body["path"])
		node.name = "Dome"
		node.scale = Vector3.ONE * float(body["scale"])
		if str(body["material"]) == "body":
			for child in node.find_children("*", "MeshInstance3D", true, false):
				(child as MeshInstance3D).material_override = material
		return node
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = Surface.dome_mesh(shape)
	dome.material_override = material
	return dome


## 顔の置き方と色を、組み立てに使う形（色は Color）にする。
static func _face_values(face: Dictionary) -> Dictionary:
	var values := face.duplicate()
	values["eye_colors"] = [Color(str(face["eye_colors"][0])), Color(str(face["eye_colors"][1]))]
	values["cheek_color"] = Color(str(face["cheek_color"]))
	return values


## 同じシェーダーを、全部の体で使い回す（体ごとに作り直さない）。
static func _shared_shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]


static func _body_material(look: Dictionary, shape: Dictionary, finish: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shared_shader("body", BODY_SHADER)
	var primary := Color(str(look["primary_color"]))
	material.set_shader_parameter("primary", primary)
	material.set_shader_parameter("secondary", Color(str(look["secondary_color"])))
	material.set_shader_parameter("secondary_top", float(shape["height"]) * float(look["secondary_top_ratio"]))
	material.set_shader_parameter("body_height", float(shape["height"]))
	material.set_shader_parameter("rim_color", primary.lightened(0.6))
	for key: String in FINISH_NUMBER_KEYS:
		material.set_shader_parameter(key, float(finish[key]))
	for key: String in FINISH_COLOR_KEYS:
		material.set_shader_parameter(key, Color(str(finish[key])))
	if look["body_texture"] != null:
		var texture := PartAssets.load_texture(str(look["body_texture"]))
		assert(texture != null, "体のテクスチャを読めません: %s" % look["body_texture"])
		material.set_shader_parameter("body_texture", texture)
		material.set_shader_parameter("use_texture", 1.0)
	if float(look["outline_width"]) > 0.0:
		var outline := ShaderMaterial.new()
		outline.shader = _shared_shader("outline", OUTLINE_SHADER)
		outline.set_shader_parameter("outline_color", Color(str(look["outline_color"])))
		outline.set_shader_parameter("outline_width", float(look["outline_width"]))
		material.next_pass = outline
	return material
