extends RefCounted
## 育てたCPU（強化学習の頭）の計算：見たもの（数字の並び）→ 操作。
## 書き出し：lab/rl/export_brain.py が data/cpu_brains/<名前>.json を作る（数字は float32 を base64 にしたもの）。
## 計算は、層ごとに「重みとの掛け算の合計＋足す数」を出し、最後の層以外は tanh を通す。
## 速くするため、数字を4つずつ Vector4 にまとめて、まとめて掛ける（ふつうに書くより約7倍速い）。
## 操作は、操作の組（ノッチ・ライン・ブレーキ・ダッシュ・ブースト）ごとに、選べるものの中で、いちばん点の高いものを選ぶ。

var label := ""
var obs_size := 0
var action_sizes: Array = []
## 層ごと：{"rows": [出力ごとの Array[Vector4]], "bias": PackedFloat32Array, "tanh": bool, "in": 入力の数}
var _layers: Array = []


## 読み込む。読めなければ null。
static func load_file(path: String) -> RefCounted:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not data is Dictionary or int(data.get("format", 0)) != 1:
		push_error("育てたCPUを読めません: " + path)
		return null
	var net: RefCounted = load("res://scripts/cpu_brain/brain_net.gd").new()
	net.label = str(data.get("label", ""))
	net.obs_size = int(data["obs_size"])
	net.action_sizes = data["action_sizes"]
	for layer: Dictionary in data["layers"]:
		net._layers.append(_build_layer(layer))
	return net


static func _build_layer(layer: Dictionary) -> Dictionary:
	var inputs := int(layer["in"])
	var outputs := int(layer["out"])
	var weights := Marshalls.base64_to_raw(str(layer["w"])).to_float32_array()
	var rows: Array = []
	for o in outputs:
		rows.append(_pack(weights.slice(o * inputs, (o + 1) * inputs)))
	return {
		"rows": rows, "bias": Marshalls.base64_to_raw(str(layer["b"])).to_float32_array(),
		"tanh": str(layer["act"]) == "tanh", "in": inputs,
	}


## 数字の並びを、4つずつ Vector4 にまとめる（足りない分は0）。
static func _pack(values: PackedFloat32Array) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var n := values.size()
	var i := 0
	while i < n:
		out.append(Vector4(values[i], values[i + 1] if i + 1 < n else 0.0, values[i + 2] if i + 2 < n else 0.0, values[i + 3] if i + 3 < n else 0.0))
		i += 4
	return out


## 見たもの → 操作ごとの点（最後の層の出力）。
func scores(obs: PackedFloat32Array) -> PackedFloat32Array:
	var h := _pack(obs)
	var out := PackedFloat32Array()
	for layer: Dictionary in _layers:
		var rows: Array = layer["rows"]
		var bias: PackedFloat32Array = layer["bias"]
		var squash := bool(layer["tanh"])
		out = PackedFloat32Array()
		out.resize(rows.size())
		for o in rows.size():
			var row: Array[Vector4] = rows[o]
			var s := bias[o]
			for k in row.size():
				s += row[k].dot(h[k])
			out[o] = tanh(s) if squash else s
		h = _pack(out)
	return out


## 見たもの・選べる操作（ACTION_SIZES の順の 0/1）→ 操作（組ごとの番号）。
func act(obs: PackedFloat32Array, mask: PackedByteArray) -> Array:
	var points := scores(obs)
	var action: Array = []
	var offset := 0
	for n in action_sizes:
		var best := -1
		for i in int(n):
			if mask[offset + i] != 0 and (best < 0 or points[offset + i] > points[offset + best]):
				best = i
		action.append(maxi(best, 0))
		offset += int(n)
	return action
