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
## 色1つあたりの枚数と、1枚の大きさ（m）。
const CONFETTI_PER_COLOR := 90
const CONFETTI_SIZE_M := Vector2(0.16, 0.09)
## まく場所（ゴールの線から見て）。高さ、前後の広がり、左右の広がりは、コース幅に対する割合。
const CONFETTI_HEIGHT_M := 6.0
const CONFETTI_DEPTH_M := 2.5
const CONFETTI_WIDTH_RATIO := 0.55
## 降りきるまでの秒数と、舞い散る速さ。
const CONFETTI_LIFETIME_S := 3.2
const CONFETTI_RISE_SPEED := Vector2(1.2, 3.4)
const CONFETTI_GRAVITY := -3.2

## ゆっくりにする強さ（1がふつうの速さ）と、その強さを保つ秒数、元に戻るまでの秒数（どちらも実時間）。
const SLOW_SCALE := 0.4
const SLOW_HOLD_S := 0.5
const SLOW_RECOVER_S := 0.8

var _slow_remaining := 0.0
var _played := false


## 1位がゴールした瞬間に、1回だけ呼ぶ。at は、ゴールの線のまん中（ワールド座標）。
## width_m は、紙吹雪を広げるコースの幅。
func play(parent: Node3D, at: Vector3, width_m: float) -> void:
	if _played:
		return
	_played = true
	_slow_remaining = SLOW_HOLD_S + SLOW_RECOVER_S
	Engine.time_scale = SLOW_SCALE
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = ROOT_NAME
	parent.add_child(root)
	root.global_position = at + Vector3(0.0, CONFETTI_HEIGHT_M, 0.0)
	for color: Color in CONFETTI_COLORS:
		root.add_child(_confetti(color, width_m))


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
	particles.amount = CONFETTI_PER_COLOR
	particles.lifetime = CONFETTI_LIFETIME_S
	particles.one_shot = true
	particles.explosiveness = 0.85
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
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 55.0
	process.initial_velocity_min = CONFETTI_RISE_SPEED.x
	process.initial_velocity_max = CONFETTI_RISE_SPEED.y
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
