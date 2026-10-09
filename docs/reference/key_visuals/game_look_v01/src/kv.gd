extends SceneTree
## キービジュアル用の撮影。ゲームの本物のぷるりんと、城下町のレース場（仮の組み立て）を写す。
## 使い方： KV_SHOT=<名前> KV_OUT=<保存先.png> godot --path client -s kv.gd

const Builder := preload("res://scripts/presentation/pururin_body_builder.gd")
const LookConfig := preload("res://scripts/config/pururin_look_config.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const FONT_PATH := "res://fonts/NotoSansCJK-Regular.ttc"

## コースの形（local_race.tscn と同じ）。
const STRAIGHT := 526.0
const RADIUS := 164.0
const TRACK_W := 15.0
const HALF_S := 263.0
const GOAL_Z := -60.0
const START_Z := 110.0
const STAND_Z0 := -236.0
const STAND_Z1 := 132.0

const NOISE_GLSL := """
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

var _rng := RandomNumberGenerator.new()
var _vp: SubViewport
var _world: Node3D
var _frames := 0
var _shot := {}
var _attr_colors := {}
var _runners: Array = []


func _initialize() -> void:
	_rng.seed = 20261009
	var stats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/pururin_stats.json"))
	for key: String in stats["attributes"]:
		_attr_colors[key] = Color(str(stats["attributes"][key]["color"]))
	_shot = _shots()[OS.get_environment("KV_SHOT")]
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	_vp = SubViewport.new()
	_vp.size = _shot.get("size", Vector2i(3840, 2160))
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.transparent_bg = bool(_shot.get("transparent", false))
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_build_light_and_sky()
	if not bool(_shot.get("no_venue", false)):
		_build_venue()
	for spec: Dictionary in _shot.get("runners", []):
		_add_runner(spec)
	if _shot.has("confetti"):
		_add_confetti(_shot["confetti"])
	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.fov = float(_shot.get("fov", 40.0))
	cam.far = 9000.0
	cam.near = 0.1
	cam.look_at_from_position(_shot["cam"], _shot["look"], Vector3.UP)
	if _shot.has("ortho"):
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(_shot["ortho"])
	if _shot.has("dof"):
		var attrs := CameraAttributesPractical.new()
		attrs.dof_blur_far_enabled = true
		attrs.dof_blur_far_distance = float(_shot["dof"][0])
		attrs.dof_blur_far_transition = float(_shot["dof"][1])
		attrs.dof_blur_amount = float(_shot["dof"][2])
		cam.attributes = attrs
	cam.current = true


func _process(delta: float) -> bool:
	_frames += 1
	for runner: Dictionary in _runners:
		(runner["body"] as Node3D).call("advance_motion", delta * float(runner["time_scale"]))
	if _frames == 60:
		var image := _vp.get_texture().get_image()
		var out := OS.get_environment("KV_OUT")
		image.save_png(out)
		print("saved ", out, " ", image.get_size())
		return true
	return false


# ---------------------------------------------------------------- 撮り方の一覧

func _shots() -> Dictionary:
	var day := {"sun": Vector3(0.55, 0.85, -0.75), "sun_color": Color(1.0, 0.97, 0.9), "sun_energy": 1.25,
		"top": Color(0.16, 0.42, 0.88), "horizon": Color(0.72, 0.88, 1.0), "ambient": 0.75, "fog": Color(0.74, 0.86, 1.0)}
	var sunset := {"sun": Vector3(-0.8, 0.22, -0.55), "sun_color": Color(1.0, 0.62, 0.36), "sun_energy": 1.5,
		"top": Color(0.22, 0.24, 0.6), "horizon": Color(1.0, 0.66, 0.42), "ambient": 0.7, "fog": Color(1.0, 0.72, 0.56),
		"cloud_shade": Color(0.62, 0.42, 0.62), "cloud_lit": Color(1.0, 0.8, 0.66)}
	var all_ids := ["player-1", "cpu-1", "cpu-2", "cpu-3", "cpu-4", "cpu-5", "cpu-6", "cpu-7"]
	var shots := {}
	# タイトル用。上のまん中はロゴ、下のまん中はボタンのために空けてある。
	var title_runners := [
		{"id": "player-1", "x": 0.1, "z": 16.2, "yaw": 3.0, "expr": "joy", "action": "dash", "hop": 0.2, "lean": 9.0},
		{"id": "cpu-1", "x": 2.95, "z": 17.5, "yaw": -9.0, "expr": "push_win", "action": "dash", "hop": 0.04, "lean": 11.0},
		{"id": "cpu-2", "x": -2.8, "z": 17.3, "yaw": 10.0, "expr": "joy", "action": "run", "hop": 0.1, "lean": 7.0},
		{"id": "cpu-3", "x": 5.9, "z": 20.4, "yaw": -14.0, "expr": "anger", "action": "run", "hop": 0.0, "lean": 6.0},
		{"id": "cpu-4", "x": -1.45, "z": 21.0, "yaw": 4.0, "expr": "relax", "action": "run", "hop": 0.3, "lean": 7.0},
		{"id": "cpu-5", "x": 1.5, "z": 21.4, "yaw": -4.0, "expr": "first_place", "action": "run", "hop": 0.12, "lean": 7.0},
		{"id": "cpu-6", "x": -5.7, "z": 20.6, "yaw": 13.0, "expr": "normal", "action": "run", "hop": 0.16, "lean": 7.0},
		{"id": "cpu-7", "x": 4.3, "z": 24.6, "yaw": -8.0, "expr": "push_win", "action": "run", "hop": 0.05, "lean": 7.0},
	]
	shots["title"] = day.merged({
		"cam": Vector3(0.2, 1.55, 7.4), "look": Vector3(0.0, 2.9, 30.0), "fov": 44.0, "dof": [30.0, 80.0, 0.04],
		"confetti": {"center": Vector3(0.0, 6.5, 30.0), "extent": Vector3(18.0, 6.0, 13.0), "count": 420},
		"runners": title_runners,
	})
	shots["title_sunset"] = sunset.merged({
		"cam": Vector3(0.2, 1.55, 7.4), "look": Vector3(0.0, 2.9, 30.0), "fov": 44.0, "dof": [30.0, 80.0, 0.04],
		"runners": title_runners,
	})
	# スタート前。8プルが、枠の番号の下に並ぶ。
	var start_runners := []
	var start_exprs := ["normal", "anger", "relax", "normal", "joy", "push_win", "normal", "anger"]
	var gate_order := ["cpu-3", "cpu-6", "cpu-1", "player-1", "cpu-4", "cpu-5", "cpu-2", "cpu-7"]
	for i in 8:
		start_runners.append({"id": gate_order[i], "x": _gate_x(i), "z": START_Z + 1.5, "yaw": 0.0, "expr": start_exprs[i], "action": "idle", "dust": false})
	shots["start"] = day.merged({
		"cam": Vector3(-7.35, 1.05, START_Z - 3.8), "look": Vector3(2.0, 1.75, START_Z + 1.8), "fov": 50.0, "dof": [40.0, 90.0, 0.04],
		"runners": start_runners,
	})
	shots["start_front"] = day.merged({
		"cam": Vector3(0.0, 1.3, START_Z - 9.0), "look": Vector3(0.0, 3.0, START_Z + 1.5), "fov": 55.0, "dof": [40.0, 90.0, 0.04],
		"runners": start_runners,
	})
	# レース中。内側から、観客席を背に、集団を写す。
	shots["race"] = day.merged({
		"cam": Vector3(-4.2, 0.85, -33.0), "look": Vector3(0.7, 1.3, -18.0), "fov": 31.0, "dof": [26.0, 40.0, 0.06],
		"runners": [
			{"id": "cpu-1", "x": -2.3, "z": -21.4, "yaw": 5.0, "expr": "push_win", "action": "dash", "hop": 0.05, "lean": 12.0},
			{"id": "player-1", "x": 0.3, "z": -20.4, "yaw": -4.0, "expr": "push_win", "action": "push", "hop": 0.0, "lean": 10.0, "roll": -5.0},
			{"id": "cpu-2", "x": 1.95, "z": -20.0, "yaw": 6.0, "expr": "push_lose", "action": "push", "hop": 0.12, "lean": 4.0, "roll": -9.0},
			{"id": "cpu-4", "x": -3.6, "z": -16.6, "yaw": 0.0, "expr": "relax", "action": "run", "hop": 0.24, "lean": 8.0},
			{"id": "cpu-3", "x": 4.6, "z": -17.0, "yaw": 2.0, "expr": "anger", "action": "run", "hop": 0.02, "lean": 7.0},
			{"id": "cpu-5", "x": -0.6, "z": -15.2, "yaw": -3.0, "expr": "joy", "action": "run", "hop": 0.15, "lean": 8.0},
			{"id": "cpu-6", "x": 2.6, "z": -13.0, "yaw": 3.0, "expr": "sorrow", "action": "run", "hop": 0.06, "lean": 6.0},
			{"id": "cpu-7", "x": -2.4, "z": -11.4, "yaw": 0.0, "expr": "push_win", "action": "run", "hop": 0.1, "lean": 8.0},
		],
	})
	# ゴール。1位が門をくぐった所を、先から振り返って写す。
	shots["goal"] = day.merged({
		"cam": Vector3(-2.2, 0.75, GOAL_Z - 10.5), "look": Vector3(0.3, 3.3, GOAL_Z), "fov": 50.0, "dof": [40.0, 90.0, 0.035],
		"confetti": {"center": Vector3(0.0, 6.0, GOAL_Z + 4.0), "extent": Vector3(13.0, 6.0, 12.0), "count": 900},
		"runners": [
			{"id": "player-1", "x": -0.9, "z": GOAL_Z - 5.4, "yaw": 14.0, "expr": "first_place", "action": "goal", "hop": 0.42, "lean": -6.0, "dust": false},
			{"id": "cpu-1", "x": 2.9, "z": GOAL_Z - 2.4, "yaw": -6.0, "expr": "anger", "action": "dash", "hop": 0.04, "lean": 11.0},
			{"id": "cpu-4", "x": -3.9, "z": GOAL_Z - 0.6, "yaw": 8.0, "expr": "sorrow", "action": "run", "hop": 0.1, "lean": 8.0},
			{"id": "cpu-2", "x": 0.6, "z": GOAL_Z + 2.6, "yaw": 0.0, "expr": "push_win", "action": "run", "hop": 0.16, "lean": 8.0},
			{"id": "cpu-3", "x": 5.2, "z": GOAL_Z + 4.4, "yaw": -4.0, "expr": "normal", "action": "run", "hop": 0.0, "lean": 6.0},
			{"id": "cpu-5", "x": -2.2, "z": GOAL_Z + 6.2, "yaw": 3.0, "expr": "sorrow", "action": "run", "hop": 0.08, "lean": 7.0},
		],
	})
	# レース画面の見え方（ゲームのカメラと同じ位置：後ろ6m・高さ3m・視野55度）。
	shots["race_view"] = day.merged({
		"cam": Vector3(0.6, 3.0, 46.0), "look": Vector3(0.6, 0.6, 40.0), "fov": 55.0,
		"runners": [
			{"id": "player-1", "x": 0.6, "z": 40.0, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.08, "lean": 6.0},
			{"id": "cpu-1", "x": -1.6, "z": 33.5, "yaw": 2.0, "expr": "normal", "action": "dash", "hop": 0.0, "lean": 9.0},
			{"id": "cpu-2", "x": 2.6, "z": 35.8, "yaw": -3.0, "expr": "normal", "action": "run", "hop": 0.14, "lean": 6.0},
			{"id": "cpu-5", "x": 0.2, "z": 28.6, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.05, "lean": 6.0},
			{"id": "cpu-3", "x": 4.6, "z": 30.5, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.0, "lean": 6.0},
			{"id": "cpu-4", "x": -3.9, "z": 37.6, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.2, "lean": 6.0},
			{"id": "cpu-6", "x": -4.4, "z": 26.0, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.1, "lean": 6.0},
			{"id": "cpu-7", "x": 2.4, "z": 24.4, "yaw": 0.0, "expr": "normal", "action": "run", "hop": 0.02, "lean": 6.0},
		],
	})
	# コーナーの見え方（ぷるりん無し）。
	shots["curve_view"] = day.merged({
		"cam": Vector3(0.0, 3.0, -HALF_S + 40.0), "look": Vector3(-6.0, 0.6, -HALF_S - 20.0), "fov": 55.0,
	})
	# レース場の全体（空から）。
	shots["venue_wide"] = day.merged({
		"cam": Vector3(330.0, 270.0, -640.0), "look": Vector3(-170.0, 0.0, 60.0), "fov": 40.0,
		"shadow_distance": 2600.0, "fog_begin": 900.0, "fog_density": 0.7,
	})
	shots["venue_wide_sunset"] = sunset.merged({
		"cam": Vector3(330.0, 270.0, -640.0), "look": Vector3(-170.0, 0.0, 60.0), "fov": 40.0,
		"shadow_distance": 2600.0, "fog_begin": 900.0, "fog_density": 0.7,
	})
	# 観客席と王さまの席（内側から。ぷるりん無し）。メニューの背景向け。
	shots["stands"] = day.merged({
		"cam": Vector3(-6.4, 2.0, GOAL_Z - 40.0), "look": Vector3(13.0, 5.6, GOAL_Z - 3.0), "fov": 48.0,
	})
	# ホームストレートを見わたす（少し高い所から。ぷるりん無し）。メニューの背景向け。
	shots["straight"] = day.merged({
		"cam": Vector3(-9.0, 6.5, GOAL_Z - 62.0), "look": Vector3(2.0, 4.0, GOAL_Z + 20.0), "fov": 46.0,
	})
	# 8プルの立ち絵（背景なし・透明）。
	var cast := []
	for i in 8:
		cast.append({"id": all_ids[i], "x": (3.5 - float(i)) * 2.15, "z": 0.0, "yaw": -14.0, "expr": "normal", "action": "idle", "dust": false})
	shots["cast"] = day.merged({
		"cam": Vector3(0.0, 2.2, -30.0), "look": Vector3(0.0, 0.62, 0.0), "ortho": 3.0, "size": Vector2i(4800, 800),
		"no_venue": true, "transparent": true, "runners": cast, "ambient": 0.85,
	})
	var cast_joy := []
	var joy_exprs := ["joy", "push_win", "relax", "normal", "first_place", "joy", "relax", "anger"]
	var group_ids := ["cpu-2", "player-1", "cpu-1", "cpu-3", "cpu-6", "cpu-4", "cpu-5", "cpu-7"]
	var group_exprs := ["relax", "joy", "push_win", "normal", "normal", "first_place", "joy", "anger"]
	var group_spots := [[-1.8, 0.0], [0.0, 0.0], [1.8, 0.0], [-0.9, 1.8], [0.9, 1.8], [-1.8, 3.6], [0.0, 3.6], [1.8, 3.6]]
	group_ids = ["cpu-2", "player-1", "cpu-1", "cpu-5", "cpu-6", "cpu-3", "cpu-4", "cpu-7"]
	group_exprs = ["relax", "joy", "push_win", "joy", "normal", "normal", "first_place", "anger"]
	for i in 8:
		cast_joy.append({"id": group_ids[i], "x": group_spots[i][0], "z": group_spots[i][1], "yaw": float(group_spots[i][0]) * 5.0, "expr": group_exprs[i], "action": "idle", "dust": false, "hop": 0.16 if i == 1 or i == 6 else 0.0})
	shots["cast_group"] = day.merged({
		"cam": Vector3(0.0, 5.4, -11.0), "look": Vector3(0.0, 0.75, 1.9), "fov": 22.0, "size": Vector2i(3840, 2160),
		"no_venue": true, "transparent": true, "runners": cast_joy, "ambient": 0.85,
	})
	# ロゴに添える1プル（透明）。
	shots["logo_pururin"] = day.merged({
		"cam": Vector3(3.0, 1.6, -9.0), "look": Vector3(0.0, 0.62, 0.0), "fov": 14.0, "size": Vector2i(1600, 1600),
		"no_venue": true, "transparent": true, "ambient": 0.85,
		"runners": [{"id": "player-1", "x": 0.0, "z": 0.0, "yaw": 0.0, "expr": "joy", "action": "idle", "dust": false, "roll": 6.0}],
	})
	# アイコン（正方形）。
	shots["icon"] = day.merged({
		"cam": Vector3(-0.9, 0.95, 51.6), "look": Vector3(0.0, 0.78, 55.0), "fov": 30.0, "size": Vector2i(2048, 2048), "dof": [9.0, 30.0, 0.09],
		"confetti": {"center": Vector3(0.0, 3.0, 62.0), "extent": Vector3(5.0, 3.0, 4.0), "count": 90},
		"runners": [{"id": "player-1", "x": 0.0, "z": 55.0, "yaw": 0.0, "expr": "joy", "action": "run", "hop": 0.1, "lean": 5.0}],
	})
	# 横長のバナー（3:1）。正面から、横に広がった集団。
	var banner_spots := [[-3.0, 17.0], [-1.0, 16.4], [1.05, 17.2], [3.1, 16.8], [-5.9, 23.0], [-3.1, 23.6], [3.2, 23.2], [6.0, 23.8]]
	var banner_ids := ["cpu-2", "player-1", "cpu-1", "cpu-3", "cpu-6", "cpu-4", "cpu-5", "cpu-7"]
	var banner_exprs := ["joy", "first_place", "push_win", "anger", "normal", "relax", "joy", "push_win"]
	var banner_hops := [0.1, 0.24, 0.04, 0.0, 0.14, 0.26, 0.08, 0.03]
	var banner := []
	for i in 8:
		banner.append({"id": banner_ids[i], "x": banner_spots[i][0], "z": banner_spots[i][1], "yaw": float(banner_spots[i][0]) * -2.5, "expr": banner_exprs[i], "action": "dash" if i < 4 else "run", "hop": banner_hops[i], "lean": 9.0})
	shots["banner"] = day.merged({
		"cam": Vector3(0.0, 0.95, 6.0), "look": Vector3(0.0, 1.75, 30.0), "fov": 14.5, "size": Vector2i(4800, 1600), "dof": [34.0, 80.0, 0.035],
		"confetti": {"center": Vector3(0.0, 4.0, 34.0), "extent": Vector3(14.0, 4.0, 10.0), "count": 300},
		"runners": banner,
	})
	return shots


## 枠の番号（0〜7）の横位置。1枠が内側（−X）。
func _gate_x(gate_index: int) -> float:
	return -TRACK_W * 0.5 + TRACK_W / 8.0 * (float(gate_index) + 0.5)


# ---------------------------------------------------------------- 明かりと空

func _build_light_and_sky() -> void:
	var sun := DirectionalLight3D.new()
	_world.add_child(sun)
	var sun_dir: Vector3 = (_shot["sun"] as Vector3).normalized()
	sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
	sun.light_color = _shot["sun_color"]
	sun.light_energy = float(_shot["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(_shot.get("shadow_distance", 140.0))
	sun.shadow_blur = 1.4
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
void sky() {
	float t = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 c = mix(horizon, top, pow(t, 0.55));
	if (LIGHT0_ENABLED) {
		float d = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		c += LIGHT0_COLOR * (pow(d, 600.0) * 2.0 + pow(d, 12.0) * 0.12);
	}
	COLOR = c;
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("top", _shot["top"])
	sky_material.set_shader_parameter("horizon", _shot["horizon"])
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (_shot["horizon"] as Color).lerp(Color.WHITE, 0.45)
	env.ambient_light_energy = float(_shot["ambient"])
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _shot["fog"]
	env.fog_depth_begin = float(_shot.get("fog_begin", 160.0))
	env.fog_depth_end = float(_shot.get("fog_end", 7000.0))
	env.fog_depth_curve = 1.0
	env.fog_density = float(_shot.get("fog_density", 0.85))
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)


# ---------------------------------------------------------------- 小道具

func _mat(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _shader_mat(code: String, params: Dictionary = {}) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	return material


func _mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation_degrees = rotation_deg
	node.scale = scale
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, material, position, rotation_deg)


func _cyl(parent: Node3D, top: float, bottom: float, height: float, position: Vector3, material: Material, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(parent, mesh, material, position + Vector3(0.0, height * 0.5, 0.0))


func _sphere_mesh(radius: float, segments: int = 16) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	return mesh


## 同じ形をたくさん置く。colors が空なら、material の色のまま。
func _multi(parent: Node3D, mesh: Mesh, transforms: Array, colors: Array, material: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if material == null:
		var tinted := StandardMaterial3D.new()
		tinted.vertex_color_use_as_albedo = true
		tinted.roughness = 1.0
		material = tinted
	node.material_override = material
	parent.add_child(node)
	return node


func _pick(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]


## コースの中心線。s は、ホームストレートの手前の端（z=+263）からの道のり。[位置, 進む向き, 外側の向き]。
func _path_at(s: float) -> Array:
	var arc := PI * RADIUS
	var total := 2.0 * STRAIGHT + 2.0 * arc
	s = fposmod(s, total)
	var position := Vector3.ZERO
	var tangent := Vector3.ZERO
	if s < STRAIGHT:
		position = Vector3(0.0, 0.0, HALF_S - s)
		tangent = Vector3(0.0, 0.0, -1.0)
	elif s < STRAIGHT + arc:
		var a := (s - STRAIGHT) / RADIUS
		position = Vector3(-RADIUS + RADIUS * cos(a), 0.0, -HALF_S - RADIUS * sin(a))
		tangent = Vector3(-sin(a), 0.0, -cos(a))
	elif s < 2.0 * STRAIGHT + arc:
		position = Vector3(-2.0 * RADIUS, 0.0, -HALF_S + (s - STRAIGHT - arc))
		tangent = Vector3(0.0, 0.0, 1.0)
	else:
		var b := (s - 2.0 * STRAIGHT - arc) / RADIUS
		position = Vector3(-RADIUS - RADIUS * cos(b), 0.0, HALF_S + RADIUS * sin(b))
		tangent = Vector3(sin(b), 0.0, cos(b))
	return [position, tangent, tangent.cross(Vector3.UP).normalized()]


## 撮り方で「内側を空ける」と決めた範囲（ホームストレートの z）に入っているか。
func _in_open_inner(point: Vector3) -> bool:
	if not _shot.has("open_inner"):
		return false
	return point.x > -40.0 and point.z > float(_shot["open_inner"][0]) and point.z < float(_shot["open_inner"][1])


func _path_total() -> float:
	return 2.0 * STRAIGHT + 2.0 * PI * RADIUS


# ---------------------------------------------------------------- レース場

func _build_venue() -> void:
	_build_ground_and_track()
	_build_fences()
	_build_stands()
	_build_royal_box()
	_build_banners_and_bunting()
	_build_arch(GOAL_Z, "GOAL", true)
	_build_arch(START_Z, "START", false)
	_build_infield()
	_build_town_and_castle()
	_build_mountains_and_clouds()


func _build_ground_and_track() -> void:
	var grass := _shader_mat("shader_type spatial;\n" + NOISE_GLSL + """
uniform vec3 a : source_color;
uniform vec3 b : source_color;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wp.xz * 0.035) * 0.55 + vnoise(wp.xz * 0.21) * 0.3 + vnoise(wp.xz * 2.7) * 0.15;
	float stripe = step(0.5, fract(wp.z / 16.0)) * 0.05;
	ALBEDO = mix(a, b, n) * (1.0 + stripe);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
""", {"a": Color(0.33, 0.56, 0.27), "b": Color(0.5, 0.71, 0.34)})
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	_mesh(_world, plane, grass, Vector3(-RADIUS, -0.05, 0.0))
	# コース（土）。両端に白い線。
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var total := _path_total()
	var count := int(total / 2.0)
	for i in count + 1:
		var s := total * float(i) / float(count)
		var at := _path_at(s)
		for side: float in [-1.0, 1.0]:
			vertices.append((at[0] as Vector3) + (at[2] as Vector3) * side * TRACK_W * 0.5 + Vector3(0.0, 0.02, 0.0))
			normals.append(Vector3.UP)
			uvs.append(Vector2(side * 0.5 + 0.5, s))
		if i > 0:
			var k := i * 2
			indices.append_array([k - 2, k, k - 1, k - 1, k, k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon := ArrayMesh.new()
	ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var dirt := _shader_mat("shader_type spatial;\nrender_mode cull_disabled;\n" + NOISE_GLSL + """
uniform vec3 base : source_color;
uniform float width = 15.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wp.xz * 0.3) * 0.5 + vnoise(wp.xz * 1.9) * 0.3 + vnoise(wp.xz * 9.0) * 0.2;
	float rake = vnoise(vec2(UV.x * 46.0, UV.y * 0.12));
	vec3 c = base * (0.86 + 0.2 * n) * (0.95 + 0.1 * rake);
	float edge = min(UV.x, 1.0 - UV.x) * width;
	float line = 1.0 - smoothstep(0.09, 0.12, abs(edge - 0.45));
	c = mix(c, vec3(0.97, 0.96, 0.92), line * 0.92);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
""", {"base": Color(0.80, 0.63, 0.43)})
	var node := MeshInstance3D.new()
	node.mesh = ribbon
	node.material_override = dirt
	_world.add_child(node)


func _build_fences() -> void:
	var white := _mat(Color(0.97, 0.96, 0.93), 0.8)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 1.2, 0.16)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.07, 0.15, 1.0)
	var posts := []
	var rails := []
	var total := _path_total()
	var count := int(total / 3.0)
	for side: float in [-1.0, 1.0]:
		var offset := side * (TRACK_W * 0.5 + 0.7)
		var previous := Vector3.ZERO
		for i in count + 1:
			var at := _path_at(total * float(i) / float(count))
			var point: Vector3 = (at[0] as Vector3) + (at[2] as Vector3) * offset
			if side < 0.0 and _in_open_inner(point):
				previous = point
				continue
			posts.append(Transform3D(Basis.looking_at(at[1], Vector3.UP), point + Vector3(0.0, 0.6, 0.0)))
			if i > 0:
				var along := point - previous
				for height: float in [0.62, 1.08]:
					var basis := Basis.looking_at(along.normalized(), Vector3.UP).scaled_local(Vector3(1.0, 1.0, along.length()))
					rails.append(Transform3D(basis, (point + previous) * 0.5 + Vector3(0.0, height, 0.0)))
			previous = point
	_multi(_world, post_mesh, posts, [], white)
	_multi(_world, rail_mesh, rails, [], white)
	# 観客席の前の柵に、お祭りの布を掛ける。
	var drape_mesh := BoxMesh.new()
	drape_mesh.size = Vector3(0.04, 0.62, 2.7)
	var drapes := []
	var drape_colors := []
	var palette := [Color(0.80, 0.16, 0.2), Color(0.96, 0.95, 0.9), Color(0.16, 0.34, 0.72), Color(0.96, 0.95, 0.9)]
	var z := STAND_Z0
	var index := 0
	while z < STAND_Z1:
		drapes.append(Transform3D(Basis.IDENTITY, Vector3(TRACK_W * 0.5 + 0.82, 0.72, z + 1.5)))
		drape_colors.append(palette[index % palette.size()])
		index += 1
		z += 3.0
	_multi(_world, drape_mesh, drapes, drape_colors)


func _build_stands() -> void:
	var stone := _mat(Color(0.86, 0.81, 0.72))
	var step_material := _mat(Color(0.72, 0.6, 0.46))
	var wood := _mat(Color(0.45, 0.3, 0.19))
	var awning_code := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	ALBEDO = mix(a, b, step(0.5, fract(wp.z / 3.2)));
	ROUGHNESS = 1.0;
	// 布なので、裏からも少し明るく見せる。
	EMISSION = ALBEDO * 0.18;
}
"""
	var awnings := [
		_shader_mat(awning_code, {"a": Color(0.17, 0.36, 0.76), "b": Color(0.97, 0.96, 0.92)}),
		_shader_mat(awning_code, {"a": Color(0.82, 0.2, 0.22), "b": Color(0.97, 0.96, 0.92)}),
	]
	var bodies := []
	var body_colors := []
	var heads := []
	var head_colors := []
	var hairs := []
	var hair_colors := []
	var brims := []
	var crowns := []
	var hat_colors := []
	var blobs := []
	var blob_colors := []
	var eyes := []
	var flags := []
	var flag_colors := []
	var sticks := []
	var clothes := [Color(0.93, 0.9, 0.82), Color(0.25, 0.42, 0.72), Color(0.62, 0.3, 0.22), Color(0.3, 0.52, 0.34), Color(0.16, 0.22, 0.4), Color(0.85, 0.68, 0.28), Color(0.86, 0.5, 0.56), Color(0.97, 0.97, 0.95), Color(0.5, 0.36, 0.56), Color(0.78, 0.36, 0.2)]
	var skins := [Color(0.98, 0.84, 0.72), Color(0.93, 0.74, 0.6), Color(0.8, 0.6, 0.45), Color(0.62, 0.44, 0.32)]
	var hair_palette := [Color(0.3, 0.2, 0.13), Color(0.14, 0.11, 0.1), Color(0.78, 0.6, 0.3), Color(0.6, 0.3, 0.16), Color(0.5, 0.5, 0.52)]
	var hat_palette := [Color(0.88, 0.76, 0.48), Color(0.42, 0.28, 0.17), Color(0.18, 0.24, 0.42), Color(0.7, 0.2, 0.2)]
	var blob_palette := [Color("#4aa9e8"), Color("#e6533c"), Color("#64c878"), Color("#D8AD5C"), Color("#FF9EC0"), Color("#9B8CF0"), Color("#FFD24D"), Color("#5ED6D0")]
	var flag_palette := [Color(0.9, 0.2, 0.22), Color(0.2, 0.42, 0.85), Color(0.98, 0.84, 0.22), Color(0.97, 0.97, 0.95)]
	var rows := 8
	var row_depth := 1.15
	var row_rise := 0.6
	var front_x := 12.5
	var base_y := 1.3
	var block_len := 34.0
	var gap := 6.0
	var z := STAND_Z0
	var block_index := 0
	while z + block_len <= STAND_Z1 + 0.1:
		var royal := absf(z + block_len * 0.5 - GOAL_Z) < 12.0
		var mid_z := z + block_len * 0.5
		if not royal:
			_box(_world, Vector3(0.5, base_y, block_len), Vector3(front_x - 0.25, base_y * 0.5, mid_z), stone)
			for row in rows:
				var top := base_y + float(row) * row_rise
				_box(_world, Vector3(row_depth, top, block_len), Vector3(front_x + (float(row) + 0.5) * row_depth, top * 0.5, mid_z), step_material)
				var pz := z + 0.6
				while pz < z + block_len - 0.5:
					pz += _rng.randf_range(0.74, 0.92)
					if _rng.randf() < 0.07:
						continue
					var px := front_x + (float(row) + 0.55) * row_depth + _rng.randf_range(-0.1, 0.1)
					var foot := Vector3(px, top, pz)
					if _rng.randf() < 0.16:
						var size := _rng.randf_range(0.3, 0.42)
						var turn := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5))
						blobs.append(Transform3D(turn.scaled_local(Vector3(size, size * 0.78, size)), foot + Vector3(0.0, size * 0.55, 0.0)))
						blob_colors.append(_pick(blob_palette))
						for eye_side: float in [-1.0, 1.0]:
							eyes.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size * 0.14), foot + turn * Vector3(-size * 0.86, size * 0.62, eye_side * size * 0.36)))
						continue
					var tall := _rng.randf_range(0.88, 1.12)
					bodies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, tall, 1.0)), foot + Vector3(0.0, 0.4 * tall, 0.0)))
					body_colors.append(_pick(clothes))
					var head := foot + Vector3(0.0, 0.8 * tall + 0.13, 0.0)
					heads.append(Transform3D(Basis.IDENTITY, head))
					head_colors.append(_pick(skins))
					if _rng.randf() < 0.42:
						var hat: Color = _pick(hat_palette)
						brims.append(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.11, 0.0)))
						crowns.append(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.19, 0.0)))
						hat_colors.append(hat)
					else:
						hairs.append(Transform3D(Basis.IDENTITY, head + Vector3(0.035, 0.035, 0.0)))
						hair_colors.append(_pick(hair_palette))
					if _rng.randf() < 0.09:
						var lean := Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
						sticks.append(Transform3D(lean, foot + Vector3(-0.22, 1.05 * tall, 0.18)))
						flags.append(Transform3D(lean, foot + Vector3(-0.22, 1.05 * tall, 0.18) + lean * Vector3(0.0, 0.3, 0.2)))
						flag_colors.append(_pick(flag_palette))
			# 後ろの壁、柱、しま模様の屋根。
			var back_x := front_x + float(rows) * row_depth
			var back_top := base_y + float(rows) * row_rise + 1.2
			_box(_world, Vector3(0.5, back_top, block_len), Vector3(back_x + 0.25, back_top * 0.5, mid_z), stone)
			var roof_front := Vector3(front_x - 1.6, back_top + 2.6, mid_z)
			var roof_back := Vector3(back_x + 0.9, back_top + 4.4, mid_z)
			var slope := roof_back - roof_front
			var roof := BoxMesh.new()
			roof.size = Vector3(slope.length(), 0.12, block_len + 1.6)
			_mesh(_world, roof, awnings[block_index % 2], (roof_front + roof_back) * 0.5, Vector3(0.0, 0.0, rad_to_deg(atan2(slope.y, slope.x))))
			# 屋根の前に下げる、三角の飾り。
			_add_valance(roof_front, block_len + 1.6, block_index % 2 == 0)
			for end: float in [-0.5, 0.5]:
				var post_z := mid_z + end * (block_len - 0.4)
				_cyl(_world, 0.14, 0.16, roof_front.y, Vector3(front_x - 0.7, 0.0, post_z), wood, 8)
				_cyl(_world, 0.14, 0.16, roof_back.y, Vector3(back_x + 0.5, 0.0, post_z), wood, 8)
				_mesh(_world, _sphere_mesh(0.3, 12), _mat(Color(0.95, 0.78, 0.25), 0.4), Vector3(front_x - 0.7, roof_front.y + 0.5, post_z))
		z += block_len + gap
		block_index += 1
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.17
	body_mesh.bottom_radius = 0.25
	body_mesh.height = 0.8
	body_mesh.radial_segments = 8
	body_mesh.rings = 1
	_multi(_world, body_mesh, bodies, body_colors)
	_multi(_world, _sphere_mesh(0.17, 10), heads, head_colors)
	_multi(_world, _sphere_mesh(0.185, 10), hairs, hair_colors)
	var brim_mesh := CylinderMesh.new()
	brim_mesh.top_radius = 0.27
	brim_mesh.bottom_radius = 0.27
	brim_mesh.height = 0.035
	brim_mesh.radial_segments = 10
	brim_mesh.rings = 1
	_multi(_world, brim_mesh, brims, hat_colors)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.14
	crown_mesh.bottom_radius = 0.16
	crown_mesh.height = 0.16
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 1
	_multi(_world, crown_mesh, crowns, hat_colors)
	var blob_material := StandardMaterial3D.new()
	blob_material.vertex_color_use_as_albedo = true
	blob_material.roughness = 0.25
	blob_material.rim_enabled = true
	blob_material.rim = 0.6
	_multi(_world, _sphere_mesh(1.0, 14), blobs, blob_colors, blob_material)
	_multi(_world, _sphere_mesh(1.0, 8), eyes, [], _mat(Color(0.08, 0.08, 0.12), 0.3))
	var stick_mesh := BoxMesh.new()
	stick_mesh.size = Vector3(0.03, 0.7, 0.03)
	_multi(_world, stick_mesh, sticks, [], wood)
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.02, 0.26, 0.4)
	_multi(_world, flag_mesh, flags, flag_colors)


## 屋根の前のふちに下げる、三角の飾りの列。
func _add_valance(roof_front: Vector3, length: float, blue: bool) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var tooth := 1.6
	var count := int(length / tooth)
	var first := Color(0.17, 0.36, 0.76) if blue else Color(0.82, 0.2, 0.22)
	for i in count:
		var z0 := roof_front.z - length * 0.5 + float(i) * tooth
		var color := first if i % 2 == 0 else Color(0.97, 0.96, 0.92)
		vertices.append_array([Vector3(roof_front.x, roof_front.y, z0), Vector3(roof_front.x, roof_front.y, z0 + tooth), Vector3(roof_front.x, roof_front.y - 1.1, z0 + tooth * 0.5)])
		for _k in 3:
			colors.append(color)
			normals.append(Vector3(-1.0, 0.0, 0.0))
	_add_colored_triangles(vertices, normals, colors)


func _add_colored_triangles(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 1.0)
	material.emission_energy_multiplier = 0.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	_world.add_child(node)


## 王さまの観覧席。ゴールの正面。
func _build_royal_box() -> void:
	var stone := _mat(Color(0.9, 0.86, 0.78))
	var red := _mat(Color(0.78, 0.14, 0.18))
	var gold := _mat(Color(0.96, 0.78, 0.25), 0.35)
	var navy := _mat(Color(0.14, 0.24, 0.55))
	var center := Vector3(18.5, 0.0, GOAL_Z)
	_box(_world, Vector3(12.0, 4.4, 18.0), center + Vector3(0.0, 2.2, 0.0), stone)
	_box(_world, Vector3(12.6, 0.4, 18.6), center + Vector3(0.0, 4.5, 0.0), _mat(Color(0.8, 0.74, 0.64)))
	_box(_world, Vector3(0.3, 1.0, 18.6), center + Vector3(-6.2, 5.1, 0.0), navy)
	_box(_world, Vector3(0.34, 0.14, 18.7), center + Vector3(-6.2, 5.65, 0.0), gold)
	for corner_x: float in [-5.6, 5.6]:
		for corner_z: float in [-8.4, 8.4]:
			_cyl(_world, 0.2, 0.22, 6.2, center + Vector3(corner_x, 4.6, corner_z), gold, 10)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 12.6
	roof.height = 5.2
	roof.radial_segments = 4
	roof.rings = 1
	_mesh(_world, roof, red, center + Vector3(0.0, 13.4, 0.0), Vector3(0.0, 45.0, 0.0), Vector3(0.72, 1.0, 1.05))
	_box(_world, Vector3(12.8, 0.5, 18.9), center + Vector3(0.0, 10.85, 0.0), gold)
	_mesh(_world, _sphere_mesh(0.6, 14), gold, center + Vector3(0.0, 16.4, 0.0))
	# 前に下げる、紋章の旗。
	for i in 3:
		_add_banner(center + Vector3(-6.4, 4.3, (float(i) - 1.0) * 5.4), [Color(0.14, 0.24, 0.55), Color(0.78, 0.14, 0.18), Color(0.14, 0.24, 0.55)][i], 2.2, 3.6, Vector3(-1.0, 0.0, 0.0))
	# 王さまと、おきさき。
	for i in 2:
		var seat := center + Vector3(-3.6, 4.7, (float(i) - 0.5) * 2.4)
		_cyl(_world, 0.3, 0.55, 1.5, seat, [red, _mat(Color(0.3, 0.3, 0.75))][i], 12)
		_mesh(_world, _sphere_mesh(0.33, 14), _mat(Color(0.97, 0.84, 0.72)), seat + Vector3(0.0, 1.75, 0.0))
		_cyl(_world, 0.3, 0.26, 0.24, seat + Vector3(0.0, 1.98, 0.0), gold, 8)


## 紋章の旗の絵（四属性の4色の丸）。下は、二またに切れている。
func _banner_texture(color: Color) -> ImageTexture:
	var width := 128
	var height := 300
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var gold := Color(0.96, 0.8, 0.3)
	var dots := [[Vector2(64.0, 86.0), _attr_colors["fire"]], [Vector2(40.0, 112.0), _attr_colors["water"]], [Vector2(88.0, 112.0), _attr_colors["wind"]], [Vector2(64.0, 138.0), _attr_colors["earth"]]]
	for y in height:
		for x in width:
			var cut := 250.0 + absf(float(x) - 64.0) * 50.0 / 64.0
			if float(y) > cut:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var pixel := color
			if x < 7 or x >= width - 7 or y < 7 or float(y) > cut - 8.0:
				pixel = gold
			var here := Vector2(float(x), float(y))
			if here.distance_to(Vector2(64.0, 112.0)) < 50.0:
				pixel = Color(0.98, 0.97, 0.93)
			if absf(here.distance_to(Vector2(64.0, 112.0)) - 50.0) < 3.0:
				pixel = gold
			for dot: Array in dots:
				if here.distance_to(dot[0]) < 17.0:
					pixel = dot[1]
			image.set_pixel(x, y, pixel)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


var _banner_materials := {}


## 旗の布を1枚、上のふちのまん中が top になるように下げる。facing は、布の表の向き。
func _add_banner(top: Vector3, color: Color, width: float, height: float, facing: Vector3) -> void:
	var key := color.to_html()
	if not _banner_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = _banner_texture(color)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 1.0
		_banner_materials[key] = material
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = _banner_materials[key]
	_world.add_child(node)
	# QuadMesh の表は +Z。
	node.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), top + Vector3(0.0, -height * 0.5, 0.0))


## 2点のあいだに、たるんだひもと、三角の小旗を張る。
func _add_bunting(from: Vector3, to: Vector3, sag: float, palette: Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var span := from.distance_to(to)
	var count := maxi(int(span / 0.62), 4)
	var across := (to - from).normalized()
	var face := across.cross(Vector3.UP).normalized()
	for i in count:
		var t0 := float(i) / float(count)
		var t1 := float(i + 1) / float(count)
		var a := from.lerp(to, t0) - Vector3(0.0, sag * 4.0 * t0 * (1.0 - t0), 0.0)
		var b := from.lerp(to, t1) - Vector3(0.0, sag * 4.0 * t1 * (1.0 - t1), 0.0)
		var tip := (a + b) * 0.5 - Vector3(0.0, 0.62, 0.0)
		vertices.append_array([a, b, tip])
		for _k in 3:
			colors.append(palette[i % palette.size()])
			normals.append(face)
	_add_colored_triangles(vertices, normals, colors)


func _build_banners_and_bunting() -> void:
	var wood := _mat(Color(0.4, 0.27, 0.17))
	var gold := _mat(Color(0.96, 0.78, 0.25), 0.35)
	var palette := [Color(0.16, 0.3, 0.68), Color(0.78, 0.14, 0.18), Color(0.92, 0.45, 0.6), Color(0.12, 0.52, 0.5), Color(0.9, 0.62, 0.12)]
	var bunting := [Color(0.9, 0.2, 0.22), Color(0.98, 0.84, 0.22), Color(0.2, 0.45, 0.88), Color(0.97, 0.97, 0.95), Color(0.3, 0.72, 0.42), Color(0.96, 0.56, 0.72)]
	var total := _path_total()
	var spacing := 24.0
	var count := int(total / spacing)
	for side: float in [-1.0, 1.0]:
		var previous_top := Vector3.ZERO
		for i in count + 1:
			var at := _path_at(total * float(i) / float(count) + 9.0)
			var foot: Vector3 = (at[0] as Vector3) + (at[2] as Vector3) * side * (TRACK_W * 0.5 + 2.6)
			if side < 0.0 and _in_open_inner(foot):
				continue
			var pole_height := 7.4
			var top := foot + Vector3(0.0, pole_height, 0.0)
			_cyl(_world, 0.07, 0.1, pole_height, foot, wood, 8)
			_mesh(_world, _sphere_mesh(0.2, 10), gold, top + Vector3(0.0, 0.15, 0.0))
			# 横木と、旗。
			var arm: Vector3 = (at[2] as Vector3) * side
			var bar := BoxMesh.new()
			bar.size = Vector3(0.07, 0.07, 1.7)
			var bar_node := _mesh(_world, bar, wood, Vector3.ZERO)
			bar_node.transform = Transform3D(Basis.looking_at(arm, Vector3.UP), top + arm * 0.75 + Vector3(0.0, -0.5, 0.0))
			_add_banner(top + arm * 0.8 + Vector3(0.0, -0.55, 0.0), palette[i % palette.size()], 1.35, 3.2, at[1])
			if i > 0 and side > 0.0:
				_add_bunting(previous_top, top, 1.3, bunting)
			previous_top = top
	# ゴールの手前と先に、コースをまたぐ小旗のひも。
	for z: float in [GOAL_Z - 36.0, GOAL_Z + 48.0, START_Z - 40.0, START_Z + 44.0]:
		var left := Vector3(-(TRACK_W * 0.5 + 2.6), 9.0, z)
		var right := Vector3(TRACK_W * 0.5 + 2.6, 9.0, z)
		_cyl(_world, 0.08, 0.11, 9.0, Vector3(left.x, 0.0, z), wood, 8)
		_cyl(_world, 0.08, 0.11, 9.0, Vector3(right.x, 0.0, z), wood, 8)
		_add_bunting(left, right, 2.0, bunting)


func _checker_texture(columns: int, rows: int, a: Color, b: Color) -> ImageTexture:
	var image := Image.create(columns, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		for x in columns:
			image.set_pixel(x, y, a if (x + y) % 2 == 0 else b)
	return ImageTexture.create_from_image(image)


## コースをまたぐ門。ゴールは白黒の市松、スタートは青の幕。
func _build_arch(z: float, text: String, checker: bool) -> void:
	var wood := _mat(Color(0.46, 0.31, 0.2))
	var gold := _mat(Color(0.96, 0.78, 0.25), 0.35)
	var half := TRACK_W * 0.5 + 1.9
	var height := 9.2
	for side: float in [-1.0, 1.0]:
		_cyl(_world, 0.42, 0.5, height, Vector3(side * half, 0.0, z), wood, 12)
		_cyl(_world, 0.62, 0.62, 0.5, Vector3(side * half, 0.0, z), _mat(Color(0.82, 0.78, 0.7)), 12)
		_mesh(_world, _sphere_mesh(0.55, 14), gold, Vector3(side * half, height + 0.45, z))
	_box(_world, Vector3(half * 2.0, 0.3, 0.3), Vector3(0.0, height - 0.4, z), wood)
	_box(_world, Vector3(half * 2.0, 0.3, 0.3), Vector3(0.0, height - 2.6, z), wood)
	var cloth := StandardMaterial3D.new()
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if checker:
		cloth.albedo_texture = _checker_texture(20, 2, Color(0.97, 0.97, 0.95), Color(0.1, 0.11, 0.14))
	else:
		cloth.albedo_color = Color(0.16, 0.34, 0.74)
	for face: float in [-1.0, 1.0]:
		var quad := QuadMesh.new()
		quad.size = Vector2(half * 2.0 - 0.9, 1.9)
		_mesh(_world, quad, cloth, Vector3(0.0, height - 1.5, z + face * 0.17), Vector3(0.0, 0.0 if face > 0.0 else 180.0, 0.0))
		# まん中の札。
		var plate := _box(_world, Vector3(6.4, 2.5, 0.12), Vector3(0.0, height - 1.5, z + face * 0.24), _mat(Color(0.98, 0.96, 0.9)))
		plate.name = "Plate"
		_box(_world, Vector3(6.8, 2.9, 0.08), Vector3(0.0, height - 1.5, z + face * 0.2), gold)
		var label := Label3D.new()
		label.text = text
		label.font = load(FONT_PATH)
		label.font_size = 200
		label.pixel_size = 0.0085
		label.outline_size = 22
		label.modulate = Color(0.8, 0.14, 0.18) if checker else Color(0.14, 0.3, 0.7)
		label.outline_modulate = label.modulate
		label.position = Vector3(0.0, height - 1.55, z + face * 0.31)
		label.rotation_degrees = Vector3(0.0, 0.0 if face > 0.0 else 180.0, 0.0)
		_world.add_child(label)
	if not checker:
		for gate in 8:
			var gate_color: Color = GateBadge.GATE_COLORS[gate]
			for face: float in [-1.0, 1.0]:
				var board_at := Vector3(_gate_x(gate), height - 3.55, z + face * 0.2)
				_box(_world, Vector3(1.25, 1.25, 0.08), board_at - Vector3(0.0, 0.0, face * 0.05), gold)
				_box(_world, Vector3(1.08, 1.08, 0.1), board_at, _mat(gate_color))
				var number := Label3D.new()
				number.text = str(gate + 1)
				number.font = load(FONT_PATH)
				number.font_size = 128
				number.pixel_size = 0.0075
				number.outline_size = 14
				number.modulate = GateBadge.text_color_for(gate)
				number.outline_modulate = number.modulate
				number.position = board_at + Vector3(0.0, -0.03, face * 0.07)
				number.rotation_degrees = Vector3(0.0, 0.0 if face > 0.0 else 180.0, 0.0)
				_world.add_child(number)
	# 地面の線。
	var line := StandardMaterial3D.new()
	line.roughness = 1.0
	line.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if checker:
		line.albedo_texture = _checker_texture(30, 2, Color(0.97, 0.97, 0.95), Color(0.1, 0.11, 0.14))
	else:
		line.albedo_color = Color(0.97, 0.97, 0.95)
	var plane := PlaneMesh.new()
	plane.size = Vector2(TRACK_W, 1.0 if checker else 0.35)
	_mesh(_world, plane, line, Vector3(0.0, 0.035, z))


func _add_trees(positions: Array) -> void:
	var trunks := []
	var canopies := []
	var canopy_colors := []
	var greens := [Color(0.22, 0.5, 0.24), Color(0.28, 0.58, 0.26), Color(0.36, 0.64, 0.28), Color(0.2, 0.44, 0.26)]
	for at: Vector3 in positions:
		var size := _rng.randf_range(0.8, 1.5)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), at + Vector3(0.0, 1.3 * size, 0.0)))
		var green: Color = _pick(greens)
		for part: Array in [[Vector3(0.0, 4.2, 0.0), 2.3], [Vector3(1.5, 3.3, 0.5), 1.6], [Vector3(-1.3, 3.5, -0.6), 1.7], [Vector3(0.2, 5.6, 0.3), 1.5]]:
			var radius: float = float(part[1]) * size
			canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 0.92, radius)), at + (part[0] as Vector3) * size))
			canopy_colors.append(green.lightened(_rng.randf_range(0.0, 0.14)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.34
	trunk.height = 2.6
	trunk.radial_segments = 8
	trunk.rings = 1
	_multi(_world, trunk, trunks, [], _mat(Color(0.42, 0.28, 0.18)))
	_multi(_world, _sphere_mesh(1.0, 12), canopies, canopy_colors)


func _build_infield() -> void:
	var center := Vector3(-RADIUS, 0.0, 0.0)
	# 池。
	var pond := CylinderMesh.new()
	pond.top_radius = 1.0
	pond.bottom_radius = 1.0
	pond.height = 0.04
	pond.radial_segments = 40
	var water := _mat(Color(0.3, 0.62, 0.9), 0.08)
	water.metallic = 0.3
	_mesh(_world, pond, water, center + Vector3(10.0, 0.0, 30.0), Vector3.ZERO, Vector3(62.0, 1.0, 110.0))
	_mesh(_world, pond, _mat(Color(0.86, 0.8, 0.62)), center + Vector3(10.0, -0.02, 30.0), Vector3.ZERO, Vector3(66.0, 1.0, 114.0))
	var trees := []
	for _i in 420:
		var p := Vector3(_rng.randf_range(-RADIUS + 16.0, RADIUS - 16.0), 0.0, _rng.randf_range(-HALF_S - RADIUS + 20.0, HALF_S + RADIUS - 20.0))
		var world_p := center + p
		# コースの内側で、池とホームストレートのそばを避ける。
		var dz := maxf(absf(p.z) - HALF_S, 0.0)
		if sqrt(p.x * p.x + dz * dz) > RADIUS - 22.0:
			continue
		if Vector2((p.x - 10.0) / 74.0, (p.z - 30.0) / 124.0).length() < 1.0:
			continue
		if world_p.x > -46.0 and world_p.z > STAND_Z0 and world_p.z < STAND_Z1 + 60.0:
			continue
		trees.append(world_p)
	# 外側の並木と、遠くの森。
	for _i in 900:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(260.0, 1500.0)
		var p := center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance * 1.35)
		var dz := maxf(absf(p.z) - HALF_S, 0.0)
		if sqrt((p.x + RADIUS) * (p.x + RADIUS) + dz * dz) < RADIUS + 60.0:
			continue
		trees.append(p)
	_add_trees(trees)
	# ホームストレートの内側の、お祭りのテント。
	var tent_colors := [[Color(0.86, 0.22, 0.24), Color(0.97, 0.96, 0.92)], [Color(0.98, 0.8, 0.24), Color(0.97, 0.96, 0.92)], [Color(0.2, 0.44, 0.82), Color(0.97, 0.96, 0.92)], [Color(0.3, 0.68, 0.44), Color(0.97, 0.96, 0.92)]]
	var tent_code := """
shader_type spatial;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float angle = atan(lp.z, lp.x) / 6.2831853 + 0.5;
	ALBEDO = mix(a, b, step(0.5, fract(angle * 6.0)));
	ROUGHNESS = 1.0;
}
"""
	var index := 0
	var z := STAND_Z0 + 20.0
	while z < STAND_Z1 + 40.0:
		var pair: Array = tent_colors[index % tent_colors.size()]
		var at := Vector3(-22.0 - float(index % 3) * 7.0, 0.0, z + _rng.randf_range(-4.0, 4.0))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.4
		cone.height = 2.6
		cone.radial_segments = 12
		cone.rings = 1
		_mesh(_world, cone, _shader_mat(tent_code, {"a": pair[0], "b": pair[1]}), at + Vector3(0.0, 4.1, 0.0))
		var wall := CylinderMesh.new()
		wall.top_radius = 3.0
		wall.bottom_radius = 3.0
		wall.height = 2.8
		wall.radial_segments = 12
		wall.rings = 1
		_mesh(_world, wall, _shader_mat(tent_code, {"a": pair[1], "b": (pair[0] as Color).lightened(0.25)}), at + Vector3(0.0, 1.4, 0.0))
		_cyl(_world, 0.05, 0.05, 1.6, at + Vector3(0.0, 5.3, 0.0), _mat(Color(0.4, 0.27, 0.17)), 6)
		_box(_world, Vector3(0.03, 0.5, 0.9), at + Vector3(0.0, 6.6, 0.45), _mat(pair[0]))
		index += 1
		z += 31.0
	# 柵の内側の花だん。
	var flowers := []
	var flower_colors := []
	var petal := [Color(1.0, 0.98, 0.95), Color(1.0, 0.6, 0.72), Color(1.0, 0.86, 0.3), Color(0.72, 0.6, 1.0), Color(1.0, 0.45, 0.4)]
	var bushes := []
	var fz := STAND_Z0
	while fz < STAND_Z1 + 80.0:
		for _i in 26:
			var p := Vector3(-(TRACK_W * 0.5 + 4.6) + _rng.randf_range(-1.1, 1.1), 0.0, fz + _rng.randf_range(-4.5, 4.5))
			if _in_open_inner(p):
				continue
			bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 0.42, 0.55)), p + Vector3(0.0, 0.25, 0.0)))
			for _j in 3:
				flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.1, 0.16)), p + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.45, 0.66), _rng.randf_range(-0.35, 0.35))))
				flower_colors.append(_pick(petal))
		fz += 24.0
	_multi(_world, _sphere_mesh(1.0, 14), bushes, [], _mat(Color(0.3, 0.6, 0.3)))
	_multi(_world, _sphere_mesh(1.0, 10), flowers, flower_colors)


func _build_town_and_castle() -> void:
	var walls := []
	var wall_colors := []
	var roofs := []
	var roof_colors := []
	var wall_palette := [Color(0.96, 0.92, 0.82), Color(0.93, 0.86, 0.74), Color(0.98, 0.95, 0.9), Color(0.9, 0.82, 0.7)]
	var roof_palette := [Color(0.82, 0.36, 0.24), Color(0.88, 0.46, 0.26), Color(0.74, 0.3, 0.24), Color(0.28, 0.4, 0.66)]
	var hill := Vector3(-RADIUS - 60.0, 0.0, 1150.0)
	# 城の丘。
	_mesh(_world, _sphere_mesh(1.0, 32), _mat(Color(0.4, 0.64, 0.32)), hill + Vector3(0.0, -40.0, 0.0), Vector3.ZERO, Vector3(420.0, 150.0, 340.0))
	# 家並み（丘のふもと、観客席の向こう、コースの先）。
	var zones := [[hill + Vector3(0.0, 0.0, -260.0), Vector2(760.0, 220.0), 520], [Vector3(250.0, 0.0, -40.0), Vector2(360.0, 1000.0), 420], [Vector3(-RADIUS, 0.0, -HALF_S - RADIUS - 260.0), Vector2(900.0, 300.0), 320]]
	for zone: Array in zones:
		var extent: Vector2 = zone[1]
		var pitch := 21.0
		var gx := -extent.x * 0.5
		while gx < extent.x * 0.5:
			var gz := -extent.y * 0.5
			while gz < extent.y * 0.5:
				gz += pitch
				# 6軒ごとに、通りを空ける。
				if int(round(gz / pitch)) % 6 == 0 or int(round(gx / pitch)) % 5 == 0 or _rng.randf() < 0.14:
					continue
				var p: Vector3 = (zone[0] as Vector3) + Vector3(gx + _rng.randf_range(-2.0, 2.0), 0.0, gz + _rng.randf_range(-2.0, 2.0))
				if p.x > 8.0 and p.x < 52.0:
					continue
				var w := _rng.randf_range(11.0, 16.0)
				var h := _rng.randf_range(7.0, 13.0)
				var d := _rng.randf_range(11.0, 16.0)
				var turn := Basis(Vector3.UP, _rng.randf_range(-0.06, 0.06) + (PI * 0.5 if _rng.randf() < 0.5 else 0.0))
				walls.append(Transform3D(turn.scaled_local(Vector3(w, h, d)), p + Vector3(0.0, h * 0.5, 0.0)))
				wall_colors.append(_pick(wall_palette))
				var roof_h := _rng.randf_range(5.0, 8.0)
				roofs.append(Transform3D(turn.scaled_local(Vector3(w + 1.6, roof_h, d + 1.6)), p + Vector3(0.0, h + roof_h * 0.5, 0.0)))
				roof_colors.append(_pick(roof_palette))
			gx += pitch
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_multi(_world, unit, walls, wall_colors)
	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	_multi(_world, prism, roofs, roof_colors)
	# 城。
	var stone := _mat(Color(0.95, 0.93, 0.88))
	var blue := _mat(Color(0.24, 0.4, 0.74))
	var top := hill + Vector3(0.0, 104.0, 0.0)
	_box(_world, Vector3(150.0, 44.0, 90.0), top + Vector3(0.0, 22.0, 0.0), stone)
	_box(_world, Vector3(90.0, 30.0, 60.0), top + Vector3(0.0, 59.0, 0.0), stone)
	var keep_roof := PrismMesh.new()
	keep_roof.size = Vector3(96.0, 26.0, 66.0)
	_mesh(_world, keep_roof, blue, top + Vector3(0.0, 87.0, 0.0))
	var towers := [[Vector3(-80.0, 0.0, -40.0), 17.0, 84.0], [Vector3(80.0, 0.0, -40.0), 17.0, 84.0], [Vector3(-48.0, 0.0, -34.0), 12.0, 118.0], [Vector3(52.0, 0.0, -30.0), 13.0, 132.0], [Vector3(0.0, 0.0, 0.0), 16.0, 170.0], [Vector3(-112.0, 0.0, 10.0), 13.0, 60.0], [Vector3(112.0, 0.0, 10.0), 13.0, 60.0]]
	for tower: Array in towers:
		var radius: float = tower[1]
		var tall: float = tower[2]
		var base: Vector3 = top + (tower[0] as Vector3)
		_cyl(_world, radius, radius * 1.06, tall, base, stone, 14)
		_cyl(_world, radius * 1.18, radius * 1.18, 5.0, base + Vector3(0.0, tall - 5.0, 0.0), stone, 14)
		_cyl(_world, 0.0, radius * 1.3, radius * 2.6, base + Vector3(0.0, tall, 0.0), blue, 14)
		_cyl(_world, 0.5, 0.5, 14.0, base + Vector3(0.0, tall + radius * 2.6, 0.0), _mat(Color(0.4, 0.3, 0.2)), 6)
		_box(_world, Vector3(11.0, 6.0, 0.4), base + Vector3(5.5, tall + radius * 2.6 + 10.5, 0.0), _mat(Color(0.86, 0.2, 0.24)))
	# 城下町の壁と、塔。
	var wall_z := hill.z - 400.0
	_box(_world, Vector3(1300.0, 20.0, 9.0), Vector3(hill.x, 10.0, wall_z), _mat(Color(0.88, 0.84, 0.76)))
	for i in 9:
		var tx := hill.x - 640.0 + float(i) * 160.0
		_cyl(_world, 14.0, 15.0, 34.0, Vector3(tx, 0.0, wall_z), _mat(Color(0.9, 0.86, 0.78)), 12)
		_cyl(_world, 0.0, 17.0, 22.0, Vector3(tx, 34.0, wall_z), [blue, _mat(Color(0.8, 0.34, 0.24))][i % 2], 12)


func _build_mountains_and_clouds() -> void:
	var mountains := []
	var mountain_colors := []
	for i in 70:
		var angle := float(i) / 70.0 * TAU + _rng.randf_range(-0.05, 0.05)
		var distance := _rng.randf_range(3200.0, 4600.0)
		var tall := _rng.randf_range(260.0, 640.0)
		var wide := tall * _rng.randf_range(2.2, 3.6)
		mountains.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(wide, tall, wide * _rng.randf_range(0.7, 1.3))), Vector3(-RADIUS + cos(angle) * distance, tall * 0.5 - 20.0, sin(angle) * distance)))
		mountain_colors.append(Color(0.4, 0.54, 0.76).lerp(Color(0.46, 0.64, 0.62), _rng.randf()))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	_multi(_world, cone, mountains, mountain_colors)
	# 手前の、なだらかな丘。
	var hills := []
	var hill_colors := []
	for i in 40:
		var angle := float(i) / 40.0 * TAU + _rng.randf_range(-0.07, 0.07)
		var distance := _rng.randf_range(1900.0, 2700.0)
		var wide := _rng.randf_range(420.0, 800.0)
		hills.append(Transform3D(Basis.IDENTITY.scaled(Vector3(wide, _rng.randf_range(90.0, 210.0), wide)), Vector3(-RADIUS + cos(angle) * distance, -30.0, sin(angle) * distance)))
		hill_colors.append(Color(0.36, 0.6, 0.34).lerp(Color(0.5, 0.72, 0.4), _rng.randf()))
	_multi(_world, _sphere_mesh(1.0, 24), hills, hill_colors)
	var cloud_material := _shader_mat("""
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 shade : source_color;
uniform vec3 lit : source_color;
varying float up;
void vertex() { up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y; }
void fragment() { ALBEDO = mix(shade, lit, smoothstep(-0.7, 0.55, up)); }
""", {"shade": _shot.get("cloud_shade", Color(0.72, 0.84, 0.98)), "lit": _shot.get("cloud_lit", Color(1.0, 1.0, 1.0))})
	var puffs := []
	for i in 30:
		var angle := float(i) / 30.0 * TAU + _rng.randf_range(-0.08, 0.08)
		var distance := _rng.randf_range(2200.0, 3600.0)
		var base := Vector3(-RADIUS + cos(angle) * distance, _rng.randf_range(420.0, 1250.0), sin(angle) * distance)
		var size := _rng.randf_range(100.0, 230.0)
		var along := Vector3(-sin(angle), 0.0, cos(angle))
		for j in 8:
			var shift := along * (float(j) - 3.5) * size * 0.55 + Vector3(0.0, _rng.randf_range(0.0, 0.5) * size * (1.0 - absf(float(j) - 3.5) / 4.0), 0.0)
			var radius := size * _rng.randf_range(0.55, 1.0) * (1.0 - absf(float(j) - 3.5) / 6.0)
			puffs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 0.72, radius)), base + shift))
	_multi(_world, _sphere_mesh(1.0, 20), puffs, [], cloud_material)


# ---------------------------------------------------------------- ぷるりん

func _add_runner(spec: Dictionary) -> void:
	var holder := Node3D.new()
	_world.add_child(holder)
	var hop := float(spec.get("hop", 0.0))
	holder.position = Vector3(float(spec["x"]), hop, float(spec["z"]))
	holder.rotation_degrees = Vector3(0.0, float(spec.get("yaw", 0.0)), 0.0)
	var tilt := Node3D.new()
	holder.add_child(tilt)
	# 前へ少し傾ける（正面は −Z）。はねている個体は、たてに少しのびる。
	tilt.rotation_degrees = Vector3(-float(spec.get("lean", 0.0)), 0.0, float(spec.get("roll", 0.0)))
	var stretch := 1.0 + hop * 0.5
	tilt.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch)) * float(spec.get("scale", 1.0))
	var body: Node3D = Builder.build(LookConfig.look_for(str(spec["id"])), LookConfig.values())
	tilt.add_child(body)
	body.call("set_expression", str(spec.get("expr", "normal")))
	body.call("set_action", str(spec.get("action", "idle")))
	body.set_process(false)
	_runners.append({"body": body, "time_scale": _rng.randf_range(0.6, 1.5)})
	if bool(spec.get("dust", true)) and str(spec.get("action", "idle")) != "idle":
		_add_dust(holder, hop)


## 走っているぷるりんの後ろの、土けむり。
func _add_dust(holder: Node3D, hop: float) -> void:
	var material := _shader_mat("""
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never;
uniform vec4 tint : source_color;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * pow(facing, 2.2);
}
""", {"tint": Color(0.93, 0.82, 0.66, 0.36)})
	for i in 5:
		var radius := _rng.randf_range(0.2, 0.42) * (1.0 + float(i) * 0.12)
		var at := Vector3(_rng.randf_range(-0.6, 0.6), radius * 0.7 - hop, 0.75 + float(i) * 0.38 + _rng.randf_range(0.0, 0.3))
		_mesh(holder, _sphere_mesh(radius, 12), material, at)


func _add_confetti(spec: Dictionary) -> void:
	var pieces := []
	var colors := []
	var palette := [Color(1.0, 0.36, 0.42), Color(1.0, 0.84, 0.25), Color(0.3, 0.62, 1.0), Color(0.4, 0.84, 0.5), Color(1.0, 0.6, 0.8), Color(1.0, 1.0, 1.0)]
	var center: Vector3 = spec["center"]
	var extent: Vector3 = spec["extent"]
	for _i in int(spec["count"]):
		var basis := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		pieces.append(Transform3D(basis, center + Vector3(_rng.randf_range(-1.0, 1.0) * extent.x, _rng.randf_range(-1.0, 1.0) * extent.y, _rng.randf_range(-1.0, 1.0) * extent.z)))
		colors.append(_pick(palette))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.11)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 1.0)
	material.emission_energy_multiplier = 0.08
	_multi(_world, quad, pieces, colors, material)
