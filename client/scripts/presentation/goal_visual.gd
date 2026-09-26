extends RefCounted
## ゴールの共通演出。配置先Path・距離・コース幅を受け取り、再配置時もノードを再利用する。
## 生成ノードの寿命は配置先Pathが所有する。
var _track: Path3D
var _path_distance: float
var _width: float
var _goal_sign: Label3D
var _goal_glow_line: MeshInstance3D
var _goal_panel: MeshInstance3D
var _goal_panel_frame: Node3D

func place(track: Path3D, path_distance: float, width_m: float) -> void:
	assert(track != null and width_m > 0.0)
	assert(_track == null or _track == track, "GoalVisualは配置先Pathごとに作成してください")
	_track = track
	_path_distance = path_distance
	_width = width_m
	_place_goal_glow_line()
	_place_goal_fx()


func _place_goal_fx() -> void:
	if _track == null or _track.curve == null:
		return
	var curve_xf := _track.curve.sample_baked_with_rotation(_path_distance)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	if _goal_panel == null:
		_goal_panel = MeshInstance3D.new()
		_goal_panel.name = "GoalPanel"
		_track.add_child(_goal_panel)
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(_width + 4.0, 4.0, 0.08)
	_goal_panel.mesh = panel_mesh
	var panel_material := StandardMaterial3D.new()
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel_material.albedo_color = Color(0.08, 0.68, 0.34, 0.055)
	panel_material.emission_enabled = true
	panel_material.emission = Color(0.04, 0.92, 0.34)
	panel_material.emission_energy_multiplier = 5.5
	_goal_panel.material_override = panel_material
	var goal_transform := _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 2.0
	)
	_goal_panel.global_transform = goal_transform
	if _goal_panel_frame != null:
		_goal_panel_frame.free()
		_goal_panel_frame = null
	if _goal_panel_frame == null:
		_goal_panel_frame = Node3D.new()
		_goal_panel_frame.name = "GoalPanelFrame"
		_track.add_child(_goal_panel_frame)
		var frame_material := StandardMaterial3D.new()
		frame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		frame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		frame_material.albedo_color = Color(0.03, 0.58, 0.24, 0.9)
		frame_material.emission_enabled = true
		frame_material.emission = Color(0.02, 1.0, 0.32)
		frame_material.emission_energy_multiplier = 7.0
		_make_goal_panel_frame_bar(
			"Top", Vector3(_width + 4.4, 0.1, 0.12), Vector3(0.0, 2.05, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Bottom", Vector3(_width + 4.4, 0.1, 0.12), Vector3(0.0, -2.05, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Left", Vector3(0.1, 4.0, 0.12), Vector3(-(_width + 4.3) * 0.5, 0.0, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Right", Vector3(0.1, 4.0, 0.12), Vector3((_width + 4.3) * 0.5, 0.0, 0.0), frame_material
		)
	_goal_panel_frame.global_transform = goal_transform * Transform3D(
		Basis.IDENTITY, Vector3(0.0, 0.0, 0.06)
	)
	if _goal_sign == null:
		_goal_sign = Label3D.new()
		_goal_sign.name = "GoalSign"
		_goal_sign.text = "GOAL"
		_goal_sign.font_size = 720
		_goal_sign.pixel_size = 0.008
		_goal_sign.modulate = Color(0.92, 1.0, 0.86, 1.0)
		_goal_sign.outline_size = 160
		_goal_sign.outline_modulate = Color(0.01, 0.08, 0.16, 1.0)
		_goal_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_track.add_child(_goal_sign)
	_goal_sign.pixel_size = 0.008 * _width / 15.0
	_goal_sign.global_transform = goal_transform * Transform3D(
		Basis.IDENTITY, Vector3(0.0, 6.4, 0.05)
	)


func _place_goal_glow_line() -> void:
	if _track == null or _track.curve == null:
		return
	if _goal_glow_line == null:
		_goal_glow_line = MeshInstance3D.new()
		_goal_glow_line.name = "GoalGlowLine"
		_track.add_child(_goal_glow_line)
	var curve_xf := _track.curve.sample_baked_with_rotation(_path_distance)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(_width, 0.08, 0.7)
	_goal_glow_line.mesh = glow_box
	var glow_material := StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(0.08, 0.78, 0.62, 0.66)
	glow_material.emission_enabled = true
	glow_material.emission = Color(0.04, 1.0, 0.68)
	glow_material.emission_energy_multiplier = 14.0
	_goal_glow_line.material_override = glow_material
	_goal_glow_line.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 0.22
	)


func _make_goal_panel_frame_bar(
	bar_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D
) -> void:
	var bar := MeshInstance3D.new()
	bar.name = bar_name
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = size
	bar.mesh = bar_mesh
	bar.material_override = material
	bar.position = local_position
	_goal_panel_frame.add_child(bar)
