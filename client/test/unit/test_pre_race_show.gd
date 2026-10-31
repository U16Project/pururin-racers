extends GutTest
## スタート前の見せ方（レース場を上から → 返し馬 → 1体ずつ紹介 → ゲートに並ぶ）。

const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const PreRaceShow := preload("res://scripts/presentation/pre_race_show.gd")


func _race(server_mode: bool = false) -> Node:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	race.set("_online_host", server_mode)
	add_child_autofree(race)
	return race


## 見せ方を、準備が終わったことにして、その秒数だけ進める。
func _advance(show: Node, seconds: float) -> void:
	var step := 0.1
	var left := seconds
	while left > 0.0 and is_instance_valid(show) and bool(show.call("is_running")):
		show._process(step)
		left -= step


func test_the_show_runs_in_order_and_holds_the_countdown_until_it_ends() -> void:
	var race := _race()
	var show: Node = race.get("_pre_race_show")
	assert_not_null(show, "画面のあるレースでは、見せ方から")
	show.set("may_finish", func() -> bool: return true)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_OVERVIEW)
	# 見せ方の間は、入場の待ちもカウントダウンも進まない。
	race.call("_update_before_start", 60.0)
	assert_false(bool(race.get("_countdown_begun")))
	_advance(show, PreRaceShow.OVERVIEW_S + 0.05)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_WARMUP)
	# 返し馬：走るのは体の写し。本物の走者は、ゲートに並んだまま（隠すだけ）。
	var runner: Node3D = (race.get("_runners") as Array)[0]
	var at_gate := runner.global_position
	_advance(show, PreRaceShow.WARMUP_S * 0.5)
	assert_false(runner.visible)
	assert_eq(runner.global_position, at_gate)
	_advance(show, PreRaceShow.WARMUP_S * 0.5)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_INTRO)
	assert_true(runner.visible)
	var runner_count := (race.get("_runners") as Array).size()
	_advance(show, PreRaceShow.INTRO_PER_RUNNER_S * runner_count)
	assert_true(bool(show.call("is_at_lineup")))
	_advance(show, PreRaceShow.LINEUP_MIN_S + 0.2)
	assert_false(is_instance_valid(show) and bool(show.call("is_running")), "並んだら終わる")
	assert_null(race.get("_pre_race_show"))
	# 終わったら、いつもの入場の待ち → カウントダウン。
	race.call("_update_before_start", 0.0)
	assert_false(bool(race.get("_countdown_begun")))


func test_skipping_goes_to_the_lineup_and_waits_for_the_preparation() -> void:
	var race := _race()
	var show: Node = race.get("_pre_race_show")
	# 中で書き換えられるように、入れ物に入れて渡す（関数は、作ったときの値を覚えるため）。
	var prepared := {"done": false}
	show.set("may_finish", func() -> bool: return bool(prepared["done"]))
	show.call("skip")
	assert_true(bool(show.call("is_at_lineup")), "飛ばすと、並んだ所へ")
	show._process(0.1)
	assert_true(bool(show.call("is_running")), "準備が終わるまでは、並んで待つ")
	prepared["done"] = true
	show._process(0.1)
	assert_false(is_instance_valid(show) and bool(show.call("is_running")), "準備が終わったら、すぐ終わる")


func test_a_server_or_lab_race_has_no_show() -> void:
	var race := _race(true)
	assert_null(race.get("_pre_race_show"))
