@tool
extends Control
## 速さ・体力の弧のゲージを、まとめて置くまとまり。
## 中の弧（ArcGauge）は、どれも同じ円の上に乗る：ハート（heart_path）をちょうど囲む、いちばん小さい円の外側に、
## すき間（gap）を空けて、太さ（thickness）で。ハートの形や大きさを変えると、弧もついてくる。
## まとまりの回転・拡大の軸は、その円のまん中。このまとまりの四角は、その円が収まる大きさに自動で合わせる。弧ごとに変えるのは、始まりと終わりの角度・色などだけ。

## 囲むハート（HeartGauge）。
@export var heart_path: NodePath:
	set(next):
		heart_path = next
		_fit()
## ハートのふちと、弧の内側のふちとの、すき間（ピクセル）。
@export var gap := 10.0:
	set(next):
		gap = next
		_fit()
## 弧の太さ（ピクセル）。中の弧で共通。
@export var thickness := 28.0:
	set(next):
		thickness = next
		_fit()

## このまとまりの四角の、弧のまわりの余白（光のぶん）。
const MARGIN := 24.0
## ハートを、この数の点で調べて、囲む円を求める。
const HEART_SAMPLES := 400

var _fitted_key: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()


func _process(_delta: float) -> void:
	# エディタの中で、ハートの形を変えたときに、ついていく。
	if Engine.is_editor_hint():
		_fit()


## ハートのふちの点（このまとまりの座標）。
static func heart_outline(heart_center: Vector2, size_x: float, size_y: float, dip: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in HEART_SAMPLES + 1:
		var x := lerpf(-1.0, 1.0, float(index) / float(HEART_SAMPLES))
		var root := sqrt(maxf(1.0 - x * x, 0.0))
		for sign: float in [1.0, -1.0]:
			var y := (sign * root + sqrt(absf(x))) / dip
			points.append(heart_center + Vector2(x * size_x, -y * size_y))
	return points


## 点の集まりを囲む、いちばん小さい円（左右が対称なので、まん中は縦の線の上で探す）。[まん中, 半径] を返す。
static func enclosing_circle(points: PackedVector2Array, axis_x: float) -> Array:
	var top := INF
	var bottom := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var low := top
	var high := bottom
	for _step in 60:
		var a := lerpf(low, high, 1.0 / 3.0)
		var b := lerpf(low, high, 2.0 / 3.0)
		if _farthest(points, Vector2(axis_x, a)) < _farthest(points, Vector2(axis_x, b)):
			high = b
		else:
			low = a
	var center := Vector2(axis_x, (low + high) * 0.5)
	return [center, _farthest(points, center)]


static func _farthest(points: PackedVector2Array, center: Vector2) -> float:
	var far := 0.0
	for point in points:
		far = maxf(far, point.distance_to(center))
	return far


## 中の弧を、ハートを囲む円の上に置き直す。
func _fit() -> void:
	if not is_inside_tree():
		return
	var heart := get_node_or_null(heart_path)
	if heart == null:
		return
	var heart_center: Vector2 = heart.get("center")
	# ハートとこのまとまりの、置き場所のずれ（どちらも同じ親の中）。
	var offset := (heart as Control).position - position if heart is Control else Vector2.ZERO
	var key := [heart_center, heart.get("size_x"), heart.get("size_y"), heart.get("dip"), heart.get("edge_width"), offset, gap, thickness]
	if key == _fitted_key:
		return
	_fitted_key = key
	var circle := enclosing_circle(heart_outline(heart_center + offset, float(heart.get("size_x")), float(heart.get("size_y")), float(heart.get("dip"))), heart_center.x + offset.x)
	var center: Vector2 = circle[0]
	# ハートのふちの線の太さの半分も、ハートに含める。
	var radius := float(circle[1]) + float(heart.get("edge_width")) * 0.5 + gap + thickness * 0.5
	# このまとまりの四角を、弧の円が収まる大きさに合わせる（エディタで、つまみやすいように）。回したり縮めたりしているときは、合わせない。
	if rotation == 0.0 and scale == Vector2.ONE:
		var reach := radius + thickness * 0.5 + MARGIN
		var box := Rect2(center - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
		if box.position.distance_to(Vector2.ZERO) >= 0.5 or box.size.distance_to(size) >= 0.5:
			position += box.position
			for child in get_children():
				if child is Control:
					(child as Control).position -= box.position
			center -= box.position
			size = box.size
			_fitted_key = [heart_center, heart.get("size_x"), heart.get("size_y"), heart.get("dip"), heart.get("edge_width"), (heart as Control).position - position if heart is Control else Vector2.ZERO, gap, thickness]
	pivot_offset = center
	for child in get_children():
		if child.get("start_deg") == null:
			continue
		# 弧のまん中は、その弧の四角の左上から。
		child.set("center", center - (child as Control).position)
		child.set("radius", radius)
		child.set("thickness", thickness)
