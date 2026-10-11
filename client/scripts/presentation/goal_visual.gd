extends RefCounted
## ゴールの門。コースをまたぐ木の門に、白黒の市松の幕と「GOAL」の札を掛け、地面に市松の線を引く。
## ゴールの前に門をくぐるレース（1周より長い距離）では、最後の周に入るまで、青い幕と「あと◯周」の札にして、
## 地面の市松の線は出さない。
## 配置先Path・距離・コース幅を受け取る。置き直すときは作り直すので、門は1つだけ。
## 生成ノードの寿命は配置先Pathが所有する。

const Parts := preload("res://scripts/presentation/venue_parts.gd")

const ROOT_NAME := "GoalGate"
## 柱は、コースの端から、これだけ外に立てる（柵の外）。
const POST_MARGIN_M := 1.9
const POST_HEIGHT_M := 9.2
const POST_RADIUS_M := 0.45
## 幕の高さ（縦）と、門の上からの下がり。
const CLOTH_HEIGHT_M := 1.9
const CLOTH_CENTER_DROP_M := 1.5
const CLOTH_CHECKER_COLUMNS := 20
## まん中の札の大きさと、文字の高さ。
const PLATE_SIZE_M := Vector2(6.4, 2.5)
const PLATE_TEXT := "GOAL"
const PLATE_TEXT_HEIGHT_M := 1.25
## まだ周回が残っているあいだの、札の文字（%d は、残りの周の数）と、文字の高さ、幕の色。
const LAP_TEXT_FORMAT := "あと%d周"
const LAP_TEXT_HEIGHT_M := 1.15
const LAP_CLOTH_COLOR := Color(0.16, 0.34, 0.74)
## 門を通りすぎてから、札を替えるまでの距離（m）。
const SWITCH_AFTER_PASS_M := 20.0
## 地面の市松の線の、進む向きの幅と、ますの数。
const LINE_DEPTH_M := 1.0
const LINE_CHECKER_COLUMNS := 30
## 地面の線を、コースの面から浮かせる量（コントローラーが引く白い線の上に出す）。
const LINE_LIFT_M := 0.045
## ゴールの線の先（走り抜ける側）に敷く、赤いじゅうたん。長さ（m）、色、へりの金の帯の幅（m）。
## 遠くからでもゴールの場所が分かるように、市松の線の向こうを、広く赤くする。
const CARPET_LENGTH_M := 30.0
const CARPET_COLOR := Color(0.70, 0.11, 0.16)
const CARPET_EDGE_WIDTH_M := 0.4
## じゅうたんを、コースの面から浮かせる量（市松の線より下にして、線が上に出るようにする）。
const CARPET_LIFT_M := 0.02
## ゴールを華やかにする、風船。色の順ぐり、1つの大きさ（半径m）、縦に少しのばす割合。
const BALLOON_COLORS := [
	Color("#FF7FB2"), Color("#FFD24D"), Color("#5BB8FF"), Color("#6FD98A"), Color("#FFFFFF"), Color("#C79BFF"),
]
const BALLOON_RADIUS_M := 0.42
const BALLOON_STRETCH := 1.22
## アーチの、風船どうしの間隔（m）と、柱から前後へ離す量（m）。
const BALLOON_SPACING_M := 1.0
const BALLOON_SIDE_OFFSET_M := 0.92
## アーチの、柱に沿って並べる高さの範囲と、門の上でふくらませる高さ（m）。
const BALLOON_COLUMN_FROM_M := 1.3
const BALLOON_COLUMN_TO_M := 9.0
const BALLOON_ARCH_BASE_M := 9.25
const BALLOON_ARCH_RISE_M := 1.1
## 柱のふもとに結ぶ、風船の束（1つぶんの数、浮かぶ高さ、ひもの太さ）。
const BUNCH_COUNT := 5
const BUNCH_HEIGHT_M := Vector2(2.6, 4.3)
const BUNCH_STRING_RADIUS_M := 0.02
const BUNCH_TIE_HEIGHT_M := 0.9
## 札の上に載せる、金の王冠（輪の半径・輪の高さ・とがりの高さ・とがりの数・宝石の色）。
const CROWN_RADIUS_M := 0.62
const CROWN_BAND_M := 0.42
const CROWN_SPIKE_M := 0.46
const CROWN_POINTS := 5
const CROWN_GEM_COLOR := Color("#FF5A8A")

var _track: Path3D
var _root: Node3D
var _width := 0.0
## ゴールまでに、あと何回この門をくぐるか（0なら、次にくぐるのがゴール）。
var _laps_to_go := 0
## 最後の周で出すもの（市松の幕、「GOAL」の文字、地面の線）と、それまで出すもの（青い幕、「あと◯周」の文字）。
var _goal_nodes: Array[Node3D] = []
var _lap_nodes: Array[Node3D] = []
var _lap_labels: Array[Label3D] = []


func place(track: Path3D, path_distance: float, width_m: float) -> void:
	assert(track != null and width_m > 0.0)
	assert(_track == null or _track == track, "GoalVisualは配置先Pathごとに作成してください")
	if track.curve == null:
		return
	_track = track
	_width = width_m
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_root.name = ROOT_NAME
	track.add_child(_root)
	var curve_xf := track.curve.sample_baked_with_rotation(path_distance)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	# ここから先は、x＝外側、y＝上、z＝手前（走者が来る側）。
	_root.transform = Parts.frame_at(curve_xf.origin, travel)
	_goal_nodes.clear()
	_lap_nodes.clear()
	_lap_labels.clear()
	_build_posts()
	_build_cloth()
	_build_carpet()
	_build_ground_line()
	_build_balloons()
	_build_crown()
	_show_for_laps()


## ゴールまでに、あと何回この門をくぐるか。progress_m は、走った距離（いちばん後ろの走者）。
## 門をくぐるのは、ゴールの1周前、2周前…の所。通りすぎて少し走るまでは、数に入れたままにする。
static func laps_to_go(race_distance_m: float, lap_length_m: float, progress_m: float) -> int:
	var count := 0
	if lap_length_m <= 0.0:
		return count
	var pass_at := race_distance_m - lap_length_m
	while pass_at > 0.0:
		if pass_at > progress_m - SWITCH_AFTER_PASS_M:
			count += 1
		pass_at -= lap_length_m
	return count


## 札と幕を、残りの周の数に合わせる。0なら「GOAL」と市松。
func set_laps_to_go(laps: int) -> void:
	if laps == _laps_to_go:
		return
	_laps_to_go = laps
	_show_for_laps()


func laps_to_go_shown() -> int:
	return _laps_to_go


func _show_for_laps() -> void:
	for node in _goal_nodes:
		node.visible = _laps_to_go == 0
	for node in _lap_nodes:
		node.visible = _laps_to_go > 0
	for label in _lap_labels:
		label.text = LAP_TEXT_FORMAT % maxi(_laps_to_go, 1)


## 柱と柱のあいだの距離（柱のまん中から、まん中まで）。
func span_m() -> float:
	return _width + POST_MARGIN_M * 2.0


func _build_posts() -> void:
	var wood := Parts.material(Parts.COLOR_WOOD)
	var half := span_m() * 0.5
	var ground := Parts.GROUND_Y_M
	for side: float in [-1.0, 1.0]:
		Parts.cylinder(_root, POST_RADIUS_M * 0.92, POST_RADIUS_M, POST_HEIGHT_M - ground, Vector3(side * half, ground, 0.0), wood, 12)
		Parts.cylinder(_root, POST_RADIUS_M * 1.4, POST_RADIUS_M * 1.4, 0.5, Vector3(side * half, ground, 0.0), Parts.material(Parts.COLOR_STONE), 12)
		Parts.mesh(_root, Parts.sphere_mesh(POST_RADIUS_M * 1.2, 14), Parts.gold(), Vector3(side * half, POST_HEIGHT_M + POST_RADIUS_M, 0.0))
	# 幕の上と下の、横木。
	var middle := POST_HEIGHT_M - CLOTH_CENTER_DROP_M
	for height: float in [middle + CLOTH_HEIGHT_M * 0.5 + 0.15, middle - CLOTH_HEIGHT_M * 0.5 - 0.15]:
		Parts.box(_root, Vector3(span_m(), 0.3, 0.3), Vector3(0.0, height, 0.0), wood)


func _build_cloth() -> void:
	var middle := POST_HEIGHT_M - CLOTH_CENTER_DROP_M
	var checker := Parts.crisp_texture_material(Parts.checker_texture(CLOTH_CHECKER_COLUMNS, 2, Parts.COLOR_WHITE, Parts.COLOR_BLACK))
	var lap_cloth := Parts.material(LAP_CLOTH_COLOR)
	lap_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 手前（z＋）と、向こう（z−）の両方から読めるように、表と裏に1枚ずつ。
	for face: float in [-1.0, 1.0]:
		var turn := Vector3(0.0, 0.0 if face > 0.0 else 180.0, 0.0)
		var side := "Front" if face > 0.0 else "Back"
		var quad := QuadMesh.new()
		quad.size = Vector2(span_m() - POST_RADIUS_M * 2.0, CLOTH_HEIGHT_M)
		_goal_nodes.append(Parts.mesh(_root, quad, checker, Vector3(0.0, middle, face * 0.17), turn))
		_lap_nodes.append(Parts.mesh(_root, quad, lap_cloth, Vector3(0.0, middle, face * 0.17), turn))
		Parts.box(_root, Vector3(PLATE_SIZE_M.x + 0.4, PLATE_SIZE_M.y + 0.4, 0.08), Vector3(0.0, middle, face * 0.2), Parts.gold())
		Parts.box(_root, Vector3(PLATE_SIZE_M.x, PLATE_SIZE_M.y, 0.12), Vector3(0.0, middle, face * 0.24), Parts.material(Parts.COLOR_WHITE))
		var text := Parts.label(_root, PLATE_TEXT, PLATE_TEXT_HEIGHT_M, Parts.COLOR_CRIMSON, Vector3(0.0, middle - 0.05, face * 0.31), turn)
		text.name = "PlateText" + side
		_goal_nodes.append(text)
		var lap_text := Parts.label(_root, LAP_TEXT_FORMAT % 1, LAP_TEXT_HEIGHT_M, Parts.COLOR_NAVY, Vector3(0.0, middle - 0.05, face * 0.31), turn)
		lap_text.name = "LapText" + side
		_lap_nodes.append(lap_text)
		_lap_labels.append(lap_text)


## ゴールの線の先に敷く、赤いじゅうたん（へりは金）。市松の線と同じく、最後の周だけ出す。
func _build_carpet() -> void:
	var carpet := PlaneMesh.new()
	carpet.size = Vector2(_width, CARPET_LENGTH_M)
	# 門の中の向きは、x＝外側、z＝手前（走者が来る側）。走り抜ける先は、マイナスZ。
	var center := Vector3(0.0, Parts.TRACK_TOP_Y_M + CARPET_LIFT_M, -CARPET_LENGTH_M * 0.5)
	var node := Parts.mesh(_root, carpet, Parts.material(CARPET_COLOR, 0.9), center)
	node.name = "Carpet"
	_goal_nodes.append(node)
	var edge := PlaneMesh.new()
	edge.size = Vector2(CARPET_EDGE_WIDTH_M, CARPET_LENGTH_M)
	for side: float in [-1.0, 1.0]:
		var at := center + Vector3(side * (_width - CARPET_EDGE_WIDTH_M) * 0.5, 0.001, 0.0)
		var line := Parts.mesh(_root, edge, Parts.material(Parts.COLOR_GOLD, 0.8), at)
		line.name = "CarpetEdge%s" % ("L" if side < 0.0 else "R")
		_goal_nodes.append(line)


## ゴールの札の上に載せる、金の王冠（1位を決める場所、という目印）。
## 風船のアーチは前後にずらしてあるので、そのすき間（まん中）に収まる。
func _build_crown() -> void:
	# 風船のアーチのまん中に空けたすき間へ、王冠を据える。
	var base := BALLOON_ARCH_BASE_M + BALLOON_ARCH_RISE_M - 0.75
	var gold := Parts.gold()
	Parts.cylinder(_root, CROWN_RADIUS_M, CROWN_RADIUS_M * 1.06, CROWN_BAND_M, Vector3(0.0, base, 0.0), gold, 14)
	for point in CROWN_POINTS:
		var angle := TAU * float(point) / float(CROWN_POINTS)
		var at := Vector3(cos(angle) * CROWN_RADIUS_M * 0.8, base + CROWN_BAND_M, sin(angle) * CROWN_RADIUS_M * 0.8)
		Parts.cylinder(_root, 0.0, CROWN_RADIUS_M * 0.3, CROWN_SPIKE_M, at, gold, 10)
		Parts.mesh(_root, Parts.sphere_mesh(CROWN_RADIUS_M * 0.17, 10), gold, at + Vector3(0.0, CROWN_SPIKE_M + 0.04, 0.0))
	# 前と後ろに、赤い宝石を1つずつ。
	var gem := Parts.material(CROWN_GEM_COLOR, 0.2)
	for face: float in [-1.0, 1.0]:
		Parts.mesh(_root, Parts.sphere_mesh(CROWN_RADIUS_M * 0.26, 12), gem, Vector3(0.0, base + CROWN_BAND_M * 0.55, face * CROWN_RADIUS_M * 0.92))


## ゴールの門を、風船で飾る。柱に沿って上がり、門の上でふくらむアーチと、ふもとに結んだ束。
## 周回の数に関わらず、いつも出す（門そのものの飾りなので）。
## アーチの風船を置く場所（柱に沿って上がり、門の上を渡る）。span は、柱と柱のあいだ。
## 位置だけを決める（テストから、この並びを確かめられるように分けてある）。
static func balloon_positions(span: float) -> Array[Vector3]:
	var half := span * 0.5
	var spots: Array[Vector3] = []
	var column_steps := int((BALLOON_COLUMN_TO_M - BALLOON_COLUMN_FROM_M) / BALLOON_SPACING_M)
	# 左右の柱に沿って、上へ並べる。柱の前後に1つずつ。
	for side: float in [-1.0, 1.0]:
		for step in column_steps + 1:
			var height := BALLOON_COLUMN_FROM_M + float(step) * BALLOON_SPACING_M
			for depth: float in [-1.0, 1.0]:
				spots.append(Vector3(side * half, height, depth * BALLOON_SIDE_OFFSET_M))
	# 門の上を、まん中がふくらむ弧で渡す。まん中は、王冠を置くために空ける。
	var arch_steps := int(half * 2.0 / BALLOON_SPACING_M)
	for step in arch_steps + 1:
		var across := -half + float(step) * (half * 2.0 / float(arch_steps))
		if absf(across) < CROWN_RADIUS_M * 2.0:
			continue
		var t := across / half
		var height := BALLOON_ARCH_BASE_M + BALLOON_ARCH_RISE_M * (1.0 - t * t)
		for depth: float in [-1.0, 1.0]:
			spots.append(Vector3(across, height, depth * BALLOON_SIDE_OFFSET_M * 0.8))
	return spots


## ゴールの門を、風船で飾る。柱に沿って上がり、門の上でふくらむアーチと、ふもとに結んだ束。
## 周回の数に関わらず、いつも出す（門そのものの飾りなので）。
func _build_balloons() -> void:
	var transforms := []
	var colors := []
	var spots := balloon_positions(span_m())
	for index in spots.size():
		_push_balloon(transforms, colors, spots[index], index)
	var balloons := Parts.multi(_root, Parts.sphere_mesh(1.0, 12), transforms, colors, _balloon_material())
	balloons.name = "Balloons"
	var half := span_m() * 0.5
	for side: float in [-1.0, 1.0]:
		_build_balloon_bunch(Vector3(side * (half + 0.9), 0.0, BALLOON_SIDE_OFFSET_M * 1.6), side)


## 風船を1つ、置き方の並びに足す。番号から、色と大きさを少しずつ変える。
func _push_balloon(transforms: Array, colors: Array, at: Vector3, index: int) -> void:
	var color: Color = BALLOON_COLORS[index % BALLOON_COLORS.size()]
	# 同じ大きさが並ばないように、番号で少しだけ散らす。
	var size := BALLOON_RADIUS_M * (0.86 + 0.28 * fposmod(float(index) * 0.37, 1.0))
	var turn := Basis(Vector3.UP, fposmod(float(index) * 1.1, TAU))
	transforms.append(Transform3D(turn.scaled(Vector3(size, size * BALLOON_STRETCH, size)), at))
	# まとめて置く形の色は、そのままだと白っぽく出るので、リニア空間に直してから渡す。
	colors.append(color.srgb_to_linear())


## 柱のふもとに結んだ、風船の束。ひもで結び目へつなぐ。
func _build_balloon_bunch(foot: Vector3, side: float) -> void:
	var tie := foot + Vector3(0.0, BUNCH_TIE_HEIGHT_M, 0.0)
	var string_material := Parts.material(Parts.COLOR_WHITE, 0.8)
	for index in BUNCH_COUNT:
		var angle := TAU * float(index) / float(BUNCH_COUNT) + side
		var spread := 0.55 + 0.25 * fposmod(float(index) * 0.53, 1.0)
		var height := lerpf(BUNCH_HEIGHT_M.x, BUNCH_HEIGHT_M.y, fposmod(float(index) * 0.41, 1.0))
		var at := foot + Vector3(cos(angle) * spread, height, sin(angle) * spread)
		var color: Color = BALLOON_COLORS[(index + int(side) + 3) % BALLOON_COLORS.size()]
		var size := BALLOON_RADIUS_M * 1.05
		Parts.mesh(_root, Parts.sphere_mesh(size, 12), _balloon_material(color), at, Vector3.ZERO, Vector3(1.0, BALLOON_STRETCH, 1.0))
		# 結び目へ向かう、細いひも。
		var line := at - tie
		var string := Parts.cylinder_mesh(BUNCH_STRING_RADIUS_M, BUNCH_STRING_RADIUS_M, line.length(), 6)
		var node := Parts.mesh(_root, string, string_material, (at + tie) * 0.5)
		node.transform = Transform3D(_basis_with_y(line), (at + tie) * 0.5)


## +Y を dir に向けた、正規直交の向き（ひもを、結び目から風船へ向けるのに使う）。
static func _basis_with_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var reference := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## 風船の塗り（つやのある、少し光る玉）。色を省くと、1つ1つの色を使う。
func _balloon_material(color: Color = Color.WHITE) -> StandardMaterial3D:
	var material := Parts.material(color, 0.22)
	material.metallic_specular = 0.75
	material.rim_enabled = true
	material.rim = 0.4
	if color == Color.WHITE:
		material.vertex_color_use_as_albedo = true
	return material


func _build_ground_line() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(_width, LINE_DEPTH_M)
	var checker := Parts.crisp_texture_material(Parts.checker_texture(LINE_CHECKER_COLUMNS, 2, Parts.COLOR_WHITE, Parts.COLOR_BLACK))
	var line := Parts.mesh(_root, plane, checker, Vector3(0.0, Parts.TRACK_TOP_Y_M + LINE_LIFT_M, 0.0))
	line.name = "GroundLine"
	_goal_nodes.append(line)


