extends GutTest

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")


func _runner(stats: Dictionary = {}) -> Node3D:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child_autofree(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	var merged := {"acceleration": 5, "handling": 5, "stamina": 5, "cardio": 5}
	merged.merge(stats, true)
	runner.set("_effective_stats", merged)
	runner.call("_reset_stamina_for_effective_stats")
	runner.set("_race_active", true)
	runner.call("set_drive_level", 4.0)
	return runner


func test_drive_boost_multiplier_scales_only_the_drive_force() -> void:
	var plain := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 4.0)
	var boosted := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 4.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, false, 1.5)
	assert_almost_eq(float(boosted["drive_contribution_kmh_per_s"]), float(plain["drive_contribution_kmh_per_s"]) * 1.5, 0.0001)
	assert_almost_eq(float(boosted["air_resistance_kmh_per_s"]), float(plain["air_resistance_kmh_per_s"]), 0.0001)
	assert_almost_eq(float(boosted["rolling_resistance_kmh_per_s"]), float(plain["rolling_resistance_kmh_per_s"]), 0.0001)
	# 倍率1.0は、今までと同じ。
	var same := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 4.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, false, 1.0)
	assert_almost_eq(float(same["total_acceleration_kmh_per_s"]), float(plain["total_acceleration_kmh_per_s"]), 0.0001)
	# ブレーキ中は、倍率をかけない。
	var braking := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 4.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, true, 1.5)
	assert_almost_eq(float(braking["drive_contribution_kmh_per_s"]), -LocalRaceMath.BRAKE_DECELERATION_KMH_PER_S, 0.0001)


func test_dash_thrust_grows_with_acceleration_and_a_little_with_handling() -> void:
	var base := LocalRaceMath.Config.number("dash_thrust_bonus")
	assert_almost_eq(LocalRaceMath.dash_thrust_bonus(5, 5), base, 0.0001)
	var by_acceleration := LocalRaceMath.dash_thrust_bonus(10, 5) - base
	var by_handling := LocalRaceMath.dash_thrust_bonus(5, 10) - base
	assert_gt(by_acceleration, by_handling)
	assert_gt(by_handling, 0.0)
	assert_gte(LocalRaceMath.dash_thrust_bonus(1, 1), 0.0)


func test_boost_points_fall_in_a_straight_line_to_zero() -> void:
	var duration := LocalRaceMath.Config.number("boost_duration_s")
	var per_use := LocalRaceMath.Config.number("boost_points_per_use")
	assert_almost_eq(LocalRaceMath.boost_points(per_use, duration), per_use, 0.0001)
	assert_almost_eq(LocalRaceMath.boost_points(per_use, duration * 0.5), per_use * 0.5, 0.0001)
	assert_eq(LocalRaceMath.boost_points(per_use, 0.0), 0.0)
	assert_almost_eq(LocalRaceMath.boost_thrust_bonus(per_use, 1.0), per_use * LocalRaceMath.Config.number("boost_thrust_per_point"), 0.0001)


func test_boost_is_stronger_with_more_stamina_left() -> void:
	var floor_factor := LocalRaceMath.Config.number("boost_stamina_factor_min")
	assert_almost_eq(LocalRaceMath.boost_stamina_factor(1.0), 1.0, 0.0001)
	assert_almost_eq(LocalRaceMath.boost_stamina_factor(0.0), floor_factor, 0.0001)
	assert_almost_eq(LocalRaceMath.boost_stamina_factor(-0.5), floor_factor, 0.0001)
	assert_gt(LocalRaceMath.boost_thrust_bonus(300.0, 0.8), LocalRaceMath.boost_thrust_bonus(300.0, 0.2))


func test_boost_halves_the_debt_penalty() -> void:
	var scale := LocalRaceMath.Config.number("boost_debt_penalty_scale")
	assert_almost_eq(LocalRaceMath.boosted_debt_efficiency(1.0), 1.0, 0.0001)
	assert_almost_eq(LocalRaceMath.boosted_debt_efficiency(0.6), 1.0 - 0.4 * scale, 0.0001)


func test_dash_refreshes_but_does_not_stack_and_ends_after_its_duration() -> void:
	var runner := _runner()
	assert_true(runner.call("trigger_dash"))
	var once := float(runner.call("get_drive_boost_multiplier"))
	assert_almost_eq(once, 1.0 + LocalRaceMath.dash_thrust_bonus(5, 5), 0.0001)
	runner.set("_dash_time_left", 0.5)
	assert_true(runner.call("trigger_dash"))
	assert_almost_eq(float(runner.call("get_drive_boost_multiplier")), once, 0.0001)
	assert_almost_eq(float(runner.get("_dash_time_left")), LocalRaceMath.Config.number("dash_duration_s"), 0.0001)
	runner.set("_dash_time_left", 0.0)
	assert_false(runner.call("is_dash_active"))
	assert_almost_eq(float(runner.call("get_drive_boost_multiplier")), 1.0, 0.0001)


func test_dash_and_boost_need_a_positive_notch_and_no_brake() -> void:
	var runner := _runner()
	runner.call("set_drive_level", 0.0)
	assert_false(runner.call("trigger_dash"))
	assert_false(runner.call("trigger_boost"))
	runner.call("set_drive_level", 4.0)
	runner.call("set_braking", true)
	assert_false(runner.call("trigger_dash"))
	assert_false(runner.call("trigger_boost"))
	assert_eq(int(runner.call("get_boost_uses_left")), int(LocalRaceMath.Config.number("boost_max_uses")))
	runner.call("set_braking", false)
	runner.set("_race_active", false)
	assert_false(runner.call("trigger_boost"))


func test_boost_stacks_on_the_remaining_points_and_is_limited_in_uses() -> void:
	var runner := _runner()
	var per_use := LocalRaceMath.Config.number("boost_points_per_use")
	var duration := LocalRaceMath.Config.number("boost_duration_s")
	var max_uses := int(LocalRaceMath.Config.number("boost_max_uses"))
	assert_true(runner.call("trigger_boost"))
	assert_almost_eq(float(runner.call("get_boost_points")), per_use, 0.0001)
	# 半分の時間が過ぎたところで重ねる。残りの半分に、上乗せされ、残り時間が戻る。
	runner.set("_boost_time_left", duration * 0.5)
	assert_true(runner.call("trigger_boost"))
	assert_almost_eq(float(runner.call("get_boost_points")), per_use + per_use * 0.5 * (1.0 + LocalRaceMath.Config.number("boost_stack_bonus")), 0.0001)
	# 残りがなければ、割り増しはない。
	assert_almost_eq(LocalRaceMath.boost_points_after_press(0.0), per_use, 0.0001)
	assert_almost_eq(float(runner.get("_boost_time_left")), duration, 0.0001)
	for _i in max_uses - 2:
		assert_true(runner.call("trigger_boost"))
	assert_eq(int(runner.call("get_boost_uses_left")), 0)
	var before := float(runner.call("get_boost_points"))
	assert_false(runner.call("trigger_boost"))
	assert_almost_eq(float(runner.call("get_boost_points")), before, 0.0001)


func test_boost_costs_heart_rate_and_stamina_when_used() -> void:
	var runner := _runner()
	var heart_before := float(runner.call("get_heart_rate_bpm"))
	var stamina_before := float(runner.call("get_stamina"))
	runner.call("trigger_boost")
	assert_almost_eq(float(runner.call("get_heart_rate_bpm")) - heart_before, LocalRaceMath.Config.number("boost_heart_cost_bpm"), 0.0001)
	assert_almost_eq(stamina_before - float(runner.call("get_stamina")), LocalRaceMath.Config.number("boost_stamina_cost_l"), 0.0001)


func test_active_dash_and_boost_raise_stamina_use_and_heart_rise() -> void:
	var results := {}
	for mode: String in ["none", "dash", "boost"]:
		var runner := _runner()
		runner.set("_previous_selected_drive_level", 4.0)
		if mode == "dash":
			runner.set("_dash_time_left", 1.0)
		elif mode == "boost":
			runner.set("_boost_time_left", 1.0)
			runner.set("_boost_points_at_press", 100.0)
		var heart_before := float(runner.call("get_heart_rate_bpm"))
		var stamina_before := float(runner.call("get_stamina"))
		runner.call("_update_condition_for_drive_level", 4.0, 1.0)
		results[mode] = {"heart": float(runner.call("get_heart_rate_bpm")) - heart_before, "stamina": stamina_before - float(runner.call("get_stamina"))}
	# 体力の消費は、倍率ぶん増える（心拍が上がるぶん、少し上乗せされる）。どちらが大きいかは、設定しだい。
	for mode: String in ["dash", "boost"]:
		var expected := float(results["none"]["stamina"]) * LocalRaceMath.Config.number("%s_stamina_multiplier" % mode)
		assert_gte(float(results[mode]["stamina"]), expected * 0.99, mode)
		assert_lte(float(results[mode]["stamina"]), expected * 1.15, mode)
		assert_gt(float(results[mode]["heart"]), float(results["none"]["heart"]), mode)


func test_boost_softens_the_debt_penalty_on_propulsion() -> void:
	var runner := _runner()
	runner.set("_stamina", -float(runner.get("_stamina_capacity_l")) * 0.5)
	var without := float(runner.call("get_propulsion_efficiency"))
	runner.set("_boost_time_left", 1.0)
	runner.set("_boost_points_at_press", 100.0)
	var with_boost := float(runner.call("get_propulsion_efficiency"))
	assert_lt(without, 1.0)
	assert_gt(with_boost, without)
	assert_lt(with_boost, 1.0)


func test_only_a_fresh_press_counts_for_dash_and_boost_keys() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Z
	press.pressed = true
	assert_true(RaceControllerInput.is_dash_pressed(press))
	assert_false(RaceControllerInput.is_boost_pressed(press))
	# 押しっぱなしの繰り返しは数えない。
	var held := InputEventKey.new()
	held.physical_keycode = KEY_Z
	held.pressed = true
	held.echo = true
	assert_false(RaceControllerInput.is_dash_pressed(held))
	var boost_key := InputEventKey.new()
	boost_key.physical_keycode = KEY_X
	boost_key.pressed = true
	assert_true(RaceControllerInput.is_boost_pressed(boost_key))
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	pad.pressed = true
	assert_true(RaceControllerInput.is_dash_pressed(pad))
	pad.button_index = JOY_BUTTON_X
	assert_true(RaceControllerInput.is_boost_pressed(pad))
