extends GutTest

const FinishCelebration := preload("res://scripts/presentation/finish_celebration.gd")


func after_each() -> void:
	# ゆっくりが、次のテストへ残らないようにする。
	Engine.time_scale = 1.0


func test_slow_motion_holds_then_returns_to_normal_speed() -> void:
	var hold := FinishCelebration.SLOW_HOLD_S
	var recover := FinishCelebration.SLOW_RECOVER_S
	# 保つあいだは、ずっと同じ速さ。
	assert_almost_eq(FinishCelebration.slow_scale(hold + recover), FinishCelebration.SLOW_SCALE, 0.0001)
	assert_almost_eq(FinishCelebration.slow_scale(recover), FinishCelebration.SLOW_SCALE, 0.0001)
	# そのあと、だんだんふつうの速さへ戻る。
	var half := FinishCelebration.slow_scale(recover * 0.5)
	assert_gt(half, FinishCelebration.SLOW_SCALE)
	assert_lt(half, 1.0)
	assert_almost_eq(FinishCelebration.slow_scale(0.0), 1.0, 0.0001)
	assert_almost_eq(FinishCelebration.slow_scale(-1.0), 1.0, 0.0001)


func test_celebration_slows_the_game_once_and_recovers_in_real_time() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var celebration := FinishCelebration.new()
	celebration.play(holder, Vector3(0.0, 0.0, -10.0), 15.0)
	assert_almost_eq(Engine.time_scale, FinishCelebration.SLOW_SCALE, 0.0001)
	assert_true(celebration.is_playing())
	assert_not_null(holder.get_node_or_null(FinishCelebration.ROOT_NAME))
	# 2回目は、もう一度ゆっくりにはしない。
	celebration.advance(FinishCelebration.SLOW_HOLD_S * FinishCelebration.SLOW_SCALE)
	var after_hold := Engine.time_scale
	celebration.play(holder, Vector3.ZERO, 15.0)
	assert_almost_eq(Engine.time_scale, after_hold, 0.0001)
	# 実時間で、保つ時間＋戻る時間が過ぎれば、ふつうの速さに戻る。
	for _step in 40:
		celebration.advance(0.05 * Engine.time_scale)
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001)
	assert_false(celebration.is_playing())


func test_celebration_stop_restores_speed_right_away() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var celebration := FinishCelebration.new()
	celebration.play(holder, Vector3.ZERO, 15.0)
	assert_lt(Engine.time_scale, 1.0)
	celebration.stop()
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001)
	assert_false(celebration.is_playing())


func test_confetti_is_spread_across_the_course_above_the_goal() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var celebration := FinishCelebration.new()
	var goal := Vector3(2.0, 0.0, -30.0)
	celebration.play(holder, goal, 15.0)
	var root := holder.get_node(FinishCelebration.ROOT_NAME) as Node3D
	assert_almost_eq(root.global_position.y, goal.y + FinishCelebration.CONFETTI_HEIGHT_M, 0.001)
	assert_eq(root.get_child_count(), FinishCelebration.CONFETTI_COLORS.size())
	for child in root.get_children():
		var particles := child as GPUParticles3D
		assert_not_null(particles)
		assert_true(particles.one_shot)
		assert_true(particles.emitting)
		assert_eq(particles.amount, FinishCelebration.CONFETTI_PER_COLOR)
		var process := particles.process_material as ParticleProcessMaterial
		assert_almost_eq(process.emission_box_extents.x, 15.0 * FinishCelebration.CONFETTI_WIDTH_RATIO, 0.001)
		# 上へ舞い上がってから、落ちてくる。
		assert_gt(process.initial_velocity_min, 0.0)
		assert_lt(process.gravity.y, 0.0)
