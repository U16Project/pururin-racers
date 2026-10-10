extends GutTest
## ゴールしたあとの走り：少し進んでから速さを落とし、ゆっくり進んで、ほかの走者を待つ。

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const LocalRaceController := preload("res://scripts/local_race_controller.gd")
const PlayerGroundMarker := preload("res://scripts/presentation/player_ground_marker.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")


func _start() -> float:
	return LocalRaceMath.Config.number("finish_slowdown_start_m")


func _end() -> float:
	return LocalRaceMath.Config.number("finish_slowdown_end_m")


func _cruise() -> float:
	return LocalRaceMath.Config.number("finish_cruise_speed_kmh")


func test_speed_is_kept_then_falls_then_stays_slow_after_the_goal() -> void:
	var speed := _cruise() + 40.0
	assert_gt(_end(), _start(), "ゆっくり進み始める距離は、速さを落とし始める距離より先")
	assert_lt(_cruise(), LocalRaceMath.MIN_SPEED_KMH, "ゆっくりの速さは、レース中の最低の速さより遅い")
	# 速さを落とし始める距離までは、そのまま。
	assert_almost_eq(LocalRaceMath.post_finish_speed_kmh(speed, 0.0), speed, 0.0001)
	assert_almost_eq(LocalRaceMath.post_finish_speed_kmh(speed, _start()), speed, 0.0001)
	# その間は、進むほど遅くなる。まん中では、ちょうど間の速さ。
	var middle := LocalRaceMath.post_finish_speed_kmh(speed, (_start() + _end()) * 0.5)
	assert_almost_eq(middle, (speed + _cruise()) * 0.5, 0.0001)
	var previous := speed
	for step in 11:
		var now := LocalRaceMath.post_finish_speed_kmh(speed, lerpf(_start(), _end(), float(step) / 10.0))
		assert_lte(now, previous + 0.0001)
		previous = now
	# ゆっくり進み始める距離からは、ずっと、ゆっくりの速さ。
	assert_almost_eq(LocalRaceMath.post_finish_speed_kmh(speed, _end()), _cruise(), 0.0001)
	assert_almost_eq(LocalRaceMath.post_finish_speed_kmh(speed, _end() + 500.0), _cruise(), 0.0001)
	# もともと、ゆっくりの速さより遅ければ、速くはしない。
	assert_almost_eq(LocalRaceMath.post_finish_speed_kmh(_cruise() * 0.5, _end() + 10.0), _cruise() * 0.5, 0.0001)


func _race_runner() -> Node3D:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var runner: Node3D = (race.call("get_runners_for_simulation") as Array)[0]
	# ほかの走者に、ふさがれない状態で確かめる。
	runner.call("set_others_snapshot", [])
	runner.call("set_race_active", true)
	return runner


func test_a_finished_runner_slows_down_past_the_goal_and_keeps_moving() -> void:
	var runner := _race_runner()
	var distance := RaceSession.selected_distance_m()
	# ゆっくり進み始める距離を過ぎた所に置いて、ゴール済みにする。
	runner.set("_race_progress", distance + _end() + 5.0)
	runner.call("mark_finished", 1, 100.0)
	var before := float(runner.call("get_race_progress"))
	var tick := 1.0 / 60.0
	for _step in 120:
		runner.call("_process", tick)
		runner.call("set_others_snapshot", [])
	var moved := float(runner.call("get_race_progress")) - before
	# 2秒で進む距離は、ゆっくりの速さぶん（止まらない。レース中の最低の速さより、ずっと遅い）。
	assert_almost_eq(moved, _cruise() / 3.6 * 2.0, _cruise() / 3.6 * 2.0 * 0.1)
	assert_gt(moved, 0.0)


func test_a_runner_that_has_not_finished_is_not_slowed_past_the_same_distance() -> void:
	var runner := _race_runner()
	var distance := RaceSession.selected_distance_m()
	runner.set("_race_progress", distance + _end() + 5.0)
	var before := float(runner.call("get_race_progress"))
	var tick := 1.0 / 60.0
	for _step in 120:
		runner.call("_process", tick)
		runner.call("set_others_snapshot", [])
	var moved := float(runner.call("get_race_progress")) - before
	assert_gt(moved, LocalRaceMath.MIN_SPEED_KMH / 3.6 * 2.0 * 0.9, "ゴールの印が付いていなければ、レース中の速さのまま")


func _race() -> Node:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	return race


func test_results_wait_for_the_last_runner_and_for_a_while_after_the_player() -> void:
	var after_last := float(LocalRaceController.RESULT_WAIT_AFTER_LAST_S)
	var after_player := float(LocalRaceController.RESULT_WAIT_AFTER_PLAYER_S)
	assert_gt(after_player, after_last)
	# ユーザーが最後にゴールした（ゴールしたばかり）：ユーザーのゴールから、長いほうの秒数を待つ。
	assert_almost_eq(LocalRaceController.result_wait_seconds(0.0), after_player, 0.0001)
	assert_almost_eq(LocalRaceController.result_wait_seconds(1.0), after_player - 1.0, 0.0001)
	# ユーザーがずっと前にゴールしていた：最後の走者のゴールから、短いほうの秒数だけ待つ。
	assert_almost_eq(LocalRaceController.result_wait_seconds(after_player), after_last, 0.0001)
	assert_almost_eq(LocalRaceController.result_wait_seconds(60.0), after_last, 0.0001)


func test_runners_keep_moving_after_the_results_are_shown() -> void:
	var race := _race()
	var runners: Array = race.call("get_runners_for_simulation")
	var distance := RaceSession.selected_distance_m()
	race.set("_race_started", true)
	for index in runners.size():
		var runner: Node3D = runners[index]
		runner.call("set_race_active", true)
		runner.set("_race_progress", distance + 1.0 + float(index))
		runner.call("mark_finished", index + 1, 100.0 + float(index))
	race.call("_show_results")
	assert_true(race.get("_race_over"))
	assert_false(race.get("_paused"), "結果の板を出しても、レースは一時停止にしない")
	var elapsed := float(race.get("_race_elapsed"))
	var before := float(runners[0].call("get_race_progress"))
	for _step in 30:
		race.call("_process", 1.0 / 60.0)
		for runner: Node3D in runners:
			assert_false(runner.get("_paused"))
			runner.call("_process", 1.0 / 60.0)
	assert_gt(float(runners[0].call("get_race_progress")), before, "走者は進み続ける")
	assert_almost_eq(float(race.get("_race_elapsed")), elapsed, 0.0001, "時計は止まる")


func test_the_control_panel_freezes_at_the_goal_but_the_standings_keep_updating() -> void:
	var race := _race()
	var runners: Array = race.call("get_runners_for_simulation")
	var player: Node3D = race.get("_player")
	var hud: Control = race.get("_race_hud")
	var distance := RaceSession.selected_distance_m()
	race.set("_race_started", true)
	race.set("_race_elapsed", 123.0)
	player.set("_race_progress", distance + 0.5)
	player.set("_actual_speed_kmh", 57.0)
	player.call("mark_finished", 1, 121.5)
	race.call("_update_race_hud")
	var state: Dictionary = hud.get("_state")
	assert_almost_eq(float(state["speed_kmh"]), 57.0, 0.0001)
	assert_eq(state["time_text"], LocalRaceMath.format_race_time(121.5), "タイムは、ゴールした時刻")
	# そのあと、速さや時計が変わっても、操作盤は、ゴールした時点のまま。
	player.set("_actual_speed_kmh", 10.0)
	player.set("_stamina", -1.0)
	race.set("_race_elapsed", 140.0)
	var fuel_at_goal := float(state["fuel_ratio"])
	# 順位表は動き続ける：ほかの走者がゴールすると、その行に着順が入る。
	var other: Node3D = runners[1] if runners[0] == player else runners[0]
	other.call("mark_finished", 2, 130.0)
	race.call("_update_race_hud")
	state = hud.get("_state")
	assert_almost_eq(float(state["speed_kmh"]), 57.0, 0.0001)
	assert_almost_eq(float(state["fuel_ratio"]), fuel_at_goal, 0.0001)
	assert_eq(state["time_text"], LocalRaceMath.format_race_time(121.5))
	var finished_rows := 0
	for row: Dictionary in state["standings"]:
		if bool(row.get("finished", false)):
			finished_rows += 1
	assert_eq(finished_rows, 2, "順位表には、あとからゴールした走者も入る")


func test_a_finished_row_in_the_standings_keeps_its_heart_and_stamina_from_the_goal() -> void:
	var race := _race()
	var runners: Array = race.call("get_runners_for_simulation")
	race.set("_race_started", true)
	var finisher: Node3D = runners[2]
	var racing: Node3D = runners[3]
	finisher.set("_heart_rate_bpm", 150.0)
	racing.set("_heart_rate_bpm", 150.0)
	finisher.call("mark_finished", 1, 100.0)
	var rows: Array = race.call("_hud_standings")
	var fuel_at_goal := 0.0
	for row: Dictionary in rows:
		if str(row["name"]) == str(finisher.get("display_name")):
			fuel_at_goal = float(row["fuel_ratio"])
	# そのあと、心拍と体力が変わっても、ゴールした行は、ゴールした時点の数字のまま。まだ走っている行は、今の数字。
	finisher.set("_heart_rate_bpm", 190.0)
	finisher.set("_stamina", -1.0)
	racing.set("_heart_rate_bpm", 190.0)
	rows = race.call("_hud_standings")
	for row: Dictionary in rows:
		if str(row["name"]) == str(finisher.get("display_name")):
			assert_almost_eq(float(row["heart_bpm"]), 150.0, 0.0001)
			assert_almost_eq(float(row["fuel_ratio"]), fuel_at_goal, 0.0001)
		if str(row["name"]) == str(racing.get("display_name")):
			assert_almost_eq(float(row["heart_bpm"]), 190.0, 0.0001)



func test_the_result_board_offers_retry_and_return_and_both_sound_like_a_decision() -> void:
	var race := _race()
	var retry := race.find_child("ResultRetryButton", true, false) as Button
	var back := race.find_child("ResultReturnButton", true, false) as Button
	assert_eq(retry.text, "もう1回 同条件で")
	assert_eq(back.text, "レース選択へ戻る")
	# 2つは横に並び、左右で行き来できる。
	assert_eq(retry.get_parent(), back.get_parent())
	assert_lt(retry.get_index(), back.get_index())
	assert_eq(retry.get_node(retry.focus_neighbor_right), back)
	assert_eq(back.get_node(back.focus_neighbor_left), retry)
	# もう1回は、同じレースの場面を開き直す（レース選択で決めた内容は変えない）。
	assert_eq(LocalRaceController.LOCAL_RACE_SCENE, "res://scenes/local_race.tscn")
	var before := RaceSession.slots_snapshot()
	assert_eq(RaceSession.slots_snapshot(), before)
	# どちらのボタンも、決定の音（戻るの音ではない）。
	var source := FileAccess.get_file_as_string("res://scripts/local_race_controller.gd")
	assert_true(source.contains('bind_button_sound(_result_return_button, "confirmation")'))
	assert_true(source.contains('bind_button_sound(_result_retry_button, "confirmation")'))


func test_only_the_players_pururin_has_a_ground_marker_under_it() -> void:
	var race := _race()
	var player: Node3D = race.get("_player")
	for runner: Node3D in race.call("get_runners_for_simulation"):
		var marker := runner.get_node_or_null("PlayerGroundMarker") as MeshInstance3D
		if runner == player:
			assert_not_null(marker)
			# 足元の、地面のすぐ上。体（半径0.75m）より外に、輪がある。体の中の節ではないので、一人称でも消えない。
			assert_almost_eq(marker.position.y, PlayerGroundMarker.HEIGHT_M, 0.0001)
			assert_gt(PlayerGroundMarker.RING_INNER_M, 0.75)
			var bounds := marker.mesh.get_aabb()
			assert_almost_eq(bounds.size.y, 0.0, 0.0001, "平ら")
			assert_almost_eq(bounds.end.x, PlayerGroundMarker.RING_OUTER_M, 0.001)
			assert_eq(marker.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		else:
			assert_null(marker)
	# 明るさは、決めた範囲の中で脈を打つ。
	for step in 20:
		var alpha := PlayerGroundMarker.alpha_at(float(step) * 0.1)
		assert_between(alpha, PlayerGroundMarker.ALPHA_MIN, PlayerGroundMarker.ALPHA_MAX)


func test_the_ground_marker_shows_notch_heart_and_stamina() -> void:
	var race := _race()
	var player: Node3D = race.get("_player")
	var marker := player.get_node("PlayerGroundMarker") as MeshInstance3D
	var arrows := marker.get_node(PlayerGroundMarker.ARROWS_NAME) as MeshInstance3D
	var heart_min := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var heart_max := LocalRaceMath.Config.number("heart_rate_overheat_max_bpm")
	var heart_state := {"heart_min_bpm": heart_min, "heart_normal_max_bpm": LocalRaceMath.Config.number("heart_rate_normal_max_bpm"), "heart_max_bpm": heart_max}
	# 矢じりの数は、ノッチの数。ノッチ0では、出さない。
	for notch in int(LocalRaceMath.DRIVE_LEVEL_MAX) + 1:
		marker.call("show_state", notch, heart_min, 1.0, 0.0)
		assert_eq(PlayerGroundMarker.arrow_count_for(notch), notch)
		if notch == 0:
			assert_null(arrows.mesh)
		else:
			assert_eq(arrows.mesh.get_faces().size(), notch * 3, "ノッチ %d" % notch)
	assert_eq(PlayerGroundMarker.arrow_count_for(-2), 0, "ブレーキ側のノッチでは、出さない")
	# 回る速さは、心拍が高いほど速い（下限と上限の間）。
	assert_almost_eq(PlayerGroundMarker.turn_speed_for(heart_min, heart_min, heart_max), PlayerGroundMarker.TURN_MIN_DEG_PER_S, 0.0001)
	assert_almost_eq(PlayerGroundMarker.turn_speed_for(heart_max + 50.0, heart_min, heart_max), PlayerGroundMarker.TURN_MAX_DEG_PER_S, 0.0001)
	assert_gt(PlayerGroundMarker.turn_speed_for(180.0, heart_min, heart_max), PlayerGroundMarker.turn_speed_for(120.0, heart_min, heart_max))
	# 色：輪は体力の色、矢じりは心拍の色（操作盤と同じ色に、少し白を混ぜたもの）。最初の1回は、そのままの色で出る。
	var fresh: MeshInstance3D = MeshInstance3D.new()
	fresh.set_script(PlayerGroundMarker)
	add_child_autofree(fresh)
	heart_state["heart_bpm"] = heart_max
	fresh.call("show_state", 3, heart_max, 0.2, 0.0)
	var ring_color := (fresh.material_override as StandardMaterial3D).albedo_color
	var arrow_color := ((fresh.get_node(PlayerGroundMarker.ARROWS_NAME) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	var expected_ring := PlayerGroundMarker.soft_color(RaceHud.fuel_color(0.2))
	var expected_arrow := PlayerGroundMarker.soft_color(RaceHud.heart_color(heart_state))
	assert_almost_eq(ring_color.r, expected_ring.r, 0.001)
	assert_almost_eq(ring_color.g, expected_ring.g, 0.001)
	assert_almost_eq(arrow_color.r, expected_arrow.r, 0.001)
	assert_almost_eq(arrow_color.b, expected_arrow.b, 0.001)
	# そのあとは、色を急に変えない（なめらかに近づける）。
	fresh.call("show_state", 3, heart_max, 1.0, 1.0 / 60.0)
	var next_ring := (fresh.material_override as StandardMaterial3D).albedo_color
	var target_ring := PlayerGroundMarker.soft_color(RaceHud.fuel_color(1.0))
	assert_gt(absf(next_ring.r - target_ring.r) + absf(next_ring.g - target_ring.g) + absf(next_ring.b - target_ring.b), 0.01)

