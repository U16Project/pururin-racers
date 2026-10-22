extends GutTest
## 2026-10-23: 採用設定0.85/1.2が、直前試案0.70/1.5より
## 風よけの効果を戻し、集団ステータス差を保つことを共通の計算式で確認する。
const Math := preload("res://scripts/local_race_math.gd")
const Config := preload("res://scripts/config/local_race_config.gd")

var _saved: Dictionary

func before_each() -> void:
	_saved = Config.values()

func after_each() -> void:
	Config._cached = _saved

func _reduction(factor: float, exponent: float, count: int, pack_stat: int) -> float:
	var values: Dictionary = _saved.duplicate(true)
	values["draft_air_resistance_factor"] = factor
	values["draft_aggregation_exponent"] = exponent
	Config._cached = values
	var contributions: Array = []
	# 距離・横ずれの条件を固定した数式比較。実際のレース時計の試験ではない。
	for n in count:
		contributions.append(Math.draft_wake_from_speed(60.0))
	return Math.draft_air_resistance_factor(Math.draft_aggregate_contributions_p(contributions), pack_stat)

func test_recommended_values_restore_benefit_for_one_two_and_three_sources() -> void:
	for count in [1, 2, 3]:
		for pack_stat in [3, 8, 12]:
			var previous := _reduction(0.70, 1.5, count, pack_stat)
			var adopted := _reduction(0.85, 1.2, count, pack_stat)
			assert_gt(adopted, previous, "sources=%d, pack=%d" % [count, pack_stat])
			assert_gt(adopted, 0.0)
			assert_lt(adopted, 0.85)

func test_pack_and_source_count_keep_their_ordering() -> void:
	for count in [1, 2, 3]:
		assert_lt(_reduction(0.85, 1.2, count, 3), _reduction(0.85, 1.2, count, 8))
		assert_lt(_reduction(0.85, 1.2, count, 8), _reduction(0.85, 1.2, count, 12))
	for pack_stat in [3, 8, 12]:
		assert_lt(_reduction(0.85, 1.2, 1, pack_stat), _reduction(0.85, 1.2, 2, pack_stat))
		assert_lt(_reduction(0.85, 1.2, 2, pack_stat), _reduction(0.85, 1.2, 3, pack_stat))

func test_aggregation_exponent_does_not_change_single_source() -> void:
	for pack_stat in [3, 8, 12]:
		assert_almost_eq(_reduction(0.85, 1.5, 1, pack_stat), _reduction(0.85, 1.2, 1, pack_stat), 0.000001)

func test_unrelated_stat_curves_stay_unchanged() -> void:
	assert_almost_eq(Config.number("aero_air_resistance_multiplier_per_stat"), 0.010, 0.000001)
	assert_almost_eq(Config.number("pack_draft_effective_multiplier_per_stat"), 0.12, 0.000001)
	assert_almost_eq(Config.number("draft_response_exponent"), 1.5, 0.000001)
