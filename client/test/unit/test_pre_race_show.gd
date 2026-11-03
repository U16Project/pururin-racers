extends GutTest
## スタート前の見せ方（レース場を上から → パドック（周回と紹介）→ 本馬場入場（全員でゲートへ歩いて、枠に入る）→ ゲートイン）。

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
	var guard := 0
	while left > 0.0 and is_instance_valid(show) and bool(show.call("is_running")) and guard < 5000:
		guard += 1
		# 写しの体も、同じだけ動かす（写しは、跳ねている間だけ前へ進むため）。
		for copy: Node in (show.get("_copies") as Array) + (show.get("_entry") as Array):
			copy._process(step)
		# 場面の見出しを出している間は、場面の時計が止まるので、その分は数えない。
		var titled := bool(show.call("is_showing_title"))
		show._process(step)
		if not titled:
			left -= step


func test_the_show_runs_in_order_and_holds_the_countdown_until_it_ends() -> void:
	var race := _race()
	var show: Node = race.get("_pre_race_show")
	assert_not_null(show, "画面のあるレースでは、見せ方から")
	# 見せ方の間は、ノッチを動かせない。
	var player: Node3D = race.get("_player")
	assert_false(bool(player.get("pre_start_input")), "見せ方の間は、ノッチを選べない")
	show.set("may_finish", func() -> bool: return true)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_OVERVIEW)
	# 見せ方の間は、入場の待ちもカウントダウンも進まない。
	race.call("_update_before_start", 60.0)
	assert_false(bool(race.get("_countdown_begun")))
	_advance(show, PreRaceShow.OVERVIEW_S + 0.05)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_PADDOCK)
	# パドック：歩くのは体の写し。本物の走者は、ゲートの位置のまま隠しておく（会場を写す間から、ゲートは空）。
	var runners: Array = race.get("_runners")
	var runner: Node3D = runners[0]
	var at_gate := runner.global_position
	assert_false(runner.visible, "会場を写す間、ゲートは空")
	var copy: Node3D = (show.get("_copies") as Array)[0]
	var paddock_start := copy.global_position
	var paddock_s: float = show.call("_paddock_seconds")
	_advance(show, paddock_s * 0.5)
	assert_false(runner.visible)
	assert_eq(runner.global_position, at_gate)
	assert_ne(copy.global_position, paddock_start, "パドックを周回している")
	assert_true((show.get("_card") as Control).visible, "パドックで、紹介の札を出す")
	_advance(show, paddock_s * 0.5)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_INTRO)
	# 本馬場入場：全員が、もうコースの上を歩いている（急に出てこない）。着いた順に、本物の走者が出る。
	assert_eq((show.get("_entry") as Array).size(), runners.size(), "全員が一度に歩いている")
	for walker: Node3D in show.get("_entry"):
		assert_gt(walker.global_position.distance_to((walker.get_meta("runner") as Node3D).global_position), PreRaceShow.ENTRY_BACK_MIN_M - 3.0, "枠の後ろのほうから歩いてくる（入場が始まった同じコマで、少し進むことがある）")
	# 歩き方は、跳ねる・ゆっくり・少し止まる、が混ざるので、着くまでの秒数は決まっていない。着くまで進める（上限つき）。
	var waited := 0.0
	while not bool(show.call("is_at_lineup")) and waited < 60.0:
		_advance(show, 0.5)
		waited += 0.5
	assert_true(bool(show.call("is_at_lineup")), "全員が枠に着く")
	for each: Node3D in runners:
		assert_true(each.visible, "全員が並んでいる")
	# カメラが前まで回り終えたら、終わる。
	_advance(show, PreRaceShow.SWEEP_S + PreRaceShow.LINEUP_MIN_S)
	assert_false(is_instance_valid(show) and bool(show.call("is_running")), "並んで、カメラが回り終えたら終わる")
	assert_null(race.get("_pre_race_show"))
	assert_true(bool(player.get("pre_start_input")), "見せ方が終わったら、ノッチを選べる")
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


func test_a_free_race_waits_in_the_paddock_with_only_my_pururin_then_joins_everyone() -> void:
	var OnlineSession := load("res://scripts/online/online_session.gd")
	var RaceScenePreload := load("res://scripts/race_scene_preload.gd")
	var ids: Array = RaceSession.roster_ids()
	OnlineSession.peer_id = 9
	RaceSession.set_online_entries([{"gate": 0, "id": ids[0], "runner_id": ids[0], "player": true, "peer_id": 9, "trainer_id": "kaede", "trainer_name": "自分"}])
	RaceSession.set_online_view(9)
	RaceScenePreload._paddock_mode = RaceScenePreload.PADDOCK_FREE_WAIT
	var race: Node = LocalRaceScene.instantiate()
	race.set("_online_host", false)
	add_child_autofree(race)
	# 待っている間：自分のぷるりんだけ。パドックで止まって待つ（先へ進まない）。
	assert_true(bool(race.get("_free_waiting")))
	assert_eq((race.get("_runners") as Array).size(), 1)
	var show: Node = race.get("_pre_race_show")
	assert_true(bool(show.get("hold_paddock")))
	# そろったら、画面はそのまま、届いた出走で走者を並べ直す（会場を読み直さない）。
	var entries := []
	for gate in 8:
		var mine := gate == 5
		entries.append({"gate": gate, "id": ids[0] if mine else ids[(gate + 1) % ids.size()], "runner_id": ids[0] if mine else "%s#%d" % [ids[(gate + 1) % ids.size()], gate], "player": mine, "peer_id": 9 if mine else 0, "trainer_id": "kaede", "trainer_name": "自分" if mine else "カエデ"})
	race.call("_start_free_race", {"t": "race_start", "distance_m": RaceSession.selected_distance_m(), "entries": entries, "free_room_id": ""})
	assert_false(bool(race.get("_free_waiting")))
	assert_eq((race.get("_runners") as Array).size(), 8)
	assert_eq(int((race.get("_player") as Node3D).get("gate_index")), 5, "自分は、決まった枠")
	assert_eq(race.get("_pre_race_show"), show, "見せ方は、そのまま続く")
	# 呼び出しが取りやめになったら、ロビーへ戻る（レースには出ていないので、結果の選びは送らない）。
	race.set("_free_waiting", true)
	race.set("_online_left", false)
	race.call("_on_free_waiting_message", {"t": "free_offer_end"})
	assert_true(bool(race.get("_online_left")))
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	OnlineSession.peer_id = 0


## 重ねている出走表の数（片づけ待ちのものは数えない）。
func _overlay_count(race: Node) -> int:
	var count := 0
	for child: Node in race.get_node("UI").get_children():
		if child.get_script() == preload("res://scripts/race_entries.gd") and not child.is_queued_for_deletion():
			count += 1
	return count


func test_a_free_race_that_fills_before_the_paddock_shows_one_list_only() -> void:
	var OnlineSession := load("res://scripts/online/online_session.gd")
	var RaceScenePreload := load("res://scripts/race_scene_preload.gd")
	var ids: Array = RaceSession.roster_ids()
	OnlineSession.peer_id = 9
	RaceSession.set_online_entries([{"gate": 0, "id": ids[0], "runner_id": ids[0], "player": true, "peer_id": 9, "trainer_id": "kaede", "trainer_name": "自分"}])
	RaceSession.set_online_view(9)
	RaceScenePreload._paddock_mode = RaceScenePreload.PADDOCK_FREE_WAIT
	var race: Node = LocalRaceScene.instantiate()
	race.set("_online_host", false)
	add_child_autofree(race)
	var show: Node = race.get("_pre_race_show")
	show.set("may_finish", func() -> bool: return true)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_OVERVIEW)
	# まだ会場を写している間に、出走者がそろう。
	var entries := []
	for gate in 8:
		var mine := gate == 2
		entries.append({"gate": gate, "id": ids[0] if mine else ids[(gate + 1) % ids.size()], "runner_id": ids[0] if mine else "%s#%d" % [ids[(gate + 1) % ids.size()], gate], "player": mine, "peer_id": 9 if mine else 0, "trainer_id": "kaede", "trainer_name": "自分" if mine else "カエデ"})
	race.call("_start_free_race", {"t": "race_start", "distance_m": RaceSession.selected_distance_m(), "entries": entries, "free_room_id": ""})
	assert_eq(_overlay_count(race), 0, "パドックに着くまでは、出走表を出さない")
	_advance(show, PreRaceShow.OVERVIEW_S + 0.05)
	assert_eq(int(show.get("_stage")), PreRaceShow.STAGE_PADDOCK)
	assert_eq(_overlay_count(race), 1, "出走表は1枚だけ")
	# パドックを出たら、出走表は残らない。
	show.call("release_paddock")
	show._process(0.1)
	assert_eq(_overlay_count(race), 0, "レースまで残らない")
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	OnlineSession.peer_id = 0


func test_the_top_bar_says_which_race_this_is() -> void:
	var race := _race()
	var label: Dictionary = race.call("race_label")
	var distance := RaceSession.selected_distance_m()
	assert_eq(label["kind"][0], "オフラインフリー対戦")
	# 距離は、区分の名前（設定）と、m の数字。
	var category: String = load("res://scripts/config/local_race_config.gd").distance_name(distance)
	assert_false(category.is_empty(), "対応している距離には、区分の名前がある")
	assert_eq(label["title"], "%s　%dm" % [category, int(distance)])
	var show: Node = race.get("_pre_race_show")
	assert_eq((show.get("_title") as Label).text, label["title"])
