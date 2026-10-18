extends Control
## ともだち対戦の、部屋の画面。3つの場面を、同じ画面の中で切り替える。
## （1）つなぐ前：サーバーの場所を入れて、つなぐ。
## （2）部屋の一覧：部屋を選んで入る（施錠の印の部屋は、パスワードを聞く窓が出る）。「部屋を作る」で、作る窓が出る。
## （3）部屋の中：自分のぷるりんを選ぶ。部屋の主は、距離・出走数・CPUを入れるか・パスワードを決め、人を出し、レースを始める。
## 名前は、トレーナー登録の名前を使う。サーバーとのつながりは、レースの画面へ持っていくので、OnlineSession に置く。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const LockMark := preload("res://scripts/menu/lock_mark.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const PururinPicker := preload("res://scripts/menu/pururin_picker.gd")
const PururinSlot := preload("res://scripts/menu/pururin_slot.gd")
const PururinPortrait := preload("res://scripts/menu/pururin_portrait.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const ButtonMark := preload("res://scripts/menu/button_mark.gd")
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const ServerChoice := preload("res://scripts/config/online_server_choice.gd")
const LocalServer := preload("res://scripts/online/local_server.gd")
## このPCのサーバーが起動するのを待つ秒数（その間は、つながらなくても、つなぎ直す）。
const LOCAL_SERVER_START_TIMEOUT_S := 12.0
const LOCAL_SERVER_RETRY_S := 0.8
const OnlineSession := preload("res://scripts/online/online_session.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LOCAL_RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const Protocol := preload("res://scripts/online/online_protocol.gd")
const PANEL_WIDTH := 1040.0
## 板と、画面の上下の端のあいだ。
const PANEL_SCREEN_MARGIN := 8.0
const BUTTON_HEIGHT := 40.0
const FIELD_HEIGHT := 34.0
const LABEL_WIDTH := 110.0
const DIALOG_WIDTH := 520.0
## 部屋の一覧の、まん中の列の幅（画面いっぱいに広げない）。
const LIST_WIDTH := 720.0
const ROOM_ROW_HEIGHT := 40.0
## 一覧の列の幅（主・人数・状態）。部屋の名前は、残りの幅。
const HOST_COLUMN_WIDTH := 190.0
const COUNT_COLUMN_WIDTH := 80.0
const STATE_COLUMN_WIDTH := 100.0
## 一覧と「部屋を作る」のあいだ。
const CREATE_BUTTON_GAP := 20.0
const CREATE_BUTTON_WIDTH := 320.0
const COLOR_CARD := Color(1.0, 1.0, 1.0, 0.055)
const COLOR_ROW_EMPTY := Color(1.0, 1.0, 1.0, 0.03)
const COLOR_CHIP := Color(0.1, 0.16, 0.26, 0.95)
const DISTANCE_BUTTON_HEIGHT := 36.0
## 距離を1つ動かすボタン（‹ L1・R1 ›）。オフラインのレース選択と同じ見た目。
const DISTANCE_STEP_BUTTON_WIDTH := 62.0
const DISTANCE_MARK_SIZE := 20.0
const COLOR_STEP_BUTTON := Color(0.36, 0.23, 0.13, 1.0)
const COLOR_STEP_BUTTON_BORDER := Color(0.62, 0.43, 0.25, 1.0)
## 行の右の、確定の印の幅と、「︙」（主が、その人を退出させる窓を開く）の幅。出さない行も、同じ幅だけ空ける。
const CONFIRM_BADGE_WIDTH := 46.0
const MEMBER_MENU_WIDTH := 24.0
## 決めごとの行の、小さい矢印ボタン。
const MINI_ARROW_SIZE := Vector2(26.0, 28.0)
const PROFILE_ICON_SIZE := 132.0
const STYLE_NAMES := {"escape": "逃げ", "pace": "先行", "stalk": "差し", "closer": "追い込み"}
const COLOR_CONFIRMED := Color(0.3, 0.8, 0.5, 1.0)
## 取り返しのつかない操作（退出させる）のボタンの色。
const COLOR_DANGER_BUTTON := Color(0.72, 0.26, 0.24, 1.0)
## ほかの人の名前の色（自分は、枠の行の「ユーザー」の色）。
const COLOR_OTHER_PLAYER := Color(1.0, 0.93, 0.6, 1.0)
const PICKER_MARGIN := 8.0
## 待機室：席の並び（4列×2行）・席の高さ・アイコンの大きさ・紹介文の吹き出しの幅・紹介の欄の高さ（3行ぶん）。
const WAITING_SEAT_COLUMNS := 4
const WAITING_SEAT_HEIGHT := 72.0
const WAITING_ICON_SIZE := 34.0
const WAITING_POPUP_WIDTH := 220.0
const WAITING_DESCRIPTION_HEIGHT := 66.0
const COLOR_SEAT := Color(1.0, 1.0, 1.0, 0.07)
const COLOR_SEAT_EMPTY := Color(1.0, 1.0, 1.0, 0.025)
## ルームチャットの背景（濃い、透ける色）。
const COLOR_CHAT_PANEL := Color(0.02, 0.03, 0.06, 0.72)
## ルームチャットの欄の、いちばん狭い幅（本体の中身が広い画面でも、入力らんが切れないように）。
const CHAT_PANEL_MIN_WIDTH := 360.0
const CHAT_PANEL_TOP_MARGIN := 14
## 部屋主がレース開始を押したときの知らせ（出す時間と、文）。
const RACE_OPEN_POPUP_MSEC := 2000
const RACE_OPEN_POPUP_WIDTH := 640.0
const RACE_OPEN_TEXT := "部屋主が「レース設定へ」を押したので、レース設定に進みます。"
## 部屋主の操作で画面が切り替わるときの知らせ（切り替わる前の画面 → あとの画面）。
const VIEW_CHANGE_TEXTS := {
	"settings>pick": "部屋主が「次へ」を押したので、プル選択に進みます。",
	"pick>paddock": "部屋主が「パドックへ」を押したので、パドックに進みます。",
	"paddock>pick": "部屋主が「選び直す」を押したので、プル選択に戻ります。",
	"settings>waiting": "部屋主が「待機室へ戻る」を押したので、待機室に戻ります。",
	"pick>waiting": "部屋主が「待機室へ戻る」を押したので、待機室に戻ります。",
	"paddock>waiting": "部屋主が「待機室へ戻る」を押したので、待機室に戻ります。",
}
## 部屋の中の流れの道しるべ（順番）と、画面ごとの今の場所。
const ROOM_STEPS := ["待機室", "レース設定", "プル選択", "パドック", "レース"]
const VIEW_STEP_INDEX := {"waiting": 0, "settings": 1, "pick": 2, "paddock": 3}
const STEP_LINE_WIDTH := 22.0
const COLOR_STEP_NOW := Color(1.0, 0.86, 0.3, 1.0)
const COLOR_STEP_OTHER := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_STEP_DONE := Color(0.45, 0.85, 0.6, 1.0)
## 待機室の、レース中の帯の色。
const COLOR_RACE_BAND := Color(0.85, 0.45, 0.15, 0.35)
## 先に進んでいる人たちが、いまいる画面の呼び名。
const PHASE_NAMES := {"settings": "レース設定", "room": "プル選択", "entries": "パドック"}
const RACE_START_TEXT := "部屋主が「レース開始」を押したので、レースが始まります。"
const RACE_OPEN_STAY_TEXT := "部屋主が「レース設定へ」を押しました。準備OKでなかったので、待機室で次のレースを待ちます。"
## プル選択：横長の席の高さ・絵の大きさ（自分の席は大きく、上下に余白）・名前の幅・自分の席の色。
const PICK_ROW_HEIGHT := 36.0
const PICK_ROW_HEIGHT_MINE := 74.0
const PICK_ICON_SIZE := 30.0
const PICK_ICON_SIZE_MINE := 56.0
const PICK_MINE_MARGIN := 6.0
const PICK_WHO_WIDTH := 170.0
const PICK_PURURIN_NAME_WIDTH := 110.0
const PICK_CHEVRON_SCALE := 0.9
const COLOR_PICK_MINE := Color(0.18, 0.42, 0.58, 0.85)
## パドック：大きな枠の高さ・絵の大きさ・枠番号の札の大きさ、詳細の窓の幅と、その左（人）の幅。
const PADDOCK_ROW_HEIGHT := 42.0
const PADDOCK_ICON_SIZE := 34.0
const PADDOCK_BADGE_SIZE := 28.0
const PADDOCK_DIALOG_WIDTH := 900.0
## 窓の中のプルの詳細の高さ（オフラインのレース選択の詳細に近い高さにして、バーを読みやすくする）と、プル選択の窓の幅。
const DETAIL_DIALOG_HEIGHT := 440.0
const PICK_DIALOG_WIDTH := 600.0
const PADDOCK_PERSON_WIDTH := 240.0
## 部屋の紹介の入力欄の高さ（3行ぶん）。
const DESCRIPTION_EDIT_HEIGHT := 112.0
const COLOR_DIALOG := Color(0.07, 0.1, 0.16, 0.98)
const COLOR_DIALOG_SHADE := Color(0.0, 0.0, 0.0, 0.55)

## サーバーに断られたときの、画面に出す文。
const ERROR_TEXTS := {
	Protocol.ERROR_ROOM_FULL: "その部屋は、満員です。",
	Protocol.ERROR_VERSION: "ゲームとサーバーの版が合っていません。ゲームを新しくしてください。",
	Protocol.ERROR_BAD_MESSAGE: "サーバーに断られました（入れた内容を確かめてください）。",
	Protocol.ERROR_TAKEN: "そのぷるりんは、ほかの人が選んでいます。",
	Protocol.ERROR_NOT_HOST: "部屋の主だけができます。",
	Protocol.ERROR_NOT_READY: "まだ、ぷるりんを選んでいない人がいます。",
	Protocol.ERROR_RACING: "その部屋は、レース中です。終わるまで待ってください。",
	Protocol.ERROR_ROOMS_FULL: "部屋の数が、上限です。ある部屋に入るか、空くのを待ってください。",
	Protocol.ERROR_ROOM_NAME_TAKEN: "同じ名前の部屋が、もうあります。別の名前にしてください。",
	Protocol.ERROR_NO_ROOM: "その部屋は、もうありません。",
	Protocol.ERROR_WRONG_PASSWORD: "パスワードが違います。",
	Protocol.ERROR_TOO_FEW: "出走が2体に足りません（CPUを入れるか、もう1人待ってください）。",
	Protocol.ERROR_IN_ENTRIES: "出走表を見ているあいだは、できません。",
	Protocol.ERROR_NOT_IN_ENTRIES: "出走表でないと、できません。",
	Protocol.ERROR_NOT_CONFIRMED: "まだ、確定していない人がいます。",
}
const KICKED_TEXTS := {
	Protocol.KICKED_BY_HOST: "部屋の主が、あなたを退出させました。",
	Protocol.KICKED_BY_ADMIN: "サーバーの管理人が、あなたを退出させました。",
}

var _client: Node
var _status: Label
var _back_button: Button
## （1）つなぐ前。
var _connect_box: VBoxContainer
var _default_server_radio: CheckBox
var _custom_server_radio: CheckBox
var _server_edit: LineEdit
var _connect_button: Button
var _local_server_card: Control
var _local_server_button: Button
var _local_server_address: Label
## このPCのサーバーを起動してからの秒数（つながるまで。待っていなければ -1）。
var _local_wait_s := -1.0
var _local_retry_s := 0.0
## （2）部屋の一覧。
var _lobby_box: VBoxContainer
var _rooms_title: Label
var _rooms_box: VBoxContainer
var _open_create_button: Button
## 部屋を作る窓。
var _create_dialog: Control
var _room_name_edit: LineEdit
var _create_password_edit: LineEdit
var _create_description_edit: TextEdit
## パスワードを聞く窓（施錠の印の部屋を選んだとき）。
var _join_dialog: Control
var _join_icon: Control
var _join_room_name: Label
var _join_host_name: Label
var _join_count: Label
var _join_lock: Control
var _join_description: Label
var _join_password_row: HBoxContainer
var _join_password_edit: LineEdit
## パスワードを聞いている部屋の番号。
var _joining_room_id := 0
var _room_header: VBoxContainer
var _room_name_row: HBoxContainer
var _room_title: Label
var _room_lock: Control
var _room_info: Label
var _step_pills: Array[PanelContainer] = []
var _step_lines: Array[ColorRect] = []
## 距離のボタン（オフラインと同じ、横並び）。距離 → ボタン。
var _distance_buttons := {}
var _distance_step_buttons: Array[Button] = []
## 出走表で、カーソルを置いている枠（入れ替えの相手を選ぶため。無ければ -1）。
var _selected_gate := -1
## 案内を出した、いまの場面（部屋か、出走表か）。
var _shown_phase := ""
## 最後に出した、部屋のできごとの知らせと、その時刻。
var _notice_text := ""
## いちばん下の行（「戻る」）。部屋の中では出さない（「部屋を出る」と「確定」は、右の列の下に置く）。
var _bottom_row: Control
var _filler: Control
## いま右に出している人。{"peer_id": 人の番号（CPUは0）, "trainer_id": CPUトレーナー（人は空）}。だれも出していなければ空。
var _shown_person := {}
## 紹介の窓。
var _profile_dialog: Control
var _profile_icon: Control
var _profile_portrait: TextureRect
var _profile_name: Label
var _profile_note: Label
var _profile_introduction: Label
## 退出させる窓と、その相手の番号。
var _kick_dialog: Control
var _kick_dialog_title: Label
var _kick_target := 0
var _picker: Control
## 部屋の主だけが押せるボタン（主でない人には、押せなくして見せる）。
var _description_dialog: Control
var _description_edit: TextEdit
## パスワードを確かめる・変える窓（部屋の主だけ）。
var _change_dialog: Control
var _current_password_label: Label
var _password_edit: LineEdit
## 自分の画面の景色を、軽くするか。ゲームモード設定の画質を引き継ぐ（コースと柵だけ・影なし・紙ふぶきなし）。
## 見た目だけの話なので、人によって違っていてよい（レースの計算は、サーバーがやる）。
var _light_scenery := RaceSession.is_course_only()
## 部屋のようす（サーバーから届いた最後のもの。部屋に入っていなければ空）。
var _room := {}
var _members: Array = []
var _connect_wait_s := -1.0
## 待機室。
var _waiting_box: HBoxContainer
## 待機室・レース設定では、上の案内（_status）の代わりに、左の本体の上に案内を出す。
var _waiting_status: Label
var _waiting_race_band: PanelContainer
var _waiting_race_text: Label
var _settings_status: Label
var _waiting_description: Label
var _waiting_host_buttons: Array[Button] = []
## 待機室の席（1席ぶんは {button, icon, portrait, name, mark, kick, peer＝その人の番号。空き席は0}）。
var _seats: Array = []
## 席・部屋の紹介文の吹き出しと、いま出している相手。
var _hover_popup: PanelContainer
var _hover_popup_label: Label
var _hover_target: Control
## ルームチャットの記録の欄（待機室・レース設定・ぷるりんを選ぶ所の、全部）。
var _chat_logs: Array[RichTextLabel] = []
var _ready_button: Button
var _waiting_leave_button: Button
var _race_open_button: Button
var _waiting_note: Label
var _lobby_chat_log: RichTextLabel
var _lobby_chat_edit: LineEdit
var _race_open_popup: CenterContainer
var _race_open_label: Label
var _race_open_until_msec := 0
var _race_open_pending := false
## 画面の切り替えを、知らせを出しているあいだ待たせる。出している画面（"waiting"・"settings"・"pick"・"paddock"）と、待たせる終わりの時刻。
var _held_view := ""
var _hold_until_msec := 0
## さっきまで出していた画面（切り替わったかを見るため）。
var _last_view := ""
## 自分で「待機室へ戻る」を押した（自分の操作なので、知らせを出さずに、すぐ戻る）。
var _self_back := false
## さっきまで、部屋でレースが走っていたか（レースが終わって待機室へ戻るときは、知らせを出さない）。
var _last_racing := false
## レースの始まりの知らせを出してから、レースの画面へ進むまで、届いた中身を持っておく。
var _race_start_data := {}
## レース設定。
var _settings_box: HBoxContainer
var _settings_note: Label
var _settings_seats: Array = []
var _settings_chat_edit: LineEdit
## プル選択。
## パドック。
var _paddock_box: HBoxContainer
var _paddock_info: Label
var _paddock_status: Label
var _paddock_rows: Array = []
var _paddock_gate_buttons: Array[Button] = []
var _paddock_back_button: Button
var _paddock_confirm_button: Button
var _paddock_start_button: Button
var _paddock_chat_edit: LineEdit
var _paddock_dialog: Control
var _paddock_dialog_title: Label
var _paddock_person_icon: Control
var _paddock_person_portrait: TextureRect
var _paddock_person_name: Label
var _paddock_person_note: Label
var _paddock_person_intro: Label
var _paddock_dialog_detail: Control
var _pick_box: HBoxContainer
var _pick_info: Label
var _pick_status: Label
var _pick_rows: Array = []
var _pick_back_button: Button
var _pick_confirm_button: Button
var _pick_paddock_button: Button
var _pick_chat_edit: LineEdit
var _pick_dialog: Control
## 「部屋を出ますか」の窓。
var _leave_dialog: Control
var _pick_dialog_title: Label
var _pick_dialog_detail: Control
var _pick_dialog_empty: Label
var _pick_change_button: Button
## いまステータスの窓・プル選択の窓で見ている席（{"kind": "self"・"cpu"・"player", "cpu_index", "row", "pururin_id"}）。
var _pick_target := {}
## プル選択の窓で押した、選びかけのプル（ステータスの窓で確かめてから決める）。空なら、今の席のプルを見ているだけ。
var _pick_candidate := ""
## プル選択に入ったとき、いつものプルを1回だけ送ったか。
var _auto_pick_sent := false
var _settings_count: Label
var _settings_leave_button: Button
var _settings_back_button: Button
var _settings_next_button: Button


func _ready() -> void:
	_client = OnlineSession.client(get_tree())
	_client.connected.connect(_on_connected)
	_client.message_received.connect(_on_message)
	_client.closed.connect(_on_closed)
	_build()
	_last_view = live_view()
	_last_racing = bool(OnlineSession.room.get("racing", false)) if OnlineSession.in_room() else false
	# レースから戻ってきたときは、部屋に入ったまま。
	if OnlineSession.in_room():
		# レースから戻ってきた。ほかの人が、まだ結果を見ているあいだは、次の準備ができない。
		if bool(OnlineSession.room.get("racing", false)):
			_set_status("ほかの人が、結果を見ています。全員が戻るか、%d秒たつと、次の準備ができます。" % int(OnlineConfig.result_linger_s()))
		else:
			_set_status("部屋「%s」にいます。" % str(OnlineSession.room.get("room", "")))
	elif OnlineSession.in_lobby():
		_set_status("部屋を選ぶか、作ってください。")
	_refresh()


func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.45, 0.45, 0.5, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 28.0, 10.0))
	# 横は、決めた幅でまん中に。縦は、画面の上下に少し余白を残して、いっぱいに使う（画面の高さが変わっても、はみ出さない）。
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = PANEL_SCREEN_MARGIN
	panel.offset_bottom = -PANEL_SCREEN_MARGIN
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	# いちばん上：小さく「ともだち対戦」。右に、ほかの人に見える自分の名前。
	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_theme_constant_override("separation", 14)
	var heading := MenuStyle.label("ともだち対戦", 17, MenuStyle.COLOR_DIM)
	heading.name = "Heading"
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(heading)
	# 部屋の中では、となりに、部屋の名前（大きく）・施錠の印・部屋主と人数。
	_room_name_row = HBoxContainer.new()
	_room_name_row.name = "RoomNameRow"
	_room_name_row.add_theme_constant_override("separation", 12)
	_room_name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_room_name_row)
	_room_title = MenuStyle.label("", 26, MenuStyle.COLOR_FOCUS)
	_room_title.name = "RoomTitle"
	_room_name_row.add_child(_room_title)
	_room_lock = LockMark.new()
	_room_lock.name = "RoomLock"
	_room_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_room_name_row.add_child(_room_lock)
	_room_info = MenuStyle.label("", 15, MenuStyle.COLOR_DIM)
	_room_info.name = "RoomInfo"
	_room_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_room_info.clip_text = true
	_room_name_row.add_child(_room_info)
	# 右上：オンラインで、ほかの人に見える、自分の名前（トレーナー登録の名前）。
	var chip := PanelContainer.new()
	chip.name = "NameChip"
	chip.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_CHIP, 14, 14.0, 4.0))
	top.add_child(chip)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	chip.add_child(chip_row)
	chip_row.add_child(MenuStyle.label("あなた", 14, MenuStyle.COLOR_DIM))
	var name_label := MenuStyle.label(TrainerProfile.trainer_name(), 18)
	name_label.name = "NameLabel"
	chip_row.add_child(name_label)
	_build_room_header(column)
	_status = MenuStyle.label("", 18)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size = Vector2(0.0, 24.0)
	_status.add_theme_color_override("font_color", MenuStyle.COLOR_FOCUS)
	column.add_child(_status)
	_build_connect(column)
	_build_lobby(column)
	_build_waiting(column)
	_build_race_settings(column)
	_build_pick(column)
	_build_paddock(column)
	# つなぐ前・部屋の一覧では、下の「戻る」を、板の下に押し付けるための、すき間。部屋の中では、出さない（部屋の中身が、板の下まで使う）。
	_filler = Control.new()
	_filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_filler)
	_back_button = MenuStyle.button("戻る", 22, MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = Vector2(240.0, BUTTON_HEIGHT)
	_back_button.pressed.connect(go_back)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	# いちばん下の行：左に「戻る」。
	var bottom := HBoxContainer.new()
	bottom.name = "BottomRow"
	column.add_child(bottom)
	bottom.add_child(_back_button)
	var bottom_gap := Control.new()
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_gap)
	_bottom_row = bottom
	_build_dialogs()


## 部屋の中で、上に出す見出し：部屋の名前（施錠の印）・部屋主と人数、その下に、流れの道しるべ（今どこにいるか）。
func _build_room_header(column: VBoxContainer) -> void:
	_room_header = VBoxContainer.new()
	_room_header.name = "RoomHeader"
	_room_header.add_theme_constant_override("separation", 4)
	column.add_child(_room_header)
	var steps := HBoxContainer.new()
	steps.name = "RoomSteps"
	steps.add_theme_constant_override("separation", 6)
	_room_header.add_child(steps)
	for index in ROOM_STEPS.size():
		if index > 0:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(STEP_LINE_WIDTH, 2.0)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			steps.add_child(line)
			_step_lines.append(line)
		var pill := PanelContainer.new()
		pill.name = "Step%d" % (index + 1)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steps.add_child(pill)
		var label := MenuStyle.label("%d  %s" % [index + 1, str(ROOM_STEPS[index])], 15)
		label.name = "StepLabel"
		# 明るい札の上でも、文字がにじまないよう、ふちどりは付けない。
		label.add_theme_constant_override("outline_size", 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(label)
		_step_pills.append(pill)


## 部屋の中の見出しを出し直す。view は今の画面（"waiting"・"settings"・"pick"・"paddock"）。
func _show_room_header(view: String) -> void:
	_room_title.text = str(_room.get("room", ""))
	_room_lock.visible = bool(_room.get("locked", false))
	var count := OnlineSession.all_members().size()
	_room_info.text = "部屋主 %s　%d／%d人" % [member_name(int(_room.get("host", 0))), count, Protocol.ROOM_CAPACITY]
	var current := int(VIEW_STEP_INDEX.get(view, 0))
	for index in _step_pills.size():
		var pill := _step_pills[index]
		var label: Label = pill.get_node("StepLabel")
		var state := "now" if index == current else ("done" if index < current else "next")
		pill.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_STEP_NOW if state == "now" else COLOR_STEP_OTHER, 14, 14.0, 3.0))
		label.text = ("✓ " if state == "done" else "%d  " % (index + 1)) + str(ROOM_STEPS[index])
		label.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE if state == "now" else (COLOR_STEP_DONE if state == "done" else Color(MenuStyle.COLOR_DIM, 0.5)))
		pill.set_meta("state", state)
	for index in _step_lines.size():
		_step_lines[index].color = Color(COLOR_STEP_DONE, 0.8) if index < current else Color(1.0, 1.0, 1.0, 0.15)


func _build_connect(column: VBoxContainer) -> void:
	_connect_box = _centered_column(column, "ConnectBox", LIST_WIDTH)
	var card := _card(_connect_box, "サーバーにつなぐ")
	var group := ButtonGroup.new()
	var default_row := HBoxContainer.new()
	default_row.add_theme_constant_override("separation", 10)
	card.add_child(default_row)
	_default_server_radio = _server_radio("標準のサーバー", "DefaultServerRadio", group)
	default_row.add_child(_default_server_radio)
	var default_url := MenuStyle.label(OnlineConfig.server_url(), 14, MenuStyle.COLOR_DIM)
	default_url.name = "DefaultServerUrl"
	default_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_url.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	default_row.add_child(default_url)
	_custom_server_radio = _server_radio("自分で指定する", "CustomServerRadio", group)
	card.add_child(_custom_server_radio)
	_server_edit = _line_edit("ServerEdit", ServerChoice.custom_url(), 200)
	_server_edit.placeholder_text = "wss://…"
	card.add_child(_server_edit)
	_server_edit.text_submitted.connect(func(_text: String) -> void: connect_to_server())
	var custom := ServerChoice.choice() == ServerChoice.CHOICE_CUSTOM
	_default_server_radio.button_pressed = not custom
	_custom_server_radio.button_pressed = custom
	_default_server_radio.toggled.connect(func(_on: bool) -> void:
		_on_server_choice_changed()
		_update_focus_paths())
	_on_server_choice_changed()
	_connect_button = _big_button(card, "つなぐ", "ConnectButton", connect_to_server, MenuStyle.COLOR_BUTTON)
	MenuStyle.add_mark(_connect_button, "START", 22.0)
	# このPCをサーバーにする：サーバーを裏で起動して、自分もそのままつないで遊ぶ。ブラウザ版では出さない。
	var local := _card(_connect_box, "このPCをサーバーにする")
	_local_server_card = local.get_parent()
	_local_server_card.name = "LocalServerCard"
	_local_server_card.visible = LocalServer.is_supported()
	var note := MenuStyle.label("このPCでサーバーを動かして、自分もそのまま遊べます。同じWi-Fiの人は、下の場所につなぎます（PC版だけ。ブラウザ版からは、つなげません）。", 15, MenuStyle.COLOR_DIM)
	note.name = "LocalServerNote"
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	local.add_child(note)
	_local_server_address = MenuStyle.label("", 15)
	_local_server_address.name = "LocalServerAddress"
	_local_server_address.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	local.add_child(_local_server_address)
	_local_server_button = _big_button(local, "", "LocalServerButton", toggle_local_server, MenuStyle.COLOR_BUTTON_QUIET)
	_show_local_server()


func _server_radio(text: String, node_name: String, group: ButtonGroup) -> CheckBox:
	var radio := CheckBox.new()
	radio.name = node_name
	radio.text = text
	radio.button_group = group
	radio.add_theme_font_size_override("font_size", 20)
	radio.add_theme_icon_override("radio_unchecked", _radio_icon(false))
	radio.add_theme_icon_override("radio_checked", _radio_icon(true))
	UIAudio.bind_button_sound(radio, "confirmation")
	return radio


static func _radio_icon(checked: bool) -> ImageTexture:
	var dot := '<circle cx="11" cy="11" r="5" fill="#ffffff"/>' if checked else ""
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22"><circle cx="11" cy="11" r="9" fill="#263344" stroke="#ffffff" stroke-width="2"/>%s</svg>' % dot)
	return ImageTexture.create_from_image(image)


## 「自分で指定する」を選んだときだけ、入力欄を使えるようにする。選びは、次の起動でも使うので保存する。
func _on_server_choice_changed() -> void:
	var custom := _custom_server_radio.button_pressed
	_server_edit.editable = custom
	_server_edit.focus_mode = Control.FOCUS_ALL if custom else Control.FOCUS_NONE
	_server_edit.modulate = Color.WHITE if custom else Color(1.0, 1.0, 1.0, 0.45)
	ServerChoice.save(ServerChoice.CHOICE_CUSTOM if custom else ServerChoice.CHOICE_DEFAULT, _server_edit.text)


## 今、つなぐ先として選ばれているURL。
func selected_server_url() -> String:
	if _custom_server_radio.button_pressed:
		return _server_edit.text.strip_edges()
	return OnlineConfig.server_url()


## 画面のまん中に置く、決めた幅の縦の並び（画面いっぱいに広げないため）。
func _centered_column(parent: Control, node_name: String, width: float) -> VBoxContainer:
	var inner := VBoxContainer.new()
	inner.name = node_name
	inner.custom_minimum_size = Vector2(width, 0.0)
	inner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_theme_constant_override("separation", 8)
	parent.add_child(inner)
	return inner


## うすい板（見出しつき）。中身を足す縦の並びを返す。
func _card(parent: Control, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_CARD, 12, 16.0, 6.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	if not title.is_empty():
		var heading := MenuStyle.label(title, 17, MenuStyle.COLOR_DIM)
		heading.name = "CardTitle"
		inner.add_child(heading)
	return inner


func _build_lobby(column: VBoxContainer) -> void:
	_lobby_box = _centered_column(column, "LobbyBox", LIST_WIDTH)
	var card := _card(_lobby_box, "")
	_rooms_title = MenuStyle.label("", 18, MenuStyle.COLOR_DIM)
	_rooms_title.name = "RoomsTitle"
	card.add_child(_rooms_title)
	# 列の見出し。
	var header := _room_columns("部屋の名前", "部屋の主", "人数", MenuStyle.COLOR_DIM, 14)
	header.name = "RoomsHeader"
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_right", 16)
	header_margin.add_child(header)
	card.add_child(header_margin)
	_rooms_box = VBoxContainer.new()
	_rooms_box.name = "Rooms"
	_rooms_box.add_theme_constant_override("separation", 6)
	card.add_child(_rooms_box)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, CREATE_BUTTON_GAP)
	_lobby_box.add_child(gap)
	_open_create_button = _big_button(_lobby_box, "＋　部屋を作る", "OpenCreateButton", open_create_dialog, MenuStyle.COLOR_BUTTON_ON)
	_open_create_button.custom_minimum_size = Vector2(CREATE_BUTTON_WIDTH, BUTTON_HEIGHT + 6.0)
	_open_create_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## 一覧の1行ぶんの、列の並び（部屋の名前｜主｜人数｜状態）。状態の列は、空で返す（印や文を、あとで足す）。
func _room_columns(room_name: String, host_name: String, count_text: String, color: Color, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var specs := [["Name", room_name, 0.0], ["Host", host_name, HOST_COLUMN_WIDTH], ["Count", count_text, COUNT_COLUMN_WIDTH]]
	for spec: Array in specs:
		var label := MenuStyle.label(str(spec[1]), font_size, color)
		label.name = str(spec[0])
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if float(spec[2]) > 0.0:
			label.custom_minimum_size = Vector2(float(spec[2]), 0.0)
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	var state := HBoxContainer.new()
	state.name = "State"
	state.custom_minimum_size = Vector2(STATE_COLUMN_WIDTH, 0.0)
	state.alignment = BoxContainer.ALIGNMENT_END
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state)
	return row


## 窓（画面の上に重ねて出す、小さな板）を作る。返すのは、[窓そのもの, 中身を足す縦の並び]。
func _dialog(node_name: String, title: String) -> Array:
	var shade := ColorRect.new()
	shade.name = node_name
	shade.color = COLOR_DIALOG_SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_DIALOG, 16, 26.0, 20.0))
	panel.custom_minimum_size = Vector2(DIALOG_WIDTH, 0.0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := MenuStyle.label(title, 22)
	heading.name = "Title"
	column.add_child(heading)
	return [shade, column]


## 窓の下の「実行」「やめる」の2つのボタン。
func _dialog_buttons(column: VBoxContainer, confirm_text: String, confirm_name: String, confirm: Callable, confirm_color: Color = MenuStyle.COLOR_BUTTON_ON) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for spec: Array in [[confirm_text, confirm_name, confirm, confirm_color, "confirmation"], ["やめる", confirm_name.replace("Button", "CancelButton"), close_dialogs, MenuStyle.COLOR_BUTTON_QUIET, "back"]]:
		var button := MenuStyle.button(str(spec[0]), 20, spec[3])
		button.name = str(spec[1])
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[2])
		UIAudio.bind_button_sound(button, str(spec[4]))
		row.add_child(button)
		if confirm_name in ["CreateButton", "JoinButton", "AdvanceButton"] and button.name == confirm_name:
			_add_mark_beside_text(button, "START", 22.0)
	# 左右の行き先は、窓の2つのボタンどうしだけ（後ろの画面へ出ない）。
	var confirm_button := row.get_child(0) as Button
	var cancel_button := row.get_child(1) as Button
	confirm_button.focus_neighbor_left = confirm_button.get_path_to(confirm_button)
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_neighbor_right = cancel_button.get_path_to(cancel_button)


func _build_dialogs() -> void:
	var create := _dialog("CreateDialog", "部屋を作る")
	_create_dialog = create[0]
	var create_column: VBoxContainer = create[1]
	_room_name_edit = _field(create_column, "部屋の名前", "RoomNameEdit", OnlineConfig.default_room(), Protocol.ROOM_NAME_MAX_LENGTH)
	_room_name_edit.text_submitted.connect(func(_text: String) -> void: create_room())
	_create_password_edit = _field(create_column, "パスワード", "CreatePasswordEdit", "", Protocol.PASSWORD_MAX_LENGTH)
	_create_password_edit.placeholder_text = "空なら、だれでも入れます"
	_create_password_edit.text_submitted.connect(func(_text: String) -> void: create_room())
	create_column.add_child(MenuStyle.label("部屋の紹介", 20))
	_create_description_edit = _text_area("CreateDescriptionEdit", Protocol.ROOM_DESCRIPTION_MAX_LENGTH)
	_create_description_edit.placeholder_text = "入る人に見えます（なくても作れます）"
	create_column.add_child(_create_description_edit)
	var note := MenuStyle.label("作った人が、部屋の主になります。主は、パスワード・部屋の紹介を変えられ、レースを始めるときに、距離と、人の足りない席にCPUを入れるかを決めます。", 16, MenuStyle.COLOR_DIM)
	note.name = "CreateNote"
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	create_column.add_child(note)
	_dialog_buttons(create_column, "作る", "CreateButton", create_room)
	var join := _dialog("JoinDialog", "")
	_join_dialog = join[0]
	var join_column: VBoxContainer = join[1]
	join_column.get_node("Title").visible = false
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 18)
	join_column.add_child(join_row)
	var join_image_box := Control.new()
	join_image_box.custom_minimum_size = Vector2(PROFILE_ICON_SIZE, PROFILE_ICON_SIZE)
	join_image_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	join_image_box.clip_contents = true
	join_row.add_child(join_image_box)
	_join_icon = TrainerIcon.new()
	_join_icon.name = "JoinHostIcon"
	_join_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	join_image_box.add_child(_join_icon)
	var join_text := VBoxContainer.new()
	join_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_text.add_theme_constant_override("separation", 6)
	join_row.add_child(join_text)
	_join_room_name = MenuStyle.label("", 26)
	_join_room_name.name = "JoinRoomName"
	_join_room_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	join_text.add_child(_join_room_name)
	_join_host_name = MenuStyle.label("", 18, MenuStyle.COLOR_FOCUS)
	_join_host_name.name = "JoinHostName"
	join_text.add_child(_join_host_name)
	var join_count_row := HBoxContainer.new()
	join_count_row.add_theme_constant_override("separation", 10)
	join_text.add_child(join_count_row)
	_join_count = MenuStyle.label("", 18)
	_join_count.name = "JoinCount"
	join_count_row.add_child(_join_count)
	_join_lock = LockMark.new()
	_join_lock.name = "JoinLock"
	_join_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join_count_row.add_child(_join_lock)
	_join_description = MenuStyle.label("", 17, MenuStyle.COLOR_DIM)
	_join_description.name = "JoinDescription"
	_join_description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	join_column.add_child(_join_description)
	_join_password_row = HBoxContainer.new()
	_join_password_row.name = "JoinPasswordRow"
	_join_password_row.add_theme_constant_override("separation", 10)
	join_column.add_child(_join_password_row)
	var join_password_label := MenuStyle.label("パスワード", 20)
	join_password_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	_join_password_row.add_child(join_password_label)
	_join_password_edit = _line_edit("JoinPasswordEdit", "", Protocol.PASSWORD_MAX_LENGTH)
	_join_password_edit.text_submitted.connect(func(_text: String) -> void: join_with_password())
	_join_password_row.add_child(_join_password_edit)
	_dialog_buttons(join_column, "入室する", "JoinButton", join_with_password)
	var change := _dialog("PasswordChangeDialog", "部屋のパスワード")
	_change_dialog = change[0]
	var change_column: VBoxContainer = change[1]
	_current_password_label = MenuStyle.label("", 20)
	_current_password_label.name = "CurrentPassword"
	change_column.add_child(_current_password_label)
	_password_edit = _field(change_column, "新しくする", "PasswordEdit", "", Protocol.PASSWORD_MAX_LENGTH)
	_password_edit.placeholder_text = "空にして変えると、施錠なし"
	_password_edit.text_submitted.connect(func(_text: String) -> void: change_password())
	var change_note := MenuStyle.label("変えても、もう部屋にいる人は、そのまま残ります。次に入る人から、新しいパスワードが要ります。", 16, MenuStyle.COLOR_DIM)
	change_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	change_column.add_child(change_note)
	_dialog_buttons(change_column, "変える", "PasswordChangeButton", change_password)
	var description_parts := _dialog("DescriptionDialog", "部屋の紹介")
	_description_dialog = description_parts[0]
	var description_column: VBoxContainer = description_parts[1]
	_description_edit = _text_area("DescriptionEdit", Protocol.ROOM_DESCRIPTION_MAX_LENGTH)
	_description_edit.placeholder_text = "入る人に見えます（空なら、紹介なし）"
	description_column.add_child(_description_edit)
	var description_note := MenuStyle.label("部屋に入る前の人と、待機室の上に出る文です。", 16, MenuStyle.COLOR_DIM)
	description_column.add_child(description_note)
	_dialog_buttons(description_column, "変える", "DescriptionChangeButton", change_description)
	var profile_parts := _dialog("ProfileDialog", "")
	_profile_dialog = profile_parts[0]
	var profile_column: VBoxContainer = profile_parts[1]
	profile_column.get_node("Title").visible = false
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 18)
	profile_column.add_child(profile_row)
	var image_box := Control.new()
	image_box.custom_minimum_size = Vector2(PROFILE_ICON_SIZE, PROFILE_ICON_SIZE)
	image_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	image_box.clip_contents = true
	profile_row.add_child(image_box)
	_profile_icon = TrainerIcon.new()
	_profile_icon.name = "ProfileIcon"
	_profile_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_box.add_child(_profile_icon)
	_profile_portrait = _portrait_rect("ProfilePortrait")
	image_box.add_child(_profile_portrait)
	var profile_text := VBoxContainer.new()
	profile_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_text.add_theme_constant_override("separation", 6)
	profile_row.add_child(profile_text)
	_profile_name = MenuStyle.label("", 26)
	_profile_name.name = "ProfileName"
	profile_text.add_child(_profile_name)
	_profile_note = MenuStyle.label("", 15, MenuStyle.COLOR_FOCUS)
	_profile_note.name = "ProfileNote"
	profile_text.add_child(_profile_note)
	_profile_introduction = MenuStyle.label("", 17)
	_profile_introduction.name = "ProfileIntroduction"
	_profile_introduction.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	profile_text.add_child(_profile_introduction)
	var profile_close := MenuStyle.button("閉じる", 20, MenuStyle.COLOR_BUTTON_QUIET)
	profile_close.name = "ProfileCloseButton"
	profile_close.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	profile_close.pressed.connect(close_dialogs)
	UIAudio.bind_button_sound(profile_close, "back")
	profile_column.add_child(profile_close)
	var kick_parts := _dialog("KickDialog", "")
	_kick_dialog = kick_parts[0]
	var kick_column: VBoxContainer = kick_parts[1]
	_kick_dialog_title = kick_column.get_node("Title")
	var kick_note := MenuStyle.label("この人を、部屋から退出させますか。退出した人は、部屋の一覧へ戻ります。", 17, MenuStyle.COLOR_DIM)
	kick_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	kick_column.add_child(kick_note)
	_dialog_buttons(kick_column, "退出させる", "KickConfirmButton", confirm_kick, COLOR_DANGER_BUTTON)
	var leave_parts := _dialog("LeaveDialog", "部屋を出ますか")
	_leave_dialog = leave_parts[0]
	var leave_column: VBoxContainer = leave_parts[1]
	var leave_note := MenuStyle.label("部屋を出て、部屋の一覧へ戻ります。", 17, MenuStyle.COLOR_DIM)
	leave_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	leave_column.add_child(leave_note)
	_dialog_buttons(leave_column, "部屋を出る", "LeaveConfirmButton", confirm_leave_room, COLOR_DANGER_BUTTON)


## 「部屋を作る」：作る窓を出す。
func open_create_dialog() -> void:
	close_dialogs()
	_create_dialog.visible = true
	_room_name_edit.grab_focus()


## 部屋の主：今のパスワードを確かめて、変える窓を出す。
func open_password_change_dialog() -> void:
	close_dialogs()
	var current := str(_room.get("password", ""))
	_current_password_label.text = "今のパスワード：%s" % (current if not current.is_empty() else "なし（だれでも入れます）")
	_password_edit.text = current
	_change_dialog.visible = true
	_password_edit.grab_focus()


## 部屋の主：部屋の紹介を書き換える窓を出す。
func open_description_dialog() -> void:
	close_dialogs()
	_description_edit.text = str(_room.get("description", ""))
	_description_dialog.visible = true
	_description_edit.grab_focus()


## 窓の「変える」：部屋の紹介を、入力らんの文字に変える（部屋の主だけ）。
func change_description() -> void:
	_client.send(Protocol.SETTINGS, {"description": _description_edit.text.replace("\n", " ")})
	_set_status("部屋の紹介を変えました。" if not _description_edit.text.strip_edges().is_empty() else "部屋の紹介を空にしました。")
	close_dialogs()


## 窓を、すべて閉じる。
func close_dialogs() -> void:
	_create_dialog.visible = false
	_join_dialog.visible = false
	_change_dialog.visible = false
	_description_dialog.visible = false
	_kick_dialog.visible = false
	_profile_dialog.visible = false
	_pick_dialog.visible = false
	_paddock_dialog.visible = false
	_leave_dialog.visible = false
	_pick_candidate = ""
	_kick_target = 0
	_joining_room_id = 0
	_join_password_edit.text = ""
	_restore_focus()


func is_dialog_open() -> bool:
	return _create_dialog.visible or _join_dialog.visible or _change_dialog.visible or _description_dialog.visible or _kick_dialog.visible or _profile_dialog.visible or _pick_dialog.visible or _paddock_dialog.visible or _leave_dialog.visible


func _build_distance_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "DistanceRow"
	row.add_theme_constant_override("separation", 6)
	# レース設定の本体（画面の5分の3）に収まるよう、文字と余白は小さめ。
	var caption := MenuStyle.label("距離", 18, MenuStyle.COLOR_DIM)
	row.add_child(caption)
	row.add_child(_distance_step_button(-1))
	for distance_m: float in RaceSession.supported_distances_m():
		var button := MenuStyle.button("%d m" % int(distance_m), 17, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = "Distance%d" % int(distance_m)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, DISTANCE_BUTTON_HEIGHT)
		_compact(button, 4.0, 6.0)
		for state: String in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, MenuStyle.box(MenuStyle.COLOR_BUTTON_ON, 10, 6.0, 4.0))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("ui_audio_focus_sound", "selection_cycle")
		button.pressed.connect(set_distance.bind(distance_m))
		# カーソルを合わせると、そのまま、その距離になる。
		button.focus_entered.connect(_on_distance_focused.bind(distance_m))
		UIAudio.bind_button_sound(button, "confirmation")
		row.add_child(button)
		_distance_buttons[distance_m] = button
	row.add_child(_distance_step_button(1))
	return row


## 距離を1つ動かすボタン。左が「‹ L1」、右が「R1 ›」。茶色の丸い形で、矢印とマークは金色（オフラインと同じ）。
func _distance_step_button(direction: int) -> Button:
	var button := Button.new()
	button.text = "‹" if direction < 0 else "›"
	button.name = "DistancePrev" if direction < 0 else "DistanceNext"
	button.custom_minimum_size = Vector2(DISTANCE_STEP_BUTTON_WIDTH, 34.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, ButtonMark.COLOR_GOLD)
	button.add_theme_stylebox_override("normal", _step_button_box(COLOR_STEP_BUTTON, COLOR_STEP_BUTTON_BORDER))
	button.add_theme_stylebox_override("disabled", _step_button_box(COLOR_STEP_BUTTON, COLOR_STEP_BUTTON_BORDER))
	button.add_theme_stylebox_override("hover", _step_button_box(COLOR_STEP_BUTTON.lightened(0.12), COLOR_STEP_BUTTON_BORDER.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _step_button_box(COLOR_STEP_BUTTON.lightened(0.25), ButtonMark.COLOR_GOLD))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if direction < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var mark := MenuStyle.mark("L1" if direction < 0 else "R1", DISTANCE_MARK_SIZE)
	mark.name = "ButtonMark"
	button.add_child(mark)
	var mark_width := float(mark.custom_minimum_size.x)
	mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT if direction < 0 else Control.PRESET_CENTER_LEFT)
	mark.offset_left = -9.0 - mark_width if direction < 0 else 9.0
	mark.offset_right = mark.offset_left + mark_width
	mark.offset_top = -DISTANCE_MARK_SIZE * 0.5
	mark.offset_bottom = DISTANCE_MARK_SIZE * 0.5
	button.pressed.connect(step_distance.bind(direction, "mouse"))
	_distance_step_buttons.append(button)
	return button


static func _step_button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(18)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 4.0
	return box


## 部屋の主が、距離を変えられる場面か（部屋の場面だけ。出走表では、変えられない）。
func can_set_distance() -> bool:
	return OnlineSession.in_room() and is_host() and OnlineSession.phase() == Protocol.PHASE_SETTINGS


## 距離のボタンにカーソルが来た：変えられる人なら、そのまま、その距離にする。
func _on_distance_focused(distance_m: float) -> void:
	if can_set_distance() and not is_equal_approx(distance_m, float(_room.get("distance_m", 0.0))):
		_client.send(Protocol.SETTINGS, {"distance_m": distance_m})


## 距離を、1つ前（-1）か次（1）へ動かす（部屋の主だけ）。端では止まる。
func step_distance(direction: int, source: String = "gamepad") -> void:
	var distances: Array = RaceSession.supported_distances_m()
	var index := distances.find(float(_room.get("distance_m", 0.0)))
	var next := clampi(index + direction, 0, distances.size() - 1)
	if not can_set_distance() or index < 0 or next == index:
		UIAudio.play_error()
		return
	_client.send(Protocol.SETTINGS, {"distance_m": float(distances[next])})
	if source == "mouse":
		UIAudio.play_arrow_click()
	else:
		UIAudio.play_selection_cycle()
	# 距離の段を選んでいるときは、選択の枠も、動かした先の距離へ付いていく。
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and _distance_buttons.values().has(focused):
		(_distance_buttons[float(distances[next])] as Button).grab_focus()


func confirm_kick() -> void:
	if _kick_target != 0:
		kick(_kick_target)
	close_dialogs()


func member_name(peer_id: int) -> String:
	for member: Dictionary in OnlineSession.all_members():
		if int(member["peer_id"]) == peer_id:
			return str(member["name"])
	return ""


## CPUトレーナーの絵を出す、四角（板いっぱい）。
func _portrait_rect(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## その人（CPUはトレーナー）の画像を、画像の部品に出す。icon は人用、portrait はCPUトレーナー用。
func _show_person_image(person: Dictionary, icon: Control, portrait: TextureRect) -> void:
	var is_cpu := int(person.get("peer_id", 0)) == 0
	icon.visible = not is_cpu
	portrait.visible = is_cpu
	if is_cpu:
		var path := str(CpuTrainers.by_id(str(person.get("trainer_id", ""))).get("portrait_path", ""))
		portrait.texture = load(path) if ResourceLoader.exists(path) else null
		return
	var peer_id := int(person["peer_id"])
	var profile: Dictionary = OnlineSession.profiles.get(peer_id, {})
	# 紹介がまだ届いていなくても、用意された絵のアイコンなら、部屋のようすに入っている種類と番号で、すぐ出す。
	if profile.is_empty():
		for member: Dictionary in OnlineSession.all_members():
			if int(member["peer_id"]) == peer_id and member.get("icon") is Dictionary:
				profile = {"kind": str(member["icon"].get("kind", "none")), "id": str(member["icon"].get("id", "")), "texture": null}
		if str(profile.get("kind", "")) == "file":
			profile = {}
	icon.call("show_icon", str(profile.get("kind", "none")), str(profile.get("id", "")), profile.get("texture"))


## 板の右上の画像を押した：その人の紹介の窓を出す（人は、名前・自己紹介。CPUは、トレーナーの名前・得意脚質・紹介）。
func open_profile_dialog() -> void:
	if _shown_person.is_empty():
		return
	close_dialogs()
	_show_person_image(_shown_person, _profile_icon, _profile_portrait)
	var peer_id := int(_shown_person.get("peer_id", 0))
	# 主は、CPUのトレーナーを、ここから変えられる。
	if peer_id == 0:
		var trainer := CpuTrainers.by_id(str(_shown_person.get("trainer_id", "")))
		_profile_name.text = str(trainer.get("name", "CPU"))
		_profile_note.text = "CPUトレーナー　得意脚質：%s" % str(STYLE_NAMES.get(str(trainer.get("favorite_running_style", "")), ""))
		_profile_introduction.text = str(trainer.get("introduction", ""))
	else:
		var profile: Dictionary = OnlineSession.profiles.get(peer_id, {})
		_profile_name.text = str(profile.get("name", member_name(peer_id)))
		var notes: PackedStringArray = []
		if peer_id == OnlineSession.peer_id:
			notes.append("あなた")
		if peer_id == int(_room.get("host", 0)):
			notes.append("部屋の主")
		_profile_note.text = "・".join(notes) if not notes.is_empty() else "プレイヤー"
		_profile_introduction.text = str(profile.get("introduction", "")) if not str(profile.get("introduction", "")).is_empty() else "（自己紹介は、ありません）"
	_profile_dialog.visible = true
	(_profile_dialog.find_child("ProfileCloseButton", true, false) as Button).grab_focus()


## 紹介の窓で見せる人を決める（席を押したとき）。
func _show_person(person: Dictionary) -> void:
	_shown_person = person


func is_picker_open() -> bool:
	return bool(_picker.call("is_open"))


func _on_picker_picked(pururin_id: String) -> void:
	_picker.call("close")
	if not _pick_target.is_empty():
		_open_pick_candidate(pururin_id)


## プル選択の窓を、選ばずに閉じた（B・Esc・閉じるボタン）。カーソルを、選んでいた席へ戻す（ゲームパッドで動けなくならないように）。
## プルを押して閉じたときは、続けてステータスの窓が開くので、何もしない。
func _on_picker_closed() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or is_dialog_open() or is_picker_open():
		return
	var row := int(_pick_target.get("row", -1))
	_pick_target = {}
	if row >= 0 and row < _pick_rows.size() and (_pick_rows[row]["button"] as Button).is_visible_in_tree():
		(_pick_rows[row]["button"] as Button).grab_focus()
	else:
		_restore_focus()


static func _compact(button: Button, margin_y: float, margin_x: float = -1.0) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_top = margin_y
		box.content_margin_bottom = margin_y
		if margin_x >= 0.0:
			box.content_margin_left = margin_x
			box.content_margin_right = margin_x
		button.add_theme_stylebox_override(state, box)


func _big_button(parent: Control, text: String, node_name: String, action: Callable, color: Color) -> Button:
	var button := MenuStyle.button(text, 22, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	UIAudio.bind_button_sound(button, "confirmation")
	parent.add_child(button)
	return button


func _line_edit(node_name: String, text: String, max_length: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.text = text
	edit.max_length = max_length
	edit.custom_minimum_size = Vector2(0.0, FIELD_HEIGHT)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 20)
	return edit


## 3行ぶんの入力らん（部屋の紹介）。決めた字数を超えたぶんは、切る。
func _text_area(node_name: String, max_length: int) -> TextEdit:
	var edit := TextEdit.new()
	edit.name = node_name
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit.custom_minimum_size = Vector2(0.0, DESCRIPTION_EDIT_HEIGHT)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 18)
	edit.text_changed.connect(func() -> void:
		if edit.text.length() > max_length:
			edit.text = edit.text.left(max_length)
			edit.set_caret_column(edit.text.length()))
	return edit


## 「名前　入力らん」の1行を足して、入力らんを返す。
func _field(column: VBoxContainer, title: String, node_name: String, text: String, max_length: int) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := MenuStyle.label(title, 20)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)
	var edit := _line_edit(node_name, text, max_length)
	row.add_child(edit)
	return edit


func _process(delta: float) -> void:
	_wait_for_local_server(delta)
	# 窓を閉じた・ボタンが消えたなどで、カーソルの行き場がなくなったら、その画面の決まった所へ戻す
	# （ゲームパッドだけで遊んでいても、動けなくならないように）。
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		_restore_focus()
	if _race_open_popup.visible and Time.get_ticks_msec() >= _race_open_until_msec:
		_race_open_popup.visible = false
		if not _race_start_data.is_empty():
			var data := _race_start_data
			_race_start_data = {}
			_go_to_race(data)
			return
	# 知らせを出し終えたら、待たせていた画面の切り替えをする。
	if not _held_view.is_empty() and Time.get_ticks_msec() >= _hold_until_msec:
		_held_view = ""
		_set_status(phase_guide(OnlineSession.phase()))
		_refresh()
	# つながるのを待つのは、決めた秒数まで。
	if _connect_wait_s >= 0.0:
		_connect_wait_s += delta
		if _connect_wait_s >= OnlineConfig.connect_timeout_s():
			_connect_wait_s = -1.0
			_client.disconnect_from_server()
			_set_status("サーバーにつながりません。サーバーの場所を確かめてください。")
			_refresh()


# ---------------------------------------------------------------- つなぐ・部屋の一覧

## 「このPCをサーバーにする」のボタン：止まっていれば起動して、つなぐ。動いていれば、止める。
func toggle_local_server() -> void:
	if LocalServer.is_running():
		stop_local_server()
	else:
		start_local_server()


## このPCのサーバーを起動する。起動しきるまで、つなぎ直しながら待つ。
func start_local_server() -> void:
	if LocalServer.start(get_tree()) != OK:
		_set_status("このPCでサーバーを起動できませんでした。")
		return
	_local_wait_s = 0.0
	_local_retry_s = LOCAL_SERVER_RETRY_S
	_set_status("このPCでサーバーを起動しています…")
	_show_local_server()


## このPCのサーバーを止める（つないでいたら、切る）。
func stop_local_server() -> void:
	_local_wait_s = -1.0
	if _client.is_open():
		_client.disconnect_from_server()
	LocalServer.stop()
	_set_status("このPCのサーバーを止めました。")
	_show_local_server()


func _wait_for_local_server(delta: float) -> void:
	if _local_wait_s < 0.0 or _client.is_open():
		return
	_local_wait_s += delta
	_local_retry_s -= delta
	if _local_wait_s >= LOCAL_SERVER_START_TIMEOUT_S or not LocalServer.is_running():
		_local_wait_s = -1.0
		_set_status("このPCのサーバーにつながりません。もう一度「始める」を押してください。")
		_show_local_server()
		return
	if _local_retry_s <= 0.0:
		_local_retry_s = LOCAL_SERVER_RETRY_S
		_client.connect_to(LocalServer.local_url())


## このPCがサーバーのときの、案内の頭（ほかの人がつなぐ場所）。サーバーでなければ空。
func local_server_note() -> String:
	if not LocalServer.is_running():
		return ""
	var urls := LocalServer.lan_urls()
	return "このPCがサーバーです（同じWi-Fiの人は %s につなぎます）。" % urls[0] if not urls.is_empty() else "このPCがサーバーです。"


## 「このPCをサーバーにする」の欄を、今の状態に合わせる。
func _show_local_server() -> void:
	if _local_server_button == null:
		return
	var running := LocalServer.is_running()
	_local_server_button.text = "このPCのサーバーを止める" if running else "このPCでサーバーを始めて、つなぐ"
	var urls := LocalServer.lan_urls()
	_local_server_address.text = "ほかの人がつなぐ場所：%s" % ("　".join(urls) if not urls.is_empty() else "（このPCの番号が見つかりません）")


## 「サーバーにつなぐ」：つないで、名乗る。名乗ると、部屋の一覧が届く。
func connect_to_server() -> void:
	var url := selected_server_url()
	ServerChoice.save(ServerChoice.CHOICE_CUSTOM if _custom_server_radio.button_pressed else ServerChoice.CHOICE_DEFAULT, _server_edit.text)
	if not OnlineConfig.is_server_url(url):
		_set_status("サーバーの場所は、ws:// か wss:// で始めてください。")
		return
	if _client.is_open():
		_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())
		return
	var error: Error = _client.connect_to(url)
	if error != OK:
		_set_status("サーバーにつながりません（%s）。" % error_string(error))
		return
	_connect_wait_s = 0.0
	_set_status("サーバーにつないでいます…")


func _on_connected() -> void:
	_connect_wait_s = -1.0
	if _local_wait_s >= 0.0:
		_local_wait_s = -1.0
		_set_status("このPCのサーバーにつながりました。")
	_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())


## 作る窓の「作る」。
func create_room() -> void:
	var room_name := Protocol.clean_text(_room_name_edit.text, Protocol.ROOM_NAME_MAX_LENGTH)
	if room_name.is_empty():
		_set_status("部屋の名前を入れてください。")
		return
	_client.create_room(room_name, _create_password_edit.text, _create_description_edit.text.replace("\n", " "))
	close_dialogs()


## 一覧の部屋を選んだ：すぐには入らず、サーバーに、その部屋のくわしい紹介を聞く。届いたら、入室の窓を出す。
func choose_room(room_id: int) -> void:
	_joining_room_id = room_id
	_client.peek_room(room_id)


## くわしい紹介が届いた：部屋の名前・主の名前と画像・人数・部屋の紹介の窓を出す。パスワード付きの部屋は、入力らんも出す。
func _open_join_dialog(info: Dictionary) -> void:
	close_dialogs()
	_joining_room_id = int(info["room_id"])
	_join_room_name.text = str(info.get("name", ""))
	_join_host_name.text = "部屋の主　%s" % str(info.get("host_name", ""))
	_join_count.text = "人数　%d／%d" % [int(info.get("count", 0)), int(info.get("capacity", 0))]
	var locked := bool(info.get("locked", false))
	_join_lock.visible = locked
	var description := str(info.get("description", ""))
	_join_description.text = description if not description.is_empty() else "（部屋の紹介は、ありません）"
	var host := OnlineSession.profile_from({"name": info.get("host_name", ""), "icon": info.get("host_icon", {})})
	_join_icon.call("show_icon", str(host["kind"]), str(host["id"]), host["texture"])
	_join_password_row.visible = locked
	_join_dialog.visible = true
	if locked:
		_join_password_edit.grab_focus()
	else:
		(_join_dialog.find_child("JoinButton", true, false) as Button).grab_focus()


## 入室の窓の「入室する」。
func join_with_password() -> void:
	if _joining_room_id != 0:
		_client.join_room(_joining_room_id, _join_password_edit.text)
	close_dialogs()


## 部屋を出て、部屋の一覧へ戻る。
## 「部屋を出る」・B：いきなり出ずに、確かめる。はじめのカーソルは「やめる」。
func open_leave_dialog() -> void:
	close_dialogs()
	_leave_dialog.visible = true
	(_leave_dialog.find_child("LeaveConfirmCancelButton", true, false) as Button).grab_focus()


func confirm_leave_room() -> void:
	close_dialogs()
	leave_room()


func leave_room() -> void:
	_client.send(Protocol.LEAVE)


func _on_message(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.LOBBY:
			if not _status.text in KICKED_TEXTS.values():
				_set_status(local_server_note() + "部屋を選ぶか、作ってください。")
			_refresh()
		Protocol.ROOMS:
			_refresh()
		Protocol.WELCOME:
			_shown_phase = str(data.get("phase", Protocol.PHASE_LOBBY))
			_last_view = live_view()
			_held_view = ""
			_set_status("部屋に入りました。" + phase_guide(OnlineSession.phase()))
			_refresh()
		Protocol.ROOM:
			_hold_view_change()
			if _race_open_pending:
				_race_open_pending = false
				if not OnlineSession.am_racer():
					show_race_open_popup()
			# 場面が替わったら、することを案内する。
			var phase := str(data.get("phase", ""))
			if phase != _shown_phase:
				_shown_phase = phase
				# 場面が替わったら、することの案内だけにする（できごとの知らせは、チャットに残っている）。
				# 知らせを出して前の画面を見せているあいだは、案内も替えず、切り替わってから替える。
				if _held_view.is_empty():
					_set_status(phase_guide(phase))
			_refresh()
		Protocol.NOTICE:
			# 部屋のできごと（入った・出た・主が替わった）：上の案内と、ひとことの欄の両方に出す。
			_notice_text = OnlineSession.notice_text(data)
			_set_status(_notice_text)
			_show_chat()
			if str(data.get("kind", "")) == Protocol.NOTICE_RACE_OPEN:
				# 知らせは、部屋のようす（レースに出る人）が届いてから出す。
				_race_open_pending = true
		Protocol.CHAT_MESSAGE:
			_show_chat()
		Protocol.ROOM_INFO:
			# 押した部屋のくわしい紹介が届いた（押したあとに、別の部屋を押していたら、古い返事は使わない）。
			if int(data["room_id"]) == _joining_room_id and OnlineSession.in_lobby():
				_open_join_dialog(data)
		Protocol.PROFILE_INFO:
			# 紹介（アイコンの画像）が届いた。席・行の画像を出し直す。
			if int(data["peer_id"]) == int(_shown_person.get("peer_id", -1)):
				_show_person(_shown_person)
			if OnlineSession.in_room():
				_refresh()
		Protocol.KICKED:
			_set_status(str(KICKED_TEXTS.get(str(data.get("by", "")), "部屋から退出させられました。")))
		Protocol.RACE_START:
			# まず知らせを出し、少し待ってから、レースの画面へ進む。
			_race_start_data = data
			_show_popup_text(RACE_START_TEXT)
		Protocol.ERROR:
			_set_status(str(ERROR_TEXTS.get(str(data.get("code", "")), "サーバーに断られました。")))


func _on_closed() -> void:
	# このPCのサーバーが起動しきるまでは、つながらなくても、黙ってつなぎ直す。
	if _local_wait_s >= 0.0:
		return
	var was_waiting := _connect_wait_s >= 0.0
	_connect_wait_s = -1.0
	_set_status("サーバーにつながりません。サーバーの場所を確かめてください。" if was_waiting else "サーバーとのつながりが切れました。")
	_refresh()


## いま出すべき画面（部屋の場面と、自分がレースに出る人か、で決まる）。部屋の外では空。
func live_view() -> String:
	if not OnlineSession.in_room():
		return ""
	if OnlineSession.in_waiting_room():
		return "waiting"
	match OnlineSession.phase():
		Protocol.PHASE_SETTINGS:
			return "settings"
		Protocol.PHASE_ENTRIES:
			return "paddock"
	return "pick"


## 部屋主の操作で画面が切り替わるときは、知らせを2秒ほど出して、そのあいだは前の画面のままにする。
## 自分で「待機室へ戻る」を押したとき、知らせの決まっていない切り替わりは、すぐ切り替える。
func _hold_view_change() -> void:
	var now_view := live_view()
	var before := _held_view if not _held_view.is_empty() else _last_view
	_last_view = now_view
	var racing_before := _last_racing
	_last_racing = bool(OnlineSession.room.get("racing", false))
	if before.is_empty() or before == now_view or racing_before:
		_held_view = ""
		return
	if _self_back:
		_self_back = false
		_held_view = ""
		return
	var text := str(VIEW_CHANGE_TEXTS.get("%s>%s" % [before, now_view], ""))
	if before == "waiting" and now_view == "settings":
		text = RACE_OPEN_TEXT
	if text.is_empty():
		_held_view = ""
		return
	_held_view = before
	_hold_until_msec = Time.get_ticks_msec() + RACE_OPEN_POPUP_MSEC
	_show_popup_text(text)


## 画面のまん中に、知らせを2秒ほど出す。
func _show_popup_text(text: String) -> void:
	_race_open_label.text = text
	_race_open_popup.visible = true
	_race_open_until_msec = Time.get_ticks_msec() + RACE_OPEN_POPUP_MSEC


## 場面ごとの、することの案内。
func phase_guide(phase: String) -> String:
	if OnlineSession.in_waiting_room():
		if phase != Protocol.PHASE_LOBBY:
			return "いまレース中です。「準備OK」を押しておくと、次のレースに出られます。"
		return "準備ができたら「準備OK」を押してください。" if not is_host() else "そろったら「レース設定へ」を押してください。準備OKの人がレースに進みます。"
	match phase:
		Protocol.PHASE_SETTINGS:
			return "距離と、人の足りない席にCPUを入れるかを決めて、「次へ」を押してください。" if is_host() else "部屋主が、距離と出走する席を決めています。"
		Protocol.PHASE_ENTRIES:
			return "枠順とプルを確かめて、「確定」を押してください。"
	return "プルが決まったら「確定」。全員そろったら「パドックへ」を押してください。" if is_host() else "プルが決まったら「確定」を押してください。"


func _set_status(text: String) -> void:
	_status.text = text
	if _waiting_status != null:
		_waiting_status.text = text
		_settings_status.text = text
		_pick_status.text = text
		_paddock_status.text = text


## 今の場面（つなぐ前・部屋の一覧・部屋の中）に合わせて、画面を出し直す。
func _refresh() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	# 部屋一覧の行は作り直すので、ノードではなく部屋の名前で選択を引き継ぐ。
	var focused_room := str(previous_focus.name) if previous_focus != null and previous_focus.get_parent() == _rooms_box else ""
	var in_room := OnlineSession.in_room()
	var in_lobby := OnlineSession.in_lobby() and not in_room
	_room = OnlineSession.room if in_room else {}
	_members = OnlineSession.members() if in_room else []
	# 知らせを出しているあいだは、前の画面のまま。
	var view := (_held_view if not _held_view.is_empty() else live_view()) if in_room else ""
	var waiting := view == "waiting"
	var settings := view == "settings"
	var picking := view == "pick"
	if not picking:
		_auto_pick_sent = false
		_pick_dialog.visible = false
	_connect_box.visible = not in_room and not in_lobby
	_show_local_server()
	_lobby_box.visible = in_lobby
	_waiting_box.visible = waiting
	_settings_box.visible = settings
	# 待機室・レース設定では、案内は、左のパネルの中に出す（上には出さない）。
	_status.visible = not waiting and not settings and not picking and view != "paddock"
	_pick_box.visible = picking
	_paddock_box.visible = view == "paddock"
	if view != "paddock":
		_paddock_dialog.visible = false
	# 「部屋を出ますか」は、待機室・レース設定の窓。主の操作で画面が進んだら閉じる。
	if not waiting and not settings:
		_leave_dialog.visible = false
	_room_header.visible = in_room
	_room_name_row.visible = in_room
	if in_room:
		_show_room_header(view)
	if not waiting and not settings and not in_lobby:
		_hover_popup.visible = false
	if not picking and is_picker_open() and not _pick_target.is_empty():
		_picker.call("close")
	# 場面が変わったら、その場面のものでない窓は閉じる。
	if not in_lobby:
		_create_dialog.visible = false
		_join_dialog.visible = false
	if not in_room or not OnlineSession.is_host():
		_change_dialog.visible = false
		_description_dialog.visible = false
	if not in_room and is_picker_open():
		_picker.call("close")
	if not in_room or not OnlineSession.is_host():
		_kick_dialog.visible = false
	_bottom_row.visible = not in_room
	_filler.visible = not in_room
	if in_lobby:
		_show_rooms()
	if waiting:
		_show_waiting()
		_show_chat()
	elif settings:
		_show_settings()
		_show_chat()
	elif picking:
		_show_pick()
		_show_chat()
	elif view == "paddock":
		_show_paddock()
		_show_chat()
	_update_focus_paths()
	if not focused_room.is_empty() and in_lobby:
		var rebuilt := _rooms_box.get_node_or_null(NodePath(focused_room)) as Button
		if rebuilt != null and not rebuilt.disabled:
			rebuilt.grab_focus()
	_restore_focus()


## つなぐ前と一覧の上下・Tabの行き先を、見えているボタンだけでつなぐ。
func _update_focus_paths() -> void:
	var controls: Array[Control] = []
	if _connect_box.visible:
		controls.assign([_default_server_radio, _custom_server_radio])
		if _server_edit.editable:
			controls.append(_server_edit)
		controls.append(_connect_button)
		if _local_server_card.visible:
			controls.append(_local_server_button)
		controls.append(_back_button)
	elif _lobby_box.visible:
		for child in _rooms_box.get_children():
			if child is Button and not child.disabled:
				controls.append(child)
		if not _open_create_button.disabled:
			controls.append(_open_create_button)
		controls.append(_back_button)
	else:
		_back_button.focus_neighbor_top = NodePath("")
		_back_button.focus_neighbor_bottom = NodePath("")
		_back_button.focus_previous = NodePath("")
		_back_button.focus_next = NodePath("")
	for index in controls.size():
		var current := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(next)


## 初回・切断・場面替えで選択がなくなったときだけ、操作できる場所に戻す。
func _restore_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused) and focused.is_visible_in_tree() and focused.focus_mode != Control.FOCUS_NONE:
		if not focused is BaseButton or not focused.disabled:
			return
	if is_dialog_open() or is_picker_open():
		return
	if _connect_box.visible:
		_connect_button.grab_focus()
	elif _lobby_box.visible:
		for child in _rooms_box.get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				return
		if not _open_create_button.disabled:
			_open_create_button.grab_focus()
		else:
			_back_button.grab_focus()
	elif _waiting_box.visible:
		(_race_open_button if is_host() else _ready_button).grab_focus()
	elif _settings_box.visible:
		(_settings_next_button if is_host() else _settings_leave_button).grab_focus()
	elif _paddock_box.visible:
		var target := _selected_gate if _selected_gate >= 0 else 0
		for index in (_room.get("entries", []) as Array).size():
			if int(_room["entries"][index].get("peer_id", 0)) == OnlineSession.peer_id and _selected_gate < 0:
				target = index
		(_paddock_rows[mini(target, _paddock_rows.size() - 1)]["button"] as Button).grab_focus()
	elif _pick_box.visible:
		for row: Dictionary in _pick_rows:
			if str(row["kind"]) == "self":
				(row["button"] as Button).grab_focus()
				return
		_pick_back_button.grab_focus()
	else:
		_back_button.grab_focus()


## 部屋の一覧を出す。1部屋が1つのボタンで、押すと入る（施錠の印の部屋は、パスワードを聞く）。満員の部屋は、押せない。
## レース中の部屋にも入れる（入った人は、待機室で次のレースを待つ）。
## 作れる数ぶんの行を、いつも出す（空いている行は、うすく「空き」）。
func _show_rooms() -> void:
	# 行は作り直すので、吹き出しは、いったん消す。
	_hover_popup.visible = false
	_hover_target = null
	for child in _rooms_box.get_children():
		child.free()
	var rooms: Array = OnlineSession.rooms
	_rooms_title.text = "部屋の一覧　%d／%d" % [rooms.size(), OnlineSession.max_rooms]
	_open_create_button.disabled = rooms.size() >= OnlineSession.max_rooms
	for index in maxi(OnlineSession.max_rooms, rooms.size()):
		if index >= rooms.size():
			_rooms_box.add_child(_empty_room_row(index))
			continue
		var entry: Dictionary = rooms[index]
		var button := MenuStyle.button("", 18, MenuStyle.COLOR_BUTTON)
		button.name = "Room%d" % int(entry["room_id"])
		button.custom_minimum_size = Vector2(0.0, ROOM_ROW_HEIGHT)
		button.disabled = int(entry["count"]) >= int(entry["capacity"])
		button.pressed.connect(choose_room.bind(int(entry["room_id"])))
		UIAudio.bind_button_sound(button, "confirmation")
		_rooms_box.add_child(button)
		# カーソル・マウスを乗せると、部屋の紹介文を、吹き出しで出す。
		var description := str(entry.get("description", ""))
		var popup_text := description if not description.is_empty() else "（部屋の紹介は、ありません）"
		button.focus_entered.connect(_show_hover_popup.bind(button, popup_text))
		button.mouse_entered.connect(_show_hover_popup.bind(button, popup_text))
		button.focus_exited.connect(_hide_hover_popup.bind(button))
		button.mouse_exited.connect(_hide_hover_popup.bind(button))
		var columns := _room_columns(str(entry["name"]), str(entry["host_name"]), "%d／%d" % [int(entry["count"]), int(entry["capacity"])], MenuStyle.COLOR_TEXT, 19)
		columns.set_anchors_preset(Control.PRESET_FULL_RECT)
		columns.offset_left = 16.0
		columns.offset_right = -16.0
		button.add_child(columns)
		var state := columns.get_node("State") as HBoxContainer
		var state_text := room_state_text(entry)
		if not state_text.is_empty():
			var state_label := MenuStyle.label(state_text, 15, MenuStyle.COLOR_TAKEN)
			state_label.name = "StateLabel"
			state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			state.add_child(state_label)
		if bool(entry["locked"]):
			var lock := LockMark.new()
			lock.name = "Lock"
			lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			state.add_child(lock)


## 空いている行（まだ作られていない部屋の場所）。
func _empty_room_row(index: int) -> Control:
	var row := PanelContainer.new()
	row.name = "EmptyRoom%d" % (index + 1)
	row.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_ROW_EMPTY, 10, 16.0, 0.0))
	row.custom_minimum_size = Vector2(0.0, ROOM_ROW_HEIGHT)
	var label := MenuStyle.label("空き", 16, Color(MenuStyle.COLOR_DIM, 0.45))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


## 一覧の行の、状態の文（レース中・満員。どちらでもなければ空）。施錠は、文ではなく、印で出す。
static func room_state_text(entry: Dictionary) -> String:
	if bool(entry["racing"]):
		return "レース中"
	if int(entry["count"]) >= int(entry["capacity"]):
		return "満員"
	return ""


# ---------------------------------------------------------------- 待機室

## 待機室：左の5分の3が本体（上段＝部屋の名前・紹介・決まり、中段＝4列×2行の席、下段＝準備OK・部屋を出る・レース開始・説明）、
## 右の5分の2がルームチャット。
func _build_waiting(column: VBoxContainer) -> void:
	_waiting_box = HBoxContainer.new()
	_waiting_box.name = "WaitingRoom"
	_waiting_box.add_theme_constant_override("separation", 16)
	_waiting_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_waiting_box)
	var main := _main_column(_waiting_box, "WaitingMain")
	_waiting_status = _panel_status(main, "WaitingStatus")
	# 上段：部屋の紹介。主には「紹介を変える」「パスワード」（部屋の名前・部屋主・人数は、上の見出しに出す）。
	var top := _card(main, "")
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	top.add_child(head_row)
	var caption := MenuStyle.label("部屋の紹介", 14, MenuStyle.COLOR_DIM)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head_row.add_child(caption)
	_waiting_description = MenuStyle.label("", 16)
	_waiting_description.name = "WaitingDescription"
	_waiting_description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_waiting_description.max_lines_visible = 3
	_waiting_description.custom_minimum_size = Vector2(0.0, WAITING_DESCRIPTION_HEIGHT)
	top.add_child(_waiting_description)
	var info_row := head_row
	for spec: Array in [["紹介を変える", "WaitingDescriptionButton", open_description_dialog], ["パスワード", "WaitingPasswordButton", open_password_change_dialog]]:
		var button := MenuStyle.button(str(spec[0]), 14, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = str(spec[1])
		button.custom_minimum_size = Vector2(0.0, MINI_ARROW_SIZE.y)
		_compact(button, 1.0, 10.0)
		button.pressed.connect(spec[2])
		UIAudio.bind_button_sound(button, "confirmation")
		info_row.add_child(button)
		_waiting_host_buttons.append(button)
	# 中段：4列×2行の席。入った順に埋まる。カーソル・マウスを乗せると、その人の紹介文を小さく出す。
	_seats = _seat_grid(main, "WaitingSeats", "Seat", _on_seat_pressed, true)
	# 席の下：ほかの人が先の画面（レース設定〜レース）に進んでいるときの、今のようす。
	_waiting_race_band = PanelContainer.new()
	_waiting_race_band.name = "WaitingRaceBand"
	_waiting_race_band.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_RACE_BAND, 10, 14.0, 5.0))
	_waiting_race_band.visible = false
	main.add_child(_waiting_race_band)
	_waiting_race_text = MenuStyle.label("", 15)
	_waiting_race_text.name = "WaitingRaceText"
	_waiting_race_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting_race_band.add_child(_waiting_race_text)
	# 下段：準備OK → 部屋を出る → レース開始（主だけ押せる）→ 説明。席との間は、空ける（下段は、板の下に寄せる）。
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(gap)
	# 下のボタンは1行：左から「部屋を出る」「準備OK」「レース設定へ」（先へ進むボタンは右端）。その下に、説明。
	var bottom := VBoxContainer.new()
	bottom.name = "WaitingBottom"
	bottom.add_theme_constant_override("separation", 4)
	main.add_child(bottom)
	var actions := HBoxContainer.new()
	actions.name = "WaitingActions"
	actions.add_theme_constant_override("separation", 8)
	bottom.add_child(actions)
	_waiting_leave_button = _row_button(actions, "部屋を出る", "WaitingLeaveButton", go_back, MenuStyle.COLOR_BUTTON_QUIET, "back", "B")
	_ready_button = _row_button(actions, "準備OK", "ReadyButton", toggle_lobby_ready, MenuStyle.COLOR_BUTTON, "confirmation", "START")
	_race_open_button = _row_button(actions, "レース設定へ", "RaceOpenButton", open_race, MenuStyle.COLOR_BUTTON_ON, "confirmation", "START")
	_waiting_note = MenuStyle.label("部屋主が「レース設定へ」を押すと、準備OKのプレーヤーが次へ進みます。", 14, MenuStyle.COLOR_DIM)
	_waiting_note.name = "WaitingNote"
	_waiting_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_waiting_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_waiting_note)
	# 右：ルームチャット。
	var chat := _room_chat(_waiting_box, "RoomChat")
	_lobby_chat_log = chat[0]
	_lobby_chat_edit = chat[1]
	# 席・部屋の紹介文の吹き出し（席・部屋の行の下に、小さく出す）。
	_hover_popup = PanelContainer.new()
	_hover_popup.name = "HoverPopup"
	_hover_popup.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_DIALOG, 8, 10.0, 6.0))
	_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_popup.top_level = true
	_hover_popup.visible = false
	_hover_popup.z_index = 10
	add_child(_hover_popup)
	_hover_popup_label = MenuStyle.label("", 13)
	_hover_popup_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hover_popup_label.custom_minimum_size = Vector2(WAITING_POPUP_WIDTH, 0.0)
	_hover_popup.add_child(_hover_popup_label)
	# 部屋主がレース開始を押したときの、2秒ほどの知らせ。画面のまん中に出す（後ろの操作は、止めない）。
	_race_open_popup = CenterContainer.new()
	_race_open_popup.name = "RaceOpenPopup"
	_race_open_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_race_open_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_race_open_popup.visible = false
	_race_open_popup.z_index = 20
	add_child(_race_open_popup)
	var popup_panel := PanelContainer.new()
	popup_panel.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_DIALOG, 16, 30.0, 22.0))
	popup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_race_open_popup.add_child(popup_panel)
	_race_open_label = MenuStyle.label("", 22)
	_race_open_label.name = "RaceOpenText"
	_race_open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_open_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_open_label.custom_minimum_size = Vector2(RACE_OPEN_POPUP_WIDTH, 0.0)
	popup_panel.add_child(_race_open_label)


## 左の本体の上に置く、案内の行（上の案内と同じ文を、左のパネルの中に出す）。
func _panel_status(parent: Control, node_name: String) -> Label:
	var label := MenuStyle.label("", 15, MenuStyle.COLOR_FOCUS)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	parent.add_child(label)
	return label


## 下の1行に並べるボタン（横幅は、同じ割合で分ける）。mark は、左に付けるボタンの印（"B"・"START"。空なら付けない）。
func _row_button(parent: HBoxContainer, text: String, node_name: String, action: Callable, color: Color, sound: String, mark: String) -> Button:
	var button := MenuStyle.button(text, 17, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.pressed.connect(action)
	UIAudio.bind_button_sound(button, sound)
	if not mark.is_empty():
		_add_mark_beside_text(button, mark, 20.0)
	parent.add_child(button)
	return button


## ボタンの左に印（"B"・"START" など）を付ける。文字は、印のぶん右へ寄せて、重ならないようにする（左右の余白を、印の幅だけ足す）。
func _add_mark_beside_text(button: Button, mark: String, mark_height: float) -> void:
	var node := MenuStyle.add_mark(button, mark, mark_height)
	var mark_width := node.offset_right
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var box := button.get_theme_stylebox(state)
		if box == null:
			continue
		box = box.duplicate()
		box.content_margin_left = mark_width + 8.0
		box.content_margin_right = 8.0
		button.add_theme_stylebox_override(state, box)


## 左の5分の3の本体の列。
func _main_column(parent: HBoxContainer, node_name: String) -> VBoxContainer:
	var main := VBoxContainer.new()
	main.name = node_name
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 3.0
	main.add_theme_constant_override("separation", 6)
	parent.add_child(main)
	return main


## 右の5分の2の、ルームチャット（濃い透ける背景。上から、見出し・メッセージ・入力欄）。返すのは [記録の欄, 入力らん]。
func _room_chat(parent: HBoxContainer, prefix: String) -> Array:
	# 上の見出し（流れの道しるべ）とくっつかないよう、上にすき間を取る。
	var outer := MarginContainer.new()
	outer.name = prefix + "Outer"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_stretch_ratio = 2.0
	outer.add_theme_constant_override("margin_top", CHAT_PANEL_TOP_MARGIN)
	parent.add_child(outer)
	var panel := PanelContainer.new()
	panel.name = prefix
	panel.custom_minimum_size = Vector2(CHAT_PANEL_MIN_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_CHAT_PANEL, 14, 16.0, 14.0))
	outer.add_child(panel)
	var chat := VBoxContainer.new()
	chat.add_theme_constant_override("separation", 10)
	panel.add_child(chat)
	var head := MenuStyle.label("ルームチャット", 20)
	head.name = prefix + "Title"
	chat.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(1.0, 1.0, 1.0, 0.12)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	chat.add_child(rule)
	var log := RichTextLabel.new()
	log.name = prefix + "Log"
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.scroll_following = true
	log.add_theme_font_size_override("normal_font_size", 15)
	log.add_theme_constant_override("line_separation", 4)
	log.mouse_filter = Control.MOUSE_FILTER_PASS
	chat.add_child(log)
	_chat_logs.append(log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chat.add_child(row)
	var edit := _line_edit(prefix + "Edit", "", OnlineConfig.chat_max_length())
	edit.placeholder_text = "メッセージ（Enterで送る）"
	edit.add_theme_stylebox_override("normal", MenuStyle.box(Color(1.0, 1.0, 1.0, 0.08), 8, 10.0, 4.0))
	edit.text_submitted.connect(func(_text: String) -> void: send_chat(edit))
	row.add_child(edit)
	var send := MenuStyle.button("送る", 16, MenuStyle.COLOR_BUTTON)
	send.name = prefix + "SendButton"
	send.custom_minimum_size = Vector2(72.0, FIELD_HEIGHT)
	_compact(send, 2.0, 8.0)
	send.pressed.connect(func() -> void: send_chat(edit))
	row.add_child(send)
	return [log, edit]


## 4列×2行の席を作る。1席ぶんは {button, icon, portrait, name, mark, kick}。
## with_popup なら、カーソル・マウスを乗せたとき、その人の紹介文を出す。
func _seat_grid(parent: Control, node_name: String, prefix: String, on_pressed: Callable, with_popup: bool) -> Array:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = WAITING_SEAT_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var seats: Array = []
	for seat in Protocol.ROOM_CAPACITY:
		var button := Button.new()
		button.name = "%s%d" % [prefix, seat + 1]
		button.custom_minimum_size = Vector2(0.0, WAITING_SEAT_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyle.style_button(button, 14, COLOR_SEAT)
		button.pressed.connect(on_pressed.bind(seat))
		grid.add_child(button)
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_top = 6.0
		inner.offset_bottom = -4.0
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inner)
		var icon_box := CenterContainer.new()
		icon_box.name = "SeatIconBox"
		icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_box)
		var icon_frame := Control.new()
		icon_frame.custom_minimum_size = Vector2(WAITING_ICON_SIZE, WAITING_ICON_SIZE)
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon_frame)
		var icon: Control = TrainerIcon.new()
		icon.name = "SeatIcon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon)
		var portrait := _portrait_rect("SeatPortrait")
		icon_frame.add_child(portrait)
		var name_label := MenuStyle.label("", 15)
		name_label.name = "SeatName"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_label)
		var mark := Label.new()
		mark.name = "SeatReady"
		mark.text = "準備OK"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 12)
		mark.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
		mark.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_CONFIRMED, 6, 6.0, 1.0))
		mark.set_anchors_preset(Control.PRESET_TOP_LEFT)
		mark.offset_left = 6.0
		mark.offset_top = 6.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = false
		button.add_child(mark)
		# 部屋の主にだけ出る、小さな「︙」。押すと、その人を退出させるかを確かめる窓が出る。
		var kick := Button.new()
		kick.name = "SeatMenu"
		kick.text = "︙"
		kick.flat = true
		kick.focus_mode = Control.FOCUS_NONE
		kick.tooltip_text = "この人について"
		kick.add_theme_font_size_override("font_size", 16)
		kick.add_theme_color_override("font_color", MenuStyle.COLOR_DIM)
		kick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		kick.offset_left = -MEMBER_MENU_WIDTH - 4.0
		kick.offset_right = -4.0
		kick.offset_top = 2.0
		kick.offset_bottom = 28.0
		kick.visible = false
		kick.pressed.connect(_open_seat_kick.bind(seat))
		button.add_child(kick)
		var parts := {"button": button, "icon": icon, "portrait": portrait, "name": name_label, "mark": mark, "kick": kick, "peer": 0}
		seats.append(parts)
		if with_popup:
			button.focus_entered.connect(_show_seat_popup.bind(parts))
			button.mouse_entered.connect(_show_seat_popup.bind(parts))
			button.focus_exited.connect(_hide_hover_popup.bind(button))
			button.mouse_exited.connect(_hide_hover_popup.bind(button))
	return seats


## 1席に、人を出す（絵・名前。自分は青、ほかの人は黄、主には［主］）。
func _show_person_seat(parts: Dictionary, member: Dictionary) -> void:
	var peer := int(member["peer_id"])
	parts["peer"] = peer
	(parts["name"] as Label).text = str(member["name"]) + ("［主］" if peer == int(_room.get("host", 0)) else "")
	(parts["name"] as Label).add_theme_color_override("font_color", PururinSlot.COLOR_USER if peer == OnlineSession.peer_id else COLOR_OTHER_PLAYER)
	(parts["icon"] as Control).get_parent().get_parent().visible = true
	_show_person_image({"kind": "player", "peer_id": peer}, parts["icon"], parts["portrait"])
	MenuStyle.style_button(parts["button"], 14, COLOR_SEAT)


## 1席に、人のいない表示（空き・CPU・入れない）を出す。
func _show_empty_seat(parts: Dictionary, text: String, color: Color, alpha: float) -> void:
	parts["peer"] = 0
	(parts["name"] as Label).text = text
	(parts["name"] as Label).add_theme_color_override("font_color", Color(MenuStyle.COLOR_TEXT, alpha))
	(parts["icon"] as Control).get_parent().get_parent().visible = false
	(parts["mark"] as Control).visible = false
	(parts["kick"] as Control).visible = false
	MenuStyle.style_button(parts["button"], 16, color)


## 待機室を出し直す。
func _show_waiting() -> void:
	var all := OnlineSession.all_members()
	var host_id := int(_room.get("host", 0))
	var description := str(_room.get("description", ""))
	_waiting_description.text = description if not description.is_empty() else "（部屋の紹介は、ありません）"
	_waiting_description.modulate.a = 1.0 if not description.is_empty() else 0.55
	var racing := OnlineSession.phase() != Protocol.PHASE_LOBBY
	var host := is_host()
	for button: Button in _waiting_host_buttons:
		button.visible = host
	for seat in _seats.size():
		var parts: Dictionary = _seats[seat]
		if seat >= all.size():
			_show_empty_seat(parts, "空き", COLOR_SEAT_EMPTY, 0.5)
			continue
		var member: Dictionary = all[seat]
		_show_person_seat(parts, member)
		# 先に進んでいる人の席には「出走中」、待機室で準備OKの人には「準備OK」。
		var mark := parts["mark"] as Label
		var in_race := racing and bool(member.get("racer", false))
		mark.text = "出走中" if in_race else "準備OK"
		mark.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_STEP_NOW if in_race else COLOR_CONFIRMED, 6, 6.0, 1.0))
		mark.visible = in_race or bool(member.get("ready", false))
		(parts["kick"] as Control).visible = host and int(member["peer_id"]) != OnlineSession.peer_id
	_waiting_race_band.visible = racing
	if racing:
		var names: Array[String] = []
		for member: Dictionary in all:
			if bool(member.get("racer", false)):
				names.append(str(member["name"]))
		var doing := "走っています" if bool(_room.get("racing", false)) else "「%s」に進んでいます" % str(PHASE_NAMES.get(OnlineSession.phase(), ""))
		_waiting_race_text.text = "現在レース中：%s（%d人）が%s。\nレースが終わると、全員この待機室に戻ります。" % ["、".join(names), names.size(), doing]
	var ready := OnlineSession.my_lobby_ready()
	_ready_button.text = "取り消す" if ready else "準備OK"
	var ready_box := MenuStyle.box(MenuStyle.COLOR_BUTTON_QUIET if ready else MenuStyle.COLOR_BUTTON, 10, 8.0, 10.0)
	ready_box.content_margin_left = (_ready_button.get_node("ButtonMark") as Control).offset_right + 8.0
	_ready_button.add_theme_stylebox_override("normal", ready_box)
	_ready_button.get_node("ButtonMark").visible = not ready and not host
	# レース開始は、主だけが押せる（ほかの人には、押せない形で見せる）。レースの最中は、だれも押せない。
	_race_open_button.disabled = not host or racing
	_race_open_button.get_node("ButtonMark").visible = host and not racing
	_race_open_button.modulate.a = 1.0 if not _race_open_button.disabled else 0.45
	# 主は、準備OKを押さなくても、必ずレースに出る。
	_ready_button.disabled = host
	_ready_button.modulate.a = 1.0 if not host else 0.45
	_link_waiting_focus()


## 待機室の上下左右の行き先：席（4列×2行）→ 準備OK → 部屋を出る → レース開始。右のチャットへは、右で移る。
func _link_waiting_focus() -> void:
	var actions: Array[Control] = []
	for button: Button in [_waiting_leave_button, _ready_button, _race_open_button]:
		if not button.disabled:
			actions.append(button)
	var first_action: Control = actions.back() if not actions.is_empty() else _waiting_leave_button
	# 部屋主だけの「紹介を変える」「パスワード」：上の段の席から、上で行ける。
	var host_buttons: Array[Control] = []
	for button: Button in _waiting_host_buttons:
		if button.visible and not button.disabled:
			host_buttons.append(button)
	_link_seat_grid(_seats, _lobby_chat_edit, host_buttons.front() if not host_buttons.is_empty() else null, first_action)
	for index in host_buttons.size():
		var button := host_buttons[index]
		var below: Control = _seats[mini(index * (WAITING_SEAT_COLUMNS - 1), WAITING_SEAT_COLUMNS - 1)]["button"]
		_link(button, host_buttons[maxi(index - 1, 0)], host_buttons[index + 1] if index < host_buttons.size() - 1 else _lobby_chat_edit, button, below)
	var above: Control = _seats[Protocol.ROOM_CAPACITY - WAITING_SEAT_COLUMNS]["button"]
	for index in actions.size():
		var button := actions[index]
		_link(button, actions[maxi(index - 1, 0)], actions[index + 1] if index < actions.size() - 1 else _lobby_chat_edit, above, button)
	_link_chat(_lobby_chat_edit, _seats[WAITING_SEAT_COLUMNS - 1]["button"])


## 4列×2行の席の行き先。右端の席の右は、チャット。上の段の上は above（無ければ、その席）、下の段の下は below。
func _link_seat_grid(seats: Array, chat_edit: Control, above: Control, below: Control) -> void:
	var buttons: Array[Control] = []
	for parts: Dictionary in seats:
		buttons.append(parts["button"])
	for seat in buttons.size():
		var column_index := seat % WAITING_SEAT_COLUMNS
		var left: Control = buttons[seat - 1] if column_index > 0 else buttons[seat]
		var right: Control = buttons[seat + 1] if column_index < WAITING_SEAT_COLUMNS - 1 else chat_edit
		var up: Control = buttons[seat - WAITING_SEAT_COLUMNS] if seat >= WAITING_SEAT_COLUMNS else (above if above != null else buttons[seat])
		var down: Control = buttons[seat + WAITING_SEAT_COLUMNS] if seat + WAITING_SEAT_COLUMNS < buttons.size() else below
		_link(buttons[seat], left, right, up, down)


## チャットの入力らんと「送る」の行き先。左は、本体へ戻る。
func _link_chat(edit: LineEdit, back_to: Control) -> void:
	var send: Control = edit.get_parent().get_node(NodePath(str(edit.name).replace("Edit", "SendButton")))
	_link(edit, back_to, send, edit, edit)
	_link(send, edit, send, send, send)


## 席にカーソル・マウスが来た：その人の紹介文を、席の下に小さく出す。空き席では出さない。
func _show_seat_popup(parts: Dictionary) -> void:
	var peer := int(parts["peer"])
	if peer == 0:
		_hover_popup.visible = false
		return
	var introduction := ""
	for member: Dictionary in OnlineSession.all_members():
		if int(member["peer_id"]) == peer:
			introduction = str(member.get("introduction", ""))
	_show_hover_popup(parts["button"], introduction if not introduction.is_empty() else "（紹介文は、ありません）")


## 部品の下に、小さな吹き出しを出す（下に入らなければ、上に出す）。
## 作り直した直後の行は、まだ位置が決まっていないので、1コマ待ってから置く。
func _show_hover_popup(target: Control, text: String) -> void:
	_hover_target = target
	await get_tree().process_frame
	if _hover_target != target or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	_hover_popup_label.text = text
	_hover_popup.size = Vector2.ZERO
	_hover_popup.reset_size()
	var rect := target.get_global_rect()
	var popup_size := _hover_popup.get_combined_minimum_size()
	var x := clampf(rect.position.x + (rect.size.x - popup_size.x) * 0.5, 8.0, get_viewport_rect().size.x - popup_size.x - 8.0)
	var y := rect.end.y + 4.0
	if y + popup_size.y > get_viewport_rect().size.y - 8.0:
		y = rect.position.y - popup_size.y - 4.0
	_hover_popup.position = Vector2(x, y)
	_hover_popup.visible = true
	_hover_target = target


## カーソルもマウスも離れたら、吹き出しを消す。
func _hide_hover_popup(target: Control) -> void:
	if _hover_target != target:
		return
	if target.has_focus() or (target is BaseButton and (target as BaseButton).is_hovered()):
		return
	_hover_popup.visible = false
	_hover_target = null


## 席を押した：その人の紹介の窓を出す（空き席では、何もしない）。
func _on_seat_pressed(seat: int) -> void:
	var peer := int(_seats[seat]["peer"])
	if peer == 0:
		return
	_show_person({"kind": "player", "peer_id": peer, "name": member_name(peer)})
	open_profile_dialog()


## 席の「︙」：その人を退出させるかを確かめる（部屋の主だけ）。
func _open_seat_kick(seat: int) -> void:
	var target := int(_seats[seat]["peer"])
	if target == 0 or target == OnlineSession.peer_id or not is_host():
		return
	close_dialogs()
	_kick_target = target
	_kick_dialog_title.text = "%s さんを退出させますか" % member_name(target)
	_kick_dialog.visible = true
	(_kick_dialog.find_child("KickConfirmCancelButton", true, false) as Button).grab_focus()


## 待機室の「準備OK」を押す・取り消す。
func toggle_lobby_ready() -> void:
	if is_host():
		return
	_client.set_lobby_ready(not OnlineSession.my_lobby_ready())


## 待機室の「レース設定へ」（部屋の主だけ）。準備OKの人と主が、レース設定へ進む。
func open_race() -> void:
	if not is_host():
		return
	_client.send(Protocol.RACE_OPEN)


## 部屋主がレース開始を押したことを、2秒ほど出す。レースに出る人と、待機室に残る人で、文を分ける。
func show_race_open_popup() -> void:
	_race_open_label.text = RACE_OPEN_TEXT if OnlineSession.am_racer() else RACE_OPEN_STAY_TEXT
	_race_open_popup.visible = true
	_race_open_until_msec = Time.get_ticks_msec() + RACE_OPEN_POPUP_MSEC


func is_race_open_popup_visible() -> bool:
	return _race_open_popup.visible


# ---------------------------------------------------------------- レース設定

## レース設定：部屋主が、距離と、人の足りない席にCPUを入れるかを決める。レースに出る人だけが見る。
## 左の5分の3が本体（距離・4列×2行の席・下のボタン）、右の5分の2がルームチャット（待機室と同じ）。
func _build_race_settings(column: VBoxContainer) -> void:
	_settings_box = HBoxContainer.new()
	_settings_box.name = "RaceSettings"
	_settings_box.add_theme_constant_override("separation", 16)
	_settings_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_settings_box)
	var main := _main_column(_settings_box, "RaceSettingsMain")
	_settings_status = _panel_status(main, "SettingsStatus")
	_settings_note = MenuStyle.label("", 15, MenuStyle.COLOR_DIM)
	_settings_note.name = "RaceSettingsNote"
	_settings_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	main.add_child(_settings_note)
	main.add_child(_build_distance_row())
	main.add_child(MenuStyle.label("出走する席", 16, MenuStyle.COLOR_DIM))
	_settings_seats = _seat_grid(main, "SettingsSeats", "SettingsSeat", toggle_seat, true)
	_settings_count = MenuStyle.label("", 16)
	_settings_count.name = "RaceSettingsCount"
	main.add_child(_settings_count)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(filler)
	# 下のボタンは1行：左から「部屋を出る」「待機室へ戻る」「次へ」（先へ進むボタンは右端）。
	var actions := HBoxContainer.new()
	actions.name = "RaceSettingsActions"
	actions.add_theme_constant_override("separation", 8)
	main.add_child(actions)
	_settings_leave_button = _row_button(actions, "部屋を出る", "SettingsLeaveButton", go_back, MenuStyle.COLOR_BUTTON_QUIET, "back", "B")
	_settings_back_button = _row_button(actions, "待機室へ戻る", "SettingsBackButton", back_to_room_phase, MenuStyle.COLOR_BUTTON_QUIET, "back", "")
	_settings_next_button = _row_button(actions, "次へ（プル選択）", "SettingsNextButton", open_pick, MenuStyle.COLOR_BUTTON_ON, "confirmation", "START")
	_settings_next_button.text = "次へ"
	var chat := _room_chat(_settings_box, "SettingsChat")
	_settings_chat_edit = chat[1]


## レース設定を出し直す。人の席は、待機室と同じ絵と名前。人の足りない席は「CPU」か「入れない」。主は、押して切り替えられる。
## 主でない人にも「待機室へ戻る」（自分だけ、待機室へ戻る）と「次へ」（押せない）を見せる。
func _show_settings() -> void:
	var host := is_host()
	_settings_note.text = "人の足りない席は、押すと「CPU」と「入れない」が切り替わります。" if host else ""
	_settings_note.visible = host
	_show_distance_buttons(host)
	var racers := OnlineSession.members()
	var seats: Array = _room.get("seats", [])
	for seat in _settings_seats.size():
		var parts: Dictionary = _settings_seats[seat]
		var button: Button = parts["button"]
		if seat < racers.size():
			_show_person_seat(parts, racers[seat])
			(parts["mark"] as Control).visible = false
			(parts["kick"] as Control).visible = false
			button.focus_mode = Control.FOCUS_ALL
			continue
		var cpu_index := seat - racers.size()
		var with_cpu: bool = bool(seats[cpu_index]) if cpu_index < seats.size() else false
		_show_empty_seat(parts, "CPU" if with_cpu else "入れない", MenuStyle.COLOR_BUTTON if with_cpu else COLOR_SEAT_EMPTY, 1.0 if with_cpu else 0.5)
		# 主だけ、押して切り替えられる。ほかの人は、カーソルも置けない。
		button.focus_mode = Control.FOCUS_ALL if host and cpu_index < seats.size() else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if host else Control.MOUSE_FILTER_IGNORE
	_settings_count.text = "出走　%d体（人 %d・CPU %d）" % [int(_room.get("field_size", 0)), racers.size(), seats.count(true)]
	_settings_next_button.disabled = not host
	_settings_next_button.get_node("ButtonMark").visible = host
	_settings_next_button.modulate.a = 1.0 if host else 0.45
	_link_settings_focus()


## レース設定の上下左右の行き先：距離 → 席（4列×2行）→ 下のボタン。右端の席の右は、チャット。
func _link_settings_focus() -> void:
	var distance_button: Control = _focused_distance_button()
	var first_seat: Control = _settings_seats[0]["button"]
	var distances: Array = _distance_buttons.keys()
	for index in distances.size():
		var button: Button = _distance_buttons[distances[index]]
		_link(button, _distance_buttons[distances[maxi(index - 1, 0)]], _distance_buttons[distances[mini(index + 1, distances.size() - 1)]], button, first_seat)
	_link_seat_grid(_settings_seats, _settings_chat_edit, distance_button, _settings_leave_button)
	var above: Control = _settings_seats[Protocol.ROOM_CAPACITY - WAITING_SEAT_COLUMNS]["button"]
	var next_usable := not _settings_next_button.disabled
	_link(_settings_leave_button, _settings_leave_button, _settings_back_button, above, _settings_leave_button)
	_link(_settings_back_button, _settings_leave_button, _settings_next_button if next_usable else _settings_chat_edit, above, _settings_back_button)
	_link(_settings_next_button, _settings_back_button, _settings_chat_edit, above, _settings_next_button)
	_link_chat(_settings_chat_edit, _settings_seats[WAITING_SEAT_COLUMNS - 1]["button"])


## 人の足りない席の、CPUを入れる・入れないを切り替える（部屋の主だけ）。人の席は、押すと、その人の紹介。
func toggle_seat(seat: int) -> void:
	var cpu_index := seat - OnlineSession.members().size()
	if cpu_index < 0:
		var peer := int(_settings_seats[seat]["peer"])
		if peer != 0:
			_show_person({"kind": "player", "peer_id": peer, "name": member_name(peer)})
			open_profile_dialog()
		return
	var seats: Array = (_room.get("seats", []) as Array).duplicate()
	if not is_host() or cpu_index >= seats.size():
		return
	seats[cpu_index] = not bool(seats[cpu_index])
	_client.send(Protocol.SETTINGS, {"seats": seats})


## レース設定の「次へ」：ぷるりんを選ぶ所へ進む（部屋の主だけ）。
func open_pick() -> void:
	if is_host():
		_client.send(Protocol.PICK_OPEN)


## 距離のボタンを、決まっている距離に合わせる。変えられる人だけ、カーソルを置ける。
func _show_distance_buttons(can_change: bool) -> void:
	var distance := float(_room.get("distance_m", 0.0))
	for distance_m: float in _distance_buttons:
		var button: Button = _distance_buttons[distance_m]
		button.set_pressed_no_signal(is_equal_approx(distance_m, distance))
		# 押せない人でも、決まっている距離は、色を付けて、はっきり見せる。ほかは、うすくする。
		button.disabled = not can_change
		button.focus_mode = Control.FOCUS_ALL if not button.disabled else Control.FOCUS_NONE
		button.add_theme_stylebox_override("disabled", MenuStyle.box(MenuStyle.COLOR_BUTTON_ON if button.button_pressed else MenuStyle.COLOR_BUTTON_QUIET, 10, 6.0, 4.0))
		button.add_theme_color_override("font_disabled_color", MenuStyle.COLOR_TEXT)
		button.modulate.a = 1.0 if not button.disabled or button.button_pressed else 0.4
	for step_button: Button in _distance_step_buttons:
		step_button.disabled = not can_change
		step_button.modulate.a = 1.0 if not step_button.disabled else 0.3


## 決まっている距離のボタン（カーソルを置けるときだけ。置けなければ null）。
func _focused_distance_button() -> Control:
	for distance_m: float in _distance_buttons:
		var button: Button = _distance_buttons[distance_m]
		if button.button_pressed and button.focus_mode != Control.FOCUS_NONE:
			return button
	return null


# ---------------------------------------------------------------- プル選択

## プル選択：左の5分の3が本体（案内・距離と出走数・横長の席 1列×8行・下のボタン）、右の5分の2がルームチャット。
## 自分の席は大きく目立たせて、押すと、プルのステータスの窓（変更・もどる）が出る。プルは、ほかの人やCPUと重なってもよい。
func _build_pick(column: VBoxContainer) -> void:
	_pick_box = HBoxContainer.new()
	_pick_box.name = "PickScreen"
	_pick_box.add_theme_constant_override("separation", 16)
	_pick_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_pick_box)
	var main := _main_column(_pick_box, "PickMain")
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	main.add_child(head_row)
	_pick_info = MenuStyle.label("", 15, MenuStyle.COLOR_DIM)
	_pick_info.name = "PickInfo"
	_pick_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head_row.add_child(_pick_info)
	_pick_status = _panel_status(main, "PickStatus")
	var rows := VBoxContainer.new()
	rows.name = "PickRows"
	rows.add_theme_constant_override("separation", 4)
	main.add_child(rows)
	for index in Protocol.ROOM_CAPACITY:
		_pick_rows.append(_pick_row(rows, index))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(filler)
	var actions := HBoxContainer.new()
	actions.name = "PickActions"
	actions.add_theme_constant_override("separation", 8)
	main.add_child(actions)
	_pick_back_button = _row_button(actions, "待機室へ戻る", "PickBackButton", back_to_room_phase, MenuStyle.COLOR_BUTTON_QUIET, "back", "B")
	# 部屋主のときは「待機室へ戻る（全員）」と長いので、ほかより少し広く取る（B の印と並べても切れないように）。
	_pick_back_button.size_flags_stretch_ratio = 1.3
	_pick_confirm_button = _row_button(actions, "確定", "PickConfirmButton", toggle_pick_confirm, MenuStyle.COLOR_BUTTON, "confirmation", "")
	_pick_paddock_button = _row_button(actions, "パドックへ", "PickPaddockButton", open_paddock, MenuStyle.COLOR_BUTTON_ON, "confirmation", "START")
	var chat := _room_chat(_pick_box, "PickChat")
	_pick_chat_edit = chat[1]
	# プルを選ぶ窓（オフラインのレース選択と同じもの）。
	_picker = PururinPicker.new()
	_picker.name = "Picker"
	add_child(_picker)
	_picker.connect("picked", _on_picker_picked)
	_picker.connect("closed", _on_picker_closed)
	# プルのステータスの窓（変更・もどる）。
	var parts := _dialog("PickDialog", "")
	_pick_dialog = parts[0]
	var dialog_column: VBoxContainer = parts[1]
	_pick_dialog_title = dialog_column.get_node("Title")
	_pick_dialog_detail = PururinDetail.new()
	_pick_dialog_detail.name = "PickDetail"
	_pick_dialog_detail.custom_minimum_size = Vector2(0.0, DETAIL_DIALOG_HEIGHT)
	(dialog_column.get_parent() as Control).custom_minimum_size = Vector2(PICK_DIALOG_WIDTH, 0.0)
	dialog_column.add_child(_pick_dialog_detail)
	# CPUの「おまかせ」の席では、詳細の代わりに、この文だけを出す（「キャラを選択してください」は出さない）。
	_pick_dialog_empty = MenuStyle.label("おまかせ\nパドックへ進むときに、空いているプルが入ります", 19)
	_pick_dialog_empty.name = "PickDialogEmpty"
	_pick_dialog_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_dialog_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pick_dialog_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pick_dialog_empty.custom_minimum_size = Vector2(0.0, DETAIL_DIALOG_HEIGHT)
	dialog_column.add_child(_pick_dialog_empty)
	var dialog_row := HBoxContainer.new()
	dialog_row.add_theme_constant_override("separation", 12)
	dialog_column.add_child(dialog_row)
	_pick_change_button = MenuStyle.button("変更", 20, MenuStyle.COLOR_BUTTON_ON)
	_pick_change_button.name = "PickChangeButton"
	_pick_change_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_pick_change_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_change_button.pressed.connect(_on_pick_change_pressed)
	UIAudio.bind_button_sound(_pick_change_button, "confirmation")
	dialog_row.add_child(_pick_change_button)
	var dialog_back := MenuStyle.button("もどる", 20, MenuStyle.COLOR_BUTTON_QUIET)
	dialog_back.name = "PickDialogBackButton"
	dialog_back.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	dialog_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_back.pressed.connect(_on_pick_dialog_back)
	UIAudio.bind_button_sound(dialog_back, "back")
	dialog_row.add_child(dialog_back)


## 横長の席を1つ作る。1席ぶんは {button, frame, icon, portrait, who, pururin, mark, note, kind（"self"・"player"・"cpu"・""）, peer, cpu_index, pururin_id}。
func _pick_row(parent: VBoxContainer, index: int) -> Dictionary:
	# 自分の席だけ、上下に余白を取る（余白の大きさは、出し直すときに決める）。
	var margin := MarginContainer.new()
	margin.name = "PickRowMargin%d" % (index + 1)
	parent.add_child(margin)
	var button := Button.new()
	button.name = "PickRow%d" % (index + 1)
	button.custom_minimum_size = Vector2(0.0, PICK_ROW_HEIGHT)
	MenuStyle.style_button(button, 14, COLOR_SEAT)
	button.pressed.connect(open_pick_dialog.bind(index))
	margin.add_child(button)
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 10.0
	line.offset_right = -10.0
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var frame := Control.new()
	frame.name = "PickIconFrame"
	frame.custom_minimum_size = Vector2(PICK_ICON_SIZE, PICK_ICON_SIZE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(frame)
	var icon: Control = TrainerIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var portrait := _portrait_rect("PickPortrait")
	frame.add_child(portrait)
	var who := MenuStyle.label("", 15)
	who.name = "PickWho"
	who.custom_minimum_size = Vector2(PICK_WHO_WIDTH, 0.0)
	who.clip_text = true
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(who)
	# 選んでいるプルの絵（おまかせ・未選択では出さない）。
	var portrait_frame := Control.new()
	portrait_frame.name = "PickPururinFrame"
	portrait_frame.custom_minimum_size = Vector2(PICK_ICON_SIZE, PICK_ICON_SIZE)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(portrait_frame)
	var pururin_portrait: Control = PururinPortrait.new()
	pururin_portrait.name = "PickPururinPortrait"
	pururin_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	pururin_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(pururin_portrait)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(texts)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_row)
	var pururin := MenuStyle.label("", 17)
	pururin.name = "PickPururin"
	pururin.custom_minimum_size = Vector2(PICK_PURURIN_NAME_WIDTH, 0.0)
	pururin.clip_text = true
	pururin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(pururin)
	# 脚質：オフラインのレース選択・詳細と同じ、矢印の印。となりに名前。
	var style_mark := Control.new()
	style_mark.name = "PickStyleMark"
	style_mark.custom_minimum_size = Vector2(RaceHud.STYLE_CHEVRON_STEP * PICK_CHEVRON_SCALE * PururinStatsMath.rank_group_count() + 4.0, 0.0)
	style_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(style_mark)
	var style := MenuStyle.label("", 14, MenuStyle.COLOR_DIM)
	style.name = "PickStyle"
	style.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(style)
	var note := MenuStyle.label("押すと、プルを変更できます", 13, MenuStyle.COLOR_FOCUS)
	note.name = "PickNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(note)
	var mark := Label.new()
	mark.name = "PickConfirmed"
	mark.text = "確定"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_font_size_override("font_size", 13)
	mark.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
	mark.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_CONFIRMED, 6, 6.0, 1.0))
	mark.custom_minimum_size = Vector2(CONFIRM_BADGE_WIDTH, 0.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(mark)
	style_mark.draw.connect(func() -> void:
		var style_id := str(style_mark.get_meta("style_id", ""))
		if style_id.is_empty():
			return
		RaceHud.draw_style_chevrons(style_mark, Vector2(2.0, style_mark.size.y * 0.5), RaceHud.COLOR_STYLE_MATCH, PururinStatsMath.rank_group_count(), PururinStatsMath.style_rank_group_index(style_id), PICK_CHEVRON_SCALE))
	return {"margin": margin, "button": button, "frame": frame, "icon": icon, "portrait": portrait, "who": who, "pururin_frame": portrait_frame, "pururin_portrait": pururin_portrait, "pururin": pururin, "style": style, "style_mark": style_mark, "mark": mark, "note": note, "kind": "", "peer": 0, "cpu_index": -1, "pururin_id": ""}


## プル選択を出し直す。並びは、レースに出る人（レース開始のときの並び）、そのあとCPUの席。
func _show_pick() -> void:
	var host := is_host()
	var racers := OnlineSession.members()
	var cpus: Array = _room.get("cpus", [])
	_pick_info.text = "距離 %dm　出走 %d体" % [int(_room.get("distance_m", 0.0)), int(_room.get("field_size", 0))]
	var mine := my_pururin_id()
	# 入ったばかりのときは、サーバーが一覧の1番目のプルを入れてある。前に使ったプルがあれば、それに替える（1回だけ）。
	if OnlineSession.am_racer() and not _auto_pick_sent:
		_auto_pick_sent = true
		if not OnlineSession.last_pick.is_empty() and OnlineSession.last_pick != mine:
			_client.send(Protocol.PICK, {"pururin_id": OnlineSession.last_pick})
	elif not mine.is_empty():
		OnlineSession.last_pick = mine
	for index in _pick_rows.size():
		var row: Dictionary = _pick_rows[index]
		var button: Button = row["button"]
		var mine_row := false
		row["visible"] = true
		if index < racers.size():
			var member: Dictionary = racers[index]
			var peer := int(member["peer_id"])
			mine_row = peer == OnlineSession.peer_id
			row["kind"] = "self" if mine_row else "player"
			row["peer"] = peer
			row["cpu_index"] = -1
			row["pururin_id"] = str(member["pururin_id"])
			(row["who"] as Label).text = str(member["name"]) + ("［主］" if peer == int(_room.get("host", 0)) else "")
			(row["who"] as Label).add_theme_color_override("font_color", PururinSlot.COLOR_USER if mine_row else COLOR_OTHER_PLAYER)
			_show_person_image({"kind": "player", "peer_id": peer}, row["icon"], row["portrait"])
			(row["mark"] as Control).modulate.a = 1.0 if bool(member.get("confirmed", false)) else 0.0
		elif index - racers.size() < cpus.size():
			var cpu_index := index - racers.size()
			var cpu_pururin := PururinRosterConfig.pururin_by_id(str(cpus[cpu_index]["pururin_id"]))
			row["kind"] = "cpu"
			row["peer"] = 0
			row["cpu_index"] = cpu_index
			row["pururin_id"] = str(cpus[cpu_index]["pururin_id"])
			var trainer := CpuTrainers.by_id(str(cpu_pururin.get("trainer_id", "")))
			(row["who"] as Label).text = "CPU" if cpu_pururin.is_empty() else "CPU %s" % str(trainer.get("name", ""))
			(row["who"] as Label).add_theme_color_override("font_color", MenuStyle.COLOR_DIM)
			_show_person_image({"peer_id": 0, "trainer_id": str(cpu_pururin.get("trainer_id", ""))}, row["icon"], row["portrait"])
			(row["mark"] as Control).modulate.a = 0.0
		else:
			row["kind"] = ""
			row["visible"] = false
		(row["margin"] as Control).visible = bool(row["visible"])
		var pururin_id := str(row["pururin_id"])
		var pururin := PururinRosterConfig.pururin_by_id(pururin_id)
		(row["pururin"] as Label).text = pururin_name(pururin_id) if not pururin_id.is_empty() else ("おまかせ" if str(row["kind"]) == "cpu" else "ー未選択ー")
		var style_id := str(pururin.get("running_style", ""))
		(row["style"] as Label).text = str(STYLE_NAMES.get(style_id, ""))
		(row["style_mark"] as Control).set_meta("style_id", style_id)
		(row["style_mark"] as Control).visible = not pururin.is_empty()
		(row["style_mark"] as Control).queue_redraw()
		(row["pururin_frame"] as Control).visible = not pururin.is_empty()
		(row["pururin_frame"] as Control).custom_minimum_size = Vector2.ONE * (PICK_ICON_SIZE_MINE if mine_row else PICK_ICON_SIZE)
		if not pururin.is_empty() and str((row["pururin_portrait"] as Control).get("_pururin").get("id", "")) != pururin_id:
			(row["pururin_portrait"] as Control).call("set_pururin", pururin)
		# 自分の席：背が高く、目立つ色で、上下に余白。中に「押すと、プルを変更できます」。
		(row["note"] as Control).visible = mine_row
		(row["frame"] as Control).custom_minimum_size = Vector2.ONE * (PICK_ICON_SIZE_MINE if mine_row else PICK_ICON_SIZE)
		button.custom_minimum_size = Vector2(0.0, PICK_ROW_HEIGHT_MINE if mine_row else PICK_ROW_HEIGHT)
		MenuStyle.style_button(button, 14, COLOR_PICK_MINE if mine_row else COLOR_SEAT)
		for side: String in ["margin_top", "margin_bottom"]:
			(row["margin"] as MarginContainer).add_theme_constant_override(side, int(PICK_MINE_MARGIN) if mine_row else 0)
	var confirmed := is_confirmed(OnlineSession.peer_id)
	_pick_confirm_button.text = "確定を取り消す" if confirmed else "確定"
	_pick_confirm_button.disabled = mine.is_empty()
	_pick_confirm_button.add_theme_stylebox_override("normal", MenuStyle.box(MenuStyle.COLOR_BUTTON_QUIET if confirmed else MenuStyle.COLOR_BUTTON, 10, 22.0, 10.0))
	_pick_back_button.text = "待機室へ戻る（全員）" if host else "待機室へ戻る"
	# パドックへは、部屋主だけ。全員が確定してから押せる。
	_pick_paddock_button.disabled = not host or not everyone_confirmed()
	_pick_paddock_button.modulate.a = 1.0 if not _pick_paddock_button.disabled else 0.45
	_link_pick_focus()


## プル選択の上下左右の行き先：席（上から下）→ 下のボタン。右は、チャット。
func _link_pick_focus() -> void:
	var buttons: Array[Control] = []
	for row: Dictionary in _pick_rows:
		if bool(row.get("visible", false)):
			buttons.append(row["button"])
	var actions: Array[Control] = []
	for button: Button in [_pick_back_button, _pick_confirm_button, _pick_paddock_button]:
		if not button.disabled:
			actions.append(button)
	var first_action: Control = actions[0] if not actions.is_empty() else _pick_back_button
	for index in buttons.size():
		_link(buttons[index], buttons[index], _pick_chat_edit, buttons[maxi(index - 1, 0)], buttons[index + 1] if index < buttons.size() - 1 else first_action)
	var last_row: Control = buttons.back() if not buttons.is_empty() else first_action
	for index in actions.size():
		_link(actions[index], actions[maxi(index - 1, 0)], actions[index + 1] if index < actions.size() - 1 else _pick_chat_edit, last_row, actions[index])
	_link_chat(_pick_chat_edit, buttons[0] if not buttons.is_empty() else first_action)


## 席を押した：そのプルのステータスの窓を出す。自分の席、部屋主のCPUの席では「変更」も出す。
func open_pick_dialog(index: int) -> void:
	var row: Dictionary = _pick_rows[index]
	var kind := str(row["kind"])
	if kind.is_empty():
		return
	close_dialogs()
	var can_change := kind == "self" or (kind == "cpu" and is_host())
	_pick_candidate = ""
	_pick_change_button.text = "変更"
	_pick_target = {"kind": kind, "cpu_index": int(row["cpu_index"]), "row": index, "pururin_id": str(row["pururin_id"])}
	_pick_dialog_title.text = str((row["who"] as Label).text)
	var pururin_id := str(row["pururin_id"])
	_pick_dialog_detail.visible = not pururin_id.is_empty()
	_pick_dialog_empty.visible = pururin_id.is_empty()
	if not pururin_id.is_empty():
		_pick_dialog_detail.call("show_pururin", pururin_id, "", false, false)
	_pick_change_button.visible = can_change
	_pick_dialog.visible = true
	(_pick_change_button if can_change else _pick_dialog.find_child("PickDialogBackButton", true, false) as Button).grab_focus()


## ステータスの窓の「変更」：プル選択の窓を出す（ほかと重なってもよいので、選べないプルは無い）。
func open_pick_picker() -> void:
	var target := _pick_target.duplicate()
	close_dialogs()
	_pick_target = target
	var area := _pick_box.get_global_rect()
	_picker.global_position = area.position + Vector2(0.0, PICKER_MARGIN)
	_picker.size = Vector2(minf(float(PururinPicker.window_width()), area.size.x), area.size.y - PICKER_MARGIN * 2.0)
	_picker.call("open_choices", "CPUのプルを選ぶ" if str(target.get("kind", "")) == "cpu" else "プルを選ぶ", str(target.get("pururin_id", "")), {})


## プル選択の窓でプルを押した：そのプルのステータスを見せて、「このプルにする」か「もどる」（窓へ戻る）を選んでもらう。
func _open_pick_candidate(pururin_id: String) -> void:
	var target := _pick_target.duplicate()
	close_dialogs()
	_pick_target = target
	_pick_candidate = pururin_id
	_pick_dialog_title.text = "このプルにしますか"
	_pick_dialog_detail.visible = true
	_pick_dialog_empty.visible = false
	_pick_dialog_detail.call("show_pururin", pururin_id, "", false, false)
	_pick_change_button.text = "このプルにする"
	_pick_change_button.visible = true
	_pick_dialog.visible = true
	_pick_change_button.grab_focus()


## ステータスの窓の左のボタン：見ているだけなら「変更」（プル選択の窓へ）、選びかけなら「このプルにする」（決める）。
func _on_pick_change_pressed() -> void:
	if _pick_candidate.is_empty():
		open_pick_picker()
		return
	var pururin_id := _pick_candidate
	_pick_candidate = ""
	_pick_dialog.visible = false
	_send_pick_target(pururin_id)


## ステータスの窓の「もどる」：選びかけなら、プル選択の窓へ戻る（そのプルにカーソル）。見ているだけなら、窓を閉じる。
func _on_pick_dialog_back() -> void:
	if _pick_candidate.is_empty():
		close_dialogs()
		return
	_pick_target["pururin_id"] = _pick_candidate
	_pick_candidate = ""
	open_pick_picker()


## プルを決めた（ステータスの窓の「このプルにする」）。自分なら pick、CPUなら cpu_pick。
func _send_pick_target(pururin_id: String) -> void:
	if str(_pick_target.get("kind", "")) == "cpu":
		_client.send(Protocol.CPU_PICK, {"index": int(_pick_target["cpu_index"]), "pururin_id": pururin_id})
	elif str(_pick_target.get("kind", "")) == "self":
		_client.send(Protocol.PICK, {"pururin_id": pururin_id})
	var row := int(_pick_target.get("row", -1))
	_pick_target = {}
	if row >= 0:
		(_pick_rows[row]["button"] as Button).grab_focus()


## 「確定」を押す・取り消す。
func toggle_pick_confirm() -> void:
	_client.send(Protocol.CONFIRM, {"on": not is_confirmed(OnlineSession.peer_id)})


## 「パドックへ」（部屋主だけ。全員が確定していること）。
func open_paddock() -> void:
	if is_host() and everyone_confirmed():
		_client.send(Protocol.ENTRIES)


# ---------------------------------------------------------------- パドック

## パドック：左の5分の3が本体（案内・距離と出走数・大きな枠 1列×8行・枠順のボタン・下のボタン）、右の5分の2がルームチャット。
## 枠を押すと、その人（CPUはトレーナー）とプルの、両方の詳細を出す。枠順を変えられるのは、部屋主だけ。プルの選び直しは、ここではしない。
func _build_paddock(column: VBoxContainer) -> void:
	_paddock_box = HBoxContainer.new()
	_paddock_box.name = "PaddockScreen"
	_paddock_box.add_theme_constant_override("separation", 16)
	_paddock_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_paddock_box)
	var main := _main_column(_paddock_box, "PaddockMain")
	_paddock_info = MenuStyle.label("", 15, MenuStyle.COLOR_DIM)
	_paddock_info.name = "PaddockInfo"
	main.add_child(_paddock_info)
	_paddock_status = _panel_status(main, "PaddockStatus")
	var rows := VBoxContainer.new()
	rows.name = "PaddockRows"
	rows.add_theme_constant_override("separation", 4)
	main.add_child(rows)
	for index in Protocol.ROOM_CAPACITY:
		_paddock_rows.append(_paddock_row(rows, index))
	# 枠順のボタン（部屋主だけ押せる）：ランダム（X）・上へ（L1）・下へ（R1）。
	var gates := HBoxContainer.new()
	gates.name = "PaddockGateButtons"
	gates.add_theme_constant_override("separation", 8)
	main.add_child(gates)
	_paddock_gate_buttons = [
		_row_button(gates, "ランダム", "PaddockShuffleButton", shuffle_gates, MenuStyle.COLOR_BUTTON_QUIET, "confirmation", "X"),
		_row_button(gates, "上へ", "PaddockUpButton", move_selected_gate.bind(-1), MenuStyle.COLOR_BUTTON_QUIET, "confirmation", "L1"),
		_row_button(gates, "下へ", "PaddockDownButton", move_selected_gate.bind(1), MenuStyle.COLOR_BUTTON_QUIET, "confirmation", "R1"),
	]
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(filler)
	var actions := HBoxContainer.new()
	actions.name = "PaddockActions"
	actions.add_theme_constant_override("separation", 8)
	main.add_child(actions)
	_paddock_back_button = _row_button(actions, "待機室へ戻る", "PaddockBackButton", back_to_waiting, MenuStyle.COLOR_BUTTON_QUIET, "back", "B")
	_paddock_confirm_button = _row_button(actions, "確定", "PaddockConfirmButton", toggle_pick_confirm, MenuStyle.COLOR_BUTTON, "confirmation", "")
	_paddock_start_button = _row_button(actions, "レース開始", "PaddockStartButton", start_race, MenuStyle.COLOR_BUTTON_ON, "confirmation", "START")
	var chat := _room_chat(_paddock_box, "PaddockChat")
	_paddock_chat_edit = chat[1]
	# 枠の詳細の窓：左に、その人（CPUはトレーナー）、右に、プル。
	var parts := _dialog("PaddockDialog", "")
	_paddock_dialog = parts[0]
	var dialog_column: VBoxContainer = parts[1]
	(dialog_column.get_parent() as Control).custom_minimum_size = Vector2(PADDOCK_DIALOG_WIDTH, 0.0)
	_paddock_dialog_title = dialog_column.get_node("Title")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	dialog_column.add_child(body)
	var person := VBoxContainer.new()
	person.custom_minimum_size = Vector2(PADDOCK_PERSON_WIDTH, 0.0)
	person.add_theme_constant_override("separation", 6)
	body.add_child(person)
	var image_box := Control.new()
	image_box.custom_minimum_size = Vector2(PROFILE_ICON_SIZE, PROFILE_ICON_SIZE)
	image_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image_box.clip_contents = true
	person.add_child(image_box)
	_paddock_person_icon = TrainerIcon.new()
	_paddock_person_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_box.add_child(_paddock_person_icon)
	_paddock_person_portrait = _portrait_rect("PaddockPersonPortrait")
	image_box.add_child(_paddock_person_portrait)
	_paddock_person_name = MenuStyle.label("", 22)
	_paddock_person_name.name = "PaddockPersonName"
	_paddock_person_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	person.add_child(_paddock_person_name)
	_paddock_person_note = MenuStyle.label("", 14, MenuStyle.COLOR_FOCUS)
	_paddock_person_note.name = "PaddockPersonNote"
	_paddock_person_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	person.add_child(_paddock_person_note)
	_paddock_person_intro = MenuStyle.label("", 15)
	_paddock_person_intro.name = "PaddockPersonIntro"
	_paddock_person_intro.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	person.add_child(_paddock_person_intro)
	_paddock_dialog_detail = PururinDetail.new()
	_paddock_dialog_detail.name = "PaddockDetail"
	_paddock_dialog_detail.custom_minimum_size = Vector2(0.0, DETAIL_DIALOG_HEIGHT)
	_paddock_dialog_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_paddock_dialog_detail)
	var close := MenuStyle.button("もどる", 20, MenuStyle.COLOR_BUTTON_QUIET)
	close.name = "PaddockDialogBackButton"
	close.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	close.pressed.connect(close_dialogs)
	UIAudio.bind_button_sound(close, "back")
	dialog_column.add_child(close)


## 大きな枠を1つ作る。1枠ぶんは {button, badge, icon, portrait, who, pururin_frame, pururin_portrait, pururin, style_mark, style, mark, entry}。
func _paddock_row(parent: VBoxContainer, index: int) -> Dictionary:
	var button := Button.new()
	button.name = "PaddockRow%d" % (index + 1)
	button.custom_minimum_size = Vector2(0.0, PADDOCK_ROW_HEIGHT)
	MenuStyle.style_button(button, 14, COLOR_SEAT)
	button.pressed.connect(open_paddock_dialog.bind(index))
	button.focus_entered.connect(func() -> void: _selected_gate = index)
	parent.add_child(button)
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8.0
	line.offset_right = -10.0
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var badge: Control = GateBadge.new()
	badge.call("setup", index, PADDOCK_BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(badge)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(PADDOCK_ICON_SIZE, PADDOCK_ICON_SIZE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(frame)
	var icon: Control = TrainerIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var portrait := _portrait_rect("PaddockPortrait")
	frame.add_child(portrait)
	var who := MenuStyle.label("", 16)
	who.name = "PaddockWho"
	who.custom_minimum_size = Vector2(PICK_WHO_WIDTH, 0.0)
	who.clip_text = true
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(who)
	var pururin_frame := Control.new()
	pururin_frame.custom_minimum_size = Vector2(PADDOCK_ICON_SIZE, PADDOCK_ICON_SIZE)
	pururin_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pururin_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pururin_frame)
	var pururin_portrait: Control = PururinPortrait.new()
	pururin_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	pururin_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pururin_frame.add_child(pururin_portrait)
	var pururin := MenuStyle.label("", 18)
	pururin.name = "PaddockPururin"
	pururin.custom_minimum_size = Vector2(PICK_PURURIN_NAME_WIDTH, 0.0)
	pururin.clip_text = true
	pururin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pururin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pururin)
	var style_mark := Control.new()
	style_mark.custom_minimum_size = Vector2(RaceHud.STYLE_CHEVRON_STEP * PICK_CHEVRON_SCALE * PururinStatsMath.rank_group_count() + 4.0, 0.0)
	style_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(style_mark)
	style_mark.draw.connect(func() -> void:
		var style_id := str(style_mark.get_meta("style_id", ""))
		if style_id.is_empty():
			return
		RaceHud.draw_style_chevrons(style_mark, Vector2(2.0, style_mark.size.y * 0.5), RaceHud.COLOR_STYLE_MATCH, PururinStatsMath.rank_group_count(), PururinStatsMath.style_rank_group_index(style_id), PICK_CHEVRON_SCALE))
	var style := MenuStyle.label("", 14, MenuStyle.COLOR_DIM)
	style.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(style)
	var mark := Label.new()
	mark.name = "PaddockConfirmed"
	mark.text = "確定"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_theme_font_size_override("font_size", 13)
	mark.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
	mark.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_CONFIRMED, 6, 6.0, 1.0))
	mark.custom_minimum_size = Vector2(CONFIRM_BADGE_WIDTH, 0.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(mark)
	return {"button": button, "badge": badge, "icon": icon, "portrait": portrait, "who": who, "pururin_frame": pururin_frame, "pururin_portrait": pururin_portrait, "pururin": pururin, "style_mark": style_mark, "style": style, "mark": mark, "entry": {}}


## パドックを出し直す。枠順に、全出走（人とCPU）を並べる。
func _show_paddock() -> void:
	var host := is_host()
	var entries: Array = _room.get("entries", [])
	_paddock_info.text = "距離 %dm　出走 %d体" % [int(_room.get("distance_m", 0.0)), entries.size()]
	for index in _paddock_rows.size():
		var row: Dictionary = _paddock_rows[index]
		var button: Button = row["button"]
		button.visible = index < entries.size()
		if not button.visible:
			continue
		var entry: Dictionary = entries[index]
		row["entry"] = entry
		var peer := int(entry.get("peer_id", 0))
		var mine := peer != 0 and peer == OnlineSession.peer_id
		if peer != 0:
			(row["who"] as Label).text = member_name(peer) + ("［主］" if peer == int(_room.get("host", 0)) else "")
			(row["who"] as Label).add_theme_color_override("font_color", PururinSlot.COLOR_USER if mine else COLOR_OTHER_PLAYER)
		else:
			(row["who"] as Label).text = "CPU %s" % str(entry.get("trainer_name", ""))
			(row["who"] as Label).add_theme_color_override("font_color", MenuStyle.COLOR_DIM)
		_show_person_image({"peer_id": peer, "trainer_id": str(entry.get("trainer_id", ""))}, row["icon"], row["portrait"])
		var pururin := PururinRosterConfig.pururin_by_id(str(entry["id"]))
		(row["pururin"] as Label).text = pururin_name(str(entry["id"]))
		var style_id := str(pururin.get("running_style", ""))
		(row["style"] as Label).text = str(STYLE_NAMES.get(style_id, ""))
		(row["style_mark"] as Control).set_meta("style_id", style_id)
		(row["style_mark"] as Control).queue_redraw()
		if str((row["pururin_portrait"] as Control).get("_pururin").get("id", "")) != str(entry["id"]):
			(row["pururin_portrait"] as Control).call("set_pururin", pururin)
		(row["mark"] as Control).modulate.a = 1.0 if peer != 0 and is_confirmed(peer) else 0.0
		MenuStyle.style_button(button, 14, COLOR_PICK_MINE if mine else COLOR_SEAT)
	# 枠順のボタンは、部屋主だけ。上へ・下へは、選んでいる枠があるときだけ。
	for gate_button: Button in _paddock_gate_buttons:
		gate_button.disabled = not host
		gate_button.modulate.a = 1.0 if host else 0.45
	var confirmed := is_confirmed(OnlineSession.peer_id)
	_paddock_confirm_button.text = "取り消す" if confirmed else "確定"
	_paddock_start_button.disabled = not host or not everyone_confirmed()
	_paddock_start_button.get_node("ButtonMark").visible = not _paddock_start_button.disabled
	_paddock_start_button.modulate.a = 1.0 if not _paddock_start_button.disabled else 0.45
	_link_paddock_focus()


## パドックの上下左右の行き先：枠（上から下）→ 枠順のボタン → 下のボタン。右は、チャット。
func _link_paddock_focus() -> void:
	var rows: Array[Control] = []
	for row: Dictionary in _paddock_rows:
		if (row["button"] as Control).visible:
			rows.append(row["button"])
	var gate_buttons: Array[Control] = []
	for button: Button in _paddock_gate_buttons:
		if not button.disabled:
			gate_buttons.append(button)
	var actions: Array[Control] = []
	for button: Button in [_paddock_back_button, _paddock_confirm_button, _paddock_start_button]:
		if not button.disabled:
			actions.append(button)
	var below_rows: Control = gate_buttons[0] if not gate_buttons.is_empty() else (actions[0] if not actions.is_empty() else _paddock_back_button)
	for index in rows.size():
		_link(rows[index], rows[index], _paddock_chat_edit, rows[maxi(index - 1, 0)], rows[index + 1] if index < rows.size() - 1 else below_rows)
	var last_row: Control = rows.back() if not rows.is_empty() else below_rows
	var first_action: Control = actions[0] if not actions.is_empty() else _paddock_back_button
	for index in gate_buttons.size():
		_link(gate_buttons[index], gate_buttons[maxi(index - 1, 0)], gate_buttons[index + 1] if index < gate_buttons.size() - 1 else _paddock_chat_edit, last_row, first_action)
	var above_actions: Control = gate_buttons[0] if not gate_buttons.is_empty() else last_row
	for index in actions.size():
		_link(actions[index], actions[maxi(index - 1, 0)], actions[index + 1] if index < actions.size() - 1 else _paddock_chat_edit, above_actions, actions[index])
	_link_chat(_paddock_chat_edit, rows[0] if not rows.is_empty() else first_action)


## 枠を押した：その人（CPUはトレーナー）と、プルの、両方の詳細を出す。
func open_paddock_dialog(index: int) -> void:
	var entry: Dictionary = _paddock_rows[index]["entry"]
	if entry.is_empty():
		return
	close_dialogs()
	_selected_gate = index
	var peer := int(entry.get("peer_id", 0))
	_paddock_dialog_title.text = "%d枠" % (index + 1)
	_show_person_image({"peer_id": peer, "trainer_id": str(entry.get("trainer_id", ""))}, _paddock_person_icon, _paddock_person_portrait)
	if peer == 0:
		var trainer := CpuTrainers.by_id(str(entry.get("trainer_id", "")))
		_paddock_person_name.text = str(trainer.get("name", "CPU"))
		_paddock_person_note.text = "CPUトレーナー　得意脚質：%s" % str(STYLE_NAMES.get(str(trainer.get("favorite_running_style", "")), ""))
		_paddock_person_intro.text = str(trainer.get("introduction", ""))
	else:
		var profile: Dictionary = OnlineSession.profiles.get(peer, {})
		_paddock_person_name.text = str(profile.get("name", member_name(peer)))
		var notes: PackedStringArray = []
		if peer == OnlineSession.peer_id:
			notes.append("あなた")
		if peer == int(_room.get("host", 0)):
			notes.append("部屋主")
		_paddock_person_note.text = "・".join(notes) if not notes.is_empty() else "プレイヤー"
		var introduction := str(profile.get("introduction", ""))
		_paddock_person_intro.text = introduction if not introduction.is_empty() else "（自己紹介は、ありません）"
	_paddock_dialog_detail.call("show_pururin", str(entry["id"]), "", false, false)
	_paddock_dialog.visible = true
	(_paddock_dialog.find_child("PaddockDialogBackButton", true, false) as Button).grab_focus()


## パドックの「レース開始」（部屋主だけ。全員が確定していること）。
func start_race() -> void:
	if is_host() and everyone_confirmed():
		_client.send(Protocol.START)


# ---------------------------------------------------------------- 部屋の中

static func _link(node: Control, left: Control, right: Control, top: Control, bottom: Control) -> void:
	node.focus_neighbor_left = node.get_path_to(left)
	node.focus_neighbor_right = node.get_path_to(right)
	node.focus_neighbor_top = node.get_path_to(top)
	node.focus_neighbor_bottom = node.get_path_to(bottom)


func is_confirmed(peer_id: int) -> bool:
	for member: Dictionary in _members:
		if int(member["peer_id"]) == peer_id:
			return bool(member.get("confirmed", false))
	return false


func everyone_confirmed() -> bool:
	for member: Dictionary in _members:
		if not bool(member.get("confirmed", false)):
			return false
	return not _members.is_empty()


func is_host() -> bool:
	return OnlineSession.is_host()


## 自分が選んでいるぷるりん（まだなら空）。
func my_pururin_id() -> String:
	return OnlineSession.my_pururin_id()


static func pururin_name(pururin_id: String) -> String:
	return str(PururinRosterConfig.pururin_by_id(pururin_id).get("display_name", pururin_id))


func set_distance(distance_m: float) -> void:
	_client.send(Protocol.SETTINGS, {"distance_m": distance_m})
	# ボタンの見た目は、サーバーから届いた部屋のようすで決める（断られたときに、ずれないように）。
	_show_distance_buttons(can_set_distance())


## 窓の「変える」：パスワードを、入力らんの文字に変える（部屋の主だけ。空なら、施錠なしにする）。
func change_password() -> void:
	_client.send(Protocol.SETTINGS, {"password": _password_edit.text})
	_set_status("パスワードを変えました。" if not _password_edit.text.strip_edges().is_empty() else "パスワードを外しました（だれでも入れます）。")
	close_dialogs()


## 部屋の人を、出す（部屋の主だけ）。
func kick(peer_id: int) -> void:
	_client.send(Protocol.KICK, {"peer_id": peer_id})


func is_light_scenery() -> bool:
	return _light_scenery


func shuffle_gates() -> void:
	_client.send(Protocol.GATES, {"action": Protocol.GATES_SHUFFLE})


## 出走表：選んでいる枠を、上（-1）か下（1）の枠と入れ替える（主だけ）。カーソルは、動かした先に付いていく。
func move_selected_gate(direction: int) -> void:
	var count := (_room.get("entries", []) as Array).size()
	var other := _selected_gate + direction
	if _selected_gate < 0 or other < 0 or other >= count:
		return
	_client.send(Protocol.GATES, {"action": Protocol.GATES_SWAP, "a": _selected_gate, "b": other})
	_selected_gate = other
	# カーソルも、動かした先の枠へ付いていく。
	if _paddock_box.visible:
		(_paddock_rows[other]["button"] as Button).grab_focus()


## 一つ前へ戻る。出走表 → ぷるりんを選ぶ所（主だけ）。レース設定 → 待機室（主は全員を、ほかの人は自分だけを戻す）。
## パドックの「待機室へ戻る」：主は全員を、ほかの人は自分だけを、待機室へ戻す。
func back_to_waiting() -> void:
	_self_back = not is_host()
	_client.send(Protocol.BACK, {"to": Protocol.BACK_TO_LOBBY})


func back_to_room_phase() -> void:
	# 主でない人が、レース設定・プル選択で押すと、自分だけ待機室へ戻る（自分の操作なので、知らせは出さない）。
	_self_back = not is_host() and OnlineSession.phase() in [Protocol.PHASE_SETTINGS, Protocol.PHASE_ROOM]
	_client.send(Protocol.BACK)


## ひとことを送る（edit は、その画面のルームチャットの入力らん）。
func send_chat(edit: LineEdit) -> void:
	var text := Protocol.clean_text(edit.text, OnlineConfig.chat_max_length())
	if text.is_empty():
		return
	_client.send(Protocol.CHAT, {"text": text})
	edit.text = ""


## ひとことの記録を、出し直す（待機室のルームチャットと、ぷるりんを選ぶ所・出走表の欄の、両方）。
func _show_chat() -> void:
	for log: RichTextLabel in _chat_logs:
		log.clear()
		for line: Dictionary in OnlineSession.chat_log:
			if bool(line.get("system", false)):
				# 部屋のできごとの知らせは、色を変えて、人のひとことと見分けられるようにする。
				log.push_color(MenuStyle.COLOR_FOCUS)
				log.add_text("— %s\n" % str(line["text"]))
				log.pop()
				continue
			log.push_color(PururinSlot.COLOR_USER if bool(line["mine"]) else COLOR_OTHER_PLAYER)
			log.add_text(str(line["name"]))
			log.pop()
			log.add_text("　" + str(line["text"]) + "\n")


## レースが始まった：届いた出走と距離で、レースの画面へ進む（レースは、サーバーから届く状態を映す）。
func _go_to_race(data: Dictionary) -> void:
	prepare_race(data)
	get_tree().change_scene_to_file(LOCAL_RACE_SCENE_PATH)


## レースの画面が読むもの（距離・出走・自分の番号・景色の軽さ）を、決めておく。
func prepare_race(data: Dictionary) -> void:
	RaceSession.select_distance(float(data["distance_m"]))
	RaceSession.set_online_entries(data["entries"])
	RaceSession.set_online_view(OnlineSession.peer_id)
	RaceSession.set_course_only(_light_scenery)


## 戻る（B・Esc）。窓が出ていれば、窓を閉じる。プル選択・パドックでは、待機室へ戻る。
## 待機室・レース設定では、部屋を出るかを確かめる。部屋の外では、つながりを切って、ゲーム選択へ戻る。
func go_back() -> void:
	if is_picker_open():
		_picker.call("close")
		return
	# 「このプルにしますか」の窓では、「もどる」と同じ（プル一覧へ戻る）。
	if _pick_dialog.visible and not _pick_candidate.is_empty():
		_on_pick_dialog_back()
		return
	if is_dialog_open():
		close_dialogs()
		return
	# 入力らんで Esc：部屋は出ずに、入力らんから抜ける。
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and OnlineSession.in_room():
		focused.release_focus()
		_restore_focus()
		return
	if _paddock_box.visible:
		back_to_waiting()
		return
	if _pick_box.visible:
		back_to_room_phase()
		return
	if OnlineSession.in_room():
		open_leave_dialog()
		return
	OnlineSession.close()
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


## Escは入力欄も標準で消費するため、戻る操作を先に受け取る。
## CやXはここで受け取らず、入力欄では文字として使えるようにする。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UIAudio.play_back()
		get_viewport().set_input_as_handled()
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if RaceControllerInput.is_menu_pressed(event):
		viewport.set_input_as_handled()
		RaceControllerInput.activate_control(start_button())
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_back()
	elif _paddock_box.visible and is_host() and not is_dialog_open() and RaceControllerInput.is_slot_clear_pressed(event) and not (get_viewport().gui_get_focus_owner() is LineEdit):
		# パドックの X：枠順のくじを引き直す（部屋主だけ）。
		viewport.set_input_as_handled()
		shuffle_gates()
	elif _paddock_box.visible and RaceControllerInput.distance_step(event) != 0 and not is_dialog_open():
		# パドックの L1・R1：選んでいる枠を、上・下の枠と入れ替える（部屋主だけ）。
		viewport.set_input_as_handled()
		if is_host():
			move_selected_gate(RaceControllerInput.distance_step(event))
	elif RaceControllerInput.distance_step(event) != 0 and OnlineSession.in_room() and not is_dialog_open() and not is_picker_open():
		# L1・R1：どこにカーソルがあっても、距離を1つ動かす（部屋の主だけ）。
		viewport.set_input_as_handled()
		step_distance(RaceControllerInput.distance_step(event), "gamepad")
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()


## STARTは、その段階の先へ進む操作だけ。別の窓やチャット入力から、背後を動かさない。
func start_button() -> Button:
	if is_picker_open():
		return null
	for dialog: Control in [_create_dialog, _join_dialog]:
		if dialog.visible:
			var button_name := {"CreateDialog": "CreateButton", "JoinDialog": "JoinButton"}
			return dialog.find_child(button_name[str(dialog.name)], true, false) as Button
	if is_dialog_open():
		return null
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return _connect_button if _connect_box.visible else null
	if _connect_box.visible:
		return _connect_button
	if _waiting_box.visible:
		if is_host():
			return _race_open_button if not _race_open_button.disabled else null
		return _ready_button if not OnlineSession.my_lobby_ready() else null
	if _settings_box.visible:
		return _settings_next_button if is_host() else null
	if _paddock_box.visible:
		if is_host() and not _paddock_start_button.disabled:
			return _paddock_start_button
		return _paddock_confirm_button if not is_confirmed(OnlineSession.peer_id) else null
	if _pick_box.visible:
		if is_host() and not _pick_paddock_button.disabled:
			return _pick_paddock_button
		return _pick_confirm_button if not is_confirmed(OnlineSession.peer_id) and not _pick_confirm_button.disabled else null
	# 部屋の一覧では、STARTで先へ進むものはない（部屋の窓を開くだけなので、STARTは使わない）。
	return null
