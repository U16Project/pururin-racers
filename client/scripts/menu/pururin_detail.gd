extends Control

## 「強制選択」ボタンが押された。
signal force_requested
## キャラ選択の右側。今見ているスロットの個体を、大きい画像・名前・属性・脚質と、能力のバー8本で出す。

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const Portrait := preload("res://scripts/menu/pururin_portrait.gd")
const FitLabel := preload("res://scripts/menu/fit_label.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const EMPTY_TEXT := "ー未選択ー"
const EMPTY_HINT_TEXT := "◀ キャラを選択してください ▶"
const FORCE_TEXT := "強制選択"
const FORCE_LOCKED_TEXT := "施錠中"
const PORTRAIT_SIZE := 148.0
const NAME_FONT_SIZE := 34
## パネルの枠と、中身までの余白。
const PANEL_MARGIN := 16.0
const COLOR_PANEL_BACK := Color(1.0, 1.0, 1.0, 0.05)
const COLOR_PANEL_BORDER := Color(1.0, 1.0, 1.0, 0.3)
## 選択済み（他のスロットで使っている）のキャラを見ているときの、背景と枠。
const COLOR_PANEL_BACK_TAKEN := Color(1.0, 0.6, 0.2, 0.1)
const COLOR_PANEL_BORDER_TAKEN := Color(1.0, 0.6, 0.2, 0.75)
const MARK_SIZE := 28.0
const CHEVRON_SCALE := 1.0
## 属性・脚質の行の文字の大きさ。
const INFO_FONT_SIZE := 20
## 能力の表示名（画面用の短い名前）。
const STAT_LABELS := {
	"top_speed": "最高速",
	"acceleration": "加速",
	"stamina": "スタミナ",
	"cardio": "心肺",
	"aero": "空力",
	"pack": "集団",
	"contact_resistance": "接触",
	"handling": "操作",
}
const BAR_WIDTH := 26.0
const BAR_TOP := 24.0
const BAR_BOTTOM_MARGIN := 22.0
const BAR_SEGMENT_GAP := 2.0
const COLOR_BAR := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_BAR_TRACK := Color(1.0, 1.0, 1.0, 0.16)
## 配分できない段（属性のボーナスが無い能力の、配分の上限より上）の色と、斜めの線の色。
const COLOR_BAR_LOCKED := Color(0.0, 0.0, 0.0, 0.42)
const COLOR_BAR_LOCKED_LINE := Color(1.0, 1.0, 1.0, 0.14)

var _portrait: Control
var _name_label: Control
var _attribute_row: HBoxContainer
var _attribute_label: Label
var _attribute_mark: Control
var _style_row: HBoxContainer
var _style_chevrons: Control
var _style_label: Control
var _bars: Control
var _preview: Dictionary = {}
var _filled_box: Control
var _empty_box: Control
var _taken_row: Control
var _taken_label: Label
var _force_button: Button
var _force_mark: Control


func _ready() -> void:
	# 未選択のときは、真ん中に「未選択」と、選び方の案内だけを出す。
	var empty_box := VBoxContainer.new()
	empty_box.name = "EmptyBox"
	_fill_inside_panel(empty_box)
	empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_box.add_theme_constant_override("separation", 14)
	add_child(empty_box)
	_empty_box = empty_box
	var empty_label := MenuStyle.label(EMPTY_TEXT, 34)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(empty_label)
	var empty_hint := MenuStyle.label(EMPTY_HINT_TEXT, 20, MenuStyle.COLOR_DIM)
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(empty_hint)
	var column := VBoxContainer.new()
	column.name = "FilledBox"
	_fill_inside_panel(column)
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_filled_box = column
	# 一番上に、名前を横いっぱいの1行で出す（全角9文字が、そのままの大きさで入る）。
	_name_label = FitLabel.new()
	_name_label.name = "NameLabel"
	_name_label.call("setup", NAME_FONT_SIZE)
	column.add_child(_name_label)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	_portrait = Portrait.new()
	_portrait.name = "Portrait"
	# 大きい絵は、体をゆっくり回して、表情も替える。
	_portrait.set("live", true)
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	top.add_child(_portrait)
	# 画像の右に2段：属性（印つき）、脚質（印つき）。
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 10)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(texts)
	_attribute_row = HBoxContainer.new()
	_attribute_row.add_theme_constant_override("separation", 6)
	texts.add_child(_attribute_row)
	_attribute_label = MenuStyle.label("", INFO_FONT_SIZE)
	_attribute_row.add_child(_attribute_label)
	_attribute_mark = Control.new()
	_attribute_mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	_attribute_mark.draw.connect(_draw_attribute_mark)
	_attribute_row.add_child(_attribute_mark)
	_style_row = HBoxContainer.new()
	_style_row.add_theme_constant_override("separation", 4)
	texts.add_child(_style_row)
	_style_row.add_child(MenuStyle.label("脚質：", INFO_FONT_SIZE))
	_style_chevrons = Control.new()
	_style_chevrons.draw.connect(_draw_style_chevrons)
	_style_row.add_child(_style_chevrons)
	# 脚質の名前は、欄に入りきらないときも切らずに、縮めて出す（名前と同じ決まり）。
	_style_label = FitLabel.new()
	_style_label.name = "StyleLabel"
	_style_label.call("setup", INFO_FONT_SIZE)
	_style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_row.add_child(_style_label)
	# 他のスロットで使っている個体を見ているときだけ出す帯。
	var taken_panel := PanelContainer.new()
	taken_panel.name = "TakenRow"
	taken_panel.add_theme_stylebox_override("panel", MenuStyle.box(Color(MenuStyle.COLOR_TAKEN, 0.22), 8, 10.0, 3.0))
	column.add_child(taken_panel)
	_taken_row = taken_panel
	var taken_box := HBoxContainer.new()
	taken_box.add_theme_constant_override("separation", 10)
	taken_panel.add_child(taken_box)
	_taken_label = MenuStyle.label("", 16, MenuStyle.COLOR_TAKEN)
	_taken_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taken_label.clip_text = true
	taken_box.add_child(_taken_label)
	_force_button = MenuStyle.button(FORCE_TEXT, 17, MenuStyle.COLOR_BUTTON)
	_force_button.name = "ForceButton"
	_force_button.custom_minimum_size = Vector2(146.0, 30.0)
	for state in ["normal", "hover", "pressed"]:
		var compact: StyleBoxFlat = _force_button.get_theme_stylebox(state).duplicate()
		compact.content_margin_top = 2.0
		compact.content_margin_bottom = 2.0
		_force_button.add_theme_stylebox_override(state, compact)
	_force_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 押しても、スロットの選択が外れないようにする（外れると、見ているだけの表示が消える）。
	_force_button.focus_mode = Control.FOCUS_NONE
	_force_button.pressed.connect(func() -> void: force_requested.emit())
	_force_mark = MenuStyle.add_mark(_force_button, "Y", 22.0)
	taken_box.add_child(_force_button)
	_bars = Control.new()
	_bars.name = "Bars"
	_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bars.draw.connect(_draw_bars)
	column.add_child(_bars)
	show_pururin("")


## 中身を、パネルの枠の内側（余白を空けた範囲）いっぱいに置く。
func _fill_inside_panel(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = PANEL_MARGIN
	node.offset_top = PANEL_MARGIN
	node.offset_right = -PANEL_MARGIN
	node.offset_bottom = -PANEL_MARGIN


## パネルの背景と枠。選択済みのキャラを見ているときは、色を少し変える。
func _draw() -> void:
	var taken := is_showing_taken()
	var panel := StyleBoxFlat.new()
	panel.bg_color = COLOR_PANEL_BACK_TAKEN if taken else COLOR_PANEL_BACK
	panel.border_color = COLOR_PANEL_BORDER_TAKEN if taken else COLOR_PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))


## 個体の、表示用の情報（名前・属性・脚質・出走前の能力）。一覧に無い個体なら空。
static func preview_for(pururin_id: String) -> Dictionary:
	var pururin := PururinRosterConfig.pururin_by_id(pururin_id)
	if pururin.is_empty():
		return {}
	var definitions := PururinStatsConfig.values()
	var attribute_id := str(pururin["attribute"])
	var style_id := str(pururin["running_style"])
	return {
		"id": str(pururin["id"]),
		"display_name": str(pururin["display_name"]),
		"attribute_id": attribute_id,
		"attribute": str(definitions["attributes"][attribute_id]["label"]),
		"attribute_color": Color.from_string(str(definitions["attributes"][attribute_id]["color"]), Color.WHITE),
		"style_id": style_id,
		"running_style": str(definitions["running_styles"][style_id]["label"]),
		"pre_race_stats": PururinStatsMath.pre_race_stats(attribute_id, pururin["allocation"]),
		"bonus_stats": (definitions["attributes"][attribute_id]["bonus_stats"] as Array).duplicate(),
	}


## 能力のバーの段の数。出走前の値の上限（設定の attribute_stat_max）と同じ。1段が1。
static func bar_segment_count() -> int:
	return int(PururinStatsConfig.values()["attribute_stat_max"])


## バーで、色が付く段の数。
static func bar_filled_segments(value: int) -> int:
	return clampi(value, 0, bar_segment_count())


## 表示する個体を変える。空のIDなら「未選択」。
## taken_by に、使っているスロットの名前（例「5枠」）を渡すと、「選択済み」の帯と強制選択のボタンを出す。
## holder_locked が true（使っているスロットが施錠中）なら、強制選択は押せない。
func show_pururin(pururin_id: String, taken_by: String = "", holder_locked: bool = false) -> void:
	_preview = preview_for(pururin_id) if not pururin_id.is_empty() else {}
	_portrait.call("set_pururin", PururinRosterConfig.pururin_by_id(pururin_id) if not _preview.is_empty() else {})
	_filled_box.visible = not _preview.is_empty()
	_empty_box.visible = _preview.is_empty()
	_taken_row.visible = not taken_by.is_empty() and not _preview.is_empty()
	_taken_label.text = "%sが使用中" % taken_by
	# 使っているスロットが施錠中なら、奪えない。
	_force_button.text = FORCE_LOCKED_TEXT if holder_locked else FORCE_TEXT
	_force_button.disabled = holder_locked
	# 押せないときは、Yのマークも暗くする。
	_force_mark.modulate = Color(0.45, 0.45, 0.5, 0.45) if holder_locked else Color.WHITE
	if not _preview.is_empty():
		_name_label.call("set_text", str(_preview["display_name"]))
		_attribute_label.text = "属性：%s" % _preview["attribute"]
		_style_label.call("set_text", str(_preview["running_style"]))
		_style_chevrons.custom_minimum_size = Vector2(
			RaceHud.STYLE_CHEVRON_STEP * CHEVRON_SCALE * PururinStatsMath.rank_group_count() + 4.0, MARK_SIZE
		)
	_attribute_mark.queue_redraw()
	_style_chevrons.queue_redraw()
	_bars.queue_redraw()
	queue_redraw()


func is_showing_taken() -> bool:
	return _taken_row != null and _taken_row.visible


func shown_pururin_id() -> String:
	return str(_preview["id"]) if not _preview.is_empty() else ""


func _draw_attribute_mark() -> void:
	if _preview.is_empty():
		return
	draw_attribute_mark(_attribute_mark, _attribute_mark.size * 0.5, MARK_SIZE, str(_preview["attribute_id"]), _preview["attribute_color"])


## 属性の印（地＝岩、水＝しずく、火＝炎、風＝流れる線）を、指定の描画先に描く。色は、設定の属性の色。
static func draw_attribute_mark(canvas: CanvasItem, c: Vector2, mark_size: float, attribute_id: String, color: Color) -> void:
	var r := mark_size * 0.44
	match attribute_id:
		"earth":
			var rock := PackedVector2Array()
			for point: Vector2 in [Vector2(-0.95, 0.75), Vector2(-0.7, -0.2), Vector2(-0.15, -0.85), Vector2(0.55, -0.6), Vector2(1.0, 0.1), Vector2(0.8, 0.75)]:
				rock.append(c + point * r)
			_fill_with_outline(canvas, rock, color)
			canvas.draw_line(c + Vector2(-0.15, -0.85) * r, c + Vector2(0.1, 0.1) * r, color.darkened(0.35), 1.5, true)
			canvas.draw_line(c + Vector2(0.1, 0.1) * r, c + Vector2(0.8, 0.75) * r, color.darkened(0.35), 1.5, true)
		"water":
			var drop := PackedVector2Array([c + Vector2(0.0, -1.0) * r])
			for index in 13:
				var angle := lerpf(-0.35, PI + 0.35, float(index) / 12.0)
				drop.append(c + Vector2(0.0, 0.3) * r + Vector2(cos(angle), sin(angle)) * r * 0.68)
			_fill_with_outline(canvas, drop, color)
			canvas.draw_circle(c + Vector2(-0.25, 0.3) * r, r * 0.16, Color(1.0, 1.0, 1.0, 0.7))
		"fire":
			var flame := PackedVector2Array()
			for point: Vector2 in [Vector2(0.0, 0.95), Vector2(-0.6, 0.8), Vector2(-0.85, 0.25), Vector2(-0.55, -0.35), Vector2(-0.3, 0.0), Vector2(0.05, -1.0), Vector2(0.45, -0.3), Vector2(0.65, -0.55), Vector2(0.85, 0.25), Vector2(0.6, 0.8)]:
				flame.append(c + point * r)
			_fill_with_outline(canvas, flame, color)
			canvas.draw_circle(c + Vector2(0.0, 0.42) * r, r * 0.3, Color(1.0, 0.85, 0.4, 0.9))
		"wind":
			for row in 3:
				var y := (float(row) - 1.0) * r * 0.6
				var length := r * (1.0 if row == 1 else 0.7)
				var line := PackedVector2Array()
				for index in 9:
					var t := float(index) / 8.0
					line.append(c + Vector2(lerpf(-length, length, t), y + sin(t * PI) * -r * 0.22))
				canvas.draw_polyline(line, MenuStyle.COLOR_OUTLINE, 5.0, true)
				canvas.draw_polyline(line, color, 2.6, true)
		_:
			push_error("属性の印がありません: %s" % attribute_id)


static func _fill_with_outline(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, MenuStyle.COLOR_OUTLINE, 4.0, true)
	canvas.draw_colored_polygon(points, color)


## 脚質の印。レース中の操作盤と同じ「〈」で、得意な順位の組だけ光らせる。
func _draw_style_chevrons() -> void:
	if _preview.is_empty():
		return
	RaceHud.draw_style_chevrons(
		_style_chevrons,
		Vector2(2.0, _style_chevrons.size.y * 0.5),
		RaceHud.COLOR_STYLE_MATCH,
		PururinStatsMath.rank_group_count(),
		PururinStatsMath.style_rank_group_index(str(_preview["style_id"])),
		CHEVRON_SCALE
	)


## 能力のバー8本を、横に並べて描く。1本は、上に数字、中に段つきの縦のバー、下に項目名。
## バーの1段の種類。segment は、下から数えた段（0から）。
## bonus＝属性のボーナスのぶん（下から、ボーナスの数だけ。属性の色で塗る）、filled＝配分したぶん、
## empty＝空き、locked＝配分できない段（ボーナスが無い能力の、配分の上限より上）。
static func bar_segment_kind(has_bonus: bool, filled: int, segment: int) -> String:
	var config := PururinStatsConfig.values()
	if has_bonus:
		if segment < mini(int(config["attribute_bonus_per_stat"]), filled):
			return "bonus"
	elif segment >= int(config["allocation_max"]):
		return "locked"
	return "filled" if segment < filled else "empty"


func _draw_bars() -> void:
	if _preview.is_empty():
		return
	var font := get_theme_default_font()
	var stats: Dictionary = _preview["pre_race_stats"]
	var stat_ids: Array = PururinStatsConfig.values()["stat_ids"]
	var bonus_stats: Array = _preview["bonus_stats"]
	var column_width := _bars.size.x / float(stat_ids.size())
	var bar_height := maxf(_bars.size.y - BAR_TOP - BAR_BOTTOM_MARGIN, 0.0)
	var segments := bar_segment_count()
	var segment_height := (bar_height - BAR_SEGMENT_GAP * float(segments - 1)) / float(segments)
	for index in stat_ids.size():
		var stat_id := str(stat_ids[index])
		var value := int(stats[stat_id])
		var center_x := column_width * (float(index) + 0.5)
		var number := "%d" % value
		var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		_draw_outlined(font, number, Vector2(center_x - number_width * 0.5, 18.0), 19, MenuStyle.COLOR_TEXT)
		var filled := bar_filled_segments(value)
		for segment in segments:
			# 下から数えて、値の数だけ色を付ける。
			var top := BAR_TOP + bar_height - segment_height * float(segment + 1) - BAR_SEGMENT_GAP * float(segment)
			var rect := Rect2(Vector2(center_x - BAR_WIDTH * 0.5, top), Vector2(BAR_WIDTH, segment_height))
			match bar_segment_kind(stat_id in bonus_stats, filled, segment):
				"bonus":
					_bars.draw_rect(rect, _preview["attribute_color"])
				"filled":
					_bars.draw_rect(rect, COLOR_BAR)
				"locked":
					_bars.draw_rect(rect, COLOR_BAR_LOCKED)
					_bars.draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position + Vector2(rect.size.x, 0.0), COLOR_BAR_LOCKED_LINE, 1.0)
				_:
					_bars.draw_rect(rect, COLOR_BAR_TRACK)
		var label := str(STAT_LABELS[stat_id])
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_draw_outlined(font, label, Vector2(center_x - label_width * 0.5, _bars.size.y - 4.0), 13, MenuStyle.COLOR_DIM)


func _draw_outlined(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	_bars.draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, MenuStyle.COLOR_OUTLINE)
	_bars.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
