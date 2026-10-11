extends GutTest

const RaceAudio := preload("res://scripts/race_audio.gd")


func test_race_sound_assets_exist_and_load() -> void:
	for key: String in RaceAudio.SOUND_PATHS:
		var path := str(RaceAudio.SOUND_PATHS[key])
		assert_true(ResourceLoader.exists(path), key)
		var stream := load(path)
		assert_not_null(stream, key)
		if path.ends_with(".ogg"):
			assert_true(stream is AudioStreamOggVorbis, key)
		else:
			assert_true(stream is AudioStreamMP3, key)


func test_other_leader_bell_is_quieter_when_far_from_the_goal() -> void:
	var near := RaceAudio.other_leader_finish_volume_db(0.0, 2000.0)
	var mid := RaceAudio.other_leader_finish_volume_db(1000.0, 2000.0)
	var far := RaceAudio.other_leader_finish_volume_db(2000.0, 2000.0)
	assert_gt(near, mid)
	assert_gt(mid, far)
	assert_almost_eq(near, RaceAudio.BELL_NEAR_DB, 0.001)
	assert_almost_eq(far, RaceAudio.BELL_FAR_DB, 0.001)


func test_player_finish_bell_always_plays_at_the_goal_volume() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.play_player_finish_bell()
	var bell := audio.get_node("GoalBell") as AudioStreamPlayer
	assert_true(bell.playing)
	assert_almost_eq(bell.volume_db, RaceAudio.BELL_NEAR_DB, 0.001)
	audio.free()


func test_player_first_goal_plays_the_bell_and_cheer_together() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.play_player_first_goal()
	var bell := audio.get_node("GoalBell") as AudioStreamPlayer
	var cheer := audio.get_node("CrowdCheer") as AudioStreamPlayer
	assert_true(bell.playing)
	assert_true(cheer.playing)
	assert_almost_eq(bell.volume_db, RaceAudio.BELL_NEAR_DB, 0.001)
	audio.free()


func test_final_stretch_ambience_can_start_and_stop() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.play_race_entry()
	var ambience := audio.get_node("StadiumAmbience") as AudioStreamPlayer
	# 入場の歓声は1回で終わる。終盤はゴールまで途切れさせないので、繰り返しにする。
	assert_false((ambience.stream as AudioStreamMP3).loop)
	audio.start_final_stretch_ambience()
	assert_true((ambience.stream as AudioStreamMP3).loop)
	assert_true(audio.is_final_stretch_ambience_playing())
	audio.stop_final_stretch_ambience()
	assert_false(audio.is_final_stretch_ambience_playing())
	audio.free()


## 入場で流し始めたあと、終盤は大きさだけを動かす（入場時の大きさへ戻さない）。
func test_final_stretch_keeps_the_swelled_volume() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.play_race_entry()
	audio.set_final_stretch_level(1.0)
	var ambience := audio.get_node("StadiumAmbience") as AudioStreamPlayer
	assert_almost_eq(ambience.volume_db, RaceAudio.AMBIENCE_LOUD_DB, 0.001)
	audio.start_final_stretch_ambience()
	assert_almost_eq(ambience.volume_db, RaceAudio.AMBIENCE_LOUD_DB, 0.001)
	audio.free()


## 入場の歓声が終わったあとでも、終盤にもう一度鳴らし直せる。
func test_final_stretch_plays_again_after_the_entry_cheer_ended() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.play_race_entry()
	audio.stop_final_stretch_ambience()
	audio.start_final_stretch_ambience()
	assert_true(audio.is_final_stretch_ambience_playing())
	audio.free()
