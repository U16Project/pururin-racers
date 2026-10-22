extends Control
## レースの左上の操作盤（場面 res://scenes/hud/race_control_panel.tscn の、いちばん上の部品）。
## 見た目（形・色・光り方・文字の型・置き場所）は、場面の部品の欄が正。ここは、レースの値を部品に入れるだけ。
## 上の行（RaceInfo）に、順位・残り距離・タイムと区切りの線。
## 値を受け取るのは update_state（レースの操作盤の値。local_race_controller が作る）。
## 大きさは set_scale_factor（1＝場面の大きさのまま）。台（Board）の左上が、この部品の左上に来るように置く。

## 速さの弧が満タンになる速さ（km/h）。
const SPEED_FULL_KMH := 110.0
## 空力の弧が満タンになる、空気抵抗の減りの割合。ふつうは1〜4割で、6割を超えることはほぼない（超えたら満タンで止める）。
## 数字は、本当の割合のまま出す。
const AERO_FULL := 0.6
## 心拍の水の色：低いうちは水色。ふつうの上限の手前から黄、上限を超えると赤。
const COLOR_HEART_LOW := Color(0.2, 0.92, 1.0, 1.0)
const COLOR_HEART_MID := Color(1.0, 0.76, 0.25, 1.0)
const COLOR_HEART_HIGH := Color(1.0, 0.32, 0.28, 1.0)
const HEART_WARN_FROM_BPM := 40.0
const HEART_WARN_AT_BPM := 20.0
## 鼓動の光：音が鳴った瞬間が1、そこからすっと消える（鼓動1回のうち、最初のどれだけ光るか）。
const HEART_BEAT_PART := 0.4
## 名前と属性の印のあいだに、最低これだけ空ける（長い名前は、横に縮めて収める）。
const NAME_GAP := 8.0
## 押し合いで削られた体力を、赤い帯で残す。押し合いが終わってから、この秒数で消す。
const STAMINA_HIT_FADE_S := 1.0
## 押し負けているあいだ、ハートのふちが赤く点滅する色と、1秒あたりの点滅の回数、震える幅（ピクセル）。
## 操作盤の描き直しは1秒に10回（local_race_controller の HEART_HUD_UPDATES_PER_S）なので、点滅は、それよりずっと遅くする。
const HEART_HIT_EDGE_COLOR := Color(1.0, 0.12, 0.12, 1.0)
const HEART_HIT_FLASH_PER_S := 2.5
const HEART_HIT_SHAKE_PX := 3.0

@onready var _board: Control = $Board
@onready var _place: Label = $RaceInfo/Place
@onready var _field: Label = $RaceInfo/Field
@onready var _remaining: Label = $RaceInfo/Remaining
@onready var _time: Label = $RaceInfo/Time
@onready var _name: Label = $NameRow/Name
@onready var _attribute: Control = $NameRow/Attribute
@onready var _style: Control = $NameRow/Style
@onready var _speed: Control = $Gauges/Speed
@onready var _stamina: Control = $Gauges/Stamina
@onready var _stamina_hit: Control = $Gauges/StaminaHit
@onready var _stamina_top: Control = $Gauges/StaminaTop
@onready var _heart: Control = $Heart
@onready var _bpm: Label = $Bpm
@onready var _aero_blue: Control = $Aero/AeroBlue
@onready var _aero_green: Control = $Aero/AeroGreen
@onready var _aero_base: Control = $Aero/AeroBase
@onready var _aero_value: Label = $Aero/AeroValue
@onready var _speed_value: Label = $SpeedText/SpeedValue
@onready var _stamina_value: Label = $StaminaText/StaminaValue
@onready var _notch_bars: Control = $Notch/NotchBars
@onready var _notch_value: Label = $Notch/NotchValue
@onready var _boost_bars: Control = $Boost/BoostBars
@onready var _boost_count: Label = $Boost/BoostCount
@onready var _dash_bar: Control = $Dash/DashBar

var _scale := 1.0
## 名前の、場面で決めた大きさ（長い名前は、ここから横に縮める）。
var _name_scale := Vector2.ONE
## 赤い帯の上のはし（体力の割合）。押し合いのあいだは、始まったときの値で止め、終わったら、だんだん今の値へ戻す。
var _stamina_hit_ratio := 1.0
var _stamina_hit_from := 1.0
var _push_ended_msec := -1
var _was_pushing := false
## ハートの、場面で決めたふちの色と位置（押し負けの点滅・震えのあと、戻すため）。
var _heart_edge_color := Color.WHITE
var _heart_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_scale = _name.scale
	_heart_edge_color = _heart.get("edge_color")
	_heart_position = _heart.position
	set_scale_factor(_scale)


## 全体の大きさを変える（1＝場面の大きさのまま）。台の左上が、この部品の左上に来るように置く。
func set_scale_factor(value: float) -> void:
	_scale = value
	if not is_node_ready():
		return
	scale = Vector2(value, value)
	position = -_board.position * value
	custom_minimum_size = _board.size * value


## 心拍の水の色。低いうちは水色、ふつうの上限に近づくと黄、超えると赤。
static func heart_water_color(bpm: float, normal_max_bpm: float, max_bpm: float) -> Color:
	var warn_from := normal_max_bpm - HEART_WARN_FROM_BPM
	var warn_at := normal_max_bpm - HEART_WARN_AT_BPM
	if bpm <= warn_from:
		return COLOR_HEART_LOW
	if bpm <= warn_at:
		return COLOR_HEART_LOW.lerp(COLOR_HEART_MID, inverse_lerp(warn_from, warn_at, bpm))
	if bpm <= normal_max_bpm:
		return COLOR_HEART_MID.lerp(COLOR_HEART_HIGH, inverse_lerp(warn_at, normal_max_bpm, bpm) * 0.5)
	return COLOR_HEART_MID.lerp(COLOR_HEART_HIGH, 0.5 + 0.5 * clampf(inverse_lerp(normal_max_bpm, max_bpm, bpm), 0.0, 1.0))


## 心拍の水の高さ（0〜1）。最低で0、過熱の上限で1。
static func heart_fill(bpm: float, min_bpm: float, max_bpm: float) -> float:
	return clampf(inverse_lerp(min_bpm, max_bpm, bpm), 0.0, 1.0)


## 体力の弧の値（0〜1）。弧のまん中が0（目印の線）、上のはしが満タン、下のはしが借りの限度。
static func stamina_value(fuel_ratio: float) -> float:
	return clampf((fuel_ratio + 1.0) * 0.5, 0.0, 1.0)


## 鼓動の光（0〜1）。鼓動の瞬間が1、HEART_BEAT_PART のうちに、すっと消える。
static func beat_glow(phase: float) -> float:
	var fade := clampf(1.0 - phase / HEART_BEAT_PART, 0.0, 1.0)
	return fade * fade


func update_state(values: Dictionary) -> void:
	if not is_node_ready():
		return
	# 上の行：順位・残り距離・タイム。初めから出す（スタート前は、順位がまだ無いので1位と出す）。
	var place := maxi(int(values.get("place", 0)), 1)
	_place.text = "%d" % place
	_field.text = "/ %d 位" % int(values.get("field_size", 0))
	_remaining.text = "残り %.0f m" % float(values.get("remaining_m", 0.0))
	_time.text = str(values.get("time_text", ""))
	var speed := float(values.get("speed_kmh", 0.0))
	_speed.set("value", clampf(speed / SPEED_FULL_KMH, 0.0, 1.0))
	_speed_value.text = "%d" % int(round(speed))
	var fuel := float(values.get("fuel_ratio", 1.0))
	var pushing := bool(values.get("pushing", false))
	_update_stamina_hit(fuel, pushing, Time.get_ticks_msec())
	_stamina.set("value", stamina_value(fuel))
	_stamina_hit.set("value", stamina_value(_stamina_hit_ratio))
	_stamina_top.set("value", stamina_value(fuel))
	_stamina_value.text = "%d" % int(round(fuel * 100.0))
	# 空力のゲージ：根本から、黄＝空力の能力の分、緑＝後方支援の分、青＝ドラフトの分。
	var base := clampf(float(values.get("air_base", 0.0)), 0.0, 1.0)
	var with_rear := clampf(base + float(values.get("air_rear", 0.0)), 0.0, 1.0)
	var total := clampf(with_rear + float(values.get("air_blue", 0.0)), 0.0, 1.0)
	_aero_blue.set("value", clampf(total / AERO_FULL, 0.0, 1.0))
	_aero_green.set("value", clampf(with_rear / AERO_FULL, 0.0, 1.0))
	_aero_base.set("value", clampf(base / AERO_FULL, 0.0, 1.0))
	_aero_value.text = "%d" % int(round(total * 100.0))
	var notch_max := maxi(int(values.get("notch_max", 1)), 1)
	var notch := clampi(int(values.get("notch", 1)), 1, notch_max)
	_notch_bars.set("count", notch_max)
	_notch_bars.set("lit_count", notch)
	_notch_value.text = "%d" % notch
	var boost_max := maxi(int(values.get("boost_max_uses", 1)), 1)
	var boost_left := clampi(int(values.get("boost_uses_left", 0)), 0, boost_max)
	_boost_bars.set("count", boost_max)
	_boost_bars.set("lit_count", boost_left)
	_boost_bars.set("partial", clampf(float(values.get("boost_ratio", 0.0)), 0.0, 1.0) if boost_left < boost_max else 0.0)
	_boost_count.text = "( %d )" % boost_left
	_dash_bar.set("value", clampf(float(values.get("dash_ratio", 0.0)), 0.0, 1.0))
	var bpm := float(values.get("heart_bpm", 100.0))
	var max_bpm := float(values.get("heart_max_bpm", 230.0))
	_heart.set("value", heart_fill(bpm, float(values.get("heart_min_bpm", 100.0)), max_bpm))
	_heart.set("water_color", heart_water_color(bpm, float(values.get("heart_normal_max_bpm", 200.0)), max_bpm))
	_heart.set("beat", beat_glow(float(values.get("heart_beat_phase", 1.0))))
	_update_heart_hit(bool(values.get("push_lost", false)), Time.get_ticks_msec())
	_bpm.text = "%d" % int(round(bpm))
	var trainer := str(values.get("trainer_name", ""))
	_name.text = str(values.get("player_name", "")) + ("（%s）" % trainer if not trainer.is_empty() else "")
	_fit_name()
	_attribute.set("attribute_id", str(values.get("attribute_id", "")))
	_attribute.set("attribute_color", values.get("attribute_color", Color.WHITE))
	_style.set("style_count", int(values.get("style_group_count", 0)))
	_style.set("style_index", int(values.get("style_group_index", 0)))
	_style.set("style_rank_bonus", int(values.get("style_rank_bonus", 0)))


## 押し合いで削られた体力の赤い帯。押し合いが始まったときの体力で上のはしを止め、終わったら STAMINA_HIT_FADE_S で今の値へ戻す。
func _update_stamina_hit(fuel: float, pushing: bool, now_msec: int) -> void:
	if pushing:
		if not _was_pushing:
			_stamina_hit_ratio = fuel
		_stamina_hit_ratio = maxf(_stamina_hit_ratio, fuel)
		_push_ended_msec = -1
	elif _was_pushing:
		_push_ended_msec = now_msec
		_stamina_hit_from = _stamina_hit_ratio
	_was_pushing = pushing
	if not pushing:
		if _push_ended_msec < 0:
			_stamina_hit_ratio = fuel
		else:
			var t := clampf(float(now_msec - _push_ended_msec) / 1000.0 / STAMINA_HIT_FADE_S, 0.0, 1.0)
			_stamina_hit_ratio = maxf(lerpf(_stamina_hit_from, fuel, t), fuel)
			if t >= 1.0:
				_push_ended_msec = -1


## 押し負けているあいだ、ハートのふちを赤く点滅させ、小さく震わせる。負けていなければ、場面で決めた見た目に戻す。
func _update_heart_hit(losing: bool, now_msec: int) -> void:
	if not losing:
		_heart.set("edge_color", _heart_edge_color)
		_heart.position = _heart_position
		return
	var seconds := float(now_msec) / 1000.0
	var flash := 0.5 + 0.5 * sin(seconds * TAU * HEART_HIT_FLASH_PER_S)
	_heart.set("edge_color", _heart_edge_color.lerp(HEART_HIT_EDGE_COLOR, flash))
	_heart.position = _heart_position + Vector2(sin(seconds * 71.0), cos(seconds * 53.0)) * HEART_HIT_SHAKE_PX


## 長い名前は、属性の印にかからないよう、横に縮める（縦の大きさは、場面で決めたまま）。
func _fit_name() -> void:
	var room := _attribute.position.x - _name.position.x - NAME_GAP
	var natural := _name.get_minimum_size().x * _name_scale.x
	_name.scale = Vector2(_name_scale.x * minf(1.0, room / maxf(natural, 1.0)), _name_scale.y)
