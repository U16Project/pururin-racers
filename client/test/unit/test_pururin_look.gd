extends GutTest
## ぷるりんの見た目：設定の検査、体の組み立て、部品の取り替え、表情とアクションの受け口。

const LookConfig := preload("res://scripts/config/pururin_look_config.gd")
const Builder := preload("res://scripts/presentation/pururin_body_builder.gd")
const Surface := preload("res://scripts/presentation/pururin_parts/pururin_surface.gd")
const PururinBody := preload("res://scripts/presentation/pururin_body.gd")
const StatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const RosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const VisualStyle := preload("res://scripts/pururin_visual_style.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const ContactFeedback := preload("res://scripts/presentation/contact_feedback.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const PortraitCache := preload("res://scripts/presentation/pururin_portrait_cache.gd")
const FaceParts := preload("res://scripts/presentation/pururin_parts/face_parts.gd")
const BodyParts := preload("res://scripts/presentation/pururin_parts/body_parts.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const SWAP_PARTS := "res://test/fixtures/pururin/parts_swap.json"
const SWAP_LOOKS := "res://test/fixtures/pururin/looks_swap.json"


func _game_config() -> Dictionary:
	var loaded := LookConfig.values()
	assert_eq(LookConfig.last_error, "")
	assert_false(loaded.is_empty())
	return loaded


## 取り替えの確認用の設定。個体一覧に無い見た目なので、色は、水の選択肢から選ぶ。
func _swap_config() -> Dictionary:
	var loaded := LookConfig.load_files(SWAP_PARTS, SWAP_LOOKS)
	assert_false(loaded.has("error"), str(loaded.get("error", "")))
	var choices: Array = StatsConfig.values()["attributes"]["water"]["primary_colors"]
	for id: String in loaded["looks"]:
		loaded["looks"][id] = LookConfig.resolved_look(loaded["looks"][id], choices)
	return loaded


func _raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_game_look_files_load_without_errors() -> void:
	var config := _game_config()
	assert_gt((config["looks"] as Dictionary).size(), 0)
	assert_gt((config["parts"] as Dictionary).size(), 0)


func test_every_body_is_as_wide_as_the_collision_circle_whatever_its_height() -> void:
	assert_eq(Surface.BODY_RADIUS, M2TrackMath.BODY_RADIUS_M, "体の半径は、当たり判定と同じ")
	for height in [0.8, 1.02, 1.3]:
		var shape := {"height": height, "base_height": 0.2}
		var widest := 0.0
		for step in 200:
			var point := Surface.surface_point(shape, PI * float(step) / 199.0, PI * 0.5)
			widest = maxf(widest, absf(point.x))
			assert_gte(point.y, -0.0001, "地面より下に出ない")
			assert_lte(point.y, height + 0.0001)
		assert_almost_eq(widest, Surface.BODY_RADIUS, 0.001, "高さ %.2f でも、一番太い所は同じ" % height)


func test_a_body_is_built_from_its_look_with_body_parts_face_and_marks() -> void:
	var config := _swap_config()
	var body: Node3D = Builder.build(config["looks"]["swapped"], config)
	add_child_autofree(body)
	assert_not_null(body.get_node_or_null("Dome"))
	# 体の一部は、頭の上・左右2つ・尾。
	var names := []
	for node: Node3D in body.call("body_part_nodes"):
		names.append(str(node.name))
	assert_eq(names, ["Top", "SideR", "SideL", "Tail"])
	assert_not_null(body.get_node_or_null("Mark0"))
	assert_not_null(body.call("body_material"))


func test_swapping_one_part_in_the_look_changes_only_that_part() -> void:
	var config := _swap_config()
	var base: Node3D = Builder.build(config["looks"]["base"], config)
	var swapped: Node3D = Builder.build(config["looks"]["swapped"], config)
	add_child_autofree(base)
	add_child_autofree(swapped)
	# 頭の上：こちらで作った突起（メッシュの節そのもの）と、用意したメッシュ（.glb から作った節）。
	assert_true(base.get_node("Top") is MeshInstance3D)
	assert_gt(swapped.get_node("Top").find_children("*", "MeshInstance3D", true, false).size() + (1 if swapped.get_node("Top") is MeshInstance3D else 0), 0)
	assert_ne(base.get_node("Top").get_class() + str(base.get_node("Top").get_child_count()), "")
	# 目：こちらで作った目は色を塗った面、画像の目は絵を貼った面。
	var drawn_eyes := base.get_node("Face_normal_eyes") as MeshInstance3D
	assert_null((drawn_eyes.material_override as StandardMaterial3D).albedo_texture)
	var image_eyes := swapped.get_node("Face_normal_eyes") as MeshInstance3D
	assert_not_null((image_eyes.material_override as StandardMaterial3D).albedo_texture)
	# 取り替えていない部品（左右・尾・口）は、同じ。
	for node_name in ["SideR", "SideL", "Tail", "Face_normal_mouth"]:
		assert_eq(swapped.get_node(node_name).get_class(), base.get_node(node_name).get_class(), node_name)


func test_expression_swaps_face_parts_and_falls_back_to_normal_per_slot() -> void:
	# 確認用の個体は、ノーマル（目・口・ほっぺ）と、喜（目だけ）を持っている。
	var config := _swap_config()
	var body: Node3D = Builder.build(config["looks"]["swapped"], config)
	add_child_autofree(body)
	assert_eq(body.call("expression"), PururinBody.NORMAL)
	assert_true((body.get_node("Face_normal_eyes") as Node3D).visible)
	assert_null(body.get_node_or_null("Face_joy_eyes"), "ほかの表情の部品は、出すときまで作らない")
	body.call("set_expression", "joy")
	# 目は「喜」の部品。口とほっぺは「喜」に無いので、ノーマルのまま出る。
	assert_eq(body.call("shown_expression_for", "eyes"), "joy")
	assert_true((body.get_node("Face_joy_eyes") as Node3D).visible)
	assert_false((body.get_node("Face_normal_eyes") as Node3D).visible)
	assert_eq(body.call("shown_expression_for", "mouth"), PururinBody.NORMAL)
	assert_true((body.get_node("Face_normal_mouth") as Node3D).visible)
	assert_true((body.get_node("Face_normal_cheeks") as Node3D).visible)
	# 用意の無い感情は、全部ノーマル。
	body.call("set_expression", "first_place")
	for slot: String in PururinBody.FACE_SLOTS:
		assert_eq(body.call("shown_expression_for", slot), PururinBody.NORMAL, slot)
	assert_true((body.get_node("Face_normal_eyes") as Node3D).visible)
	assert_false((body.get_node("Face_joy_eyes") as Node3D).visible)


func test_every_pururin_has_its_own_face_for_every_expression() -> void:
	var config := _game_config()
	var names: Array = config["expression_names"]
	assert_true(PururinBody.NORMAL in names)
	var seen := {}
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var expressions: Dictionary = look["face"]["expressions"]
		for name: String in names:
			assert_true(expressions.has(name), "%s に、表情 %s がある" % [id, name])
		# 表情どうしが、同じ顔にならない（どこか1つは違う部品）。
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var faces := {}
		for name: String in names:
			body.call("set_expression", name)
			var shown := []
			for slot: String in PururinBody.FACE_SLOTS:
				shown.append((expressions[str(body.call("shown_expression_for", slot))] as Dictionary).get(slot))
			assert_false(faces.has(shown), "%s の %s は、ほかの表情と同じ顔" % [id, name])
			faces[shown] = true
			# その表情で出ている顔の部品は、スロットごとに1つまで。
			for slot: String in PururinBody.FACE_SLOTS:
				var visible_count := 0
				for other: String in names:
					var node := body.get_node_or_null("Face_%s_%s" % [other, slot]) as Node3D
					if node != null and node.visible:
						visible_count += 1
				assert_lte(visible_count, 1, "%s %s %s" % [id, name, slot])
		# 個体どうしで、顔のひとそろい（目の形・傾き・まつ毛・表情の組み合わせ）が同じにならない。
		var style := [look["face"]["eye_size"], look["face"]["eye_tilt_deg"], look["face"]["eye_lashes"], expressions]
		assert_false(seen.has(style), "%s は、ほかの個体と同じ顔" % id)
		seen[style] = true


func test_an_expression_can_hide_a_slot_and_unknown_expression_names_stop_the_load() -> void:
	var parts := _raw(SWAP_PARTS)
	var looks := _raw(SWAP_LOOKS)
	# null と書いたスロットは、その表情では何も出さない（ノーマルにも戻さない）。
	looks["looks"]["swapped"]["face"]["expressions"]["joy"]["cheeks"] = null
	assert_eq(LookConfig.validate(parts, looks).size(), 0)
	var config := {"parts": parts["parts"], "finishes": parts["finishes"], "body_motions": parts["body_motions"]}
	var choices: Array = StatsConfig.values()["attributes"]["water"]["primary_colors"]
	var body: Node3D = Builder.build(LookConfig.resolved_look(looks["looks"]["swapped"], choices), config)
	add_child_autofree(body)
	body.call("set_expression", "joy")
	assert_false((body.get_node("Face_normal_cheeks") as Node3D).visible)
	assert_true((body.get_node("Face_normal_mouth") as Node3D).visible)
	# 一覧に無い表情の名前（書き間違い）は、読み込みで止める。
	var typo := _raw(SWAP_LOOKS)
	typo["looks"]["base"]["face"]["expressions"]["joyy"] = {"eyes": "eyes_joy"}
	assert_true("; ".join(LookConfig.validate(parts, typo)).contains("expression_names"))
	# 顔の部品の数字や色が足りない。
	for part_id: String in parts["parts"]:
		var part: Dictionary = parts["parts"][part_id]
		if str(part["kind"]) != "face" or str(part["source"]["type"]) != "builtin":
			continue
		var shape := str(part["source"]["shape"])
		for key: String in FaceParts.REQUIRED_PARAMS[shape] + FaceParts.REQUIRED_COLORS.get(shape, []):
			var broken := parts.duplicate(true)
			broken["parts"][part_id]["source"].erase(key)
			assert_true("; ".join(LookConfig.validate(broken, looks)).contains("%s.source.%s" % [part_id, key]), "%s %s" % [part_id, key])


func test_every_builtin_face_shape_is_used_by_a_part_in_the_catalogue() -> void:
	var config := _game_config()
	var used := {}
	for part: Dictionary in (config["parts"] as Dictionary).values():
		if str(part["kind"]) != "body_part" and str(part["source"]["type"]) == "builtin":
			used["%s/%s" % [part["slot"], part["source"]["shape"]]] = true
	for slot: String in FaceParts.BUILTIN_SHAPES:
		for shape: String in FaceParts.BUILTIN_SHAPES[slot]:
			assert_true(used.has("%s/%s" % [slot, shape]), "%s の %s を使う部品が、一覧にある" % [slot, shape])


func test_action_is_remembered_and_only_parts_with_a_motion_for_it_move() -> void:
	var config := _game_config()
	var changed := config.duplicate(true)
	var look: Dictionary = (config["looks"] as Dictionary).values()[0]
	# 頭の上の部品にだけ、「走る」の動かし方を書いた場合。
	for slot: String in ["top", "sides", "tail"]:
		changed["parts"][str(look[slot]["part"])]["motions"] = {}
	# 体全体は動かさない（部品の動きだけを見る）。
	changed["body_motions"][str(look["body_motion"]["set"])]["actions"] = {}
	changed["parts"][str(look["top"]["part"])]["motions"] = {"run": [{"type": "sway", "axis": "z", "angle_deg": 6.0, "hz": 2.0}]}
	var body: Node3D = Builder.build(look, changed)
	add_child_autofree(body)
	var side := body.get_node("SideR") as Node3D
	var top := body.get_node("Top") as Node3D
	var side_rest := side.transform
	var top_rest := top.transform
	body.call("set_action", "run")
	assert_eq(body.call("action"), "run")
	var moving: Array = body.call("parts_moving_in", "run")
	assert_eq(moving.size(), 1)
	assert_eq(str(moving[0].name), "Top")
	assert_eq((body.call("parts_moving_in", "dash") as Array).size(), 0, "動かし方が書かれていないアクションでは、動かさない")
	# 時間を進めると、頭の上の部品だけが回る。付け根の位置は動かない。
	for _step in 37:
		body.call("advance_motion", 1.0 / 60.0)
	assert_false(top.transform.basis.is_equal_approx(top_rest.basis), "頭の上の部品が回っている")
	assert_almost_eq(top.transform.origin.distance_to(top_rest.origin), 0.0, 0.0001)
	assert_true(side.transform.is_equal_approx(side_rest), "動かし方の無い部品は、そのまま")
	# 動かし方の無いアクションに替えると、なめらかに元の形へ戻る。
	body.call("set_action", "dash")
	for _step in 120:
		body.call("advance_motion", 1.0 / 60.0)
	assert_true(top.transform.is_equal_approx(top_rest))


func test_motion_pose_follows_the_kinds_of_motion() -> void:
	var quarter := 0.25  # hz が1なら、4分の1秒で、ゆれが一番大きくなる
	var sway := [{"type": "sway", "axis": "z", "angle_deg": 20.0, "hz": 1.0}]
	assert_almost_eq((PururinBody.motion_pose(sway, quarter)[0] as Vector3).z, deg_to_rad(20.0), 0.0001)
	assert_almost_eq((PururinBody.motion_pose(sway, 0.0)[0] as Vector3).z, 0.0, 0.0001)
	assert_almost_eq((PururinBody.motion_pose(sway, quarter * 3.0)[0] as Vector3).z, -deg_to_rad(20.0), 0.0001)
	# phase で、ゆれの出だしをずらせる。
	var shifted := [{"type": "sway", "axis": "z", "angle_deg": 20.0, "hz": 1.0, "phase": 0.25}]
	assert_almost_eq((PururinBody.motion_pose(shifted, 0.0)[0] as Vector3).z, deg_to_rad(20.0), 0.0001)
	# 傾けたまま・大きくしたまま。
	var held := [{"type": "lean", "axis": "x", "angle_deg": 15.0}, {"type": "grow", "amount": 0.3}]
	assert_almost_eq((PururinBody.motion_pose(held, 3.7)[0] as Vector3).x, deg_to_rad(15.0), 0.0001)
	assert_true((PururinBody.motion_pose(held, 3.7)[1] as Vector3).is_equal_approx(Vector3.ONE * 1.3))
	# 大きくなったり小さくなったり。重ねた動きは、合わせる。
	var mixed := [{"type": "pulse", "amount": 0.1, "hz": 1.0}, {"type": "sway", "axis": "x", "angle_deg": 5.0, "hz": 1.0}, {"type": "lean", "axis": "x", "angle_deg": 10.0}]
	assert_true((PururinBody.motion_pose(mixed, quarter)[1] as Vector3).is_equal_approx(Vector3.ONE * 1.1))
	assert_almost_eq((PururinBody.motion_pose(mixed, quarter)[0] as Vector3).x, deg_to_rad(15.0), 0.0001)
	# 何も無ければ、動かさない。
	assert_eq(PururinBody.motion_pose([], 1.0), PururinBody.pose_identity())


func test_stretch_keeps_the_volume_and_hop_never_goes_below_the_ground() -> void:
	# 伸び縮み：1つの向きに伸びたぶん、ほかの2つが縮んで、かさは変わらない。hz が 0 なら、伸ばしたまま。
	var held: Vector3 = PururinBody.motion_pose([{"type": "stretch", "axis": "z", "amount": 0.25, "hz": 0.0}], 1.3)[1]
	assert_almost_eq(held.z, 1.25, 0.0001)
	assert_lt(held.x, 1.0)
	assert_almost_eq(held.x, held.y, 0.0001)
	assert_almost_eq(held.x * held.y * held.z, 1.0, 0.0001)
	var moving := [{"type": "stretch", "axis": "y", "amount": 0.2, "hz": 1.0}]
	assert_almost_eq((PururinBody.motion_pose(moving, 0.25)[1] as Vector3).y, 1.2, 0.0001)
	assert_almost_eq((PururinBody.motion_pose(moving, 0.75)[1] as Vector3).y, 0.8, 0.0001)
	# 跳ねる：1秒に hz 回。地面より下へは行かない。地面でつぶれ、一番高い所で伸びる。
	var hop := [{"type": "hop", "height": 0.3, "hz": 2.0, "squash": 0.2}]
	for step in 41:
		var pose := PururinBody.motion_pose(hop, float(step) / 40.0)
		assert_gte((pose[2] as Vector3).y, 0.0)
		assert_lte((pose[2] as Vector3).y, 0.3 + 0.0001)
	assert_almost_eq((PururinBody.motion_pose(hop, 0.25)[2] as Vector3).y, 0.3, 0.0001, "4分の1秒で、一番高い")
	assert_almost_eq((PururinBody.motion_pose(hop, 0.5)[2] as Vector3).y, 0.0, 0.0001, "2分の1秒で、着地")
	assert_lt((PururinBody.motion_pose(hop, 0.5)[1] as Vector3).y, 1.0, "着地で、上下につぶれる")
	assert_gt((PururinBody.motion_pose(hop, 0.25)[1] as Vector3).y, 1.0, "一番高い所で、上下に伸びる")
	# 輪を描いて動き回る：始めは元の場所。持ち上げたまま。
	var around := [{"type": "circle", "radius": 0.25, "hz": 1.0}, {"type": "lift", "height": 0.1}]
	assert_true((PururinBody.motion_pose(around, 0.0)[2] as Vector3).is_equal_approx(Vector3(0.0, 0.1, 0.0)))
	assert_almost_eq((PururinBody.motion_pose(around, 0.5)[2] as Vector3).x, -0.5, 0.0001)


func _dome_transform(body: Node3D) -> Transform3D:
	return (body.get_node("Dome") as Node3D).transform


func test_the_whole_body_moves_with_the_action_and_the_look_scales_it() -> void:
	var config := _game_config()
	var roster: Array = RosterConfig.values()["roster"]
	var look := LookConfig.look_for(str(roster[0]["id"]))
	var body: Node3D = Builder.build(look, config)
	add_child_autofree(body)
	# アクションを決めていないあいだは、動かない。体の節そのもの（使う側が置く）は、どのアクションでも動かさない。
	body.call("advance_motion", 0.5)
	assert_true(_dome_transform(body).is_equal_approx(Transform3D.IDENTITY))
	body.call("set_action", "goal_win")
	var highest := 0.0
	for _step in 120:
		body.call("advance_motion", 1.0 / 60.0)
		highest = maxf(highest, _dome_transform(body).origin.y)
		assert_gte(_dome_transform(body).origin.y, -0.0001, "地面より下へは行かない")
	assert_eq(body.transform, Transform3D.IDENTITY)
	# 1位の跳ねの高さは、設定の高さ × その個体の大きさの倍率。
	var hop_height := 0.0
	for motion: Dictionary in config["body_motions"][str(look["body_motion"]["set"])]["actions"]["goal_win"]:
		if str(motion["type"]) == "hop":
			hop_height = float(motion["height"])
	assert_gt(hop_height, 0.0)
	assert_almost_eq(highest, hop_height * float(look["body_motion"]["amount"]), hop_height * 0.05)
	# 顔・マーク・部品も、体と一緒に動く。
	assert_gt((body.get_node("Face_normal_eyes") as Node3D).transform.origin.y + (body.get_node("Mark0") as Node3D).transform.origin.y, -0.0001)
	var eyes := (body.get_node("Face_normal_eyes") as Node3D).transform
	assert_true(eyes.is_equal_approx(_dome_transform(body)), "顔は、体の本体と同じ置き方")
	# あとから出した顔にも、すぐ同じ置き方が掛かる。
	body.call("set_expression", "joy")
	assert_true((body.get_node("Face_joy_eyes") as Node3D).transform.is_equal_approx(_dome_transform(body)))


func test_steer_leans_the_body_to_the_side_and_one_shot_ends_by_itself() -> void:
	var config := _game_config()
	var changed := config.duplicate(true)
	var look: Dictionary = (config["looks"] as Dictionary).values()[0]
	var motion: Dictionary = changed["body_motions"][str(look["body_motion"]["set"])]
	motion["actions"] = {}
	var body: Node3D = Builder.build(look, changed)
	add_child_autofree(body)
	# 右へ傾ける：体のてっぺんが、体の右（+x）へ動く。左は逆。
	body.call("set_steer", 1.0)
	for _step in 120:
		body.call("advance_motion", 1.0 / 60.0)
	assert_almost_eq(float(body.call("steer")), 1.0, 0.01)
	var top_right := (_dome_transform(body) * Vector3(0.0, 1.0, 0.0)).x
	assert_almost_eq(top_right, sin(deg_to_rad(float(motion["steer_lean_deg"]) * float(look["body_motion"]["amount"]))), 0.01)
	body.call("set_steer", -1.0)
	for _step in 120:
		body.call("advance_motion", 1.0 / 60.0)
	assert_lt((_dome_transform(body) * Vector3(0.0, 1.0, 0.0)).x, 0.0)
	body.call("set_steer", 0.0)
	for _step in 240:
		body.call("advance_motion", 1.0 / 60.0)
	assert_true(_dome_transform(body).is_equal_approx(Transform3D.IDENTITY))
	# 1回だけの動き：決まった秒数だけ出て、ひとりでに終わる。
	var name: String = (motion["one_shots"] as Dictionary).keys()[0]
	var seconds := float(motion["one_shots"][name]["seconds"])
	body.call("play_once", name)
	assert_eq(body.call("playing_once"), name)
	body.call("advance_motion", seconds * 0.5)
	assert_false(_dome_transform(body).is_equal_approx(Transform3D.IDENTITY), "途中は、形が変わっている")
	body.call("advance_motion", seconds * 0.6)
	assert_eq(body.call("playing_once"), "")
	assert_true(_dome_transform(body).is_equal_approx(Transform3D.IDENTITY))


func test_left_and_right_parts_move_as_mirror_images() -> void:
	var config := _game_config()
	for id: String in config["looks"]:
		var body: Node3D = Builder.build(config["looks"][id], config)
		add_child_autofree(body)
		body.call("set_action", "run")
		for _step in 37:
			body.call("advance_motion", 1.0 / 60.0)
		var right := _body_space_bounds(body.get_node("SideR"))
		var left := _body_space_bounds(body.get_node("SideL"))
		assert_almost_eq(-left.end.x, right.position.x, 0.001, id)
		assert_almost_eq(left.end.y, right.end.y, 0.001, id)
		assert_almost_eq(left.end.z, right.end.z, 0.001, id)


func test_every_action_moves_something_and_motion_errors_stop_the_load() -> void:
	var parts := _raw(LookConfig.PARTS_PATH)
	var looks := _raw(LookConfig.LOOKS_PATH)
	# 一覧にあるアクションは、どれも、どこかの部品を動かす。動かし方の種類も、全部どこかで使っている。
	var used_actions := {}
	var used_types := {}
	var motion_sets := []
	for part: Dictionary in (parts["parts"] as Dictionary).values():
		motion_sets.append(part.get("motions", {}))
	for body_motion: Dictionary in (parts["body_motions"] as Dictionary).values():
		motion_sets.append(body_motion["actions"])
		for one_shot: Dictionary in (body_motion["one_shots"] as Dictionary).values():
			for motion: Dictionary in one_shot["motions"]:
				used_types[str(motion["type"])] = true
	for motions: Dictionary in motion_sets:
		for action: String in motions:
			used_actions[action] = true
			for motion: Dictionary in motions[action]:
				used_types[str(motion["type"])] = true
	for action: String in parts["action_names"]:
		assert_true(used_actions.has(action), "アクション %s で動く部品がある" % action)
	for type: String in PururinBody.MOTION_TYPES:
		assert_true(used_types.has(type), "動かし方 %s を使う部品がある" % type)
	# 書き間違い
	var moving_part := ""
	for part_id: String in parts["parts"]:
		if not (parts["parts"][part_id].get("motions", {}) as Dictionary).is_empty():
			moving_part = part_id
			break
	var first_action: String = (parts["parts"][moving_part]["motions"] as Dictionary).keys()[0]
	var unknown_action := parts.duplicate(true)
	unknown_action["parts"][moving_part]["motions"]["fly"] = []
	assert_true("; ".join(LookConfig.validate(unknown_action, looks)).contains("%s.motions.fly" % moving_part))
	var unknown_type := parts.duplicate(true)
	unknown_type["parts"][moving_part]["motions"][first_action] = [{"type": "spin"}]
	assert_true("; ".join(LookConfig.validate(unknown_type, looks)).contains("%s.motions.%s[0].type" % [moving_part, first_action]))
	var missing_number := parts.duplicate(true)
	missing_number["parts"][moving_part]["motions"][first_action] = [{"type": "sway", "axis": "z", "angle_deg": 5.0}]
	assert_true("; ".join(LookConfig.validate(missing_number, looks)).contains("%s.motions.%s[0].hz" % [moving_part, first_action]))
	var bad_axis := parts.duplicate(true)
	bad_axis["parts"][moving_part]["motions"][first_action] = [{"type": "lean", "axis": "up", "angle_deg": 5.0}]
	assert_true("; ".join(LookConfig.validate(bad_axis, looks)).contains("%s.motions.%s[0].axis" % [moving_part, first_action]))
	var extra_key := parts.duplicate(true)
	extra_key["parts"][moving_part]["motions"][first_action] = [{"type": "grow", "amount": 0.1, "speed": 2.0}]
	assert_true("; ".join(LookConfig.validate(extra_key, looks)).contains("%s.motions.%s[0].speed" % [moving_part, first_action]))
	# 体全体の動かし方の書き間違い。
	var set_id: String = (parts["body_motions"] as Dictionary).keys()[0]
	var body_unknown_action := parts.duplicate(true)
	body_unknown_action["body_motions"][set_id]["actions"]["fly"] = []
	assert_true("; ".join(LookConfig.validate(body_unknown_action, looks)).contains("body_motions.%s.actions.fly" % set_id))
	var no_seconds := parts.duplicate(true)
	var one_shot_name: String = (parts["body_motions"][set_id]["one_shots"] as Dictionary).keys()[0]
	no_seconds["body_motions"][set_id]["one_shots"][one_shot_name].erase("seconds")
	assert_true("; ".join(LookConfig.validate(no_seconds, looks)).contains("one_shots.%s.seconds" % one_shot_name))
	var no_lean := parts.duplicate(true)
	no_lean["body_motions"][set_id].erase("steer_lean_deg")
	assert_true("; ".join(LookConfig.validate(no_lean, looks)).contains("steer_lean_deg"))
	# 個体が、一覧に無い動かし方を選んでいる。倍率が足りない。
	var first_id: String = (looks["looks"] as Dictionary).keys()[0]
	var unknown_set := looks.duplicate(true)
	unknown_set["looks"][first_id]["body_motion"]["set"] = "floaty"
	assert_true("; ".join(LookConfig.validate(parts, unknown_set)).contains("%s.body_motion.set" % first_id))
	var no_amount := looks.duplicate(true)
	no_amount["looks"][first_id]["body_motion"].erase("amount")
	assert_true("; ".join(LookConfig.validate(parts, no_amount)).contains("%s.body_motion.amount" % first_id))


func test_config_errors_stop_the_load_instead_of_using_another_shape() -> void:
	var parts := _raw(SWAP_PARTS)
	var looks := _raw(SWAP_LOOKS)
	assert_eq(LookConfig.validate(parts, looks).size(), 0)
	# 無いファイル
	var missing_file := parts.duplicate(true)
	missing_file["parts"]["test_top_crystal"]["source"]["path"] = "res://test/fixtures/pururin/none.glb"
	assert_true("; ".join(LookConfig.validate(missing_file, looks)).contains("ファイルがありません"))
	# 知らない部品
	var unknown_part := looks.duplicate(true)
	unknown_part["looks"]["base"]["top"]["part"] = "no_such_part"
	assert_true("; ".join(LookConfig.validate(parts, unknown_part)).contains("部品の一覧にありません"))
	# スロットの合わない部品（目の部品を、頭の上に）
	var wrong_slot := looks.duplicate(true)
	wrong_slot["looks"]["base"]["top"]["part"] = "eyes_round"
	assert_true("; ".join(LookConfig.validate(parts, wrong_slot)).contains("用の部品ではありません"))
	# ノーマルの顔が無い
	var no_normal := looks.duplicate(true)
	no_normal["looks"]["base"]["face"]["expressions"].erase("normal")
	assert_true("; ".join(LookConfig.validate(parts, no_normal)).contains("ノーマルの表情"))
	# 足りない数字、こちらで作れない形
	var missing_number := parts.duplicate(true)
	missing_number["parts"]["nub_drop"]["source"].erase("lean")
	assert_true("; ".join(LookConfig.validate(missing_number, looks)).contains("nub_drop.source.lean"))
	var unknown_shape := parts.duplicate(true)
	unknown_shape["parts"]["nub_drop"]["source"]["shape"] = "horn"
	assert_true("; ".join(LookConfig.validate(unknown_shape, looks)).contains("使える形"))
	# 色の書き間違い、未知の項目
	var bad_color := looks.duplicate(true)
	bad_color["looks"]["base"]["secondary_color"] = "blue-ish"
	assert_true("; ".join(LookConfig.validate(parts, bad_color)).contains("secondary_color"))
	var bad_index := looks.duplicate(true)
	bad_index["looks"]["base"]["primary_color_index"] = "blue"
	assert_true("; ".join(LookConfig.validate(parts, bad_index)).contains("primary_color_index"))
	var unknown_key := looks.duplicate(true)
	unknown_key["looks"]["base"]["hat"] = "cap"
	assert_true("; ".join(LookConfig.validate(parts, unknown_key)).contains("未知の項目"))


func _body_space_bounds(node: Node3D) -> AABB:
	return node.transform * (node as MeshInstance3D).mesh.get_aabb()


func test_every_look_in_the_game_builds_with_all_its_body_parts() -> void:
	var config := _game_config()
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var expected := 0
		for slot: String in ["top", "sides", "tail"]:
			if look[slot] != null:
				expected += 2 if slot == "sides" else 1
		var nodes: Array = body.call("body_part_nodes")
		assert_eq(nodes.size(), expected, id)
		for node: Node3D in nodes:
			var mesh := (node as MeshInstance3D).mesh
			assert_gt(mesh.get_faces().size(), 0, "%s の %s に、形がある" % [id, node.name])


func test_every_builtin_shape_is_used_by_a_part_in_the_catalogue() -> void:
	var config := _game_config()
	var used := {}
	for part: Dictionary in (config["parts"] as Dictionary).values():
		if str(part["kind"]) == "body_part" and str(part["source"]["type"]) == "builtin":
			used["%s/%s" % [part["slot"], part["source"]["shape"]]] = true
	for slot: String in BodyParts.BUILTIN_SHAPES:
		for shape: String in BodyParts.BUILTIN_SHAPES[slot]:
			assert_true(used.has("%s/%s" % [slot, shape]), "%s の %s を使う部品が、一覧にある" % [slot, shape])


func test_left_and_right_side_parts_are_mirror_images() -> void:
	var config := _game_config()
	for id: String in config["looks"]:
		var body: Node3D = Builder.build(config["looks"][id], config)
		add_child_autofree(body)
		var right := _body_space_bounds(body.get_node("SideR"))
		var left := _body_space_bounds(body.get_node("SideL"))
		# 左の箱を、体のまん中（x=0）で折り返すと、右の箱に重なる。
		assert_almost_eq(-left.end.x, right.position.x, 0.001, id)
		assert_almost_eq(-left.position.x, right.end.x, 0.001, id)
		assert_almost_eq(left.position.y, right.position.y, 0.001, id)
		assert_almost_eq(left.end.y, right.end.y, 0.001, id)
		assert_almost_eq(left.position.z, right.position.z, 0.001, id)
		assert_almost_eq(left.end.z, right.end.z, 0.001, id)


func test_body_parts_start_on_the_body_and_stick_out() -> void:
	var config := _game_config()
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var height := float(look["body"]["height"])
		# 頭の上の部品：付け根は頭のてっぺん、先はそれより上。
		var top := body.get_node("Top") as Node3D
		assert_almost_eq(top.position.y, height, 0.0001, id)
		assert_gt(_body_space_bounds(top).end.y, height + 0.05, id)
		# 左右の部品：体の横（半径0.75m）より外へ出る。尾は、後ろへ出る。
		assert_gt(_body_space_bounds(body.get_node("SideR")).end.x, Surface.BODY_RADIUS + 0.05, id)
		assert_gt(_body_space_bounds(body.get_node("Tail")).end.z, Surface.BODY_RADIUS + 0.05, id)
		# 明るさと第二カラーの高さを、体とそろえるための値。
		assert_almost_eq(float((top as MeshInstance3D).get_instance_shader_parameter("part_y")), height, 0.0001, id)


func test_the_finish_of_a_look_sets_the_body_material() -> void:
	var config := _game_config()
	var seen := {}
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var finish: Dictionary = config["finishes"][str(look["finish"])]
		seen[str(look["finish"])] = true
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var material := body.call("body_material") as ShaderMaterial
		for key: String in Builder.FINISH_NUMBER_KEYS:
			assert_almost_eq(float(material.get_shader_parameter(key)), float(finish[key]), 0.0001, "%s %s" % [id, key])
		assert_eq(material.get_shader_parameter("primary"), Color(str(look["primary_color"])), id)
	for finish_id: String in config["finishes"]:
		assert_true(seen.has(finish_id), "質感 %s を使う個体がある" % finish_id)


func test_finish_and_part_override_errors_stop_the_load() -> void:
	var parts := _raw(LookConfig.PARTS_PATH)
	var looks := _raw(LookConfig.LOOKS_PATH)
	assert_eq(LookConfig.validate(parts, looks).size(), 0)
	var first_id: String = (looks["looks"] as Dictionary).keys()[0]
	# 質感の一覧に無い名前
	var unknown_finish := looks.duplicate(true)
	unknown_finish["looks"][first_id]["finish"] = "chrome"
	assert_true("; ".join(LookConfig.validate(parts, unknown_finish)).contains("質感の一覧にありません"))
	# 質感の数字が足りない
	var missing_number := parts.duplicate(true)
	(missing_number["finishes"] as Dictionary).values()[0].erase("roughness")
	assert_true("; ".join(LookConfig.validate(missing_number, looks)).contains("roughness"))
	# 部品の色が足りない
	for part_id: String in parts["parts"]:
		var source: Dictionary = parts["parts"][part_id]["source"]
		for key: String in BodyParts.REQUIRED_COLORS.get(str(source.get("shape", "")), []):
			var missing_color := parts.duplicate(true)
			missing_color["parts"][part_id]["source"].erase(key)
			assert_true("; ".join(LookConfig.validate(missing_color, looks)).contains("%s.source.%s" % [part_id, key]), part_id)
	# 個体ごとの上書きが、数字でない
	var bad_override := looks.duplicate(true)
	var top_part := str(bad_override["looks"][first_id]["top"]["part"])
	var number_key: String = BodyParts.REQUIRED_PARAMS[str(parts["parts"][top_part]["source"]["shape"])][0]
	bad_override["looks"][first_id]["top"]["params"][number_key] = "big"
	assert_true("; ".join(LookConfig.validate(parts, bad_override)).contains("%s.top.params.source.%s" % [first_id, number_key]))


func test_every_pururin_in_the_roster_has_a_look_with_a_colour_of_its_attribute() -> void:
	var config := _game_config()
	var attributes: Dictionary = StatsConfig.values()["attributes"]
	var roster: Array = RosterConfig.values()["roster"]
	assert_eq((config["looks"] as Dictionary).size(), roster.size())
	for pururin: Dictionary in roster:
		var id := str(pururin["id"])
		var look := LookConfig.look_for(id)
		var choice: Dictionary = attributes[str(pururin["attribute"])]["primary_colors"][int(look["primary_color_index"])]
		assert_eq(look["primary_color"], choice["color"], id)
		assert_eq(look["outline_color"], choice["outline"], id)
		# 操作盤・順位表などの丸の色も、体の色と同じ所から来る。
		assert_eq(VisualStyle.color_for_pururin(pururin), Color(str(choice["color"])), id)
		assert_eq(VisualStyle.color_for_racer_id(id), Color(str(choice["color"])), id)
		assert_false(pururin.has("visual_color"), "個体一覧には、色を持たせない")


func test_two_pururins_of_the_same_attribute_do_not_share_a_colour_or_a_height() -> void:
	var config := _game_config()
	var seen := {}
	for pururin: Dictionary in RosterConfig.values()["roster"]:
		var look: Dictionary = config["looks"][str(pururin["id"])]
		var color_key := "%s/%s" % [pururin["attribute"], look["primary_color"]]
		var height_key := "%s/%s" % [pururin["attribute"], look["body"]["height"]]
		assert_false(seen.has(color_key), "%s：同じ属性で、同じ色の個体がいる" % pururin["id"])
		assert_false(seen.has(height_key), "%s：同じ属性で、同じ高さの個体がいる" % pururin["id"])
		seen[color_key] = true
		seen[height_key] = true


func test_roster_mismatches_stop_the_load() -> void:
	var raw := LookConfig.load_files()
	var roster: Array = RosterConfig.values()["roster"]
	var attributes: Dictionary = StatsConfig.values()["attributes"]
	assert_eq(LookConfig.validate_for_roster(raw["looks"], roster, attributes).size(), 0)
	var first := str(roster[0]["id"])
	# 見た目の無い個体
	var missing: Dictionary = (raw["looks"] as Dictionary).duplicate(true)
	missing.erase(first)
	assert_true("; ".join(LookConfig.validate_for_roster(missing, roster, attributes)).contains("looks.%s" % first))
	# 個体一覧に無い見た目
	var extra: Dictionary = (raw["looks"] as Dictionary).duplicate(true)
	extra["nobody"] = extra[first]
	assert_true("; ".join(LookConfig.validate_for_roster(extra, roster, attributes)).contains("looks.nobody"))
	# 選択肢に無い番号
	var out_of_range: Dictionary = (raw["looks"] as Dictionary).duplicate(true)
	out_of_range[first]["primary_color_index"] = (attributes[str(roster[0]["attribute"])]["primary_colors"] as Array).size()
	assert_true("; ".join(LookConfig.validate_for_roster(out_of_range, roster, attributes)).contains("primary_color_index"))


func test_runners_in_the_race_wear_the_body_of_their_own_look() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var runners: Array = race.call("get_runners_for_simulation")
	assert_eq(runners.size(), RaceSession.SLOT_COUNT)
	for runner: Node3D in runners:
		var id := str(runner.call("get_snapshot")["id"])
		var look := LookConfig.look_for(id)
		var body := runner.get_node("Body") as Node3D
		assert_true(body.get_script() == PururinBody, id)
		# 足元が走者の位置。体の色と高さは、その個体の設定どおり。
		assert_eq(body.position, Vector3.ZERO, id)
		assert_eq((body.call("body_material") as ShaderMaterial).get_shader_parameter("primary"), Color(str(look["primary_color"])), id)
		assert_almost_eq((body.get_node("Top") as Node3D).position.y, float(look["body"]["height"]), 0.0001, id)


func test_contact_makes_the_body_glow_and_squash_without_leaving_the_ground() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var runner: Node3D = (race.call("get_runners_for_simulation") as Array)[0]
	var body := runner.get_node("Body") as Node3D
	runner.call("set_race_active", true)
	runner.set("_contact_count", 1)
	runner.set("_in_push_contest", true)
	# 光り方と、体の動きが、目標へ追いつくまで、何回か進める。
	var narrowest := 1.0
	for _step in 60:
		runner.call("_update_contact_visual", 1.0 / 60.0)
		runner.call("_update_action", 1.0 / 60.0)
		body.call("advance_motion", 1.0 / 60.0)
		narrowest = minf(narrowest, _dome_transform(body).basis.get_scale().x)
		assert_gte(_dome_transform(body).origin.y, -0.0001, "足元は、地面のまま")
	var level := float(runner.get("_contact_level"))
	assert_almost_eq(level, ContactFeedback.LEVEL_PUSH, 0.01)
	assert_almost_eq(float(body.call("glow")), ContactFeedback.glow_energy(level), 0.0001)
	assert_eq(body.call("action"), "push")
	assert_lt(narrowest, 0.95, "横につぶれる")
	assert_gt(_dome_transform(body).basis.get_scale().y, 1.0, "上下にふくらむ")
	# 体の節そのものは、動かさない（走者が置いた場所のまま）。
	assert_eq(body.transform, Transform3D.IDENTITY)
	# 離れたら、光りが消える。
	runner.set("_contact_count", 0)
	runner.set("_in_push_contest", false)
	for _step in 120:
		runner.call("_update_contact_visual", 1.0 / 60.0)
		runner.call("_update_action", 1.0 / 60.0)
		body.call("advance_motion", 1.0 / 60.0)
	assert_almost_eq(float(body.call("glow")), 0.0, 0.001)
	assert_ne(body.call("action"), "push")


func _portrait(live: bool) -> Control:
	var portrait: Control = Portrait.new()
	portrait.set("live", live)
	portrait.size = Vector2(148, 148)
	add_child_autofree(portrait)
	return portrait


func test_the_big_portrait_turns_slowly_and_changes_face_each_time_its_back_is_shown() -> void:
	var showcase := LookConfig.showcase()
	var expressions: Array = showcase["expressions"]
	var turn_seconds := float(showcase["turn_seconds"])
	var roster: Array = RosterConfig.values()["roster"]
	var portrait := _portrait(true)
	portrait.call("set_pururin", roster[0])
	# 正面・最初の表情から始まる。
	assert_almost_eq(float(portrait.call("turn_angle")), 0.0, 0.0001)
	assert_eq(portrait.call("shown_expression"), expressions[0])
	# 4分の1回転：まだ同じ表情。
	portrait.call("advance", turn_seconds * 0.25)
	assert_almost_eq(float(portrait.call("turn_angle")), TAU * 0.25, 0.0001)
	assert_eq(portrait.call("shown_expression"), expressions[0])
	# 半回転をこえた（背中がこちら）：次の表情。1回転して正面に戻っても、そのまま。
	portrait.call("advance", turn_seconds * 0.3)
	assert_eq(portrait.call("shown_expression"), expressions[1])
	portrait.call("advance", turn_seconds * 0.5)
	assert_eq(portrait.call("shown_expression"), expressions[1])
	# 一覧の最後まで出したら、最初に戻る。
	for _turn in expressions.size() - 1:
		portrait.call("advance", turn_seconds * 0.5)
		portrait.call("advance", turn_seconds * 0.5)
	assert_eq(portrait.call("shown_expression"), expressions[0])
	# 別の個体に替えたら、正面・最初の表情からやり直す。
	portrait.call("advance", turn_seconds * 0.6)
	portrait.call("set_pururin", roster[1])
	assert_almost_eq(float(portrait.call("turn_angle")), 0.0, 0.0001)
	assert_eq(portrait.call("shown_expression"), expressions[0])
	# 空にしたら、体を出さない。
	portrait.call("set_pururin", {})
	assert_eq(portrait.call("shown_expression"), "")


func test_small_portraits_use_one_picture_per_pururin() -> void:
	var roster: Array = RosterConfig.values()["roster"]
	var first: Texture2D = PortraitCache.texture_for(str(roster[0]["id"]), get_tree())
	assert_not_null(first)
	assert_eq(first.get_width(), PortraitCache.SIZE_PX)
	# 同じ個体は、同じ絵を使い回す。別の個体は、別の絵。
	assert_eq(PortraitCache.texture_for(str(roster[0]["id"]), get_tree()), first)
	assert_ne(PortraitCache.texture_for(str(roster[1]["id"]), get_tree()), first)
	# 小さい絵は、回さない（体を持たない）。
	var portrait := _portrait(false)
	portrait.call("set_pururin", roster[0])
	assert_eq(portrait.call("shown_expression"), "")


func test_showcase_errors_stop_the_load() -> void:
	var parts := _raw(LookConfig.PARTS_PATH)
	var looks := _raw(LookConfig.LOOKS_PATH)
	var no_speed := looks.duplicate(true)
	no_speed["showcase"]["turn_seconds"] = 0
	assert_true("; ".join(LookConfig.validate(parts, no_speed)).contains("showcase.turn_seconds"))
	var no_faces := looks.duplicate(true)
	no_faces["showcase"]["expressions"] = []
	assert_true("; ".join(LookConfig.validate(parts, no_faces)).contains("showcase.expressions"))
	var typo := looks.duplicate(true)
	typo["showcase"]["expressions"] = ["normal", "smile"]
	assert_true("; ".join(LookConfig.validate(parts, typo)).contains("smile"))


func test_second_colour_is_painted_on_the_body_only_up_to_the_height_in_the_look() -> void:
	var config := _game_config()
	var with_second_colour := 0
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var material := body.call("body_material") as ShaderMaterial
		assert_almost_eq(float(material.get_shader_parameter("secondary_top")), float(look["body"]["height"]) * float(look["secondary_top_ratio"]), 0.0001, id)
		assert_eq(material.get_shader_parameter("secondary"), Color(str(look["secondary_color"])), id)
		if float(look["secondary_top_ratio"]) > 0.0:
			with_second_colour += 1
		# 頭の上・左右・尾の部品には、第二カラーを塗らない。体の本体には塗る。
		for node: Node3D in body.call("body_part_nodes"):
			assert_eq(float((node as MeshInstance3D).get_instance_shader_parameter("secondary_band")), 0.0, "%s %s" % [id, node.name])
		assert_null((body.get_node("Dome") as MeshInstance3D).get_instance_shader_parameter("secondary_band"), "体の本体は、初めの値（塗る）のまま")
	assert_gt(with_second_colour, 0, "第二カラーを使う個体がいる")


func test_marks_in_the_look_are_put_on_the_body() -> void:
	var config := _game_config()
	var with_marks := 0
	for id: String in config["looks"]:
		var look: Dictionary = config["looks"][id]
		var body: Node3D = Builder.build(look, config)
		add_child_autofree(body)
		var marks: Array = look["marks"]
		for index in marks.size():
			var node := body.get_node_or_null("Mark%d" % index) as MeshInstance3D
			assert_not_null(node, "%s のマーク %d" % [id, index])
			# マークは、設定した高さのあたりに付く。
			var center := node.mesh.get_aabb().get_center()
			assert_almost_eq(center.y, float(look["body"]["height"]) * float(marks[index]["height_ratio"]), float(marks[index]["size"]), "%s のマーク %d の高さ" % [id, index])
		assert_null(body.get_node_or_null("Mark%d" % marks.size()), id)
		if not marks.is_empty():
			with_marks += 1
	assert_gt(with_marks, 0, "マークを付けた個体がいる")


func test_every_pururin_wears_its_own_kind_of_mark() -> void:
	var config := _game_config()
	var seen := {}
	for id: String in config["looks"]:
		var marks: Array = config["looks"][id]["marks"]
		assert_gt(marks.size(), 0, "%s に、マークがある" % id)
		# 選択肢が増えても既存部品を再利用できる。種類・色・配置の組合せで識別する。
		var kind := JSON.stringify(marks)
		assert_false(seen.has(kind), "%s のマークは、ほかの個体と同じ種類" % id)
		seen[kind] = true
