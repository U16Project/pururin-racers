extends Path3D
## 競馬場形の Curve3D を Path にセットし、帯幅をコース幅に合わせる（起動時に course_builder.gd が本来の寸法で作り直す）。


const TrackCurveBuilder := preload("res://scripts/track_curve_builder.gd")
const TrackMath := preload("res://scripts/track_math.gd")

@export var straight_len: float = 28.0
@export var turn_radius: float = 18.0
@export var bake_interval: float = 0.25
@export var ribbon_path: NodePath = ^"TrackRibbon"


func _enter_tree() -> void:
	# 子 CSGPolygon の _ready より先に curve が必要（ノード入場順）。
	curve = TrackCurveBuilder.make_racecourse_curve(
		straight_len, turn_radius, 20, bake_interval
	)


func _ready() -> void:
	var ribbon := get_node_or_null(ribbon_path) as CSGPolygon3D
	if ribbon:
		var h := TrackMath.HALF_WIDTH_M
		ribbon.polygon = PackedVector2Array([
			Vector2(-h, 0.0),
			Vector2(h, 0.0),
			Vector2(h, 0.12),
			Vector2(-h, 0.12),
		])


func get_straight_len() -> float:
	return straight_len


func get_turn_radius() -> float:
	return turn_radius
