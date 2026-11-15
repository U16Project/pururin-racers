extends PanelContainer
## 画面の下の帯。カメラで見ている子（自分も含む）の属性のマーク・名前・トレーナー・能力・ダッシュとブーストの残りを1段で出す。
## 能力は、走る前の値を白で、レース中の補正（順位と脚質）の差を色付きで添える（上がり＝青、下がり＝赤）。
## 両端に、見る子を替えるボタン（L1・R1、パッドが無ければ「,」「.」）を出す。

const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const StatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const STAT_LABELS := PururinDetail.STAT_LABELS
const MARK_SIZE := 20.0
const FONT_SIZE := 18
const SMALL_FONT_SIZE := 13
const BOTTOM_MARGIN := 14.0
const COLOR_TEXT := Color(1, 1, 1, 0.95)
const COLOR_DIM := Color(1, 1, 1, 0.55)
const COLOR_KEY := Color(0.55, 0.85, 1.0, 0.9)

var _text := RichTextLabel.new()
var _left := Label.new()
var _mark := Control.new()
var _attribute_id := ""
var _last := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.62)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_color_override("default_color", COLOR_TEXT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_left.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	_left.add_theme_color_override("font_color", COLOR_KEY)
	_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_left)
	_mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	row.add_child(_mark)
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## 見ている子の値で、帯の文を作り直す（同じ文なら何もしない）。place・field_size は、今の順位と頭数。
## 能力の補正は、ここで計算する（オンラインでは、走者が届いた値を映すだけで、補正を計算し直さないため）。
func show_runner(runner: Node3D, place: int, field_size: int, race_distance_m: float) -> void:
	var pad := Input.get_connected_joypads().size() > 0
	var progress_ratio := float(runner.call("get_race_progress")) / race_distance_m if race_distance_m > 0.0 else 0.0
	var text := bar_text(runner, pad, place, field_size, progress_ratio)
	if text == _last:
		return
	_left.text = "◀ L1" if pad else "◀ ,"
	_last = text
	_attribute_id = str((runner.get("_pururin") as Dictionary).get("attribute", ""))
	_mark.visible = not _attribute_id.is_empty()
	_mark.queue_redraw()
	_text.text = text
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, get_viewport_rect().size.y - size.y - BOTTOM_MARGIN)


static func bar_text(runner: Node3D, pad: bool, place: int, field_size: int, progress_ratio: float) -> String:
	var pururin: Dictionary = runner.get("_pururin")
	var stats := {}
	var before := {}
	if pururin.has("attribute") and pururin.has("allocation"):
		before = PururinStatsMath.pre_race_stats(str(pururin["attribute"]), pururin["allocation"])
		stats = PururinStatsMath.effective_stats(str(pururin["attribute"]), pururin["allocation"], str(pururin.get("running_style", "")), place, progress_ratio, field_size)
	var parts := PackedStringArray()
	for stat_id: String in STAT_LABELS:
		if stats.has(stat_id):
			parts.append(_small(STAT_LABELS[stat_id]) + stat_text(int(stats[stat_id]), int(before.get(stat_id, stats[stat_id]))))
	var separator := "  [color=#%s]│[/color]  " % COLOR_DIM.to_html()
	return "".join(PackedStringArray([
		"[b]%s[/b]" % str(runner.get("display_name")), " ",
		_small("（%s）" % str(pururin.get("trainer_name", ""))),
		separator, "  ".join(parts),
		separator, _small("ダッシュ"), "[b]∞[/b]  ", _small("ブースト"), "[b]%d[/b]" % int(runner.call("get_boost_uses_left")),
		"   ", _key("R1 ▶" if pad else ". ▶"),
	]))


## 走る前の値を白で出し、レース中の補正があれば、その差を色付きで添える（上がり＝青、下がり＝赤）。
static func stat_text(value: int, before: int) -> String:
	var diff := value - before
	if diff == 0:
		return "[b]%d[/b]" % before
	return "[b]%d[/b][color=#%s][b](%+d)[/b][/color]" % [before, RaceHud.style_state_color(diff).to_html(), diff]


func _draw_mark() -> void:
	if _attribute_id.is_empty():
		return
	var color := Color.from_string(str(StatsConfig.values()["attributes"][_attribute_id]["color"]), Color.WHITE)
	PururinDetail.draw_attribute_mark(_mark, _mark.size * 0.5, MARK_SIZE, _attribute_id, color)


static func _small(label: String) -> String:
	return "[font_size=%d][color=#%s]%s[/color][/font_size] " % [SMALL_FONT_SIZE, COLOR_DIM.to_html(), label]


static func _key(label: String) -> String:
	return "[font_size=%d][color=#%s]%s[/color][/font_size]" % [SMALL_FONT_SIZE, COLOR_KEY.to_html(), label]
