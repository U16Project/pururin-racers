extends Control
## 入力機器ごとに切り替えて読むレース操作ページ。

signal closed

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const DIAGRAM_PATHS := [
	"res://assets/ui/race_controls_guide.png",
	"res://assets/ui/race_controls_keyboard.png",
	"res://assets/ui/race_controls_touch.png",
]
const DEVICE_NAMES := ["ゲームパッド", "キーボード", "マウス・タッチ"]
const PANEL_MAX_SIZE := Vector2(1000.0, 780.0)
const VIEWPORT_MARGIN := 14.0
const DEVICE_ROWS := [
	[
		"ライン左右 ｜ 左スティック／十字キー左右を倒す",
		"ノッチ上下 ｜ 十字キー上下（長押しで連続変更）",
		"ブレーキ ｜ A または LT を押し続ける",
		"ダッシュ ｜ B を1回押す",
		"ブースト ｜ X を1回押す",
		"視点切替 ｜ Y を1回押す",
		"見回す ｜ 右スティックを倒す。離すと元の向きへ",
		"視点を戻す ｜ 右スティックを押し込む",
		"一時停止 ｜ START",
	],
	[
		"ライン左右 ｜ ← → を押し続ける",
		"ノッチ上下 ｜ ↑ ↓（長押しで連続変更）",
		"ブレーキ ｜ X または Space を押し続ける",
		"ダッシュ ｜ C を1回押す",
		"ブースト ｜ Z を1回押す",
		"視点切替 ｜ S を1回押す",
		"視点を戻す ｜ R",
		"一時停止 ｜ Esc",
		"画面ボタン ｜ F2で表示・非表示",
		"詳細表示 ｜ F3",
	],
	[
		"PCで始める ｜ F2を押して画面ボタンを表示",
		"スマホで始める ｜ 画面ボタンは最初から表示",
		"ライン左右 ｜ ◀ ▶ を押し続ける",
		"ノッチ上下 ｜ ▲ ▼（長押しで連続変更）",
		"ブレーキ ｜ 右下の「ブレーキ」を押し続ける",
		"ダッシュ ｜ DASHを1回押す",
		"ブースト ｜ BOOSTを1回押す",
		"視点切替 ｜ 「視点」を1回押す",
		"一時停止 ｜ 右上の ≡ を1回押す",
		"マウス ｜ 左クリック。長押しの操作はボタンを離さず保持",
		"タッチ ｜ 指で押す。ラインは左右へ指を滑らせても変更可能",
	],
]

var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _diagram: TextureRect
var _close_button: Button
var _tabs: Array[Button] = []
var _device_index := 0
var _is_closing := false


func _ready() -> void:
	name = "ControlGuideOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build_overlay()
	get_viewport().size_changed.connect(_queue_fit_panel)
	_fit_panel()
	select_device(0)
	_tabs[0].grab_focus()


func _build_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.055, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "GuidePanel"
	_panel.add_theme_stylebox_override("panel", MenuStyle.box(Color(0.05, 0.08, 0.14, 1.0), 18, 20.0, 16.0))
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := MenuStyle.label("レース操作ガイド", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_close_button = MenuStyle.button("閉じる", 18, MenuStyle.COLOR_BUTTON_QUIET)
	_close_button.name = "GuideCloseButton"
	_close_button.custom_minimum_size = Vector2(100.0, 44.0)
	_close_button.pressed.connect(close_guide)
	UIAudio.bind_button_sound(_close_button, "back")
	heading.add_child(_close_button)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for index in DEVICE_NAMES.size():
		var button := MenuStyle.button(DEVICE_NAMES[index], 18)
		button.name = "DeviceTab%d" % index
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44.0
		button.pressed.connect(select_device.bind(index))
		tabs.add_child(button)
		_tabs.append(button)
	_scroll = ScrollContainer.new()
	_scroll.name = "GuideScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)
	var footer := MenuStyle.label("← →：機器を切替   ↑ ↓：スクロール   B／C／Esc：閉じる", 18, MenuStyle.COLOR_DIM)
	footer.name = "GuideFooter"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)


func select_device(index: int) -> void:
	_device_index = clampi(index, 0, DEVICE_NAMES.size() - 1)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for tab_index in _tabs.size():
		MenuStyle.style_button(_tabs[tab_index], 18, MenuStyle.COLOR_BUTTON_ON if tab_index == _device_index else MenuStyle.COLOR_BUTTON_QUIET)
	_add_intro([
		"左右で走る位置、上下で走る力（ノッチ0〜6）を調整します。",
		"心拍と残スタミナを見ながら加減しましょう。",
	])
	_diagram = TextureRect.new()
	_diagram.name = "GuideDiagram"
	_diagram.custom_minimum_size.y = 330.0
	_diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_diagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_diagram.texture = load(DIAGRAM_PATHS[_device_index]) as Texture2D
	_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_diagram)
	_add_section(DEVICE_NAMES[_device_index] + "の操作", DEVICE_ROWS[_device_index])
	_add_section("操作盤を見る", [
		"ハート：心拍。200を超える走りが続くと、走る力が落ちていきます。",
		"速さ・ノッチ：今の速度と指示している段階。体力：残スタミナ。",
		"ノッチは希望速度ではなく、走る力の段階です。",
		"空気抵抗の軽減：前のぷるりんから受けるドラフトの効果。",
		"ダッシュ・ブースト：使える状態を確認してから仕掛けましょう。",
	])
	_add_section("オンライン対戦", [
		"操作はオフラインと共通です。",
		"一時停止メニューやこのガイドを開いても、オンラインのレースは進みます。",
	])
	_scroll.scroll_vertical = 0
	_queue_fit_panel()


func _add_section(heading_text: String, rows: Array) -> void:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", MenuStyle.box(Color(0.10, 0.14, 0.22), 12, 14.0, 12.0))
	_content.add_child(section)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	section.add_child(column)
	column.add_child(MenuStyle.label(heading_text, 21))
	for row_text in rows:
		var row := MenuStyle.label(str(row_text), 18, MenuStyle.COLOR_DIM)
		row.add_theme_constant_override("outline_size", 1)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(row)


func _add_intro(rows: Array[String]) -> void:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", MenuStyle.box(Color(0.10, 0.14, 0.22), 10, 12.0, 6.0))
	_content.add_child(section)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	section.add_child(column)
	for row_text: String in rows:
		var row := MenuStyle.label(row_text, 16, MenuStyle.COLOR_DIM)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(row)


func _fit_panel() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(minf(PANEL_MAX_SIZE.x, maxf(240.0, viewport_size.x - VIEWPORT_MARGIN * 2.0)), minf(PANEL_MAX_SIZE.y, maxf(240.0, viewport_size.y - VIEWPORT_MARGIN * 2.0)))
	_panel.position = (viewport_size - panel_size) * 0.5
	_panel.size = panel_size


func _queue_fit_panel() -> void:
	call_deferred("_fit_panel")


func _input(event: InputEvent) -> void:
	if RaceControllerInput.is_cancel_pressed(event) or event.is_action_pressed("ui_cancel"):
		UIAudio.play_back()
		close_guide()
		get_viewport().set_input_as_handled()
		return
	var direction := 0
	var scroll_direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_LEFT:
			direction = -1
		elif event.physical_keycode == KEY_RIGHT:
			direction = 1
		elif event.physical_keycode == KEY_DOWN or event.physical_keycode == KEY_PAGEDOWN:
			scroll_direction = 1
		elif event.physical_keycode == KEY_UP or event.physical_keycode == KEY_PAGEUP:
			scroll_direction = -1
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			direction = -1
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			direction = 1
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			scroll_direction = 1
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			scroll_direction = -1
	if direction != 0:
		select_device(posmod(_device_index + direction, DEVICE_NAMES.size()))
		_tabs[_device_index].grab_focus()
	if scroll_direction != 0:
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + scroll_direction * 90)
	if direction != 0 or scroll_direction != 0:
		get_viewport().set_input_as_handled()


func close_guide() -> void:
	if _is_closing:
		return
	_is_closing = true
	closed.emit()
	queue_free()
