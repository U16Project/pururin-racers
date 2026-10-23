extends SceneTree
## 強化学習：画面なしのゴドー1つぶん。Python の指示で、レースを1本ずつ走らせる。
## 起動：godot --headless --fixed-fps 30 --path client -s ../lab/rl/rl_worker.gd -- port=<Python が待つ番号> field=<出る数>
## つながったら、最初に {"obs_size", "action_sizes"} を送る（Python が、見るものと操作の大きさを知るため）。
## Python からの指示（1行に1つの JSON）：
##   {"cmd": "reset", "spec": {seed, distance_m, lineup, focus_gate, baseline}, "settings": rl_settings.json の中身}
##   {"cmd": "step", "action": [ノッチ, ライン, ブレーキ, ダッシュ, ブースト]}（レースの途中だけ）
##   {"cmd": "close"}

const RlLink := preload("rl_link.gd")
const RlRace := preload("rl_race.gd")
const RlObserve := preload("rl_observe.gd")

var _link := RlLink.new()
var _current: Node


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	if not _link.open(int(args.get("port", "0"))):
		push_error("Python につながりませんでした")
		quit(1)
		return
	_link.send({"obs_size": RlObserve.size(int(args.get("field", "8"))), "action_sizes": RlObserve.ACTION_SIZES})
	_next.call_deferred()


## 次の指示を待って、レースを作る。
func _next() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var message: Dictionary = _link.receive()
	if message.is_empty() or str(message.get("cmd", "")) == "close":
		quit()
		return
	if str(message["cmd"]) != "reset":
		push_error("レースの外で、reset 以外の指示が来ました: " + str(message["cmd"]))
		quit(1)
		return
	_current = RlRace.new()
	root.add_child(_current)
	_current.race_done.connect(func(): _next.call_deferred())
	_current.start(_link, message["spec"], message["settings"])
	if not _current.is_ok():
		push_error("レースを作れませんでした")
		quit(1)
