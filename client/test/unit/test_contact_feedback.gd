extends GutTest

const ContactFeedback := preload("res://scripts/presentation/contact_feedback.gd")


func test_target_level_is_push_over_contact_over_none() -> void:
	assert_eq(ContactFeedback.target_level(0, false), 0.0)
	assert_eq(ContactFeedback.target_level(2, false), ContactFeedback.LEVEL_CONTACT)
	assert_eq(ContactFeedback.target_level(0, true), ContactFeedback.LEVEL_PUSH)
	assert_eq(ContactFeedback.target_level(1, true), ContactFeedback.LEVEL_PUSH)
	assert_gt(ContactFeedback.LEVEL_PUSH, ContactFeedback.LEVEL_CONTACT)


func test_level_follows_the_target_smoothly_without_overshooting() -> void:
	var level := 0.0
	var previous := 0.0
	for _step in 120:
		level = ContactFeedback.next_level(level, ContactFeedback.LEVEL_PUSH, 1.0 / 60.0)
		assert_gte(level, previous)
		assert_lte(level, ContactFeedback.LEVEL_PUSH)
		previous = level
	assert_almost_eq(level, ContactFeedback.LEVEL_PUSH, 0.01)
	# 1フレームでは、目標へ飛ばない。
	assert_lt(ContactFeedback.next_level(0.0, 1.0, 1.0 / 60.0), 0.5)


func test_no_contact_means_no_glow() -> void:
	assert_eq(ContactFeedback.glow_energy(0.0), 0.0)


func test_glow_grows_with_the_level() -> void:
	assert_gt(ContactFeedback.glow_energy(ContactFeedback.LEVEL_PUSH), ContactFeedback.glow_energy(ContactFeedback.LEVEL_CONTACT))
