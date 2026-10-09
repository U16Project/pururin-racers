extends Control
## ローカルレースの常時表示HUD。数値の羅列ではなく、走りながら読める4つ
## （速度・ノッチ・心拍・体力）を画面左下に大きく描く。詳細な診断はデバッグ表示（F3）へ分ける。
## 値は update_state() で受け取り、計算はここでは行わない（表示用の割合と色だけ）。

const ButtonMark := preload("res://scripts/menu/button_mark.gd")
const FitText := preload("res://scripts/presentation/fit_text.gd")
const PANEL_WIDTH := 440.0
## BOOST・DASH の文字の左に付ける、ボタンのマークの大きさ。
const DRIVE_ACTION_MARK_SIZE := 13.0
## 操作盤は画面の左下（順位表の下）。画面の左端からの余白。
const PANEL_LEFT_MARGIN := 46.0
const GAUGE_BAR_HEIGHT := 110.0
## 体力バーのうち、下から負債（マイナス）に使う割合。負債の全体（0〜限度）をこの長さで見せるので、プラス側より縮尺が小さい（減りが遅く見える）。
const FUEL_DEBT_ZONE_RATIO := 0.25
const PANEL_BODY_HEIGHT := 196.0
## 進行バー（文字の行とバー）の帯の高さ。
const PANEL_TOP_STRIP := 52.0
const PANEL_HEIGHT := PANEL_BODY_HEIGHT + PANEL_TOP_STRIP
const PROGRESS_BAR_HEIGHT := 10.0
const PROGRESS_SIDE_MARGIN := 24.0
## 操作盤の左上の角の上に付ける、名前の札。全角9文字が、そのままの大きさで入る。
const NAME_TAB_HEIGHT := 24.0
const NAME_TAB_FONT_SIZE := 17
const NAME_TAB_PADDING := 14.0
const NAME_TAB_MAX_TEXT_WIDTH := 170.0
## 名札の、トレーナー名（名前の右に、小さく出す）。
const NAME_TAB_TRAINER_FONT_SIZE := 13
const NAME_TAB_TRAINER_GAP := 10.0
const NAME_TAB_TRAINER_MAX_WIDTH := 120.0
## 脚質の印「〈」の間隔。
const STYLE_CHEVRON_STEP := 10.0
## 左上の順位表。行の高さは、確定した行も、まだの行も同じ。
## 左上の、自分の順位・残り距離・タイムの左上の位置と、その高さ。
const RACE_INFO_ORIGIN := Vector2(54.0, 34.0)
const RACE_INFO_HEIGHT := 64.0
const STANDINGS_LEFT := 54.0
const STANDINGS_ROW_HEIGHT := 26.0
## 順位表の、満員のときの行の数。表の位置は、この行の数で決める（人数が少なくても、上の位置は同じ）。
const STANDINGS_FULL_ROWS := 8
const STANDINGS_WIDTH := 432.0
const STANDINGS_TIME_X := 368.0
const STANDINGS_NAME_X := 50.0
const STANDINGS_NAME_WIDTH := 120.0
const STANDINGS_STYLE_X := 178.0
const STANDINGS_HEART_X := 224.0
const STANDINGS_FUEL_X := 278.0
const STANDINGS_BATTERY_SIZE := Vector2(36.0, 12.0)
const STANDINGS_FONT_SIZE := 16
const STANDINGS_CONFIRMED_FONT_SIZE := 20
const STANDINGS_VALUE_FONT_SIZE := 14
## 画面下端からの余白。
const PANEL_BOTTOM_MARGIN := 40.0
const NOTCH_COUNT := 7
## 空気抵抗の減りのゲージ。30段で、満タン＝空気抵抗が60%減る（1段＝2%）。
const AIR_GAUGE_SEGMENTS := 30
const AIR_GAUGE_FULL := 0.60

const COLOR_PANEL := Color(0.05, 0.08, 0.14, 0.72)
const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.78, 1.0)
const COLOR_TRACK := Color(1.0, 1.0, 1.0, 0.16)
const COLOR_OK := Color(0.36, 0.86, 0.52, 1.0)
const COLOR_WARN := Color(1.0, 0.76, 0.25, 1.0)
const COLOR_DANGER := Color(1.0, 0.32, 0.28, 1.0)
const COLOR_FUEL_FULL := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_FUEL_LOW := Color(1.0, 0.55, 0.2, 1.0)
const COLOR_DEBT_DEEP := Color(0.72, 0.04, 0.06, 1.0)
const COLOR_PROGRESS := Color(0.3, 0.88, 1.0, 1.0)
## 脚質と順位の関係の色。得意な順位にいる（補正がプラス）と青、普通は白、離れている（マイナス）と赤。
const COLOR_STYLE_MATCH := Color(0.35, 0.72, 1.0, 1.0)
const COLOR_STYLE_FAR := Color(1.0, 0.36, 0.32, 1.0)
const COLOR_GOLD := Color(1.0, 0.82, 0.22, 1.0)
const COLOR_SILVER := Color(0.82, 0.86, 0.92, 1.0)
const COLOR_BRONZE := Color(0.84, 0.54, 0.3, 1.0)
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const COLOR_BOOST := Color(1.0, 0.55, 0.2, 1.0)
const COLOR_COOL := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_AERO := Color(0.36, 0.86, 0.52, 1.0)

var _state := {
	"place": 0,
	"field_size": 0,
	"remaining_m": 0.0,
	"race_distance_m": 0.0,
	"player_name": "",
	"trainer_name": "",
	"style_group_index": -1,
	"style_group_count": 0,
	"style_rank_bonus": 0,
	"dash_ratio": 0.0,
	"boost_ratio": 0.0,
	"boost_points": 0.0,
	"boost_uses_left": 0,
	"boost_max_uses": 0,
	"runners": [],
	"standings": [],
	"time_text": "",
	"speed_kmh": 0.0,
	"notch": 0,
	"notch_max": 6,
	"braking": false,
	"fuel_ratio": 1.0,
	"heart_bpm": 100.0,
	"heart_min_bpm": 100.0,
	"heart_normal_max_bpm": 200.0,
	"heart_max_bpm": 230.0,
	"air_green": 0.0,
	"air_blue": 0.0,
	"countdown": false,
}
var _blink := 0.0
## 確定した行に使う太字。
var _bold_font: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.0)
	if heart_is_overheated(_state) or fuel_is_in_debt(_state) or bool(_state["braking"]):
		queue_redraw()


func update_state(values: Dictionary) -> void:
	for key in values:
		_state[key] = values[key]
	queue_redraw()


## 脚質と今の順位の関係の色（順位の補正がプラスなら青、0なら白、マイナスなら赤）。
static func style_state_color(rank_bonus: int) -> Color:
	if rank_bonus > 0:
		return COLOR_STYLE_MATCH
	if rank_bonus < 0:
		return COLOR_STYLE_FAR
	return COLOR_TEXT


## 順位表のうち、順位が確定した（ゴールした）行の数。確定した行は、上から続けて並ぶ。
static func confirmed_count(standings: Array) -> int:
	var count := 0
	for row in standings:
		if not bool(row["finished"]):
			break
		count += 1
	return count


## 順位表のいちばん上の縦の位置。row_count 行の表が、上の項目（順位・残り距離・タイム）と操作盤の、ちょうど中間に来る位置。
static func standings_top(screen_height: float, row_count: int) -> float:
	var info_bottom := RACE_INFO_ORIGIN.y + RACE_INFO_HEIGHT
	var panel_top := screen_height - PANEL_BOTTOM_MARGIN - PANEL_HEIGHT
	return (info_bottom + panel_top - row_count * STANDINGS_ROW_HEIGHT) * 0.5


## 順位表に出すゴールタイム（分:秒:100分の1秒）。
static func standings_time_text(seconds: float) -> String:
	var total_centiseconds := int(floorf(maxf(seconds, 0.0) * 100.0 + 0.0001))
	return "%d:%02d:%02d" % [total_centiseconds / 6000, (total_centiseconds / 100) % 60, total_centiseconds % 100]


## 進行バー上の位置（0〜1）。
static func progress_ratio(progress_m: float, distance_m: float) -> float:
	if distance_m <= 0.0:
		return 0.0
	return clampf(progress_m / distance_m, 0.0, 1.0)


## 燃料バーのプラス側の表示割合（0〜1）。
static func fuel_fill_ratio(fuel_ratio: float) -> float:
	return clampf(fuel_ratio, 0.0, 1.0)


## 燃料バーのマイナス側（負債）の表示割合（0〜1。負債の限度で1）。
static func fuel_debt_ratio(fuel_ratio: float) -> float:
	return clampf(-fuel_ratio, 0.0, 1.0)


static func fuel_is_in_debt(state: Dictionary) -> bool:
	return float(state.get("fuel_ratio", 1.0)) < 0.0


## 体力バーの色の段階（体力の割合, 色）。満タンの青から、0の赤、負債の濃い赤へ、なめらかにつなぐ。
## 負債の限度（-1）は、バーの下端の濃い赤。
static func fuel_gradient_stops() -> Array:
	return [
		[1.0, COLOR_FUEL_FULL],
		[0.65, COLOR_OK],
		[0.35, COLOR_WARN],
		[0.12, COLOR_FUEL_LOW],
		[0.0, COLOR_DANGER],
		[-1.0, COLOR_DEBT_DEEP],
	]


## その体力の割合での色。バーの位置に対応するなめらかな色。範囲の外は両端の色。
static func fuel_color(fuel_ratio: float) -> Color:
	var stops := fuel_gradient_stops()
	if fuel_ratio >= float(stops[0][0]):
		return stops[0][1]
	for index in stops.size() - 1:
		var upper: Array = stops[index]
		var lower: Array = stops[index + 1]
		if fuel_ratio >= float(lower[0]):
			var span := float(upper[0]) - float(lower[0])
			var t := (float(upper[0]) - fuel_ratio) / span
			return (upper[1] as Color).lerp(lower[1], t)
	return stops[stops.size() - 1][1]


## 心拍バーの表示割合（最低〜過熱上限）。
static func heart_fill_ratio(state: Dictionary) -> float:
	var low := float(state.get("heart_min_bpm", 100.0))
	var high := float(state.get("heart_max_bpm", 230.0))
	return clampf((float(state.get("heart_bpm", low)) - low) / maxf(high - low, 0.001), 0.0, 1.0)


## 通常上限（200）の位置。バー上の目印に使う。
static func heart_limit_ratio(state: Dictionary) -> float:
	var low := float(state.get("heart_min_bpm", 100.0))
	var high := float(state.get("heart_max_bpm", 230.0))
	return clampf((float(state.get("heart_normal_max_bpm", 200.0)) - low) / maxf(high - low, 0.001), 0.0, 1.0)


## 空気抵抗の減り（緑＝空力と後方支援、青＝ドラフト）を、20段の点灯数へ。
## 緑を先に積み、続けて青を積む。少しでもあれば、その色は最低1段は点く。合計は20段を超えない。
static func air_gauge_segments(green: float, blue: float) -> Dictionary:
	var step := AIR_GAUGE_FULL / float(AIR_GAUGE_SEGMENTS)
	var green_value := maxf(green, 0.0)
	var blue_value := maxf(blue, 0.0)
	var green_count := 0
	if green_value > 0.0:
		green_count = clampi(maxi(roundi(green_value / step), 1), 1, AIR_GAUGE_SEGMENTS)
	var total_count := clampi(ceili((green_value + blue_value) / step - 0.0001), 0, AIR_GAUGE_SEGMENTS)
	if blue_value > 0.0:
		total_count = maxi(total_count, green_count + 1)
	total_count = clampi(total_count, green_count, AIR_GAUGE_SEGMENTS)
	green_count = mini(green_count, total_count)
	return {"green": green_count, "blue": total_count - green_count}


static func heart_is_overheated(state: Dictionary) -> bool:
	return float(state.get("heart_bpm", 0.0)) > float(state.get("heart_normal_max_bpm", 200.0))


static func heart_color(state: Dictionary) -> Color:
	var bpm := float(state.get("heart_bpm", 0.0))
	var normal_max := float(state.get("heart_normal_max_bpm", 200.0))
	if bpm > normal_max:
		return COLOR_DANGER
	if bpm > normal_max - 20.0:
		return COLOR_WARN
	return COLOR_COOL


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	_draw_race_info(font)
	_draw_standings(font)
	_draw_main_panel(font)


func _draw_race_info(font: Font) -> void:
	var place := int(_state["place"])
	if place <= 0:
		return
	# 左：自分の順位。その右に2段で、残り距離とタイム。
	var origin := RACE_INFO_ORIGIN
	var place_text := "%d" % place
	var field_text := "/ %d 位" % int(_state["field_size"])
	var field_x := origin.x + font.get_string_size(place_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x + 10.0
	var info_x := field_x + font.get_string_size(field_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 20.0
	_draw_text(font, place_text, origin + Vector2(0.0, 58.0), 72, COLOR_TEXT)
	_draw_text(font, field_text, Vector2(field_x, origin.y + 58.0), 24, COLOR_DIM)
	_draw_text(font, "残り %.0f m" % float(_state["remaining_m"]), Vector2(info_x, origin.y + 28.0), 24, COLOR_TEXT)
	_draw_text(font, str(_state["time_text"]), Vector2(info_x, origin.y + 58.0), 24, COLOR_TEXT)


func _draw_main_panel(font: Font) -> void:
	# 親が CanvasLayer の場合は Control の size が当てにならないため、ビューポートの大きさを使う。
	var screen := get_viewport_rect().size
	var panel := Rect2(
		Vector2(PANEL_LEFT_MARGIN, screen.y - PANEL_BOTTOM_MARGIN - PANEL_HEIGHT),
		Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	)
	draw_rect(panel, COLOR_PANEL)
	_draw_name_tab(font, panel)
	var braking := bool(_state["braking"])
	# 左：速度とドラフト
	_draw_progress_bar(font, panel)
	var body_top := panel.position.y + PANEL_TOP_STRIP
	var speed_origin := Vector2(panel.position.x + 24.0, body_top + 96.0)
	_draw_text(font, "%d" % int(roundf(float(_state["speed_kmh"]))), speed_origin, 76, COLOR_TEXT)
	_draw_text(font, "km/h", speed_origin + Vector2(0.0, 30.0), 22, COLOR_DIM)
	_draw_draft_gauge(font, Vector2(panel.position.x + 24.0, body_top + 160.0))
	_draw_drive_actions(font, Vector2(panel.position.x + 128.0, body_top + 34.0))
	# 右：縦ゲージ3本（ノッチ・心拍・体力）
	var gauge_top := body_top + 18.0
	var left := panel.position.x + 224.0
	var column := 68.0
	_draw_notch_gauge(font, Vector2(left, gauge_top), braking)
	var heart_color_now := heart_color(_state)
	if heart_is_overheated(_state) and _blink > 0.5:
		heart_color_now = heart_color_now.lightened(0.35)
	_draw_vertical_gauge(
		font, "心拍", Vector2(left + column, gauge_top), heart_fill_ratio(_state), heart_color_now,
		heart_limit_ratio(_state), "%d" % int(roundf(float(_state["heart_bpm"])))
	)
	var fuel := float(_state["fuel_ratio"])
	_draw_fuel_gauge(font, Vector2(left + column * 2.0, gauge_top), fuel)
	if bool(_state["countdown"]):
		_draw_text(font, "↑↓で開始ノッチを選択", Vector2(panel.position.x + 24.0, panel.position.y - 10.0), 20, COLOR_TEXT)


## ダッシュとブーストの小さな表示。ブーストは残り回数（丸）と、効いている間の残り（バー）。
## ダッシュは、効いている間だけ光るバー。
func _draw_drive_actions(font: Font, origin: Vector2) -> void:
	var width := 78.0
	# 文字の左に、ゲームパッドのボタンのマーク（ブーストはX、ダッシュはB）。
	var mark_offset := Vector2(DRIVE_ACTION_MARK_SIZE * 0.5, -4.5)
	var text_offset := Vector2(DRIVE_ACTION_MARK_SIZE + 4.0, 0.0)
	ButtonMark.draw_mark(self, font, origin + mark_offset, "X", DRIVE_ACTION_MARK_SIZE)
	_draw_text(font, "BOOST", origin + text_offset, 12, COLOR_DIM)
	var uses_left := int(_state["boost_uses_left"])
	for index in int(_state["boost_max_uses"]):
		var center := Vector2(origin.x + 6.0 + index * 15.0, origin.y + 12.0)
		if index < uses_left:
			draw_circle(center, 5.0, COLOR_BOOST)
		else:
			draw_arc(center, 4.5, 0.0, TAU, 20, COLOR_DIM, 1.0)
	_draw_ratio_bar(Vector2(origin.x, origin.y + 22.0), width, float(_state["boost_ratio"]), COLOR_BOOST)
	ButtonMark.draw_mark(self, font, origin + Vector2(0.0, 46.0) + mark_offset, "B", DRIVE_ACTION_MARK_SIZE)
	_draw_text(font, "DASH", origin + Vector2(0.0, 46.0) + text_offset, 12, COLOR_DIM)
	_draw_ratio_bar(Vector2(origin.x, origin.y + 51.0), width, float(_state["dash_ratio"]), COLOR_PROGRESS)


func _draw_ratio_bar(position: Vector2, width: float, ratio: float, color: Color) -> void:
	var height := 5.0
	_draw_rounded_rect(Rect2(position, Vector2(width, height)), COLOR_TRACK, height * 0.5)
	var fill := width * clampf(ratio, 0.0, 1.0)
	if fill > 0.0:
		_draw_rounded_rect(Rect2(position, Vector2(maxf(fill, height), height)), color, height * 0.5)


## パネル上部の進行バー。上にレース距離（左）と残り距離（右）、下に全走者の位置。
## 名札。操作盤の左上の角の上に、名前を出す。札の幅は、名前の長さに合わせる。
func _draw_name_tab(font: Font, panel: Rect2) -> void:
	var player_name := str(_state["player_name"])
	if player_name.is_empty():
		return
	var fitted := FitText.fit(font, player_name, NAME_TAB_MAX_TEXT_WIDTH, NAME_TAB_FONT_SIZE)
	var trainer_name := str(_state["trainer_name"])
	var trainer_fitted := FitText.fit(font, trainer_name, NAME_TAB_TRAINER_MAX_WIDTH, NAME_TAB_TRAINER_FONT_SIZE)
	var trainer_space := 0.0 if trainer_name.is_empty() else NAME_TAB_TRAINER_GAP + float(trainer_fitted["width"])
	var tab := Rect2(
		Vector2(panel.position.x, panel.position.y - NAME_TAB_HEIGHT),
		Vector2(float(fitted["width"]) + trainer_space + NAME_TAB_PADDING * 2.0, NAME_TAB_HEIGHT)
	)
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	draw_style_box(box, tab)
	FitText.draw(
		self, font, Vector2(tab.position.x + NAME_TAB_PADDING, tab.position.y + NAME_TAB_HEIGHT * 0.5 + NAME_TAB_FONT_SIZE * 0.36),
		player_name, NAME_TAB_MAX_TEXT_WIDTH, NAME_TAB_FONT_SIZE, COLOR_TEXT, 0.0, 6, COLOR_OUTLINE
	)
	if not trainer_name.is_empty():
		FitText.draw(
			self, font, Vector2(tab.position.x + NAME_TAB_PADDING + float(fitted["width"]) + NAME_TAB_TRAINER_GAP, tab.position.y + NAME_TAB_HEIGHT * 0.5 + NAME_TAB_FONT_SIZE * 0.36),
			trainer_name, NAME_TAB_TRAINER_MAX_WIDTH, NAME_TAB_TRAINER_FONT_SIZE, COLOR_PROGRESS, 0.0, 6, COLOR_OUTLINE
		)


func _draw_progress_bar(font: Font, panel: Rect2) -> void:
	var left := panel.position.x + PROGRESS_SIDE_MARGIN
	var width := PANEL_WIDTH - PROGRESS_SIDE_MARGIN * 2.0
	var text_y := panel.position.y + 28.0
	# 左：順位と脚質の印。中央：タイム。右：残り距離とレース距離。名前は、操作盤の上の名札に出す。
	var state_color := style_state_color(int(_state["style_rank_bonus"]))
	var place := int(_state["place"])
	var place_text := "%s/%d位" % [str(place) if place > 0 else "-", int(_state["field_size"])]
	_draw_text(font, place_text, Vector2(left, text_y), 16, state_color)
	var chevrons_x := left + font.get_string_size(place_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 6.0
	_draw_style_chevrons(Vector2(chevrons_x, text_y - 6.0), state_color, int(_state["style_group_count"]), int(_state["style_group_index"]))
	var time_text := str(_state["time_text"])
	var time_width := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_draw_text(font, time_text, Vector2(left + (width - time_width) * 0.5, text_y), 16, COLOR_TEXT)
	var total_text := " / %d m" % int(roundf(float(_state["race_distance_m"])))
	var total_width := font.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var remaining_text := "残り %d" % int(roundf(float(_state["remaining_m"])))
	var remaining_width := font.get_string_size(remaining_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_draw_text(font, total_text, Vector2(left + width - total_width, text_y), 12, COLOR_DIM)
	_draw_text(font, remaining_text, Vector2(left + width - total_width - remaining_width, text_y), 16, COLOR_TEXT)
	var bar_y := panel.position.y + 38.0
	var rail := Rect2(Vector2(left, bar_y), Vector2(width, PROGRESS_BAR_HEIGHT))
	_draw_rounded_rect(rail, COLOR_TRACK, PROGRESS_BAR_HEIGHT * 0.5)
	var runners: Array = _state["runners"]
	var player_ratio := 0.0
	for mark in runners:
		if bool(mark["player"]):
			player_ratio = float(mark["ratio"])
	if player_ratio > 0.0:
		_draw_rounded_rect(Rect2(rail.position, Vector2(maxf(width * player_ratio, PROGRESS_BAR_HEIGHT), PROGRESS_BAR_HEIGHT)), COLOR_PROGRESS, PROGRESS_BAR_HEIGHT * 0.5)
	for quarter: float in [0.25, 0.5, 0.75]:
		var x: float = left + width * quarter
		draw_line(Vector2(x, bar_y - 2.0), Vector2(x, bar_y + PROGRESS_BAR_HEIGHT + 2.0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
	_draw_goal_checker(Vector2(left + width, bar_y + PROGRESS_BAR_HEIGHT * 0.5))
	var center_y := bar_y + PROGRESS_BAR_HEIGHT * 0.5
	for mark in runners:
		if not bool(mark["player"]):
			draw_circle(Vector2(left + width * float(mark["ratio"]), center_y), 4.5, mark["color"])
	for mark in runners:
		if bool(mark["player"]):
			var center := Vector2(left + width * float(mark["ratio"]), center_y)
			draw_circle(center, 8.5, COLOR_TEXT)
			draw_circle(center, 6.0, mark["color"])


## 脚質の印。順位の組の数だけ「〈」を並べ、左が先頭の組。得意な組だけ、はっきり太く描く。
## center_left は、印の並びの左端・縦の中央。色は、今の順位との関係（青・白・赤）。
func _draw_style_chevrons(center_left: Vector2, color: Color, count: int, own: int, size_scale: float = 1.0) -> void:
	draw_style_chevrons(self, center_left, color, count, own, size_scale)


## 脚質の印を、指定の描画先に描く（操作盤・順位表・レース選択で共通）。
static func draw_style_chevrons(canvas: CanvasItem, center_left: Vector2, color: Color, count: int, own: int, size_scale: float = 1.0) -> void:
	var step := STYLE_CHEVRON_STEP * size_scale
	var half_height := 6.5 * size_scale
	var depth := 5.0 * size_scale
	for index in count:
		var tip := Vector2(center_left.x + index * step, center_left.y)
		var points := PackedVector2Array([
			tip + Vector2(depth, -half_height), tip, tip + Vector2(depth, half_height),
		])
		if index == own:
			# 光っているように、外側を薄く太く、内側を濃く描く。
			canvas.draw_polyline(points, Color(color, 0.28), 6.0 * size_scale, true)
			canvas.draw_polyline(points, color, 2.6 * size_scale, true)
		else:
			canvas.draw_polyline(points, Color(color, 0.38), 1.6, true)


## 左上の順位表。上から今の順位の順。ゴールして確定した行は、太く・大きく・明るくし、印を王冠・メダルにする。
func _draw_standings(font: Font) -> void:
	var standings: Array = _state["standings"]
	if int(_state["place"]) <= 0 or standings.is_empty():
		return
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.variation_embolden = 0.8
	_bold_font.base_font = font
	var confirmed := confirmed_count(standings)
	# 人数が少ないときも、満員のときと同じ高さから、上に詰めて並べる。
	var table_top := standings_top(get_viewport_rect().size.y, STANDINGS_FULL_ROWS)
	for index in standings.size():
		var row: Dictionary = standings[index]
		var top := table_top + index * STANDINGS_ROW_HEIGHT
		var center_y := top + STANDINGS_ROW_HEIGHT * 0.5
		var x := STANDINGS_LEFT
		var is_confirmed := index < confirmed
		if bool(row["player"]):
			_draw_rounded_rect(Rect2(Vector2(x - 8.0, top + 1.0), Vector2(STANDINGS_WIDTH + 8.0, STANDINGS_ROW_HEIGHT - 2.0)), Color(COLOR_PROGRESS, 0.22), 6.0)
		var row_font: Font = _bold_font if is_confirmed else font
		var text_color := COLOR_TEXT if is_confirmed else COLOR_DIM.lerp(COLOR_TEXT, 0.45)
		var text_size := STANDINGS_CONFIRMED_FONT_SIZE if is_confirmed else STANDINGS_FONT_SIZE
		var baseline := center_y + text_size * 0.36
		_draw_standings_rank(row_font, Vector2(x + 12.0, center_y), index + 1, is_confirmed, text_size, text_color)
		draw_circle(Vector2(x + 36.0, center_y), 6.5, COLOR_OUTLINE)
		draw_circle(Vector2(x + 36.0, center_y), 5.0, row["color"])
		# 長い名前は、欄の幅に収める（少し小さく・少し細く。それでも入らなければ末尾を「…」に）。
		FitText.draw(self, row_font, Vector2(x + STANDINGS_NAME_X, baseline), str(row["name"]), STANDINGS_NAME_WIDTH, text_size, text_color, 0.0, 6, COLOR_OUTLINE)
		_draw_style_chevrons(Vector2(x + STANDINGS_STYLE_X, center_y), style_state_color(int(row["style_rank_bonus"])), int(row["style_group_count"]), int(row["style_group_index"]), 0.85)
		var value_baseline := center_y + STANDINGS_VALUE_FONT_SIZE * 0.36
		_draw_heart(Vector2(x + STANDINGS_HEART_X + 7.0, center_y), COLOR_DANGER)
		# 心拍の数字の色は、操作盤の心拍と同じ決め方。
		var heart_text_color := heart_color({"heart_bpm": row["heart_bpm"], "heart_normal_max_bpm": _state["heart_normal_max_bpm"]})
		_draw_text(font, "%d" % int(roundf(float(row["heart_bpm"]))), Vector2(x + STANDINGS_HEART_X + 18.0, value_baseline), STANDINGS_VALUE_FONT_SIZE, heart_text_color)
		var fuel := float(row["fuel_ratio"])
		_draw_battery(Vector2(x + STANDINGS_FUEL_X, center_y - STANDINGS_BATTERY_SIZE.y * 0.5), fuel)
		_draw_text(font, "%d%%" % int(roundf(fuel * 100.0)), Vector2(x + STANDINGS_FUEL_X + STANDINGS_BATTERY_SIZE.x + 8.0, value_baseline), STANDINGS_VALUE_FONT_SIZE, COLOR_DANGER if fuel < 0.0 else text_color)
		if is_confirmed:
			_draw_text(font, standings_time_text(float(row["finish_time"])), Vector2(x + STANDINGS_TIME_X, value_baseline), STANDINGS_VALUE_FONT_SIZE, text_color)
	if confirmed > 0 and confirmed < standings.size():
		# 確定した行と、まだの行の境目。行の境目に引くので、行の高さは変わらない。
		var line_y := table_top + confirmed * STANDINGS_ROW_HEIGHT
		var from := Vector2(STANDINGS_LEFT - 8.0, line_y)
		var to := Vector2(STANDINGS_LEFT + STANDINGS_WIDTH, line_y)
		draw_line(from, to, COLOR_OUTLINE, 4.0)
		draw_line(from, to, COLOR_TEXT, 1.5)


## 順位の印。確定したら、1位は金の王冠、2位は銀メダル、3位は銅メダル、4位からは太い数字。
func _draw_standings_rank(font: Font, center: Vector2, place: int, is_confirmed: bool, font_size: int, color: Color) -> void:
	if is_confirmed and place == 1:
		_draw_crown(center)
		return
	if is_confirmed and place <= 3:
		_draw_medal(font, center, place, COLOR_SILVER if place == 2 else COLOR_BRONZE)
		return
	var text := "%d" % place
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_draw_text(font, text, Vector2(center.x - width * 0.5, center.y + font_size * 0.36), font_size, color)


func _draw_crown(center: Vector2) -> void:
	draw_crown(self, center)


func _draw_medal(font: Font, center: Vector2, place: int, color: Color) -> void:
	draw_medal(self, font, center, place, color)


## 金の王冠を、指定の描画先に描く（順位表と、着順の板で共通）。
static func draw_crown(canvas: CanvasItem, center: Vector2, size_scale: float = 1.0) -> void:
	var shape := PackedVector2Array([
		Vector2(-11.0, 8.0), Vector2(-11.0, -5.0), Vector2(-5.0, 1.0), Vector2(0.0, -9.0),
		Vector2(5.0, 1.0), Vector2(11.0, -5.0), Vector2(11.0, 8.0),
	])
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point * size_scale)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, COLOR_OUTLINE, 4.0 * size_scale, true)
	canvas.draw_colored_polygon(points, COLOR_GOLD)
	canvas.draw_line(center + Vector2(-11.0, 4.5) * size_scale, center + Vector2(11.0, 4.5) * size_scale, Color(0.72, 0.46, 0.05), 1.5 * size_scale)
	for tip: Vector2 in [Vector2(-11.0, -5.0), Vector2(0.0, -9.0), Vector2(11.0, -5.0)]:
		canvas.draw_circle(center + tip * size_scale, 2.2 * size_scale, COLOR_GOLD)


## メダル（リボンと丸）を、指定の描画先に描く。
static func draw_medal(canvas: CanvasItem, font: Font, center: Vector2, place: int, color: Color, size_scale: float = 1.0) -> void:
	var ribbon := PackedVector2Array([
		center + Vector2(-7.0, -12.0) * size_scale, center + Vector2(7.0, -12.0) * size_scale,
		center + Vector2(3.0, -3.0) * size_scale, center + Vector2(-3.0, -3.0) * size_scale,
	])
	canvas.draw_colored_polygon(ribbon, COLOR_COOL)
	var medal_center := center + Vector2(0.0, 2.5) * size_scale
	canvas.draw_circle(medal_center, 9.5 * size_scale, COLOR_OUTLINE)
	canvas.draw_circle(medal_center, 8.0 * size_scale, color)
	canvas.draw_arc(medal_center, 5.8 * size_scale, 0.0, TAU, 24, color.darkened(0.3), 1.0 * size_scale, true)
	var text := "%d" % place
	var font_size := int(roundf(11.0 * size_scale))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, medal_center + Vector2(-width * 0.5, 4.0 * size_scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color.darkened(0.6))


func _draw_heart(center: Vector2, color: Color) -> void:
	for pass_index in 2:
		var grow := 1.5 if pass_index == 0 else 0.0
		var pass_color := COLOR_OUTLINE if pass_index == 0 else color
		draw_circle(center + Vector2(-3.0, -2.0), 3.4 + grow, pass_color)
		draw_circle(center + Vector2(3.0, -2.0), 3.4 + grow, pass_color)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-6.2 - grow, -0.4), center + Vector2(6.2 + grow, -0.4), center + Vector2(0.0, 6.6 + grow * 1.4),
		]), pass_color)


## 体力の電池。操作盤の体力バーを横にしたもの：左の4分の1が負債（マイナス）、その右がプラス。
## 今の体力の位置まで、左から色を塗る。
func _draw_battery(top_left: Vector2, fuel_ratio: float) -> void:
	var body := Rect2(top_left, STANDINGS_BATTERY_SIZE)
	draw_rect(body.grow(1.5), COLOR_OUTLINE)
	var cap := Rect2(Vector2(body.end.x, body.position.y + 3.0), Vector2(3.0, body.size.y - 6.0))
	draw_rect(cap.grow(1.0), COLOR_OUTLINE)
	draw_rect(cap, COLOR_TEXT)
	var inner := body.grow(-2.0)
	_draw_battery_gradient(inner, -1.0, 1.0, 0.25)
	_draw_battery_gradient(inner, -1.0, clampf(fuel_ratio, -1.0, 1.0), 1.0)
	draw_rect(body, COLOR_TEXT, false, 1.5)


## 電池の中での、体力の割合の横の位置。負債の限度（-1）が左端、0が左から4分の1、満タン（1）が右端。
static func battery_x(inner: Rect2, fuel_ratio: float) -> float:
	var zero_x := inner.position.x + inner.size.x * FUEL_DEBT_ZONE_RATIO
	if fuel_ratio >= 0.0:
		return zero_x + inner.size.x * (1.0 - FUEL_DEBT_ZONE_RATIO) * minf(fuel_ratio, 1.0)
	return zero_x - inner.size.x * FUEL_DEBT_ZONE_RATIO * minf(-fuel_ratio, 1.0)


## 電池の中身を、体力の割合 [from_ratio, to_ratio] の範囲だけ、操作盤の体力バーと同じ色で描く。
func _draw_battery_gradient(inner: Rect2, from_ratio: float, to_ratio: float, alpha: float) -> void:
	var stops := fuel_gradient_stops()
	for index in stops.size() - 1:
		var high: Array = stops[index]
		var low: Array = stops[index + 1]
		var r0 := maxf(float(low[0]), from_ratio)
		var r1 := minf(float(high[0]), to_ratio)
		if r1 <= r0:
			continue
		var c0 := fuel_color(r0)
		var c1 := fuel_color(r1)
		c0.a = alpha
		c1.a = alpha
		var x0 := battery_x(inner, r0)
		var x1 := battery_x(inner, r1)
		draw_polygon(
			PackedVector2Array([Vector2(x0, inner.position.y), Vector2(x1, inner.position.y), Vector2(x1, inner.end.y), Vector2(x0, inner.end.y)]),
			PackedColorArray([c0, c1, c1, c0])
		)


func _draw_goal_checker(center: Vector2) -> void:
	var cell := 4.0
	for row in 4:
		for column in 2:
			var color := Color(0.97, 0.98, 1.0, 1.0) if (row + column) % 2 == 0 else Color(0.08, 0.1, 0.16, 1.0)
			draw_rect(Rect2(Vector2(center.x - cell + column * cell, center.y - cell * 2.0 + row * cell), Vector2(cell, cell)), color)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


func _draw_draft_gauge(font: Font, origin: Vector2) -> void:
	var green_value := float(_state["air_green"])
	var blue_value := float(_state["air_blue"])
	var counts := air_gauge_segments(green_value, blue_value)
	_draw_text(font, "空気抵抗 −%d%%" % int(roundf((green_value + blue_value) * 100.0)), origin + Vector2(0.0, -8.0), 16, COLOR_DIM)
	var segment_width := 4.5
	var gap := 1.2
	for index in AIR_GAUGE_SEGMENTS:
		var rect := Rect2(origin + Vector2(index * (segment_width + gap), 0.0), Vector2(segment_width, 14.0))
		var color := COLOR_TRACK
		if index < int(counts["green"]):
			color = COLOR_AERO
		elif index < int(counts["green"]) + int(counts["blue"]):
			color = COLOR_COOL
		draw_rect(rect, color)
	# 凡例
	var legend_y := origin.y + 28.0
	draw_rect(Rect2(Vector2(origin.x, legend_y - 9.0), Vector2(9.0, 9.0)), COLOR_AERO)
	_draw_text(font, "空力", Vector2(origin.x + 13.0, legend_y), 14, COLOR_DIM)
	draw_rect(Rect2(Vector2(origin.x + 56.0, legend_y - 9.0), Vector2(9.0, 9.0)), COLOR_COOL)
	_draw_text(font, "集団", Vector2(origin.x + 69.0, legend_y), 14, COLOR_DIM)


func _draw_notch_gauge(font: Font, origin: Vector2, braking: bool) -> void:
	var notch := int(_state["notch"])
	var bar_width := 34.0
	var bar_height := 110.0
	var gap := 3.0
	var segment_height := (bar_height - gap * (NOTCH_COUNT - 1)) / NOTCH_COUNT
	for index in NOTCH_COUNT:
		# 下がノッチ0、上へ積み上げる。
		var y := origin.y + bar_height - (index + 1) * segment_height - index * gap
		var rect := Rect2(Vector2(origin.x, y), Vector2(bar_width, segment_height))
		var color := COLOR_TRACK
		if index > 0 and index <= notch:
			color = COLOR_DIM if braking else COLOR_OK.lerp(COLOR_WARN, float(index) / float(NOTCH_COUNT - 1))
		draw_rect(rect, color)
		if index == notch:
			draw_rect(rect.grow(2.0), COLOR_TEXT, false, 2.0)
	_draw_text(font, "ノッチ", Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, "ブレーキ" if braking else "%d" % notch, Vector2(origin.x - (6.0 if braking else -8.0), origin.y + bar_height + 54.0), 20 if braking else 26, COLOR_DANGER if braking else COLOR_TEXT)


func _draw_vertical_gauge(font: Font, title: String, origin: Vector2, ratio: float, color: Color, mark_ratio: float, value_text: String) -> void:
	var bar_width := 34.0
	var bar_height := 110.0
	var track := Rect2(origin, Vector2(bar_width, bar_height))
	draw_rect(track, COLOR_TRACK)
	var fill_height := bar_height * ratio
	draw_rect(Rect2(Vector2(origin.x, origin.y + bar_height - fill_height), Vector2(bar_width, fill_height)), color)
	if mark_ratio >= 0.0:
		var y := origin.y + bar_height - bar_height * mark_ratio
		draw_line(Vector2(origin.x - 4.0, y), Vector2(origin.x + bar_width + 4.0, y), COLOR_TEXT, 2.0)
	_draw_text(font, title, Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, value_text, Vector2(origin.x - 6.0, origin.y + bar_height + 54.0), 20, color)


## 体力バー。1本の目盛りで、上が満タン、下から1/4が負債。今の体力の高さまで、下から明るく塗る。
## 色は位置で決まり、満タンの青から、緑・黄・橙・0の赤、負債の濃い赤まで、常に全体を薄く見せる。
## 負債の全体（0〜限度）は下の1/4に収まるので、プラスより縮尺が小さく、減る速さは遅く見える。
func _draw_fuel_gauge(font: Font, origin: Vector2, fuel: float) -> void:
	var bar_width := 34.0
	var bar_height := GAUGE_BAR_HEIGHT
	var zero_y := fuel_zero_y(origin.y)
	var bottom_y := origin.y + bar_height
	draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), COLOR_TRACK)
	_draw_fuel_gradient(origin.x, bar_width, zero_y, origin.y, bottom_y, 0.22)
	_draw_fuel_gradient(origin.x, bar_width, zero_y, fuel_y(zero_y, fuel), bottom_y, 1.0)
	# 体力0の境目。ここより下が負債（マイナス）。
	draw_line(Vector2(origin.x, zero_y), Vector2(origin.x + bar_width, zero_y), COLOR_TEXT, 1.0)
	var debt := fuel_debt_ratio(fuel)
	var value_text := "-%d%%" % int(roundf(debt * 100.0)) if debt > 0.0 else "%d%%" % int(roundf(fuel * 100.0))
	_draw_text(font, "体力", Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, value_text, Vector2(origin.x - 6.0, origin.y + bar_height + 54.0), 20, fuel_color(fuel))


## バーの上端が origin_y のとき、体力0の線の縦の位置。
static func fuel_zero_y(origin_y: float) -> float:
	return origin_y + GAUGE_BAR_HEIGHT * (1.0 - FUEL_DEBT_ZONE_RATIO)


## 体力の割合に対応する、バー上の縦の位置。0が zero_y、プラスは上へ（満タンで上端）、負債は下へ（限度で下端）。
static func fuel_y(zero_y: float, fuel_ratio: float) -> float:
	if fuel_ratio >= 0.0:
		return zero_y - GAUGE_BAR_HEIGHT * (1.0 - FUEL_DEBT_ZONE_RATIO) * minf(fuel_ratio, 1.0)
	return zero_y + GAUGE_BAR_HEIGHT * FUEL_DEBT_ZONE_RATIO * minf(-fuel_ratio, 1.0)


## 体力バーの色を、縦の範囲 [from_y, to_y]（from_y が上）だけ、なめらかに描く。
func _draw_fuel_gradient(x: float, width: float, zero_y: float, from_y: float, to_y: float, alpha: float) -> void:
	if to_y <= from_y:
		return
	var stops := fuel_gradient_stops()
	for index in stops.size() - 1:
		var upper: Array = stops[index]
		var lower: Array = stops[index + 1]
		var upper_y := fuel_y(zero_y, float(upper[0]))
		var lower_y := fuel_y(zero_y, float(lower[0]))
		var y0 := maxf(upper_y, from_y)
		var y1 := minf(lower_y, to_y)
		if y1 <= y0 or lower_y <= upper_y:
			continue
		var c0 := (upper[1] as Color).lerp(lower[1], (y0 - upper_y) / (lower_y - upper_y))
		var c1 := (upper[1] as Color).lerp(lower[1], (y1 - upper_y) / (lower_y - upper_y))
		c0.a = alpha
		c1.a = alpha
		draw_polygon(
			PackedVector2Array([Vector2(x, y0), Vector2(x + width, y0), Vector2(x + width, y1), Vector2(x, y1)]),
			PackedColorArray([c0, c0, c1, c1])
		)


func _draw_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	# 背景に溶けないよう、暗い縁取りを付ける。
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Color(0.03, 0.05, 0.1, 0.9))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
