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


func test_no_contact_keeps_the_original_shape_and_no_glow() -> void:
	assert_eq(ContactFeedback.body_scale(0.0, 0.123), Vector3.ONE)
	assert_eq(ContactFeedback.glow_energy(0.0), 0.0)


func test_contact_squashes_sideways_and_bulges_up_and_front() -> void:
	var scale := ContactFeedback.body_scale(ContactFeedback.LEVEL_CONTACT, 0.0)
	assert_lt(scale.x, 1.0)
	assert_gt(scale.y, 1.0)
	assert_gt(scale.z, 1.0)
	# 体積はほぼ変わらない。
	assert_almost_eq(scale.x * scale.y * scale.z, 1.0, 0.03)


func test_push_shakes_but_contact_does_not() -> void:
	var quarter := 1.0 / (ContactFeedback.SHAKE_HZ * 4.0)
	assert_eq(ContactFeedback.body_scale(ContactFeedback.LEVEL_CONTACT, 0.0), ContactFeedback.body_scale(ContactFeedback.LEVEL_CONTACT, quarter))
	assert_ne(ContactFeedback.body_scale(ContactFeedback.LEVEL_PUSH, 0.0), ContactFeedback.body_scale(ContactFeedback.LEVEL_PUSH, quarter))


func test_glow_grows_with_the_level() -> void:
	assert_gt(ContactFeedback.glow_energy(ContactFeedback.LEVEL_PUSH), ContactFeedback.glow_energy(ContactFeedback.LEVEL_CONTACT))
