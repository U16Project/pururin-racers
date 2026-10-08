extends RefCounted
## レース中のアクションの決め方。走者の状態から、体全体と、体の一部（ヒレ・突起・炎・羽など）の動かし方の名前を選ぶ。
## アクションの名前は、部品の設定（action_names）と同じ。動きは見た目だけで、走りの計算には使わない。

## 走る動きの速さの基準。この速さ（km/h）のとき、動きの速さの倍率が1になる。
const RUN_REFERENCE_KMH := 50.0
## 走る動きの速さの倍率の、下限と上限。
const RUN_RATE_MIN := 0.5
const RUN_RATE_MAX := 1.8
## ゴールしたとき、この順位までは、小さく跳ねる（1位は、跳ね回る）。
const GOAL_PLACE_MAX_ORDER := 3
## 横へ動く速さ（m/秒）が、これで、体の傾きがいっぱいになる。
const STEER_FULL_LATERAL_MPS := 3.0
## 向きが変わる速さ（ラジアン/秒）が、これで、カーブの傾きがいっぱいになる。
const STEER_FULL_TURN_RAD_PER_S := 0.25
## カーブの傾きの、いっぱいのときの大きさ（横へ動くときの傾きを1として）。
const STEER_TURN_SHARE := 0.6
## スタートした瞬間に、1回だけ出す動きの名前。
const LAUNCH_ONE_SHOT := "launch"


## 今のアクション。上に書いたものほど優先する。
## state: race_active, finished, finish_order, in_push_contest, contact_count, braking,
##        dashing（ダッシュかブーストの最中）, tired（体力がマイナスか、心拍が通常上限ごえ）
static func wanted(state: Dictionary) -> String:
	if bool(state["finished"]):
		var order := int(state["finish_order"])
		if order == 1:
			return "goal_win"
		return "goal_place" if order <= GOAL_PLACE_MAX_ORDER else "goal"
	if not bool(state["race_active"]):
		return "ready"
	if bool(state["in_push_contest"]):
		return "push"
	if int(state["contact_count"]) > 0:
		return "contact"
	if bool(state["braking"]):
		return "brake"
	if bool(state["dashing"]):
		return "dash"
	if bool(state["tired"]):
		return "tired"
	return "run"


## 動きの速さの倍率。走っているときだけ、速さに合わせる。
static func rate(action: String, speed_kmh: float) -> float:
	if action != "run":
		return 1.0
	return clampf(speed_kmh / RUN_REFERENCE_KMH, RUN_RATE_MIN, RUN_RATE_MAX)


## 体の左右への傾き（−1〜1。＋で体の右へ傾く）。
## lateral_mps は、体の右へ動く速さ。turn_rad_per_s は、向きが変わる速さ（＋で左へ曲がる）。カーブでは、内側へ傾く。
static func steer(lateral_mps: float, turn_rad_per_s: float) -> float:
	return clampf(lateral_mps / STEER_FULL_LATERAL_MPS - STEER_TURN_SHARE * turn_rad_per_s / STEER_FULL_TURN_RAD_PER_S, -1.0, 1.0)
