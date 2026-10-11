extends PanelContainer
## 描くのが重い原因を探すための、試しの測定（探検モードだけに出す。原因が分かったら消す）。
## 画面に触らなくてよいように、自動で「描く細かさ」と「影」を順番に切り替えて、それぞれのコマ数（1秒あたり）を測り、表にして出す。
## 測り終わったら、もとの設定（細かさ：ふつう、影：入）に戻す。レースには入れていない。

## 描く細かさを落としたときの割合（縦・横それぞれ）。
const LOW_SCALE := 0.5
const SUN_NAME := "Sun"
const FONT_SIZE := 18
## 1つの状態を測る時間（秒）と、切り替えた直後に測らずに待つ時間（秒）。
const STEP_S := 5.0
const SETTLE_S := 1.5
## 測る状態：[名前, 細かさ, 影]。軽い状態から先に測る（重い状態への切り替えで固まっても、それまでの数字が残るように）。
const STEPS := [
	["細かさ 半分・影 切", LOW_SCALE, false],
	["細かさ ふつう・影 切", 1.0, false],
	["細かさ 半分・影 入", LOW_SCALE, true],
	["細かさ ふつう・影 入", 1.0, true],
]

var _label: Label
var _sun: DirectionalLight3D
var _step := 0
var _step_seconds := 0.0
var _frames := 0
var _measured_seconds := 0.0
var _results: Array[String] = []


func _ready() -> void:
	name = "RenderProbe"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# この部品は、場面の「UI」の下に置かれる。太陽の光は、場面の直下にある。
	_sun = get_parent().get_parent().get_node_or_null(SUN_NAME) as DirectionalLight3D
	if _sun == null:
		push_error("RenderProbe: 太陽の光（%s）が見つかりません" % SUN_NAME)
		set_process(false)
		return
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_label)
	_apply(_step)


func _process(delta: float) -> void:
	if _step >= STEPS.size():
		return
	_step_seconds += delta
	if _step_seconds >= SETTLE_S:
		_frames += 1
		_measured_seconds += delta
	if _step_seconds >= STEP_S:
		_results.append("%s：%d コマ/秒" % [STEPS[_step][0], roundi(float(_frames) / maxf(_measured_seconds, 0.001))])
		_step += 1
		_step_seconds = 0.0
		_frames = 0
		_measured_seconds = 0.0
		_apply(_step)
	var lines: Array[String] = _results.duplicate()
	lines.append(_progress_text())
	_label.text = "\n".join(lines)


## その番号の状態にする。全部終わったら、もとの設定に戻す。
func _apply(step: int) -> void:
	var done := step >= STEPS.size()
	get_viewport().scaling_3d_scale = 1.0 if done else float(STEPS[step][1])
	_sun.shadow_enabled = true if done else bool(STEPS[step][2])


func _progress_text() -> String:
	if _step >= STEPS.size():
		return "測定おわり（もとの設定に戻しました）"
	return "測定中 %d/%d：%s" % [_step + 1, STEPS.size(), STEPS[_step][0]]


func _exit_tree() -> void:
	# ほかの画面へ持ち越さない。
	get_viewport().scaling_3d_scale = 1.0
