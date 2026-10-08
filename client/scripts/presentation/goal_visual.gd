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
	_build_ground_line()
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


func _build_ground_line() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(_width, LINE_DEPTH_M)
	var checker := Parts.crisp_texture_material(Parts.checker_texture(LINE_CHECKER_COLUMNS, 2, Parts.COLOR_WHITE, Parts.COLOR_BLACK))
	var line := Parts.mesh(_root, plane, checker, Vector3(0.0, Parts.TRACK_TOP_Y_M + LINE_LIFT_M, 0.0))
	line.name = "GroundLine"
	_goal_nodes.append(line)
