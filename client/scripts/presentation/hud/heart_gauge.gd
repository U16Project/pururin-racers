@tool
extends ColorRect
## ハートのゲージ。光るふち、中のガラス、値（value。0〜1）の分だけ下から入る水。
## 形・色・光り方は、エディタの右の欄で変えられ、エディタの中ですぐ見える（@tool）。描くのは heart_gauge.gdshader。
## 位置（center）は、この部品の左上からの点。
## ゲームのコードが変えるのは、value（水の高さ）、water_color（水の色。心拍で変わる）、beat（鼓動の光）だけ。

const HeartShader := preload("res://scripts/presentation/hud/heart_gauge.gdshader")

## 水の高さ（0＝空、1＝満タン）。
@export_range(0.0, 1.0, 0.001) var value := 0.5:
	set(next):
		value = clampf(next, 0.0, 1.0)
		_push()
## 鼓動の光（0〜1。1で一番明るい）。
@export_range(0.0, 1.0, 0.01) var beat := 0.0:
	set(next):
		beat = clampf(next, 0.0, 1.0)
		_push()

@export_group("形")
## ハートのまん中（この部品の左上から）と、横・縦の大きさ（式の1あたりのピクセル）。
@export var center := Vector2(100.0, 100.0):
	set(next):
		center = next
		_push()
@export var size_x := 80.0:
	set(next):
		size_x = next
		_push()
@export var size_y := 80.0:
	set(next):
		size_y = next
		_push()
## 上のくぼみの浅さ（大きいほど浅く、全体が丸い）。
@export_range(0.8, 2.0, 0.01) var dip := 1.25:
	set(next):
		dip = next
		_push()
## 鼓動のいちばん強い瞬間に、ハートが大きくなる割合（0.06＝6%大きくなる）。
@export_range(0.0, 0.3, 0.01) var beat_grow := 0.06:
	set(next):
		beat_grow = next
		_push()

@export_group("水")
@export var water_color := Color(0.2, 0.92, 1.0, 1.0):
	set(next):
		water_color = next
		_push()
## 水の底の暗さ、波の高さと長さ、水面の線、横じまの間かくと濃さ。
@export_range(0.0, 1.0, 0.01) var water_bottom_shade := 0.25:
	set(next):
		water_bottom_shade = next
		_push()
@export var wave_height := 3.0:
	set(next):
		wave_height = next
		_push()
@export var wave_length := 40.0:
	set(next):
		wave_length = next
		_push()
@export var surface_color := Color(1.0, 1.0, 1.0, 0.7):
	set(next):
		surface_color = next
		_push()
@export var surface_width := 3.0:
	set(next):
		surface_width = next
		_push()
@export var stripe_spacing := 6.0:
	set(next):
		stripe_spacing = next
		_push()
@export_range(0.0, 1.0, 0.01) var stripe_strength := 0.12:
	set(next):
		stripe_strength = next
		_push()

@export_group("ガラス")
@export var glass_color := Color(0.08, 0.11, 0.2, 0.92):
	set(next):
		glass_color = next
		_push()
@export_range(0.0, 1.0, 0.01) var gloss_strength := 0.25:
	set(next):
		gloss_strength = next
		_push()

@export_group("ふち")
@export var edge_color := Color(1.0, 0.2, 0.7, 1.0):
	set(next):
		edge_color = next
		_push()
@export var edge_width := 6.0:
	set(next):
		edge_width = next
		_push()
@export var edge_core_color := Color(1.0, 0.82, 0.95, 1.0):
	set(next):
		edge_core_color = next
		_push()
@export var edge_core_width := 1.5:
	set(next):
		edge_core_width = next
		_push()
@export var glow_width := 18.0:
	set(next):
		glow_width = next
		_push()
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.55:
	set(next):
		glow_strength = next
		_push()
@export var beat_color := Color(1.0, 0.96, 0.98, 1.0):
	set(next):
		beat_color = next
		_push()

## 水面の波を動かすか（エディタの中では止める）と、その速さ。
@export var wave_speed := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_push):
		resized.connect(_push)
	_push()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or wave_speed == 0.0:
		return
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("wave_phase", Time.get_ticks_msec() / 1000.0 * wave_speed)


## 欄の値を、描く側（シェーダー）へ渡す。
func _push() -> void:
	if not is_inside_tree():
		return
	if not _fitting:
		_fit_rect()
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader != HeartShader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = HeartShader
		material = shader_material
	for key: String in ["center", "size_x", "size_y", "dip", "water_color", "water_bottom_shade", "wave_height", "wave_length", "surface_color", "surface_width", "stripe_spacing", "stripe_strength", "glass_color", "gloss_strength", "edge_color", "edge_width", "edge_core_color", "edge_core_width", "glow_width", "glow_strength", "beat", "beat_color"]:
		shader_material.set_shader_parameter(key, get(key))
	# 鼓動で、ハートを少しふくらませる。
	shader_material.set_shader_parameter("size_x", size_x * (1.0 + beat_grow * beat))
	shader_material.set_shader_parameter("size_y", size_y * (1.0 + beat_grow * beat))
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("fill", value)


## 四角を合わせている最中か（合わせるときに変える値で、また合わせ直さないように）。
var _fitting := false


## 描いている所の四角（この部品の左上から）。ハートと、ふち・まわりの光のはみ出しを含む。
## ハートの上のてっぺんは、まん中から 1.577 ÷ dip、下の先は 1 ÷ dip（縦の大きさ1あたり）。
func drawn_rect() -> Rect2:
	var margin := edge_width + glow_width * 2.5 + 4.0
	var top := center.y - 1.577 / dip * size_y
	var bottom := center.y + 1.0 / dip * size_y
	return Rect2(Vector2(center.x - size_x, top), Vector2(size_x * 2.0, bottom - top)).grow(margin)


## この部品の四角を、描いている所に合わせる（見た目の位置は変えない）。回したり縮めたりしているときは、合わせない。
func _fit_rect() -> void:
	if rotation != 0.0 or scale != Vector2.ONE:
		return
	var box := drawn_rect()
	if box.position.distance_to(Vector2.ZERO) < 0.5 and box.size.distance_to(size) < 0.5:
		return
	_fitting = true
	position += box.position
	center -= box.position
	size = box.size
	_fitting = false

