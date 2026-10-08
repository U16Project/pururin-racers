extends Node3D
## 組み立てた、ぷるりんの体。表情（顔の部品の入れ替え）と、アクション（体全体と、体の一部の動かし方）の受け口。
## 顔の部品は、感情の名前ごとに登録しておく。その感情の部品が無いスロットは、ノーマルを出す。
## 動かし方は、アクションごとに、設定で持つ（書かれていないアクションでは、動かさない）。
## 体全体の動きは、この節そのものではなく、中の節（体の本体・部品・顔・マーク）に掛ける。
## この節の位置・向き・大きさは、使う側（走者、絵の舞台など）が自由に決めてよい。動きは見た目だけ。

## 必ず用意する表情の名前。
const NORMAL := "normal"
## 動かし方の種類と、必ず要る項目（あとから足せる）。体の一部（ヒレ・突起など）にも、体全体にも、同じ種類を使う。
## sway＝軸まわりに、行ったり来たり回す。lean＝軸まわりに、決まった角度だけ傾けたままにする。
## pulse＝大きくなったり小さくなったりする。grow＝決まった分だけ、大きくしたままにする。
## stretch＝1つの軸の向きに伸び縮みする（ほかの2つの向きは、かさが変わらないように逆へ動く）。hz が 0 なら、伸ばした（縮めた）ままにする。
## hop＝跳ねる（1秒に hz 回。地面に着く所で、squash のぶんだけ上下につぶれる）。
## circle＝水平に、輪を描いて動き回る。lift＝決まった高さだけ、持ち上げたままにする。
## 軸は、その部品の中の向き。体全体：x＝体の右、y＝上、z＝後ろ。頭の上の部品：同じ。左右・尾の部品：x＝体から外、y＝上。
## どれも、phase（0〜1。ゆれの出だしをずらす）を足せる。
const MOTION_TYPES := {
	"sway": {"numbers": ["angle_deg", "hz"], "axis": true},
	"lean": {"numbers": ["angle_deg"], "axis": true},
	"pulse": {"numbers": ["amount", "hz"], "axis": false},
	"grow": {"numbers": ["amount"], "axis": false},
	"stretch": {"numbers": ["amount", "hz"], "axis": true},
	"hop": {"numbers": ["height", "hz", "squash"], "axis": false},
	"circle": {"numbers": ["radius", "hz"], "axis": false},
	"lift": {"numbers": ["height"], "axis": false},
}
const AXES := {"x": 0, "y": 1, "z": 2}
## アクションが変わったとき、前の形から新しい動きへ、つなぐ時間（秒）。
const MOTION_BLEND_SECONDS := 0.25
## 左右への傾き（set_steer）が、目標へ追いつく速さ（1秒あたりの割合）。
const STEER_FOLLOW_PER_S := 6.0
## 顔のスロット。目、まゆ、口、ほっぺ、効果（汗・涙・キラキラなど）。
const FACE_SLOTS := ["eyes", "brows", "mouth", "cheeks", "effect"]

## 表情の名前 → スロット → その部品を作る関数。部品は、その表情を最初に出すときに作る
## （全部の表情を先に作ると、体を組み立てる時間が長くなるため）。
var _face_makers := {}
## 作り終えた部品。表情の名前 → スロット → その部品の節の並び。
var _face_nodes := {}
## 体の一部の部品。1つぶん：node（節）、motions（アクションの名前 → 動かし方の並び）、
## rest（動かす前の置き方）、from（アクションが変わったときの形）、shown（今の形）。
var _body_parts: Array = []
## 体全体の動かし方（設定の body_motions の1つ）。actions（アクションの名前 → 動かし方の並び）、
## one_shots（1回だけの動きの名前 → seconds と motions）、steer_lean_deg（左右へ動くときに傾ける角度）。
var _body_motion := {}
## 体全体の動きの、大きさと速さの倍率（個体ごと）。
var _body_amount := 1.0
var _body_speed := 1.0
var _body_time := 0.0
var _body_from: Array = pose_identity()
var _body_shown: Array = pose_identity()
## 体全体の、今の置き方（子の節に掛ける）。
var _body_transform := Transform3D.IDENTITY
## 体の中の節 → 動かす前の置き方。
var _rest := {}
var _blend_seconds := MOTION_BLEND_SECONDS
## 左右への傾き（−1〜1。＋で体の右へ傾く）。目標と、今の値。
var _steer_target := 0.0
var _steer := 0.0
## 再生中の、1回だけの動き。名前（空なら無し）と、始めてからの秒数。
var _one_shot := ""
var _one_shot_seconds := 0.0
var _body_material: Material
var _expression := NORMAL
var _action := ""
var _motion_rate := 1.0
var _motion_time := 0.0


## 顔の部品を登録する。maker は、部品の節の並びを作って返す関数（何も出さないスロットは、空の並びを返す）。
func register_face(expression: String, slot: String, maker: Callable) -> void:
	if not _face_makers.has(expression):
		_face_makers[expression] = {}
	_face_makers[expression][slot] = maker


func register_body_part(node: Node3D, motions: Dictionary) -> void:
	_body_parts.append({"node": node, "motions": motions, "rest": node.transform, "from": pose_identity(), "shown": pose_identity()})
	_rest[node] = node.transform


## 体全体の動かし方（設定の body_motions の1つ）と、その個体の、大きさ・速さの倍率。
func set_body_motion(motion: Dictionary, amount: float, speed: float) -> void:
	_body_motion = motion
	_body_amount = amount
	_body_speed = speed


func set_body_material(material: Material) -> void:
	_body_material = material


## 体を塗っている素材（接触の演出など、色を変えるときに使う）。
func body_material() -> Material:
	return _body_material


## 体を白く光らせる量（接触の演出）。0で、光らせない。
func set_glow(amount: float) -> void:
	(_body_material as ShaderMaterial).set_shader_parameter("glow", amount)


func glow() -> float:
	return float((_body_material as ShaderMaterial).get_shader_parameter("glow"))


## 用意されている表情の名前。
func expression_names() -> Array:
	return _face_makers.keys()


## 表情を変える。その感情の部品が無いスロットは、ノーマルを出す。
func set_expression(expression: String) -> void:
	_expression = expression
	for slot: String in FACE_SLOTS:
		var shown := shown_expression_for(slot)
		_make_face(shown, slot)
		for name: String in _face_nodes:
			for node: Node3D in _face_nodes[name].get(slot, []):
				node.visible = name == shown
	_place_children()


## まだ作っていない部品なら、作って、体に付ける。
func _make_face(expression: String, slot: String) -> void:
	if not _face_makers.get(expression, {}).has(slot) or _face_nodes.get(expression, {}).has(slot):
		return
	var nodes: Array = (_face_makers[expression][slot] as Callable).call()
	for node: Node3D in nodes:
		add_child(node)
	if not _face_nodes.has(expression):
		_face_nodes[expression] = {}
	_face_nodes[expression][slot] = nodes


func expression() -> String:
	return _expression


## そのスロットで、今出している部品の表情の名前（部品が無ければ、ノーマル）。
func shown_expression_for(slot: String) -> String:
	return _expression if _face_makers.get(_expression, {}).has(slot) else NORMAL


## アクションを変える。体全体と、体の一部の部品が、そのアクションの動かし方に切り替わる
## （動かし方が書かれていないものは、動かさない）。切り替えは、今の形から、なめらかにつなぐ。
func set_action(action: String) -> void:
	if action == _action:
		return
	_action = action
	_blend_seconds = 0.0
	_body_from = _body_shown
	for part: Dictionary in _body_parts:
		part["from"] = part["shown"]


func action() -> String:
	return _action


## 動きの速さの倍率（1がふつう）。走る速さに合わせて、動きを速くするときに使う。
func set_motion_rate(rate: float) -> void:
	_motion_rate = rate


func motion_rate() -> float:
	return _motion_rate


## 左右への傾き（−1〜1。＋で体の右へ傾く）。横へ動いているときや、カーブで使う。
func set_steer(amount: float) -> void:
	_steer_target = clampf(amount, -1.0, 1.0)


func steer() -> float:
	return _steer


## 1回だけの動きを、今のアクションの動きに重ねて出す（スタートの飛び出し、選んだときの跳ね、など）。
func play_once(one_shot: String) -> void:
	assert((_body_motion.get("one_shots", {}) as Dictionary).has(one_shot), "1回だけの動きが、設定にありません: %s" % one_shot)
	_one_shot = one_shot
	_one_shot_seconds = 0.0


## 再生中の、1回だけの動きの名前（無ければ空）。
func playing_once() -> String:
	return _one_shot


## そのアクションで動く、体の一部の部品。
func parts_moving_in(action: String) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for part: Dictionary in _body_parts:
		if not (part["motions"] as Dictionary).get(action, []).is_empty():
			nodes.append(part["node"])
	return nodes


func _process(delta: float) -> void:
	advance_motion(delta)


## 体全体と、体の一部の部品を、今のアクションの動かし方で動かす。
func advance_motion(delta: float) -> void:
	_motion_time += delta * _motion_rate
	_body_time += delta * _motion_rate * _body_speed
	_blend_seconds = minf(_blend_seconds + delta, MOTION_BLEND_SECONDS)
	var blend := smoothstep(0.0, 1.0, _blend_seconds / MOTION_BLEND_SECONDS)
	# 体全体：アクションの動き（個体ごとの大きさを掛ける）。
	var body_target := pose_scaled(motion_pose((_body_motion.get("actions", {}) as Dictionary).get(_action, []), _body_time), _body_amount)
	_body_shown = pose_lerp(_body_from, body_target, blend)
	var body_pose: Array = _body_shown
	# 左右への傾き。＋（体の右へ）は、後ろ向きの軸（z）まわりに、マイナスへ回す。
	_steer = lerpf(_steer, _steer_target, clampf(delta * STEER_FOLLOW_PER_S, 0.0, 1.0))
	if _steer != 0.0:
		body_pose = pose_added(body_pose, [Vector3(0.0, 0.0, -deg_to_rad(float(_body_motion.get("steer_lean_deg", 0.0))) * _steer * _body_amount), Vector3.ONE, Vector3.ZERO])
	# 1回だけの動き：出だしと終わりをなめらかにして、重ねる。
	if _one_shot != "":
		var one_shot: Dictionary = _body_motion["one_shots"][_one_shot]
		_one_shot_seconds += delta
		var progress := _one_shot_seconds / float(one_shot["seconds"])
		if progress >= 1.0:
			_one_shot = ""
		else:
			body_pose = pose_added(body_pose, pose_scaled(motion_pose(one_shot["motions"], _one_shot_seconds), sin(PI * progress) * _body_amount))
	_body_transform = pose_transform(body_pose)
	# 体の一部の部品。
	for part: Dictionary in _body_parts:
		part["shown"] = pose_lerp(part["from"], motion_pose(part["motions"].get(_action, []), _motion_time), blend)
	_place_children()


## 体の中の節を、体全体の置き方（と、部品ごとの動き）に合わせて置く。見えていない節は、飛ばす。
func _place_children() -> void:
	var part_poses := {}
	for part: Dictionary in _body_parts:
		part_poses[part["node"]] = part["shown"]
	for child in get_children():
		var node := child as Node3D
		if node == null or not node.visible:
			continue
		if not _rest.has(node):
			_rest[node] = node.transform
		var placed: Transform3D = _body_transform * (_rest[node] as Transform3D)
		if part_poses.has(node):
			placed = placed * pose_transform(part_poses[node])
		node.transform = placed


## 動かない形（[回す角度, 大きさ, ずらす量]）。
static func pose_identity() -> Array:
	return [Vector3.ZERO, Vector3.ONE, Vector3.ZERO]


## 動かし方の並びから、その時刻の形を求める。
## 形は、[回す角度（ラジアン。x・y・z の軸まわり）, 大きさ（x・y・z の倍率）, ずらす量（m）]。
static func motion_pose(motions: Array, time_s: float) -> Array:
	var turn := Vector3.ZERO
	var size := Vector3.ONE
	var offset := Vector3.ZERO
	for motion: Dictionary in motions:
		var hz := float(motion.get("hz", 0.0))
		var phase := float(motion.get("phase", 0.0))
		var wave := sin(TAU * (hz * time_s + phase))
		match str(motion["type"]):
			"sway":
				turn[AXES[str(motion["axis"])]] += deg_to_rad(float(motion["angle_deg"])) * wave
			"lean":
				turn[AXES[str(motion["axis"])]] += deg_to_rad(float(motion["angle_deg"]))
			"pulse":
				size *= 1.0 + float(motion["amount"]) * wave
			"grow":
				size *= 1.0 + float(motion["amount"])
			"stretch":
				# hz が 0 なら、伸ばした（縮めた）ままにする。
				size *= stretch_scale(AXES[str(motion["axis"])], float(motion["amount"]) * (1.0 if hz == 0.0 else wave))
			"hop":
				# 1秒に hz 回、跳ねる。地面に着く所でつぶれ、一番高い所で少し伸びる。
				var air := absf(sin(PI * (hz * time_s + phase)))
				offset.y += float(motion["height"]) * air
				size *= stretch_scale(1, float(motion["squash"]) * (0.4 * air - pow(1.0 - air, 2.0)))
			"circle":
				var angle := TAU * (hz * time_s + phase)
				offset += Vector3(cos(angle) - 1.0, 0.0, sin(angle)) * float(motion["radius"])
			"lift":
				offset.y += float(motion["height"])
	return [turn, size, offset]


## 1つの軸の向きに (1 + amount) 倍する大きさ。ほかの2つの向きは、かさが変わらないように逆へ動かす。
static func stretch_scale(axis: int, amount: float) -> Vector3:
	var along := maxf(1.0 + amount, 0.05)
	var across := 1.0 / sqrt(along)
	var size := Vector3(across, across, across)
	size[axis] = along
	return size


## 2つの形の間（t＝0 で a、1 で b）。
static func pose_lerp(a: Array, b: Array, t: float) -> Array:
	return [(a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t), (a[2] as Vector3).lerp(b[2], t)]


## 形の、動きの大きさを amount 倍にする（0 で動かない形、1 でそのまま）。
static func pose_scaled(pose: Array, amount: float) -> Array:
	return [(pose[0] as Vector3) * amount, Vector3.ONE + ((pose[1] as Vector3) - Vector3.ONE) * amount, (pose[2] as Vector3) * amount]


## 形に、別の形を重ねる。
static func pose_added(pose: Array, extra: Array) -> Array:
	return [(pose[0] as Vector3) + (extra[0] as Vector3), (pose[1] as Vector3) * (extra[1] as Vector3), (pose[2] as Vector3) + (extra[2] as Vector3)]


## 形を、置き方に直す（大きさを変えてから、回して、ずらす）。
static func pose_transform(pose: Array) -> Transform3D:
	return Transform3D(Basis.from_euler(pose[0]) * Basis.from_scale(pose[1]), pose[2])


func body_part_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for part: Dictionary in _body_parts:
		nodes.append(part["node"])
	return nodes
