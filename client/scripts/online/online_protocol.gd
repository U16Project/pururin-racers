extends RefCounted
## オンライン対戦の、通信の決まり（ゲームと、画面なしで動くサーバーの、両方が使う）。
## 文は JSON。どの文にも、決まりの版 `v` と、種類 `t` が入る。くわしくは shared/protocol_online.md。

const VERSION := 9
## サーバーが待ち受ける入口の番号。置き場所が番号を指定してくるとき（環境変数 PORT）は、そちらを使う。
const DEFAULT_PORT := 18766
const PORT_ENVIRONMENT := "PORT"
## 1部屋に入れる人数の上限（レースの枠の数と同じ）。レースの出走数は、出る人とCPUの席の数で決まり、FIELD_SIZE_MIN〜これ。
const ROOM_CAPACITY := 8
const FIELD_SIZE_MIN := 2
## 名前・部屋の名前・パスワードの、長さの上限。
const NAME_MAX_LENGTH := 12
const ROOM_NAME_MAX_LENGTH := 16
const PASSWORD_MAX_LENGTH := 16
## 自己紹介の長さの上限と、相手に送るアイコンの画像（自分で入れた画像を、小さくしたもの）の大きさ。
const INTRODUCTION_MAX_LENGTH := 70
## 部屋の紹介文の長さの上限（部屋の主が書く）。
const ROOM_DESCRIPTION_MAX_LENGTH := 70
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
## 一覧の部屋の、くわしい紹介を聞く（room_id。部屋に入る前に、入るか決めるため）。返事は room_info。
const PEEK := "peek"
## 部屋を作る（room_name、password、description＝部屋の紹介文。パスワードが空なら、だれでも入れる）。作った人が、部屋の主。
const CREATE := "create"
## 部屋に入る（room_id、password）。
const JOIN := "join"
## 部屋から出て、部屋の一覧の所へ戻る。
const LEAVE := "leave"
## 部屋の決めごとを変える（部屋の主だけ。password・description は待機室でも、distance_m・seats はレース設定で。変えたいものだけ）。
## seats＝人の足りない席ごとに、CPUを入れるか（真偽の並び。長さは、8 − レースに出る人数）。
const SETTINGS := "settings"
## 部屋の人を出す（部屋の主だけ。peer_id）。
const KICK := "kick"
## 部屋の中で、ひとこと送る（text）。
const CHAT := "chat"
## 管理人の命令（token と、command＝"list"・"kick"・"close"。kick は peer_id、close は room_id）。
const ADMIN := "admin"
## 待機室で「準備OK」を押した・外した（on＝真偽）。
const LOBBY_READY := "lobby_ready"
## 待機室から、レースへ進む（部屋の主だけ）。準備OKの人と主が、レース設定へ進む。ほかの人は、待機室に残る。
const RACE_OPEN := "race_open"
## レース設定を終えて、ぷるりんを選ぶ所へ進む（部屋の主だけ）。
const PICK_OPEN := "pick_open"
## 自分のぷるりんを選ぶ（pururin_id）。
const PICK := "pick"
## CPUのプルを決める（部屋の主だけ。プル選択でだけ）。index＝何番目のCPUか（0から）、pururin_id（空の文字で「おまかせ」）。
## トレーナーは、そのプルのデフォルトで、変えられない。
const CPU_PICK := "cpu_pick"
## 「確定」を押した・外した（on＝真偽）。部屋でも、出走表でも、全員の確定がそろうと、主が先へ進める。
const CONFIRM := "confirm"
## 出走表へ進む（部屋の主だけ。全員が選び終わって、確定していること）。CPUの個体と、枠順（くじ）が決まる。
const ENTRIES := "entries"
## 出走表の枠順を変える（部屋の主だけ）。action＝"shuffle"（くじを引き直す）か "swap"（a と b の枠を入れ替える。0から）。
const GATES := "gates"
## 待機室へ戻る。主は全員を戻して、レースに出る人を解く。主でないレースに出る人は、自分だけ抜けて待機室へ戻る。
## レース設定・プル選択から。パドックからは、to＝"lobby" を付ける。
const BACK := "back"
## back に to＝"lobby" を付けると、パドックからでも待機室へ戻る（主は全員、ほかの人は自分だけ）。
const BACK_TO_LOBBY := "lobby"
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
## オンラインフリー対戦。サーバーが持つルームの、全体のロビーに入る（レースから戻ったときも送る）。返事は free_lobby。
const FREE_ENTER := "free_enter"
## オンラインフリー対戦のロビーから出る（エントリー候補は、全部消える）。返事は lobby。
const FREE_LEAVE := "free_leave"
## ルームの画面を開いた・閉じた（room_id。閉じたら空）。開いているあいだ、そのルームの free_room が届く。
const FREE_VIEW := "free_view"
## ルームの画像を聞く（room_id）。返事は free_image。
const FREE_IMAGE_ASK := "free_image_ask"
## ルームにエントリーする（room_id、pururin_id、uid・secret＝自分のぷるりんのIDと合言葉。OwnedPururins）。エントリー候補の、優先のいちばん後ろに入る。
## もうエントリーしていれば、ぷるりんだけ替える。チケットの要るルームは、そのぷるりんがチケットを持っていないと no_ticket。
const FREE_ENTRY := "free_entry"
## エントリーを取り消す（room_id）。
const FREE_CANCEL := "free_cancel"
## エントリー候補を、一時保留にする・保留を外す（room_id、hold＝真偽）。保留のあいだは呼ばれない。待っている時間は数え続ける。
const FREE_HOLD := "free_hold"
## エントリー候補の、優先の順番を並べ替える（room_ids＝今のエントリー候補の全部を、前ほど優先の順に）。
const FREE_ORDER := "free_order"
## 呼ばれたルームに、入るか答える（room_id、accept＝真偽）。入らないと、そのルームのエントリーを取り消す。
const FREE_ANSWER := "free_answer"
## オンラインフリー対戦のチャットに書く（room_id＝ルームのID。空なら、全体のロビーのチャット。text＝文字だけ。長さは online.json の chat_max_length まで）。
## 全体のチャットは、ロビーにいる全員に、ルームのチャットは、そのルームの画面を開いている人に届く。
const FREE_CHAT := "free_chat"
## そのルームの過去の結果を聞く（room_id）。返事は free_results。
const FREE_RESULTS_ASK := "free_results_ask"
## 大会（本戦）の結果を聞く。返事は free_events。
const FREE_EVENTS_ASK := "free_events_ask"
## レースのあとの選択（room_id、entry＝"on"＝続けて呼ばれる・"hold"＝保留・"off"＝取り消す、top＝優先をいちばん前にするか）。
const FREE_AFTER := "free_after"
const FREE_AFTER_ON := "on"
const FREE_AFTER_HOLD := "hold"
const FREE_AFTER_OFF := "off"
## サーバー → ゲーム。
## オンラインフリー対戦のロビーのようす（peer_id、rooms、entries、answer_wait_s）。変わるたびに届く。
## rooms の1つぶん：room_id、name、distance_m、tag、tag_color、rule、state（idle・calling・racing）、races（走っているレースの数）、
## max_races、waiting（エントリーしている人数）、kind（"normal"＝ふつう、"final"＝本戦）、本戦なら start_unix・max_players・phase（下の FINAL_PHASE_…）・final_answer_s（呼び出しに答える秒数）、open_unix・close_unix（受付の開始と終了。世界の基準の秒。いつでも開いていれば0）、needs_ticket・gives_ticket（チケットのID。無ければ空）、needs_ticket_name・gives_ticket_name（名前）。
## entries は、自分のエントリー候補（前ほど優先）。1つぶん：room_id、pururin_id、hold、place（待っている列の何番目か。保留中も数える）、state（"wait"＝待っている・"called"＝呼ばれている・"accepted"＝入ると答えて、始まるのを待っている・"racing"＝走っている）。
## rest_s は、レースのあと呼ばないで休ませる残りの秒数（休んでいなければ0）。
## now_unix は、サーバーの今の時刻（締め切りまでの時間を、サーバーの時計で数えるため）。終わったルーム（受付が終わって、走っているレースも無い）は、rooms に入らない。
const FREE_LOBBY := "free_lobby"
## 開いているルームのくわしいようす（room_id、intro、capacity、fill_wait_s、races、entrants＝エントリーしている人
## {name, pururin_id, hold}の並び＝待っている列の順）。
const FREE_ROOM := "free_room"
## オンラインフリー対戦のチャットの1行（room_id、peer_id、name、text）。
const FREE_CHAT_MESSAGE := "free_chat_message"
## オンラインフリー対戦のチャットの、これまで（room_id、lines＝{peer_id, name, text} の並び。古いものが前）。
## 全体のロビーに入ったとき（全体のチャット）と、ルームの画面を開いたとき（そのルームのチャット）に届く。
const FREE_CHAT_LOG := "free_chat_log"
## チャットの、サーバーが覚えておく行の数（チャットごと）。
const FREE_CHAT_HISTORY := 30
## そのルームの過去の結果（room_id、results＝新しいものが前。1レースぶん：unix、room_id、name、distance_m、stage、
## rows＝着順の順の {place, name＝人の名前（CPUはトレーナー）, pururin, player, time}）。
const FREE_RESULTS := "free_results"
## 大会（本戦）の結果（events＝新しいものが前。1つぶん：room_id、name、distance_m、start_unix、end_unix（決勝が終わった時刻。まだなら無い）、
## semis＝準決勝ごとの rows、final＝決勝の rows）。
const FREE_EVENTS := "free_events"
## 大会の結果を、いくつまで送るか。
const FREE_EVENTS_SHOWN := 30
## 本戦の知らせ（room_id、text＝画面に出す文。決勝に進んだ・敗退・優勝など）。
const FREE_NOTICE := "free_notice"
## 本戦の進み方（free_lobby の rooms の phase）。エントリー受付中・呼び出し中・準決勝・決勝に進む人が戻るのを待つ・決勝の呼び出し中・決勝・終わり。
const FINAL_PHASE_ENTRY := "entry"
const FINAL_PHASE_CALLING := "calling"
const FINAL_PHASE_SEMIS := "semis"
const FINAL_PHASE_WAIT := "wait"
const FINAL_PHASE_FINAL_CALLING := "final_calling"
const FINAL_PHASE_FINAL := "final"
const FINAL_PHASE_DONE := "done"
## レースの段（race_start・free_offer の stage）。ふつうのルームは空。
const STAGE_SEMI := "semi"
const STAGE_FINAL := "final"
## チケットをもらった（uid＝どのぷるりんか、ticket_id、name、expires_unix＝期限（無ければ0）、room_id＝どのルームで）。ルームの1位のぷるりんに届く。
const FREE_TICKET := "free_ticket"
## ルームの画像（room_id、image＝jpg か png の中身を base64 にした文。画像が無ければ空）。
const FREE_IMAGE := "free_image"
## ルームに呼ばれた（room_id、name、distance_m、pururin_id、priority＝何番目の候補か、wait_s＝返事を待つ秒数、stage＝本戦なら "semi"（本戦の最初の呼び出し）か "final"（決勝）。ふつうは空）。
const FREE_OFFER := "free_offer"
## 呼ばれたのが取り消された（room_id、reason＝"timeout"＝返事がなかった（そのルームのエントリーは取り消し）、"started"＝待たずにレースが始まった）。
const FREE_OFFER_END := "free_offer_end"
const FREE_STATE_IDLE := "idle"
const FREE_STATE_CALLING := "calling"
const FREE_STATE_RACING := "racing"
const FREE_ENTRY_WAIT := "wait"
const FREE_ENTRY_CALLED := "called"
const FREE_ENTRY_ACCEPTED := "accepted"
const FREE_ENTRY_RACING := "racing"
const FREE_OFFER_TIMEOUT := "timeout"
const FREE_OFFER_STARTED := "started"
## ルームの画像の、base64 にした文の長さの上限（つながりの1回に送れる量に収める）。
const FREE_IMAGE_MAX_CHARS := ICON_IMAGE_MAX_CHARS
## 部屋の一覧の所に入れた（peer_id、max_rooms、rooms）。部屋を出たとき・出されたときも、これが届く。
const LOBBY := "lobby"
## 部屋の一覧が変わった（rooms。部屋に入っていない人に配る）。
const ROOMS := "rooms"
## 部屋に入れた（部屋のようす）。
const WELCOME := "welcome"
const ROOM := "room"
## 一覧の部屋のくわしい紹介（room_id、name、host_name、host_icon、count、field_size、description、locked、racing、in_entries）。
const ROOM_INFO := "room_info"
## 部屋の人の紹介（peer_id、name、introduction、icon）。
const PROFILE_INFO := "profile_info"
## 部屋の人のひとこと（peer_id、name、text）。
const CHAT_MESSAGE := "chat_message"
## 部屋のできごとの知らせ（kind と、その人の name）。部屋の全員に配る。
## kind：joined＝入った、left＝出た、disconnected＝つながりが切れた、kicked＝退出させられた（by＝"host" か "admin"）、host＝部屋の主になった、
## race_open＝部屋の主がレース開始を押した（name＝主）。
const NOTICE := "notice"
const NOTICE_JOINED := "joined"
const NOTICE_LEFT := "left"
const NOTICE_DISCONNECTED := "disconnected"
const NOTICE_KICKED := "kicked"
const NOTICE_HOST := "host"
const NOTICE_RACE_OPEN := "race_open"
## 部屋から出された（by＝"host" か "admin"）。このあと、lobby が届く。
const KICKED := "kicked"
## 管理人の命令の返事（command と、その結果）。
const ADMIN_RESULT := "admin_result"
const PONG := "pong"
const ERROR := "error"
## レースが始まる（distance_m、entries＝出走の一覧。オンラインフリー対戦なら、free_room_id＝ルームのID も）。
const RACE_START := "race_start"
## レースの今の状態（1秒に STATE_RATE_HZ 回）。
const RACE_STATE := "race_state"
## レースが終わった（rows＝着順の一覧）。
const RACE_RESULT := "race_result"

## レースを片づけた（結果が出てから、決めた秒数がたった・全員が画面を出た）。まだレースの画面にいる人は、待機室へ戻る。
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
## レースに出る人（準備OKの人と主）でないと、できない。
const ERROR_NOT_RACER := "not_racer"
## 今の場面では、できない（待機室・レース設定・ぷるりんを選ぶ所・出走表の、決まった所でだけできること）。
const ERROR_WRONG_PHASE := "wrong_phase"
## オンラインフリー対戦のロビーに入っていないと、できない。
const ERROR_NOT_IN_FREE := "not_in_free"
## そのルームに、エントリーしていない。
const ERROR_NO_ENTRY := "no_entry"
## そのルームに要るチケットを、そのぷるりんが持っていない（または、IDと合言葉・能力が、チケットを渡したときと合わない）。
const ERROR_NO_TICKET := "no_ticket"
## そのルームは、今は受付をしていない（受付の前・後）。
const ERROR_CLOSED := "closed"
## 管理人の合い札が違う・管理人の合い札が、サーバーに設定されていない。
const ERROR_NOT_ADMIN := "not_admin"

const KICKED_BY_HOST := "host"
const KICKED_BY_ADMIN := "admin"
const ADMIN_LIST := "list"
const ADMIN_KICK := "kick"
const ADMIN_CLOSE := "close"
## 管理人の合い札を入れておく、サーバーの環境変数。空なら、管理人の命令は、すべて断る。
const ADMIN_TOKEN_ENVIRONMENT := "PURURIN_ADMIN_TOKEN"

## 部屋の場面：待機室（lobby）、レース設定（settings）、ぷるりんを選ぶ所（room）、出走表（entries）。
## 待機室のほかの場面は、レースに出る人だけのもの。出ない人は、そのあいだも待機室にいる。
const PHASE_LOBBY := "lobby"
const PHASE_SETTINGS := "settings"
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
