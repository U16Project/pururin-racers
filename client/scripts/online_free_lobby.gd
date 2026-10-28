extends Control
## オンラインフリー対戦の、全体のロビーとルームの画面（場面 res://scenes/online_free_lobby.tscn）。
## 見た目（並び・色・字の大きさ・形）は、場面の部品の欄が正。ここは、サーバーから届いたようすを部品に入れ、押されたことをサーバーへ送る。
## 全体のロビー：タブで「ルーム」（カードの一覧。種類の札でしぼりこめる）と「エントリー候補」（優先の順番・一時保留・取り消し）を切り替える。
## ルームの画面：カードを押すと開く。くわしい条件・紹介文・エントリーしている人を見て、出るぷるりんを選び、「エントリーする」を押して、はじめてエントリーになる。
## 番が来たら、どの画面にいても、確かめの窓が出る。レースのあとは、ここへ戻る（結果の画面で選んだとおり、ロビーかルームの画面を開く）。
## ルームの中身（名前・画像・札・縛り・紹介文・同時に走るレースの数）は、サーバーの設定（data/config/online.json の free_rooms）。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const OnlineConfig := preload("res://scripts/config/online_config.gd")
const ServerChoice := preload("res://scripts/config/online_server_choice.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const PururinPicker := preload("res://scripts/menu/pururin_picker.gd")
const OwnedPururins := preload("res://scripts/config/owned_pururins.gd")
const LocalServer := preload("res://scripts/online/local_server.gd")

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const LOCAL_RACE_SCENE_PATH := "res://scenes/local_race.tscn"
## ルームの今のようすの色（カードの下の帯・ルームの画面の帯）。空き＝緑、呼び出し中＝黄、レース中＝橙。
const STATE_COLORS := {
	Protocol.FREE_STATE_IDLE: Color(0.32, 0.86, 0.5),
	Protocol.FREE_STATE_CALLING: Color(1.0, 0.8, 0.28),
	Protocol.FREE_STATE_RACING: Color(1.0, 0.56, 0.25),
}
## 受付の外のルームの帯の色。
const COLOR_CLOSED := Color(0.62, 0.68, 0.78)
## 帯の地の濃さ（色の不透明度）。
const STRIP_FILL_ALPHA := 0.18
const ERROR_TEXTS := {
	Protocol.ERROR_VERSION: "ゲームとサーバーの版が違います。ゲームを新しくしてください。",
	Protocol.ERROR_NO_ROOM: "そのルームはありません。",
	Protocol.ERROR_NO_ENTRY: "そのルームには、エントリーしていません。",
	Protocol.ERROR_NO_TICKET: "このぷるりんは、このルームに要るチケットを持っていません。",
	Protocol.ERROR_CLOSED: "このルームは、今は受付をしていません。",
	Protocol.ERROR_ROOM_FULL: "このルームは、エントリーの人数が上限です。",
}
## チャットの名前の色（自分・ほかの人）。
const COLOR_CHAT_MINE := Color(1.0, 0.8, 0.28)
const COLOR_CHAT_OTHER := Color(0.35, 0.86, 1.0)
## 下の帯に、ふだん出しておく案内。
const HINT_TEXT := "番が来たら、どの画面にいても呼び出しが届きます"
## ロビーのタブ。
const TAB_ROOMS := "rooms"
const TAB_ENTRIES := "entries"
const TAB_RESULTS := "results"
const TABS := [TAB_ROOMS, TAB_ENTRIES, TAB_RESULTS]
## ルームの画面の下半分のタブ。
const PART_CONDITIONS := "conditions"
const PART_ENTRANTS := "entrants"
const PART_RESULTS := "results"
## ルームの過去の結果で、レースごとに出す着順の数。
const RESULT_ROWS_SHOWN := 3
## 結果の、CPUの名前の色。
const COLOR_RESULT_CPU := Color(0.74, 0.8, 0.9)
## このPCのサーバーを起動してから、つながるまで待つ秒数と、つなぎ直す間（ともだち対戦の画面と同じ）。
const LOCAL_SERVER_START_TIMEOUT_S := 12.0
const LOCAL_SERVER_RETRY_S := 0.8
## しぼりこみの「すべて」。
const FILTER_ALL := "すべて"
## 下の帯のお知らせを、1行に収めるために小さくする、いちばん小さい文字。
const STATUS_MIN_FONT_SIZE := 10
## プル選択の窓の横に出す、ステータスの欄の幅と、窓とのすき間。
const PICKER_STATUS_WIDTH := 460.0
const PICKER_STATUS_GAP := 12.0

@onready var _server_name: Label = %ServerName
@onready var _clock: Label = %Clock
@onready var _trainer_name: Label = %TrainerName
@onready var _status: Label = %Status
@onready var _lobby_view: Control = %LobbyView
@onready var _rooms_tab: Button = %RoomsTab
@onready var _entries_tab: Button = %EntriesTab
@onready var _entries_count: Label = %EntriesCount
@onready var _filter: OptionButton = %Filter
@onready var _rooms_page: Control = %RoomsPage
@onready var _room_grid: GridContainer = %RoomGrid
@onready var _entries_page: Control = %EntriesPage
@onready var _results_tab: Button = %ResultsTab
@onready var _results_page: Control = %ResultsPage
@onready var _events_log: RichTextLabel = %EventsLog
@onready var _conditions_tab: Button = %ConditionsTab
@onready var _conditions_page: Control = %ConditionsPage
@onready var _entrants_tab: Button = %EntrantsTab
@onready var _room_results_tab: Button = %RoomResultsTab
@onready var _room_results_log: RichTextLabel = %RoomResultsLog
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _entries_empty: Label = %EntriesEmpty
@onready var _room_view: Control = %RoomView
@onready var _banner_image: TextureRect = %BannerImage
@onready var _room_tag: Control = %RoomTag
@onready var _room_tag_text: Label = %RoomTagText
@onready var _room_distance: Label = %RoomDistance
@onready var _room_name: Label = %RoomName
@onready var _distance_value: Label = %DistanceValue
@onready var _field_value: Label = %FieldValue
@onready var _rule_value: Label = %RuleValue
@onready var _open_value: Label = %OpenValue
@onready var _wait_value: Label = %WaitValue
@onready var _ticket_value: Label = %TicketValue
@onready var _pick_tickets: Label = %PickTickets
@onready var _intro: Label = %Intro
@onready var _room_strip: Control = %RoomStrip
@onready var _room_strip_dot: Control = %RoomStripDot
@onready var _room_strip_text: Label = %RoomStripText
@onready var _entrant_grid: GridContainer = %EntrantGrid
@onready var _entrants_empty: Label = %EntrantsEmpty
@onready var _portrait: Control = %Portrait
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _pick_name: Label = %PickName
@onready var _pick_info: Label = %PickInfo
@onready var _status_button: Button = %StatusButton
@onready var _entry_button: Button = %EntryButton
@onready var _hold_button: Button = %HoldButton
@onready var _entry_note: Label = %EntryNote
@onready var _picker_status: Control = %PickerStatus
@onready var _picker_status_window: Control = %PickerStatusWindow
@onready var _pick_detail: Control = %PickDetail
@onready var _picker: Control = %Picker
@onready var _lobby_chat_log: RichTextLabel = %LobbyChatLog
@onready var _lobby_chat_edit: LineEdit = %LobbyChatEdit
@onready var _lobby_chat_send: Button = %LobbyChatSend
@onready var _room_chat_log: RichTextLabel = %RoomChatLog
@onready var _room_chat_edit: LineEdit = %RoomChatEdit
@onready var _room_chat_send: Button = %RoomChatSend
@onready var _chat_overlay: Control = %ChatOverlay
@onready var _chat_overlay_tabs: Control = %ChatOverlayTabs
@onready var _chat_overlay_lobby_tab: Button = %ChatOverlayLobbyTab
@onready var _chat_overlay_room_tab: Button = %ChatOverlayRoomTab
@onready var _chat_overlay_log: RichTextLabel = %ChatOverlayLog
@onready var _chat_overlay_edit: LineEdit = %ChatOverlayEdit
@onready var _chat_overlay_send: Button = %ChatOverlaySend
@onready var _guide_chat: Control = %GuideChat
@onready var _server_button: Button = %ServerButton
@onready var _server_dialog: Control = %ServerDialog
@onready var _server_official: Button = %ServerOfficial
@onready var _server_custom: Button = %ServerCustom
@onready var _server_local: Button = %ServerLocal
@onready var _server_url_edit: LineEdit = %ServerUrl
@onready var _server_local_note: Label = %ServerLocalNote
@onready var _server_ok: Button = %ServerOk
@onready var _server_back: Button = %ServerBack
@onready var _confirm_dialog: Control = %ConfirmDialog
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo
@onready var _card_template: Button = %CardTemplate
@onready var _entry_row_template: Control = %EntryRowTemplate
@onready var _entrant_template: Control = %EntrantTemplate
@onready var _offer_panel: Control = %OfferPanel
@onready var _offer_image: TextureRect = %OfferImage
@onready var _offer_room: Label = %OfferRoom
@onready var _offer_info: Label = %OfferInfo
@onready var _offer_bar: ProgressBar = %OfferBar
@onready var _offer_time: Label = %OfferTime
@onready var _accept_button: Button = %AcceptButton
@onready var _decline_button: Button = %DeclineButton
@onready var _guide_accept: Label = %GuideAccept
@onready var _back_button: Button = %BackButton
@onready var _guide_tabs: Control = %GuideTabs

var _client: Node
## サーバーから届いた最後のもの：ルームの一覧（設定の順）、自分のエントリー候補（前ほど優先）、開いているルームのくわしいようす。
var _rooms: Array = []
var _entries: Array = []
var _detail := {}
## ルームのID → カード。
var _cards := {}
## 開いているルームの画面（ID。開いていなければ空）と、そこで選んでいるぷるりん（一覧の何番目か）。
var _open_room := ""
var _pick_index := 0
## チャットの行（ルームのID → {peer_id, name, text} の並び。空のIDは、全体のチャット）。
var _chat_lines := {}
## このPCのサーバーにつなごうとしている秒数（つなごうとしていなければ負）と、次につなぎ直すまでの秒数。
var _local_wait_s := -1.0
## サーバーを替えるために、自分でつながりを切っているところか。
var _switching_server := false
var _local_retry_s := 0.0
## 確かめの窓で「はい」「いいえ」を押したときにすること。
var _confirm_yes_action := Callable()
var _confirm_no_action := Callable()
## レースのあと、呼ばれない時刻（ミリ秒。休んでいなければ0）。
var _rest_until_msec := 0
## 下の帯のお知らせの、ふだんの文字の大きさ（場面ファイルの値）。
var _status_font_size := 0
## 大きなチャット欄で出しているチャット（ルームのID。空なら全体のチャット）。
var _overlay_room := ""
## レースのあと、ロビーのようすが届いたら開くルーム（ID）。
var _open_after_lobby := ""
var _answer_wait_s := 0.0
## サーバーの時計と、この機械の時計のずれ（秒）。締め切りまでの時間は、サーバーの時計で数える。
var _server_offset_s := 0
var _offer := {}
var _offer_until_msec := 0
var _offer_total_s := 1.0
## つながるのを待っている秒数（待っていなければ負）。
var _connect_wait_s := -1.0
## 画像を聞いたルーム（同じルームに、何度も聞かないため）。
var _asked_images := {}
var _clock_wait_s := 0.0


func _ready() -> void:
	OnlineSession.free_mode = true
	_card_template.visible = false
	_entry_row_template.visible = false
	_entrant_template.visible = false
	_offer_panel.visible = false
	_picker_status.visible = false
	_confirm_dialog.visible = false
	_chat_overlay.visible = false
	_room_view.visible = false
	_status_font_size = _status.get_theme_font_size("font_size")
	_status.resized.connect(_fit_status)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: _refresh_guide_accept())
	_status.text = HINT_TEXT
	_refresh_server_name()
	_server_button.pressed.connect(open_server_dialog)
	var group := ButtonGroup.new()
	for option: Button in [_server_official, _server_custom, _server_local]:
		option.button_group = group
		option.pressed.connect(_refresh_server_dialog)
		UIAudio.bind_button_sound(option, "confirmation")
	_server_local.visible = LocalServer.is_supported()
	_server_ok.pressed.connect(apply_server_choice)
	_server_back.pressed.connect(close_server_dialog)
	_server_url_edit.text_submitted.connect(func(_text: String) -> void: apply_server_choice())
	for button: Button in [_server_button, _server_ok]:
		UIAudio.bind_button_sound(button, "confirmation")
	UIAudio.bind_button_sound(_server_back, "back")
	_link_server_dialog_focus()
	_server_dialog.visible = false
	_trainer_name.text = TrainerProfile.trainer_name()
	_update_clock()
	_rooms_tab.pressed.connect(show_tab.bind(TAB_ROOMS))
	_entries_tab.pressed.connect(show_tab.bind(TAB_ENTRIES))
	_results_tab.pressed.connect(show_tab.bind(TAB_RESULTS))
	_conditions_tab.pressed.connect(show_room_part.bind(PART_CONDITIONS))
	_entrants_tab.pressed.connect(show_room_part.bind(PART_ENTRANTS))
	_room_results_tab.pressed.connect(show_room_part.bind(PART_RESULTS))
	for button: Button in [_results_tab, _conditions_tab, _entrants_tab, _room_results_tab]:
		UIAudio.bind_button_sound(button, "confirmation")
	_filter.item_selected.connect(func(_index: int) -> void: _refresh_cards())
	_prev_button.pressed.connect(step_pick.bind(-1))
	_next_button.pressed.connect(step_pick.bind(1))
	_status_button.pressed.connect(open_picker)
	_picker.connect("picked", _on_picker_picked)
	_picker.connect("tile_focused", func(pururin_id: String) -> void: _pick_detail.call("show_pururin", pururin_id, "", false, false))
	_picker.connect("closed", _on_picker_closed)
	for pair: Array in [[_lobby_chat_edit, _lobby_chat_send, false], [_room_chat_edit, _room_chat_send, true]]:
		var edit: LineEdit = pair[0]
		var in_room: bool = pair[2]
		# チャットの入力らんは、押したときだけ入る（ゲームパッド・方向キーでは入らない。入ると出られず、字も打てないため）。
		# ゲームパッドでは、T・SELECT の大きなチャット欄から書く。
		edit.focus_mode = Control.FOCUS_CLICK
		(pair[1] as Button).focus_mode = Control.FOCUS_NONE
		edit.max_length = OnlineConfig.chat_max_length()
		edit.text_submitted.connect(func(_text: String) -> void: send_chat(edit, in_room))
		(pair[1] as Button).pressed.connect(func() -> void: send_chat(edit, in_room))
		UIAudio.bind_button_sound(pair[1], "confirmation")
	_confirm_yes.pressed.connect(func() -> void: _answer_confirm(true))
	_confirm_no.pressed.connect(func() -> void: _answer_confirm(false))
	UIAudio.bind_button_sound(_confirm_yes, "confirmation")
	UIAudio.bind_button_sound(_confirm_no, "back")
	_chat_overlay_edit.max_length = OnlineConfig.chat_max_length()
	_chat_overlay_edit.text_submitted.connect(func(_text: String) -> void: _send_overlay_chat())
	_chat_overlay_send.pressed.connect(_send_overlay_chat)
	_chat_overlay_lobby_tab.pressed.connect(_show_overlay_chat.bind(true))
	_chat_overlay_room_tab.pressed.connect(_show_overlay_chat.bind(false))
	for button: Button in [_chat_overlay_send, _chat_overlay_lobby_tab, _chat_overlay_room_tab]:
		UIAudio.bind_button_sound(button, "confirmation")
	_entry_button.pressed.connect(press_entry)
	_hold_button.pressed.connect(press_hold)
	_accept_button.pressed.connect(answer.bind(true))
	_decline_button.pressed.connect(answer.bind(false))
	_back_button.pressed.connect(press_back)
	for button: BaseButton in [_rooms_tab, _entries_tab, _prev_button, _next_button, _hold_button, _status_button]:
		UIAudio.bind_button_sound(button, "confirmation")
	UIAudio.bind_button_sound(_entry_button, "confirmation")
	UIAudio.bind_button_sound(_accept_button, "confirmation")
	UIAudio.bind_button_sound(_decline_button, "back")
	UIAudio.bind_button_sound(_back_button, "back")
	_add_marks()
	_link_room_focus()
	show_tab(TAB_ROOMS)
	_client = OnlineSession.client(get_tree())
	_client.message_received.connect(_on_message)
	_client.connected.connect(_on_connected)
	_client.closed.connect(_on_closed)
	if OnlineSession.in_lobby():
		# レースから戻ってきた：結果の画面で選んだことを送ってから、ロビーに戻る（戻るまで、サーバーは呼ばない）。
		var after: Dictionary = OnlineSession.free_after
		OnlineSession.free_after = {}
		if after.has("entry"):
			_client.send(Protocol.FREE_AFTER, {"room_id": after["room_id"], "entry": after["entry"], "top": after["top"]})
		if not after.is_empty():
			if bool(after["stay"]):
				_open_after_lobby = str(after["room_id"])
		_client.send(Protocol.FREE_ENTER)
		_set_status("ロビーに戻りました。")
		if not OnlineSession.free_lobby.is_empty():
			_apply_lobby(OnlineSession.free_lobby)
	elif _client.is_open():
		_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())
	else:
		connect_to_server()


## ルームの画面の、ゲームパッド・方向キーでの動き：右の欄（ステータス・矢印・エントリー・保留）と、左の下のタブ（出走の条件・紹介／エントリーしている人／過去の結果）を、左右で行き来する。
func _link_room_focus() -> void:
	for button: Control in [_status_button, _prev_button, _entry_button]:
		button.focus_neighbor_left = button.get_path_to(_room_results_tab)
	_room_results_tab.focus_neighbor_right = _room_results_tab.get_path_to(_entry_button)
	for tab: Control in [_conditions_tab, _entrants_tab, _room_results_tab]:
		tab.focus_neighbor_top = tab.get_path_to(tab)
		tab.focus_neighbor_bottom = tab.get_path_to(tab)
	_entry_button.focus_neighbor_bottom = _entry_button.get_path_to(_hold_button)
	_hold_button.focus_neighbor_top = _hold_button.get_path_to(_entry_button)
	_hold_button.focus_neighbor_bottom = _hold_button.get_path_to(_hold_button)


## ゲームパッドのボタンのマーク（そのボタンを押すと、この動きになる、の印）。
func _add_marks() -> void:
	MenuStyle.add_mark(_entry_button, "A")
	MenuStyle.add_mark(_accept_button, "A")
	MenuStyle.add_mark(_decline_button, "B")
	MenuStyle.add_mark(_back_button, "B", 24.0)
	MenuStyle.add_mark(_confirm_yes, "A")
	MenuStyle.add_mark(_confirm_no, "B")
	# 印の右から文字が始まるように、左の余白を広げる。
	for button: Button in [_confirm_yes, _confirm_no]:
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var box := button.get_theme_stylebox(state)
			if box is StyleBoxFlat:
				var wider := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
				wider.content_margin_left = 48.0
				button.add_theme_stylebox_override(state, wider)
	var accept_row := _guide_accept.get_parent()
	accept_row.add_child(MenuStyle.mark("A", 24.0))
	accept_row.move_child(accept_row.get_child(accept_row.get_child_count() - 1), 0)
	_guide_chat.add_child(MenuStyle.mark("SELECT", 24.0))
	_guide_chat.move_child(_guide_chat.get_child(_guide_chat.get_child_count() - 1), 0)
	(_guide_chat.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for kind: String in ["R1", "L1"]:
		_guide_tabs.add_child(MenuStyle.mark(kind, 24.0))
		_guide_tabs.move_child(_guide_tabs.get_child(_guide_tabs.get_child_count() - 1), 0)
	for mark: Control in [accept_row.get_child(0), _guide_tabs.get_child(0), _guide_tabs.get_child(1)]:
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## つなぐ先：このPCのサーバーを動かしていればそれ。でなければ、選んだもの（自分で指定したURLが正しければ、それ。でなければ、公式サーバー）。
## 選びは、ともだち対戦の画面と同じ所に保存する（どちらで選んでも同じ）。
static func server_url() -> String:
	if LocalServer.is_running():
		return LocalServer.local_url()
	if ServerChoice.choice() == ServerChoice.CHOICE_CUSTOM and OnlineConfig.is_server_url(ServerChoice.custom_url()):
		return ServerChoice.custom_url()
	return OnlineConfig.server_url()


func connect_to_server() -> void:
	var error: Error = _client.connect_to(server_url())
	if error != OK:
		_set_status("サーバーにつながりません（%s）。" % error_string(error))
		ask("サーバーにつながりませんでした。", "つなぎ直す", reconnect, "ゲームモード選択へ", go_back)
		return
	_connect_wait_s = 0.0
	_set_status("サーバーにつないでいます…")


## 下の帯のお知らせ。1行に収まらないときは、文字を小さくする（それでも長ければ、終わりを「…」にする）。
func _set_status(text: String) -> void:
	_status.text = text
	_fit_status()


## 下の帯の「A」の案内：ロビーでルームのカードにいるときは「ルームを見る」、ほかは「決定」。
func _refresh_guide_accept() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	_guide_accept.text = "ルームを見る" if _lobby_view.visible and _cards.values().has(focused) else "決定"


func _fit_status() -> void:
	var font := _status.get_theme_font("font")
	var size := _status_font_size
	while size > STATUS_MIN_FONT_SIZE and font.get_string_size(_status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > _status.size.x:
		size -= 1
	_status.add_theme_font_size_override("font_size", size)


# ---------------------------------------------------------------- ルームの一覧

## タブを切り替える（ルーム・エントリー候補・結果）。結果のタブを開いたら、サーバーに大会の結果を聞く。
func show_tab(tab: String) -> void:
	_rooms_tab.set_pressed_no_signal(tab == TAB_ROOMS)
	_entries_tab.set_pressed_no_signal(tab == TAB_ENTRIES)
	_results_tab.set_pressed_no_signal(tab == TAB_RESULTS)
	_rooms_page.visible = tab == TAB_ROOMS
	_entries_page.visible = tab == TAB_ENTRIES
	_results_page.visible = tab == TAB_RESULTS
	_filter.visible = tab == TAB_ROOMS
	if tab == TAB_RESULTS and _client != null:
		_client.send(Protocol.FREE_EVENTS_ASK, {"room_id": ""})
	_focus_lobby()


## 今のタブ。
func current_tab() -> String:
	if _entries_page.visible:
		return TAB_ENTRIES
	return TAB_RESULTS if _results_page.visible else TAB_ROOMS


## ルームの画面の下半分：出走の条件・紹介か、エントリーしている人か、過去の結果か。過去の結果を開いたら、サーバーに聞く。
func show_room_part(part: String) -> void:
	_conditions_tab.set_pressed_no_signal(part == PART_CONDITIONS)
	_entrants_tab.set_pressed_no_signal(part == PART_ENTRANTS)
	_room_results_tab.set_pressed_no_signal(part == PART_RESULTS)
	_conditions_page.visible = part == PART_CONDITIONS
	_entrant_grid.get_parent().visible = part == PART_ENTRANTS
	_entrants_empty.visible = part == PART_ENTRANTS and (_detail.get("entrants", []) as Array).is_empty()
	_room_results_log.visible = part == PART_RESULTS
	if part == PART_RESULTS and not _open_room.is_empty():
		_room_results_log.clear()
		_room_results_log.add_text("読み込んでいます…")
		_client.send(Protocol.FREE_RESULTS_ASK, {"room_id": _open_room})


## レースのタイム「1分44秒84」。
static func time_text(seconds: float) -> String:
	var hundredths := int(round(seconds * 100.0))
	return "%d分%02d秒%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]


## 着順の1行を足す（人の走者は、名前の色を変える）。
func _add_result_row(log: RichTextLabel, row: Dictionary) -> void:
	log.add_text("　%d位　" % int(row["place"]))
	log.push_color(COLOR_CHAT_MINE if bool(row["player"]) else COLOR_RESULT_CPU)
	log.add_text("%s（%s）" % [str(row["pururin"]), str(row["name"])])
	log.pop()
	log.add_text("　" + time_text(float(row["time"])) + "\n")


## そのルームの過去の結果：レースごとに、日時と、上位3着。
func _fill_room_results(results: Array) -> void:
	_room_results_log.clear()
	if results.is_empty():
		_room_results_log.add_text("まだ結果はありません。")
		return
	for record: Dictionary in results:
		_room_results_log.push_bold()
		_room_results_log.add_text("%s%s\n" % [schedule_text(int(record["unix"])), {Protocol.STAGE_SEMI: "　準決勝", Protocol.STAGE_FINAL: "　決勝"}.get(str(record.get("stage", "")), "")])
		_room_results_log.pop()
		for row: Dictionary in (record["rows"] as Array).slice(0, RESULT_ROWS_SHOWN):
			_add_result_row(_room_results_log, row)


## 大会の結果：大会ごとに、名前・距離・日時、優勝と、決勝の着順、準決勝の数。
func _fill_events(events: Array) -> void:
	_events_log.clear()
	if events.is_empty():
		_events_log.add_text("まだ大会の結果はありません。")
		return
	for event: Dictionary in events:
		_events_log.push_bold()
		_events_log.add_text("%s　%s　%s\n" % [str(event["name"]), distance_text(float(event["distance_m"])), schedule_text(int(event["start_unix"]))])
		_events_log.pop()
		var final_rows: Array = event.get("final", [])
		if final_rows.is_empty():
			_events_log.add_text("　決勝はまだです（準決勝 %dレース）\n" % (event["semis"] as Array).size())
		else:
			_events_log.push_color(COLOR_CHAT_MINE)
			_events_log.add_text("　優勝　%s（%s）\n" % [str(final_rows[0]["pururin"]), str(final_rows[0]["name"])])
			_events_log.pop()
			for row: Dictionary in final_rows:
				_add_result_row(_events_log, row)
			if not (event["semis"] as Array).is_empty():
				_events_log.add_text("　準決勝 %dレース\n" % (event["semis"] as Array).size())
		_events_log.add_text("\n")


func _focus_lobby() -> void:
	if not is_inside_tree() or _room_view.visible or _offer_panel.visible:
		return
	if _rooms_page.visible:
		for card: Button in _visible_cards():
			card.grab_focus()
			return
		_rooms_tab.grab_focus()
	elif _results_page.visible:
		_results_tab.grab_focus()
	else:
		if not _entries.is_empty():
			(_entry_list.get_child(0).find_child("Open", true, false) as Button).grab_focus()
		else:
			_entries_tab.grab_focus()


func _visible_cards() -> Array:
	return _room_grid.get_children().filter(func(card: Control) -> bool: return card.visible)


func _apply_lobby(data: Dictionary) -> void:
	OnlineSession.free_lobby = data
	if _status.text.begins_with("サーバーにつないで"):
		_set_status("ロビーに入りました。ルームを選んで、くわしい条件を見てから、エントリーしてください。")
	_rooms = data.get("rooms", [])
	_entries = data.get("entries", [])
	_answer_wait_s = float(data.get("answer_wait_s", 0.0))
	_server_offset_s = int(data.get("now_unix", _local_unix())) - _local_unix()
	var rest_s := float(data.get("rest_s", 0.0))
	_rest_until_msec = Time.get_ticks_msec() + int(rest_s * 1000.0) if rest_s > 0.0 else 0
	_refresh_filter()
	_refresh_cards()
	_refresh_entries()
	if not _open_after_lobby.is_empty():
		var room_id := _open_after_lobby
		_open_after_lobby = ""
		if not room_by_id(room_id).is_empty():
			open_room(room_id)
	elif not _open_room.is_empty():
		_refresh_room_view()


func room_by_id(room_id: String) -> Dictionary:
	for room: Dictionary in _rooms:
		if str(room["room_id"]) == room_id:
			return room
	return {}


## 自分のエントリー候補のうち、そのルームのもの（無ければ空）。
func entry_for(room_id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if str(entry["room_id"]) == room_id:
			return entry
	return {}


## しぼりこみ：「すべて」と、ルームの種類の札（届いた順）。選んでいたものは、そのまま。
func _refresh_filter() -> void:
	var tags: Array = [FILTER_ALL]
	for room: Dictionary in _rooms:
		if not tags.has(str(room["tag"])):
			tags.append(str(room["tag"]))
	var current := _filter.get_item_text(_filter.selected) if _filter.selected >= 0 else FILTER_ALL
	var same := _filter.item_count == tags.size()
	for index in mini(_filter.item_count, tags.size()):
		same = same and _filter.get_item_text(index) == str(tags[index])
	if same:
		return
	_filter.clear()
	for tag: String in tags:
		_filter.add_item(tag)
	_filter.select(maxi(tags.find(current), 0))


func _refresh_cards() -> void:
	var tag := _filter.get_item_text(_filter.selected) if _filter.selected >= 0 else FILTER_ALL
	var index := 0
	for room: Dictionary in _rooms:
		var room_id := str(room["room_id"])
		var card: Button = _cards.get(room_id)
		if card == null:
			card = _card_template.duplicate()
			card.name = "Card_%s" % room_id
			card.unique_name_in_owner = false
			card.pressed.connect(open_room.bind(room_id))
			UIAudio.bind_button_sound(card, "confirmation")
			_room_grid.add_child(card)
			_cards[room_id] = card
		_room_grid.move_child(card, index)
		index += 1
		card.visible = tag == FILTER_ALL or str(room["tag"]) == tag
		fill_card(card, room, entry_for(room_id))


## カードに、ルームのようすを入れる。
func fill_card(card: Control, room: Dictionary, entry: Dictionary) -> void:
	var room_id := str(room["room_id"])
	(card.get_node("Image/Texture") as TextureRect).texture = _room_image(room_id)
	_set_tag(card.get_node("Tag"), card.get_node("Tag/Text"), room)
	(card.get_node("Distance") as Label).text = distance_text(float(room["distance_m"]))
	(card.get_node("Name") as Label).text = str(room["name"])
	(card.get_node("Rule") as Label).text = "本戦 開始 " + schedule_text(int(room["start_unix"])) if is_final(room) else "受付 " + schedule_range_text(int(room["open_unix"]), int(room["close_unix"])) if int(room.get("close_unix", 0)) > 0 else str(room["rule"])
	var priority := _entries.find(entry) + 1 if not entry.is_empty() else 0
	(card.get_node("Priority") as Control).visible = priority > 0 and not bool(entry["hold"])
	(card.get_node("Priority/Number") as Label).text = str(priority)
	(card.get_node("Hold") as Control).visible = not entry.is_empty() and bool(entry["hold"])
	_set_strip(card.get_node("Strip"), card.get_node("Strip/Dot"), card.get_node("Strip/Text"), room)
	var locked := is_locked(room)
	(card.get_node("Lock") as Control).visible = locked
	if locked:
		(card.get_node("Strip/Text") as Label).text = "%sが必要" % str(room["needs_ticket_name"])
	elif is_final(room):
		_set_strip_final(card.get_node("Strip"), card.get_node("Strip/Dot"), card.get_node("Strip/Text"), room)
	elif not is_open(room):
		_set_strip_closed(card.get_node("Strip"), card.get_node("Strip/Dot"), card.get_node("Strip/Text"), room)


## チケットが要るのに、自分のぷるりんが、どれも（期限の前に）持っていないルームか（カードを暗くして、錠を付ける。押しても開かない）。
func is_locked(room: Dictionary) -> bool:
	var needs := str(room.get("needs_ticket", ""))
	return not needs.is_empty() and not OwnedPururins.any_has_ticket(needs, server_now())


## 今のサーバーの時刻（世界の基準の秒）。
func server_now() -> int:
	return _local_unix() + _server_offset_s


static func _local_unix() -> int:
	return int(Time.get_unix_time_from_system())


## 今、受付をしているか（受付の時刻が無ければ、いつでも。本戦は、開始の時刻まで）。
func is_open(room: Dictionary) -> bool:
	if is_final(room):
		return str(room.get("phase", "")) == Protocol.FINAL_PHASE_ENTRY and server_now() < int(room.get("start_unix", 0))
	var open_unix := int(room.get("open_unix", 0))
	return open_unix == 0 or (server_now() >= open_unix and server_now() < int(room.get("close_unix", 0)))


## 大会の時刻を、日本の時間で「10/25 7:00」の形にする。
static func schedule_text(unix: int) -> String:
	var at := Time.get_datetime_dict_from_unix_time(unix + OnlineConfig.JST_OFFSET_S)
	return "%d/%d %d:%02d" % [int(at["month"]), int(at["day"]), int(at["hour"]), int(at["minute"])]


## 受付の時刻の幅「10/25 7:00〜7:30」（終わりが別の日なら、終わりにも日付）。
static func schedule_range_text(open_unix: int, close_unix: int) -> String:
	var open_text := schedule_text(open_unix)
	var close_text := schedule_text(close_unix)
	if open_text.get_slice(" ", 0) == close_text.get_slice(" ", 0):
		close_text = close_text.get_slice(" ", 1)
	return "%s〜%s" % [open_text, close_text]


static func is_final(room: Dictionary) -> bool:
	return str(room.get("kind", "")) == "final"


## 本戦の今のようすの文（エントリーの人数・呼び出し中・準決勝・決勝など）。short なら、カード用に短く。
static func final_state_text(room: Dictionary, now_unix: int, short: bool = false) -> String:
	match str(room.get("phase", "")):
		Protocol.FINAL_PHASE_ENTRY:
			var left := int(room.get("start_unix", 0)) - now_unix
			var count := ("%d/%d人" if short else "エントリー %d/%d人") % [int(room.get("waiting", 0)), int(room.get("max_players", 0))]
			if left <= 0:
				return count + "　まもなく開始"
			var minutes := int(ceil(float(left) / 60.0))
			return count + ("　開始まで %d分" % minutes if minutes < 60 else "　開始まで %d時間%d分" % [minutes / 60, minutes % 60])
		Protocol.FINAL_PHASE_CALLING:
			return "本戦の呼び出し中"
		Protocol.FINAL_PHASE_SEMIS:
			return "準決勝 %dレース中" % int(room.get("races", 0))
		Protocol.FINAL_PHASE_WAIT, Protocol.FINAL_PHASE_FINAL_CALLING:
			return "決勝の呼び出し中"
		Protocol.FINAL_PHASE_FINAL:
			return "決勝 レース中"
	return "終わりました"


## 受付の時刻の文：受付の前なら「受付は ○ から」、受付中なら「締め切りまで ○分」（1時間を超えれば「○時間○分」）。時刻が無ければ空。
static func schedule_state_text(room: Dictionary, now_unix: int) -> String:
	var open_unix := int(room.get("open_unix", 0))
	var close_unix := int(room.get("close_unix", 0))
	if open_unix == 0:
		return ""
	if now_unix < open_unix:
		return "受付は %s から" % schedule_text(open_unix)
	if now_unix >= close_unix:
		return "受付は終わりました"
	var minutes := int(ceil(float(close_unix - now_unix) / 60.0))
	return "締め切りまで %d分" % minutes if minutes < 60 else "締め切りまで %d時間%d分" % [minutes / 60, minutes % 60]


## 受付の外のカードの帯：うすい色で、受付の時刻の文。
func _set_strip_closed(strip: Control, dot: Control, label: Label, room: Dictionary) -> void:
	var color := COLOR_CLOSED
	var box := (strip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color = Color(color, STRIP_FILL_ALPHA)
	box.border_color = color
	strip.add_theme_stylebox_override("panel", box)
	var dot_box := (dot.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	dot_box.bg_color = color
	dot.add_theme_stylebox_override("panel", dot_box)
	label.text = schedule_state_text(room, server_now())
	label.add_theme_color_override("font_color", color.lightened(0.2))


## 本戦の帯：エントリー受付中は緑、呼び出し中は黄、レース中は橙。
func _set_strip_final(strip: Control, dot: Control, label: Label, room: Dictionary) -> void:
	var phase := str(room.get("phase", ""))
	var state := Protocol.FREE_STATE_IDLE
	if phase in [Protocol.FINAL_PHASE_CALLING, Protocol.FINAL_PHASE_WAIT, Protocol.FINAL_PHASE_FINAL_CALLING]:
		state = Protocol.FREE_STATE_CALLING
	elif phase in [Protocol.FINAL_PHASE_SEMIS, Protocol.FINAL_PHASE_FINAL]:
		state = Protocol.FREE_STATE_RACING
	var shown := room.duplicate()
	shown["state"] = state
	_set_strip(strip, dot, label, shown)
	label.text = final_state_text(room, server_now(), strip != _room_strip)


## ルームの今のようすの文。
static func state_text(room: Dictionary) -> String:
	var waiting := int(room.get("waiting", 0))
	match str(room.get("state", "")):
		Protocol.FREE_STATE_CALLING:
			return "呼び出し中　待ち %d人" % waiting
		Protocol.FREE_STATE_RACING:
			return "レース中 %d　待ち %d人" % [int(room.get("races", 0)), waiting]
	return "空いています　待ち %d人" % waiting


static func distance_text(distance_m: float) -> String:
	return "%dm" % int(round(distance_m))


func _set_strip(strip: Control, dot: Control, label: Label, room: Dictionary) -> void:
	var color: Color = STATE_COLORS.get(str(room.get("state", "")), STATE_COLORS[Protocol.FREE_STATE_IDLE])
	var box := (strip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color = Color(color, STRIP_FILL_ALPHA)
	box.border_color = color
	strip.add_theme_stylebox_override("panel", box)
	var dot_box := (dot.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	dot_box.bg_color = color
	dot.add_theme_stylebox_override("panel", dot_box)
	label.text = state_text(room)
	label.add_theme_color_override("font_color", color.lightened(0.25))


func _set_tag(tag: Control, label: Label, room: Dictionary) -> void:
	var box := (tag.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color = Color.html(str(room["tag_color"]))
	tag.add_theme_stylebox_override("panel", box)
	label.text = str(room["tag"])


## ルームの画像（まだ届いていなければ、サーバーに聞いて、届くまでは無し）。
func _room_image(room_id: String) -> Texture2D:
	var texture: Texture2D = OnlineSession.free_images.get(room_id)
	if texture == null and not _asked_images.has(room_id):
		_asked_images[room_id] = true
		_client.send(Protocol.FREE_IMAGE_ASK, {"room_id": room_id})
	return texture


func _apply_image(data: Dictionary) -> void:
	var room_id := str(data.get("room_id", ""))
	var texture := image_texture(str(data.get("image", "")))
	if texture == null:
		return
	OnlineSession.free_images[room_id] = texture
	if _cards.has(room_id):
		(_cards[room_id].get_node("Image/Texture") as TextureRect).texture = texture
	if _open_room == room_id:
		_banner_image.texture = texture
	if str(_offer.get("room_id", "")) == room_id:
		_offer_image.texture = texture


## base64 の jpg・png を、絵にする（読めなければ null）。
static func image_texture(text: String) -> Texture2D:
	if text.is_empty():
		return null
	var bytes := Marshalls.base64_to_raw(text)
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK and image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------- エントリー候補

## エントリー候補のタブ：優先の順に、1行ずつ。行ごとに、ルームを開く・優先を上げる下げる・保留・取り消す。
## 行は、作り直さずに使い回す（ゲームパッドで選んでいる所が、届くたびに外れないように）。
func _refresh_entries() -> void:
	_entries_count.text = str(_entries.size())
	(_entries_count.get_parent() as Control).visible = not _entries.is_empty()
	_entries_empty.visible = _entries.is_empty()
	while _entry_list.get_child_count() < _entries.size():
		var row: Control = _entry_row_template.duplicate()
		row.name = "Entry_%d" % _entry_list.get_child_count()
		row.unique_name_in_owner = false
		_entry_list.add_child(row)
		for action: String in ["Open", "Up", "Down", "Hold", "Cancel"]:
			var button: Button = row.find_child(action, true, false)
			button.pressed.connect(_press_entry_row.bind(row, action))
			UIAudio.bind_button_sound(button, "back" if action == "Cancel" else "confirmation")
	for index in _entry_list.get_child_count():
		var row: Control = _entry_list.get_child(index)
		row.visible = index < _entries.size()
		if not row.visible:
			continue
		var entry: Dictionary = _entries[index]
		var room := room_by_id(str(entry["room_id"]))
		row.set_meta("index", index)
		(row.find_child("Number", true, false) as Label).text = str(index + 1)
		(row.find_child("Open", true, false) as Button).text = "%s　%s" % [str(room.get("name", entry["room_id"])), distance_text(float(room.get("distance_m", 0.0)))]
		(row.find_child("Pururin", true, false) as Label).text = "%sで出る" % pururin_name(str(entry["pururin_id"]))
		(row.find_child("State", true, false) as Label).text = entry_state_text(entry)
		(row.find_child("Up", true, false) as Button).disabled = index == 0
		(row.find_child("Down", true, false) as Button).disabled = index == _entries.size() - 1
		(row.find_child("Hold", true, false) as Button).text = "保留を外す" if bool(entry["hold"]) else "保留にする"
	# 行が消えて、カーソルが行き場をなくしたら（取り消した・呼ばれて答えなかった）、残った行かタブへ戻す。
	if _entries_page.visible and is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		_focus_lobby()


func _press_entry_row(row: Control, action: String) -> void:
	var index := int(row.get_meta("index", -1))
	if index < 0 or index >= _entries.size():
		return
	var room_id := str(_entries[index]["room_id"])
	match action:
		"Open": open_room(room_id)
		"Up": move_entry(index, -1)
		"Down": move_entry(index, 1)
		"Hold": set_hold(room_id, not bool(_entries[index]["hold"]))
		"Cancel": cancel_entry(room_id)


## エントリー候補の今のようすの文。
static func entry_state_text(entry: Dictionary) -> String:
	match str(entry.get("state", "")):
		Protocol.FREE_ENTRY_CALLED:
			return "呼ばれています"
		Protocol.FREE_ENTRY_ACCEPTED:
			return "始まるのを待っています"
		Protocol.FREE_ENTRY_RACING:
			return "レース中"
	if bool(entry.get("hold", false)):
		return "保留中（待ち %d番目）" % int(entry.get("place", 0))
	return "待ち %d番目" % int(entry.get("place", 0))


static func pururin_name(pururin_id: String) -> String:
	return str(PururinRosterConfig.pururin_by_id(pururin_id).get("display_name", pururin_id))


## 優先の順番を、1つ上げる（step＝-1）・下げる（step＝1）。
func move_entry(index: int, step: int) -> void:
	var target := index + step
	if target < 0 or target >= _entries.size():
		return
	var ids: Array = _entries.map(func(entry: Dictionary) -> String: return str(entry["room_id"]))
	var moved: String = ids[index]
	ids[index] = ids[target]
	ids[target] = moved
	_client.send(Protocol.FREE_ORDER, {"room_ids": ids})


func set_hold(room_id: String, hold: bool) -> void:
	_client.send(Protocol.FREE_HOLD, {"room_id": room_id, "hold": hold})
	# 呼ばれているルームを保留にしたら、サーバーは呼び出しを取り消すので、窓も閉じる。
	if hold and str(_offer.get("room_id", "")) == room_id:
		_close_offer()
	_set_status("「%s」を保留にしました（保留のあいだは呼ばれません）。" % str(room_by_id(room_id).get("name", room_id)) if hold else "「%s」の保留を外しました。" % str(room_by_id(room_id).get("name", room_id)))


func cancel_entry(room_id: String) -> void:
	_client.send(Protocol.FREE_CANCEL, {"room_id": room_id})
	if str(_offer.get("room_id", "")) == room_id:
		_close_offer()
	_set_status("「%s」のエントリーを取り消しました。" % str(room_by_id(room_id).get("name", room_id)))


# ---------------------------------------------------------------- ルームの画面

## ルームの画面を開く。出るぷるりんは、エントリーしていればそのぷるりん、でなければ前に選んだもの（無ければ、一覧の最初）。
func open_room(room_id: String) -> void:
	var room := room_by_id(room_id)
	if room.is_empty():
		return
	if is_locked(room):
		_set_status("「%s」に出るには、「%s」が必要です。" % [str(room["name"]), str(room["needs_ticket_name"])])
		UIAudio.play_back()
		return
	close_chat_overlay()
	_open_room = room_id
	_detail = {}
	_room_chat_log.clear()
	_room_chat_edit.text = ""
	_client.send(Protocol.FREE_VIEW, {"room_id": room_id})
	var entry := entry_for(room_id)
	var pururin_id := str(entry["pururin_id"]) if not entry.is_empty() else OnlineSession.last_pick
	_pick_index = maxi(_roster_ids().find(pururin_id), 0)
	_lobby_view.visible = false
	_room_view.visible = true
	_guide_tabs.visible = false
	_back_button.text = "ロビーへ戻る"
	_refresh_room_view()
	show_room_part(PART_CONDITIONS)
	_entry_button.grab_focus()


func close_room() -> void:
	close_chat_overlay()
	var room_id := _open_room
	_open_room = ""
	_detail = {}
	_client.send(Protocol.FREE_VIEW, {"room_id": ""})
	_room_view.visible = false
	_lobby_view.visible = true
	_guide_tabs.visible = true
	_back_button.text = "戻る"
	if _cards.has(room_id) and _rooms_page.visible and (_cards[room_id] as Control).visible:
		(_cards[room_id] as Button).grab_focus()
	else:
		_focus_lobby()


func _roster_ids() -> Array:
	return (PururinRosterConfig.values()["roster"] as Array).map(func(pururin: Dictionary) -> String: return str(pururin["id"]))


func selected_pururin_id() -> String:
	var ids := _roster_ids()
	return str(ids[clampi(_pick_index, 0, ids.size() - 1)])


## 出るぷるりんを、一覧の次・前に替える（端まで行ったら、反対の端へ）。
func step_pick(step: int) -> void:
	var count := _roster_ids().size()
	_pick_index = posmod(_pick_index + step, count)
	OnlineSession.last_pick = selected_pururin_id()
	_refresh_pick()


func _refresh_room_view() -> void:
	var room := room_by_id(_open_room)
	if room.is_empty():
		close_room()
		return
	_banner_image.texture = _room_image(_open_room)
	_set_tag(_room_tag, _room_tag_text, room)
	_room_distance.text = distance_text(float(room["distance_m"]))
	_room_name.text = str(room["name"])
	_distance_value.text = distance_text(float(room["distance_m"]))
	var capacity := int(_detail.get("capacity", Protocol.ROOM_CAPACITY))
	_field_value.text = "%d人（足りない枠はCPU）" % capacity if not is_final(room) else "最大%d人。%d人ずつ準決勝、各1位で決勝" % [int(room["max_players"]), capacity]
	_rule_value.text = str(room["rule"])
	_ticket_value.text = ticket_text(room)
	if is_final(room):
		_open_value.text = "開始 %s まで（開始の時刻に呼び出し）" % schedule_text(int(room["start_unix"]))
	else:
		_open_value.text = schedule_range_text(int(room["open_unix"]), int(room["close_unix"])) if int(room.get("open_unix", 0)) > 0 else "いつでも（終わったら次のレース）"
	_wait_value.text = "呼び出しに %d秒以内に答える（答えないと失格）" % int(round(float(room.get("final_answer_s", 0.0)))) if is_final(room) else "返事 %d秒・集まり 最大%d秒" % [int(round(_answer_wait_s)), int(round(float(_detail.get("fill_wait_s", 0.0))))]
	_intro.text = str(_detail.get("intro", ""))
	_refresh_room_strip(room)
	_refresh_entrants()
	_refresh_pick()


## ルームの画面の帯：受付の外なら受付の時刻の文。受付中なら、今のようすと、締め切りまでの時間（あれば）。
func _refresh_room_strip(room: Dictionary) -> void:
	if is_final(room):
		_set_strip_final(_room_strip, _room_strip_dot, _room_strip_text, room)
		return
	if not is_open(room):
		_set_strip_closed(_room_strip, _room_strip_dot, _room_strip_text, room)
		return
	_set_strip(_room_strip, _room_strip_dot, _room_strip_text, room)
	var schedule := schedule_state_text(room, server_now())
	_room_strip_text.text = state_text(room) + ("　" + schedule if not schedule.is_empty() else "　同時に走るレースは %d まで" % int(room.get("max_races", 1)))


## 条件の「チケット」の行。
static func ticket_text(room: Dictionary) -> String:
	if not str(room.get("needs_ticket", "")).is_empty():
		return "要る：%s" % str(room["needs_ticket_name"])
	if not str(room.get("gives_ticket", "")).is_empty():
		return "1位でもらえる：%s" % str(room["gives_ticket_name"])
	return "なし"


## エントリーしている人（待っている列の順）。
func _refresh_entrants() -> void:
	for child in _entrant_grid.get_children():
		child.queue_free()
		_entrant_grid.remove_child(child)
	var entrants: Array = _detail.get("entrants", [])
	_entrants_empty.visible = entrants.is_empty() and _entrant_grid.get_parent().visible
	for entrant: Dictionary in entrants:
		var row: Control = _entrant_template.duplicate()
		row.unique_name_in_owner = false
		row.visible = true
		_entrant_grid.add_child(row)
		var preview := PururinDetail.preview_for(str(entrant["pururin_id"]))
		var dot: Control = row.get_node("Dot")
		var box := (dot.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.bg_color = preview.get("attribute_color", Color.WHITE)
		dot.add_theme_stylebox_override("panel", box)
		(row.get_node("Name") as Label).text = str(entrant["name"])
		(row.get_node("Pururin") as Label).text = str(preview.get("display_name", "")) + ("（保留中）" if bool(entrant["hold"]) else "")


## 右の欄：出るぷるりんの絵と名前、エントリーのボタン（まだ・ぷるりんを替える・取り消す）、保留のボタン。
func _refresh_pick() -> void:
	var pururin_id := selected_pururin_id()
	var preview := PururinDetail.preview_for(pururin_id)
	_portrait.call("set_pururin", PururinRosterConfig.pururin_by_id(pururin_id))
	_pick_name.text = str(preview.get("display_name", ""))
	_pick_info.text = "%s属性・%s" % [str(preview.get("attribute", "")), str(preview.get("running_style", ""))]
	var owned_tickets := OwnedPururins.tickets(pururin_id, server_now())
	_pick_tickets.text = "チケット：" + "・".join(PackedStringArray(owned_tickets.values())) if not owned_tickets.is_empty() else ""
	var entry := entry_for(_open_room)
	var needs := str(room_by_id(_open_room).get("needs_ticket", ""))
	var missing := not needs.is_empty() and not owned_tickets.has(needs)
	var closed := not is_open(room_by_id(_open_room))
	_entry_button.disabled = (missing or closed) and (entry.is_empty() or str(entry["pururin_id"]) != pururin_id)
	# 本戦は、保留できない（開始の時刻に、エントリーした全員を呼ぶ）。
	_hold_button.visible = not entry.is_empty() and not is_final(room_by_id(_open_room))
	if closed and _entry_button.disabled:
		_entry_button.text = "エントリーする" if entry.is_empty() else "ぷるりんを替える"
		_entry_note.text = "本戦は、開始の時刻までにエントリーした人だけが出られます。" if is_final(room_by_id(_open_room)) else schedule_state_text(room_by_id(_open_room), server_now()) + "。受付のあいだだけエントリーできます。"
	elif missing and _entry_button.disabled:
		_entry_button.text = "エントリーする" if entry.is_empty() else "ぷるりんを替える"
		_entry_note.text = "このぷるりんは「%s」を持っていません。" % str(room_by_id(_open_room)["needs_ticket_name"])
	elif entry.is_empty():
		_entry_button.text = "エントリーする"
		_entry_note.text = "エントリーすると、番が来たときに呼ばれます。呼ばれたら、入るか答えます。"
	elif str(entry["pururin_id"]) != pururin_id:
		_entry_button.text = "ぷるりんを替える"
		_entry_note.text = "%sでエントリーしています（%s）。" % [pururin_name(str(entry["pururin_id"])), entry_state_text(entry)]
	else:
		_entry_button.text = "取り消す"
		_entry_note.text = "エントリーしています（%s）。" % entry_state_text(entry)
	_hold_button.text = "保留を外す" if not entry.is_empty() and bool(entry["hold"]) else "保留にする"


## エントリーのボタン：まだならエントリー、ぷるりんが違えば替える、同じなら取り消す。
func press_entry() -> void:
	if _open_room.is_empty():
		return
	var entry := entry_for(_open_room)
	var room_name := str(room_by_id(_open_room).get("name", _open_room))
	if not entry.is_empty() and str(entry["pururin_id"]) == selected_pururin_id():
		cancel_entry(_open_room)
		return
	OnlineSession.last_pick = selected_pururin_id()
	_client.send(Protocol.FREE_ENTRY, {"room_id": _open_room, "pururin_id": selected_pururin_id(), "uid": OwnedPururins.uid(selected_pururin_id()), "secret": OwnedPururins.secret(selected_pururin_id())})
	if entry.is_empty():
		_set_status("「%s」にエントリーしました。番が来たら呼ばれます。" % room_name)
	else:
		_set_status("「%s」に出るぷるりんを、%sに替えました。" % [room_name, pururin_name(selected_pururin_id())])


## プル選択の窓を開く（ほかの人と重なってもよいので、選べないプルは無い）。横に、カーソル（マウス）のプルのステータスを出す。
## プルを押すと、そのプルに決まる。
func open_picker() -> void:
	_picker.size.x = PururinPicker.window_width()
	_picker_status_window.offset_left = _picker.offset_left + _picker.size.x + PICKER_STATUS_GAP
	_picker_status_window.offset_right = _picker_status_window.offset_left + PICKER_STATUS_WIDTH
	_pick_detail.call("show_pururin", selected_pururin_id(), "", false, false)
	_picker_status.visible = true
	# 一覧を開いているあいだの B は、一覧を閉じる。
	_back_button.text = "閉じる"
	_picker.call("open_choices", "出るぷるりんを選ぶ", selected_pururin_id(), {})


func is_picker_open() -> bool:
	return bool(_picker.call("is_open"))


func _on_picker_picked(pururin_id: String) -> void:
	_pick_index = maxi(_roster_ids().find(pururin_id), 0)
	OnlineSession.last_pick = selected_pururin_id()
	_picker.call("close")
	_refresh_pick()


func _on_picker_closed() -> void:
	_picker_status.visible = false
	_back_button.text = "ロビーへ戻る" if _room_view.visible else "戻る"
	if is_inside_tree() and _room_view.visible and _offer.is_empty():
		_status_button.grab_focus()


func press_hold() -> void:
	var entry := entry_for(_open_room)
	if not entry.is_empty():
		set_hold(_open_room, not bool(entry["hold"]))


## チケットをもらった：そのぷるりんに覚えさせて、知らせる。錠のカードは、開けられるようになる。
func apply_ticket(data: Dictionary) -> void:
	if OwnedPururins.add_ticket(str(data.get("uid", "")), str(data.get("ticket_id", "")), str(data.get("name", "")), int(data.get("expires_unix", 0))):
		_set_status("「%s」をもらいました！" % str(data.get("name", "")))
	_refresh_cards()
	if not _open_room.is_empty():
		_refresh_pick()


# ---------------------------------------------------------------- チャット

## チャットに書く（in_room なら、開いているルームのチャット。でなければ、全体のチャット）。
func send_chat(edit: LineEdit, in_room: bool) -> void:
	var text := Protocol.clean_text(edit.text, OnlineConfig.chat_max_length())
	if text.is_empty() or (in_room and _open_room.is_empty()):
		return
	_client.send(Protocol.FREE_CHAT, {"room_id": _open_room if in_room else "", "text": text})
	edit.text = ""


func _apply_chat_log(data: Dictionary) -> void:
	_chat_lines[str(data.get("room_id", ""))] = (data.get("lines", []) as Array).duplicate()
	_show_chat(str(data.get("room_id", "")))


func _apply_chat_message(data: Dictionary) -> void:
	var room_id := str(data.get("room_id", ""))
	var lines: Array = _chat_lines.get_or_add(room_id, [])
	lines.append(data)
	while lines.size() > Protocol.FREE_CHAT_HISTORY:
		lines.pop_front()
	_show_chat(room_id)


## チャットの行を、出し直す（全体のチャットか、開いているルームのチャット。大きなチャット欄で出していれば、そちらも）。
func _show_chat(room_id: String) -> void:
	if _chat_overlay.visible and room_id == _overlay_room:
		_fill_chat_log(_chat_overlay_log, room_id)
	if not room_id.is_empty() and room_id != _open_room:
		return
	_fill_chat_log(_lobby_chat_log if room_id.is_empty() else _room_chat_log, room_id)


## チャットの行を、欄に入れる。自分の行は、名前の色を変える。
func _fill_chat_log(log: RichTextLabel, room_id: String) -> void:
	log.clear()
	for line: Dictionary in _chat_lines.get(room_id, []):
		log.push_color(COLOR_CHAT_MINE if int(line.get("peer_id", 0)) == OnlineSession.peer_id else COLOR_CHAT_OTHER)
		log.add_text(str(line.get("name", "")))
		log.pop()
		log.add_text("　" + str(line.get("text", "")) + "\n")


## 大きなチャット欄を開く・閉じる（T・SELECT）。ロビーでは全体のチャット。ルームの画面では、タブで全体とこのルームを切り替える（はじめは、このルーム）。
func toggle_chat_overlay() -> void:
	if _chat_overlay.visible:
		close_chat_overlay()
		return
	_chat_overlay.visible = true
	_chat_overlay_tabs.visible = _room_view.visible
	_show_overlay_chat(not _room_view.visible)
	_chat_overlay_edit.grab_focus()


func close_chat_overlay() -> void:
	if not _chat_overlay.visible:
		return
	_chat_overlay.visible = false
	if _room_view.visible:
		_entry_button.grab_focus()
	else:
		_focus_lobby()


## 大きなチャット欄に出すチャットを決める（lobby なら全体、でなければ開いているルーム）。
func _show_overlay_chat(lobby: bool) -> void:
	_overlay_room = "" if lobby or _open_room.is_empty() else _open_room
	_chat_overlay_lobby_tab.set_pressed_no_signal(_overlay_room.is_empty())
	_chat_overlay_room_tab.set_pressed_no_signal(not _overlay_room.is_empty())
	_fill_chat_log(_chat_overlay_log, _overlay_room)


func _send_overlay_chat() -> void:
	var text := Protocol.clean_text(_chat_overlay_edit.text, OnlineConfig.chat_max_length())
	if text.is_empty():
		return
	_client.send(Protocol.FREE_CHAT, {"room_id": _overlay_room, "text": text})
	_chat_overlay_edit.text = ""


# ---------------------------------------------------------------- 呼ばれたとき

## 呼ばれた：どのルームか（画像・名前・距離・何番目の候補か・出るぷるりん）と、返事の残り秒を出して、答えを待つ。
func _show_offer(data: Dictionary) -> void:
	# ぷるりんを選んでいる途中・大きなチャット欄を開いているときも、呼ばれたら閉じて、確かめを先にする。
	_chat_overlay.visible = false
	_picker.call("close")
	_offer = data
	_offer_total_s = maxf(float(data.get("wait_s", 0.0)), 0.1)
	_offer_until_msec = Time.get_ticks_msec() + int(_offer_total_s * 1000.0)
	_offer_image.texture = _room_image(str(data["room_id"]))
	_offer_room.text = "%s　%s" % [str(data["name"]), distance_text(float(data["distance_m"]))]
	_offer_info.text = "第%d候補・%sで出ます" % [int(data.get("priority", 1)), pururin_name(str(data.get("pururin_id", "")))]
	var stage := str(data.get("stage", ""))
	(_offer_panel.find_child("Called", true, false) as Label).text = {Protocol.STAGE_SEMI: "本戦の呼び出しです！", Protocol.STAGE_FINAL: "決勝の呼び出しです！"}.get(stage, "呼ばれました！")
	if not stage.is_empty():
		_offer_info.text = "%sで出ます。答えないと失格になります" % pururin_name(str(data.get("pururin_id", "")))
	_offer_panel.visible = true
	_update_offer_time()
	_accept_button.grab_focus()
	UIAudio.play_confirmation()


## 呼ばれたルームに答える。
func answer(accept: bool) -> void:
	if _offer.is_empty():
		return
	_client.send(Protocol.FREE_ANSWER, {"room_id": str(_offer["room_id"]), "accept": accept})
	_set_status("入ると答えました。レースが始まるのを待っています…" if accept else "「%s」のエントリーを取り消しました。" % str(_offer["name"]))
	_close_offer()


## 呼び出しの窓を閉じる。カーソルは、続けてAを押しても何も取り消さない所へ戻す
## （ルームの画面のエントリーのボタンは、入ると答えたあと「取り消す」になるため、そこへは戻さない）。
func _close_offer() -> void:
	_offer = {}
	if _offer_panel == null or not _offer_panel.visible:
		return
	_offer_panel.visible = false
	if _room_view.visible:
		_status_button.grab_focus()
	else:
		_focus_lobby()


func _update_offer_time() -> void:
	var left := maxf(float(_offer_until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	_offer_bar.value = left / _offer_total_s * _offer_bar.max_value
	_offer_time.text = "返事を待つのは、あと %d 秒" % int(ceil(left))


# ---------------------------------------------------------------- 戻る・つながり

## 戻る：窓が出ていれば、窓を閉じる。ルームの画面なら、ロビーへ。ロビーなら、ロビーを出て、つながりを切り、ゲームモード選択へ。
func press_back() -> void:
	if not _offer.is_empty():
		answer(false)
	elif is_picker_open():
		_picker.call("close")
	elif _room_view.visible:
		close_room()
	else:
		request_leave()


# ---------------------------------------------------------------- つなぐサーバー

## 上の帯の札：今つないでいるサーバーの名前。
func _refresh_server_name() -> void:
	var text := "公式サーバー"
	if LocalServer.is_running():
		text = "このPCのサーバー"
	elif ServerChoice.choice() == ServerChoice.CHOICE_CUSTOM and OnlineConfig.is_server_url(ServerChoice.custom_url()):
		text = "自分で指定したサーバー"
	_server_name.text = text + " ▼"


## つなぐサーバーを選ぶ窓を開く。
func open_server_dialog() -> void:
	if LocalServer.is_running():
		_server_local.button_pressed = true
	elif ServerChoice.choice() == ServerChoice.CHOICE_CUSTOM:
		_server_custom.button_pressed = true
	else:
		_server_official.button_pressed = true
	_server_url_edit.text = ServerChoice.custom_url()
	_refresh_server_dialog()
	_server_dialog.visible = true
	_server_ok.grab_focus()


## サーバーの窓の、ゲームパッド・方向キーでの動き：上下は、選ぶもの → URL → つなぐ・もどる。窓の外へは出ない。
func _link_server_dialog_focus() -> void:
	var column: Array[Control] = [_server_official, _server_custom]
	if _server_local.visible:
		column.append(_server_local)
	column.append(_server_url_edit)
	for index in column.size():
		var control := column[index]
		control.focus_neighbor_top = control.get_path_to(column[maxi(index - 1, 0)])
		control.focus_neighbor_bottom = control.get_path_to(column[index + 1] if index < column.size() - 1 else _server_ok)
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)
	for button: Button in [_server_ok, _server_back]:
		button.focus_neighbor_top = button.get_path_to(_server_url_edit)
		button.focus_neighbor_bottom = button.get_path_to(button)
	_server_ok.focus_neighbor_left = _server_ok.get_path_to(_server_ok)
	_server_ok.focus_neighbor_right = _server_ok.get_path_to(_server_back)
	_server_back.focus_neighbor_left = _server_back.get_path_to(_server_ok)
	_server_back.focus_neighbor_right = _server_back.get_path_to(_server_back)
	# Tab でも、窓の中を順に回る。
	var ring: Array[Control] = column.duplicate()
	ring.append_array([_server_ok, _server_back])
	for index in ring.size():
		ring[index].focus_next = ring[index].get_path_to(ring[(index + 1) % ring.size()])
		ring[index].focus_previous = ring[index].get_path_to(ring[posmod(index - 1, ring.size())])


func close_server_dialog() -> void:
	_server_dialog.visible = false
	_focus_lobby()


func _refresh_server_dialog() -> void:
	_server_url_edit.editable = _server_custom.button_pressed
	_server_url_edit.modulate = Color.WHITE if _server_custom.button_pressed else Color(1, 1, 1, 0.4)
	var urls := LocalServer.lan_urls()
	_server_local_note.text = ("同じWi-Fiの人は %s につなぎます。" % urls[0] if not urls.is_empty() else "このPCで、サーバーを動かします。") if _server_local.button_pressed else ""
	_server_local_note.visible = _server_local.button_pressed


## 窓の「つなぐ」：選んだサーバーへつなぎ直す（今のつながりは切る。エントリー候補は取り消される）。
func apply_server_choice() -> void:
	if _server_custom.button_pressed and not OnlineConfig.is_server_url(_server_url_edit.text.strip_edges()):
		_server_local_note.text = "ws:// か wss:// で始まるURLを入れてください。"
		_server_local_note.visible = true
		return
	_server_dialog.visible = false
	if _server_local.button_pressed:
		if LocalServer.start(get_tree()) != OK:
			_set_status("このPCでサーバーを起動できませんでした。")
			return
	else:
		LocalServer.stop()
		ServerChoice.save(ServerChoice.CHOICE_CUSTOM if _server_custom.button_pressed else ServerChoice.CHOICE_DEFAULT, _server_url_edit.text if _server_custom.button_pressed else ServerChoice.custom_url())
	_refresh_server_name()
	_switching_server = true
	if _client.is_open():
		_client.send(Protocol.FREE_LEAVE)
		_client.disconnect_from_server()
	_switching_server = false
	_entries = []
	_rooms = []
	OnlineSession.free_lobby = {}
	if LocalServer.is_running():
		# 起動しきるまで、つなぎ直しながら待つ。
		_local_wait_s = 0.0
		_local_retry_s = 0.0
		_set_status("このPCでサーバーを起動しています…")
	else:
		connect_to_server()


func _wait_for_local_server(delta: float) -> void:
	if _local_wait_s < 0.0:
		return
	if _client.is_open():
		_local_wait_s = -1.0
		return
	_local_wait_s += delta
	_local_retry_s -= delta
	if _local_wait_s >= LOCAL_SERVER_START_TIMEOUT_S or not LocalServer.is_running():
		_local_wait_s = -1.0
		ask("このPCのサーバーにつながりませんでした。", "つなぎ直す", reconnect, "ゲームモード選択へ", go_back)
		return
	if _local_retry_s <= 0.0:
		_local_retry_s = LOCAL_SERVER_RETRY_S
		_client.connect_to(LocalServer.local_url())


## 確かめの窓を出す（文、「はい」の字とすること、「いいえ」の字とすること）。
func ask(text: String, yes_text: String, on_yes: Callable, no_text: String, on_no: Callable) -> void:
	_confirm_text.text = text
	_confirm_yes.text = yes_text
	_confirm_no.text = no_text
	_confirm_yes_action = on_yes
	_confirm_no_action = on_no
	_confirm_dialog.visible = true
	_confirm_no.grab_focus()


func _answer_confirm(yes: bool) -> void:
	_confirm_dialog.visible = false
	var action := _confirm_yes_action if yes else _confirm_no_action
	_confirm_yes_action = Callable()
	_confirm_no_action = Callable()
	if action.is_valid():
		action.call()
	if is_inside_tree() and not _confirm_dialog.visible:
		if _room_view.visible:
			_status_button.grab_focus()
		else:
			_focus_lobby()


## 戻る（ロビーから）：エントリー候補があれば、全部消えることを確かめてから出る。
func request_leave() -> void:
	if _entries.is_empty() or not _client.is_open():
		go_back()
		return
	ask("ロビーを出ると、エントリー候補（%d件）は、すべて取り消されます。出ますか？" % _entries.size(), "出る", go_back, "出ない", Callable())


func go_back() -> void:
	if _client != null and is_instance_valid(_client):
		_client.send(Protocol.FREE_LEAVE)
	OnlineSession.free_mode = false
	OnlineSession.close()
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func _on_connected() -> void:
	_connect_wait_s = -1.0
	_client.hello(TrainerProfile.trainer_name(), TrainerProfile.introduction(), OnlineSession.my_icon_to_send())


## つながりが切れた・つながらなかった：つなぎ直すか、ゲームモード選択へ戻るかを聞く。
func _on_closed() -> void:
	# サーバーを替えるために、自分で切ったとき・このPCのサーバーが起動しきるのを待っているときは、聞かない。
	if _switching_server or _local_wait_s >= 0.0:
		return
	var was_waiting := _connect_wait_s >= 0.0
	_connect_wait_s = -1.0
	_close_offer()
	_chat_overlay.visible = false
	_picker.call("close")
	_set_status("サーバーにつながりません。" if was_waiting else "サーバーとのつながりが切れました。")
	if _confirm_dialog.visible:
		return
	var text := "サーバーにつながりませんでした。" if was_waiting else "サーバーとのつながりが切れました。エントリー候補は、取り消されています。"
	ask(text, "つなぎ直す", reconnect, "ゲームモード選択へ", go_back)


## つなぎ直す（つながったら、名乗って、ロビーに入り直す）。
func reconnect() -> void:
	if _open_room != "":
		close_room()
	_entries = []
	_rooms = []
	OnlineSession.free_lobby = {}
	connect_to_server()


func _on_message(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.LOBBY:
			# 名乗り終えた：フリー対戦のロビーに入る。
			_client.send(Protocol.FREE_ENTER)
		Protocol.FREE_LOBBY:
			_apply_lobby(data)
		Protocol.FREE_ROOM:
			if str(data.get("room_id", "")) == _open_room:
				_detail = data
				_refresh_room_view()
		Protocol.FREE_IMAGE:
			_apply_image(data)
		Protocol.FREE_RESULTS:
			if str(data.get("room_id", "")) == _open_room:
				_fill_room_results(data.get("results", []))
		Protocol.FREE_EVENTS:
			_fill_events(data.get("events", []))
		Protocol.FREE_TICKET:
			apply_ticket(data)
		Protocol.FREE_NOTICE:
			_set_status(str(data.get("text", "")))
		Protocol.FREE_CHAT_LOG:
			_apply_chat_log(data)
		Protocol.FREE_CHAT_MESSAGE:
			_apply_chat_message(data)
		Protocol.FREE_OFFER:
			_show_offer(data)
		Protocol.FREE_OFFER_END:
			_close_offer()
			if str(data.get("reason", "")) == Protocol.FREE_OFFER_TIMEOUT:
				_set_status("返事がなかったので、「%s」のエントリーを取り消しました。" % str(room_by_id(str(data.get("room_id", ""))).get("name", "")))
			else:
				_set_status("待たずにレースが始まりました。次の番を待ちます。")
		Protocol.RACE_START:
			_close_offer()
			_go_to_race(data)
		Protocol.ERROR:
			_set_status(str(ERROR_TEXTS.get(str(data.get("code", "")), "サーバーに断られました。")))


func _process(delta: float) -> void:
	_wait_for_local_server(delta)
	if not _offer.is_empty():
		_update_offer_time()
	if _rest_until_msec > 0:
		var left := int(ceil(float(_rest_until_msec - Time.get_ticks_msec()) / 1000.0))
		if left > 0:
			_set_status("ひと休み：次の呼び出しまで %d秒" % left)
		else:
			_rest_until_msec = 0
			_set_status(HINT_TEXT)
	_clock_wait_s -= delta
	if _clock_wait_s <= 0.0:
		_update_clock()
	if _connect_wait_s >= 0.0:
		_connect_wait_s += delta
		if _connect_wait_s >= OnlineConfig.connect_timeout_s():
			_client.disconnect_from_server()
			if _connect_wait_s >= 0.0:
				_connect_wait_s = -1.0
				_set_status("サーバーにつながりません。")
				if not _confirm_dialog.visible:
					ask("サーバーにつながりませんでした。", "つなぎ直す", reconnect, "ゲームモード選択へ", go_back)


func _update_clock() -> void:
	_clock_wait_s = 1.0
	# 締め切り・開始までの時間は、1秒ごとに数え直す。
	if not _rooms.is_empty():
		_refresh_cards()
	if not _open_room.is_empty() and not room_by_id(_open_room).is_empty():
		_refresh_room_strip(room_by_id(_open_room))
	# 大会の時刻と同じ、日本の時間（サーバーの時計に合わせる）。
	var now := Time.get_datetime_dict_from_unix_time(server_now() + OnlineConfig.JST_OFFSET_S)
	_clock.text = "%d:%02d" % [int(now["hour"]), int(now["minute"])]


## レースの画面が読むもの（距離・出走・自分の番号・どのルームか）を決めて、レースの画面へ。
func _go_to_race(data: Dictionary) -> void:
	OnlineSession.free_race_room = str(data.get("free_room_id", ""))
	RaceSession.select_distance(float(data["distance_m"]))
	RaceSession.set_online_entries(data["entries"])
	RaceSession.set_online_view(OnlineSession.peer_id)
	get_tree().change_scene_to_file(LOCAL_RACE_SCENE_PATH)


## 大きなチャット欄は、入力らんで書いている途中でも、Esc・B・SELECT の1回で閉じる（入力らんより先に受け取る）。
## キーボードの C（Bに当たるキー）は、字として打てるように、ここでは受け取らない。
func _input(event: InputEvent) -> void:
	if not _chat_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_button_pressed(event, JOY_BUTTON_B) or RaceControllerInput.is_button_pressed(event, JOY_BUTTON_BACK):
		get_viewport().set_input_as_handled()
		close_chat_overlay()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner()
	# 大きなチャット欄：T（入力らんで書いているときは除く）・SELECT で開く。開いているときの C（Bに当たるキー）は、書いていなければ閉じる。
	var toggle_key: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_T and not focused is LineEdit
	if _offer.is_empty() and (toggle_key or RaceControllerInput.is_button_pressed(event, JOY_BUTTON_BACK)):
		viewport.set_input_as_handled()
		toggle_chat_overlay()
		return
	if _chat_overlay.visible and (event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event)):
		viewport.set_input_as_handled()
		close_chat_overlay()
		return
	# チャットの入力らんで Esc・B：画面は戻らず、入力らんから抜ける。
	if focused is LineEdit and (event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event)):
		viewport.set_input_as_handled()
		if _room_view.visible:
			_entry_button.grab_focus()
		else:
			focused.release_focus()
			_focus_lobby()
		return
	if _server_dialog.visible and (event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event)) and not focused is LineEdit:
		viewport.set_input_as_handled()
		UIAudio.play_back()
		close_server_dialog()
		return
	if _confirm_dialog.visible and (event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event)):
		viewport.set_input_as_handled()
		_answer_confirm(false)
		return
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		viewport.set_input_as_handled()
		if _offer.is_empty() and not _room_view.visible and not is_picker_open():
			UIAudio.play_back()
		press_back()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
	elif _offer.is_empty() and _lobby_view.visible and (RaceControllerInput.is_button_pressed(event, JOY_BUTTON_LEFT_SHOULDER) or RaceControllerInput.is_button_pressed(event, JOY_BUTTON_RIGHT_SHOULDER)):
		viewport.set_input_as_handled()
		UIAudio.play_confirmation()
		var step := 1 if RaceControllerInput.is_button_pressed(event, JOY_BUTTON_RIGHT_SHOULDER) else -1
		show_tab(TABS[posmod(TABS.find(current_tab()) + step, TABS.size())])
