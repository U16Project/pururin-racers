extends RefCounted
## レースの画面を、パドックにいる間に裏で読み込んでおく（切り替えたときに、読み込みで画面が止まらないように）。
## パドックに入ったら start、レースへ進むときに go で切り替える。読み込みが終わっていなければ、go が待つ。

const SCENE_PATH := "res://scenes/local_race.tscn"


## 裏での読み込みを始める（もう始めていれば、何もしない）。
static func start() -> void:
	if ResourceLoader.load_threaded_get_status(SCENE_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(SCENE_PATH)


## 裏で読み込みを始めているか（終わっているときも含む）。
static func is_started() -> bool:
	return ResourceLoader.load_threaded_get_status(SCENE_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE


## レースの画面へ切り替える。裏で読み込んでいれば、それを使う（まだ途中なら、終わるまで待つ）。
static func go(tree: SceneTree) -> void:
	var scene: PackedScene = null
	if is_started():
		scene = ResourceLoader.load_threaded_get(SCENE_PATH) as PackedScene
	if scene == null:
		scene = load(SCENE_PATH) as PackedScene
	tree.change_scene_to_packed(scene)
