extends RefCounted
## レースの画面を、パドックにいる間に裏で読み込んでおく（切り替えたときに、読み込みで画面が止まらないように）。
## パドックに入ったら start、レースへ進むときに go で切り替える。読み込みが終わっていなければ、go が待つ。

const SCENE_PATH := "res://scenes/local_race.tscn"
## 会場のパドックから始めるときの種類（レースの画面が、開くときに1回だけ受け取る）。
## 空＝ふつう（すぐスタート前の見せ方）。PADDOCK_OFFLINE＝オフラインのパドック、PADDOCK_FREE_WAIT＝フリー対戦で出走者を待つ、
## PADDOCK_FRIEND＝ともだち対戦のパドック。
const PADDOCK_OFFLINE := "offline"
const PADDOCK_FREE_WAIT := "free_wait"
const PADDOCK_FRIEND := "friend"
static var _paddock_mode := ""


## 裏での読み込みを始める（もう始めていれば、何もしない）。
static func start() -> void:
	if ResourceLoader.load_threaded_get_status(SCENE_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(SCENE_PATH)


## 裏で読み込みを始めているか（終わっているときも含む）。
static func is_started() -> bool:
	return ResourceLoader.load_threaded_get_status(SCENE_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE


## レースの画面へ切り替える。裏で読み込んでいれば、それを使う（まだ途中なら、終わるまで待つ）。
## paddock_mode を渡すと、会場のパドックから始める。
static func go(tree: SceneTree, paddock_mode: String = "") -> void:
	_paddock_mode = paddock_mode
	var scene: PackedScene = null
	if is_started():
		scene = ResourceLoader.load_threaded_get(SCENE_PATH) as PackedScene
	if scene == null:
		scene = load(SCENE_PATH) as PackedScene
	tree.change_scene_to_packed(scene)


## レースの画面が開くときに、パドックの種類を受け取る（受け取ったら空に戻す）。
static func take_paddock_mode() -> String:
	var mode := _paddock_mode
	_paddock_mode = ""
	return mode
