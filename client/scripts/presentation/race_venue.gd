extends RefCounted
## レース場の景色。コースの形（Path の曲線）に合わせて、柵、観客席、王さまの席、旗、テント、
## 木、池、城下町、城、丘、山、雲を置く。ゴールの門、スタートのゲート、距離の標識は、別の部品。
## 置き場所は毎回同じ（決まった種の乱数）。生成ノードの寿命は配置先Pathが所有する。

const Parts := preload("res://scripts/presentation/venue_parts.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")

const ROOT_NAME := "RaceVenue"
const RANDOM_SEED := 20261009
## 柵の柱の間隔（m）と、横板の高さ（地面から。下と上）。
const FENCE_POST_SPACING_M := 3.0
const FENCE_RAIL_HEIGHTS_M := [0.62, 1.08]
## 旗のポール。コースの中心線からの距離、間隔、高さ。
const POLE_SIDE_OFFSET_M := 10.1
const POLE_SPACING_M := 24.0
const POLE_HEIGHT_M := 7.4
const POLE_BANNER_SIZE_M := Vector2(1.35, 3.2)
const POLE_BUNTING_SAG_M := 1.3
const BANNER_COLORS := [Color(0.16, 0.3, 0.68), Color(0.78, 0.14, 0.18), Color(0.92, 0.45, 0.6), Color(0.12, 0.52, 0.5), Color(0.9, 0.62, 0.12)]
## 観客席。ゴールより先（進む向き）と、手前（走者が来る側）の長さ。直線の端には、必ずこれだけ空ける。
const STAND_PAST_GOAL_M := 70.0
const STAND_BEFORE_GOAL_M := 250.0
const STAND_STRAIGHT_END_MARGIN_M := 20.0
const STAND_BLOCK_LENGTH_M := 34.0
const STAND_BLOCK_GAP_M := 6.0
## 観客席の前の壁。コースの中心線からの距離と、高さ。
const STAND_FRONT_OFFSET_M := 12.5
const STAND_BASE_HEIGHT_M := 1.3
const STAND_ROWS := 8
const STAND_ROW_DEPTH_M := 1.15
const STAND_ROW_RISE_M := 0.6
## 王さまの席（ゴールの正面）。奥行きと、横幅。
const ROYAL_BOX_SIZE_M := Vector2(12.0, 18.0)
## 王さまと、おきさき。席の前のふちから台のまん中まで、台の大きさ（奥行き・高さ・横幅）、2人の間隔、体の高さ、頭の半径。
const ROYAL_SEAT_FROM_FRONT_M := 2.1
const ROYAL_DAIS_SIZE_M := Vector3(3.2, 0.9, 7.6)
const ROYAL_SPACING_M := 3.4
const ROYAL_BODY_HEIGHT_M := 2.1
const ROYAL_HEAD_RADIUS_M := 0.5
## 助走の直線（スタート専用の直線）のまわりに、物を置かない幅（中心線から）。
const LAUNCH_CLEAR_HALF_WIDTH_M := 14.0
## 遠くの景色の距離（コースの中心から）。カメラの見える距離（4000m）に収める。
const HILL_RING_M := Vector2(1800.0, 2400.0)
const MOUNTAIN_RING_M := Vector2(2600.0, 3200.0)
const CLOUD_RING_M := Vector2(2000.0, 3000.0)
## 城の丘の場所（コースの中心から。x＝ホームストレートを進む向き、y＝ホームストレートの外側）。
const CASTLE_HILL_AT_M := Vector2(1250.0, 75.0)
## 城の丘の半径（進む向き、横）と、丘のまん中から城下町の壁までの距離（レース場の側）。
const CASTLE_HILL_RADIUS_M := Vector2(420.0, 340.0)
const CASTLE_WALL_AHEAD_M := 650.0
## 観客席の向こうの家並みが始まる所（コースの中心線から）。
const TOWN_FROM_TRACK_M := 110.0

var _track: Path3D
var _root: Node3D
## ゴールを基準にした置き場所。x＝外側、y＝上、z＝手前（走者が来る側）。
var _home: Node3D
## コースの中心を基準にした置き場所。x＝ホームストレートの外側、y＝上、z＝ホームストレートを進む向きの逆。
var _field: Node3D
var _rng := RandomNumberGenerator.new()
var _lap := 0.0
var _straight := 0.0
var _radius := 0.0
var _goal_path := 0.0
## 助走の直線。全部のルートのぶん（物を置かない）と、今のルートのぶん（柵を開ける）。
var _launch_strips: Array = []
var _open_strips: Array = []
## 立てた柵の柱の位置（足元。Path の中の座標）。
var _fence_post_positions: Array[Vector3] = []


## 助走の直線の一覧。1つぶん：join（本線につながる点）、travel（進む向き）、length（長さ）。
static func launch_strips(curve: Curve3D, routes: Array, lap_length_m: float) -> Array:
	var strips := []
	for route: Dictionary in routes:
		var segments: Array = route.get("segments", [])
		if segments.is_empty() or str(segments[0].get("type", "")) != "straight":
			continue
		var xf := curve.sample_baked_with_rotation(fposmod(float(route.get("start_mainline_m", 0.0)), lap_length_m))
		var travel := -xf.basis.z
		travel.y = 0.0
		strips.append({"join": xf.origin, "travel": travel.normalized(), "length": float(segments[0].get("distance_m", 0.0))})
	return strips


## 点が、助走の直線の帯（中心線から half_width_m まで）に入っているか。
static func in_strip(point: Vector3, strip: Dictionary, half_width_m: float) -> bool:
	var travel: Vector3 = strip["travel"]
	var from_join: Vector3 = point - (strip["join"] as Vector3)
	var along := from_join.dot(travel)
	var across := from_join.dot(Vector3(-travel.z, 0.0, travel.x))
	return along <= 0.0 and along >= -float(strip["length"]) and absf(across) < half_width_m


## コースの中心線までの距離（コースの外は正、内側は負）。along は直線の向き、across はその横（どちらも、コースの中心から）。
static func distance_outside_track(along: float, across: float, straight_m: float, radius_m: float) -> float:
	var beyond := maxf(absf(along) - straight_m * 0.5, 0.0)
	return sqrt(beyond * beyond + across * across) - radius_m


## 観客席のかたまりの、まん中の位置（ゴールを0として、手前が正）。王さまの席にかかる所は、空ける。
static func stand_block_centers(before_goal_m: float, past_goal_m: float) -> Array[float]:
	var centers: Array[float] = []
	var pitch := STAND_BLOCK_LENGTH_M + STAND_BLOCK_GAP_M
	var royal_half := ROYAL_BOX_SIZE_M.y * 0.5 + STAND_BLOCK_GAP_M
	# 王さまの席の両どなりから、外へ並べる。
	var at := royal_half + STAND_BLOCK_LENGTH_M * 0.5
	while at + STAND_BLOCK_LENGTH_M * 0.5 <= before_goal_m:
		centers.append(at)
		at += pitch
	at = -royal_half - STAND_BLOCK_LENGTH_M * 0.5
	while at - STAND_BLOCK_LENGTH_M * 0.5 >= -past_goal_m:
		centers.append(at)
		at -= pitch
	return centers


## layout は、コースの定義（shared/course_layout_m5.json）。route は、今のレースのルート。
## ground_material は、シーンの地面の素材（外へ広げる地面にも、同じものを使う）。
func place(track: Path3D, ground_material: Material, layout: Dictionary, route: Dictionary) -> void:
	assert(_track == null or _track == track, "RaceVenueは配置先Pathごとに作成してください")
	if track == null or track.curve == null or layout.is_empty() or route.is_empty():
		return
	_track = track
	_lap = float(layout["track_length_m"])
	_straight = float(layout["straight_length_m"])
	_radius = float(layout["turn_radius_m"])
	_goal_path = float(layout["goal_path_m"])
	_launch_strips = launch_strips(track.curve, layout["routes"], _lap)
	_open_strips = launch_strips(track.curve, [route], _lap)
	_rng.seed = RANDOM_SEED
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_root.name = ROOT_NAME
	track.add_child(_root)
	var goal := _pose(_goal_path)
	_home = Node3D.new()
	_home.name = "HomeStraight"
	_home.transform = Parts.frame_at(goal[0], goal[1])
	_root.add_child(_home)
	_field = Node3D.new()
	_field.name = "Field"
	_field.transform = Parts.frame_at(_course_center(), goal[1])
	_root.add_child(_field)
	_build_ground(ground_material)
	_build_fences()
	_build_poles()
	_build_stands()
	_build_royal_box()
	_build_tents_and_flowers()
	_build_pond_and_trees()
	_build_town_and_castle()
	_build_far_scenery()


## 本線の上の1点。[位置, 進む向き, 外側の向き]。
func _pose(path_distance: float) -> Array:
	var xf := _track.curve.sample_baked_with_rotation(fposmod(path_distance, _lap))
	var travel := -xf.basis.z
	travel.y = 0.0
	travel = travel.normalized()
	return [xf.origin, travel, Vector3(-travel.z, 0.0, travel.x)]


func _course_center() -> Vector3:
	var points := _track.curve.get_baked_points()
	var sum := Vector3.ZERO
	for point in points:
		sum += point
	return sum / maxf(float(points.size()), 1.0)


func _pick(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]


func _near_launch_strip(point: Vector3) -> bool:
	for strip: Dictionary in _launch_strips:
		if in_strip(point, strip, LAUNCH_CLEAR_HALF_WIDTH_M):
			return true
	return false


## _field の中の点（along＝進む向き、across＝外側）を、_field の座標にする。
func _field_point(along: float, across: float, height: float = 0.0) -> Vector3:
	return Vector3(across, height, -along)


## 観客席の、手前の端と、先の端（ゴールを0として）。直線からはみ出さない。
func _stand_range() -> Vector2:
	var before := minf(STAND_BEFORE_GOAL_M, _goal_path - STAND_STRAIGHT_END_MARGIN_M)
	var past := minf(STAND_PAST_GOAL_M, _straight - _goal_path - STAND_STRAIGHT_END_MARGIN_M)
	return Vector2(before, past)


# ---------------------------------------------------------------- 地面と柵

## シーンの地面の外へ、同じ色の地面を広げる（少し下に置いて、重なりのちらつきを防ぐ）。
func _build_ground(ground_material: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000.0, 9000.0)
	var node := Parts.mesh(_root, plane, ground_material, _course_center() + Vector3(0.0, Parts.GROUND_Y_M - 0.25, 0.0))
	node.name = "WideGround"


## 立てた柵の柱の位置（足元。Path の中の座標）。
func fence_post_positions() -> Array[Vector3]:
	return _fence_post_positions


func _build_fences() -> void:
	_fence_post_positions.clear()
	var posts := []
	var rails := []
	var count := int(round(_lap / FENCE_POST_SPACING_M))
	for side: float in [-1.0, 1.0]:
		var line := []
		for i in count + 1:
			var at := _pose(_lap * float(i) / float(count))
			var point: Vector3 = (at[0] as Vector3) + (at[2] as Vector3) * side * Parts.FENCE_SIDE_OFFSET_M
			# 今のルートが助走の直線を使うときは、外側の柵を、そこだけ開ける。
			var blocked := false
			if side > 0.0:
				for strip: Dictionary in _open_strips:
					blocked = blocked or in_strip(point, strip, Parts.FENCE_SIDE_OFFSET_M + 0.05)
			line.append(null if blocked else point)
		_add_fence_line(line, posts, rails, true)
	# 助走の直線の両脇の柵。本線の柵の外にある所だけ。
	for strip: Dictionary in _open_strips:
		var travel: Vector3 = strip["travel"]
		var outward := Vector3(-travel.z, 0.0, travel.x)
		var steps := int(ceil(float(strip["length"]) / FENCE_POST_SPACING_M))
		for side: float in [-1.0, 1.0]:
			var line := []
			# 本線の柵とつながるように、つなぎ目の先まで、1本ぶん延ばす。
			for i in steps + 2:
				var point: Vector3 = (strip["join"] as Vector3) - travel * float(strip["length"]) * (1.0 - float(i) / float(steps)) + outward * side * Parts.FENCE_SIDE_OFFSET_M
				var from_track := point.distance_to(_track.curve.get_closest_point(point))
				line.append(point if from_track >= Parts.FENCE_SIDE_OFFSET_M - 0.05 else null)
			_add_fence_line(line, posts, rails, false)
	var white := Parts.material(Parts.COLOR_WHITE, 0.8)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, Parts.FENCE_HEIGHT_M, 0.16)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.07, 0.15, 1.0)
	Parts.multi(_root, post_mesh, posts, [], white).name = "FencePosts"
	Parts.multi(_root, rail_mesh, rails, [], white).name = "FenceRails"


## 点の並び（null は、柵を切る所）から、柱と横板の置き方を足す。
## closed は、最後の点が最初の点と同じ（1周してつながる）とき。最後の柱は、立てない。
func _add_fence_line(line: Array, posts: Array, rails: Array, closed: bool) -> void:
	var ground := Vector3(0.0, Parts.GROUND_Y_M, 0.0)
	for i in line.size():
		if line[i] == null:
			continue
		var point: Vector3 = line[i]
		if not (closed and i == line.size() - 1):
			_fence_post_positions.append(point + ground)
			posts.append(Transform3D(Basis.IDENTITY, point + ground + Vector3(0.0, Parts.FENCE_HEIGHT_M * 0.5, 0.0)))
		if i == 0 or line[i - 1] == null:
			continue
		var along: Vector3 = point - (line[i - 1] as Vector3)
		for height: float in FENCE_RAIL_HEIGHTS_M:
			var basis := Basis.looking_at(along.normalized(), Vector3.UP).scaled_local(Vector3(1.0, 1.0, along.length()))
			rails.append(Transform3D(basis, (point + (line[i - 1] as Vector3)) * 0.5 + ground + Vector3(0.0, height, 0.0)))


## コースの両脇の、紋章の旗のポール。外側は、ポールの先を、小旗のひもでつなぐ。
func _build_poles() -> void:
	var wood := Parts.material(Parts.COLOR_WOOD_DARK)
	var count := int(round(_lap / POLE_SPACING_M))
	var spacing := _lap / float(count)
	var pole_mesh := Parts.cylinder_mesh(0.07, 0.1, POLE_HEIGHT_M, 8)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.07, 0.07, 1.7)
	var poles := []
	var knobs := []
	var bars := []
	var ground := Vector3(0.0, Parts.GROUND_Y_M, 0.0)
	for side: float in [-1.0, 1.0]:
		# ポールの先（立てなかった所は null）。
		var tops := []
		for i in count:
			# ゴールの門の柱に当たらないように、ゴールからは半分ずらす。
			var at := _pose(_goal_path + (float(i) + 0.5) * spacing)
			var foot: Vector3 = (at[0] as Vector3) + (at[2] as Vector3) * side * POLE_SIDE_OFFSET_M + ground
			if _near_launch_strip(foot):
				tops.append(null)
				continue
			var top := foot + Vector3(0.0, POLE_HEIGHT_M, 0.0)
			tops.append(top)
			poles.append(Transform3D(Basis.IDENTITY, foot + Vector3(0.0, POLE_HEIGHT_M * 0.5, 0.0)))
			knobs.append(Transform3D(Basis.IDENTITY, top + Vector3(0.0, 0.15, 0.0)))
			# 横木と、旗（進む向きに面を向ける）。
			var arm: Vector3 = (at[2] as Vector3) * side
			bars.append(Transform3D(Basis.looking_at(arm, Vector3.UP), top + arm * 0.75 + Vector3(0.0, -0.5, 0.0)))
			Parts.banner(_root, top + arm * 0.8 + Vector3(0.0, -0.55, 0.0), BANNER_COLORS[i % BANNER_COLORS.size()], POLE_BANNER_SIZE_M.x, POLE_BANNER_SIZE_M.y, at[1])
		if side > 0.0:
			for i in count:
				var next: Variant = tops[(i + 1) % count]
				if tops[i] == null or next == null:
					continue
				# 王さまの席の前には、張らない（王さまと、おきさきが隠れるため）。
				var middle: Vector3 = _home.transform.affine_inverse() * (((tops[i] as Vector3) + (next as Vector3)) * 0.5)
				if absf(middle.z) < ROYAL_BOX_SIZE_M.y * 0.5:
					continue
				Parts.bunting(_root, tops[i], next, POLE_BUNTING_SAG_M)
	Parts.multi(_root, pole_mesh, poles, [], wood).name = "Poles"
	Parts.multi(_root, Parts.sphere_mesh(0.2, 10), knobs, [], Parts.gold())
	Parts.multi(_root, bar_mesh, bars, [], wood)


# ---------------------------------------------------------------- 観客席

func _build_stands() -> void:
	var stone := Parts.material(Parts.COLOR_STONE)
	var step_material := Parts.material(Color(0.72, 0.6, 0.46))
	var wood := Parts.material(Parts.COLOR_WOOD_DARK)
	var awning_shader := Shader.new()
	awning_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 first : source_color;
uniform vec3 second : source_color;
varying float along;
void vertex() { along = VERTEX.z; }
void fragment() {
	ALBEDO = mix(first, second, step(0.5, fract(along / 3.2)));
	ROUGHNESS = 1.0;
	// 布なので、裏からも少し明るく見せる。
	EMISSION = ALBEDO * 0.18;
}
"""
	var awning_colors := [Color(0.17, 0.36, 0.76), Color(0.82, 0.2, 0.22)]
	var awnings := []
	for color: Color in awning_colors:
		var awning := ShaderMaterial.new()
		awning.shader = awning_shader
		awning.set_shader_parameter("first", color)
		awning.set_shader_parameter("second", Parts.COLOR_WHITE)
		awnings.append(awning)
	var crowd := {
		"bodies": [], "body_colors": [], "heads": [], "head_colors": [], "hairs": [], "hair_colors": [],
		"brims": [], "crowns": [], "hat_colors": [], "blobs": [], "blob_colors": [], "eyes": [],
		"flags": [], "flag_colors": [], "sticks": [],
	}
	var ground := Parts.GROUND_Y_M
	var range_m := _stand_range()
	var centers := stand_block_centers(range_m.x, range_m.y)
	var back_x := STAND_FRONT_OFFSET_M + float(STAND_ROWS) * STAND_ROW_DEPTH_M
	var back_top := STAND_BASE_HEIGHT_M + float(STAND_ROWS) * STAND_ROW_RISE_M + 1.2
	for block_index in centers.size():
		var mid_z: float = centers[block_index]
		var length := STAND_BLOCK_LENGTH_M
		Parts.box(_home, Vector3(0.5, STAND_BASE_HEIGHT_M - ground, length), Vector3(STAND_FRONT_OFFSET_M - 0.25, (STAND_BASE_HEIGHT_M + ground) * 0.5, mid_z), stone)
		for row in STAND_ROWS:
			var top := STAND_BASE_HEIGHT_M + float(row) * STAND_ROW_RISE_M
			Parts.box(_home, Vector3(STAND_ROW_DEPTH_M, top - ground, length), Vector3(STAND_FRONT_OFFSET_M + (float(row) + 0.5) * STAND_ROW_DEPTH_M, (top + ground) * 0.5, mid_z), step_material)
			_seat_row(crowd, STAND_FRONT_OFFSET_M + (float(row) + 0.55) * STAND_ROW_DEPTH_M, top, mid_z - length * 0.5, mid_z + length * 0.5)
		# 後ろの壁、柱、しま模様の屋根。
		Parts.box(_home, Vector3(0.5, back_top - ground, length), Vector3(back_x + 0.25, (back_top + ground) * 0.5, mid_z), stone)
		var roof_front := Vector3(STAND_FRONT_OFFSET_M - 1.6, back_top + 2.6, mid_z)
		var roof_back := Vector3(back_x + 0.9, back_top + 4.4, mid_z)
		var slope := roof_back - roof_front
		var roof := BoxMesh.new()
		roof.size = Vector3(slope.length(), 0.12, length + 1.6)
		Parts.mesh(_home, roof, awnings[block_index % 2], (roof_front + roof_back) * 0.5, Vector3(0.0, 0.0, rad_to_deg(atan2(slope.y, slope.x))))
		_add_valance(roof_front, length + 1.6, awning_colors[block_index % 2])
		for end: float in [-0.5, 0.5]:
			var post_z := mid_z + end * (length - 0.4)
			Parts.cylinder(_home, 0.14, 0.16, roof_front.y - ground, Vector3(STAND_FRONT_OFFSET_M - 0.7, ground, post_z), wood, 8)
			Parts.cylinder(_home, 0.14, 0.16, roof_back.y - ground, Vector3(back_x + 0.5, ground, post_z), wood, 8)
			Parts.mesh(_home, Parts.sphere_mesh(0.3, 12), Parts.gold(), Vector3(STAND_FRONT_OFFSET_M - 0.7, roof_front.y + 0.5, post_z))
	_build_crowd(crowd)
	_build_drapes(range_m)


## 観客を1段ぶん並べる。人（体・頭・髪か帽子・ときどき小旗）と、見に来たぷるりん。
func _seat_row(crowd: Dictionary, x: float, top: float, z_from: float, z_to: float) -> void:
	var clothes := [Color(0.93, 0.9, 0.82), Color(0.25, 0.42, 0.72), Color(0.62, 0.3, 0.22), Color(0.3, 0.52, 0.34), Color(0.16, 0.22, 0.4), Color(0.85, 0.68, 0.28), Color(0.86, 0.5, 0.56), Color(0.97, 0.97, 0.95), Color(0.5, 0.36, 0.56), Color(0.78, 0.36, 0.2)]
	var skins := [Color(0.98, 0.84, 0.72), Color(0.93, 0.74, 0.6), Color(0.8, 0.6, 0.45), Color(0.62, 0.44, 0.32)]
	var hair_palette := [Color(0.3, 0.2, 0.13), Color(0.14, 0.11, 0.1), Color(0.78, 0.6, 0.3), Color(0.6, 0.3, 0.16), Color(0.5, 0.5, 0.52)]
	var hat_palette := [Color(0.88, 0.76, 0.48), Color(0.42, 0.28, 0.17), Color(0.18, 0.24, 0.42), Color(0.7, 0.2, 0.2)]
	var blob_palette := [Color("#4aa9e8"), Color("#e6533c"), Color("#64c878"), Color("#D8AD5C"), Color("#FF9EC0"), Color("#9B8CF0"), Color("#FFD24D"), Color("#5ED6D0")]
	var flag_palette := [Color(0.9, 0.2, 0.22), Color(0.2, 0.42, 0.85), Color(0.98, 0.84, 0.22), Color(0.97, 0.97, 0.95)]
	var pz := z_from + 0.6
	while pz < z_to - 0.5:
		pz += _rng.randf_range(0.74, 0.92)
		if _rng.randf() < 0.07:
			continue
		var foot := Vector3(x + _rng.randf_range(-0.1, 0.1), top, pz)
		if _rng.randf() < 0.16:
			var size := _rng.randf_range(0.3, 0.42)
			var turn := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5))
			crowd["blobs"].append(Transform3D(turn.scaled_local(Vector3(size, size * 0.78, size)), foot + Vector3(0.0, size * 0.55, 0.0)))
			crowd["blob_colors"].append(_pick(blob_palette))
			for eye_side: float in [-1.0, 1.0]:
				crowd["eyes"].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size * 0.14), foot + turn * Vector3(-size * 0.86, size * 0.62, eye_side * size * 0.36)))
			continue
		var tall := _rng.randf_range(0.88, 1.12)
		crowd["bodies"].append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, tall, 1.0)), foot + Vector3(0.0, 0.4 * tall, 0.0)))
		crowd["body_colors"].append(_pick(clothes))
		var head := foot + Vector3(0.0, 0.8 * tall + 0.13, 0.0)
		crowd["heads"].append(Transform3D(Basis.IDENTITY, head))
		crowd["head_colors"].append(_pick(skins))
		if _rng.randf() < 0.42:
			crowd["brims"].append(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.11, 0.0)))
			crowd["crowns"].append(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.19, 0.0)))
			crowd["hat_colors"].append(_pick(hat_palette))
		else:
			crowd["hairs"].append(Transform3D(Basis.IDENTITY, head + Vector3(0.035, 0.035, 0.0)))
			crowd["hair_colors"].append(_pick(hair_palette))
		if _rng.randf() < 0.09:
			var lean := Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
			var hand := foot + Vector3(-0.22, 1.05 * tall, 0.18)
			crowd["sticks"].append(Transform3D(lean, hand))
			crowd["flags"].append(Transform3D(lean, hand + lean * Vector3(0.0, 0.3, 0.2)))
			crowd["flag_colors"].append(_pick(flag_palette))


func _build_crowd(crowd: Dictionary) -> void:
	Parts.multi(_home, Parts.cylinder_mesh(0.17, 0.25, 0.8, 8), crowd["bodies"], crowd["body_colors"], null, false).name = "CrowdBodies"
	Parts.multi(_home, Parts.sphere_mesh(0.17, 8), crowd["heads"], crowd["head_colors"], null, false)
	Parts.multi(_home, Parts.sphere_mesh(0.185, 8), crowd["hairs"], crowd["hair_colors"], null, false)
	Parts.multi(_home, Parts.cylinder_mesh(0.27, 0.27, 0.035, 10), crowd["brims"], crowd["hat_colors"], null, false)
	Parts.multi(_home, Parts.cylinder_mesh(0.14, 0.16, 0.16, 10), crowd["crowns"], crowd["hat_colors"], null, false)
	var blob_material := StandardMaterial3D.new()
	blob_material.vertex_color_use_as_albedo = true
	blob_material.roughness = 0.25
	blob_material.rim_enabled = true
	blob_material.rim = 0.6
	Parts.multi(_home, Parts.sphere_mesh(1.0, 12), crowd["blobs"], crowd["blob_colors"], blob_material, false).name = "CrowdPururins"
	Parts.multi(_home, Parts.sphere_mesh(1.0, 6), crowd["eyes"], [], Parts.material(Color(0.08, 0.08, 0.12), 0.3), false)
	var stick_mesh := BoxMesh.new()
	stick_mesh.size = Vector3(0.03, 0.7, 0.03)
	Parts.multi(_home, stick_mesh, crowd["sticks"], [], Parts.material(Parts.COLOR_WOOD_DARK), false)
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.02, 0.26, 0.4)
	Parts.multi(_home, flag_mesh, crowd["flags"], crowd["flag_colors"], null, false)


## 屋根の前のふちに下げる、三角の飾りの列。
func _add_valance(roof_front: Vector3, length: float, color: Color) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var tooth := 1.6
	for i in int(length / tooth):
		var z0 := roof_front.z - length * 0.5 + float(i) * tooth
		vertices.append_array([Vector3(roof_front.x, roof_front.y, z0), Vector3(roof_front.x, roof_front.y, z0 + tooth), Vector3(roof_front.x, roof_front.y - 1.1, z0 + tooth * 0.5)])
		for _k in 3:
			colors.append(color if i % 2 == 0 else Parts.COLOR_WHITE)
			normals.append(Vector3(-1.0, 0.0, 0.0))
	Parts.colored_triangles(_home, vertices, normals, colors)


## 観客席の前の柵に、お祭りの布を掛ける。
func _build_drapes(range_m: Vector2) -> void:
	var drape_mesh := BoxMesh.new()
	drape_mesh.size = Vector3(0.04, 0.62, FENCE_POST_SPACING_M - 0.3)
	var drapes := []
	var drape_colors := []
	var palette := [Parts.COLOR_CRIMSON, Parts.COLOR_WHITE, Color(0.16, 0.34, 0.72), Parts.COLOR_WHITE]
	var z := -range_m.y
	var index := 0
	while z < range_m.x:
		drapes.append(Transform3D(Basis.IDENTITY, Vector3(Parts.FENCE_SIDE_OFFSET_M + 0.12, Parts.GROUND_Y_M + 0.78, z + FENCE_POST_SPACING_M * 0.5)))
		drape_colors.append(palette[index % palette.size()])
		index += 1
		z += FENCE_POST_SPACING_M
	Parts.multi(_home, drape_mesh, drapes, drape_colors).name = "Drapes"


## 王さまの観覧席。ゴールの正面。
func _build_royal_box() -> void:
	var stone := Parts.material(Color(0.9, 0.86, 0.78))
	var red := Parts.material(Parts.COLOR_CRIMSON)
	var navy := Parts.material(Parts.COLOR_NAVY)
	var gold := Parts.gold()
	var depth := ROYAL_BOX_SIZE_M.x
	var width := ROYAL_BOX_SIZE_M.y
	var floor_y := 4.4
	var ground := Parts.GROUND_Y_M
	var center := Vector3(STAND_FRONT_OFFSET_M + depth * 0.5, 0.0, 0.0)
	Parts.box(_home, Vector3(depth, floor_y - ground, width), center + Vector3(0.0, (floor_y + ground) * 0.5, 0.0), stone)
	Parts.box(_home, Vector3(depth + 0.6, 0.4, width + 0.6), center + Vector3(0.0, floor_y + 0.1, 0.0), Parts.material(Color(0.8, 0.74, 0.64)))
	Parts.box(_home, Vector3(0.3, 1.0, width + 0.6), center + Vector3(-depth * 0.5 - 0.2, floor_y + 0.7, 0.0), navy)
	Parts.box(_home, Vector3(0.34, 0.14, width + 0.7), center + Vector3(-depth * 0.5 - 0.2, floor_y + 1.25, 0.0), gold)
	for corner_x: float in [-depth * 0.5 + 0.4, depth * 0.5 - 0.4]:
		for corner_z: float in [-width * 0.5 + 0.6, width * 0.5 - 0.6]:
			Parts.cylinder(_home, 0.2, 0.22, 6.2, center + Vector3(corner_x, floor_y + 0.2, corner_z), gold, 10)
	# 四角すいの屋根（4面の、すい）。
	var roof_y := floor_y + 6.4
	Parts.box(_home, Vector3(depth + 0.8, 0.5, width + 0.9), center + Vector3(0.0, roof_y + 0.05, 0.0), gold)
	Parts.mesh(_home, Parts.cylinder_mesh(0.0, 12.6, 5.2, 4), red, center + Vector3(0.0, roof_y + 2.6, 0.0), Vector3(0.0, 45.0, 0.0), Vector3(0.72, 1.0, 1.05))
	Parts.mesh(_home, Parts.sphere_mesh(0.6, 14), gold, center + Vector3(0.0, roof_y + 5.6, 0.0))
	# 前に下げる、紋章の旗。
	var banner_colors := [Parts.COLOR_NAVY, Parts.COLOR_CRIMSON, Parts.COLOR_NAVY]
	for i in 3:
		Parts.banner(_home, center + Vector3(-depth * 0.5 - 0.4, floor_y - 0.1, (float(i) - 1.0) * width * 0.3), banner_colors[i], 2.2, 3.6, Vector3(-1.0, 0.0, 0.0))
	_build_royals(center + Vector3(-depth * 0.5 + ROYAL_SEAT_FROM_FRONT_M, floor_y + 0.3, 0.0))


## 王さまと、おきさき。席の前のほうの、一段高い台に並べる。遠くからも見えるように、観客より大きく作る。
## at は、台の下のまん中。顔は、コースの側（x−）を向く。
func _build_royals(at: Vector3) -> void:
	var gold := Parts.gold()
	var white := Parts.material(Color(0.98, 0.97, 0.94))
	var red := Parts.material(Parts.COLOR_CRIMSON)
	var skin := Parts.material(Color(0.97, 0.84, 0.72))
	var dark := Parts.material(Color(0.1, 0.09, 0.12), 0.4)
	var blush := Parts.material(Color(1.0, 0.62, 0.62))
	# 赤いじゅうたんの台。
	Parts.box(_home, Vector3(ROYAL_DAIS_SIZE_M.x, ROYAL_DAIS_SIZE_M.y, ROYAL_DAIS_SIZE_M.z), at + Vector3(0.0, ROYAL_DAIS_SIZE_M.y * 0.5, 0.0), red)
	Parts.box(_home, Vector3(ROYAL_DAIS_SIZE_M.x + 0.2, 0.12, ROYAL_DAIS_SIZE_M.z + 0.2), at + Vector3(0.0, ROYAL_DAIS_SIZE_M.y, 0.0), gold)
	var stand := at + Vector3(0.0, ROYAL_DAIS_SIZE_M.y + 0.06, 0.0)
	# 1人ぶん：横の位置、衣の色、すその広がり、王さまか。
	var royals := [
		{"z": ROYAL_SPACING_M * 0.5, "robe": Parts.COLOR_CRIMSON, "hem": 0.85, "king": true},
		{"z": -ROYAL_SPACING_M * 0.5, "robe": Color(0.42, 0.3, 0.78), "hem": 1.05, "king": false},
	]
	for royal: Dictionary in royals:
		var king := bool(royal["king"])
		var foot := stand + Vector3(0.0, 0.0, float(royal["z"]))
		var robe := Parts.material(royal["robe"])
		var hem := float(royal["hem"])
		var tall := ROYAL_BODY_HEIGHT_M
		var head_radius := ROYAL_HEAD_RADIUS_M
		# 玉座（赤い背もたれに、金のふち）。
		Parts.box(_home, Vector3(0.22, 3.5, 1.9), foot + Vector3(1.25, 1.75, 0.0), gold)
		Parts.box(_home, Vector3(0.24, 3.2, 1.6), foot + Vector3(1.22, 1.75, 0.0), red)
		Parts.mesh(_home, Parts.sphere_mesh(0.26, 12), gold, foot + Vector3(1.25, 3.7, 0.0))
		# 衣（すそが広い）、すその帯、えり。
		Parts.cylinder(_home, 0.36, hem, tall, foot, robe, 16)
		Parts.cylinder(_home, hem + 0.03, hem + 0.05, 0.26, foot, white if king else gold, 16)
		Parts.cylinder(_home, 0.4, 0.56, 0.24, foot + Vector3(0.0, tall - 0.2, 0.0), white if king else gold, 16)
		# 頭、目、ほっぺ。
		var head := foot + Vector3(0.0, tall + head_radius * 0.8, 0.0)
		Parts.mesh(_home, Parts.sphere_mesh(head_radius, 18), skin, head)
		for side: float in [-1.0, 1.0]:
			Parts.mesh(_home, Parts.sphere_mesh(0.065, 8), dark, head + Vector3(-head_radius * 0.9, 0.05, side * 0.19))
			Parts.mesh(_home, Parts.sphere_mesh(0.09, 8), blush, head + Vector3(-head_radius * 0.82, -0.12, side * 0.32), Vector3.ZERO, Vector3(0.5, 0.7, 1.0))
		if king:
			# 白いひげと、とがった冠。
			Parts.mesh(_home, Parts.sphere_mesh(0.34, 12), white, head + Vector3(-head_radius * 0.55, -0.3, 0.0), Vector3.ZERO, Vector3(0.8, 0.9, 1.15))
			Parts.cylinder(_home, 0.44, 0.4, 0.3, head + Vector3(0.0, head_radius * 0.72, 0.0), gold, 12)
			Parts.mesh(_home, Parts.sphere_mesh(0.36, 12), red, head + Vector3(0.0, head_radius * 0.72 + 0.28, 0.0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
			for point in 6:
				var turn := TAU * float(point) / 6.0
				Parts.cylinder(_home, 0.0, 0.11, 0.3, head + Vector3(cos(turn) * 0.4, head_radius * 0.72 + 0.3, sin(turn) * 0.4), gold, 6)
		else:
			# 長い髪と、小さい冠（まん中に赤い玉）。
			var hair := Parts.material(Color(0.86, 0.66, 0.3))
			Parts.mesh(_home, Parts.sphere_mesh(head_radius * 1.08, 14), hair, head + Vector3(0.14, 0.06, 0.0))
			Parts.cylinder(_home, 0.3, 0.42, 1.0, head + Vector3(0.3, -1.05, 0.0), hair, 10)
			Parts.cylinder(_home, 0.3, 0.28, 0.16, head + Vector3(0.0, head_radius * 0.86, 0.0), gold, 12)
			Parts.cylinder(_home, 0.0, 0.1, 0.3, head + Vector3(-0.27, head_radius * 0.86 + 0.14, 0.0), gold, 6)
			Parts.mesh(_home, Parts.sphere_mesh(0.07, 8), red, head + Vector3(-0.29, head_radius * 0.86 + 0.1, 0.0))


# ---------------------------------------------------------------- コースの内側

## ホームストレートの内側の、お祭りのテントと、柵のそばの花だん。
func _build_tents_and_flowers() -> void:
	var range_m := _stand_range()
	var tent_shader := Shader.new()
	tent_shader.code = """
shader_type spatial;
uniform vec3 first : source_color;
uniform vec3 second : source_color;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float turn = atan(local.z, local.x) / 6.2831853 + 0.5;
	ALBEDO = mix(first, second, step(0.5, fract(turn * 6.0)));
	ROUGHNESS = 1.0;
}
"""
	var tent_colors := [Color(0.86, 0.22, 0.24), Color(0.98, 0.8, 0.24), Color(0.2, 0.44, 0.82), Color(0.3, 0.68, 0.44)]
	var ground := Vector3(0.0, Parts.GROUND_Y_M, 0.0)
	var index := 0
	var z := -range_m.y + 20.0
	while z < range_m.x:
		var color: Color = tent_colors[index % tent_colors.size()]
		var at := Vector3(-22.0 - float(index % 3) * 7.0, 0.0, z + _rng.randf_range(-4.0, 4.0)) + ground
		var roof := ShaderMaterial.new()
		roof.shader = tent_shader
		roof.set_shader_parameter("first", color)
		roof.set_shader_parameter("second", Parts.COLOR_WHITE)
		var wall := ShaderMaterial.new()
		wall.shader = tent_shader
		wall.set_shader_parameter("first", Parts.COLOR_WHITE)
		wall.set_shader_parameter("second", color.lightened(0.25))
		Parts.mesh(_home, Parts.cylinder_mesh(0.0, 3.4, 2.6, 12), roof, at + Vector3(0.0, 4.1, 0.0))
		Parts.mesh(_home, Parts.cylinder_mesh(3.0, 3.0, 2.8, 12), wall, at + Vector3(0.0, 1.4, 0.0))
		Parts.cylinder(_home, 0.05, 0.05, 1.6, at + Vector3(0.0, 5.3, 0.0), Parts.material(Parts.COLOR_WOOD_DARK), 6)
		Parts.box(_home, Vector3(0.03, 0.5, 0.9), at + Vector3(0.0, 6.6, 0.45), Parts.material(color))
		index += 1
		z += 31.0
	var flowers := []
	var flower_colors := []
	var petals := [Color(1.0, 0.98, 0.95), Color(1.0, 0.6, 0.72), Color(1.0, 0.86, 0.3), Color(0.72, 0.6, 1.0), Color(1.0, 0.45, 0.4)]
	var bushes := []
	var bed_z := -range_m.y
	while bed_z < range_m.x:
		for _i in 26:
			var p := Vector3(-(M2TrackMath.HALF_WIDTH_M + 4.6) + _rng.randf_range(-1.1, 1.1), 0.0, bed_z + _rng.randf_range(-4.5, 4.5)) + ground
			bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 0.42, 0.55)), p + Vector3(0.0, 0.25, 0.0)))
			for _j in 3:
				flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.1, 0.16)), p + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.45, 0.66), _rng.randf_range(-0.35, 0.35))))
				flower_colors.append(_pick(petals))
		bed_z += 24.0
	Parts.multi(_home, Parts.sphere_mesh(1.0, 12), bushes, [], Parts.material(Color(0.3, 0.6, 0.3)), false).name = "FlowerBushes"
	Parts.multi(_home, Parts.sphere_mesh(1.0, 8), flowers, flower_colors, null, false)


func _build_pond_and_trees() -> void:
	var ground := Parts.GROUND_Y_M
	var pond_radius := Vector2(_straight * 0.22, _radius * 0.42)
	var disc := Parts.cylinder_mesh(1.0, 1.0, 0.04, 40)
	var water := Parts.material(Color(0.3, 0.62, 0.9), 0.08)
	water.metallic = 0.3
	Parts.mesh(_field, disc, Parts.material(Color(0.86, 0.8, 0.62)), Vector3(0.0, ground + 0.02, 0.0), Vector3.ZERO, Vector3(pond_radius.y + 3.0, 1.0, pond_radius.x + 3.0))
	Parts.mesh(_field, disc, water, Vector3(0.0, ground + 0.04, 0.0), Vector3.ZERO, Vector3(pond_radius.y, 1.0, pond_radius.x)).name = "Pond"
	var trees := []
	var range_m := _stand_range()
	var goal_along := _goal_path - _straight * 0.5
	# コースの内側。池と、ホームストレートのそば（テントの所）を避ける。
	for _i in 260:
		var along := _rng.randf_range(-_straight * 0.5 - _radius, _straight * 0.5 + _radius)
		var across := _rng.randf_range(-_radius, _radius)
		if distance_outside_track(along, across, _straight, _radius) > -(M2TrackMath.HALF_WIDTH_M + 14.0):
			continue
		if Vector2(along / (pond_radius.x + 12.0), across / (pond_radius.y + 12.0)).length() < 1.0:
			continue
		if across > _radius - 50.0 and along > goal_along - range_m.x - 20.0 and along < goal_along + range_m.y + 20.0:
			continue
		trees.append(_field_point(along, across, ground))
	# コースの外。観客席と城下町の側、城の丘、助走の直線を避ける。
	for _i in 520:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(_radius + 40.0, 1500.0)
		var along := cos(angle) * distance * 1.3
		var across := sin(angle) * distance
		if distance_outside_track(along, across, _straight, _radius) < 30.0:
			continue
		if across > _radius + TOWN_FROM_TRACK_M - 20.0 and absf(along) < 620.0 and across < _radius + TOWN_FROM_TRACK_M + 420.0:
			continue
		if along > CASTLE_HILL_AT_M.x - CASTLE_WALL_AHEAD_M - 30.0 and Vector2(along - CASTLE_HILL_AT_M.x, across - CASTLE_HILL_AT_M.y).length() < CASTLE_WALL_AHEAD_M + 60.0:
			continue
		var point := _field_point(along, across, ground - 0.25)
		if _near_launch_strip(_field.transform * point):
			continue
		trees.append(point)
	var trunks := []
	var canopies := []
	var canopy_colors := []
	var greens := [Color(0.22, 0.5, 0.24), Color(0.28, 0.58, 0.26), Color(0.36, 0.64, 0.28), Color(0.2, 0.44, 0.26)]
	for at: Vector3 in trees:
		var size := _rng.randf_range(0.8, 1.5)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), at + Vector3(0.0, 1.3 * size, 0.0)))
		var green: Color = _pick(greens)
		for part: Array in [[Vector3(0.0, 4.2, 0.0), 2.3], [Vector3(1.5, 3.3, 0.5), 1.6], [Vector3(-1.3, 3.5, -0.6), 1.7]]:
			var radius: float = float(part[1]) * size
			canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 0.92, radius)), at + (part[0] as Vector3) * size))
			canopy_colors.append(green.lightened(_rng.randf_range(0.0, 0.14)))
	Parts.multi(_field, Parts.cylinder_mesh(0.22, 0.34, 2.6, 8), trunks, [], Parts.material(Color(0.42, 0.28, 0.18)), false).name = "TreeTrunks"
	Parts.multi(_field, Parts.sphere_mesh(1.0, 10), canopies, canopy_colors, null, false).name = "TreeCanopies"


# ---------------------------------------------------------------- 遠くの景色

func _build_town_and_castle() -> void:
	var ground := Parts.GROUND_Y_M - 0.25
	var walls := []
	var wall_colors := []
	var roofs := []
	var roof_colors := []
	var wall_palette := [Color(0.96, 0.92, 0.82), Color(0.93, 0.86, 0.74), Color(0.98, 0.95, 0.9), Color(0.9, 0.82, 0.7)]
	var roof_palette := [Color(0.82, 0.36, 0.24), Color(0.88, 0.46, 0.26), Color(0.74, 0.3, 0.24), Color(0.28, 0.4, 0.66)]
	var hill := CASTLE_HILL_AT_M
	# 家並み。観客席の向こうと、城の丘のふもと。1つぶん：[まん中（along, across）, 大きさ（along, across）]。
	var zones := [
		[Vector2(0.0, _radius + TOWN_FROM_TRACK_M + 190.0), Vector2(1100.0, 380.0)],
		[Vector2(hill.x - CASTLE_WALL_AHEAD_M + 130.0, hill.y), Vector2(220.0, 900.0)],
	]
	var pitch := 21.0
	for zone: Array in zones:
		var middle: Vector2 = zone[0]
		var extent: Vector2 = zone[1]
		var columns := int(extent.x / pitch)
		var rows := int(extent.y / pitch)
		for column in columns:
			for row in rows:
				# 5〜6軒ごとに、通りを空ける。
				if column % 5 == 0 or row % 6 == 0 or _rng.randf() < 0.14:
					continue
				var along := middle.x - extent.x * 0.5 + float(column) * pitch + _rng.randf_range(-2.0, 2.0)
				var across := middle.y - extent.y * 0.5 + float(row) * pitch + _rng.randf_range(-2.0, 2.0)
				if Vector2((along - hill.x) / CASTLE_HILL_RADIUS_M.x, (across - hill.y) / CASTLE_HILL_RADIUS_M.y).length() < 1.05:
					continue
				var w := _rng.randf_range(11.0, 16.0)
				var h := _rng.randf_range(7.0, 13.0)
				var d := _rng.randf_range(11.0, 16.0)
				var turn := Basis(Vector3.UP, _rng.randf_range(-0.06, 0.06) + (PI * 0.5 if _rng.randf() < 0.5 else 0.0))
				var foot := _field_point(along, across, ground)
				walls.append(Transform3D(turn.scaled_local(Vector3(w, h, d)), foot + Vector3(0.0, h * 0.5, 0.0)))
				wall_colors.append(_pick(wall_palette))
				var roof_h := _rng.randf_range(5.0, 8.0)
				roofs.append(Transform3D(turn.scaled_local(Vector3(w + 1.6, roof_h, d + 1.6)), foot + Vector3(0.0, h + roof_h * 0.5, 0.0)))
				roof_colors.append(_pick(roof_palette))
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	Parts.multi(_field, unit, walls, wall_colors, null, false).name = "TownWalls"
	var prism := PrismMesh.new()
	prism.size = Vector3.ONE
	Parts.multi(_field, prism, roofs, roof_colors, null, false).name = "TownRoofs"
	# 城の丘と、城。
	var castle := Node3D.new()
	castle.name = "Castle"
	castle.position = _field_point(hill.x, hill.y, ground)
	# 城の正面（z＋）は、レース場の側。
	_field.add_child(castle)
	Parts.mesh(castle, Parts.sphere_mesh(1.0, 32), Parts.material(Color(0.44, 0.64, 0.38)), Vector3(0.0, -40.0, 0.0), Vector3.ZERO, Vector3(CASTLE_HILL_RADIUS_M.y, 150.0, CASTLE_HILL_RADIUS_M.x))
	var stone := Parts.material(Color(0.95, 0.93, 0.88))
	var blue := Parts.material(Color(0.24, 0.4, 0.74))
	var top := Vector3(0.0, 104.0, 0.0)
	Parts.box(castle, Vector3(150.0, 44.0, 90.0), top + Vector3(0.0, 22.0, 0.0), stone)
	Parts.box(castle, Vector3(90.0, 30.0, 60.0), top + Vector3(0.0, 59.0, 0.0), stone)
	var keep_roof := PrismMesh.new()
	keep_roof.size = Vector3(96.0, 26.0, 66.0)
	Parts.mesh(castle, keep_roof, blue, top + Vector3(0.0, 87.0, 0.0))
	var towers := [[Vector3(-80.0, 0.0, 40.0), 17.0, 84.0], [Vector3(80.0, 0.0, 40.0), 17.0, 84.0], [Vector3(-48.0, 0.0, 34.0), 12.0, 118.0], [Vector3(52.0, 0.0, 30.0), 13.0, 132.0], [Vector3(0.0, 0.0, 0.0), 16.0, 170.0], [Vector3(-112.0, 0.0, -10.0), 13.0, 60.0], [Vector3(112.0, 0.0, -10.0), 13.0, 60.0]]
	for tower: Array in towers:
		var radius: float = tower[1]
		var tall: float = tower[2]
		var base: Vector3 = top + (tower[0] as Vector3)
		Parts.cylinder(castle, radius, radius * 1.06, tall, base, stone, 14)
		Parts.cylinder(castle, radius * 1.18, radius * 1.18, 5.0, base + Vector3(0.0, tall - 5.0, 0.0), stone, 14)
		Parts.cylinder(castle, 0.0, radius * 1.3, radius * 2.6, base + Vector3(0.0, tall, 0.0), blue, 14)
		Parts.cylinder(castle, 0.5, 0.5, 14.0, base + Vector3(0.0, tall + radius * 2.6, 0.0), Parts.material(Parts.COLOR_WOOD_DARK), 6)
		Parts.box(castle, Vector3(11.0, 6.0, 0.4), base + Vector3(5.5, tall + radius * 2.6 + 10.5, 0.0), Parts.material(Color(0.86, 0.2, 0.24)))
	# 城下町の壁と、塔（レース場の側）。
	var wall_z := CASTLE_WALL_AHEAD_M
	Parts.box(castle, Vector3(1100.0, 20.0, 9.0), Vector3(0.0, 10.0, wall_z), Parts.material(Color(0.88, 0.84, 0.76)))
	var tower_roofs := [blue, Parts.material(Color(0.8, 0.34, 0.24))]
	for i in 8:
		var tower_x := -540.0 + float(i) * 154.0
		Parts.cylinder(castle, 14.0, 15.0, 34.0, Vector3(tower_x, 0.0, wall_z), Parts.material(Color(0.9, 0.86, 0.78)), 12)
		Parts.cylinder(castle, 0.0, 17.0, 22.0, Vector3(tower_x, 34.0, wall_z), tower_roofs[i % 2], 12)
	for child in castle.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 丘、山、雲。
func _build_far_scenery() -> void:
	var hills := []
	var hill_colors := []
	for i in 40:
		var angle := float(i) / 40.0 * TAU + _rng.randf_range(-0.07, 0.07)
		var distance := _rng.randf_range(HILL_RING_M.x, HILL_RING_M.y)
		var wide := _rng.randf_range(420.0, 800.0)
		hills.append(Transform3D(Basis.IDENTITY.scaled(Vector3(wide, _rng.randf_range(90.0, 210.0), wide)), Vector3(cos(angle) * distance, -30.0, sin(angle) * distance)))
		hill_colors.append(Color(0.5, 0.68, 0.48).lerp(Color(0.58, 0.76, 0.52), _rng.randf()))
	Parts.multi(_field, Parts.sphere_mesh(1.0, 24), hills, hill_colors, null, false).name = "Hills"
	var mountains := []
	var mountain_colors := []
	for i in 60:
		var angle := float(i) / 60.0 * TAU + _rng.randf_range(-0.05, 0.05)
		var distance := _rng.randf_range(MOUNTAIN_RING_M.x, MOUNTAIN_RING_M.y)
		var tall := _rng.randf_range(240.0, 560.0)
		var wide := tall * _rng.randf_range(2.2, 3.6)
		mountains.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(wide, tall, wide * _rng.randf_range(0.7, 1.3))), Vector3(cos(angle) * distance, tall * 0.5 - 20.0, sin(angle) * distance)))
		mountain_colors.append(Color(0.52, 0.66, 0.84).lerp(Color(0.56, 0.72, 0.76), _rng.randf()))
	Parts.multi(_field, Parts.cylinder_mesh(0.06, 1.0, 1.0, 7), mountains, mountain_colors, null, false).name = "Mountains"
	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type spatial;
render_mode unshaded;
varying float up;
void vertex() { up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y; }
void fragment() { ALBEDO = mix(vec3(0.72, 0.84, 0.98), vec3(1.0), smoothstep(-0.7, 0.55, up)); }
"""
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = cloud_shader
	var puffs := []
	for i in 26:
		var angle := float(i) / 26.0 * TAU + _rng.randf_range(-0.08, 0.08)
		var distance := _rng.randf_range(CLOUD_RING_M.x, CLOUD_RING_M.y)
		var base := Vector3(cos(angle) * distance, _rng.randf_range(420.0, 1100.0), sin(angle) * distance)
		var size := _rng.randf_range(100.0, 220.0)
		var along := Vector3(-sin(angle), 0.0, cos(angle))
		for j in 8:
			var from_middle := absf(float(j) - 3.5)
			var shift := along * (float(j) - 3.5) * size * 0.55 + Vector3(0.0, _rng.randf_range(0.0, 0.5) * size * (1.0 - from_middle / 4.0), 0.0)
			var radius := size * _rng.randf_range(0.55, 1.0) * (1.0 - from_middle / 6.0)
			puffs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 0.72, radius)), base + shift))
	Parts.multi(_field, Parts.sphere_mesh(1.0, 16), puffs, [], cloud_material, false).name = "Clouds"
