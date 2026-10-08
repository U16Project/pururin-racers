extends GutTest
## レース中の表情：走者の状態から表情を選ぶ決まりと、走者の体への反映。

const RaceExpression := preload("res://scripts/presentation/race_expression.gd")
const RaceAction := preload("res://scripts/presentation/race_action.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LookConfig := preload("res://scripts/config/pururin_look_config.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func _state(overrides: Dictionary = {}) -> Dictionary:
	var state := {
		"finished": false, "finish_order": -1, "in_push_contest": false, "lost_push": false, "contact_count": 0,
		"stamina": 1.0, "heart_bpm": 120.0, "heart_normal_max_bpm": 195.0, "draft_reduction": 0.0,
	}
	state.merge(overrides, true)
	return state


func test_every_expression_the_race_uses_is_in_the_list_of_expression_names() -> void:
	var names: Array = LookConfig.values()["expression_names"]
	var cases := [
		_state(), _state({"finished": true, "finish_order": 1}), _state({"finished": true, "finish_order": 2}),
		_state({"in_push_contest": true}), _state({"in_push_contest": true, "lost_push": true}),
		_state({"contact_count": 1}), _state({"stamina": -0.1}), _state({"draft_reduction": 1.0}),
	]
	var seen := {}
	for state: Dictionary in cases:
		var name := RaceExpression.wanted(state)
		assert_true(name in names, name)
		seen[name] = true
	# 一覧にある表情は、どれもレースのどこかで出る。
	for name: String in names:
		assert_true(seen.has(name), "%s が、レースで出る" % name)


func test_expression_follows_the_runner_state_in_priority_order() -> void:
	assert_eq(RaceExpression.wanted(_state()), RaceExpression.NORMAL)
	# ドラフトで楽をしている。
	assert_eq(RaceExpression.wanted(_state({"draft_reduction": RaceExpression.RELAX_DRAFT_REDUCTION})), "relax")
	assert_eq(RaceExpression.wanted(_state({"draft_reduction": RaceExpression.RELAX_DRAFT_REDUCTION - 0.01})), RaceExpression.NORMAL)
	# 疲れ（体力がマイナス、または心拍が上限ごえ）は、楽より優先。
	assert_eq(RaceExpression.wanted(_state({"stamina": -0.01, "draft_reduction": 1.0})), "sorrow")
	assert_eq(RaceExpression.wanted(_state({"heart_bpm": 196.0, "heart_normal_max_bpm": 195.0})), "sorrow")
	assert_eq(RaceExpression.wanted(_state({"heart_bpm": 195.0, "heart_normal_max_bpm": 195.0})), RaceExpression.NORMAL)
	# 接触は、疲れより優先。押し合いは、接触より優先。
	assert_eq(RaceExpression.wanted(_state({"contact_count": 1, "stamina": -1.0})), "anger")
	assert_eq(RaceExpression.wanted(_state({"in_push_contest": true, "contact_count": 1})), "push_win")
	assert_eq(RaceExpression.wanted(_state({"in_push_contest": true, "lost_push": true})), "push_lose")
	# ゴールしたら、ゴールの顔が最優先。
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": 1, "in_push_contest": true})), "first_place")
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": RaceExpression.JOY_MAX_ORDER})), "joy")
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": RaceExpression.JOY_MAX_ORDER + 1})), RaceExpression.NORMAL)
	# 6位以下でゴールしたら、哀の顔。その手前（4・5位）は、ノーマル。
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": RaceExpression.SORROW_MIN_ORDER - 1})), RaceExpression.NORMAL)
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": RaceExpression.SORROW_MIN_ORDER})), "sorrow")
	assert_eq(RaceExpression.wanted(_state({"finished": true, "finish_order": RaceExpression.SORROW_MIN_ORDER + 2, "draft_reduction": 1.0})), "sorrow")


func test_expression_is_kept_for_a_moment_so_it_does_not_flicker() -> void:
	var hold := RaceExpression.MIN_SHOW_SECONDS
	assert_eq(RaceExpression.next("anger", "normal", hold * 0.5, false), "anger")
	assert_eq(RaceExpression.next("anger", "normal", hold, false), "normal")
	assert_eq(RaceExpression.next("anger", "anger", 0.0, false), "anger")
	# ゴールの顔は、待たずに替える。
	assert_eq(RaceExpression.next("anger", "first_place", 0.0, true), "first_place")


func test_the_loser_of_a_push_is_the_one_with_lower_contact_resistance() -> void:
	var gap := LocalRaceMath.required_lateral_gap(0.0)
	var strong := {"id": "A", "progress": 100.0, "offset": 0.0, "old_offset": 0.0, "stat": 8}
	var weak := {"id": "B", "progress": 100.0, "offset": gap * 0.5, "old_offset": gap * 0.5, "stat": 3}
	var result := LocalRaceMath.resolve_lateral_pushes([strong, weak])
	assert_eq(result["lost_ids"], ["B"])
	assert_true("A" in result["contest_ids"] and "B" in result["contest_ids"])
	# 接触耐性が同じなら、どちらも負けではない（両方が頑張っている顔になる）。
	var even: Dictionary = weak.duplicate()
	even["stat"] = strong["stat"]
	assert_eq(LocalRaceMath.resolve_lateral_pushes([strong, even])["lost_ids"], [])


func test_a_runner_shows_the_expression_on_its_body() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var runner: Node3D = (race.call("get_runners_for_simulation") as Array)[0]
	var body := runner.get_node("Body") as Node3D
	var hold := RaceExpression.MIN_SHOW_SECONDS
	assert_eq(body.call("expression"), RaceExpression.NORMAL)
	# 押し合いで負けている。
	runner.call("apply_push_result", float(runner.call("get_offset")), true, true)
	runner.call("_update_expression", hold)
	assert_eq(body.call("expression"), "push_lose")
	# 押し合いが終わっても、すぐには戻さない。決まった時間がたったら、戻す。
	runner.call("apply_push_result", float(runner.call("get_offset")), false, false)
	runner.call("_update_expression", hold * 0.5)
	assert_eq(body.call("expression"), "push_lose")
	runner.call("_update_expression", hold * 0.5)
	assert_eq(body.call("expression"), RaceExpression.NORMAL)
	# 1位でゴールしたら、すぐに1位の顔。
	runner.call("mark_finished", 1, 100.0)
	runner.call("_update_expression", 0.0)
	assert_eq(body.call("expression"), "first_place")


func _action_state(overrides: Dictionary = {}) -> Dictionary:
	var state := {
		"race_active": true, "finished": false, "finish_order": -1, "in_push_contest": false, "contact_count": 0,
		"braking": false, "dashing": false, "tired": false,
	}
	state.merge(overrides, true)
	return state


func test_every_action_the_race_uses_is_in_the_list_of_action_names() -> void:
	var names: Array = LookConfig.values()["action_names"]
	var seen := {}
	for state: Dictionary in [
		_action_state(), _action_state({"race_active": false}), _action_state({"in_push_contest": true}),
		_action_state({"contact_count": 1}), _action_state({"braking": true}), _action_state({"dashing": true}),
		_action_state({"tired": true}), _action_state({"finished": true, "finish_order": 1}),
		_action_state({"finished": true, "finish_order": RaceAction.GOAL_PLACE_MAX_ORDER}),
		_action_state({"finished": true, "finish_order": RaceAction.GOAL_PLACE_MAX_ORDER + 1}),
	]:
		var name := RaceAction.wanted(state)
		assert_true(name in names, name)
		seen[name] = true
	# 一覧にあるアクションは、レースで出るか、レース選択画面の絵で使う。
	seen[Portrait.SHOWCASE_ACTION] = true
	for name: String in names:
		assert_true(seen.has(name), "%s が、どこかで出る" % name)
	# 1回だけの動きの名前も、どの体の動かし方にも入っている。
	for body_motion: Dictionary in (LookConfig.values()["body_motions"] as Dictionary).values():
		assert_true((body_motion["one_shots"] as Dictionary).has(RaceAction.LAUNCH_ONE_SHOT))
		assert_true((body_motion["one_shots"] as Dictionary).has(Portrait.SHOWCASE_ONE_SHOT))


func test_action_follows_the_runner_state_in_priority_order() -> void:
	assert_eq(RaceAction.wanted(_action_state()), "run")
	assert_eq(RaceAction.wanted(_action_state({"race_active": false})), "ready")
	# 疲れ < ダッシュ < ブレーキ < 接触 < 押し合い < ゴール の順に、優先する。
	assert_eq(RaceAction.wanted(_action_state({"tired": true})), "tired")
	assert_eq(RaceAction.wanted(_action_state({"tired": true, "dashing": true})), "dash")
	assert_eq(RaceAction.wanted(_action_state({"dashing": true, "braking": true})), "brake")
	assert_eq(RaceAction.wanted(_action_state({"braking": true, "contact_count": 1})), "contact")
	assert_eq(RaceAction.wanted(_action_state({"contact_count": 1, "in_push_contest": true})), "push")
	assert_eq(RaceAction.wanted(_action_state({"finished": true, "finish_order": 1, "in_push_contest": true, "race_active": false})), "goal_win")
	assert_eq(RaceAction.wanted(_action_state({"finished": true, "finish_order": 2})), "goal_place")
	assert_eq(RaceAction.wanted(_action_state({"finished": true, "finish_order": RaceAction.GOAL_PLACE_MAX_ORDER + 1})), "goal")


func test_run_motion_gets_faster_with_speed_within_limits() -> void:
	assert_almost_eq(RaceAction.rate("run", RaceAction.RUN_REFERENCE_KMH), 1.0, 0.0001)
	assert_almost_eq(RaceAction.rate("run", RaceAction.RUN_REFERENCE_KMH * 1.2), 1.2, 0.0001)
	assert_almost_eq(RaceAction.rate("run", 0.0), RaceAction.RUN_RATE_MIN, 0.0001)
	assert_almost_eq(RaceAction.rate("run", RaceAction.RUN_REFERENCE_KMH * 10.0), RaceAction.RUN_RATE_MAX, 0.0001)
	# 走る以外は、速さに合わせない。
	assert_almost_eq(RaceAction.rate("goal_win", RaceAction.RUN_REFERENCE_KMH * 1.5), 1.0, 0.0001)


func test_the_body_leans_toward_its_sideways_move_and_into_the_curve() -> void:
	assert_almost_eq(RaceAction.steer(0.0, 0.0), 0.0, 0.0001)
	# 右へ動けば右へ（＋）、左へ動けば左へ。
	assert_almost_eq(RaceAction.steer(RaceAction.STEER_FULL_LATERAL_MPS * 0.5, 0.0), 0.5, 0.0001)
	assert_almost_eq(RaceAction.steer(-RaceAction.STEER_FULL_LATERAL_MPS, 0.0), -1.0, 0.0001)
	# 左へ曲がるカーブ（＋）では、内側＝左へ（−）。
	assert_almost_eq(RaceAction.steer(0.0, RaceAction.STEER_FULL_TURN_RAD_PER_S), -RaceAction.STEER_TURN_SHARE, 0.0001)
	assert_gt(RaceAction.steer(0.0, -RaceAction.STEER_FULL_TURN_RAD_PER_S), 0.0)
	# 大きすぎても、−1〜1に収める。
	assert_almost_eq(RaceAction.steer(RaceAction.STEER_FULL_LATERAL_MPS * 5.0, 0.0), 1.0, 0.0001)


func test_a_runner_sets_the_action_on_its_body() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var runner: Node3D = (race.call("get_runners_for_simulation") as Array)[0]
	var body := runner.get_node("Body") as Node3D
	var tick := 1.0 / 60.0
	# スタート前は、構える。走り出した瞬間に、飛び出しの動きを1回出して、走る。
	runner.call("_update_action", tick)
	assert_eq(body.call("action"), "ready")
	assert_eq(body.call("playing_once"), "")
	runner.call("set_race_active", true)
	runner.call("_update_action", tick)
	assert_eq(body.call("action"), "run")
	assert_eq(body.call("playing_once"), RaceAction.LAUNCH_ONE_SHOT)
	# 接触、押し合い、ゴール。
	runner.call("apply_contact_count", 1)
	runner.call("_update_action", tick)
	assert_eq(body.call("action"), "contact")
	runner.call("apply_push_result", float(runner.call("get_offset")), true, false)
	runner.call("_update_action", tick)
	assert_eq(body.call("action"), "push")
	runner.call("mark_finished", 1, 100.0)
	runner.call("_update_action", tick)
	assert_eq(body.call("action"), "goal_win")
	# ゴールしたあとは、傾けない。
	body.call("advance_motion", 2.0)
	assert_almost_eq(float(body.call("steer")), 0.0, 0.001)
