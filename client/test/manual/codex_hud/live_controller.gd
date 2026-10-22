extends "res://scripts/local_race_controller.gd"
## 試作専用の派生クラス。実レースをそのまま動かし、表示部品だけ差し替える。
## 元シーン・元コントローラー・計算用JSONは編集しない。

const CodexDashboard := preload("res://test/manual/codex_hud/dashboard.gd")
var _comparison_hud: Control
var _codex_dashboard: Control
var _codex_shown := true
var _saved_slots: Dictionary
var _saved_distance := 0.0
var _sketch_overlay: TextureRect


func _ready() -> void:
	get_window().title = "ぷるりんレーサーズ — Codex操作盤 / F4で比較"
	get_window().size = Vector2i(1280, 720)
	_saved_slots = RaceSession.slots_snapshot()
	_saved_distance = RaceSession.selected_distance_m()
	# 下書きのアカネを操作役として、現在の個体設定から8プルを組む。
	RaceSession.select_full_field("cpu-1")
	RaceSession.select_distance(2400)
	super._ready()
	_comparison_hud = _heart_hud
	_comparison_hud.hide()
	_codex_dashboard = CodexDashboard.new()
	_heart_hud_viewport.add_child(_codex_dashboard)
	_heart_hud = _codex_dashboard
	_place_heart_hud()
	_sketch_overlay = TextureRect.new()
	var sketch_path := ProjectSettings.globalize_path("res://../docs/reference/ui/codex_hud_20261019/source_sketch.png")
	_sketch_overlay.texture = ImageTexture.create_from_image(Image.load_from_file(sketch_path))
	_sketch_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sketch_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_sketch_overlay.modulate.a = 0.32
	_sketch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sketch_overlay.visible = false
	_heart_hud_viewport.add_child(_sketch_overlay)
	_place_heart_hud()
	var hint := Label.new()
	hint.text = "Codex操作盤  /  F4：比較  /  F5：下書き重ね"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 3)
	hint.position = Vector2(12, get_viewport().get_visible_rect().size.y - 22)
	$UI.add_child(hint)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-live="):
			_capture_live.call_deferred(argument.trim_prefix("--capture-live="))


func _place_heart_hud() -> void:
	if _heart_hud == null:
		return
	var zoom := maxf(get_viewport().get_stretch_transform().get_scale().x, 1)
	var draw_zoom := zoom * 2 if _codex_shown and _codex_dashboard != null else zoom
	var factor := 0.64 if _codex_shown and _codex_dashboard != null else HEART_HUD_SCALE
	_heart_hud.call("set_scale_factor", factor * draw_zoom)
	var drawn := _heart_hud.custom_minimum_size.ceil()
	_heart_hud_viewport.size = Vector2i(drawn)
	_heart_hud.size = drawn
	_heart_hud.position = Vector2.ZERO
	_heart_hud_view.size = drawn / draw_zoom
	_heart_hud_view.position = Vector2(6, 4)
	_heart_hud_drawn_msec = -1000000
	if _sketch_overlay != null:
		_sketch_overlay.size = drawn
	if _race_hud_viewport != null:
		var screen := get_viewport().get_visible_rect().size
		_race_hud_viewport.size = Vector2i((screen * zoom).ceil())
		_race_hud_viewport.size_2d_override = Vector2i(screen.ceil())
		_race_hud_view.size = screen


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		_codex_shown = not _codex_shown
		_codex_dashboard.visible = _codex_shown
		_comparison_hud.visible = not _codex_shown
		_sketch_overlay.visible = false
		_heart_hud = _codex_dashboard if _codex_shown else _comparison_hud
		_place_heart_hud()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		_sketch_overlay.visible = not _sketch_overlay.visible
		_heart_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_viewport().set_input_as_handled()


func _capture_live(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	# スタート前の準備を待つ。時間切れ時は成功扱いにしない。
	var deadline := Time.get_ticks_msec() + 30000
	while not _race_started and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _race_started:
		push_error("実レースが開始しませんでした")
		get_tree().quit(1)
		return
	while _race_elapsed < 8.0:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var state: Dictionary = _codex_dashboard.get("_state")
	if state.is_empty() or not state.has("speed_kmh") or not state.has("standings"):
		push_error("実レースのHUDデータが届きません")
		get_tree().quit(1)
		return
	var speed := float(_player.call("get_actual_speed"))
	if absf(float(state.speed_kmh) - speed) > 5.0:
		push_error("実速度と表示速度が一致しません")
		get_tree().quit(1)
		return
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join("live_race.png"))
	_heart_hud_viewport.get_texture().get_image().save_png(directory.path_join("live_dashboard.png"))
	# F5の実際のハンドラーで下書きを重ね、配置確認用の画像を保存。
	var reference_event := InputEventKey.new()
	reference_event.physical_keycode = KEY_F5
	reference_event.pressed = true
	_input(reference_event)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("sketch_overlay.png"))
	_input(reference_event)
	var compare_event := InputEventKey.new()
	compare_event.physical_keycode = KEY_F4
	compare_event.pressed = true
	_input(compare_event)
	if _heart_hud != _comparison_hud or _codex_dashboard.visible:
		push_error("F4の比較切り替えに失敗しました")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("comparison_race.png"))
	_input(compare_event)
	var log := FileAccess.open(directory.path_join("live_state.json"), FileAccess.WRITE)
	if log != null:
		log.store_string(JSON.stringify({"player_name": state.player_name, "speed_kmh": state.speed_kmh, "heart_bpm": state.heart_bpm, "fuel_ratio": state.fuel_ratio, "notch": state.notch, "boost_uses_left": state.boost_uses_left, "dash_ratio": state.dash_ratio, "field_size": state.field_size}, "  "))
	print("LIVE HUD: ", state.player_name, ", ", state.speed_kmh, " km/h, ", state.heart_bpm, " bpm, ", state.field_size, " runners")
	print("LIVE REVIEW: F4 comparison / F5 source overlay OK")
	get_tree().quit(0 if error == OK else 1)


func _exit_tree() -> void:
	super._exit_tree()
	if not _saved_slots.is_empty():
		RaceSession.restore_slots(_saved_slots)
		RaceSession.select_distance(_saved_distance)
