extends Label
## 1秒あたりのコマ数を、画面の上のまん中に小さく出す（どのレースにも置く。重さを確かめるため。見せるのは、詳細表示（F3）のときだけ）。
## 横に、1コマの処理にかかった時間（直前の区切りの中で、いちばん長かったもの）と、描く回数も出す。
## 「絵」は、操作盤と順位表の絵を組み立てるのに使った時間（1秒あたりの合計。「処理」には入らない時間）。
## 重くなったとき、処理（計算・音）の側か、絵を組み立てる側か、描く側かを見分けるため。
## コマ数は、直前の区切り（REFRESH_S）の中で実際に描いたコマを数えて出す（エンジンの値は1秒ぶんの平均で、変化が遅れて見える）。

const HudPainter := preload("res://scripts/presentation/hud_painter.gd")

const FONT_SIZE := 16
const TOP_MARGIN := 4.0
## 数字を書き換える間隔（秒）。毎コマ書き換えると、読めない。
const REFRESH_S := 0.5

var _frames := 0
var _refreshed_usec := 0
var _worst_process_ms := 0.0
var _build_usec_seen := 0


func _ready() -> void:
	name = "FpsLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP_MARGIN
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1, 0.9))
	add_theme_constant_override("outline_size", 5)
	_refreshed_usec = Time.get_ticks_usec()
	_build_usec_seen = HudPainter.build_usec_total


func _process(_delta: float) -> void:
	_worst_process_ms = maxf(_worst_process_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_frames += 1
	# 実際の時間で数える（ゴールのゆっくり演出のあいだも、正しいコマ数になるように）。
	var now := Time.get_ticks_usec()
	var elapsed_s := float(now - _refreshed_usec) / 1000000.0
	if elapsed_s < REFRESH_S:
		return
	text = status_text(
		frames_per_second(_frames, elapsed_s),
		_worst_process_ms,
		float(HudPainter.build_usec_total - _build_usec_seen) / 1000.0 / elapsed_s,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	)
	_build_usec_seen = HudPainter.build_usec_total
	_refreshed_usec = now
	_frames = 0
	_worst_process_ms = 0.0


static func frames_per_second(frames: int, elapsed_s: float) -> int:
	return roundi(float(frames) / maxf(elapsed_s, 0.001))


static func status_text(fps: int, process_ms: float, build_ms_per_s: float, draw_calls: int) -> String:
	return "%d コマ/秒　処理 %d ms　絵 %d ms/秒　描く %d 回" % [fps, roundi(process_ms), roundi(build_ms_per_s), draw_calls]
