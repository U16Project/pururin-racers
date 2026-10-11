extends RefCounted
## 1位がゴールした瞬間の演出。ゴールの上に紙吹雪をまき、ほんの少しのあいだ、ゆっくりにする。
## 生成ノードの寿命は、渡された親が所有する（紙吹雪は、降り終わったら自分で消える）。

const Parts := preload("res://scripts/presentation/venue_parts.gd")

const ROOT_NAME := "FinishCelebration"
## 紙吹雪の色。色ごとに1つずつ、まとめて降らせる。
const CONFETTI_COLORS := [
	Color("#ff5a6e"), Color("#ffd24d"), Color("#4aa9ff"),
	Color("#5fd98a"), Color("#ff8fd0"), Color("#ffffff"),
]
## 1本の紙吹雪帯・1色あたりの枚数と、1枚の大きさ（m）。
## 帯を複数に分けても、合計枚数が極端に増えないようにする。
const CONFETTI_PER_COLOR_PER_STRIP := 24
const CONFETTI_SIZE_M := Vector2(0.16, 0.09)
## まく場所（ゴール線より先）。先頭が止まる前の進行方向へ寄せ、画面内に残す。
const CONFETTI_BEYOND_GOAL_M := 12.0
## 1点から噴き出すのではなく、ゴール先の進行方向へ複数の帯として広げる。
const CONFETTI_STRIP_OFFSETS_M := [0.0, 9.0, 18.0, 27.0]
const CONFETTI_HEIGHT_M := 3.8
const CONFETTI_DEPTH_M := 3.5
const CONFETTI_WIDTH_RATIO := 0.55
## 降りきるまでの秒数と、舞い散る速さ。
const CONFETTI_LIFETIME_S := 3.2
const CONFETTI_FALL_SPEED := Vector2(1.2, 3.4)
const CONFETTI_GRAVITY := -3.2
const CONFETTI_EXPLOSIVENESS := 0.35

## ゆっくりにする強さ（1がふつうの速さ）と、その強さを保つ秒数、元に戻るまでの秒数（どちらも実時間）。
const SLOW_SCALE := 0.4
const SLOW_HOLD_S := 0.5
const SLOW_RECOVER_S := 0.8

var _slow_remaining := 0.0
var _played := false
var _slow_started := false


## 1位がゴール前後に、1回だけ呼ぶ。at は、ゴールの線のまん中（ワールド座標）。
## width_m は、紙吹雪を広げるコースの幅。
func play(parent: Node3D, at: Vector3, width_m: float, travel: Vector3 = Vector3.ZERO, slow_on_start: bool = true) -> void:
	if _played:
		if slow_on_start:
			start_slow_motion()
		return
	_played = true
	if slow_on_start:
		start_slow_motion()
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = ROOT_NAME
	parent.add_child(root)
	var forward := travel.normalized() if travel.length_squared() > 0.0001 else Vector3.ZERO
	root.global_position = at + forward * CONFETTI_BEYOND_GOAL_M + Vector3.UP * CONFETTI_HEIGHT_M
	for strip_index: int in CONFETTI_STRIP_OFFSETS_M.size():
		var strip := Node3D.new()
		strip.name = "ConfettiStrip%02d" % strip_index
		strip.position = forward * CONFETTI_STRIP_OFFSETS_M[strip_index]
		root.add_child(strip)
		for color: Color in CONFETTI_COLORS:
			strip.add_child(_confetti(color, width_m))


## 紙吹雪とは分けて、ゴール線を通過した瞬間だけスローを始める。
func start_slow_motion() -> void:
	if _slow_started:
		return
	_slow_started = true
	_slow_remaining = SLOW_HOLD_S + SLOW_RECOVER_S
	Engine.time_scale = SLOW_SCALE


func has_played() -> bool:
	return _played


## 毎フレーム呼ぶ。delta は、場面がそのまま受け取っている（ゆっくりの影響を受けた）値でよい。
func advance(delta: float) -> void:
	if _slow_remaining <= 0.0:
		return
	# ゆっくりの最中は delta も縮むので、実時間に直してから数える。
	_slow_remaining = maxf(_slow_remaining - delta / maxf(Engine.time_scale, 0.01), 0.0)
	Engine.time_scale = slow_scale(_slow_remaining)


## 場面を抜けるときなどに呼ぶ。速さを、すぐふつうに戻す。
func stop() -> void:
	_slow_remaining = 0.0
	_slow_started = false
	Engine.time_scale = 1.0


func is_playing() -> bool:
	return _slow_remaining > 0.0


## 残り時間（実時間の秒）から、今の速さを求める。保つあいだは SLOW_SCALE のまま、
## そのあと、残りが0になるまでに、ふつうの速さ（1.0）へ戻す。
static func slow_scale(remaining_s: float) -> float:
	if remaining_s <= 0.0:
		return 1.0
	if remaining_s >= SLOW_RECOVER_S:
		return SLOW_SCALE
	return lerpf(1.0, SLOW_SCALE, remaining_s / SLOW_RECOVER_S)


## 色1つぶんの紙吹雪。1回だけまいて、降り終わったら自分で消える。
func _confetti(color: Color, width_m: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Confetti%s" % color.to_html(false)
	particles.amount = CONFETTI_PER_COLOR_PER_STRIP
	particles.lifetime = CONFETTI_LIFETIME_S
	particles.one_shot = true
	# 一瞬の柱状の噴出ではなく、帯ごとに少し時間差を持って降らせる。
	particles.explosiveness = CONFETTI_EXPLOSIVENESS
	particles.randomness = 0.5
	particles.emitting = true
	var quad := QuadMesh.new()
	quad.size = CONFETTI_SIZE_M
	particles.draw_pass_1 = quad
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = surface
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(width_m * CONFETTI_WIDTH_RATIO, 0.6, CONFETTI_DEPTH_M)
	# 上へ打ち上げず、低い位置からすぐ下へ落とす。ゴール後に置き去りにしない。
	process.direction = Vector3.DOWN
	process.spread = 38.0
	process.initial_velocity_min = CONFETTI_FALL_SPEED.x
	process.initial_velocity_max = CONFETTI_FALL_SPEED.y
	process.gravity = Vector3(0.0, CONFETTI_GRAVITY, 0.0)
	process.damping_min = 0.4
	process.damping_max = 1.2
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.angular_velocity_min = -220.0
	process.angular_velocity_max = 220.0
	particles.process_material = process
	particles.finished.connect(particles.queue_free)
	return particles
