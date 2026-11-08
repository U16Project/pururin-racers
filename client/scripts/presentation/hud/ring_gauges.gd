@tool
extends Control
## 共通の輪。位置は親で、中心・半径・太さはこの欄で決める。
@export var center := Vector2(200, 200):
	set(next):
		center = next
		_fit()
@export var radius := 162.0:
	set(next):
		radius = next
		_fit()
@export var thickness := 30.8:
	set(next):
		thickness = next
		_fit()

func _ready() -> void:
	_fit()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_fit()

func _fit() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.get("follow_ring") != true:
			continue
		var point: Vector2 = child.get_transform().affine_inverse() * center
		if child.get("center") != point:
			child.set("center", point)
		if child.get("radius") != radius:
			child.set("radius", radius)
		if child.get("thickness") != thickness:
			child.set("thickness", thickness)
