extends SceneTree
## CPU育成ラボ：画面なしで、仕事のファイルに書かれたレースを、1本ずつ順に走らせて、結果をファイルに書く。
## 起動：godot --headless --fixed-fps 30 --path client -s ../lab/lab_worker.gd -- job=<仕事のファイル> out=<結果のファイル>
## 仕事のファイル：{settings, brains: {頭の名前: 頭}, races: [spec, …]}（spec は lab_race.gd の start を見る）。

const LabRace := preload("lab_race.gd")

var _job: Dictionary
var _out_path := ""
var _results: Array = []
var _index := 0
var _current: Node


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var file := FileAccess.open(str(args["job"]), FileAccess.READ)
	_job = JSON.parse_string(file.get_as_text())
	_out_path = str(args["out"])
	_next.call_deferred()


func _next() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var races: Array = _job["races"]
	if _index >= races.size():
		_write(_out_path)
		quit()
		return
	_current = LabRace.new()
	root.add_child(_current)
	_current.race_done.connect(_on_race_done)
	_current.start(races[_index], _job["brains"], _job["settings"])
	if not _current.is_ok():
		push_error("レースを作れませんでした")
		quit(1)


func _on_race_done(result: Dictionary) -> void:
	_results.append(result)
	_index += 1
	# 途中の結果も書いておく（ラボの画面で、進み具合を見られるように）。
	_write(_out_path + ".part")
	_next.call_deferred()


func _write(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_results))
	file.close()
