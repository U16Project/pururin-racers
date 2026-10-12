extends RefCounted
## オンライン対戦の、通信の決まり（ゲームと、画面なしで動くサーバーの、両方が使う）。
## 文は JSON。どの文にも、決まりの版 `v` と、種類 `t` が入る。くわしくは shared/protocol_online.md。

const VERSION := 1
## サーバーが待ち受ける入口の番号。置き場所が番号を指定してくるとき（環境変数 PORT）は、そちらを使う。
const DEFAULT_PORT := 18766
const PORT_ENVIRONMENT := "PORT"
## 1部屋に入れる人数（レースの枠の数と同じ）。
const ROOM_CAPACITY := 8
## 名前と合言葉の、長さの上限。
const NAME_MAX_LENGTH := 12
const ROOM_CODE_MAX_LENGTH := 16

## ゲーム → サーバー。
const HELLO := "hello"
const PING := "ping"
## 自分のぷるりんを選ぶ（pururin_id）。
const PICK := "pick"
## 距離を決める（distance_m。部屋の主だけ）。
const DISTANCE := "distance"
## レースを始める（部屋の主だけ。全員が選び終わっていること）。
const START := "start"
## レース中の操作（line＝ライン -1〜1、notch＝ノッチの上げ下げ -1〜1、brake＝ブレーキを押しているか）。
const INPUT := "input"
## ダッシュ・ブーストを押した（kind＝"dash" か "boost"）。
const ACTION := "action"
## レースの画面ができた（全員ぶんそろうと、入場の待ちとカウントダウンが始まる）。
const READY := "ready"
## サーバー → ゲーム。
const WELCOME := "welcome"
const ROOM := "room"
const PONG := "pong"
const ERROR := "error"
## レースが始まる（distance_m、entries＝出走の一覧）。
const RACE_START := "race_start"
## レースの今の状態（1秒に STATE_RATE_HZ 回）。
const RACE_STATE := "race_state"
## レースが終わった（rows＝着順の一覧）。
const RACE_RESULT := "race_result"

## 断るときの理由。
const ERROR_BAD_MESSAGE := "bad_message"
const ERROR_VERSION := "version"
const ERROR_ROOM_FULL := "room_full"
const ERROR_NOT_IN_ROOM := "not_in_room"
## そのぷるりんは、部屋のほかの人が選んでいる。
const ERROR_TAKEN := "taken"
## 部屋の主でないと、できない。
const ERROR_NOT_HOST := "not_host"
## まだ選んでいない人がいる。
const ERROR_NOT_READY := "not_ready"
## レース中は、できない。
const ERROR_RACING := "racing"

const ACTION_DASH := "dash"
const ACTION_BOOST := "boost"
## レースの状態を配る回数（1秒あたり）。
const STATE_RATE_HZ := 20.0
## 全員のレースの画面ができるのを待つ秒数の上限。過ぎたら、できていない人を待たずに始める。
const READY_TIMEOUT_S := 20.0


## 送る文を作る。
static func message(type: String, fields: Dictionary = {}) -> Dictionary:
	var result := {"v": VERSION, "t": type}
	result.merge(fields)
	return result


static func encode(data: Dictionary) -> String:
	return JSON.stringify(data)


## 受け取った文を読む。読めない・決まりの形でないときは、空の辞書。
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary) or not (json.data as Dictionary).has("t"):
		return {}
	return json.data


## サーバーが待ち受ける入口の番号。
static func server_port() -> int:
	var from_environment := OS.get_environment(PORT_ENVIRONMENT)
	return int(from_environment) if from_environment.is_valid_int() else DEFAULT_PORT


## 名前や合言葉を、前後の空白を取り、長さの上限で切る。
static func clean_text(value: Variant, max_length: int) -> String:
	return str(value).strip_edges().left(max_length)
