extends Control
## M3: オフライン導入から M2 控室へ進む入口。

const NEXT_SCENE_PATH := "res://scenes/m2_run.tscn"
const INTRO_ITEMS := [
	"←→：ぷるりんの走る位置を調整",
	"C：カメラを切り替え",
	"控室：サーバーに接続して入室",
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


func _ready() -> void:
	print("ぷるりんレーサーズ — M3 導入を表示します")
	_proceed_button.pressed.connect(_on_proceed_pressed)
	_proceed_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		go_to_m2()


func get_intro_items() -> PackedStringArray:
	return PackedStringArray(INTRO_ITEMS)


func get_connection_status(stage: ConnectionStage) -> String:
	return CONNECTION_STATUS.get(stage, "")


func next_scene_path() -> String:
	return NEXT_SCENE_PATH


func go_to_m2() -> void:
	get_tree().change_scene_to_file(next_scene_path())


func _on_proceed_pressed() -> void:
	go_to_m2()
