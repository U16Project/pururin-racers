extends RefCounted
## Godot が受け取った入力を診断用に記録する。ゲームの割り当ては変更しない。
const STEPS := ["右4ボタンの下", "右4ボタンの右", "右4ボタンの左", "右4ボタンの上", "L1", "R1", "L2", "R2", "SELECT", "START", "左スティック押し込み", "右スティック押し込み", "左スティック上", "左スティック下", "左スティック左", "左スティック右", "右スティック上", "右スティック下", "右スティック左", "右スティック右", "十字キー上", "十字キー下", "十字キー左", "十字キー右"]
var device := -1
var connected := false
var buttons: Dictionary = {}
var axes: Dictionary = {}
var baseline: Dictionary = {}
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var step := -1
var armed := false
var candidate: Dictionary = {}

func select_device(id: int) -> void:
	device = id
	connected = id >= 0
	buttons.clear()
	axes.clear()
	baseline.clear()
	events.clear()
	samples.clear()
	step = -1
	armed = false
	candidate.clear()

func disconnect_device(id: int) -> void:
	if id == device:
		connected = false
		armed = false
		candidate.clear()
		buttons.clear()
		axes.clear()

func start_guide() -> bool:
	if not connected or buttons.values().has(true):
		return false
	baseline = axes.duplicate()
	samples.clear()
	step = 0
	candidate.clear()
	armed = false
	return true

func is_resting() -> bool:
	if buttons.values().has(true):
		return false
	for axis in axes:
		if absf(float(axes[axis]) - float(baseline.get(axis, 0.0))) > 0.2:
			return false
	return true

func arm() -> bool:
	if not connected or step < 0 or step >= STEPS.size() or not is_resting():
		return false
	candidate.clear()
	armed = true
	return true

func record(event: InputEvent) -> void:
	if not connected or event.device != device:
		return
	var entry: Dictionary = {"elapsed_ms": Time.get_ticks_msec(), "device": device}
	var eligible := false
	if event is InputEventJoypadButton:
		buttons[event.button_index] = event.pressed
		entry.merge({"kind": "button", "index": event.button_index, "pressed": event.pressed})
		eligible = event.pressed
	elif event is InputEventJoypadMotion:
		axes[event.axis] = event.axis_value
		entry.merge({"kind": "axis", "index": event.axis, "value": event.axis_value})
		eligible = absf(event.axis_value - float(baseline.get(event.axis, 0.0))) >= 0.55
	else:
		return
	events.append(entry)
	if events.size() > 2000:
		events.pop_front()
	if armed and eligible:
		candidate = entry.duplicate()
		armed = false

func confirm() -> bool:
	if candidate.is_empty() or not connected:
		return false
	var sample := candidate.duplicate()
	sample["physical_control"] = STEPS[step]
	samples.append(sample)
	step += 1
	candidate.clear()
	return true

func skip() -> void:
	if connected and step >= 0 and step < STEPS.size():
		samples.append({"physical_control": STEPS[step], "skipped": true})
		step += 1
		candidate.clear()
		armed = false
