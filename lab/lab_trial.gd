extends SceneTree
## CPU育成ラボ：頭をいくつか、同じ組み合わせのレースで走らせて、点を付ける（試し走り）。
## 頭は、そのぷるりんに乗り、ほかの7席は今までのCPU。比べる目安に、同じレースで同じぷるりんを今までのCPUが走らせたときの点も出す。
## 起動（client/ で）：godot --headless --path . -s ../lab/lab_trial.gd -- races=10 seed=1 out=trial1 brains=<頭のファイル>,…
## 結果：client/lab/runs/<out>/report.json と results.json（レースごと）。

const KnobBrain := preload("knob_brain.gd")
const LabScore := preload("lab_score.gd")
const LabBatch := preload("lab_batch.gd")

var _batch: LabBatch


func _initialize() -> void:
	var args := LabBatch.user_args()
	var brains := {}
	for path in str(args["brains"]).split(",", false):
		var brain := KnobBrain.load_file(path)
		brains[str(brain["id"])] = brain
	_batch = LabBatch.new(LabScore.load_settings(), LabScore.lab_dir().path_join("runs/%s" % str(args["out"])))
	var jobs := _batch.make_trial_jobs(brains, int(args["races"]), int(args["seed"]))
	_batch.launch(brains, jobs)
	print("レース %d 本を走らせます" % jobs.size())


func _process(_delta: float) -> bool:
	if _batch.is_running():
		return false
	var results := _batch.collect()
	var table := _batch.score_table(results)
	LabBatch.save_json(_batch.out_dir.path_join("results.json"), results)
	LabBatch.save_json(_batch.out_dir.path_join("report.json"), {"seconds": _batch.seconds(), "races": results.size(), "score_weights": _batch.settings["score"], "table": table})
	print("%d 本、%.0f 秒" % [results.size(), _batch.seconds()])
	LabBatch.print_table(table)
	return true
