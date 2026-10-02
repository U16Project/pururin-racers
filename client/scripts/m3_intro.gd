extends Control
## M3: オフライン導入から控室またはローカル簡易レースへ進む入口。

const ROOM_SCENE_PATH := "res://scenes/m2_run.tscn"
const RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const M5_SCENE_PATH := "res://scenes/m5_online_race.tscn"
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const INTRO_ITEMS := [
	"←→／左スティック：走る位置　↑↓／十字キー：ローカルは出力、オンラインは目標スピード",
	"Y/C：カメラ切替　Start/Esc：メニュー（レース中）",
	"A：決定　B：キャンセル　X：ブースト（実装予定）",
	"レース開始＝ローカル　オンラインレース＝M5　控室＝接続",
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
@onready var _distance_option: OptionButton = %DistanceOption
@onready var _pururin_option: OptionButton = %PururinOption
@onready var _stamina_load_option: OptionButton = %StaminaLoadOption
@onready var _pururin_preview: Label = %PururinPreview
@onready var _m5_button: Button = %M5Button


func _ready() -> void:
	print("ぷるりんレーサーズ — M3 導入を表示します")
	_race_button.pressed.connect(_on_race_pressed)
	_distance_option.item_selected.connect(_on_distance_selected)
	_pururin_option.item_selected.connect(_on_pururin_selected)
	_stamina_load_option.item_selected.connect(_on_stamina_load_selected)
	_m5_button.pressed.connect(_on_m5_pressed)
	_proceed_button.pressed.connect(_on_proceed_pressed)
	for distance_m in RaceSession.supported_distances_m():
		_distance_option.add_item("%dm" % int(distance_m))
	_distance_option.select(_distance_index(RaceSession.selected_distance_m()))
	for pururin: Variant in PururinRosterConfig.values().get("roster", []):
		if pururin is Dictionary:
			_pururin_option.add_item(str(pururin.get("display_name", "")))
	_pururin_option.select(_pururin_index(RaceSession.selected_player_pururin_id()))
	for preset: Dictionary in RaceSession.stamina_load_presets():
		_stamina_load_option.add_item("%s　燃料消費 ×%.2f" % [preset.label, preset.multiplier])
	_stamina_load_option.select(RaceSession.selected_stamina_load_preset_index())
	_refresh_pururin_preview()
	_distance_option.grab_focus()
	_refresh_guide_label()


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_accept") or RaceControllerInput.is_button_pressed(event, JOY_BUTTON_A)) and get_viewport().gui_get_focus_owner() == _race_button:
		go_to_local_race()


func get_intro_items() -> PackedStringArray:
	return PackedStringArray(INTRO_ITEMS)


func get_connection_status(stage: ConnectionStage) -> String:
	return CONNECTION_STATUS.get(stage, "")


func next_scene_path() -> String:
	return ROOM_SCENE_PATH


func race_scene_path() -> String:
	return RACE_SCENE_PATH


func go_to_m2() -> void:
	get_tree().change_scene_to_file(next_scene_path())


func go_to_local_race() -> void:
	get_tree().change_scene_to_file(race_scene_path())


func _on_proceed_pressed() -> void:
	go_to_m2()


func _on_race_pressed() -> void:
	go_to_local_race()


func _on_distance_selected(index: int) -> void:
	var distances := RaceSession.supported_distances_m()
	if index >= 0 and index < distances.size():
		RaceSession.select_distance(float(distances[index]))


func _on_pururin_selected(index: int) -> void:
	var roster: Array = PururinRosterConfig.values().get("roster", [])
	if index >= 0 and index < roster.size() and roster[index] is Dictionary:
		RaceSession.select_player_pururin(str(roster[index].get("id", "")))
		_refresh_pururin_preview()


func _on_stamina_load_selected(index: int) -> void:
	var presets := RaceSession.stamina_load_presets()
	if index >= 0 and index < presets.size():
		RaceSession.select_stamina_load_preset(str(presets[index].id))


func _distance_index(distance_m: float) -> int:
	var distances := RaceSession.supported_distances_m()
	for index in distances.size():
		if is_equal_approx(float(distances[index]), distance_m):
			return index
	return 2


func _pururin_index(identifier: String) -> int:
	var roster: Array = PururinRosterConfig.values().get("roster", [])
	for index in roster.size():
		if roster[index] is Dictionary and str(roster[index].get("id", "")) == identifier:
			return index
	return 0


func selected_pururin_preview() -> Dictionary:
	var pururin := PururinRosterConfig.pururin_by_id(RaceSession.selected_player_pururin_id())
	if pururin.is_empty():
		return {}
	var definitions := PururinStatsConfig.values()
	var attribute_id := str(pururin.get("attribute", ""))
	var style_id := str(pururin.get("running_style", ""))
	return {
		"id": str(pururin.get("id", "")),
		"display_name": str(pururin.get("display_name", "")),
		"attribute": str(definitions.get("attributes", {}).get(attribute_id, {}).get("label", attribute_id)),
		"running_style": str(definitions.get("running_styles", {}).get(style_id, {}).get("label", style_id)),
		"pre_race_stats": PururinStatsMath.pre_race_stats(attribute_id, pururin.get("allocation", {})),
	}


func _refresh_pururin_preview() -> void:
	var preview := selected_pururin_preview()
	if preview.is_empty():
		_pururin_preview.text = "個体情報を読み込めませんでした"
		return
	var stats: Dictionary = preview["pre_race_stats"]
	_pururin_preview.text = "\n".join(PackedStringArray([
		"%s　属性：%s　脚質：%s" % [preview["display_name"], preview["attribute"], preview["running_style"]],
		"出走前（属性補正後）　最高速 %d　加速力 %d　スタミナ %d　心肺 %d" % [
			int(stats["top_speed"]), int(stats["acceleration"]), int(stats["stamina"]), int(stats["cardio"]),
		],
		"空力 %d　集団 %d　接触耐性 %d　操作性 %d" % [
			int(stats["aero"]), int(stats["pack"]), int(stats["contact_resistance"]), int(stats["handling"]),
		],
		"順位・区間の補正はレース中に変動します",
	]))


func _on_m5_pressed() -> void:
	get_tree().change_scene_to_file(M5_SCENE_PATH)


func _refresh_guide_label() -> void:
	var guide := get_node_or_null("Content/Guide") as Label
	if guide:
		guide.text = "\n".join(INTRO_ITEMS)
