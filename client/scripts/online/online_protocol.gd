extends RefCounted
## オンライン対戦の、通信の決まり（ゲームと、画面なしで動くサーバーの、両方が使う）。
## 文は JSON。どの文にも、決まりの版 `v` と、種類 `t` が入る。くわしくは shared/protocol_online.md。

const VERSION := 5
## サーバーが待ち受ける入口の番号。置き場所が番号を指定してくるとき（環境変数 PORT）は、そちらを使う。
const DEFAULT_PORT := 18766
const PORT_ENVIRONMENT := "PORT"
## 1部屋に入れる人数の上限（レースの枠の数と同じ）。部屋ごとの出走数は、部屋の主が、FIELD_SIZE_MIN〜これ で決める。
const ROOM_CAPACITY := 8
const FIELD_SIZE_MIN := 2
## 名前・部屋の名前・パスワードの、長さの上限。
const NAME_MAX_LENGTH := 12
const ROOM_NAME_MAX_LENGTH := 16
const PASSWORD_MAX_LENGTH := 16
## 自己紹介の長さの上限と、相手に送るアイコンの画像（自分で入れた画像を、小さくしたもの）の大きさ。
const INTRODUCTION_MAX_LENGTH := 70
const ICON_IMAGE_SIDE_PX := 128
## 送るアイコンの画像（文字にしたあと）の長さの上限。超えたら、画像なしとして扱う。
const ICON_IMAGE_MAX_CHARS := 60000
const ICON_KINDS := ["none", "avatar", "file"]

## ゲーム → サーバー。
## 名前を名乗って、部屋の一覧の所（ロビー）に入る（name。あれば introduction＝自己紹介、
## icon＝{kind: none・avatar・file, id: 用意された絵のID, image: 自分で入れた画像（JPEGを文字にしたもの）}）。
const HELLO := "hello"
## 同じ部屋の人の、紹介（名前・自己紹介・アイコン）を聞く（peer_id）。
const PROFILE := "profile"
const PING := "ping"
## 部屋を作る（room_name、password。パスワードが空なら、だれでも入れる）。作った人が、部屋の主。
const CREATE := "create"
## 部屋に入る（room_id、password）。
const JOIN := "join"
## 部屋から出て、部屋の一覧の所へ戻る。
const LEAVE := "leave"
## 部屋の決めごとを変える（部屋の主だけ。distance_m・field_size・cpu・password のうち、変えたいものだけ）。
const SETTINGS := "settings"
## 部屋の人を出す（部屋の主だけ。peer_id）。
const KICK := "kick"
## 部屋の中で、ひとこと送る（text）。
const CHAT := "chat"
## 管理人の命令（token と、command＝"list"・"kick"・"close"。kick は peer_id、close は room_id）。
const ADMIN := "admin"
## 自分のぷるりんを選ぶ（pururin_id）。
const PICK := "pick"
## CPUのぷるりん・トレーナーを決める（部屋の主だけ）。部屋では index＝何番目のCPUか（0から）、出走表では gate＝枠（0から）。
## pururin_id・trainer_id のうち、変えたいものだけ。部屋では、空の文字を送ると「おまかせ」に戻る。
const CPU_PICK := "cpu_pick"
## 「確定」を押した・外した（on＝真偽）。部屋でも、出走表でも、全員の確定がそろうと、主が先へ進める。
const CONFIRM := "confirm"
## 出走表へ進む（部屋の主だけ。全員が選び終わって、確定していること）。CPUの個体と、枠順（くじ）が決まる。
const ENTRIES := "entries"
## 出走表の枠順を変える（部屋の主だけ）。action＝"shuffle"（くじを引き直す）か "swap"（a と b の枠を入れ替える。0から）。
const GATES := "gates"
## 出走表から、部屋へ戻る（部屋の主だけ）。
const BACK := "back"
## レースを始める（部屋の主だけ。出走表で、全員が確定していること）。
const START := "start"
## レース中の操作（line＝ライン -1〜1、notch＝ノッチの上げ下げ -1〜1、brake＝ブレーキを押しているか）。
const INPUT := "input"
## ダッシュ・ブーストを押した（kind＝"dash" か "boost"）。
const ACTION := "action"
## 結果を見終わって、レースの画面を出た（全員ぶんそろうと、サーバーは、決めた秒数を待たずに、レースを片づける）。
const RACE_DONE := "race_done"
## レースの画面ができた（全員ぶんそろうと、入場の待ちとカウントダウンが始まる）。
const READY := "ready"
## サーバー → ゲーム。
## 部屋の一覧の所に入れた（peer_id、max_rooms、rooms）。部屋を出たとき・出されたときも、これが届く。
const LOBBY := "lobby"
## 部屋の一覧が変わった（rooms。部屋に入っていない人に配る）。
const ROOMS := "rooms"
## 部屋に入れた（部屋のようす）。
const WELCOME := "welcome"
const ROOM := "room"
## 部屋の人の紹介（peer_id、name、introduction、icon）。
const PROFILE_INFO := "profile_info"
## 部屋の人のひとこと（peer_id、name、text）。
const CHAT_MESSAGE := "chat_message"
## 部屋のできごとの知らせ（kind と、その人の name）。部屋の全員に配る。
## kind：joined＝入った、left＝出た、disconnected＝つながりが切れた、kicked＝退出させられた（by＝"host" か "admin"）、host＝部屋の主になった。
const NOTICE := "notice"
const NOTICE_JOINED := "joined"
const NOTICE_LEFT := "left"
const NOTICE_DISCONNECTED := "disconnected"
const NOTICE_KICKED := "kicked"
const NOTICE_HOST := "host"
## 部屋から出された（by＝"host" か "admin"）。このあと、lobby が届く。
const KICKED := "kicked"
## 管理人の命令の返事（command と、その結果）。
const ADMIN_RESULT := "admin_result"
const PONG := "pong"
const ERROR := "error"
## レースが始まる（distance_m、entries＝出走の一覧）。
const RACE_START := "race_start"
## レースの今の状態（1秒に STATE_RATE_HZ 回）。
const RACE_STATE := "race_state"
## レースが終わった（rows＝着順の一覧）。
const RACE_RESULT := "race_result"

## レースを片づけた（結果が出てから、決めた秒数がたった・全員が画面を出た）。まだレースの画面にいる人は、部屋へ戻る。
const RACE_END := "race_end"

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
## 出走表を見ているあいだは、できない（部屋に入る・ぷるりんを選ぶ・決めごとを変える）。
const ERROR_IN_ENTRIES := "in_entries"
## 出走表でないと、できない。
const ERROR_NOT_IN_ENTRIES := "not_in_entries"
## まだ確定していない人がいる。
const ERROR_NOT_CONFIRMED := "not_confirmed"
## 部屋の数が、上限に達している。
const ERROR_ROOMS_FULL := "rooms_full"
## その名前の部屋は、もうある。
const ERROR_ROOM_NAME_TAKEN := "room_name_taken"
## その部屋は、もう無い。
const ERROR_NO_ROOM := "no_room"
## パスワードが違う。
const ERROR_WRONG_PASSWORD := "wrong_password"
## まだ名乗っていない（hello の前には、できない）。
const ERROR_NO_NAME := "no_name"
## 出走が、2体に足りない。
const ERROR_TOO_FEW := "too_few"
## 管理人の合い札が違う・管理人の合い札が、サーバーに設定されていない。
const ERROR_NOT_ADMIN := "not_admin"

const KICKED_BY_HOST := "host"
const KICKED_BY_ADMIN := "admin"
const ADMIN_LIST := "list"
const ADMIN_KICK := "kick"
const ADMIN_CLOSE := "close"
## 管理人の合い札を入れておく、サーバーの環境変数。空なら、管理人の命令は、すべて断る。
const ADMIN_TOKEN_ENVIRONMENT := "PURURIN_ADMIN_TOKEN"

## 部屋の場面：ぷるりんを選ぶ所（room）と、出走表（entries）。
const PHASE_ROOM := "room"
const PHASE_ENTRIES := "entries"
const GATES_SHUFFLE := "shuffle"
const GATES_SWAP := "swap"
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
