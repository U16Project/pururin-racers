extends Control
## オンラインフリー対戦の、部屋の画面。3つの場面を、同じ画面の中で切り替える。
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
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const CpuTrainers := preload("res://scripts/config/cpu_trainers_config.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LOCAL_RACE_SCENE_PATH := "res://scenes/local_race.tscn"
const Protocol := preload("res://scripts/online/online_protocol.gd")
const PANEL_WIDTH := 1040.0
## 板と、画面の上下の端のあいだ。
const PANEL_SCREEN_MARGIN := 8.0
## 左右2列の、列のあいだ。
const COLUMN_GAP := 28
const ARROW_BUTTON_SIZE := Vector2(52.0, 34.0)
const BUTTON_HEIGHT := 40.0
const ROW_BUTTON_HEIGHT := 40.0
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
## 部屋の中の、左の列（決めごと・人）の幅。右は、ぷるりんの詳細。
const ROOM_LEFT_WIDTH := 500.0
const GATE_BADGE_SIZE := 28.0
const DISTANCE_BUTTON_HEIGHT := 36.0
## 行の右の、確定の印の幅と、「︙」（主が、その人を退出させる窓を開く）の幅。出さない行も、同じ幅だけ空ける。
const CONFIRM_BADGE_WIDTH := 46.0
const MEMBER_MENU_WIDTH := 24.0
## 行の、名前の札の幅（全角12文字の名前が、そのままの大きさで入る）。
const NAME_TAG_WIDTH := 176.0
## ひとことの記録の高さ。
const CHAT_LOG_HEIGHT := 70.0
## 決めごとの行の、小さい矢印ボタン。
const MINI_ARROW_SIZE := Vector2(26.0, 28.0)
## ぷるりんの板の右上の、人の画像の大きさと、板の端からの間。紹介の窓の中の画像の大きさ。
const PERSON_BUTTON_SIZE := 72.0
const PERSON_BUTTON_MARGIN := 14.0
const PROFILE_ICON_SIZE := 132.0
const STYLE_NAMES := {"escape": "逃げ", "pace": "先行", "stalk": "差し", "closer": "追い込み"}
## ぷるりんの詳細の、最低の高さ（能力の棒が、つぶれない高さ）。
const DETAIL_MIN_HEIGHT := 300.0
const COLOR_CONFIRMED := Color(0.3, 0.8, 0.5, 1.0)
## 取り返しのつかない操作（退出させる）のボタンの色。
const COLOR_DANGER_BUTTON := Color(0.72, 0.26, 0.24, 1.0)
## ほかの人の名前の色（自分は、枠の行の「ユーザー」の色）。
const COLOR_OTHER_PLAYER := Color(1.0, 0.93, 0.6, 1.0)
const CPU_SLOT_TEXT := "おまかせ（始めるときに決まる）"
const WAITING_SLOT_TEXT := "ー選び中ー"
const CLOSED_SLOT_TEXT := "ー"
const PICKER_MARGIN := 8.0
const LEAVE_BUTTON_WIDTH := 168.0
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
var _server_edit: LineEdit
var _connect_button: Button
## （2）部屋の一覧。
var _lobby_box: VBoxContainer
var _rooms_title: Label
var _rooms_box: VBoxContainer
var _open_create_button: Button
## 部屋を作る窓。
var _create_dialog: Control
var _room_name_edit: LineEdit
var _create_password_edit: LineEdit
## パスワードを聞く窓（施錠の印の部屋を選んだとき）。
var _password_dialog: Control
var _password_dialog_title: Label
var _join_password_edit: LineEdit
## パスワードを聞いている部屋の番号。
var _joining_room_id := 0
## （3）部屋の中。
var _room_box: HBoxContainer
var _room_box_outer: VBoxContainer
var _room_title: Label
var _room_lock: Control
## 距離のボタン（オフラインと同じ、横並び）。距離 → ボタン。
var _distance_buttons := {}
## 1〜8枠の行（オフラインのレース選択と同じ部品）と、その右の「出す」ボタン。
var _slots: Array[Control] = []
var _badges: Array[Control] = []
var _confirm_marks: Array[Label] = []
var _menu_buttons: Array[Button] = []
## 行ごとの中身（その行が、だれ・何を出しているか）。{"peer_id": 人の番号（CPU・閉じた行は0）, "pururin_id": 個体}
var _row_infos: Array = []
## 出走表で、カーソルを置いている枠（入れ替えの相手を選ぶため。無ければ -1）。
var _selected_gate := -1
## 案内を出した、いまの場面（部屋か、出走表か）。
var _shown_phase := ""
## 枠の下の板：部屋の決めごと（部屋）と、枠順の操作（出走表）。
var _rules_card: Control
var _gates_card: Control
var _gates_note: Label
var _gate_buttons: Array[Button] = []
var _confirm_button: Button
## いちばん下の行（「戻る」）。部屋の中では出さない（「部屋を出る」と「確定」は、右の列の下に置く）。
var _bottom_row: Control
var _filler: Control
var _leave_button: Button
## 全員が確定したときに、主に出す窓（「出走表へ」「レース開始」を押してもらう）。
var _advance_dialog: Control
var _advance_title: Label
var _advance_note: Label
var _advance_button: Button
## 主が、その窓を「まだ進まない」で閉じたか（だれかの確定が外れると、戻る）。
var _advance_dismissed := false
## ぷるりんの板の右上の、その人（CPUはトレーナー）の画像。押すと、その人の紹介の窓が出る。
var _person_button: Button
var _person_icon: Control
var _person_portrait: TextureRect
## いま右に出している人。{"peer_id": 人の番号（CPUは0）, "trainer_id": CPUトレーナー（人は空）}。だれも出していなければ空。
var _shown_person := {}
## 紹介の窓。
var _profile_dialog: Control
var _profile_icon: Control
var _profile_portrait: TextureRect
var _profile_name: Label
var _profile_note: Label
var _profile_introduction: Label
## マウスを乗せている行（無ければ -1）。乗せているあいだ、その行のぷるりんを、右の詳細に出す。
var _hovered_row := -1
## 退出させる窓と、その相手の番号。
var _kick_dialog: Control
var _kick_dialog_title: Label
var _kick_target := 0
## ひとこと。
var _chat_log: RichTextLabel
var _chat_edit: LineEdit
## 自分のぷるりんの詳細（能力・見た目）。一覧の窓を開いているあいだは、カーソルの個体を出す。
var _detail: Control
var _picker: Control
var _field_size_label: Label
var _cpu_label: Label
var _scenery_label: Label
## 部屋の主だけが押せるボタン（主でない人には、押せなくして見せる）。
var _host_buttons: Array[Button] = []
var _open_password_button: Button
## パスワードを確かめる・変える窓（部屋の主だけ）。
var _change_dialog: Control
var _current_password_label: Label
var _password_edit: LineEdit
## 自分の画面の景色を、軽くするか（コースと柵だけ・影なし・紙ふぶきなし）。ブラウザ版は、最初から軽くする。
## 見た目だけの話なので、人によって違っていてよい（レースの計算は、サーバーがやる）。
var _light_scenery := OS.has_feature("web")
## 部屋のようす（サーバーから届いた最後のもの。部屋に入っていなければ空）。
var _room := {}
var _members: Array = []
var _connect_wait_s := -1.0


func _ready() -> void:
	_client = OnlineSession.client(get_tree())
	_client.connected.connect(_on_connected)
	_client.message_received.connect(_on_message)
	_client.closed.connect(_on_closed)
	_build()
	# レースから戻ってきたときは、部屋に入ったまま。
	if OnlineSession.in_room():
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
	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_theme_constant_override("separation", 14)
	var heading := MenuStyle.label("オンラインフリー対戦", 26)
	top.add_child(heading)
	# 部屋の中では、見出しの横に、部屋の名前（と、施錠の印）を出す。
	var title_row := HBoxContainer.new()
	title_row.name = "RoomTitleRow"
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_row)
	_room_title = MenuStyle.label("", 22, MenuStyle.COLOR_FOCUS)
	_room_title.name = "RoomTitle"
	title_row.add_child(_room_title)
	_room_lock = LockMark.new()
	_room_lock.name = "RoomLock"
	_room_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_room_lock)
	# 右上：オンラインで、ほかの人に見える、自分の名前（トレーナー登録の名前）。
	var chip := PanelContainer.new()
	chip.name = "NameChip"
	chip.add_theme_stylebox_override("panel", MenuStyle.box(COLOR_CHIP, 14, 14.0, 4.0))
	top.add_child(chip)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	chip.add_child(chip_row)
	chip_row.add_child(MenuStyle.label("あなたの名前", 15, MenuStyle.COLOR_DIM))
	var name_label := MenuStyle.label(TrainerProfile.trainer_name(), 20)
	name_label.name = "NameLabel"
	chip_row.add_child(name_label)
	_status = MenuStyle.label("", 18)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size = Vector2(0.0, 24.0)
	_status.add_theme_color_override("font_color", MenuStyle.COLOR_FOCUS)
	column.add_child(_status)
	_build_connect(column)
	_build_lobby(column)
	_build_room(column)
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
	# いちばん下の行：左に「戻る」、右に「レース開始」（部屋の主にだけ出る）。
	var bottom := HBoxContainer.new()
	bottom.name = "BottomRow"
	column.add_child(bottom)
	bottom.add_child(_back_button)
	var bottom_gap := Control.new()
	bottom_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_gap)
	_bottom_row = bottom
	_build_dialogs()


func _build_connect(column: VBoxContainer) -> void:
	_connect_box = _centered_column(column, "ConnectBox", LIST_WIDTH)
	var card := _card(_connect_box, "サーバーにつなぐ")
	_server_edit = _field(card, "サーバー", "ServerEdit", OnlineConfig.server_url(), 200)
	_server_edit.text_submitted.connect(func(_text: String) -> void: connect_to_server())
	_connect_button = _big_button(card, "つなぐ", "ConnectButton", connect_to_server, MenuStyle.COLOR_BUTTON)


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


func _build_dialogs() -> void:
	var create := _dialog("CreateDialog", "部屋を作る")
	_create_dialog = create[0]
	var create_column: VBoxContainer = create[1]
	_room_name_edit = _field(create_column, "部屋の名前", "RoomNameEdit", OnlineConfig.default_room(), Protocol.ROOM_NAME_MAX_LENGTH)
	_room_name_edit.text_submitted.connect(func(_text: String) -> void: create_room())
	_create_password_edit = _field(create_column, "パスワード", "CreatePasswordEdit", "", Protocol.PASSWORD_MAX_LENGTH)
	_create_password_edit.placeholder_text = "空なら、だれでも入れます"
	_create_password_edit.text_submitted.connect(func(_text: String) -> void: create_room())
	var note := MenuStyle.label("作った人が、部屋の主になります。主は、距離・出走数・CPUを入れるか・パスワードを決められます。", 16, MenuStyle.COLOR_DIM)
	note.name = "CreateNote"
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	create_column.add_child(note)
	_dialog_buttons(create_column, "作る", "CreateButton", create_room)
	var password := _dialog("PasswordDialog", "")
	_password_dialog = password[0]
	var password_column: VBoxContainer = password[1]
	_password_dialog_title = password_column.get_node("Title")
	_join_password_edit = _field(password_column, "パスワード", "JoinPasswordEdit", "", Protocol.PASSWORD_MAX_LENGTH)
	_join_password_edit.text_submitted.connect(func(_text: String) -> void: join_with_password())
	_dialog_buttons(password_column, "入る", "JoinButton", join_with_password)
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
	var advance_parts := _dialog("AdvanceDialog", "")
	_advance_dialog = advance_parts[0]
	var advance_column: VBoxContainer = advance_parts[1]
	_advance_title = advance_column.get_node("Title")
	_advance_note = MenuStyle.label("", 17, MenuStyle.COLOR_DIM)
	_advance_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	advance_column.add_child(_advance_note)
	_dialog_buttons(advance_column, "出走表へ", "AdvanceButton", advance)
	_advance_button = advance_column.find_child("AdvanceButton", true, false)
	(advance_column.find_child("AdvanceCancelButton", true, false) as Button).text = "まだ進まない"
	(advance_column.find_child("AdvanceCancelButton", true, false) as Button).pressed.connect(func() -> void: _advance_dismissed = true)
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


## 窓を、すべて閉じる。
func close_dialogs() -> void:
	_create_dialog.visible = false
	_password_dialog.visible = false
	_change_dialog.visible = false
	_kick_dialog.visible = false
	_advance_dialog.visible = false
	_profile_dialog.visible = false
	_kick_target = 0
	_joining_room_id = 0
	_join_password_edit.text = ""
	_restore_focus()


func is_dialog_open() -> bool:
	return _create_dialog.visible or _password_dialog.visible or _change_dialog.visible or _kick_dialog.visible or _advance_dialog.visible or _profile_dialog.visible


func _build_room(column: VBoxContainer) -> void:
	# 並びは、オフラインのレース選択に合わせる：上に距離、左に出走の行、右にぷるりんの詳細。
	# 同じ並びを、2つの場面で使う。「部屋」＝だれが何を選んだか（枠順は出さない）。「出走表」＝枠順つきの全出走。
	_room_box_outer = VBoxContainer.new()
	_room_box_outer.name = "RoomBox"
	_room_box_outer.add_theme_constant_override("separation", 6)
	_room_box_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_room_box_outer)
	_room_box_outer.add_child(_build_distance_row())
	_room_box = HBoxContainer.new()
	_room_box.name = "RoomColumns"
	_room_box.add_theme_constant_override("separation", COLUMN_GAP - 8)
	_room_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_box_outer.add_child(_room_box)
	var left := VBoxContainer.new()
	left.name = "SlotColumn"
	left.custom_minimum_size = Vector2(ROOM_LEFT_WIDTH, 0.0)
	left.add_theme_constant_override("separation", 1)
	_room_box.add_child(left)
	for slot in RaceSession.SLOT_COUNT:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		left.add_child(line)
		# 枠番号の札は、出走表でだけ出す。
		var badge: Control = GateBadge.new()
		badge.call("setup", slot, GATE_BADGE_SIZE)
		line.add_child(badge)
		_badges.append(badge)
		var row: Control = PururinSlot.new()
		row.call("setup", slot)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.connect("cycle_requested", func(_slot: int, direction: int, _source: String) -> void: step_pururin(direction))
		row.connect("pick_requested", func(_slot: int) -> void: open_picker())
		row.connect("slot_focused", _on_row_focused)
		# マウスを乗せているあいだも、その行の人とぷるりんを、右に出す。
		row.mouse_entered.connect(_on_row_hovered.bind(slot))
		row.mouse_exited.connect(_on_row_unhovered.bind(slot))
		line.add_child(row)
		_slots.append(row)
		# 確定した人の行に出す印。
		var mark := Label.new()
		mark.name = "Confirmed%d" % (slot + 1)
		mark.text = "確定"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 13)
		mark.add_theme_color_override("font_color", MenuStyle.COLOR_OUTLINE)
		mark.add_theme_stylebox_override("normal", MenuStyle.box(COLOR_CONFIRMED, 6, 5.0, 1.0))
		mark.custom_minimum_size = Vector2(CONFIRM_BADGE_WIDTH, 0.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(mark)
		_confirm_marks.append(mark)
		# 部屋の主にだけ出る、小さな「︙」。押すと、その人を退出させるかを確かめる窓が出る。
		var menu := Button.new()
		menu.name = "MemberMenu%d" % (slot + 1)
		menu.text = "︙"
		menu.flat = true
		menu.focus_mode = Control.FOCUS_NONE
		menu.tooltip_text = "この人について"
		menu.add_theme_font_size_override("font_size", 16)
		menu.add_theme_color_override("font_color", MenuStyle.COLOR_DIM)
		menu.custom_minimum_size = Vector2(MEMBER_MENU_WIDTH, 26.0)
		menu.pressed.connect(open_kick_dialog.bind(slot))
		line.add_child(menu)
		_menu_buttons.append(menu)
		_row_infos.append({"peer_id": 0, "pururin_id": ""})
	# 行の下：部屋では、決めごと（出走数・CPU・パスワード。主だけが変えられる）と、自分の画面の画質を、1行に小さく並べる。
	var rules := _card(left, "")
	_rules_card = rules.get_parent()
	var rules_row := HBoxContainer.new()
	rules_row.name = "RulesRow"
	rules_row.add_theme_constant_override("separation", 10)
	rules.add_child(rules_row)
	_field_size_label = _mini_chooser(rules_row, "出走数", "FieldSize", step_field_size, 40.0, _host_buttons)
	_cpu_label = _mini_chooser(rules_row, "CPU", "Cpu", step_cpu, 40.0, _host_buttons)
	_scenery_label = _mini_chooser(rules_row, "画質", "Scenery", step_scenery, 40.0)
	_open_password_button = MenuStyle.button("パスワード", 14, MenuStyle.COLOR_BUTTON_QUIET)
	_open_password_button.name = "OpenPasswordButton"
	_open_password_button.custom_minimum_size = Vector2(0.0, MINI_ARROW_SIZE.y)
	_open_password_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact(_open_password_button, 1.0, 6.0)
	_open_password_button.pressed.connect(open_password_change_dialog)
	UIAudio.bind_button_sound(_open_password_button, "confirmation")
	rules_row.add_child(_open_password_button)
	# 出走表では、枠順の操作（主だけ）。
	var gates := _card(left, "")
	_gates_card = gates.get_parent()
	_gates_note = MenuStyle.label("", 16, MenuStyle.COLOR_DIM)
	_gates_note.name = "GatesNote"
	_gates_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	gates.add_child(_gates_note)
	var gate_row := HBoxContainer.new()
	gate_row.add_theme_constant_override("separation", 8)
	gates.add_child(gate_row)
	for spec: Array in [["くじを引き直す", "ShuffleButton", shuffle_gates], ["▲ 上へ", "GateUpButton", move_selected_gate.bind(-1)], ["▼ 下へ", "GateDownButton", move_selected_gate.bind(1)], ["選び直す", "BackToRoomButton", back_to_room_phase]]:
		var button := MenuStyle.button(str(spec[0]), 16, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = str(spec[1])
		button.custom_minimum_size = Vector2(0.0, MINI_ARROW_SIZE.y)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = {"ShuffleButton": "枠順のくじを、引き直す", "GateUpButton": "選んでいる行を、上の枠と入れ替える", "GateDownButton": "選んでいる行を、下の枠と入れ替える", "BackToRoomButton": "全員が、ぷるりんを選ぶ所へ戻る"}[str(spec[1])]
		_compact(button, 1.0, 4.0)
		button.pressed.connect(spec[2])
		UIAudio.bind_button_sound(button, "confirmation")
		gate_row.add_child(button)
		_gate_buttons.append(button)
	# ひとこと（部屋でも、出走表でも、みんなで話せる）。左の列の、残りの高さを全部使う。
	var chat := _card(left, "")
	(chat.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log = RichTextLabel.new()
	_chat_log.name = "ChatLog"
	_chat_log.custom_minimum_size = Vector2(0.0, CHAT_LOG_HEIGHT)
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.scroll_following = true
	_chat_log.add_theme_font_size_override("normal_font_size", 15)
	_chat_log.mouse_filter = Control.MOUSE_FILTER_PASS
	chat.add_child(_chat_log)
	var chat_row := HBoxContainer.new()
	chat_row.add_theme_constant_override("separation", 8)
	chat.add_child(chat_row)
	_chat_edit = _line_edit("ChatEdit", "", OnlineConfig.chat_max_length())
	_chat_edit.placeholder_text = "ひとこと（Enterで送る）"
	_chat_edit.text_submitted.connect(func(_text: String) -> void: send_chat())
	chat_row.add_child(_chat_edit)
	var send := MenuStyle.button("送る", 16, MenuStyle.COLOR_BUTTON)
	send.name = "ChatSendButton"
	send.custom_minimum_size = Vector2(72.0, FIELD_HEIGHT)
	_compact(send, 2.0, 8.0)
	send.pressed.connect(send_chat)
	chat_row.add_child(send)
	var right := _half(_room_box)
	# 右の列は、全部、ぷるりんの詳細（見た目・属性・脚質・能力）に使う。
	_detail = PururinDetail.new()
	_detail.name = "Detail"
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	# 板の右上のすみに、その人（CPUはトレーナー）の画像。押す・カーソルを合わせて決定で、紹介の窓が出る。
	_person_button = Button.new()
	_person_button.name = "PersonButton"
	_person_button.flat = true
	_person_button.tooltip_text = "この人の紹介を見る"
	_person_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_person_button.offset_left = -PERSON_BUTTON_SIZE - PERSON_BUTTON_MARGIN
	_person_button.offset_right = -PERSON_BUTTON_MARGIN
	_person_button.offset_top = PERSON_BUTTON_MARGIN
	_person_button.offset_bottom = PERSON_BUTTON_MARGIN + PERSON_BUTTON_SIZE
	_person_button.add_theme_stylebox_override("focus", MenuStyle.focus_box(12))
	_person_button.pressed.connect(open_profile_dialog)
	UIAudio.bind_button_sound(_person_button, "confirmation")
	_detail.add_child(_person_button)
	_person_icon = TrainerIcon.new()
	_person_icon.name = "PersonIcon"
	_person_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_person_button.add_child(_person_icon)
	_person_portrait = _portrait_rect("PersonPortrait")
	_person_button.add_child(_person_portrait)
	# 右の列の下：小さめの「部屋を出る」と、「確定」。左の列（ひとこと）は、板の下まで使える。
	var actions := HBoxContainer.new()
	actions.name = "RoomActions"
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	_leave_button = MenuStyle.button("　 部屋を出る", 16, MenuStyle.COLOR_BUTTON_QUIET)
	_leave_button.name = "LeaveButton"
	_leave_button.custom_minimum_size = Vector2(LEAVE_BUTTON_WIDTH, BUTTON_HEIGHT)
	_leave_button.pressed.connect(go_back)
	UIAudio.bind_button_sound(_leave_button, "back")
	MenuStyle.add_mark(_leave_button, "B", 22.0)
	actions.add_child(_leave_button)
	# 「確定」は全員にある。全員の確定がそろうと、主に「先へ進みますか」の窓が出る。
	_confirm_button = _big_button(actions, "確定", "ConfirmButton", toggle_confirm, MenuStyle.COLOR_BUTTON)
	_confirm_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ぷるりんの一覧の窓（オフラインのレース選択と同じもの）。出走の行の上に重ねて出す。
	_picker = PururinPicker.new()
	_picker.name = "Picker"
	add_child(_picker)
	_picker.connect("picked", _on_picker_picked)
	_picker.connect("tile_focused", _on_picker_tile_focused)
	_picker.connect("closed", _on_picker_closed)


## 距離は、横に並べたボタンから1つ選ぶ（オフラインと同じ見た目）。押せるのは、部屋の主だけ。
func _build_distance_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "DistanceRow"
	row.add_theme_constant_override("separation", 10)
	var caption := MenuStyle.label("距離", 20, MenuStyle.COLOR_DIM)
	caption.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(caption)
	for distance_m: float in RaceSession.supported_distances_m():
		var button := MenuStyle.button("%d m" % int(distance_m), 20, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = "Distance%d" % int(distance_m)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, DISTANCE_BUTTON_HEIGHT)
		_compact(button, 4.0)
		for state: String in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, MenuStyle.box(MenuStyle.COLOR_BUTTON_ON, 10, 22.0, 4.0))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_distance.bind(distance_m))
		UIAudio.bind_button_sound(button, "confirmation")
		row.add_child(button)
		_distance_buttons[distance_m] = button
	return row


## 行の「︙」：その人を退出させるかを確かめる窓を出す（部屋の主だけ）。
func open_kick_dialog(row_index: int) -> void:
	var target := int(_row_infos[row_index]["peer_id"])
	if target == 0 or target == OnlineSession.peer_id or not is_host():
		return
	close_dialogs()
	_kick_target = target
	_kick_dialog_title.text = "%s さん" % member_name(target)
	_kick_dialog.visible = true


## 退出させる窓の「退出させる」。
func confirm_kick() -> void:
	if _kick_target != 0:
		kick(_kick_target)
	close_dialogs()


func member_name(peer_id: int) -> String:
	for member: Dictionary in _members:
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
	var profile: Dictionary = OnlineSession.profiles.get(int(person["peer_id"]), {})
	icon.call("show_icon", str(profile.get("kind", "none")), str(profile.get("id", "")), profile.get("texture"))


## 板の右上の画像を押した：その人の紹介の窓を出す（人は、名前・自己紹介。CPUは、トレーナーの名前・得意脚質・紹介）。
func open_profile_dialog() -> void:
	if _shown_person.is_empty():
		return
	close_dialogs()
	_show_person_image(_shown_person, _profile_icon, _profile_portrait)
	var peer_id := int(_shown_person.get("peer_id", 0))
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


## 行にカーソルが来た。その行の人とぷるりんを、右に出す。出走表では、入れ替えの相手にもなる。
func _on_row_focused(row_index: int) -> void:
	_selected_gate = row_index
	_show_row_detail(row_index)
	if OnlineSession.in_entries():
		_show_gate_controls()


func _on_row_hovered(row_index: int) -> void:
	if int(_row_infos[row_index]["peer_id"]) == 0 and str(_row_infos[row_index]["pururin_id"]).is_empty():
		return
	_hovered_row = row_index
	if not is_picker_open():
		_show_row_detail(row_index)


func _on_row_unhovered(row_index: int) -> void:
	if _hovered_row != row_index:
		return
	_hovered_row = -1
	if not is_picker_open():
		_show_current_detail()


## 右に出す行：マウスを乗せている行 → カーソルの行 → 自分の行、の順。
func _show_current_detail() -> void:
	var row_index := _hovered_row if _hovered_row >= 0 else _selected_gate
	if row_index < 0 or (int(_row_infos[row_index]["peer_id"]) == 0 and str(_row_infos[row_index]["pururin_id"]).is_empty()):
		row_index = my_row()
	if row_index >= 0:
		_show_row_detail(row_index)


## 自分が出ている行（部屋では入った順、出走表では枠順。いなければ -1）。
func my_row() -> int:
	for index in _row_infos.size():
		if int(_row_infos[index]["peer_id"]) == OnlineSession.peer_id:
			return index
	return -1


## その行のぷるりんを、右に出す。板の右上には、その人（CPUはトレーナー）の画像を出す。
func _show_row_detail(row_index: int) -> void:
	var info: Dictionary = _row_infos[row_index]
	var peer_id := int(info["peer_id"])
	var pururin_id := str(info["pururin_id"])
	_detail.call("show_pururin", pururin_id, "", false, false)
	if peer_id != 0:
		_show_person({"peer_id": peer_id, "trainer_id": ""})
	elif not pururin_id.is_empty():
		_show_person({"peer_id": 0, "trainer_id": str(info.get("trainer_id", ""))})
	else:
		_show_person({})


## 板の右上の画像を、その人に替える（空の辞書なら、出さない）。
func _show_person(person: Dictionary) -> void:
	_shown_person = person
	_person_button.visible = not person.is_empty()
	if not person.is_empty():
		_show_person_image(person, _person_icon, _person_portrait)


## 「一覧から選ぶ」：ぷるりんの一覧の窓を、左の列の上に開く。右の詳細は、カーソルの個体に替わる。
func open_picker() -> void:
	close_dialogs()
	var area := _room_box.get_global_rect()
	_picker.global_position = area.position + Vector2(0.0, PICKER_MARGIN)
	_picker.size = Vector2(minf(float(PururinPicker.window_width()), ROOM_LEFT_WIDTH), area.size.y - PICKER_MARGIN * 2.0)
	_picker.call("open_choices", "ぷるりんを選ぶ", my_pururin_id(), taken_by_others())


func is_picker_open() -> bool:
	return bool(_picker.call("is_open"))


## ほかの人が選んでいる個体（個体 → その人の番目。0から）。
func taken_by_others() -> Dictionary:
	var taken := {}
	for index in _members.size():
		var member: Dictionary = _members[index]
		if int(member["peer_id"]) != OnlineSession.peer_id and not str(member["pururin_id"]).is_empty():
			taken[str(member["pururin_id"])] = index
	return taken


func _on_picker_picked(pururin_id: String) -> void:
	_client.send(Protocol.PICK, {"pururin_id": pururin_id})
	_picker.call("close")


func _on_picker_tile_focused(pururin_id: String) -> void:
	_show_detail(pururin_id)


func _on_picker_closed() -> void:
	_show_current_detail()
	var mine := my_slot()
	if mine >= 0:
		_slots[mine].grab_focus()


## 右の詳細に、その個体を出す。ほかの人が選んでいる個体なら、「◯◯が使用中」を付ける（奪えないので、強制選択のボタンは出さない）。
func _show_detail(pururin_id: String) -> void:
	# 一覧の窓で見ているあいだは、だれのぷるりんでもないので、人の画像は出さない。
	if is_picker_open():
		_show_person({})
	var holder := ""
	for member: Dictionary in _members:
		if int(member["peer_id"]) != OnlineSession.peer_id and str(member["pururin_id"]) == pururin_id and not pururin_id.is_empty():
			holder = str(member["name"])
	_detail.call("show_pururin", pururin_id, holder, false, false)


## ボタンの中の余白を詰める（行の高さを抑えるため）。
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


## 左右2列の、1列ぶん。
func _half(parent: HBoxContainer) -> VBoxContainer:
	var half := VBoxContainer.new()
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_stretch_ratio = 1.0
	half.add_theme_constant_override("separation", 4)
	parent.add_child(half)
	return half


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


## 小さい「名前 ◀ 値 ▶」を、横の並びに足して、値のラベルを返す（部屋の決めごとの行）。押すと step に -1 か 1 を渡す。
func _mini_chooser(parent: HBoxContainer, title: String, node_name: String, step: Callable, value_width: float, buttons: Array[Button] = []) -> Label:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 3)
	parent.add_child(group)
	group.add_child(MenuStyle.label(title, 14, MenuStyle.COLOR_DIM))
	var value := MenuStyle.label("", 15)
	value.name = node_name + "Label"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(value_width, 0.0)
	for direction: int in [-1, 1]:
		var button := MenuStyle.button("◀" if direction < 0 else "▶", 12, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = node_name + ("Previous" if direction < 0 else "Next")
		_compact(button, 1.0, 4.0)
		button.custom_minimum_size = MINI_ARROW_SIZE
		button.pressed.connect(step.bind(direction))
		UIAudio.bind_button_sound(button, "confirmation")
		buttons.append(button)
		if direction > 0:
			group.add_child(value)
		group.add_child(button)
	return value


## 「名前　◀　今の値　▶」の1行を足して、今の値のラベルを返す。押すと step に -1 か 1 を渡す。
func _chooser(parent: VBoxContainer, title: String, node_name: String, step: Callable, buttons: Array[Button] = []) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := MenuStyle.label(title, 20)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)
	var value := MenuStyle.label("", 20)
	value.name = node_name + "Label"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for direction: int in [-1, 1]:
		var button := MenuStyle.button("◀" if direction < 0 else "▶", 20, MenuStyle.COLOR_BUTTON_QUIET)
		button.name = node_name + ("Previous" if direction < 0 else "Next")
		button.custom_minimum_size = ARROW_BUTTON_SIZE
		_compact(button, 2.0)
		button.pressed.connect(step.bind(direction))
		UIAudio.bind_button_sound(button, "confirmation")
		buttons.append(button)
		if direction > 0:
			row.add_child(value)
		row.add_child(button)
	return value


func _process(delta: float) -> void:
	# つながるのを待つのは、決めた秒数まで。
	if _connect_wait_s >= 0.0:
		_connect_wait_s += delta
		if _connect_wait_s >= OnlineConfig.connect_timeout_s():
			_connect_wait_s = -1.0
			_client.disconnect_from_server()
			_set_status("サーバーにつながりません。サーバーの場所を確かめてください。")
			_refresh()


# ---------------------------------------------------------------- つなぐ・部屋の一覧

## 「サーバーにつなぐ」：つないで、名乗る。名乗ると、部屋の一覧が届く。
func connect_to_server() -> void:
	var url := _server_edit.text.strip_edges()
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
	_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())


## 作る窓の「作る」。
func create_room() -> void:
	var room_name := Protocol.clean_text(_room_name_edit.text, Protocol.ROOM_NAME_MAX_LENGTH)
	if room_name.is_empty():
		_set_status("部屋の名前を入れてください。")
		return
	_client.create_room(room_name, _create_password_edit.text)
	close_dialogs()


## 一覧の部屋を選んだ。施錠の印の部屋は、パスワードを聞く窓を出す。それ以外は、そのまま入る。
func choose_room(room_id: int) -> void:
	for entry: Dictionary in OnlineSession.rooms:
		if int(entry["room_id"]) == room_id and bool(entry["locked"]):
			close_dialogs()
			_joining_room_id = room_id
			_password_dialog_title.text = "「%s」のパスワード" % str(entry["name"])
			_password_dialog.visible = true
			_join_password_edit.grab_focus()
			return
	_client.join_room(room_id)


## パスワードを聞く窓の「入る」。
func join_with_password() -> void:
	if _joining_room_id != 0:
		_client.join_room(_joining_room_id, _join_password_edit.text)
	close_dialogs()


## 部屋を出て、部屋の一覧へ戻る。
func leave_room() -> void:
	_client.send(Protocol.LEAVE)


func _on_message(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.LOBBY:
			if not _status.text in KICKED_TEXTS.values():
				_set_status("部屋を選ぶか、作ってください。")
			_refresh()
		Protocol.ROOMS:
			_refresh()
		Protocol.WELCOME:
			_shown_phase = str(data.get("phase", Protocol.PHASE_ROOM))
			_set_status("部屋「%s」に入りました。ぷるりんを選んで、「確定」を押してください。" % str(data["room"]))
			_refresh()
		Protocol.ROOM:
			# 場面が替わったら、することを案内する。
			var phase := str(data.get("phase", ""))
			if phase != _shown_phase:
				_shown_phase = phase
				_set_status("出走表です。枠順と、みんなのぷるりんを確かめて、「確定」を押してください。" if phase == Protocol.PHASE_ENTRIES else "ぷるりんを選んで、「確定」を押してください。")
			_refresh()
		Protocol.CHAT_MESSAGE:
			_show_chat()
		Protocol.PROFILE_INFO:
			# 紹介が届いた。いま出している人の画像なら、出し直す。
			if int(data["peer_id"]) == int(_shown_person.get("peer_id", -1)):
				_show_person(_shown_person)
		Protocol.KICKED:
			_set_status(str(KICKED_TEXTS.get(str(data.get("by", "")), "部屋から退出させられました。")))
		Protocol.RACE_START:
			_go_to_race(data)
		Protocol.ERROR:
			_set_status(str(ERROR_TEXTS.get(str(data.get("code", "")), "サーバーに断られました。")))


func _on_closed() -> void:
	var was_waiting := _connect_wait_s >= 0.0
	_connect_wait_s = -1.0
	_set_status("サーバーにつながりません。サーバーの場所を確かめてください。" if was_waiting else "サーバーとのつながりが切れました。")
	_refresh()


func _set_status(text: String) -> void:
	_status.text = text


## 今の場面（つなぐ前・部屋の一覧・部屋の中）に合わせて、画面を出し直す。
func _refresh() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	# 部屋一覧の行は作り直すので、ノードではなく部屋の名前で選択を引き継ぐ。
	var focused_room := str(previous_focus.name) if previous_focus != null and previous_focus.get_parent() == _rooms_box else ""
	var in_room := OnlineSession.in_room()
	var in_lobby := OnlineSession.in_lobby() and not in_room
	_room = OnlineSession.room if in_room else {}
	_members = _room.get("members", [])
	_connect_box.visible = not in_room and not in_lobby
	_lobby_box.visible = in_lobby
	_room_box_outer.visible = in_room
	_room_title.visible = in_room
	_room_lock.visible = in_room and bool(OnlineSession.room.get("locked", false))
	# 場面が変わったら、その場面のものでない窓は閉じる。
	if not in_lobby:
		_create_dialog.visible = false
		_password_dialog.visible = false
	if not in_room or not OnlineSession.is_host():
		_change_dialog.visible = false
	if not in_room and is_picker_open():
		_picker.call("close")
	if not in_room or not OnlineSession.is_host():
		_kick_dialog.visible = false
	_bottom_row.visible = not in_room
	_filler.visible = not in_room
	if not in_room or not OnlineSession.is_host():
		_advance_dialog.visible = false
	if in_lobby:
		_show_rooms()
	if in_room:
		_show_room()
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
		controls.assign([_server_edit, _connect_button, _back_button])
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
	elif OnlineSession.in_entries() and _selected_gate >= 0:
		_slots[_selected_gate].grab_focus()
	elif my_slot() >= 0:
		_slots[my_slot()].grab_focus()
	elif OnlineSession.in_room():
		_leave_button.grab_focus()
	else:
		_back_button.grab_focus()


## 部屋の一覧を出す。1部屋が1つのボタンで、押すと入る（施錠の印の部屋は、パスワードを聞く）。満員・レース中の部屋は、押せない。
## 作れる数ぶんの行を、いつも出す（空いている行は、うすく「空き」）。
func _show_rooms() -> void:
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
		button.disabled = bool(entry["racing"]) or int(entry["count"]) >= int(entry["field_size"])
		button.pressed.connect(choose_room.bind(int(entry["room_id"])))
		UIAudio.bind_button_sound(button, "confirmation")
		_rooms_box.add_child(button)
		var columns := _room_columns(str(entry["name"]), str(entry["host_name"]), "%d／%d" % [int(entry["count"]), int(entry["field_size"])], MenuStyle.COLOR_TEXT, 19)
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
	if int(entry["count"]) >= int(entry["field_size"]):
		return "満員"
	return ""


# ---------------------------------------------------------------- 部屋の中

func _show_room() -> void:
	var in_entries := OnlineSession.in_entries()
	_room_title.text = "／　部屋「%s」%s" % [str(_room.get("room", "")), "　出走表" if in_entries else ""]
	var mine := my_pururin_id()
	_scenery_label.text = scenery_text()
	_field_size_label.text = "%d体" % int(_room.get("field_size", 0))
	_cpu_label.text = "あり" if bool(_room.get("cpu", true)) else "なし"
	# 部屋の決めごとは、部屋の主だけ。出走表では、変えられない。
	var host := is_host()
	for button: Button in _host_buttons:
		button.disabled = not host
	var distance := float(_room.get("distance_m", 0.0))
	for distance_m: float in _distance_buttons:
		var button: Button = _distance_buttons[distance_m]
		button.set_pressed_no_signal(is_equal_approx(distance_m, distance))
		# 押せない人・押せない場面でも、決まっている距離は、色を付けて、はっきり見せる。ほかは、うすくする。
		button.disabled = not host or in_entries
		button.add_theme_stylebox_override("disabled", MenuStyle.box(MenuStyle.COLOR_BUTTON_ON if button.button_pressed else MenuStyle.COLOR_BUTTON_QUIET, 10, 22.0, 4.0))
		button.add_theme_color_override("font_disabled_color", MenuStyle.COLOR_TEXT)
		button.modulate.a = 1.0 if not button.disabled or button.button_pressed else 0.4
	_open_password_button.visible = host
	_rules_card.visible = not in_entries
	_gates_card.visible = in_entries
	if in_entries:
		if is_picker_open():
			_picker.call("close")
		_show_entry_rows()
		_show_gate_controls()
		_show_current_detail()
	else:
		_selected_gate = -1
		_show_member_rows()
		# 一覧の窓を開いているあいだは、詳細はカーソルの個体のまま。窓のタイルの状態は、開き直して合わせる。
		if is_picker_open():
			_picker.call("open_choices", "ぷるりんを選ぶ", mine, taken_by_others())
		else:
			_show_current_detail()
	_show_bottom_buttons()
	_show_chat()


## 自分の行（0から。部屋に入った順。いなければ -1）。
func my_slot() -> int:
	for index in _members.size():
		if int(_members[index]["peer_id"]) == OnlineSession.peer_id:
			return index
	return -1


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


## 行の右の、確定の印と「︙」を、その行の人に合わせる（CPU・閉じた行は、どちらも出さない）。
func _show_row_side(row_index: int, peer_id: int) -> void:
	var mark := _confirm_marks[row_index]
	mark.modulate.a = 1.0 if peer_id != 0 and is_confirmed(peer_id) else 0.0
	var menu := _menu_buttons[row_index]
	var can_open := peer_id != 0 and peer_id != OnlineSession.peer_id and is_host()
	menu.modulate.a = 1.0 if can_open else 0.0
	menu.disabled = not can_open


## 部屋の場面：人を、入った順に並べる（枠順は、まだ決まっていないので、枠番号は出さない）。
## そのあとは、CPU（入れる部屋だけ。出走数まで）。出走数より先の行は、閉じた見た目にする。
func _show_member_rows() -> void:
	var field_size := int(_room.get("field_size", Protocol.ROOM_CAPACITY))
	var with_cpu := bool(_room.get("cpu", true))
	for index in _slots.size():
		var row := _slots[index]
		_badges[index].visible = false
		row.modulate.a = 1.0
		var info := {"peer_id": 0, "pururin_id": ""}
		if index < _members.size():
			var member: Dictionary = _members[index]
			var is_me := int(member["peer_id"]) == OnlineSession.peer_id
			info = {"peer_id": int(member["peer_id"]), "pururin_id": str(member["pururin_id"])}
			row.call("set_role", is_me)
			row.call("set_view", name_tag(member), PururinSlot.COLOR_USER if is_me else COLOR_OTHER_PLAYER, PururinSlot.EMPTY_TEXT if is_me else WAITING_SLOT_TEXT, is_me, true, NAME_TAG_WIDTH)
			row.call("set_pururin", PururinRosterConfig.pururin_by_id(str(member["pururin_id"])))
		elif with_cpu and index < field_size:
			row.call("set_role", false)
			row.call("set_view", PururinSlot.CPU_TAG, MenuStyle.COLOR_DIM, CPU_SLOT_TEXT, false, false, NAME_TAG_WIDTH)
			row.call("set_pururin", {})
		else:
			row.call("set_role", false)
			row.call("set_view", "", MenuStyle.COLOR_DIM, CLOSED_SLOT_TEXT, false, false, NAME_TAG_WIDTH)
			row.call("set_pururin", {})
			row.modulate.a = 0.35
		_row_infos[index] = info
		_show_row_side(index, int(info["peer_id"]))


## 行の左の札に出す名前（部屋の主には、印を付ける）。
func name_tag(member: Dictionary) -> String:
	return str(member["name"]) + ("［主］" if int(member["peer_id"]) == int(_room.get("host", 0)) else "")


## 出走表の場面：枠順に、全出走（人とCPU）を並べる。どの行にもカーソルを置けて、右の詳細で能力を見られる。
func _show_entry_rows() -> void:
	var entries: Array = _room.get("entries", [])
	for index in _slots.size():
		var row := _slots[index]
		var info := {"peer_id": 0, "pururin_id": ""}
		_badges[index].visible = true
		_badges[index].modulate.a = 1.0 if index < entries.size() else 0.25
		row.modulate.a = 1.0
		if index < entries.size():
			var entry: Dictionary = entries[index]
			var peer_id := int(entry["peer_id"])
			var is_me := peer_id == OnlineSession.peer_id
			info = {"peer_id": peer_id, "pururin_id": str(entry["id"]), "trainer_id": str(entry.get("trainer_id", ""))}
			var tag := str(entry["trainer_name"])
			var color := MenuStyle.COLOR_DIM
			if peer_id != 0:
				tag += "［主］" if peer_id == int(_room.get("host", 0)) else ""
				color = PururinSlot.COLOR_USER if is_me else COLOR_OTHER_PLAYER
			row.call("set_role", is_me)
			row.call("set_view", tag, color, CLOSED_SLOT_TEXT, false, true, NAME_TAG_WIDTH)
			row.call("set_pururin", PururinRosterConfig.pururin_by_id(str(entry["id"])))
		else:
			row.call("set_role", false)
			row.call("set_view", "", MenuStyle.COLOR_DIM, CLOSED_SLOT_TEXT, false, false, NAME_TAG_WIDTH)
			row.call("set_pururin", {})
			row.modulate.a = 0.35
		_row_infos[index] = info
		_show_row_side(index, int(info["peer_id"]))
	# 最初は、自分の枠を選んでおく（自分のぷるりんが、右に出る）。
	if _selected_gate < 0 or _selected_gate >= entries.size():
		_selected_gate = my_row()


## 出走表の、枠順の操作（主だけ押せる）と、その説明。
func _show_gate_controls() -> void:
	var host := is_host()
	var count := (_room.get("entries", []) as Array).size()
	# 主には、ボタンだけを出す（行を選んで▲▼で、となりの枠と入れ替える。「選び直す」で、全員が部屋へ戻る）。
	_gates_note.text = "枠順は、くじで決まりました。主が、引き直しや入れ替えをできます。"
	_gates_note.visible = not host
	for button: Button in _gate_buttons:
		button.visible = host
	if host:
		(_gate_buttons[1] as Button).disabled = _selected_gate <= 0
		(_gate_buttons[2] as Button).disabled = _selected_gate < 0 or _selected_gate >= count - 1


## いちばん下の「確定」を、今の場面に合わせる。全員が確定したら、主に「先へ進みますか」の窓を出す。
func _show_bottom_buttons() -> void:
	var in_entries := OnlineSession.in_entries()
	var confirmed := is_confirmed(OnlineSession.peer_id)
	var all_confirmed := everyone_confirmed()
	var host := is_host()
	if not all_confirmed:
		_advance_dismissed = false
		_advance_dialog.visible = false
	# 主は、全員が確定したあと（窓を「まだ進まない」で閉じたあと）は、このボタンで、もう一度窓を開ける。
	if host and all_confirmed:
		_confirm_button.text = "レース開始へ…" if in_entries else "出走表へ…"
	else:
		_confirm_button.text = "確定を取り消す" if confirmed else "確定"
	_confirm_button.add_theme_stylebox_override("normal", MenuStyle.box(MenuStyle.COLOR_BUTTON_ON if host and all_confirmed else (MenuStyle.COLOR_BUTTON_QUIET if confirmed else MenuStyle.COLOR_BUTTON), 10, 22.0, 10.0))
	# 部屋では、ぷるりんを選んでからでないと、確定できない。
	_confirm_button.disabled = not in_entries and my_pururin_id().is_empty()
	if host and all_confirmed and not _advance_dismissed and not _advance_dialog.visible and not is_picker_open():
		open_advance_dialog()


## 主に出す窓：全員が確定した。部屋では「出走表へ」、出走表では「レース開始」。
func open_advance_dialog() -> void:
	if not is_host() or not everyone_confirmed():
		return
	close_dialogs()
	var in_entries := OnlineSession.in_entries()
	_advance_title.text = "全員が確定しました"
	_advance_note.text = "この枠順で、レースを始めますか。" if in_entries else "出走表へ進みますか。CPUのぷるりんと、枠順（くじ）が決まります。"
	_advance_button.text = "レース開始" if in_entries else "出走表へ"
	_advance_dialog.visible = true
	_advance_button.grab_focus()


func is_host() -> bool:
	return OnlineSession.is_host()


## 自分が選んでいるぷるりん（まだなら空）。
func my_pururin_id() -> String:
	return OnlineSession.my_pururin_id()


func everyone_picked() -> bool:
	for member: Dictionary in _members:
		if str(member["pururin_id"]).is_empty():
			return false
	return not _members.is_empty()


static func pururin_name(pururin_id: String) -> String:
	return str(PururinRosterConfig.pururin_by_id(pururin_id).get("display_name", pururin_id))


## ぷるりんを、次（1）か前（-1）の個体に替える。ほかの人が選んでいる個体は、飛ばす。
func step_pururin(direction: int) -> void:
	var taken := {}
	for member: Dictionary in _members:
		if int(member["peer_id"]) != OnlineSession.peer_id and not str(member["pururin_id"]).is_empty():
			taken[str(member["pururin_id"])] = true
	var ids: Array = (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))
	var index := ids.find(my_pururin_id())
	# まだ選んでいないとき、次へ＝最初の個体、前へ＝最後の個体から始める。
	if index < 0:
		index = -1 if direction > 0 else ids.size()
	for _attempt in ids.size():
		index = posmod(index + direction, ids.size())
		if not taken.has(ids[index]):
			_client.send(Protocol.PICK, {"pururin_id": ids[index]})
			return


## 距離を決める（部屋の主だけ）。
func set_distance(distance_m: float) -> void:
	_client.send(Protocol.SETTINGS, {"distance_m": distance_m})
	# ボタンの見た目は、サーバーから届いた部屋のようすで決める（断られたときに、ずれないように）。
	_show_room()


## 出走数を、1つ増やす（1）か減らす（-1）（部屋の主だけ）。今いる人数より少なくは、できない。
func step_field_size(direction: int) -> void:
	var lowest := maxi(Protocol.FIELD_SIZE_MIN, _members.size())
	var wanted := clampi(int(_room.get("field_size", Protocol.ROOM_CAPACITY)) + direction, lowest, Protocol.ROOM_CAPACITY)
	if wanted != int(_room.get("field_size", 0)):
		_client.send(Protocol.SETTINGS, {"field_size": wanted})


## CPUを入れるかを、切り替える（部屋の主だけ。どちら向きに押しても、切り替わる）。
func step_cpu(_direction: int) -> void:
	_client.send(Protocol.SETTINGS, {"cpu": not bool(_room.get("cpu", true))})


## 窓の「変える」：パスワードを、入力らんの文字に変える（部屋の主だけ。空なら、施錠なしにする）。
func change_password() -> void:
	_client.send(Protocol.SETTINGS, {"password": _password_edit.text})
	_set_status("パスワードを変えました。" if not _password_edit.text.strip_edges().is_empty() else "パスワードを外しました（だれでも入れます）。")
	close_dialogs()


## 部屋の人を、出す（部屋の主だけ）。
func kick(peer_id: int) -> void:
	_client.send(Protocol.KICK, {"peer_id": peer_id})


## 画質を、標準と軽量で切り替える（どちら向きに押しても、切り替わる）。
func step_scenery(_direction: int) -> void:
	_light_scenery = not _light_scenery
	_scenery_label.text = scenery_text()


func is_light_scenery() -> bool:
	return _light_scenery


func scenery_text() -> String:
	return "軽量" if _light_scenery else "標準"


## 「確定」を押す・取り消す。
func toggle_confirm() -> void:
	# 主は、全員が確定したあとは、「先へ進みますか」の窓を開く。
	if is_host() and everyone_confirmed():
		_advance_dismissed = false
		open_advance_dialog()
		return
	_client.send(Protocol.CONFIRM, {"on": not is_confirmed(OnlineSession.peer_id)})


## 主の、先へ進むボタン。部屋では「出走表へ」、出走表では「レース開始」。
func advance() -> void:
	_client.send(Protocol.START if OnlineSession.in_entries() else Protocol.ENTRIES)
	close_dialogs()


## 出走表：枠順のくじを、引き直す（主だけ）。
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


## 出走表から、部屋へ戻る（主だけ。全員が、ぷるりんを選ぶ所へ戻る）。
func back_to_room_phase() -> void:
	_client.send(Protocol.BACK)


## ひとことを送る。
func send_chat() -> void:
	var text := Protocol.clean_text(_chat_edit.text, OnlineConfig.chat_max_length())
	if text.is_empty():
		return
	_client.send(Protocol.CHAT, {"text": text})
	_chat_edit.text = ""


## ひとことの記録を、出し直す。
func _show_chat() -> void:
	_chat_log.clear()
	for line: Dictionary in OnlineSession.chat_log:
		_chat_log.push_color(PururinSlot.COLOR_USER if bool(line["mine"]) else COLOR_OTHER_PLAYER)
		_chat_log.add_text(str(line["name"]))
		_chat_log.pop()
		_chat_log.add_text("　" + str(line["text"]) + "\n")


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


## 窓が出ていれば、窓を閉じる。部屋の中では、部屋を出て、一覧へ戻る。それ以外では、つながりを切って、ゲーム選択へ戻る。
func go_back() -> void:
	if is_picker_open():
		_picker.call("close")
		return
	if is_dialog_open():
		close_dialogs()
		return
	if OnlineSession.in_room():
		leave_room()
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
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_back()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
