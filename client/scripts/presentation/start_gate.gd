extends RefCounted
## スタートのゲート。車輪つきの台に柱を立て、横木から枠の番号の札（1〜8）を下げる。
## 置く場所は、ルートのスタート（進んだ距離0m）。レースの距離ごとに、置き直せる。
## スタートのあとは、片づける（周回でもう一度通るときに、じゃまにならないように）。
## 生成ノードの寿命は配置先Pathが所有する。

const Parts := preload("res://scripts/presentation/venue_parts.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")

const ROOT_NAME := "StartGate"
## 枠の数。
const GATE_COUNT := LocalRaceMath.FIELD_SIZE
## ゲートは、スタートの線より、これだけ先に置く（札が、走者の少し前の上に来る）。
const AHEAD_OF_LINE_M := 1.0
## 横木の高さ（まん中）。追う視点のカメラ（高さ3m）が、上を通れる高さにしてある。
const BEAM_HEIGHT_M := 2.72
const BEAM_THICKNESS_M := 0.12
## 札の一辺と、金のふちの幅、数字の高さ。
const BOARD_SIDE_M := 0.62
const BOARD_FRAME_M := 0.05
const BOARD_DIGIT_HEIGHT_M := 0.4
## 台は、コースの端のすぐ外（柵の内側）に置く。
const CART_SIZE_M := Vector3(0.34, 0.5, 2.2)
const CART_GAP_FROM_TRACK_M := 0.1
const WHEEL_RADIUS_M := 0.33
const WHEEL_WIDTH_M := 0.1
const POST_RADIUS_M := 0.08
## スタートしてから、片づけるまでの秒数。
const CLEAR_DELAY_S := 10.0

var _track: Path3D
var _root: Node3D


## 札の横位置（コースの中心線から。負が内側）。走者のスタートの横位置と同じ。
static func board_offset_m(gate_index: int) -> float:
	return LocalRaceMath.starting_offset_for_gate(gate_index, GATE_COUNT)


## 台のまん中の横位置（コースの中心線からの距離）。
static func cart_offset_m() -> float:
	return M2TrackMath.HALF_WIDTH_M + CART_GAP_FROM_TRACK_M + CART_SIZE_M.x * 0.5


func place(track: Path3D, route: Dictionary, lap_length_m: float) -> void:
	assert(_track == null or _track == track, "StartGateは配置先Pathごとに作成してください")
	if track == null or track.curve == null or route.is_empty():
		return
	_track = track
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_root.name = ROOT_NAME
	track.add_child(_root)
	var pose := M5CourseBuilder.route_pose(track.curve, route, 0.0, lap_length_m)
	var travel: Vector3 = pose["travel"]
	# ここから先は、x＝外側、y＝上、z＝手前（進む向きの逆）。
	_root.transform = Parts.frame_at((pose["position"] as Vector3) + travel * AHEAD_OF_LINE_M, travel)
	_build_frame()
	_build_boards()


## ゲートが出ているか。
func is_out() -> bool:
	return _root != null and _root.visible


## スタートしたら呼ぶ。delay_s 秒あとに、ゲートを片づける。
func clear_after_start(delay_s: float = CLEAR_DELAY_S) -> void:
	if _root == null or not _root.is_inside_tree():
		return
	_root.create_tween().tween_callback(_root.hide).set_delay(delay_s)


## 横木の上の高さ（地面から）。
static func beam_top_m() -> float:
	return BEAM_HEIGHT_M + BEAM_THICKNESS_M * 0.5


func _build_frame() -> void:
	var wood := Parts.material(Parts.COLOR_WOOD)
	var red := Parts.material(Parts.COLOR_CRIMSON)
	var dark := Parts.material(Parts.COLOR_WOOD_DARK)
	var ground := Parts.GROUND_Y_M
	var cart_bottom := ground + WHEEL_RADIUS_M
	var cart_top := cart_bottom + CART_SIZE_M.y
	var wheel := Parts.cylinder_mesh(WHEEL_RADIUS_M, WHEEL_RADIUS_M, WHEEL_WIDTH_M, 14)
	var hub := Parts.cylinder_mesh(WHEEL_RADIUS_M * 0.35, WHEEL_RADIUS_M * 0.35, WHEEL_WIDTH_M + 0.04, 10)
	for side: float in [-1.0, 1.0]:
		var x := side * cart_offset_m()
		Parts.box(_root, CART_SIZE_M, Vector3(x, cart_bottom + CART_SIZE_M.y * 0.5, 0.0), red)
		Parts.box(_root, Vector3(CART_SIZE_M.x + 0.06, 0.08, CART_SIZE_M.z + 0.06), Vector3(x, cart_top, 0.0), Parts.gold())
		for along: float in [-0.7, 0.7]:
			for face: float in [-1.0, 1.0]:
				var at := Vector3(x + face * (CART_SIZE_M.x * 0.5 + WHEEL_WIDTH_M * 0.5), ground + WHEEL_RADIUS_M, along)
				# 筒の軸（y）を、横（x）へ倒す。
				Parts.mesh(_root, wheel, dark, at, Vector3(0.0, 0.0, 90.0))
				Parts.mesh(_root, hub, Parts.gold(), at, Vector3(0.0, 0.0, 90.0))
		Parts.cylinder(_root, POST_RADIUS_M, POST_RADIUS_M, BEAM_HEIGHT_M - cart_top, Vector3(x, cart_top, 0.0), wood, 10)
		Parts.mesh(_root, Parts.sphere_mesh(0.15, 12), Parts.gold(), Vector3(x, BEAM_HEIGHT_M + 0.16, 0.0))
	Parts.box(_root, Vector3(cart_offset_m() * 2.0 + 0.3, BEAM_THICKNESS_M, BEAM_THICKNESS_M), Vector3(0.0, BEAM_HEIGHT_M, 0.0), wood)


func _build_boards() -> void:
	var center_y := BEAM_HEIGHT_M - BEAM_THICKNESS_M * 0.5 - BOARD_FRAME_M - BOARD_SIDE_M * 0.5
	var frame_side := BOARD_SIDE_M + BOARD_FRAME_M * 2.0
	for gate in GATE_COUNT:
		var board := Node3D.new()
		board.name = "Board%d" % (gate + 1)
		board.position = Vector3(board_offset_m(gate), center_y, 0.0)
		_root.add_child(board)
		Parts.box(board, Vector3(frame_side, frame_side, 0.05), Vector3.ZERO, Parts.gold())
		Parts.box(board, Vector3(BOARD_SIDE_M, BOARD_SIDE_M, 0.08), Vector3.ZERO, Parts.material(GateBadge.GATE_COLORS[gate], 0.7))
		# 後ろ（カメラの側。z＋）からも、前からも読めるように、表と裏に数字を書く。
		for face: float in [-1.0, 1.0]:
			Parts.label(board, str(gate + 1), BOARD_DIGIT_HEIGHT_M, GateBadge.text_color_for(gate), Vector3(0.0, -0.02, face * 0.045), Vector3(0.0, 0.0 if face > 0.0 else 180.0, 0.0))
