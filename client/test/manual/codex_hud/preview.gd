extends Control
## F6でこの場面だけ起動可能。試験用数値を操作し、PNGも実描画から保存できる。

const Dashboard := preload("res://test/manual/codex_hud/dashboard.gd")
const Summary := preload("res://test/manual/codex_hud/race_summary.gd")
const Legacy := preload("res://scripts/presentation/round_race_hud.gd")
const BASE_STAGE := Vector2i(1152, 648)
var _viewport: SubViewport
var _view: TextureRect
var _background: TextureRect
var _solid: ColorRect
var _dashboard: Control
var _legacy: Control
var _summary: Control
var _controls: PanelContainer
var _toolbar: HBoxContainer
var _status: Label
var _sliders: Dictionary = {}
var _state: Dictionary = {}
var _mode := 1
var _animate := false
var _time := 0.0
var _pulse := 0.0
var _send_time := 0.0
var _capturing := false
var _syncing := false
var _capture_directory := ""
var _stage_size := BASE_STAGE


func _ready() -> void:
	get_window().title = "ぷるりんレーサーズ — Codex UI 試作"
	get_window().size = Vector2i(1440, 950)
	var back := ColorRect.new()
	back.color = Color("101c2a")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_viewport = SubViewport.new()
	_set_stage_size(BASE_STAGE)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_solid = ColorRect.new()
	_solid.color = Color("253c4d")
	_viewport.add_child(_solid)
	_background = TextureRect.new()
	var path := ProjectSettings.globalize_path("res://../docs/reference/key_visuals/game_look_v01/ref_race_view_v01.png")
	if FileAccess.file_exists(path):
		_background.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_viewport.add_child(_background)
	_dashboard = Dashboard.new()
	_viewport.add_child(_dashboard)
	_summary = Summary.new()
	_viewport.add_child(_summary)
	_legacy = Legacy.new()
	_viewport.add_child(_legacy)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_build_toolbar()
	_build_controls()
	_state = _sample(0)
	_apply_sample(0)
	resized.connect(_layout)
	_layout()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_directory = arg.trim_prefix("--capture=")
	if not _capture_directory.is_empty():
		_capture.call_deferred()


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 10)
	add_child(_toolbar)
	var title := Label.new()
	title.text = "CODEX / HUD 試作"
	title.add_theme_font_size_override("font_size", 21)
	title.custom_minimum_size.x = 225
	_toolbar.add_child(title)
	for entry in [["レース配置", 0], ["操作盤を拡大", 1], ["旧操作盤と比較", 2]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(150, 40)
		button.pressed.connect(_set_mode.bind(int(entry[1])))
		_toolbar.add_child(button)
	var animate_button := CheckButton.new()
	animate_button.text = "動かす"
	animate_button.toggled.connect(func(value: bool) -> void: _animate = value)
	_toolbar.add_child(animate_button)
	_status = Label.new()
	_status.text = "表示サンプル・実レース未接続"
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color("a9bfcd")
	_toolbar.add_child(_status)


func _build_controls() -> void:
	_controls = PanelContainer.new()
	add_child(_controls)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	_controls.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var presets := GridContainer.new()
	presets.columns = 2
	rows.add_child(presets)
	for entry in [["下書きの数値", 0], ["温存", 1], ["上限・負債", 2], ["3桁・長い名前", 3], ["ゼロ・使い切り", 4]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(_apply_sample.bind(int(entry[1])))
		presets.add_child(button)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	rows.add_child(grid)
	for definition in [["速度 km/h", "speed_kmh", 0, 140], ["心拍 bpm", "heart_bpm", 100, 230], ["体力 %", "fuel_ratio", -100, 100], ["空力 %", "air_green", 0, 80], ["集団 %", "air_blue", 0, 120], ["ノッチ", "notch", 1, 6], ["Boost 残り", "boost_uses_left", 0, 3], ["Boost 効果 %", "boost_ratio", 0, 100], ["Dash 効果 %", "dash_ratio", 0, 100]]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)
		var label := Label.new()
		label.text = definition[0]
		label.custom_minimum_size.x = 94
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = definition[2]
		slider.max_value = definition[3]
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 116
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 40
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number)
		var key: String = definition[1]
		_sliders[key] = slider
		slider.value_changed.connect(func(value: float) -> void:
			number.text = str(roundi(value))
			if not _syncing:
				_state[key] = value / 100.0 if key in ["fuel_ratio", "air_green", "air_blue", "boost_ratio", "dash_ratio"] else value
				_refresh())


func _sample(index: int) -> Dictionary:
	var names := ["ナギ", "アカネ", "ソラ", "ヒカリ", "コハク", "モモ", "イワ", "ミント"]
	var colors := [Color("368eff"), Color("ff805a"), Color("5ee6dd"), Color("66efa5"), Color("e8bd64"), Color("ffc78d"), Color("9b8151"), Color("8be0ff")]
	var standings: Array = []
	for i in 8:
		standings.append({"name": names[i], "color": colors[i], "is_player": i == 1, "heart_bpm": 138.0 + i * 5, "fuel_ratio": 0.9 - i * 0.07, "finished": false, "style_group_count": 3, "style_group_index": i % 3, "style_rank_bonus": 0})
	var state := {"player_name": "アカネ", "trainer_name": "U16", "attribute_id": "fire", "attribute_color": Color("ff3769"), "style_group_count": 3, "style_group_index": 0, "style_rank_bonus": 1,
		"speed_kmh": 63.0, "heart_bpm": 143.0, "heart_min_bpm": 100.0, "heart_normal_max_bpm": 200.0, "heart_max_bpm": 230.0, "heart_beat_phase": 1.0, "notch": 6, "notch_max": 6, "fuel_ratio": 0.69, "air_green": 0.20, "air_blue": 0.48, "boost_uses_left": 3, "boost_max_uses": 3, "boost_ratio": 0.0, "dash_ratio": 0.6, "place": 2, "field_size": 8, "remaining_m": 846.0, "race_distance_m": 2400.0, "time_text": "1:32:48", "time_s": 92.48, "standings": standings,
		"runners": [{"ratio": 0.64, "is_player": true, "color": colors[1]}, {"ratio": 0.66, "is_player": false, "color": colors[0]}]}
	match index:
		1: state.merge({"notch": 3, "speed_kmh": 42.0, "heart_bpm": 128.0, "fuel_ratio": 0.92, "air_green": 0.10, "air_blue": 0.0, "dash_ratio": 0.0}, true)
		2: state.merge({"heart_bpm": 224.0, "fuel_ratio": -0.30, "boost_uses_left": 0, "dash_ratio": 0.15}, true)
		3: state.merge({"player_name": "あかねいろのぷるりん", "trainer_name": "長いトレーナー名", "speed_kmh": 128.0, "air_green": 0.55, "air_blue": 0.79, "fuel_ratio": 1.0}, true)
		4: state.merge({"notch": 1, "speed_kmh": 0.0, "heart_bpm": 100.0, "fuel_ratio": 0.0, "air_green": 0.0, "air_blue": 0.0, "boost_uses_left": 0, "dash_ratio": 0.0}, true)
	return state


func _apply_sample(index: int) -> void:
	_state = _sample(index)
	_sync_sliders()
	_refresh()


func _sync_sliders() -> void:
	_syncing = true
	for key: String in _sliders:
		var factor := 100.0 if key in ["fuel_ratio", "air_green", "air_blue", "boost_ratio", "dash_ratio"] else 1.0
		_sliders[key].value = float(_state.get(key, 0)) * factor
	_syncing = false


func _refresh() -> void:
	if _state.is_empty():
		return
	_state["standings"][1].heart_bpm = _state.heart_bpm
	_state["standings"][1].fuel_ratio = _state.fuel_ratio
	_state["standings"][1].name = _state.player_name
	_dashboard.update_state(_state)
	_legacy.update_state(_state)
	_summary.update_state(_state)


func _set_mode(mode: int) -> void:
	_mode = mode
	_layout_stage()


func _layout_stage() -> void:
	var canvas := Vector2(_stage_size)
	_background.size = canvas
	_solid.size = canvas
	_background.visible = _mode != 1
	_summary.visible = _mode != 1
	_dashboard.visible = _mode != 2
	_legacy.visible = _mode == 2
	if _mode == 1:
		var factor := minf((canvas.x - 70) / Dashboard.BASE_SIZE.x, (canvas.y - 40) / Dashboard.BASE_SIZE.y)
		_dashboard.set_scale_factor(factor)
		_dashboard.position = (canvas - _dashboard.size) * 0.5
	else:
		var factor := minf(0.52, (canvas.x - 360) / Dashboard.BASE_SIZE.x)
		_dashboard.set_scale_factor(factor)
		_dashboard.position = Vector2(14, 12)
	_summary.position = Vector2(canvas.x - 334, 18)
	_legacy.set_radius(142)
	_legacy.position = Vector2(14, canvas.y - _legacy.size.y - 10)


func _layout() -> void:
	if _view == null:
		return
	_toolbar.position = Vector2(16, 10)
	_controls.position = Vector2(size.x - 346, 64)
	_controls.size = Vector2(330, size.y - 80)
	var available := Vector2(size.x - 378, size.y - 88)
	var factor := minf(available.x / _stage_size.x, available.y / _stage_size.y)
	_view.size = Vector2(_stage_size) * maxf(factor, 0.1)
	_view.position = Vector2(16 + (available.x - _view.size.x) * 0.5, 68 + (available.y - _view.size.y) * 0.5)
	_layout_stage()


## Webと同じCompatibility描画でも輪郭を滑らかにするため、試作を2倍で描いて縮小。
func _set_stage_size(value: Vector2i) -> void:
	_stage_size = value
	_viewport.size = value * 2
	_viewport.size_2d_override = value
	_viewport.size_2d_override_stretch = true


func _process(delta: float) -> void:
	if _state.is_empty() or _capturing:
		return
	_pulse = fposmod(_pulse + delta * float(_state.heart_bpm) / 60.0, 1.0)
	_state.heart_beat_phase = _pulse
	_send_time += delta
	if _animate:
		_time += delta
		_state.speed_kmh = 55.0 + 12.0 * sin(_time * 0.5)
		_state.heart_bpm = 158.0 + 36.0 * sin(_time * 0.22)
		_state.fuel_ratio = 0.5 + 0.4 * cos(_time * 0.12)
		_state.dash_ratio = fposmod(_time * 0.16, 1.0)
		if _send_time >= 0.1:
			_sync_sliders()
	if _send_time >= 0.1:
		_send_time = 0
		_refresh()


func _capture() -> void:
	_capturing = true
	DirAccess.make_dir_recursive_absolute(_capture_directory)
	if not _verify_controls():
		get_tree().quit(1)
		return
	_apply_sample(0)
	_set_mode(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture_directory.path_join("preview_window.png"))
	for job in [["dashboard", 1, 0, Vector2i(1440, 960)], ["race_layout", 0, 0, BASE_STAGE], ["warning", 1, 2, Vector2i(1440, 960)], ["three_digits", 1, 3, Vector2i(1440, 960)], ["zero", 1, 4, Vector2i(1440, 960)], ["phone_layout", 0, 0, Vector2i(960, 540)], ["legacy_layout", 2, 0, BASE_STAGE]]:
		_set_stage_size(job[3])
		_set_mode(job[1])
		_apply_sample(job[2])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := _capture_directory.path_join(str(job[0]) + ".png")
		var error := _viewport.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("画像を保存できません: %s (%s)" % [path, error])
			get_tree().quit(1)
			return
		print("CAPTURE ", path)
	get_tree().quit()


## スライダーのシグナルが、左の盤・旧盤・右の自分の行へ届くことを確認。
func _verify_controls() -> bool:
	for entry in [["speed_kmh", 128, 128.0], ["heart_bpm", 224, 224.0], ["fuel_ratio", -30, -0.3], ["air_green", 55, 0.55], ["air_blue", 79, 0.79], ["notch", 2, 2.0], ["boost_uses_left", 0, 0.0], ["dash_ratio", 0, 0.0]]:
		_sliders[entry[0]].value = entry[1]
		for target: Control in [_dashboard, _legacy]:
			var state: Dictionary = target.get("_state")
			if not is_equal_approx(float(state.get(entry[0], -999)), entry[2]):
				push_error("値がUIへ届きません: %s" % entry[0])
				return false
	var right_state: Dictionary = _summary.get("_state")
	if not is_equal_approx(float(right_state["standings"][1]["fuel_ratio"]), -0.3):
		push_error("右側の順位表へ体力が届きません")
		return false
	_set_mode(2)
	if not _legacy.visible or _dashboard.visible:
		push_error("旧操作盤との比較切り替えに失敗")
		return false
	print("VERIFY: slider signals -> Codex / legacy / standings; comparison mode OK")
	return true
