extends MeshInstance3D
## 自分のぷるりんの足元の、地面の目印。光る輪と、そのまわりを回る、内向きの矢じり。
## 走者（親の節）の今の状態を映す：矢じりの数＝ノッチ、矢じりの色＝心拍の色、回る速さ＝心拍数、輪の色＝体力の色。
## 色は操作盤と同じ決め方だが、少し白を混ぜて、やわらかくする。色と速さは、なめらかに変える。
## 輪のうしろ側（カメラ側）に重ねて、ノッチ → 速さ → 心拍数 を、順番に、うすく点滅させて出す（数字は大きく、名前・単位は小さく）。
## ノッチが変わったら、ノッチの表示に戻る。
## 見た目だけ（当たり判定・走りには関係しない）。走者の子にして、足元（原点）に置く。

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
## 輪の内側と外側の半径（m）。体（半径0.75m）の、少し外。
const RING_INNER_M := 0.95
const RING_OUTER_M := 1.12
## 矢じりの、外の端・先の半径（m）と、幅（度）。
const ARROW_OUTER_M := 1.42
const ARROW_TIP_M := 1.16
const ARROW_HALF_WIDTH_DEG := 9.0
## 走者の足元からの高さ（m）。コースの帯（走る面）は、足元より0.12m高いので、その少し上に置く。
const HEIGHT_M := 0.16
## 明るさの下限と上限、脈の速さ（回/秒）。
const ALPHA_MIN := 0.45
const ALPHA_MAX := 0.8
const PULSE_HZ := 0.8
## 回る速さ（度/秒）。心拍が下限のときと、上限のとき。
const TURN_MIN_DEG_PER_S := 20.0
const TURN_MAX_DEG_PER_S := 110.0
## 色に混ぜる白の割合（きつい色にしない）と、色・速さが目標へ追いつく速さ（1秒あたりの割合）。
const SOFTEN := 0.3
const FOLLOW_PER_S := 3.0
const SEGMENTS := 48
const ARROWS_NAME := "Arrows"
const INFO_VALUE_NAME := "InfoValue"
const INFO_WORD_NAME := "InfoWord"
## 地面の文字：目印の中心からうしろへの距離（m。輪の上に重なる位置）、輪からの浮かせ（m）、
## 数字の大きさ、名前・単位の大きさ、左右の文字のあいだ（m）、1つを出している時間（秒）、一番濃いときの濃さ。
## 文字の色は、操作盤の数値と同じ。
const INFO_BEHIND_M := 1.5
const INFO_LIFT_M := 0.03
## 文字の起こし具合（度）。0＝地面に寝かせる、90＝まっすぐ立てる。カメラの方へ起こして、読みやすくする。
const INFO_TILT_DEG := 35.0
const INFO_VALUE_FONT_SIZE := 96
const INFO_WORD_FONT_SIZE := 46
const INFO_PIXEL_SIZE_M := 0.0033
const INFO_GAP_M := 0.05
const INFO_STEP_S := 1.6
const INFO_ALPHA_MAX := 0.88
const INFO_COLOR := RaceHud.COLOR_GOLD
## 描く順番（大きいほど後＝手前）。透ける体のぷるりんより後に描く。
const INFO_RENDER_PRIORITY := 100
const INFO_COUNT := 3

var _ring_material: StandardMaterial3D
var _arrow_material: StandardMaterial3D
var _arrows: MeshInstance3D
var _arrow_count := -1
var _seconds := 0.0
var _turn_deg_per_s := TURN_MIN_DEG_PER_S
var _ring_color := Color.WHITE
var _arrow_color := Color.WHITE
var _has_state := false
var _info_value: Label3D
var _info_word: Label3D
var _info_index := 0
var _info_seconds := 0.0
var _info_notch := -1


func _ready() -> void:
	name = "PlayerGroundMarker"
	mesh = build_ring_mesh()
	position = Vector3(0.0, HEIGHT_M, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_material = _flat_material()
	material_override = _ring_material
	_arrows = MeshInstance3D.new()
	_arrows.name = ARROWS_NAME
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow_material = _flat_material()
	_arrows.material_override = _arrow_material
	add_child(_arrows)
	# 文字は2つに分ける。数字は、ぷるりんの真うしろ（まん中）に。名前・単位は、その横に小さく。
	_info_value = _info_label(INFO_VALUE_NAME, INFO_VALUE_FONT_SIZE)
	_info_word = _info_label(INFO_WORD_NAME, INFO_WORD_FONT_SIZE)


## 輪のうしろ側に置く文字。カメラ（うしろ）の方へ起こしてある。
func _info_label(label_name: String, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.rotation.x = deg_to_rad(INFO_TILT_DEG - 90.0)
	label.position = Vector3(0.0, INFO_LIFT_M, INFO_BEHIND_M)
	label.font_size = font_size
	label.outline_size = font_size / 6
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.pixel_size = INFO_PIXEL_SIZE_M
	label.shaded = false
	label.double_sided = true
	# いつも一番手前に描く（ぷるりんの体や尻尾、ほかのぷるりんに隠れない）。
	label.no_depth_test = true
	label.render_priority = INFO_RENDER_PRIORITY
	label.outline_render_priority = INFO_RENDER_PRIORITY - 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label


static func _flat_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _process(delta: float) -> void:
	var runner := get_parent()
	if runner != null and runner.has_method("get_drive_level"):
		show_state(
			int(roundi(float(runner.call("get_drive_level")))),
			float(runner.call("get_heart_rate_bpm")),
			float(runner.call("get_stamina_ratio")),
			delta
		)
		show_info(int(roundi(float(runner.call("get_drive_level")))), float(runner.call("get_actual_speed")), float(runner.call("get_heart_rate_bpm")), delta)


## 走者の状態を映す。notch＝ノッチ、heart_bpm＝心拍数、fuel_ratio＝体力の割合。
func show_state(notch: int, heart_bpm: float, fuel_ratio: float, delta: float) -> void:
	var heart_state := {
		"heart_bpm": heart_bpm,
		"heart_min_bpm": LocalRaceMath.Config.number("heart_rate_min_bpm"),
		"heart_normal_max_bpm": LocalRaceMath.Config.number("heart_rate_normal_max_bpm"),
		"heart_max_bpm": LocalRaceMath.Config.number("heart_rate_overheat_max_bpm"),
	}
	var count := arrow_count_for(notch)
	if count != _arrow_count:
		_arrow_count = count
		_arrows.mesh = build_arrows_mesh(count)
	var ring_target := soft_color(RaceHud.fuel_color(fuel_ratio))
	var arrow_target := soft_color(RaceHud.heart_color(heart_state))
	var turn_target := turn_speed_for(heart_bpm, float(heart_state["heart_min_bpm"]), float(heart_state["heart_max_bpm"]))
	# 最初の1回は、そのままの値から始める。あとは、なめらかに近づける。
	var follow := 1.0 if not _has_state else clampf(delta * FOLLOW_PER_S, 0.0, 1.0)
	_has_state = true
	_ring_color = _ring_color.lerp(ring_target, follow)
	_arrow_color = _arrow_color.lerp(arrow_target, follow)
	_turn_deg_per_s = lerpf(_turn_deg_per_s, turn_target, follow)
	_seconds += delta
	_arrows.rotation.y += deg_to_rad(_turn_deg_per_s) * delta
	var alpha := alpha_at(_seconds)
	_ring_material.albedo_color = Color(_ring_color, alpha)
	_arrow_material.albedo_color = Color(_arrow_color, alpha)


## 地面の文字を進める。ノッチ → 速さ → 心拍数 の順に、1つずつ、ふわっと出して消す。ノッチが変わったら、ノッチに戻る。
func show_info(notch: int, speed_kmh: float, heart_bpm: float, delta: float) -> void:
	if notch != _info_notch:
		_info_notch = notch
		_info_index = 0
		_info_seconds = 0.0
	else:
		_info_seconds += delta
		while _info_seconds >= INFO_STEP_S:
			_info_seconds -= INFO_STEP_S
			_info_index = (_info_index + 1) % INFO_COUNT
	var parts := info_parts(_info_index, notch, speed_kmh, heart_bpm)
	var alpha := info_alpha_at(_info_seconds)
	_info_value.text = str(parts[0])
	_info_word.text = str(parts[1])
	# 名前・単位は、数字の幅の半分だけ横へずらして、数字のとなりに置く。
	var half_value_m := ThemeDB.fallback_font.get_string_size(_info_value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_VALUE_FONT_SIZE).x * INFO_PIXEL_SIZE_M * 0.5
	var word_on_left := bool(parts[2])
	_info_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if word_on_left else HORIZONTAL_ALIGNMENT_LEFT
	_info_word.position.x = (half_value_m + INFO_GAP_M) * (-1.0 if word_on_left else 1.0)
	for label: Label3D in [_info_value, _info_word]:
		label.modulate = Color(INFO_COLOR, alpha)
		label.outline_modulate = Color(RaceHud.COLOR_OUTLINE, alpha * RaceHud.COLOR_OUTLINE.a)


## 地面の文字。index＝0：ノッチ、1：速さ、2：心拍数。
## 返すのは [数字, 名前・単位, 名前・単位を数字の左に置くか]。ノッチは、0を出さない（一番下は1）。
static func info_parts(index: int, notch: int, speed_kmh: float, heart_bpm: float) -> Array:
	match index:
		0: return ["%d" % maxi(notch, 1), "ノッチ", true]
		1: return ["%d" % int(round(speed_kmh)), "km/h", false]
	return ["%d" % int(round(heart_bpm)), "bpm", false]


## 1つの文字を出しているあいだの濃さ（出はじめと消えぎわは0、まん中が一番濃い）。
static func info_alpha_at(seconds: float) -> float:
	return INFO_ALPHA_MAX * sin(PI * clampf(seconds / INFO_STEP_S, 0.0, 1.0))


## 矢じりの数。ノッチの数と同じ（0以下なら、出さない）。
static func arrow_count_for(notch: int) -> int:
	return clampi(notch, 0, int(LocalRaceMath.DRIVE_LEVEL_MAX))


## 回る速さ（度/秒）。心拍が下限なら一番ゆっくり、上限なら一番速い。
static func turn_speed_for(heart_bpm: float, heart_min_bpm: float, heart_max_bpm: float) -> float:
	return lerpf(TURN_MIN_DEG_PER_S, TURN_MAX_DEG_PER_S, clampf((heart_bpm - heart_min_bpm) / maxf(heart_max_bpm - heart_min_bpm, 0.001), 0.0, 1.0))


## 色に、少し白を混ぜる（きつい色にしない）。
static func soft_color(color: Color) -> Color:
	return Color(color, 1.0).lerp(Color.WHITE, SOFTEN)


## その時刻の、明るさ（透けぐあい）。
static func alpha_at(seconds: float) -> float:
	return lerpf(ALPHA_MIN, ALPHA_MAX, 0.5 + 0.5 * sin(TAU * PULSE_HZ * seconds))


static func _point(radius: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## 輪の、平らなメッシュ（上向き）。
static func build_ring_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for index in SEGMENTS:
		var a0 := TAU * float(index) / float(SEGMENTS)
		var a1 := TAU * float(index + 1) / float(SEGMENTS)
		vertices.append_array(PackedVector3Array([
			_point(RING_INNER_M, a0), _point(RING_OUTER_M, a0), _point(RING_OUTER_M, a1),
			_point(RING_INNER_M, a0), _point(RING_OUTER_M, a1), _point(RING_INNER_M, a1),
		]))
	return _flat_mesh(vertices)


## 矢じり count 個の、平らなメッシュ（輪のまわりに、等しい間で並べる）。0個なら null。
static func build_arrows_mesh(count: int) -> ArrayMesh:
	if count <= 0:
		return null
	var vertices := PackedVector3Array()
	var half := deg_to_rad(ARROW_HALF_WIDTH_DEG)
	for index in count:
		var angle := TAU * float(index) / float(count)
		vertices.append_array(PackedVector3Array([_point(ARROW_OUTER_M, angle - half), _point(ARROW_OUTER_M, angle + half), _point(ARROW_TIP_M, angle)]))
	return _flat_mesh(vertices)


static func _flat_mesh(vertices: PackedVector3Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
