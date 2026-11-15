extends GutTest

const Observe := preload("res://scripts/cpu_brain/brain_observe.gd")
const Trainers := preload("res://scripts/config/cpu_trainers_config.gd")
const Net := preload("res://scripts/cpu_brain/brain_net.gd")

class Runner extends Node3D:
	var progress := 0.0
	var notch := 2.0
	var stamina := 1.0
	var draft := 0.0
	var rear := 0.0
	var contacts := 0
	var _lateral_move_m := 0.0
	var finished := false
	var finish_order := 1
	var finish_time := 10.0
	func get_race_progress() -> float: return progress
	func get_drive_level() -> float: return notch
	func get_stamina_ratio() -> float: return stamina
	func get_contact_count() -> int: return contacts
	func get_draft_status() -> Dictionary: return {"received_draft_p": draft, "rear_assist_air_factor": rear}
	func is_finished() -> bool: return finished
	func get_finish_order() -> int: return finish_order
	func get_finish_time() -> float: return finish_time

var _race
var _runner: Runner

func before_each() -> void:
	# ラボの台本は client プロジェクトの外にある。
	var script = load(ProjectSettings.globalize_path("res://").path_join("../lab/rl/rl_race.gd"))
	_race = script.new()
	add_child_autofree(_race)
	_runner = Runner.new()
	add_child_autofree(_runner)
	_race._spec = {"distance_m": 100.0}
	# 現在の設定の数字から独立した、計算確認専用の重さ。
	_race._settings = {"reward": {
		"personality": {"stick": 2.0, "draft": 3.0, "rear": 4.0, "contact": 5.0,
			"steady_per_change": 0.2, "steady_max": 0.7, "keep": 6.0, "stick_until": 0.8,
			"draft_at_least": 0.4, "keep_at": [0.25, 0.5, 0.75],
			"place_by_style": {"escape": [1, 2], "pace": [3, 4]}},
		"gap_running": {"per_s": 0.0}, "place": [10.0, 4.0], "gap_bonus": 2.0, "gap_scale_s": 5.0,
		"gap_penalty_per_s": 0.3, "gap_penalty_max": 1.2, "progress_total": 0.8,
		"style": {"opening_ratio": 0.1, "opening_per_boost": -3.0, "spurt_last_ratio": 0.25,
			"spurt_per_boost": 2.0, "outside_per_boost": -1.0}}}

func seat() -> Dictionary:
	return {"fit_progress": 0.0, "owed": 0.0, "points": {}, "running_style": "escape",
		"frame": {"stick": 0.5, "draft": 0.5, "rear": 0.5, "contact": -0.5, "steady": 0.5, "keep": 0.5},
		"previous_notch": null, "line_pending": false, "last_progress": 0.0,
		"fit": {"stick_m": 0.0, "draft_m": 0.0, "rear_m": 0.0, "contact_m": 0.0,
			"notch_changes": 0, "line_changes": 0, "keep_stamina": [null, null, null]}}

func count(s: Dictionary, progress: float) -> void:
	_runner.progress = progress
	_race._count_fit(_runner, [_runner], s)

func test_distance_rewards_signs_and_eighty_percent_boundary() -> void:
	var s := seat()
	_runner.draft = 0.4
	_runner.rear = 0.01
	_runner.contacts = 1
	count(s, 40.0)
	assert_almost_eq(float(s.points.stick), 0.5, 0.00001)
	assert_almost_eq(float(s.points.draft), 0.6, 0.00001)
	assert_almost_eq(float(s.points.rear), 0.8, 0.00001)
	assert_almost_eq(float(s.points.contact), -1.0, 0.00001)
	s.running_style = "pace"
	count(s, 100.0)
	assert_almost_eq(float(s.points.stick), 0.0, 0.00001)
	assert_almost_eq(float(s.points.draft), 1.5, 0.00001)
	assert_almost_eq(float(s.fit.stick_m), 40.0, 0.00001)

func test_splitting_distance_does_not_change_continuous_points() -> void:
	var one := seat()
	var split := seat()
	_runner.draft = 0.7
	_runner.contacts = 1
	count(one, 100.0)
	for progress in [5.0, 19.0, 40.0, 79.0, 83.0, 100.0]:
		count(split, progress)
	for key in ["stick", "draft", "rear", "contact", "keep"]:
		assert_almost_eq(float(one.points.get(key, 0.0)), float(split.points.get(key, 0.0)), 0.00001, key)

func test_contact_positive_zero_and_negative_personalities() -> void:
	_runner.contacts = 1
	for value in [-0.8, 0.0, 0.6]:
		var s := seat()
		s.frame.contact = value
		count(s, 20.0)
		assert_almost_eq(float(s.points.contact), value, 0.00001)

func test_draft_threshold_rear_and_no_contact_are_independent() -> void:
	var s := seat()
	_runner.draft = 0.399
	_runner.rear = 0.0
	count(s, 20.0)
	for key in ["draft", "rear", "contact"]:
		assert_eq(float(s.points.get(key, 0.0)), 0.0)
	_runner.draft = 0.4
	_runner.rear = 0.1
	count(s, 40.0)
	assert_almost_eq(float(s.points.draft), 0.3, 0.00001)
	assert_almost_eq(float(s.points.rear), 0.4, 0.00001)

func test_keep_is_paid_once_at_each_crossing_and_clamps_negative_stamina() -> void:
	var s := seat()
	_runner.stamina = 0.6
	count(s, 24.0)
	assert_eq(s.fit.keep_stamina, [null, null, null])
	count(s, 25.0)
	assert_almost_eq(float(s.points.keep), 0.6, 0.00001)
	_runner.stamina = -0.3
	count(s, 50.0)
	_runner.stamina = 0.2
	count(s, 76.0)
	count(s, 90.0)
	assert_eq(s.fit.keep_stamina, [0.6, -0.3, 0.2])
	assert_almost_eq(float(s.points.keep), 0.8, 0.00001)

func test_steady_counts_actual_changes_and_caps_the_race_penalty() -> void:
	var s := seat()
	count(s, 1.0)
	s.line_pending = true
	count(s, 2.0) # 壁で不動・ノッチも変わらない
	assert_eq(float(s.points.steady), 0.0)
	_runner._lateral_move_m = 0.2
	_runner.notch = 3.0
	count(s, 3.0)
	assert_eq(s.fit.notch_changes, 1)
	assert_eq(s.fit.line_changes, 1)
	assert_almost_eq(float(s.points.steady), -0.2, 0.00001)
	count(s, 4.0) # 同じ操作を保持しているだけなら追加で数えない
	assert_eq(s.fit.line_changes, 1)
	_runner.notch = 5.0
	count(s, 5.0)
	assert_almost_eq(float(s.points.steady), -0.35, 0.00001)
	_runner.notch = 1.0
	count(s, 6.0)
	assert_almost_eq(float(s.points.steady), -0.35, 0.00001)

func test_goal_and_cutoff_ledger_match_paid_reward_without_unreached_keep() -> void:
	var s := seat()
	_runner.progress = 20.0
	var progress_reward: float = _race._progress_reward(_runner, s)
	var total: float = progress_reward + _race._goal_reward(_runner, [_runner], s)
	var ledger := 0.0
	for value in s.points.values():
		ledger += float(value)
	assert_almost_eq(total, ledger, 0.00001)
	assert_eq(s.fit.keep_stamina, [null, null, null])
	assert_eq(float(_race._take_owed(s)), 0.0)

func test_frame_follows_the_six_personality_keys_and_is_cached() -> void:
	var original := Trainers._cached
	var attempted := Trainers._attempted
	Trainers._cached = [{"id": "fixture", "frame": {"stick": 0.1, "draft": 0.2, "rear": 0.3, "contact": -0.4, "steady": 0.5, "keep": 0.6}}]
	Trainers._attempted = true
	Observe._frames.clear()
	var frame := Observe._frame("fixture")
	assert_eq(frame.size(), Observe.FRAME_KEYS.size())
	assert_almost_eq(frame[3], -0.4, 0.00001)
	assert_eq(Observe._frame("fixture"), frame)
	Trainers._cached = original
	Trainers._attempted = attempted
	Observe._frames.clear()

func test_current_main_brain_uses_current_observation() -> void:
	var net := Net.load_file("res://data/cpu_brains/main.json")
	assert_not_null(net)
	if net != null:
		assert_eq(net.observation_version, Observe.VERSION)
		assert_eq(net.obs_size, Observe.size(8))
