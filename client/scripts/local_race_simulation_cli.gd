extends SceneTree
## Godot headless CLI: --script scripts/local_race_simulation_cli.gd -- --scenario notch4_cruise

const Simulator := preload("res://scripts/local_race_simulator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# SceneTree に root が入った後に実行し、Node3D の通常のライフサイクルを保つ。
	await process_frame
	var scenario_id := "notch4_cruise"
	var user_args := OS.get_cmdline_user_args()
	for index in user_args.size():
		if user_args[index] == "--scenario" and index + 1 < user_args.size():
			scenario_id = user_args[index + 1]
	var simulator := Simulator.new()
	var result: Dictionary = simulator.run_scenario_by_id(get_root(), scenario_id)
	print(JSON.stringify(result))
	quit(1 if result.has("error") else 0)
