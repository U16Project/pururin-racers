extends Control
## レース終了時の着順の表。1行に、着順（1〜3着は王冠・メダル）、個体の色の丸、名前、タイムを、位置をそろえて描く。
## ユーザーの行は、帯と名前の色で目立たせる。値は set_rows() で受け取り、計算はしない。

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const FitText := preload("res://scripts/presentation/fit_text.gd")
const BOARD_WIDTH := 500.0
const ROW_HEIGHT := 40.0
const RANK_CENTER_X := 30.0
const DOT_X := 76.0
const NAME_X := 96.0
const TIME_RIGHT_MARGIN := 16.0
const NAME_TIME_GAP := 12.0
## トレーナー名（名前の右に、小さく出す）。名前との間、文字の大きさ、これより狭い所には出さない幅。
const TRAINER_GAP := 10.0
const TRAINER_FONT_SIZE := 15
const TRAINER_MIN_WIDTH := 44.0
const FONT_SIZE := 24
const MARK_SCALE := 1.35
const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.78, 1.0)
const COLOR_PLAYER := Color(0.45, 0.92, 1.0, 1.0)
const COLOR_ROW_BAND := Color(1.0, 1.0, 1.0, 0.045)

## 1行ぶんの辞書：place（着順）、name、color、player（ユーザーかどうか）、time_text
var _rows: Array = []
var _bold_font: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_rows(rows: Array) -> void:
	_rows = rows
	custom_minimum_size = Vector2(BOARD_WIDTH, ROW_HEIGHT * rows.size())
	queue_redraw()


func rows() -> Array:
	return _rows


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.variation_embolden = 0.8
	_bold_font.base_font = font
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var top := ROW_HEIGHT * index
		var center_y := top + ROW_HEIGHT * 0.5
		var baseline := center_y + FONT_SIZE * 0.36
		var is_player := bool(row["player"])
		var band := Rect2(Vector2(0.0, top + 2.0), Vector2(size.x, ROW_HEIGHT - 4.0))
		if is_player:
			draw_style_box(_band_box(Color(RaceHud.COLOR_PROGRESS, 0.24)), band)
			draw_rect(Rect2(band.position, Vector2(5.0, band.size.y)), COLOR_PLAYER)
		elif index % 2 == 1:
			draw_style_box(_band_box(COLOR_ROW_BAND), band)
		var place := int(row["place"])
		_draw_rank(font, Vector2(RANK_CENTER_X, center_y), place)
		draw_circle(Vector2(DOT_X, center_y), 8.5, RaceHud.COLOR_OUTLINE)
		draw_circle(Vector2(DOT_X, center_y), 7.0, row["color"])
		var name_font: Font = _bold_font if is_player else font
		var time_text := str(row["time_text"])
		var time_width := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		# 名前は、タイムの手前までの幅に収める（全角9文字は、そのままの大きさで入る）。
		var name_width := size.x - TIME_RIGHT_MARGIN - time_width - NAME_TIME_GAP - NAME_X
		FitText.draw(self, name_font, Vector2(NAME_X, baseline), str(row["name"]), name_width, FONT_SIZE, COLOR_PLAYER if is_player else COLOR_TEXT)
		# 名前の右の、タイムまでの空きに、トレーナー名を小さく出す（長いときは縮める）。
		var trainer_x := NAME_X + float(FitText.fit(name_font, str(row["name"]), name_width, FONT_SIZE)["width"]) + TRAINER_GAP
		var trainer_width := NAME_X + name_width - trainer_x
		if trainer_width >= TRAINER_MIN_WIDTH:
			FitText.draw(self, font, Vector2(trainer_x, baseline), str(row["trainer"]), trainer_width, TRAINER_FONT_SIZE, COLOR_PLAYER if is_player else COLOR_DIM)
		draw_string(font, Vector2(size.x - TIME_RIGHT_MARGIN - time_width, baseline), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, RaceHud.COLOR_GOLD if place == 1 else COLOR_TEXT)


## 着順の印。1着は金の王冠、2着は銀メダル、3着は銅メダル、4着からは「4着」の文字。
func _draw_rank(font: Font, center: Vector2, place: int) -> void:
	if place == 1:
		RaceHud.draw_crown(self, center, MARK_SCALE)
		return
	if place <= 3:
		RaceHud.draw_medal(self, font, center, place, RaceHud.COLOR_SILVER if place == 2 else RaceHud.COLOR_BRONZE, MARK_SCALE)
		return
	var number := "%d" % place
	var number_width := _bold_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var unit_width := font.get_string_size("着", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var left := center.x - (number_width + unit_width) * 0.5
	var baseline := center.y + FONT_SIZE * 0.36
	draw_string(_bold_font, Vector2(left, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, COLOR_TEXT)
	draw_string(font, Vector2(left + number_width + 1.0, baseline), "着", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, COLOR_DIM)


static func _band_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	return box
