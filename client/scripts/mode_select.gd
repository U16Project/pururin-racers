extends Control
## ゲームモード選択。オフライン・オンラインフリー対戦・ともだち対戦・カメラで探検を選ぶ。
## 見た目は、オンラインフリー対戦の画面と同じ組み立て（上の帯・絵つきのカード・下の帯）。

const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const MENU_SCENE_PATH := "res://scenes/options.tscn"
const ONLINE_LOBBY_SCENE_PATH := "res://scenes/online_lobby.tscn"
const ONLINE_FREE_LOBBY_SCENE_PATH := "res://scenes/online_free_lobby.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/race_select_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const OnlineSession := preload("res://scripts/online/online_session.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const CAMERA_EXPLORATION_SCENE_PATH := "res://scenes/camera_exploration.tscn"
const CARD_GAP := 20
## 絵を、カードの縁から内側へ寄せる幅（選んでいるときの黄色い枠が、絵に隠れないように）。
const CARD_INSET := 4.0
## カードの並び（2列×2段）と、上下の帯からのすき間。
const CARD_COLUMNS := 2
const CARD_TOP_GAP := 24.0
const CARD_BOTTOM_GAP := 20.0
## カード1枚ぶん：ボタンの名前、題、札（文字・色）、ひとこと、絵（ファイルと、切り出す場所）。
const MODES := [
	{"name": "OfflineFreeRaceButton", "title": "オフラインフリー対戦", "tag": "ひとりで", "tag_color": Color(0.32, 0.86, 0.5),
		"text": "CPUと走ります。距離も相手も、自分で決められます。",
		"image": "res://assets/ui/race_select_background.jpg", "region": Rect2(1150, 1000, 2690, 1035)},
	{"name": "OnlineFreeRaceButton", "title": "オンラインフリー対戦", "tag": "オンライン", "tag_color": Color(1.0, 0.8, 0.28),
		"text": "ロビーでエントリーして、みんなと走ります。大会もあります。",
		"image": "res://assets/ui/trainer_background.jpg", "region": Rect2(300, 150, 2940, 1100)},
	{"name": "FriendRaceButton", "title": "ともだち対戦", "tag": "オンライン", "tag_color": Color(1.0, 0.8, 0.28),
		"text": "部屋を作って、ともだちと走ります。",
		"image": "res://assets/ui/title_screen_background.png", "region": Rect2(80, 410, 1432, 531)},
	{"name": "CameraExplorationButton", "title": "カメラで探検", "tag": "おまけ", "tag_color": Color(0.74, 0.8, 0.9),
		"text": "レース場を、自由に飛び回って見られます。",
		"image": "res://assets/ui/race_select_background.jpg", "region": Rect2(0, 60, 3840, 1430)},
]

var _offline_button: Button
var _online_button: Button
var _friend_button: Button
var _back_button: Button


func _ready() -> void:
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "ゲームモード選択", TrainerProfile.trainer_name())
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", CARD_GAP)
	grid.add_theme_constant_override("v_separation", CARD_GAP)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = MenuStyle.SCREEN_MARGIN
	grid.offset_right = -MenuStyle.SCREEN_MARGIN
	grid.offset_top = MenuStyle.BAR_HEIGHT + CARD_TOP_GAP
	grid.offset_bottom = -MenuStyle.GUIDE_HEIGHT - CARD_BOTTOM_GAP
	add_child(grid)
	var cards: Array[Button] = []
	for mode: Dictionary in MODES:
		var card := _mode_card(mode)
		UIAudio.bind_button_sound(card, "confirmation")
		grid.add_child(card)
		cards.append(card)
	_offline_button = cards[0]
	_online_button = cards[1]
	_friend_button = cards[2]
	var exploration := cards[3]
	_offline_button.pressed.connect(go_to_race_select)
	_online_button.pressed.connect(go_to_online_free_lobby)
	_friend_button.pressed.connect(go_to_online_lobby)
	exploration.pressed.connect(go_to_camera_exploration)
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	_back_button = MenuStyle.guide_button(guide, "B", "戻る")
	_back_button.name = "BackButton"
	_back_button.pressed.connect(go_to_menu)
	UIAudio.bind_button_sound(_back_button, "back")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_child(spacer)
	var quit_button := MenuStyle.button("ゲームを終了", 15, MenuStyle.COLOR_BUTTON_QUIET)
	quit_button.name = "QuitButton"
	quit_button.add_theme_stylebox_override("normal", MenuStyle.box(MenuStyle.COLOR_BUTTON_QUIET, 14, 16.0, 2.0))
	quit_button.add_theme_stylebox_override("hover", MenuStyle.box(MenuStyle.COLOR_BUTTON_QUIET.lightened(0.12), 14, 16.0, 2.0))
	quit_button.add_theme_stylebox_override("focus", MenuStyle.focus_box(14))
	quit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quit_button.pressed.connect(func(): get_tree().quit())
	UIAudio.bind_button_sound(quit_button, "confirmation")
	guide.add_child(quit_button)
	_link_focus(cards, quit_button)
	_offline_button.grab_focus()


## 絵つきのカード：絵を全面に敷き、下を暗くして、札・題・ひとことを乗せる。
func _mode_card(mode: Dictionary) -> Button:
	var card := Button.new()
	card.name = str(mode["name"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	MenuStyle.style_card_button(card)
	# 絵は、角を丸めた不透明の板の中に入れて、はみ出しを切る（カードの地は半透明なので、カードでは切らない）。
	var frame := Panel.new()
	frame.name = "Image"
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_BAR, 11, 0.0, 0.0))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inset(frame, CARD_INSET)
	card.add_child(frame)
	var image := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(str(mode["image"]))
	atlas.region = mode["region"]
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(image)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(MenuStyle.COLOR_BAR, 0.0))
	gradient.set_color(1, Color(MenuStyle.COLOR_BAR, 0.95))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.0, 0.3)
	shade_texture.fill_to = Vector2(0.0, 1.0)
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(shade)
	var tag := MenuStyle.tag(str(mode["tag"]), mode["tag_color"])
	tag.name = "Tag"
	tag.position = Vector2(14.0, 14.0)
	card.add_child(tag)
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 2)
	text_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	text_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	text_box.offset_left = 18.0
	text_box.offset_right = -18.0
	text_box.offset_bottom = -14.0
	card.add_child(text_box)
	var title := MenuStyle.bold_label(str(mode["title"]), 32, MenuStyle.COLOR_TEXT, 8)
	title.name = "Title"
	text_box.add_child(title)
	var text := MenuStyle.label(str(mode["text"]), 16, MenuStyle.COLOR_BAR_DIM)
	text.name = "Text"
	text.add_theme_constant_override("outline_size", 4)
	text_box.add_child(text)
	return card


func _inset(control: Control, margin: float) -> void:
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


## カードは上下左右で行き来する。下の段から下で「ゲームを終了」、そこから上で右下のカードへ。
func _link_focus(cards: Array[Button], quit_button: Button) -> void:
	for index in cards.size():
		var card := cards[index]
		var column := index % CARD_COLUMNS
		var left := cards[index - 1] if column > 0 else card
		var right := cards[index + 1] if column < CARD_COLUMNS - 1 else card
		var up := cards[index - CARD_COLUMNS] if index >= CARD_COLUMNS else card
		var down: Control = cards[index + CARD_COLUMNS] if index + CARD_COLUMNS < cards.size() else quit_button
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
		card.focus_neighbor_top = card.get_path_to(up)
		card.focus_neighbor_bottom = card.get_path_to(down)
	quit_button.focus_neighbor_top = quit_button.get_path_to(cards.back())
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(quit_button)
	quit_button.focus_neighbor_left = quit_button.get_path_to(quit_button)
	quit_button.focus_neighbor_right = quit_button.get_path_to(quit_button)


## オンラインフリー対戦：共通のロビーへ。
func go_to_online_free_lobby() -> void:
	get_tree().change_scene_to_file(ONLINE_FREE_LOBBY_SCENE_PATH)


## ともだち対戦：部屋の画面へ（今は、合言葉の部屋に集まる所まで）。
func go_to_online_lobby() -> void:
	OnlineSession.free_mode = false
	get_tree().change_scene_to_file(ONLINE_LOBBY_SCENE_PATH)


func go_to_camera_exploration() -> void:
	get_tree().change_scene_to_file(CAMERA_EXPLORATION_SCENE_PATH)


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_SCENE_PATH)


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_to_menu()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
