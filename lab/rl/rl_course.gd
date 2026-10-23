extends RefCounted
## 強化学習：コースの形（走る道すじ全体を、決めた間隔で区切った表）。距離ごとに1回だけ作って取っておく。
## 「先のコーナーまでの距離・曲がり具合」「ゴールまでの直線の長さ」を見るために使う。

const TrackMath := preload("res://scripts/track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")

## 区切る間隔（m）。
const STEP_M := 5.0
## コーナーとみなす曲がり具合（lab_situation.gd と同じ値）。
const CORNER_CURVATURE := 0.0005

static var _cache := {}


## {"bend": 区切りごとの曲がり具合（コーナーでなければ0）, "max_bend": いちばん曲がる所, "final_straight_m": ゴール前の直線の長さ}
static func profile(curve: Curve3D, route: Dictionary, distance_m: float) -> Dictionary:
	var key := "%d" % roundi(distance_m)
	if _cache.has(key):
		return _cache[key]
	var bend := PackedFloat32Array()
	var max_bend := 0.0
	var d := 0.0
	while d <= distance_m + STEP_M:
		var pose := CourseBuilder.route_pose(curve, route, d, LocalRaceMath.lap_length_m())
		var k := 0.0
		if not pose.is_empty() and not bool(pose.get("is_straight", false)):
			k = absf(TrackMath.curvature_at(curve, float(pose["mainline_distance"])))
			if k <= CORNER_CURVATURE:
				k = 0.0
		bend.append(k)
		max_bend = maxf(max_bend, k)
		d += STEP_M
	var goal_index := mini(int(distance_m / STEP_M), bend.size() - 1)
	var i := goal_index
	while i > 0 and bend[i] == 0.0:
		i -= 1
	var out := {"bend": bend, "max_bend": maxf(max_bend, 0.0001), "final_straight_m": float(goal_index - i) * STEP_M}
	_cache[key] = out
	return out


## progress_m の所から見た、先の形：
## {"to_corner_m": 次のコーナーの入口まで（コーナーの中なら0）, "corner_bend": そのコーナーのいちばん曲がる所（0〜1）,
##  "corner_left_m": 今のコーナーの残り（直線なら0）, "on_final_straight": ゴール前の直線にいるか}
static func ahead(profile_data: Dictionary, progress_m: float, look_m: float) -> Dictionary:
	var bend: PackedFloat32Array = profile_data["bend"]
	var i := clampi(int(progress_m / STEP_M), 0, bend.size() - 1)
	var last := mini(i + int(look_m / STEP_M), bend.size() - 1)
	var out := {"to_corner_m": look_m, "corner_bend": 0.0, "corner_left_m": 0.0, "on_final_straight": false}
	var j := i
	if bend[i] > 0.0:
		out["to_corner_m"] = 0.0
		while j <= last and bend[j] > 0.0:
			j += 1
		out["corner_left_m"] = float(j - i) * STEP_M
		j = i
	else:
		while j <= last and bend[j] == 0.0:
			j += 1
		if j > last:
			# この先に、もうコーナーがない（ゴール前の直線）か、見る範囲の外。
			var rest := true
			for k in range(j, bend.size()):
				if bend[k] > 0.0:
					rest = false
					break
			out["on_final_straight"] = rest
			return out
		out["to_corner_m"] = float(j - i) * STEP_M
	var top := 0.0
	while j < bend.size() and bend[j] > 0.0:
		top = maxf(top, bend[j])
		j += 1
	out["corner_bend"] = top / float(profile_data["max_bend"])
	return out
