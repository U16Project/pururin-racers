extends SceneTree
## 強化学習：書き出した育てたCPU（client/data/cpu_brains/）が、Python と同じ操作を選ぶかの確かめ。
## export_brain.py が書いた lab/rl/runs/brain_check.json の場面を、ゲーム側の計算（brain_net.gd）で解いて比べる。
## 起動（client/ で）：godot --headless -s ../lab/rl/brain_check.gd

const BrainNet := preload("res://scripts/cpu_brain/brain_net.gd")


func _initialize() -> void:
	var check: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../lab/rl/runs/brain_check.json")))
	var net: RefCounted = BrainNet.load_file(str(check["brain"]))
	var same := 0
	var cases: Array = check["cases"]
	var started := Time.get_ticks_usec()
	for case: Dictionary in cases:
		var obs := PackedFloat32Array(case["obs"])
		var mask := PackedByteArray(case["mask"])
		var action: Array = net.act(obs, mask)
		var expected: Array = (case["action"] as Array).map(func(a): return int(a))
		if action == expected:
			same += 1
		elif cases.size() - same <= 5:
			print("ちがう：Python %s ／ ゲーム %s" % [expected, action])
	var per_ms := (Time.get_ticks_usec() - started) / 1000.0 / maxf(float(cases.size()), 1.0)
	print("%s：%d場面のうち、同じ操作 %d（1回 %.2f ms）" % [net.label, cases.size(), same, per_ms])
	quit(0 if same == cases.size() else 1)
