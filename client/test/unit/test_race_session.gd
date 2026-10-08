extends GutTest

const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())


func test_supported_distances_are_the_five_course_routes() -> void:
	assert_eq(RaceSession.supported_distances_m(), [1200.0, 1600.0, 2000.0, 2400.0, 3000.0])


func test_selection_keeps_only_defined_routes_and_falls_back_to_2000m() -> void:
	assert_eq(RaceSession.select_distance(1600.0), 1600.0)
	assert_eq(RaceSession.selected_distance_m(), 1600.0)
	assert_eq(RaceSession.select_distance(1700.0), 2000.0)


func test_local_runner_uses_selected_distance_and_route_goal() -> void:
	RaceSession.select_distance(1600.0)
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	assert_eq(player.call("get_race_distance"), 1600.0)
	assert_almost_eq(player.call("get_race_progress"), 0.0, 0.001)
	assert_almost_eq(player.call("get_distance"), 1043.1, 0.2)
	assert_true(LocalRaceMath.has_finished(1600.0, player.call("get_race_distance")))
	race.free()


func test_local_race_uses_the_selected_roster_entry_as_the_only_player() -> void:
	RaceSession.select_full_field("cpu-1")
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var runners: Array = race.call("get_runners_for_simulation")
	var expected_cpu_ids: Array[String] = []
	for pururin: Dictionary in PururinRosterConfig.values()["roster"]:
		if str(pururin["id"]) != "cpu-1":
			expected_cpu_ids.append(str(pururin["id"]))
	for gate in runners.size():
		var runner: Node = runners[gate]
		var snapshot: Dictionary = runner.call("get_snapshot")
		assert_eq(snapshot["gate"], gate)
		if gate == 0:
			assert_true(snapshot["player"])
			assert_eq(snapshot["id"], "cpu-1")
		else:
			var expected_id := expected_cpu_ids[gate - 1]
			assert_false(snapshot["player"])
			assert_eq(snapshot["id"], expected_id)
			var expected_pururin := PururinRosterConfig.pururin_by_id(expected_id)
			assert_eq(
				runner.get("_cpu_trainer_profile")["id"],
				expected_pururin["trainer_profile_id"]
			)
	race.free()


func test_runner_setup_does_not_change_the_selected_distance() -> void:
	RaceSession.select_distance(1600.0)
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "テスト", {}, 2400.0)
	assert_eq(float(runner.call("get_race_distance")), 2400.0)
	assert_eq(RaceSession.selected_distance_m(), 1600.0)
	runner.free()


func test_every_slot_is_empty_and_unlocked_and_the_user_is_in_gate_one_at_first() -> void:
	RaceSession.clear_slots()
	assert_eq(RaceSession.SLOT_COUNT, LocalRaceMath.FIELD_SIZE)
	assert_eq(RaceSession.user_slot(), 0)
	assert_eq(RaceSession.selected_player_pururin_id(), RaceSession.EMPTY)
	assert_eq(RaceSession.selected_opponent_ids().size(), 0)
	assert_eq(RaceSession.field_entries().size(), 0)
	for slot in RaceSession.SLOT_COUNT:
		assert_false(RaceSession.is_locked(slot))
	assert_eq(RaceSession.race_start_problem(), "no_player")


func test_a_race_needs_the_user_and_at_least_one_opponent() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	assert_true(RaceSession.set_slot(RaceSession.user_slot(), ids[0]))
	assert_eq(RaceSession.race_start_problem(), "no_opponent")
	assert_true(RaceSession.set_slot(3, ids[1]))
	assert_eq(RaceSession.race_start_problem(), "")
	assert_eq(RaceSession.selected_player_pururin_id(), ids[0])
	assert_eq(RaceSession.selected_opponent_ids(), [ids[1]] as Array[String])


func test_a_slot_refuses_unknown_and_already_used_pururin_without_changing() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	assert_false(RaceSession.set_slot(1, ids[0]), "他のスロットで使っている個体は入れない")
	assert_false(RaceSession.set_slot(1, "unknown"), "一覧に無い個体は入れない")
	assert_eq(RaceSession.slot_pururin_id(1), RaceSession.EMPTY)
	assert_false(RaceSession.set_slot(RaceSession.SLOT_COUNT, ids[1]))
	assert_true(RaceSession.set_slot(1, ids[1]))
	assert_true(RaceSession.set_slot(1, RaceSession.EMPTY))
	assert_eq(RaceSession.slot_pururin_id(1), RaceSession.EMPTY)


func test_cycling_goes_through_empty_and_the_whole_roster_without_skipping() -> void:
	var ids := RaceSession.roster_ids()
	assert_eq(RaceSession.cycle_candidate(RaceSession.EMPTY, 1), ids[0], "未選択の次は、一覧の1番目")
	assert_eq(RaceSession.cycle_candidate(RaceSession.EMPTY, -1), ids[ids.size() - 1], "未選択の前は、一覧の最後")
	assert_eq(RaceSession.cycle_candidate(ids[ids.size() - 1], 1), RaceSession.EMPTY, "最後の次は、未選択")
	var current := RaceSession.EMPTY
	var seen := {}
	for _step in ids.size() + 1:
		current = RaceSession.cycle_candidate(current, 1)
		seen[current] = true
	assert_eq(seen.size(), ids.size() + 1, "使っているかどうかに関係なく、全部の個体と未選択が出る")


func test_slot_holding_tells_which_slot_uses_a_pururin() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	RaceSession.set_slot(4, ids[3])
	assert_eq(RaceSession.slot_holding(ids[0]), 0)
	assert_eq(RaceSession.slot_holding(ids[3]), 4)
	assert_eq(RaceSession.slot_holding(ids[5]), -1)
	assert_eq(RaceSession.slot_holding(RaceSession.EMPTY), -1)


func test_taking_a_pururin_empties_the_slot_that_held_it() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	RaceSession.set_slot(4, ids[3])
	assert_true(RaceSession.take_slot(2, ids[3]), "CPUのスロットから奪う")
	assert_eq(RaceSession.slot_pururin_id(2), ids[3])
	assert_eq(RaceSession.slot_pururin_id(4), RaceSession.EMPTY)
	assert_true(RaceSession.take_slot(2, ids[0]), "ユーザーのスロットから奪う")
	assert_eq(RaceSession.selected_player_pururin_id(), RaceSession.EMPTY)
	assert_eq(RaceSession.race_start_problem(), "no_player")
	assert_false(RaceSession.take_slot(2, "unknown"))
	assert_eq(RaceSession.slot_pururin_id(2), ids[0])


func test_moving_a_slot_swaps_it_with_its_neighbour_and_carries_user_and_lock() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	RaceSession.set_slot(1, ids[1])
	RaceSession.toggle_lock(0)
	assert_eq(RaceSession.move_slot(0, 1), 1, "下の枠へ")
	assert_eq(RaceSession.user_slot(), 1)
	assert_eq(RaceSession.slot_pururin_id(1), ids[0])
	assert_eq(RaceSession.slot_pururin_id(0), ids[1])
	assert_true(RaceSession.is_locked(1), "施錠も一緒に動く")
	assert_false(RaceSession.is_locked(0))
	# CPUのスロットを動かして、ユーザーのスロットと入れ替わる場合。
	assert_eq(RaceSession.move_slot(0, 1), 1)
	assert_eq(RaceSession.user_slot(), 0)
	assert_eq(RaceSession.slot_pururin_id(0), ids[0])
	# 端では動かない。
	assert_eq(RaceSession.move_slot(0, -1), 0)
	assert_eq(RaceSession.move_slot(RaceSession.SLOT_COUNT - 1, 1), RaceSession.SLOT_COUNT - 1)
	assert_eq(RaceSession.user_slot(), 0)


func test_a_locked_slot_refuses_every_change_of_its_pururin() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	RaceSession.set_slot(1, ids[1])
	assert_true(RaceSession.toggle_lock(1))
	assert_false(RaceSession.set_slot(1, ids[2]), "別の個体にできない")
	assert_false(RaceSession.set_slot(1, RaceSession.EMPTY), "未選択にできない")
	assert_false(RaceSession.take_slot(3, ids[1]), "他のスロットから奪われない")
	assert_false(RaceSession.take_slot(1, ids[0]), "施錠中のスロットは、奪うこともできない")
	assert_eq(RaceSession.slot_pururin_id(1), ids[1])
	assert_eq(RaceSession.slot_pururin_id(3), RaceSession.EMPTY)
	assert_false(RaceSession.toggle_lock(1))
	assert_true(RaceSession.set_slot(1, ids[2]), "解錠すれば変えられる")


func test_random_selection_fills_only_unlocked_slots_and_avoids_locked_pururin() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(2, ids[4])
	RaceSession.toggle_lock(2)
	RaceSession.randomize_unlocked()
	assert_eq(RaceSession.slot_pururin_id(2), ids[4], "施錠中は変わらない")
	var seen := {}
	for slot in RaceSession.SLOT_COUNT:
		var identifier := RaceSession.slot_pururin_id(slot)
		if identifier != RaceSession.EMPTY:
			assert_false(seen.has(identifier), "重複しない")
			seen[identifier] = true
	assert_eq(seen.size(), mini(RaceSession.SLOT_COUNT, ids.size()), "ユーザーのスロットも含めて、埋まる")
	assert_ne(RaceSession.selected_player_pururin_id(), RaceSession.EMPTY)


func test_clear_all_empties_only_unlocked_slots() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.select_full_field(ids[0])
	RaceSession.toggle_lock(3)
	var kept := RaceSession.slot_pururin_id(3)
	RaceSession.clear_unlocked()
	for slot in RaceSession.SLOT_COUNT:
		assert_eq(RaceSession.slot_pururin_id(slot), kept if slot == 3 else RaceSession.EMPTY)
	assert_eq(RaceSession.selected_player_pururin_id(), RaceSession.EMPTY, "施錠していなければ、ユーザーも解除される")


func test_gate_order_shuffle_keeps_every_slot_with_its_user_mark_and_lock() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.select_full_field(ids[0])
	RaceSession.toggle_lock(5)
	var locked_id := RaceSession.slot_pururin_id(5)
	for _attempt in 5:
		RaceSession.shuffle_gate_order()
		assert_eq(RaceSession.selected_player_pururin_id(), ids[0], "ユーザーの個体は、ユーザーのスロットと一緒に動く")
		assert_true(RaceSession.is_locked(RaceSession.slot_holding(locked_id)), "施錠も一緒に動く")
		var locks := 0
		var seen := {}
		for slot in RaceSession.SLOT_COUNT:
			seen[RaceSession.slot_pururin_id(slot)] = true
			locks += 1 if RaceSession.is_locked(slot) else 0
		assert_eq(seen.size(), RaceSession.SLOT_COUNT)
		assert_eq(locks, 1)


func test_full_field_puts_the_player_in_gate_one_and_the_rest_in_roster_order() -> void:
	var ids := RaceSession.roster_ids()
	assert_false(RaceSession.select_full_field("unknown"))
	assert_true(RaceSession.select_full_field(ids[3]))
	assert_eq(RaceSession.user_slot(), 0)
	assert_eq(RaceSession.selected_player_pururin_id(), ids[3])
	var expected: Array[String] = []
	for identifier in ids:
		if identifier != ids[3]:
			expected.append(identifier)
	assert_eq(RaceSession.selected_opponent_ids(), expected)


func test_snapshot_restores_pururin_locks_and_the_user_slot() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[0])
	RaceSession.move_slot(0, 1)
	RaceSession.toggle_lock(1)
	var snapshot := RaceSession.slots_snapshot()
	RaceSession.select_full_field(ids[5])
	RaceSession.restore_slots(snapshot)
	assert_eq(RaceSession.user_slot(), 1)
	assert_eq(RaceSession.selected_player_pururin_id(), ids[0])
	assert_true(RaceSession.is_locked(1))
	assert_eq(RaceSession.slots_snapshot(), snapshot)


func test_local_race_starts_each_pururin_from_its_gate_and_leaves_empty_gates_open() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.clear_slots()
	RaceSession.set_slot(0, ids[4])
	RaceSession.move_slot(0, 1)
	RaceSession.move_slot(1, 1)
	RaceSession.set_slot(6, ids[1])
	RaceSession.set_slot(4, ids[3])
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var runners: Array = race.call("get_runners_for_simulation")
	assert_eq(runners.size(), 3)
	var by_gate := {}
	for runner in runners:
		var snapshot: Dictionary = runner.call("get_snapshot")
		by_gate[int(snapshot["gate"])] = str(snapshot["id"])
		# スタートの位置は、枠の番号どおり（空の枠は、詰めない）。
		assert_almost_eq(float(snapshot["offset"]), LocalRaceMath.starting_offset_for_gate(int(snapshot["gate"])), 0.002)
		assert_eq(bool(runner.get("player_controlled")), str(snapshot["id"]) == ids[4])
	assert_eq(by_gate, {2: ids[4], 4: ids[3], 6: ids[1]})
	race.free()


func test_local_race_does_not_run_when_the_user_slot_is_empty() -> void:
	RaceSession.clear_slots()
	var race := LocalRaceScene.instantiate()
	add_child(race)
	assert_eq((race.call("get_runners_for_simulation") as Array).size(), 0)
	assert_true(race.get_node("UI/HudLabel").visible)
	assert_true(str(race.get_node("UI/HudLabel").text).contains("レース選択"))
	race.free()
