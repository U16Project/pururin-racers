extends Control
## ぷるりんの絵。3Dの体を写したものを出す。
## 小さい絵（スロット・一覧の窓）は、個体ごとに1回だけ写した、止まった絵。
## live を true にした絵（右側の詳細）は、体をゆっくり回して、背中がこちらを向くたびに表情を替える。

const PortraitCache := preload("res://scripts/presentation/pururin_portrait_cache.gd")
const Stage := preload("res://scripts/presentation/pururin_portrait_stage.gd")
const PururinBodyBuilder := preload("res://scripts/presentation/pururin_body_builder.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
## 回る絵の一辺（ピクセル）と、縦に写る範囲（m）。回っても、左右の飾りが切れない広さ。
const LIVE_SIZE_PX := 512
const LIVE_VIEW_HEIGHT_M := 2.5
## 回る絵で、体の一部にさせるアクション。
const SHOWCASE_ACTION := "idle"
## 個体を出したときに、1回だけ出す動き。
const SHOWCASE_ONE_SHOT := "pick"

## 体を回して、表情を替えるか。set_pururin より前に決める。
var live := false

var _pururin: Dictionary = {}
var _viewport: SubViewport
var _body: Node3D
var _angle := 0.0
var _expression_index := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 表示する個体。空なら、何も描かない。
func set_pururin(pururin: Dictionary) -> void:
	_pururin = pururin
	if live:
		_show_live_body()
	queue_redraw()


## 回る絵の体を、今の個体のものに取り替える。正面・最初の表情から始める。
func _show_live_body() -> void:
	if _viewport == null:
		_viewport = Stage.make(LIVE_SIZE_PX, LIVE_VIEW_HEIGHT_M)
		add_child(_viewport)
	if _body != null:
		_body.queue_free()
		_body = null
	_angle = 0.0
	_expression_index = 0
	var table := Stage.turntable(_viewport)
	table.rotation.y = 0.0
	if _pururin.is_empty():
		return
	_body = PururinBodyBuilder.build(PururinLookConfig.look_for(str(_pururin["id"])), PururinLookConfig.values())
	table.add_child(_body)
	_body.call("set_expression", showcase_expressions()[0])
	# ヒレや突起は、待っているときの動き。
	_body.call("set_action", SHOWCASE_ACTION)
	# 出てきたときに、1回ぽよんと跳ねる。
	_body.call("play_once", SHOWCASE_ONE_SHOT)


func _process(delta: float) -> void:
	if not live or _viewport == null:
		return
	# 見えているときだけ、写して回す。
	var showing := _body != null and is_visible_in_tree()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if showing:
		advance(delta)


## 体を回す。背中がこちらを向いた所（半回転）で、次の表情に替える。
func advance(delta: float) -> void:
	var before := _angle
	_angle = fmod(_angle + TAU * delta / float(PururinLookConfig.showcase()["turn_seconds"]), TAU)
	Stage.turntable(_viewport).rotation.y = _angle
	if before < PI and _angle >= PI:
		var expressions := showcase_expressions()
		_expression_index = (_expression_index + 1) % expressions.size()
		_body.call("set_expression", expressions[_expression_index])


## 回る絵で、順に出す表情の名前。
func showcase_expressions() -> Array:
	return PururinLookConfig.showcase()["expressions"]


## 回る絵の、今の向き（ラジアン。0が正面）と、出している表情。
func turn_angle() -> float:
	return _angle


func shown_expression() -> String:
	return "" if _body == null else str(_body.call("expression"))


func _draw() -> void:
	if _pururin.is_empty():
		return
	var texture: Texture2D = _viewport.get_texture() if live else PortraitCache.texture_for(str(_pururin["id"]), get_tree())
	var side := minf(size.x, size.y)
	draw_texture_rect(texture, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
