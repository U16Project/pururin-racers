extends RefCounted
## CPU育成ラボ：点の付け方。レースの結果から、見る項目（成績）を数え、設定の重さを掛けて足す。
## 点＝Σ（成績の項目 × 重さ）。重さは lab_settings.json の "score"。項目を足すときは、ここで数えて、設定に重さを書く。

const METRICS := {
	"win_rate": "1位の割合",
	"gap_to_winner_s": "1位とのタイム差の平均（秒・1位なら0）",
	"avg_place": "平均の着順",
	"stamina_left": "ゴールで残った体力の割合の平均",
	"top2_rate": "2着以内の割合",
	"top3_rate": "3着以内の割合",
	"over_heart_s": "心拍の上限超えの時間の平均（秒）",
	"dash_uses": "ダッシュを使った回数の平均",
	"boost_uses": "ブーストを使った回数の平均",
	"timed_out": "時間切れになった割合",
}


## ラボのフォルダ（リポジトリのいちばん上の lab/）。ゲームの外に置いてあるので、この台本の場所から決める。
static func lab_dir() -> String:
	var path: String = (new() as RefCounted).get_script().resource_path
	if path.is_relative_path():
		path = OS.get_environment("PWD").path_join(path)
	return path.get_base_dir().simplify_path()


static func load_settings() -> Dictionary:
	var file := FileAccess.open(lab_dir().path_join("lab_settings.json"), FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data


## 結果を、点を付ける相手ごとの行に分ける：{名前: [{result, row}, …]}。
## 頭の席は、その頭の名前。頭のいない席（今までのCPU）は、focus_gate の席だけを「今までのCPU（型）」として数える。
static func rows_by_name(results: Array, baseline_name: Callable) -> Dictionary:
	var out := {}
	for result: Dictionary in results:
		for row: Dictionary in result["rows"]:
			var name := str(row["brain"])
			if name.is_empty():
				if int(row["gate"]) != int(result["focus_gate"]):
					continue
				name = str(baseline_name.call(row))
			if not out.has(name):
				out[name] = []
			out[name].append({"result": result, "row": row})
	return out


## いくつかのレースの、ある相手の行（{result, row} の並び）から、成績の項目を数える。
static func metrics(entries: Array) -> Dictionary:
	var m := {}
	for key: String in METRICS:
		m[key] = 0.0
	for entry: Dictionary in entries:
		var result: Dictionary = entry["result"]
		var row: Dictionary = entry["row"]
		var winner_time := INF
		for other: Dictionary in result["rows"]:
			if float(other["time"]) >= 0.0:
				winner_time = minf(winner_time, float(other["time"]))
		var place := int(row["place"])
		m["win_rate"] += 1.0 if place == 1 else 0.0
		m["top2_rate"] += 1.0 if place <= 2 else 0.0
		m["top3_rate"] += 1.0 if place <= 3 else 0.0
		m["avg_place"] += float(place)
		# ゴールできなかった（時間切れ）ときは、打ち切った時間で数える。
		var my_time := float(row["time"]) if float(row["time"]) >= 0.0 else float(result["race_s"])
		m["gap_to_winner_s"] += maxf(my_time - winner_time, 0.0) if winner_time < INF else 0.0
		m["stamina_left"] += maxf(float(row["stamina_left"]), 0.0)
		m["over_heart_s"] += float(row["over_heart_s"])
		m["dash_uses"] += float(row["dash_uses"])
		m["boost_uses"] += float(row["boost_uses"])
		m["timed_out"] += 1.0 if bool(result["timed_out"]) else 0.0
	for key: String in m:
		m[key] = m[key] / maxf(float(entries.size()), 1.0)
	m["races"] = entries.size()
	return m


static func points(m: Dictionary, weights: Dictionary) -> float:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key]) * float(m[key])
	return total
