extends RefCounted
## レース中の表情の決め方。走者の状態から、出したい表情の名前を選ぶ。
## 値の計算だけをここに置き、体への反映は走者が行う。表情の名前は、見た目の設定（expression_names）と同じ。
## その表情の顔の部品を持たない個体は、ノーマルの顔になる。

const NORMAL := "normal"
## 表情を替えたら、最低これだけの秒数は出しておく（細かく切り替わって、ちらつかないように）。
const MIN_SHOW_SECONDS := 0.8
## ドラフトで空気抵抗がこの割合以上減っているとき、楽（ほっこり）の顔にする。
const RELAX_DRAFT_REDUCTION := 0.1
## ゴールしたとき、この順位までは喜の顔にする（1位は、1位の顔）。
const JOY_MAX_ORDER := 3
## ゴールしたとき、この順位からは哀の顔にする。
const SORROW_MIN_ORDER := 6


## 出したい表情。上に書いたものほど優先する。
## state: finished, finish_order, in_push_contest, lost_push, contact_count, stamina,
##        heart_bpm, heart_normal_max_bpm, draft_reduction
static func wanted(state: Dictionary) -> String:
	if bool(state["finished"]):
		var order := int(state["finish_order"])
		if order == 1:
			return "first_place"
		if order <= JOY_MAX_ORDER:
			return "joy"
		return "sorrow" if order >= SORROW_MIN_ORDER else NORMAL
	if bool(state["in_push_contest"]):
		return "push_lose" if bool(state["lost_push"]) else "push_win"
	if int(state["contact_count"]) > 0:
		return "anger"
	if float(state["stamina"]) < 0.0 or float(state["heart_bpm"]) > float(state["heart_normal_max_bpm"]):
		return "sorrow"
	if float(state["draft_reduction"]) >= RELAX_DRAFT_REDUCTION:
		return "relax"
	return NORMAL


## 次に出す表情。今の表情を出してから MIN_SHOW_SECONDS たつまでは、替えない。ゴールの顔だけは、すぐ替える。
static func next(current: String, wanted_now: String, seconds_shown: float, finished: bool) -> String:
	if wanted_now == current:
		return current
	return wanted_now if finished or seconds_shown >= MIN_SHOW_SECONDS else current
