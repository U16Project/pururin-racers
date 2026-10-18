@tool
extends ColorRect
## 弧のゲージ。段々なしで、値（value。0〜1）の割合だけ、なめらかに色を塗る。
## 形・色・光り方は、エディタの右の欄で変えられ、エディタの中ですぐ見える（@tool）。描くのは arc_gauge.gdshader。
## 位置（center）は、この部品の左上からの点。角度は、12時を0として時計まわりの度。
## 終わりの角度（end_deg）が始まり（start_deg）より小さければ、反時計まわりに進む。
## ゲームのコードが変えるのは value だけ。

const ArcShader := preload("res://scripts/presentation/hud/arc_gauge.gdshader")

## 今の値（0〜1）。
@export_range(0.0, 1.0, 0.001) var value := 1.0:
	set(next):
		value = clampf(next, 0.0, 1.0)
		_push()

@export_group("形")
## 弧のまん中（この部品の左上から）。
@export var center := Vector2(100.0, 100.0):
	set(next):
		center = next
		_push()
## 弧の半径（太さのまん中まで）と、太さ。
@export var radius := 80.0:
	set(next):
		radius = next
		_push()
@export var thickness := 20.0:
	set(next):
		thickness = next
		_push()
## 始まりと終わりの角度（12時が0、時計まわり）。
@export_range(-360.0, 720.0, 0.5) var start_deg := 0.0:
	set(next):
		start_deg = next
		_push()
@export_range(-360.0, 720.0, 0.5) var end_deg := 90.0:
	set(next):
		end_deg = next
		_push()

## 先の丸み（ピクセル）。太さの半分で半円。光っている所の伸びていく先と、下の2つで選んだはしを丸くする。
@export var cap_radius := 0.0:
	set(next):
		cap_radius = maxf(next, 0.0)
		_push()
## 始まりのはし・終わりのはしを丸くするか。別の弧とつながっているはし（体力の0の所など）は、切る（途切れないように）。
@export var round_start := true:
	set(next):
		round_start = next
		_push()
@export var round_end := true:
	set(next):
		round_end = next
		_push()

@export_group("色")
## 弧の始まりから終わりまでの色。
@export var gradient: Gradient:
	set(next):
		if gradient != null and gradient.changed.is_connected(_push):
			gradient.changed.disconnect(_push)
		gradient = next
		if gradient != null and not gradient.changed.is_connected(_push):
			gradient.changed.connect(_push)
		_push()
## 空の所の色と、そのふちの線の色。
@export var track_color := Color(1.0, 1.0, 1.0, 0.08):
	set(next):
		track_color = next
		_push()
@export var track_edge_color := Color(0.6, 0.8, 1.0, 0.35):
	set(next):
		track_edge_color = next
		_push()

@export_group("光り方")
## まわりの光の広がり（ピクセル）と濃さ。
@export var glow_width := 10.0:
	set(next):
		glow_width = next
		_push()
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.5:
	set(next):
		glow_strength = next
		_push()
## 外寄りのつやの明るさと、内のふちの暗さ。
@export_range(0.0, 1.0, 0.01) var gloss_strength := 0.3:
	set(next):
		gloss_strength = next
		_push()
@export_range(0.0, 1.0, 0.01) var inner_shade := 0.2:
	set(next):
		inner_shade = next
		_push()

@export_group("目印の線")
## 目印の線の場所（弧の始まり0〜終わり1。負なら描かない）、色、太さ、弧からのはみ出し。
@export_range(-1.0, 1.0, 0.001) var marker_at := -1.0:
	set(next):
		marker_at = next
		_push()
@export var marker_color := Color.WHITE:
	set(next):
		marker_color = next
		_push()
@export var marker_width := 4.0:
	set(next):
		marker_width = next
		_push()
@export var marker_overhang := 4.0:
	set(next):
		marker_overhang = next
		_push()

var _gradient_texture := GradientTexture1D.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_push):
		resized.connect(_push)
	_push()


## 欄の値を、描く側（シェーダー）へ渡す。
func _push() -> void:
	if not is_inside_tree():
		return
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader != ArcShader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = ArcShader
		material = shader_material
	_gradient_texture.gradient = gradient
	_gradient_texture.width = 256
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("center", center)
	shader_material.set_shader_parameter("radius", radius)
	shader_material.set_shader_parameter("thickness", thickness)
	shader_material.set_shader_parameter("start_deg", start_deg)
	shader_material.set_shader_parameter("end_deg", end_deg)
	shader_material.set_shader_parameter("fill", value)
	shader_material.set_shader_parameter("gradient", _gradient_texture)
	shader_material.set_shader_parameter("track_color", track_color)
	shader_material.set_shader_parameter("track_edge_color", track_edge_color)
	shader_material.set_shader_parameter("glow_width", glow_width)
	shader_material.set_shader_parameter("glow_strength", glow_strength)
	shader_material.set_shader_parameter("gloss_strength", gloss_strength)
	shader_material.set_shader_parameter("inner_shade", inner_shade)
	shader_material.set_shader_parameter("marker_at", marker_at)
	shader_material.set_shader_parameter("marker_color", marker_color)
	shader_material.set_shader_parameter("marker_width", marker_width)
	shader_material.set_shader_parameter("marker_overhang", marker_overhang)
	shader_material.set_shader_parameter("cap_radius", cap_radius)
	shader_material.set_shader_parameter("round_start", round_start)
	shader_material.set_shader_parameter("round_end", round_end)
