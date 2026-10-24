extends SceneTree
## 強化学習：あなたがオフラインで走った記録（ゲームの記録ファイル）を、お手本の束に直す。レースは走らせない。
## 記録の0.5秒ごとの場面から「頭が見るもの（rl_observe と同じ並び）・選べる操作・あなたがした操作」の組を作る。
## 記録1本ごとに、1つのファイルに書く（作ったものは作り直さない。新しい記録だけ足す）。
## 起動（client/ で）：godot --headless --path . -s ../lab/rl/rl_demos.gd -- out=<書く場所> since=<この日時より後の記録>
## 使う記録：since より後に保存され、あなたが操作して、ゴールまで走ったレース（ぷるりん・距離は問わない）。
## ふつうのオフラインのレースも、ラボで育てるCPUと走ったレース（play.py）も、同じ置き場に記録が残るので、どちらも使う。
## 育てるCPUの席は、記録の remote_controlled（通信ごしに操作）で見分けて外す。
## こわれた記録・古い形の記録・途中でやめたレースは外す。使った・外した記録の一覧を <書く場所>/_index.json に書く。

const RlObserve := preload("rl_observe.gd")
const LabSituation := preload("../lab_situation.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")

const LOG_DIR := "user://pururin_race_logs"
## 記録の1体ぶんに、これが全部ないと使わない（古い形の記録）。
const NEEDED := ["race_progress", "offset", "speed", "actual_speed_kmh", "heart_rate_bpm", "stamina_ratio", "drive_level", "boost_uses_left",
	"dash_active", "boost_points", "draft", "in_push_contest", "contact_heart_load_bpm_per_s", "overheat_ratio",
	"overheat_propulsion_efficiency", "propulsion_efficiency", "braking", "effective_stats", "gate", "finished", "stamina", "stamina_capacity_l"]
const SETTINGS_PATH := "../lab/rl/rl_settings.json"


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(SETTINGS_PATH)))
	var out_dir := str(args["out"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	# since は、このPCの時刻で書く。ファイルの時刻（世界共通の秒）と比べるため、時差を引く。
	var since_unix := Time.get_unix_time_from_datetime_string(str(args["since"])) - int(Time.get_time_zone_from_system()["bias"]) * 60
	var dir := ProjectSettings.globalize_path(LOG_DIR)
	var made := 0
	var kept := 0
	# どの記録を使ったか・外したか（報告の表に使う）。記録の名前 → {使ったか, 外した理由, ぷるりん, 距離, 着順}。
	var index := {}
	for name in DirAccess.get_files_at(dir):
		var path := dir.path_join(name)
		if not name.ends_with(".json") or FileAccess.get_modified_time(path) < since_unix:
			continue
		var target := out_dir.path_join(name)
		if FileAccess.file_exists(target):
			var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(target))
			if old is Dictionary:
				index[name] = {"used": true, "reason": "", "pururin": old["pururin"], "distance_m": old["distance_m"], "place": old.get("place", 0)}
				kept += 1
				continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var checked := _check(data)
		if not str(checked["reason"]).is_empty():
			index[name] = checked.merged({"used": false})
			continue
		var demo := _demo(data, settings, str(checked["player_id"]))
		if demo.is_empty():
			index[name] = checked.merged({"used": false, "reason": "使える場面がない"}, true)
			continue
		demo["place"] = checked["place"]
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_string(JSON.stringify(demo))
		file.close()
		checked.erase("player_id")
		index[name] = checked.merged({"used": true})
		made += 1
	var index_file := FileAccess.open(out_dir.path_join("_index.json"), FileAccess.WRITE)
	index_file.store_string(JSON.stringify(index, " "))
	index_file.close()
	print("お手本：新しく %d 本、前からの %d 本、外した %d 本" % [made, kept, index.size() - made - kept])
	quit()


## 記録を使えるか。使えなければ reason に外す理由（こわれた・古い形・人が操作していない・途中でやめた）。
static func _check(data: Variant) -> Dictionary:
	var out := {"reason": "", "pururin": "", "distance_m": 0.0, "place": 0}
	if not data is Dictionary or (data.get("samples", []) as Array).is_empty() or not data.has("race_distance_m"):
		out["reason"] = "こわれた記録"
		return out
	out["distance_m"] = float(data["race_distance_m"])
	var runners: Array = data["samples"][0].get("runners", [])
	if runners.is_empty() or not (runners[0] as Dictionary).has_all(NEEDED):
		out["reason"] = "古い形の記録"
		return out
	# 「人が操作」でも、通信ごしに操作されている席（ラボで走らせた、育てるCPUの席）は、人ではない。
	var players: Array = runners.filter(func(r): return bool(r.get("player", false)) and not bool(r.get("remote_controlled", false))).map(func(r): return str(r["id"]))
	if players.is_empty():
		out["reason"] = "人が操作していない"
		return out
	var player_id := str(players[0])
	out["player_id"] = player_id
	out["pururin"] = player_id.split("#")[0]
	for result: Dictionary in data.get("final_results", []):
		if str(result.get("id", "")) == player_id:
			out["place"] = int(result.get("finish_order", -1))
	if int(out["place"]) <= 0:
		out["reason"] = "途中でやめた（ゴールしていない）"
	return out


## 1本の記録から、お手本の組の並び。player_id＝あなたが操作した走者。
func _demo(data: Dictionary, settings: Dictionary, player_id: String) -> Dictionary:
	var samples: Array = data["samples"]
	var distance := float(data["race_distance_m"])
	var path3d := Path3D.new()
	LocalRaceMath.apply_course_to_path(path3d)
	var route := CourseBuilder.route_for_distance(LocalRaceMath.course_layout(), distance)
	var inside := LabSituation.inside_sign(path3d.curve)
	var threshold := float(settings["demo"]["line_threshold_m"])
	var obs: Array = []
	var masks: Array = []
	var actions: Array = []
	for i in range(samples.size() - 1):
		var me := _find(samples[i], player_id)
		var next := _find(samples[i + 1], player_id)
		if me.is_empty() or next.is_empty() or bool(me["finished"]):
			break
		# スタートの前（まだ動いていない間）は、操作がないので使わない。
		if float(samples[i]["elapsed_s"]) <= 0.0:
			continue
		var others: Array = (samples[i]["runners"] as Array).filter(func(r): return str(r["id"]) != player_id)
		var ctx := {
			"distance_m": distance, "elapsed_s": float(samples[i]["elapsed_s"]), "curve": path3d.curve, "route": route,
			"inside": inside, "field": int(settings["field"]), "scales": settings["observe"],
		}
		# ブレーキ中の記録は、ノッチの段が0に見えるので、ノッチはどれでも選べたことにする。
		var braking := bool(me["braking"]) or bool(next["braking"])
		var mask := RlObserve.mask_from(me, -1.0 if bool(me["braking"]) else float(me["drive_level"]), inside)
		var notch := 1 if braking else 1 + signi(roundi(float(next["drive_level"])) - roundi(float(me["drive_level"])))
		var line_change := -inside * (float(next["offset"]) - float(me["offset"]))
		var line := 0 if line_change < -threshold else (2 if line_change > threshold else 1)
		var action := [
			notch, line, 1 if bool(next["braking"]) else 0,
			1 if bool(next["dash_active"]) and not bool(me["dash_active"]) else 0,
			1 if int(next["boost_uses_left"]) < int(me["boost_uses_left"]) else 0,
		]
		# 記録の上で選べない操作になったもの（端でさらに外へ、など）は「そのまま」にする。
		var offset := 0
		for k in RlObserve.ACTION_SIZES.size():
			if mask[offset + int(action[k])] == 0:
				action[k] = 1 if RlObserve.ACTION_SIZES[k] == 3 else 0
			offset += int(RlObserve.ACTION_SIZES[k])
		obs.append(Array(RlObserve.from_records(me, others, ctx)))
		masks.append(Array(mask))
		actions.append(action)
	path3d.free()
	if obs.is_empty():
		return {}
	return {"pururin": player_id.split("#")[0], "distance_m": distance, "started_at": str(data.get("started_at", "")), "obs": obs, "mask": masks, "action": actions}


static func _find(sample: Dictionary, runner_id: String) -> Dictionary:
	for record: Dictionary in sample["runners"]:
		if str(record["id"]) == runner_id:
			return record
	return {}
