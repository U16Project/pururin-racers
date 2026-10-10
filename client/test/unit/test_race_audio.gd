extends GutTest

const RaceAudio := preload("res://scripts/race_audio.gd")


func test_race_sound_assets_exist_and_load_as_mp3_streams() -> void:
	for key: String in RaceAudio.SOUND_PATHS:
		var path := str(RaceAudio.SOUND_PATHS[key])
		assert_true(ResourceLoader.exists(path), key)
		var stream := load(path)
		assert_not_null(stream, key)
		assert_true(stream is AudioStreamMP3, key)


func test_final_stretch_ambience_can_start_and_stop() -> void:
	var audio := RaceAudio.new()
	add_child(audio)
	audio.start_final_stretch_ambience()
	assert_true(audio.is_final_stretch_ambience_playing())
	audio.stop_final_stretch_ambience()
	assert_false(audio.is_final_stretch_ambience_playing())
	audio.free()
