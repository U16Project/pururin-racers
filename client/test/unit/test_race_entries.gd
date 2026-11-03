extends GutTest
const Session := preload("res://scripts/race_session.gd")
const EntriesScene := preload("res://scenes/race_entries.tscn")
const Select := preload("res://scripts/race_select.gd")
const RaceScenePreload := preload("res://scripts/race_scene_preload.gd")
class WithoutNavigation extends "res://scripts/race_entries.gd":
	var paths: Array[String] = []
	func _navigate(path: String) -> void:
		paths.append(path)

func before_each() -> void:
	Session.clear_slots()
	Session.set_slot(0, "player-1")
	Session.set_slot(4, "cpu-1")
	Session.set_slot_trainer(4, "kaede")

func after_each() -> void:
	Session.clear_slots()

func test_entries_preserve_gate_and_show_selected_trainer_and_player() -> void:
	var before := Session.slots_snapshot()
	var screen: Control = EntriesScene.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen.get("_rows").size(), 2)
	assert_eq(screen.get("_entries")[1]["gate"], 4)
	assert_eq(screen.get("_favorite").text, "プレイヤー操作")
	screen.get("_rows")[1].grab_focus()
	assert_eq(screen.get("shown_gate"), 4)
	assert_eq(screen.get("_trainer_name").text, "カエデ")
	assert_eq(screen.get("_detail").call("shown_pururin_id"), "cpu-1")
	assert_eq(Session.slots_snapshot(), before)
	assert_eq(Select.RACE_SCENE_PATH, "res://scenes/race_entries.tscn")
	# パドックにいる間に、レースの画面を裏で読み込み始めている。
	assert_true(RaceScenePreload.is_started())
	assert_eq(screen.get_node("TopBar/Title").text, "パドック　%d m" % int(Session.selected_distance_m()))
	# オフラインでは、誰が動かすかの札は出さない。
	assert_null(screen.get("_rows")[1].find_child("Text", true, false))

func test_start_and_back_are_guarded_and_never_change_selection() -> void:
	var screen := WithoutNavigation.new()
	add_child_autofree(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var before := Session.slots_snapshot()
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	screen._unhandled_input(event)
	screen._unhandled_input(event)
	assert_eq(screen.paths, ["res://scenes/local_race.tscn"])
	assert_eq(Session.slots_snapshot(), before)
	var returning := WithoutNavigation.new()
	add_child_autofree(returning)
	returning.back()
	returning.back()
	assert_eq(returning.paths, ["res://scenes/race_select.tscn"])
	Session.clear_slots()
	var invalid := WithoutNavigation.new()
	add_child_autofree(invalid)
	invalid.start()
	assert_true(invalid.paths.is_empty())

func test_the_preloaded_race_scene_is_the_one_used() -> void:
	RaceScenePreload.start()
	var scene: PackedScene = ResourceLoader.load_threaded_get(RaceScenePreload.SCENE_PATH)
	assert_not_null(scene)
	assert_eq(scene.resource_path, RaceScenePreload.SCENE_PATH)
	# 受け取ったあとは、もう一度始められる（次のレースのパドックで、また裏で読む）。
	assert_false(RaceScenePreload.is_started())
	RaceScenePreload.start()
	assert_true(RaceScenePreload.is_started())
	ResourceLoader.load_threaded_get(RaceScenePreload.SCENE_PATH)

func test_full_field_fits_viewport_with_readable_details() -> void:
	Session.select_full_field("player-1")
	var screen: Control = EntriesScene.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = screen.find_child("Panel", true, false)
	assert_true(screen.get_viewport_rect().encloses(panel.get_global_rect()))
	for row: Button in screen.get("_rows"):
		row.grab_focus()
		assert_true(panel.get_global_rect().encloses(row.get_global_rect()))
	assert_eq(screen.get("_rows").size(), 8)
	assert_lte((screen.get("_start") as Control).get_global_rect().end.y, screen.get_viewport_rect().size.y - 16)
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-race-entries-full.png"))

func test_hovering_shows_that_row_and_leaving_returns_to_the_cursor_row() -> void:
	var screen: Control = EntriesScene.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Array = screen.get("_rows")
	rows[0].grab_focus()
	assert_eq(screen.get("shown_gate"), 0)
	rows[1].mouse_entered.emit()
	assert_eq(screen.get("shown_gate"), 4, "マウスを乗せた行を見せる")
	rows[1].mouse_exited.emit()
	assert_eq(screen.get("shown_gate"), 0, "離れたら、カーソルが合っている行に戻る")
	assert_eq(screen.get("_detail").call("shown_pururin_id"), "player-1")


func test_online_paddock_overlay_only_shows_and_marks_only_me() -> void:
	var entries := [
		{"gate": 0, "id": "player-1", "player": true, "peer_id": 5, "trainer_id": "kaede", "trainer_name": "ほかの人"},
		{"gate": 1, "id": "cpu-1", "player": false, "peer_id": 0, "trainer_id": "kaede", "trainer_name": "カエデ"},
		{"gate": 2, "id": "cpu-2", "player": true, "peer_id": 9, "trainer_id": "kaede", "trainer_name": "自分"},
	]
	Session.set_online_entries(entries)
	Session.set_online_view(9)
	var screen: Control = EntriesScene.instantiate()
	screen.set("overlay_mode", true)
	screen.set("read_only", true)
	add_child_autofree(screen)
	await get_tree().process_frame
	# 「自分」は、自分の番号の人だけ。はじめのカーソルも、自分の行。
	var rows: Array = screen.get("_rows")
	assert_eq(screen.get("shown_gate"), 2)
	assert_true(rows[2].has_focus())
	# ほかの人の行を見ると、トレーナーの所は、その人の名前。CPUは、出走に書いてあるトレーナー。
	rows[0].grab_focus()
	assert_eq(screen.get("_trainer_name").text, "ほかの人")
	rows[1].grab_focus()
	assert_eq(screen.get("_trainer_name").text, "カエデ")
	# オンラインでは、人の行に「プレイヤー」、CPUの行に「CPU」の札（行にも、右の欄にも）。
	var Hud := preload("res://scripts/presentation/race_hud.gd")
	var tag_text := func(node: Node) -> String: return (node.find_child("Text", true, false) as Label).text
	assert_eq(tag_text.call(rows[0]), Hud.CONTROL_TAGS[Hud.KIND_PLAYER][0])
	assert_eq(tag_text.call(rows[1]), Hud.CONTROL_TAGS[Hud.KIND_CPU][0])
	assert_eq(tag_text.call(rows[2]), Hud.CONTROL_TAGS[Hud.KIND_PLAYER][0])
	assert_eq(tag_text.call(screen.get("_kind_tag")), Hud.CONTROL_TAGS[Hud.KIND_CPU][0])
	# レース開始・戻るは出さない（進めるのはサーバー）。START・B でも進まない。
	assert_false((screen.find_child("StartButton", true, false) as Control).is_visible_in_tree())
	assert_not_null(screen.find_child("SoonLabel", true, false))
	watch_signals(screen)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	screen._unhandled_input(start)
	assert_signal_not_emitted(screen, "start_requested")
	Session.set_online_entries([])
	Session.set_online_view(0)
