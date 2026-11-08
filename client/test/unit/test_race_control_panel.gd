extends GutTest
## レースの左上の操作盤と、その下の順位表の配置を確かめる。期待値は、入力や式・場面の値から作る。

const RaceControlPanel := preload("res://scripts/presentation/hud/race_control_panel.gd")
const PanelScene := preload("res://scenes/hud/race_control_panel.tscn")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func _panel() -> Control:
	var panel: Control = PanelScene.instantiate()
	add_child_autofree(panel)
	return panel


func test_race_shows_the_panel_at_the_top_left_and_hides_the_old_bottom_panel() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var hud: Control = race.get("_heart_hud")
	assert_eq(hud.get_script(), RaceControlPanel)
	var view: Control = race.get_node("UI/HeartRaceHudView")
	assert_eq(view.position, race.HEART_HUD_MARGIN)
	assert_almost_eq(view.size.x, hud.render_rect.size.x * hud.panel_scale, 1.0)
	assert_false(bool(race.get_node("UI/RaceHud").get("main_panel_visible")))


func test_render_rect_sits_at_the_panel_origin() -> void:
	var panel := _panel()
	var factor := 0.5
	panel.set_scale_factor(factor)
	var actual := factor * float(panel.panel_scale)
	assert_almost_eq(panel.position + panel.render_rect.position * actual, Vector2.ZERO, Vector2(0.001, 0.001))
	assert_almost_eq(panel.custom_minimum_size, panel.render_rect.size * actual, Vector2(0.001, 0.001))


func test_values_reach_the_parts() -> void:
	var panel := _panel()
	var notch_max := 7
	var boost_max := 4
	panel.update_state({
		"speed_kmh": RaceControlPanel.SPEED_FULL_KMH * 0.5, "fuel_ratio": -0.4, "air_base": 0.05, "air_rear": 0.1, "air_blue": 0.2,
		"notch": 2, "notch_max": notch_max, "boost_uses_left": 1, "boost_max_uses": boost_max, "boost_ratio": 0.6,
		"dash_ratio": 0.3, "heart_bpm": 165.0, "heart_min_bpm": 100.0, "heart_max_bpm": 230.0, "heart_normal_max_bpm": 200.0,
		"player_name": "アカネ", "trainer_name": "U16",
	})
	assert_almost_eq(float(panel.get_node("Gauges/Speed").get("value")), 0.5, 0.0001)
	assert_eq(panel.get_node("SpeedText/SpeedValue").text, "%d" % int(round(RaceControlPanel.SPEED_FULL_KMH * 0.5)))
	assert_almost_eq(float(panel.get_node("Gauges/Stamina").get("value")), RaceControlPanel.stamina_value(-0.4), 0.0001)
	assert_eq(panel.get_node("StaminaText/StaminaValue").text, "-40")
	# 空力のゲージは、根本から 黄（空力の能力）・緑（後方支援）・青（ドラフト）を積み上げる。
	# 弧は AERO_FULL で満タン。数字は本当の割合。
	assert_almost_eq(float(panel.get_node("Aero/AeroBlue").get("value")), 0.35 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_almost_eq(float(panel.get_node("Aero/AeroGreen").get("value")), 0.15 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_almost_eq(float(panel.get_node("Aero/AeroBase").get("value")), 0.05 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_eq(panel.get_node("Aero/AeroValue").text, "35")
	assert_eq(int(panel.get_node("Notch/NotchBars").get("count")), notch_max)
	assert_eq(int(panel.get_node("Notch/NotchBars").get("lit_count")), 2)
	assert_eq(int(panel.get_node("Boost/BoostRing").get("count")), boost_max)
	assert_eq(int(panel.get_node("Boost/BoostRing").get("lit_count")), 1)
	assert_almost_eq(float(panel.get_node("Boost/BoostRing").get("partial")), 0.6, 0.0001)
	assert_almost_eq(float(panel.get_node("Dash/DashBar").get("value")), 0.3, 0.0001)
	assert_almost_eq(float(panel.get_node("Heart").get("value")), 0.5, 0.0001)
	assert_eq(panel.get_node("NameRow/Name").text, "アカネ")
	assert_eq(panel.get_node("NameRow/Trainer").text, "（U16）")


func test_stamina_zero_is_the_middle_of_the_arc() -> void:
	assert_almost_eq(RaceControlPanel.stamina_value(1.0), 1.0, 0.0001)
	assert_almost_eq(RaceControlPanel.stamina_value(0.0), 0.5, 0.0001)
	assert_almost_eq(RaceControlPanel.stamina_value(-1.0), 0.0, 0.0001)


func test_long_name_is_squeezed_before_the_attribute_mark() -> void:
	var panel := _panel()
	panel.update_state({"player_name": "ア".repeat(12), "trainer_name": "ト".repeat(12)})
	var name: Label = panel.get_node("NameRow/Name")
	var attribute: Control = panel.get_node("NameRow/Attribute")
	assert_lt(name.position.x + name.get_minimum_size().x * name.scale.x, attribute.position.x)


func test_heart_water_turns_from_cyan_to_red_near_the_limit() -> void:
	var normal_max := 200.0
	assert_eq(RaceControlPanel.heart_water_color(normal_max - RaceControlPanel.HEART_WARN_FROM_BPM, normal_max, 230.0), RaceControlPanel.COLOR_HEART_LOW)
	assert_eq(RaceControlPanel.heart_water_color(230.0, normal_max, 230.0), RaceControlPanel.COLOR_HEART_HIGH)


func test_standings_sit_under_the_panel_at_its_left_edge() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var view: Control = race.get_node("UI/HeartRaceHudView")
	var origin: Vector2 = race.get_node("UI/RaceHud").get("standings_origin")
	# 操作盤のすぐ下に、左はしをそろえる。
	assert_almost_eq(origin.y, view.position.y + view.size.y + float(race.STANDINGS_GAP), 0.001)
	assert_almost_eq(origin.x - RaceHud.STANDINGS_ROW_PAD, view.position.x, 0.001)
	var hud: Control = race.get_node("UI/RaceHud")
	var panel: Control = race.get("_heart_hud")
	for panel_scale in [0.3, 0.6]:
		panel.panel_scale = panel_scale
		race.call("_place_heart_hud")
		var width: float = (RaceHud.STANDINGS_ROW_PAD + RaceHud.STANDINGS_WIDTH) * hud.standings_draw_scale()
		assert_almost_eq(width, view.size.x * hud.standings_scale, 0.001)


func test_stamina_lost_in_a_push_stays_red_and_then_fades() -> void:
	var panel := _panel()
	var stamina_hit := panel.get_node("Gauges/StaminaHit")
	panel.call("_update_stamina_hit", 0.8, true, 0)
	panel.call("_update_stamina_hit", 0.6, true, 100)
	# 押し合いのあいだは、始まったときの体力で、赤い帯の上のはしを止める。
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.8, 0.0001)
	# 終わったら、だんだん今の値へ戻り、決めた秒数で消える。
	panel.call("_update_stamina_hit", 0.6, false, 200)
	panel.call("_update_stamina_hit", 0.6, false, 200 + int(RaceControlPanel.STAMINA_HIT_FADE_S * 500.0))
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.7, 0.0001)
	panel.call("_update_stamina_hit", 0.6, false, 200 + int(RaceControlPanel.STAMINA_HIT_FADE_S * 1000.0))
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.6, 0.0001)
	assert_not_null(stamina_hit)


func test_losing_a_push_flashes_and_shakes_the_heart_and_then_restores_it() -> void:
	var panel := _panel()
	var heart: Control = panel.get_node("Heart")
	var edge: Color = heart.get("edge_color")
	var position: Vector2 = heart.position
	# 点滅のいちばん赤い瞬間（1回の点滅の4分の1）。
	panel.call("_update_heart_hit", true, int(1000.0 / RaceControlPanel.HEART_HIT_FLASH_PER_S / 4.0))
	assert_true((heart.get("edge_color") as Color).is_equal_approx(RaceControlPanel.HEART_HIT_EDGE_COLOR))
	panel.call("_update_heart_hit", false, 0)
	assert_true((heart.get("edge_color") as Color).is_equal_approx(edge))
	assert_eq(heart.position, position)


func _labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	for child in node.get_children():
		if child is Label:
			result.append(child)
		result.append_array(_labels(child))
	return result


func test_labels_have_separate_settings_in_each_scene_instance() -> void:
	var panel := _panel()
	var other := _panel()
	var seen: Array[LabelSettings] = []
	for label in _labels(panel):
		assert_false(seen.has(label.label_settings), label.name)
		seen.append(label.label_settings)
	var speed: Label = panel.get_node("SpeedText/SpeedValue")
	var stamina: Label = panel.get_node("StaminaText/StaminaValue")
	var original := stamina.label_settings.font_size
	speed.label_settings.font_size += 7
	assert_eq(stamina.label_settings.font_size, original)
	assert_ne(speed.label_settings.font_size, other.get_node("SpeedText/SpeedValue").label_settings.font_size)


func test_updates_preserve_edited_parts_and_fixed_words() -> void:
	var panel := _panel()
	panel.fit_long_names = false
	panel.trainer_after_name = false
	var paths := ["Heart", "Gauges", "Gauges/Speed", "Notch/NotchBars", "Boost/BoostRing", "NameRow/Name", "NameRow/Trainer", "Aero/Icon", "Boost/BoostButton", "RaceInfo/Minutes"]
	var positions: Array[Vector2] = []
	for path in paths:
		var part: Control = panel.get_node(path)
		part.position += Vector2(13, 17)
		part.scale = Vector2(0.8, 1.2)
		part.visible = false
		positions.append(part.position)
	var fixed: Label = panel.get_node("RaceInfo/MinuteUnit")
	fixed.text = "編集した字"
	panel.update_state({"time_s": 62.4, "player_name": "名前", "trainer_name": "親"})
	for i in paths.size():
		var part: Control = panel.get_node(paths[i])
		assert_eq(part.position, positions[i], paths[i])
		assert_eq(part.scale, Vector2(0.8, 1.2), paths[i])
		assert_false(part.visible, paths[i])
	assert_eq(fixed.text, "編集した字")
	assert_eq(panel.get_node("RaceInfo/Minutes").text, "1")
	assert_eq(panel.get_node("RaceInfo/Seconds").text, "02")
	assert_eq(panel.get_node("RaceInfo/Centiseconds").text, "40")


func test_time_carries_and_large_numbers_reach_separate_labels() -> void:
	var panel := _panel()
	panel.update_state({"time_s": 59.999, "place": 123, "field_size": 456, "remaining_m": 123456.0})
	assert_eq(panel.get_node("RaceInfo/Minutes").text, "1")
	assert_eq(panel.get_node("RaceInfo/Seconds").text, "00")
	assert_eq(panel.get_node("RaceInfo/Centiseconds").text, "00")
	assert_eq(panel.get_node("RaceInfo/Place").text, "123")
	assert_eq(panel.get_node("RaceInfo/Field").text, "456")
	assert_eq(panel.get_node("RaceInfo/Remaining").text, "123456")


func test_scale_and_render_bounds_are_independent_of_board() -> void:
	var panel := _panel()
	panel.panel_scale = 0.6
	panel.render_rect = Rect2(-100, -80, 1200, 900)
	panel.get_node("Board").position += Vector2(40, 30)
	for zoom in [1.0, 1.5, 2.0]:
		panel.set_scale_factor(zoom)
		assert_eq(panel.panel_scale, 0.6)
		assert_almost_eq(panel.scale, Vector2.ONE * 0.6 * zoom, Vector2.ONE * 0.001)
		assert_almost_eq(panel.custom_minimum_size, Vector2(1200, 900) * 0.6 * zoom, Vector2.ONE * 0.001)


func test_independent_arc_keeps_its_edited_geometry() -> void:
	var panel := _panel()
	var arc: Control = panel.get_node("Gauges/Speed")
	arc.follow_ring = false
	arc.position = Vector2(30, 40)
	arc.center = Vector2(170, 180)
	arc.radius = 140.0
	panel.get_node("Gauges").radius += 10.0
	assert_eq(arc.position, Vector2(30, 40))
	assert_eq(arc.center, Vector2(170, 180))
	assert_eq(arc.radius, 140.0)


func test_notch_follows_transformed_arc_and_grows_upwards() -> void:
	var panel := _panel()
	var bars: Control = panel.get_node("Notch/NotchBars")
	var arc: Control = panel.get_node("Gauges/Stamina")
	panel.get_node("Gauges").position += Vector2(23, 11)
	panel.get_node("Notch").position += Vector2(-17, 9)
	var previous := 0.0
	var transform := bars.get_global_transform().affine_inverse() * arc.get_global_transform()
	var center: Vector2 = transform * Vector2(arc.center)
	var radius: float = (arc.radius + arc.thickness * 0.5) * transform.x.length() + bars.arc_gap
	for i in bars.count:
		var shape: PackedVector2Array = bars.bar_shape(i)
		var expected := center.x + sqrt(maxf(0.0, radius * radius - pow(shape[0].y - center.y, 2.0)))
		assert_almost_eq(shape[0].x, expected, 0.001)
		var length := shape[1].x - shape[0].x
		if i > 0:
			assert_gte(length + 0.001, previous + bars.length_growth)
		previous = length


func test_boost_segments_accept_any_configured_count() -> void:
	var panel := _panel()
	var ring: Control = panel.get_node("Boost/BoostRing")
	for count in [1, 4, 7]:
		panel.update_state({"boost_max_uses": count, "boost_uses_left": count - 1, "boost_ratio": 0.6})
		assert_eq(ring.count, count)
		for i in count:
			assert_almost_eq(ring.segment_fill(i), 1.0 if i < count - 1 else 0.6, 0.001)


func test_heart_bounds_include_the_largest_beat_and_match_shape_heights() -> void:
	var panel := _panel()
	var heart: Control = panel.get_node("Heart")
	var bounds: Vector2 = heart.shape_heights()
	assert_almost_eq(bounds.x, (pow(heart.blunt, 0.25) - 1.0) / heart.dip * heart.tip, 0.0001)
	var box: Rect2 = heart.drawn_rect()
	for i in 401:
		var x := -1.0 + float(i) / 200.0
		for sign_value in [-1.0, 1.0]:
			var y: float = (sign_value * sqrt(maxf(0.0, 1.0 - x * x)) + pow(x * x + heart.blunt, 0.25)) / heart.dip
			if y < 0.0:
				y *= heart.tip
			var point: Vector2 = heart.center + Vector2(x * heart.size_x, -y * heart.size_y) * (1.0 + heart.beat_grow)
			assert_true(box.has_point(point))


func test_scene_reopens_without_moving_geometry() -> void:
	var first := _panel()
	var packed := PackedScene.new()
	assert_eq(packed.pack(first), OK)
	var reopened: Control = packed.instantiate()
	add_child_autofree(reopened)
	for path in ["Heart", "Gauges", "Gauges/Speed", "Aero/AeroBlue", "Notch/NotchBars"]:
		var before: Control = first.get_node(path)
		var after: Control = reopened.get_node(path)
		assert_eq(after.position, before.position, path)
		assert_eq(after.scale, before.scale, path)


func _text_width(label: Label) -> float:
	return label.label_settings.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.label_settings.font_size).x


func test_trainer_follows_the_visible_name_width_only_when_enabled() -> void:
	var panel := _panel()
	var name: Label = panel.get_node("NameRow/Name")
	var trainer: Label = panel.get_node("NameRow/Trainer")
	panel.fit_long_names = false
	trainer.position.y += 17.0
	trainer.scale = Vector2(0.7, 1.4)
	trainer.visible = false
	var y := trainer.position.y
	for text in ["ア", "アカネ", "長い名前".repeat(4)]:
		panel.update_state({"player_name": text, "trainer_name": "U16"})
		assert_almost_eq(trainer.position.x, name.position.x + _text_width(name) * name.scale.x + float(panel.trainer_name_gap), 0.001)
		assert_eq(trainer.position.y, y)
		assert_eq(trainer.scale, Vector2(0.7, 1.4))
		assert_false(trainer.visible)
	panel.trainer_after_name = false
	trainer.position = Vector2(77, 123)
	for fit in [false, true]:
		panel.fit_long_names = fit
		panel.update_state({"player_name": "ア".repeat(12), "trainer_name": "U16"})
		assert_eq(trainer.position, Vector2(77, 123))


func test_long_name_and_trainer_fit_together_before_the_attribute() -> void:
	var panel := _panel()
	var name: Label = panel.get_node("NameRow/Name")
	var trainer: Label = panel.get_node("NameRow/Trainer")
	var attribute: Control = panel.get_node("NameRow/Attribute")
	var name_scale := name.scale
	var trainer_scale := trainer.scale
	panel.update_state({"player_name": "ア".repeat(20), "trainer_name": "ト".repeat(20)})
	assert_lt(name.scale.x, name_scale.x)
	assert_almost_eq(name.scale.x / name_scale.x, trainer.scale.x / trainer_scale.x, 0.001)
	assert_lte(trainer.position.x + _text_width(trainer) * trainer.scale.x, attribute.position.x - RaceControlPanel.NAME_GAP + 0.001)
	assert_eq(name.scale.y, name_scale.y)
	assert_eq(trainer.scale.y, trainer_scale.y)
	panel.update_state({"player_name": "ア", "trainer_name": "U16"})
	assert_eq(name.scale, name_scale)
	assert_eq(trainer.scale, trainer_scale)


func _board_point(panel: Control, part: Control, point := Vector2.ZERO) -> Vector2:
	return panel.get_global_transform().affine_inverse() * (part.get_global_transform() * point) - panel.get_node("Board").position


func test_reference_icon_and_boost_button_centers() -> void:
	var panel := _panel()
	var centers := {"SpeedText/Icon": Vector2(224, 291), "StaminaText/Icon": Vector2(252, 574), "Aero/Icon": Vector2(38, 353), "Notch/Icon": Vector2(560, 311), "Boost/Icon": Vector2(607, 531), "Dash/Icon": Vector2(723, 531)}
	for path in centers:
		assert_almost_eq(_board_point(panel, panel.get_node(path)), centers[path], Vector2.ONE * 0.001, path)
	var ring: Control = panel.get_node("Boost/BoostRing")
	assert_almost_eq(_board_point(panel, ring, ring.center), Vector2(702, 474), Vector2.ONE * 0.001)
	var button: Control = panel.get_node("Boost/BoostButton")
	assert_almost_eq(_board_point(panel, button, button.size * 0.5), Vector2(702.2, 473.3), Vector2.ONE * 0.001)
	assert_eq(button.scale, panel.get_node("Dash/DashButton").scale)
	assert_eq(button.mark_size, panel.get_node("Dash/DashButton").mark_size)
	for path in ["Aero/AeroBlue", "Aero/AeroGreen", "Aero/AeroBase"]:
		var arc: Control = panel.get_node(path)
		assert_almost_eq(_board_point(panel, arc, arc.center), Vector2(366.78, 435.97) + Vector2(16, -10), Vector2.ONE * 0.02)
	assert_almost_eq(_board_point(panel, panel.get_node("Aero/AeroUnit")), Vector2(130, 377), Vector2.ONE * 0.001)


func test_split_text_matches_reference_spacing_and_time_grows_left() -> void:
	var panel := _panel()
	panel.update_state({"time_s": 62.4, "remaining_m": 1240.0, "field_size": 8, "boost_max_uses": 3, "boost_uses_left": 2})
	var minute: Label = panel.get_node("RaceInfo/Minutes")
	var second: Label = panel.get_node("RaceInfo/Seconds")
	var centi: Label = panel.get_node("RaceInfo/Centiseconds")
	var minute_unit: Label = panel.get_node("RaceInfo/MinuteUnit")
	var second_unit: Label = panel.get_node("RaceInfo/SecondUnit")
	for pair in [[minute, minute_unit], [minute_unit, second], [second, second_unit], [second_unit, centi]]:
		var left: Label = pair[0]
		var right: Label = pair[1]
		assert_almost_eq(left.position.x + left.size.x, right.position.x + right.size.x - _text_width(right), 1.0, left.name)
	assert_almost_eq(_board_point(panel, centi, Vector2(centi.size.x, 0)), Vector2(738, 104.5), Vector2.ONE * 0.001)
	var minute_right := minute.position.x + minute.size.x
	panel.update_state({"time_s": 12345.0 * 60.0 + 2.4})
	assert_eq(minute.text, "12345")
	assert_almost_eq(minute.position.x + minute.size.x, minute_right, 0.001)
	assert_lte(minute.position.x + minute.size.x, minute_unit.position.x + 0.001)
	for group in [["RaceInfo/RemainingWord", "RaceInfo/Remaining", "RaceInfo/RemainingUnit"], ["RaceInfo/Slash", "RaceInfo/Field", "RaceInfo/PlaceUnit"], ["Boost/BoostOpen", "Boost/BoostCount", "Boost/BoostClose"]]:
		# 比較する文字を同じ更新で入れ、前後の半角空白の幅を確かめる。
		panel.update_state({"remaining_m": 1240.0, "field_size": 8, "boost_max_uses": 3, "boost_uses_left": 2})
		for i in 2:
			var left: Label = panel.get_node(group[i])
			var right: Label = panel.get_node(group[i + 1])
			var space := left.label_settings.font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, left.label_settings.font_size).x
			var left_end := left.position.x + (left.size.x if left.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else _text_width(left))
			var right_start := right.position.x + (right.size.x - _text_width(right) if right.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
			assert_almost_eq(right_start - left_end, space, 1.0, left.name)
