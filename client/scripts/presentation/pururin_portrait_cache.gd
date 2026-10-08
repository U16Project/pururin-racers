extends RefCounted
## 個体ごとの、止まった絵（レース選択画面のスロットや、一覧の窓に出す小さい絵）。
## 3Dの体を、個体ごとに1回だけ写して、使い回す。

const Stage := preload("res://scripts/presentation/pururin_portrait_stage.gd")
const PururinBodyBuilder := preload("res://scripts/presentation/pururin_body_builder.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
## 絵の一辺（ピクセル）。小さく出しても、ぼやけない大きさ。
const SIZE_PX := 256
## 絵の縦に写る範囲（m）。顔が大きく入るように、左右の飾りの先は少し切れる。
const VIEW_HEIGHT_M := 2.1
## 体を、正面から少し横へ向ける角度（度）。
const BODY_YAW_DEG := 18.0
const HOLDER_NAME := "PururinPortraitCache"
## 絵を写し続けるフレーム数。
const SETTLE_FRAMES := 30

## 個体のID → その絵を写した舞台。
static var _viewports := {}
static var _holder: Node


## 個体の絵。最初に呼ばれたときに、体を組み立てて1回だけ写す。
static func texture_for(pururin_id: String, tree: SceneTree) -> Texture2D:
	if _holder == null or not is_instance_valid(_holder):
		_viewports.clear()
		_holder = Node.new()
		_holder.name = HOLDER_NAME
		# 場面を切り替えても消えないように、一番上に付ける。
		tree.root.add_child.call_deferred(_holder)
	if not _viewports.has(pururin_id):
		var viewport := Stage.make(SIZE_PX, VIEW_HEIGHT_M)
		viewport.name = pururin_id
		var body := PururinBodyBuilder.build(PururinLookConfig.look_for(pururin_id), PururinLookConfig.values())
		var table := Stage.turntable(viewport)
		table.rotation.y = deg_to_rad(BODY_YAW_DEG)
		table.add_child(body)
		_holder.add_child(viewport)
		_viewports[pururin_id] = viewport
		_take_picture(viewport, tree)
	return (_viewports[pururin_id] as SubViewport).get_texture()


## 絵を写す。最初の数フレームは、体の描き方の準備が終わっていないことがあるので、
## 少しのあいだ写し続けてから、止める。
static func _take_picture(viewport: SubViewport, tree: SceneTree) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _frame in SETTLE_FRAMES:
		await tree.process_frame
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
