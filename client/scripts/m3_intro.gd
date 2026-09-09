extends Control
## M3: オフライン導入から控室またはローカル簡易レースへ進む入口。

const ROOM_SCENE_PATH := "res://scenes/m2_run.tscn"
const RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const M4_SCENE_PATH := "res://scenes/m4_group_race.tscn"
const INTRO_ITEMS := [
	"←→：走る位置　↑↓：目標スピード",
	"C：カメラ切替　Esc：メニュー（レース中）",
	"レース開始＝ローカル　集団プロトタイプ＝M4　控室へ進む＝接続",
]

enum ConnectionStage {
	CONNECTING,
	CONNECTED,
	FAILED,
}

const CONNECTION_STATUS := {
	ConnectionStage.CONNECTING: "接続しています…",
	ConnectionStage.CONNECTED: "接続できました",
	ConnectionStage.FAILED: "接続できませんでした。サーバーを起動してください",
}

@onready var _proceed_button: Button = %ProceedButton
@onready var _race_button: Button = %RaceButton
@onready var _m4_button: Button = %M4Button


func _ready() -> void:
	print("ぷるりんレーサーズ — M3 導入を表示します")
	_race_button.pressed.connect(_on_race_pressed)
	_m4_button.pressed.connect(_on_m4_pressed)
	_proceed_button.pressed.connect(_on_proceed_pressed)
	_race_button.grab_focus()
	_refresh_guide_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		go_to_local_race()


func get_intro_items() -> PackedStringArray:
	return PackedStringArray(INTRO_ITEMS)


func get_connection_status(stage: ConnectionStage) -> String:
	return CONNECTION_STATUS.get(stage, "")


func next_scene_path() -> String:
	return ROOM_SCENE_PATH


func race_scene_path() -> String:
	return RACE_SCENE_PATH


func m4_scene_path() -> String:
	return M4_SCENE_PATH


func go_to_m2() -> void:
	get_tree().change_scene_to_file(next_scene_path())


func go_to_local_race() -> void:
	get_tree().change_scene_to_file(race_scene_path())


func _on_proceed_pressed() -> void:
	go_to_m2()


func _on_race_pressed() -> void:
	go_to_local_race()


func _on_m4_pressed() -> void:
	get_tree().change_scene_to_file(m4_scene_path())


func _refresh_guide_label() -> void:
	var guide := get_node_or_null("Content/Guide") as Label
	if guide:
		guide.text = "\n".join(INTRO_ITEMS)
