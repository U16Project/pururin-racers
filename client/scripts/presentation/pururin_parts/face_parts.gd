extends RefCounted
## 顔（目・まゆ・口・ほっぺ・効果）と、マークの部品を作る。どれも、体の表面に沿わせた薄い面。
## source.type が "builtin" なら、こちらで形を作る。"image" なら、用意された透明背景の画像を貼る。
## 1つの部品は、1つの節（メッシュ1つ）にまとめる。目の大きさ・傾き・色などは、個体の顔の設定（face）から取る。

const Surface := preload("res://scripts/presentation/pururin_parts/pururin_surface.gd")
const PartAssets := preload("res://scripts/presentation/pururin_parts/part_assets.gd")
## こちらで作れる形（スロットごと）。
const BUILTIN_SHAPES := {
	"eyes": ["eyes_open", "eyes_lidded", "eyes_dot", "eyes_arc", "eyes_squeeze", "eyes_dizzy", "eyes_cat", "eyes_ring", "eyes_gloss"],
	"brows": ["brow"],
	"mouth": ["mouth_omega", "mouth_smile", "mouth_open", "mouth_flat", "mouth_frown", "mouth_wavy", "mouth_o", "mouth_grit", "mouth_triangle", "mouth_zigzag", "mouth_bunny"],
	"cheeks": ["cheek_ellipse", "cheek_lines", "cheek_swirl", "cheek_freckles"],
	"effect": ["effect_sweat", "effect_tears", "effect_sparkle", "effect_anger"],
	"mark": ["star", "heart", "drop", "bolt", "flower", "diamond", "moon", "swirl", "note", "paw", "snow", "clover", "dot", "ring", "sun", "plus", "sparkle", "triangle", "hexagon", "spade", "cloud", "leaf", "fish", "crown", "fire", "wave", "bone", "cherry", "ribbon", "cat"],
}
## 形ごとに、必ず要る数字。
## 目：scale＝大きさの倍率、sparkle＝星の光（0か1）、level＝上まぶたの高さ、slope＝上まぶたの傾き（−で内側が下がる）、
## lower＝下まぶたが隠す量、line＝まぶたの線の太さの倍率、bend＝弧の向き（＋で上にふくらむ）。
## まゆ：length・thickness は目の横幅を1とした大きさ、tilt_deg は＋で内側が下がる、lift は目の縦の半分を1とした高さ。
const REQUIRED_PARAMS := {
	"eyes_open": ["scale", "sparkle"],
	"eyes_lidded": ["level", "slope", "lower", "line"],
	"eyes_dot": ["scale"],
	"eyes_arc": ["bend", "scale"],
	"eyes_squeeze": [],
	"eyes_dizzy": [],
	"eyes_cat": ["scale"],
	"eyes_ring": ["scale"],
	"eyes_gloss": ["scale"],
	"brow": ["length", "thickness", "tilt_deg", "lift", "curve"],
	"mouth_omega": ["width"],
	"mouth_smile": ["width", "fang"],
	"mouth_open": ["width", "fang"],
	"mouth_flat": ["width"],
	"mouth_frown": ["width"],
	"mouth_wavy": ["width"],
	"mouth_o": ["width"],
	"mouth_grit": ["width"],
	"mouth_triangle": ["width"],
	"mouth_zigzag": ["width"],
	"mouth_bunny": ["width"],
	"cheek_ellipse": ["width", "height"],
	"cheek_lines": ["width", "height"],
	"cheek_swirl": ["width", "height"],
	"cheek_freckles": ["width", "height"],
	"effect_sweat": ["size"],
	"effect_tears": ["size"],
	"effect_sparkle": ["size"],
	"effect_anger": ["size"],
	"star": [],
	"heart": [],
	"drop": [],
	"bolt": [],
	"flower": [],
	"diamond": [],
	"moon": [],
	"swirl": [],
	"note": [],
	"paw": [],
	"snow": [],
	"clover": [],
	"dot": [],
	"ring": [],
	"sun": [],
	"plus": [],
	"sparkle": [],
	"triangle": [],
	"hexagon": [],
	"spade": [],
	"cloud": [],
	"leaf": [],
	"fish": [],
	"crown": [],
	"fire": [],
	"wave": [],
	"bone": [],
	"cherry": [],
	"ribbon": [],
	"cat": [],
}
## 形ごとに、必ず要る色。
const REQUIRED_COLORS := {
	"mouth_smile": ["fang_color"],
	"mouth_open": ["inside_color", "tongue_color", "fang_color"],
	"mouth_o": ["inside_color"],
	"mouth_grit": ["teeth_color"],
	"mouth_triangle": ["inside_color"],
	"effect_sweat": ["color"],
	"effect_tears": ["color"],
	"effect_sparkle": ["color"],
	"effect_anger": ["color"],
}
## 画像の部品に、必ず要る項目（width・height は、貼る大きさ。m）。
const REQUIRED_IMAGE_PARAMS := ["path", "width", "height"]


## 1つの部品ぶんの、重ねる面の集まり。
class Sheet:
	## 1枚ぶん：[三角形, 正面からの角度, 高さの割合, 重ねる順, 色を決める関数]
	var layers: Array = []

	func add(triangles: PackedVector2Array, yaw_deg: float, height_ratio: float, level: float, color_for: Callable) -> void:
		if not triangles.is_empty():
			layers.append([triangles, yaw_deg, height_ratio, level, color_for])


## 顔の部品を1つ作る。slot は、eyes・brows・mouth・cheeks・effect。
## face は、顔の置き方と色（色は Color に直したもの）。
static func build(slot: String, shape: Dictionary, source: Dictionary, face: Dictionary, node_name: String) -> MeshInstance3D:
	if str(source["type"]) == "image":
		return _image_patch(shape, source, 0.0, _slot_height(slot, face), node_name)
	var sheet := Sheet.new()
	match slot:
		"eyes": _eyes(sheet, source, face)
		"brows": _brows(sheet, source, face)
		"mouth": _mouth(sheet, source, face)
		"cheeks": _cheeks(sheet, source, face)
		"effect": _effect(sheet, source, face)
	return _sheet_node(shape, sheet, node_name)


## マーク。mark は、置き方（yaw_deg、height_ratio、size＝中心から端まで、color）。
static func build_mark(shape: Dictionary, source: Dictionary, mark: Dictionary, node_name: String) -> MeshInstance3D:
	var size := float(mark["size"])
	if str(source["type"]) == "image":
		var sized := source.duplicate()
		sized["width"] = size * 2.0
		sized["height"] = size * 2.0
		# 表面の左右は、外から見ると反対になる。マークは、外から見て正しい向きにする。
		var picture := _image_patch(shape, sized, float(mark["yaw_deg"]), float(mark["height_ratio"]), node_name)
		var flipped := picture.material_override as StandardMaterial3D
		flipped.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		flipped.uv1_offset = Vector3(1.0, 0.0, 0.0)
		return picture
	var color: Color = mark["color"]
	var light := color.lightened(0.55)
	var yaw := float(mark["yaw_deg"])
	var height := float(mark["height_ratio"])
	var solid := func(_p: Vector2) -> Color: return color
	var lighter := func(_p: Vector2) -> Color: return light
	var sheet := Sheet.new()
	match str(source["shape"]):
		"star":
			sheet.add(_fill(_star_outline(Vector2.ZERO, size, 5, 0.45), Vector2.ZERO), yaw, height, 1.0, solid)
		"heart":
			sheet.add(_fill(_heart_outline(size), Vector2(0.0, size * 0.1)), yaw, height, 1.0, solid)
		"drop":
			sheet.add(_fill(_drop_outline(size / 1.4), Vector2(0.0, -size * 0.3)), yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2(-size * 0.22, -size * 0.35), size * 0.14), yaw, height, 2.0, lighter)
		"bolt":
			# いなずま：右上から左下へ下りる板と、そこから左下へのびる、とがった先。
			var slab := PackedVector2Array([Vector2(-0.05, 1.0), Vector2(0.5, 1.0), Vector2(0.08, 0.12), Vector2(-0.55, -0.12)])
			var spike := PackedVector2Array([Vector2(-0.12, 0.05), Vector2(0.55, 0.28), Vector2(-0.32, -1.0)])
			for index in slab.size():
				slab[index] *= size
			for index in spike.size():
				spike[index] *= size
			var triangles := _fill(slab, (slab[0] + slab[1] + slab[2] + slab[3]) * 0.25)
			triangles.append_array(_fill(spike, (spike[0] + spike[1] + spike[2]) / 3.0))
			sheet.add(triangles, yaw, height, 1.0, solid)
		"flower":
			# 花びら5枚と、まん中の丸。
			var outline := PackedVector2Array()
			for index in 60:
				var angle := PI * 0.5 + TAU * float(index) / 60.0
				outline.append(Vector2(cos(angle), sin(angle)) * size * (0.5 + 0.5 * absf(cos(2.5 * (angle - PI * 0.5)))))
			sheet.add(_fill(outline, Vector2.ZERO), yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2.ZERO, size * 0.24), yaw, height, 2.0, lighter)
		"diamond":
			# ひし形の宝石。上の面を、少し明るくする。
			var corners := [Vector2(0.0, size), Vector2(size * 0.72, size * 0.1), Vector2(0.0, -size), Vector2(-size * 0.72, size * 0.1)]
			var outline := PackedVector2Array()
			for index in 4:
				for step in 4:
					outline.append((corners[index] as Vector2).lerp(corners[(index + 1) % 4], float(step) / 4.0))
			sheet.add(_fill(outline, Vector2.ZERO), yaw, height, 1.0, solid)
			sheet.add(PackedVector2Array([Vector2(0.0, size * 0.8), Vector2(size * 0.5, size * 0.14), Vector2(-size * 0.5, size * 0.14)]), yaw, height, 2.0, lighter)
		"moon":
			# 三日月：大きい丸から、右にずらした丸を抜いた形。
			var tip_x := (1.0 - 0.64 + 0.2025) / 0.9
			var outer_from := atan2(sqrt(1.0 - tip_x * tip_x), tip_x)
			var inner_from := atan2(sqrt(1.0 - tip_x * tip_x), tip_x - 0.45)
			var triangles := PackedVector2Array()
			var previous_outer := Vector2.ZERO
			var previous_inner := Vector2.ZERO
			for index in 25:
				var t := float(index) / 24.0
				var outer_angle := lerpf(outer_from, TAU - outer_from, t)
				var inner_angle := lerpf(inner_from, TAU - inner_from, t)
				var outer := Vector2(cos(outer_angle), sin(outer_angle)) * size
				var inner := (Vector2(0.45, 0.0) + Vector2(cos(inner_angle), sin(inner_angle)) * 0.8) * size
				if index > 0:
					triangles.append_array(PackedVector2Array([previous_outer, outer, inner, previous_outer, inner, previous_inner]))
				previous_outer = outer
				previous_inner = inner
			# 月の太い所が、マークのまん中に来るように、少し右へ寄せる。
			sheet.add(_moved(triangles, Vector2(size * 0.25, 0.0)), yaw, height, 1.0, solid)
		"swirl":
			# うずまき（風）。
			var spiral := PackedVector2Array()
			for index in 49:
				var t := float(index) / 48.0
				spiral.append(Vector2(cos(t * TAU * 1.7 + PI), sin(t * TAU * 1.7 + PI)) * size * (0.12 + 0.76 * t))
			sheet.add(_stroke(spiral, size * 0.11), yaw, height, 1.0, solid)
		"note":
			# 音符：丸い玉と、まっすぐの棒と、旗。
			var head := Surface.ellipse_triangles(Vector2(-size * 0.25, -size * 0.6), size * 0.36, size * 0.27)
			# 長い線は、体の丸みに沿うように、細かく分ける。
			var stem := PackedVector2Array()
			for index in 8:
				stem.append(Vector2(size * 0.08, lerpf(-size * 0.55, size * 0.85, float(index) / 7.0)))
			head.append_array(_stroke(stem, size * 0.08))
			var flag := PackedVector2Array()
			for index in 9:
				var t := float(index) / 8.0
				flag.append(Vector2(size * 0.08 + size * 0.45 * t, size * (0.85 - 0.25 * t - 0.3 * t * t)))
			head.append_array(_stroke(flag, size * 0.08))
			sheet.add(head, yaw, height, 1.0, solid)
		"paw":
			# 肉球：大きい玉と、上に小さい玉4つ。
			var pads := Surface.ellipse_triangles(Vector2(0.0, -size * 0.3), size * 0.45, size * 0.38)
			for index in 4:
				var angle := deg_to_rad(lerpf(145.0, 35.0, float(index) / 3.0))
				pads.append_array(Surface.ellipse_triangles(Vector2(cos(angle), sin(angle)) * size * 0.68 + Vector2(0.0, -size * 0.12), size * 0.17, size * 0.21))
			sheet.add(pads, yaw, height, 1.0, solid)
		"snow":
			# 雪の結晶：6本の線と、それぞれの枝。
			var lines := PackedVector2Array()
			for index in 6:
				var direction := Vector2.from_angle(PI * 0.5 + TAU * float(index) / 6.0)
				lines.append_array(_stroke(PackedVector2Array([Vector2.ZERO, direction * size]), size * 0.07))
				var fork := direction * size * 0.58
				for turn: float in [0.7, -0.7]:
					lines.append_array(_stroke(PackedVector2Array([fork, fork + direction.rotated(turn) * size * 0.3]), size * 0.06))
			sheet.add(lines, yaw, height, 1.0, solid)
		"clover":
			# 四つ葉：ハートを4枚、まん中から外へ向けて並べる。
			var leaves := PackedVector2Array()
			var leaf := _heart_outline(size * 0.48)
			for index in 4:
				var angle := PI * 0.25 + PI * 0.5 * float(index)
				var turned := PackedVector2Array()
				for point in leaf:
					# ハートのとがった先（下）を、まん中へ向ける。
					turned.append((point + Vector2(0.0, size * 0.42)).rotated(angle - PI * 0.5))
				leaves.append_array(_fill(turned, Vector2.from_angle(angle) * size * 0.45))
			sheet.add(leaves, yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2.ZERO, size * 0.14), yaw, height, 2.0, lighter)
		"dot":
			sheet.add(_disc(Vector2.ZERO, size * 0.62), yaw, height, 1.0, solid)
		"ring":
			sheet.add(_stroke(_circle(Vector2.ZERO, size * 0.68, 40), size * 0.2), yaw, height, 1.0, solid)
		"sun":
			# 太陽：まん中の丸と、まわりの8本の光。
			var rays := PackedVector2Array()
			for index in 8:
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				var across := direction.orthogonal() * size * 0.13
				rays.append_array(PackedVector2Array([direction * size * 0.58 + across, direction * size * 0.58 - across, direction * size]))
			sheet.add(rays, yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2.ZERO, size * 0.46), yaw, height, 1.0, solid)
		"plus":
			var cross := Surface.rect_triangles(Rect2(-size * 0.78, -size * 0.17, size * 1.56, size * 0.34))
			cross.append_array(Surface.rect_triangles(Rect2(-size * 0.17, -size * 0.78, size * 0.34, size * 1.56)))
			sheet.add(cross, yaw, height, 1.0, solid)
		"sparkle":
			# キラッ：4つのとがった先の星と、小さい星。
			sheet.add(_fill(_star_outline(Vector2(-size * 0.1, -size * 0.05), size * 0.85, 4, 0.28), Vector2(-size * 0.1, -size * 0.05)), yaw, height, 1.0, solid)
			sheet.add(_fill(_star_outline(Vector2(size * 0.62, size * 0.6), size * 0.3, 4, 0.3), Vector2(size * 0.62, size * 0.6)), yaw, height, 1.0, solid)
		"triangle":
			sheet.add(_fill(_polygon(size * 0.95, 3, PI * 0.5), Vector2(0.0, 0.0)), yaw, height, 1.0, solid)
		"hexagon":
			sheet.add(_fill(_polygon(size * 0.82, 6, PI * 0.5), Vector2.ZERO), yaw, height, 1.0, solid)
			sheet.add(_fill(_polygon(size * 0.42, 6, PI * 0.5), Vector2.ZERO), yaw, height, 2.0, lighter)
		"spade":
			# スペード：さかさまのハートと、下の足。
			var spade := PackedVector2Array()
			for point in _heart_outline(size * 0.72):
				spade.append(Vector2(point.x, -point.y + size * 0.15))
			var triangles := _fill(spade, Vector2(0.0, size * 0.1))
			triangles.append_array(PackedVector2Array([Vector2(0.0, -size * 0.2), Vector2(size * 0.3, -size * 0.9), Vector2(-size * 0.3, -size * 0.9)]))
			sheet.add(triangles, yaw, height, 1.0, solid)
		"cloud":
			# 雲：丸を4つと、平たい底。
			var puffs := _disc(Vector2(-size * 0.45, -size * 0.15), size * 0.38)
			puffs.append_array(_disc(Vector2(0.0, size * 0.18), size * 0.5))
			puffs.append_array(_disc(Vector2(size * 0.48, -size * 0.1), size * 0.4))
			puffs.append_array(Surface.ellipse_triangles(Vector2(0.0, -size * 0.3), size * 0.85, size * 0.25))
			sheet.add(puffs, yaw, height, 1.0, solid)
		"leaf":
			# 葉っぱ：ななめの、両はしがとがった形と、まん中のすじ。
			var blade := PackedVector2Array()
			for index in 32:
				var t := TAU * float(index) / 32.0
				blade.append(Vector2(cos(t) * size, sin(t) * size * 0.45 * absf(sin(t)) + sin(t) * size * 0.08))
			var turn := PI * 0.25
			sheet.add(_rotated(_fill(blade, Vector2.ZERO), turn), yaw, height, 1.0, solid)
			sheet.add(_rotated(_stroke(PackedVector2Array([Vector2(-size * 0.8, 0.0), Vector2(0.0, 0.0), Vector2(size * 0.8, 0.0)]), size * 0.06), turn), yaw, height, 2.0, lighter)
		"fish":
			# 魚：だ円の体と、三角のしっぽと、目。
			var fish := Surface.ellipse_triangles(Vector2(size * 0.15, 0.0), size * 0.62, size * 0.4)
			fish.append_array(PackedVector2Array([Vector2(-size * 0.35, 0.0), Vector2(-size * 0.92, size * 0.42), Vector2(-size * 0.92, -size * 0.42)]))
			sheet.add(fish, yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2(size * 0.45, size * 0.08), size * 0.09), yaw, height, 2.0, lighter)
		"crown":
			# かんむり：下の帯と、3つのとがった山。
			var crown := Surface.rect_triangles(Rect2(-size * 0.8, -size * 0.55, size * 1.6, size * 0.5))
			for peak: Vector3 in [Vector3(-0.55, 0.5, 0.0), Vector3(0.0, 0.72, 0.0), Vector3(0.55, 0.5, 0.0)]:
				var corners := [Vector2((peak.x - 0.27) * size, -size * 0.06), Vector2((peak.x + 0.27) * size, -size * 0.06), Vector2(peak.x * size, peak.y * size)]
				var outline := PackedVector2Array()
				for index in 3:
					for step in 4:
						outline.append((corners[index] as Vector2).lerp(corners[(index + 1) % 3], float(step) / 4.0))
				crown.append_array(_fill(outline, Vector2(peak.x * size, peak.y * size * 0.3)))
			sheet.add(crown, yaw, height, 1.0, solid)
			for x: float in [-0.42, 0.0, 0.42]:
				sheet.add(_disc(Vector2(x * size, -size * 0.3), size * 0.1), yaw, height, 2.0, lighter)
		"fire":
			# ほのお：しずくを上下にした形を2つ重ねる（中は明るく）。
			var outer := PackedVector2Array()
			for point in _drop_outline(size / 1.4):
				outer.append(point)
			sheet.add(_fill(outer, Vector2(0.0, -size * 0.3)), yaw, height, 1.0, solid)
			var inner := PackedVector2Array()
			for point in _drop_outline(size / 2.6):
				inner.append(point + Vector2(0.0, -size * 0.32))
			sheet.add(_fill(inner, Vector2(0.0, -size * 0.5)), yaw, height, 2.0, lighter)
		"wave":
			# 波：うねる線を2本。
			var waves := PackedVector2Array()
			for row: float in [0.3, -0.3]:
				var line := PackedVector2Array()
				for index in 25:
					var t := float(index) / 24.0
					line.append(Vector2(lerpf(-size * 0.85, size * 0.85, t), size * row + sin(t * TAU * 1.5) * size * 0.16))
				waves.append_array(_stroke(line, size * 0.13))
			sheet.add(waves, yaw, height, 1.0, solid)
		"bone":
			# ほね：ななめの棒と、両はしに丸2つずつ。
			var bone := Surface.rect_triangles(Rect2(-size * 0.6, -size * 0.13, size * 1.2, size * 0.26))
			for end: float in [-1.0, 1.0]:
				for up: float in [-1.0, 1.0]:
					bone.append_array(_disc(Vector2(end * size * 0.62, up * size * 0.17), size * 0.2))
			sheet.add(_rotated(bone, PI * 0.2), yaw, height, 1.0, solid)
		"cherry":
			# さくらんぼ：実が2つと、くきと、葉。
			var fruit := _disc(Vector2(-size * 0.38, -size * 0.45), size * 0.34)
			fruit.append_array(_disc(Vector2(size * 0.4, -size * 0.35), size * 0.34))
			sheet.add(fruit, yaw, height, 1.0, solid)
			var stems := _stroke(PackedVector2Array([Vector2(-size * 0.38, -size * 0.2), Vector2(-size * 0.15, size * 0.35), Vector2(size * 0.12, size * 0.75)]), size * 0.07)
			stems.append_array(_stroke(PackedVector2Array([Vector2(size * 0.4, -size * 0.1), Vector2(size * 0.3, size * 0.4), Vector2(size * 0.12, size * 0.75)]), size * 0.07))
			sheet.add(stems, yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2(-size * 0.48, -size * 0.35), size * 0.09), yaw, height, 2.0, lighter)
			sheet.add(_disc(Vector2(size * 0.3, -size * 0.25), size * 0.09), yaw, height, 2.0, lighter)
		"ribbon":
			# リボン：左右の三角と、まん中の結び目。
			for x: float in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(0.0, 0.0), Vector2(x * size * 0.9, size * 0.5), Vector2(x * size * 0.9, -size * 0.5)])
				sheet.add(_fill(wing, Vector2(x * size * 0.6, 0.0)), yaw, height, 1.0, solid)
			sheet.add(_disc(Vector2.ZERO, size * 0.22), yaw, height, 2.0, lighter)
		"cat":
			# ねこの顔の形：丸い頭と、三角の耳2つ。
			var cat := Surface.ellipse_triangles(Vector2(0.0, -size * 0.12), size * 0.75, size * 0.62)
			for x: float in [-1.0, 1.0]:
				cat.append_array(PackedVector2Array([Vector2(x * size * 0.72, size * 0.15), Vector2(x * size * 0.2, size * 0.42), Vector2(x * size * 0.68, size * 0.9)]))
			sheet.add(cat, yaw, height, 1.0, solid)
	# 表面の左右は、外から見ると反対になる。外から見て正しい向きになるよう、左右を入れ替える。
	for layer: Array in sheet.layers:
		layer[0] = _mirrored(layer[0])
		var color_for: Callable = layer[4]
		layer[4] = func(point: Vector2) -> Color: return color_for.call(Vector2(-point.x, point.y))
	return _sheet_node(shape, sheet, node_name)


## 左右を入れ替えた三角形（面の表が変わらないよう、点の順も入れ替える）。
static func _mirrored(triangles: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(0, triangles.size(), 3):
		result.append(Vector2(-triangles[index].x, triangles[index].y))
		result.append(Vector2(-triangles[index + 2].x, triangles[index + 2].y))
		result.append(Vector2(-triangles[index + 1].x, triangles[index + 1].y))
	return result


## 画像を貼るときの、スロットごとの高さ。
static func _slot_height(slot: String, face: Dictionary) -> float:
	match slot:
		"mouth": return float(face["mouth_height_ratio"])
		"cheeks": return float(face["cheek_height_ratio"])
	return float(face["eye_height_ratio"])


# ---------------------------------------------------------------- 目

static func _eyes(sheet: Sheet, source: Dictionary, face: Dictionary) -> void:
	var kind := str(source["shape"])
	var dark: Color = face["eye_colors"][0]
	var bright: Color = face["eye_colors"][1]
	for side: float in [1.0, -1.0]:
		var yaw := float(face["eye_yaw_deg"]) * side
		var height := float(face["eye_height_ratio"])
		# 目の傾き（＋で、目じりが上がる）。左右で鏡写しにする。
		var angle := deg_to_rad(float(face["eye_tilt_deg"])) * side
		# 気持ちのまぶた（lid）：目の形はそのままで、上（と下）を隠して、怒る・悲しい・がんばるを出す。
		var lid: Dictionary = source.get("lid", {})
		var box := {}
		var add := func(triangles: PackedVector2Array, level: float, color_for: Callable) -> void:
			if not lid.is_empty():
				triangles = _lid_clip(triangles, lid, side, box)
			sheet.add(_rotated(triangles, angle), yaw, height, level, func(point: Vector2) -> Color: return color_for.call(point.rotated(-angle)))
		var w := float(face["eye_size"][0])
		var h := float(face["eye_size"][1])
		var solid_dark := func(_p: Vector2) -> Color: return dark
		match kind:
			"eyes_open":
				w *= float(source["scale"])
				h *= float(source["scale"])
				add.call(Surface.ellipse_triangles(Vector2.ZERO, w, h), 1.0, _iris_color(w, h, dark, bright))
				var shine := PackedVector2Array()
				if float(source["sparkle"]) > 0.0:
					# 星の形の光と、小さい光を2つ。
					shine.append_array(_fill(_star_outline(Vector2(-w * 0.2, h * 0.32), w * 0.5, 4, 0.36), Vector2(-w * 0.2, h * 0.32)))
					shine.append_array(_disc(Vector2(w * 0.38, h * 0.38), w * 0.13))
				else:
					shine.append_array(Surface.ellipse_triangles(Vector2(-w * 0.28, h * 0.42), w * 0.34, h * 0.26))
				shine.append_array(Surface.ellipse_triangles(Vector2(w * 0.3, -h * 0.5), w * 0.2, h * 0.12))
				add.call(shine, 2.0, _shine_color())
				add.call(_lashes(w, h, side, int(face["eye_lashes"]), func(x: float) -> float: return h * 2.0), 3.0, solid_dark)
			"eyes_lidded":
				var level := float(source["level"])
				var slope := float(source["slope"])
				# 上まぶた（内側＝顔の中心側で inward が +1）と、下まぶた。
				var top := func(x: float) -> float: return h * (level + slope * (-x * side / w))
				var bottom := -h * (1.0 - float(source["lower"]))
				var eye := Surface.ellipse_triangles(Vector2.ZERO, w, h)
				for index in eye.size():
					eye[index].y = maxf(minf(eye[index].y, top.call(eye[index].x)), minf(bottom, top.call(eye[index].x)))
				add.call(eye, 1.0, _iris_color(w, h, dark, bright))
				var shine := Surface.ellipse_triangles(Vector2(-w * 0.28, h * 0.42), w * 0.34, h * 0.26)
				shine.append_array(Surface.ellipse_triangles(Vector2(w * 0.3, -h * 0.5), w * 0.2, h * 0.12))
				for index in shine.size():
					shine[index].y = maxf(minf(shine[index].y, top.call(shine[index].x) - h * 0.08), minf(bottom + h * 0.06, top.call(shine[index].x) - h * 0.08))
				add.call(shine, 2.0, _shine_color())
				var lines := PackedVector2Array()
				if float(source["line"]) > 0.0:
					lines.append_array(_stroke(PackedVector2Array([Vector2(-w * 1.05, top.call(-w * 1.05)), Vector2(w * 1.05, top.call(w * 1.05))]), w * 0.16 * float(source["line"])))
				if float(source["lower"]) > 0.0:
					lines.append_array(_stroke(PackedVector2Array([Vector2(-w * 0.8, bottom), Vector2(w * 0.8, bottom)]), w * 0.09))
				lines.append_array(_lashes(w, h, side, int(face["eye_lashes"]), top))
				add.call(lines, 3.0, solid_dark)
			"eyes_dot":
				var radius := w * float(source["scale"])
				add.call(Surface.ellipse_triangles(Vector2.ZERO, radius, radius * 1.15), 1.0, solid_dark)
				add.call(_disc(Vector2(-radius * 0.3, radius * 0.4), radius * 0.28), 2.0, func(_p: Vector2) -> Color: return Color.WHITE)
			"eyes_arc":
				# 閉じた目。bend が＋なら上にふくらむ弧（笑った目）、−なら下にふくらむ弧（ほっこり）、0なら横線。
				var bend := float(source["bend"])
				w *= float(source["scale"])
				h *= float(source["scale"])
				var arc := PackedVector2Array()
				for index in 13:
					var t := float(index) / 12.0
					arc.append(Vector2(lerpf(-w, w, t), bend * (sin(t * PI) * h * 0.5 - h * 0.2)))
				add.call(_stroke(arc, w * 0.2), 1.0, solid_dark)
			"eyes_squeeze":
				# ぎゅっとつぶった目（＞＜）。とがった所が、顔の中心側。
				var chevron := PackedVector2Array([Vector2(side * w * 0.85, h * 0.5), Vector2(-side * w * 0.7, 0.0), Vector2(side * w * 0.85, -h * 0.5)])
				add.call(_stroke(chevron, w * 0.2), 1.0, solid_dark)
			"eyes_dizzy":
				# ぐるぐる目。
				var spiral := PackedVector2Array()
				for index in 41:
					var t := float(index) / 40.0
					spiral.append(Vector2(cos(t * TAU * 2.2), sin(t * TAU * 2.2)) * w * 0.95 * t)
				add.call(_stroke(spiral, w * 0.12), 1.0, solid_dark)
			"eyes_cat":
				# ねこ目：丸い目に、たての細いひとみ。
				w *= float(source["scale"])
				h *= float(source["scale"])
				add.call(Surface.ellipse_triangles(Vector2.ZERO, w, h), 1.0, func(point: Vector2) -> Color: return bright.lerp(dark, 0.35 + 0.35 * clampf(point.y / h, 0.0, 1.0)))
				add.call(Surface.ellipse_triangles(Vector2.ZERO, w * 0.2, h * 0.86), 2.0, solid_dark)
				add.call(Surface.ellipse_triangles(Vector2(-w * 0.38, h * 0.4), w * 0.2, h * 0.15), 3.0, _shine_color())
				add.call(_lashes(w, h, side, int(face["eye_lashes"]), func(x: float) -> float: return h * 2.0), 3.0, solid_dark)
			"eyes_ring":
				# びっくり目：白い目に、小さい黒目と、ふちの線。
				w *= float(source["scale"])
				h *= float(source["scale"])
				add.call(Surface.ellipse_triangles(Vector2.ZERO, w, h), 1.0, func(_p: Vector2) -> Color: return Color.WHITE)
				add.call(_disc(Vector2(0.0, -h * 0.05), w * 0.38), 2.0, solid_dark)
				add.call(_disc(Vector2(-w * 0.12, h * 0.1), w * 0.11), 3.0, func(_p: Vector2) -> Color: return Color.WHITE)
				var rim := PackedVector2Array()
				for index in 33:
					var turn := TAU * float(index) / 32.0
					rim.append(Vector2(cos(turn) * w, sin(turn) * h))
				add.call(_stroke(rim, w * 0.1), 3.0, solid_dark)
			"eyes_gloss":
				# 黒目がち：たて長の、つやのある黒い目に、大きい光と小さい光。
				w *= float(source["scale"])
				h *= float(source["scale"]) * 1.25
				add.call(Surface.ellipse_triangles(Vector2.ZERO, w * 0.85, h), 1.0, func(point: Vector2) -> Color: return dark.darkened(0.45).lerp(dark, clampf(-point.y / h, 0.0, 1.0) * 0.6))
				var gloss := Surface.ellipse_triangles(Vector2(-w * 0.25, h * 0.38), w * 0.34, h * 0.3)
				gloss.append_array(_disc(Vector2(w * 0.32, -h * 0.4), w * 0.15))
				add.call(gloss, 2.0, func(_p: Vector2) -> Color: return Color.WHITE)
				add.call(_lashes(w * 0.85, h, side, int(face["eye_lashes"]), func(x: float) -> float: return h * 2.0), 3.0, solid_dark)
		if not lid.is_empty() and not box.is_empty():
			# まぶたの線。
			var top_left := _lid_top(lid, side, box, box["left"] - box["w"] * 0.08)
			var top_right := _lid_top(lid, side, box, box["right"] + box["w"] * 0.08)
			add_line(sheet, PackedVector2Array([top_left, top_right]), box["w"] * 0.16, yaw, height, angle, dark)



## まぶたの線を1本足す（まぶたで隠さずに）。
static func add_line(sheet: Sheet, line: PackedVector2Array, thickness: float, yaw: float, height: float, angle: float, color: Color) -> void:
	sheet.add(_rotated(_stroke(line, thickness), angle), yaw, height, 4.0, func(_p: Vector2) -> Color: return color)


## 上まぶたの、x での高さ。level＝目の高さに対する位置（1で上のはし）、slope＝＋で内側が上がる（−で内側が下がる＝怒り）。
static func _lid_top(lid: Dictionary, side: float, box: Dictionary, x: float) -> Vector2:
	var half_w: float = box["w"] * 0.5
	var inward: float = -(x - float(box["cx"])) * side / half_w
	return Vector2(x, box["cy"] + box["h"] * 0.5 * (float(lid["level"]) + float(lid["slope"]) * inward))


## 目の絵を、まぶたで隠す（上まぶたより上と、下まぶたより下を、まぶたの線へ寄せる）。
## box は、はじめの絵（目の本体）の大きさを覚えておく入れ物。
static func _lid_clip(triangles: PackedVector2Array, lid: Dictionary, side: float, box: Dictionary) -> PackedVector2Array:
	if box.is_empty():
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point in triangles:
			low = low.min(point)
			high = high.max(point)
		box["left"] = low.x
		box["right"] = high.x
		box["w"] = high.x - low.x
		box["h"] = high.y - low.y
		box["cx"] = (low.x + high.x) * 0.5
		box["cy"] = (low.y + high.y) * 0.5
	var bottom: float = box["cy"] - box["h"] * 0.5 * (1.0 - 2.0 * float(lid["lower"]))
	var clipped := PackedVector2Array()
	for point in triangles:
		var top := _lid_top(lid, side, box, point.x).y
		clipped.append(Vector2(point.x, maxf(minf(point.y, top), minf(bottom, top))))
	return clipped


## 目の色：上が暗く、下が明るい。ふちは暗い。
static func _iris_color(w: float, h: float, dark: Color, bright: Color) -> Callable:
	return func(point: Vector2) -> Color:
		var edge := Vector2(point.x / w, point.y / h).length()
		var vertical := clampf(0.5 - point.y / (h * 2.0), 0.0, 1.0)
		return dark.lerp(bright, smoothstep(0.25, 1.0, vertical) * (1.0 - smoothstep(0.82, 1.0, edge)))


## 目の光：上は白、下は水色。
static func _shine_color() -> Callable:
	return func(point: Vector2) -> Color: return Color.WHITE if point.y > 0.0 else Color(0.75, 0.9, 1.0)


## まつ毛。目じりの上に、count 本。top は、上まぶたの高さ（それより上には生やさない）。
static func _lashes(w: float, h: float, side: float, count: int, top: Callable) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	for index in count:
		var x := side * w * (0.92 - 0.24 * float(index))
		var start := Vector2(x, minf(h * sqrt(maxf(1.0 - pow(x / w, 2.0), 0.0)), float(top.call(x))))
		var direction := Vector2(side * (0.85 - 0.25 * float(index)), 0.6).normalized()
		triangles.append_array(_stroke(PackedVector2Array([start, start + direction * w * 0.42]), w * 0.07))
	return triangles


# ---------------------------------------------------------------- まゆ

static func _brows(sheet: Sheet, source: Dictionary, face: Dictionary) -> void:
	var w := float(face["eye_size"][0])
	var h := float(face["eye_size"][1])
	var dark: Color = face["eye_colors"][0]
	var length := float(source["length"]) * w * 2.0
	var rise := tan(deg_to_rad(float(source["tilt_deg"])))
	for side: float in [1.0, -1.0]:
		var line := PackedVector2Array()
		for index in 9:
			var t := float(index) / 8.0
			# along は、顔の中心側（−）から外側（＋）へ。tilt が＋なら、内側が下がる。
			var along := lerpf(-length * 0.5, length * 0.5, t)
			line.append(Vector2(side * along, h * float(source["lift"]) + rise * along + float(source["curve"]) * w * sin(t * PI)))
		sheet.add(_stroke(line, float(source["thickness"]) * w), float(face["eye_yaw_deg"]) * side, float(face["eye_height_ratio"]), 4.0, func(_p: Vector2) -> Color: return dark)


# ---------------------------------------------------------------- 口

static func _mouth(sheet: Sheet, source: Dictionary, face: Dictionary) -> void:
	var width := float(source["width"])
	var line_color: Color = face["eye_colors"][0]
	var height := float(face["mouth_height_ratio"])
	var thickness := 0.0075
	var line := func(_p: Vector2) -> Color: return line_color
	# 気持ち（mood）：口の形はそのままで、上下を返す（flip）・大きさ（scale）・たての縮み（squash）で、表情を出す。
	var mood: Dictionary = source.get("mood", {})
	var add := func(triangles: PackedVector2Array, level: float, color_for: Callable) -> void:
		if not mood.is_empty():
			triangles = _mood_shape(triangles, mood, width)
		sheet.add(triangles, 0.0, height, level, color_for)
	match str(source["shape"]):
		"mouth_omega":
			# 小さい「ω」：2つの弧。
			var triangles := PackedVector2Array()
			for half: float in [-1.0, 1.0]:
				var arc := PackedVector2Array()
				for index in 11:
					var t := float(index) / 10.0
					arc.append(Vector2(half * width * 0.5 * t, -sin(t * PI) * width * 0.2))
				triangles.append_array(_stroke(arc, thickness))
			add.call(triangles, 1.0, line)
		"mouth_smile":
			add.call(_stroke(_arc_line(width, -width * 0.24, 0.0), thickness), 1.0, line)
			_add_fang(add, source, Vector2(float(source["fang"]) * width * 0.24, -width * 0.14), width)
		"mouth_open":
			# 開いた口：上がまっすぐ、下が丸い。中に舌。
			var depth := width * 0.6
			var outline := PackedVector2Array()
			for index in 25:
				var t := float(index) / 24.0
				outline.append(Vector2(cos(PI + t * PI) * width * 0.5, -sin(t * PI) * depth))
			var inside := Color(str(source["inside_color"]))
			var tongue := Color(str(source["tongue_color"]))
			add.call(_fill(outline, Vector2(0.0, -depth * 0.4)), 1.0, func(_p: Vector2) -> Color: return inside)
			add.call(Surface.ellipse_triangles(Vector2(0.0, -depth * 0.64), width * 0.22, depth * 0.26), 2.0, func(_p: Vector2) -> Color: return tongue)
			outline.append(outline[0])
			add.call(_stroke(outline, thickness * 0.8), 3.0, line)
			_add_fang(add, source, Vector2(float(source["fang"]) * width * 0.24, 0.0), width)
		"mouth_flat":
			add.call(_stroke(PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0)]), thickness), 1.0, line)
		"mouth_frown":
			add.call(_stroke(_arc_line(width, width * 0.22, -width * 0.1), thickness), 1.0, line)
		"mouth_wavy":
			var wave := PackedVector2Array()
			for index in 25:
				var t := float(index) / 24.0
				wave.append(Vector2(lerpf(-width * 0.5, width * 0.5, t), sin(t * TAU * 1.5) * width * 0.09))
			add.call(_stroke(wave, thickness), 1.0, line)
		"mouth_o":
			var inside := Color(str(source["inside_color"]))
			var ring := PackedVector2Array()
			for index in 21:
				var angle := TAU * float(index) / 20.0
				ring.append(Vector2(cos(angle) * width * 0.5, sin(angle) * width * 0.6 - width * 0.3))
			add.call(Surface.ellipse_triangles(Vector2(0.0, -width * 0.3), width * 0.5, width * 0.6), 1.0, func(_p: Vector2) -> Color: return inside)
			add.call(_stroke(ring, thickness * 0.8), 2.0, line)
		"mouth_grit":
			# 食いしばった歯：角の丸い四角に、歯の線。
			var half_w := width * 0.5
			var half_h := width * 0.2
			var corner := half_h * 0.7
			var outline := PackedVector2Array()
			for quarter in 4:
				var center := Vector2((half_w - corner) * (1.0 if quarter in [0, 3] else -1.0), (half_h - corner) * (1.0 if quarter < 2 else -1.0) - half_h)
				for index in 6:
					var angle := PI * 0.5 * (float(quarter) + float(index) / 5.0)
					outline.append(center + Vector2(cos(angle), sin(angle)) * corner)
			var teeth := Color(str(source["teeth_color"]))
			add.call(_fill(outline, Vector2(0.0, -half_h)), 1.0, func(_p: Vector2) -> Color: return teeth)
			outline.append(outline[0])
			var lines := _stroke(outline, thickness * 0.8)
			for index in 3:
				var x := lerpf(-half_w, half_w, float(index + 1) / 4.0)
				lines.append_array(Surface.stroke_triangles(PackedVector2Array([Vector2(x, 0.0), Vector2(x, -half_h * 2.0)]), thickness * 0.45))
			add.call(lines, 2.0, line)
		"mouth_triangle":
			# 小さい「▽」の口。
			var inside := Color(str(source["inside_color"]))
			var corners := [Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0), Vector2(0.0, -width * 0.62)]
			var outline := PackedVector2Array()
			for index in 3:
				for step in 4:
					outline.append((corners[index] as Vector2).lerp(corners[(index + 1) % 3], float(step) / 4.0))
			add.call(_fill(outline, Vector2(0.0, -width * 0.2)), 1.0, func(_p: Vector2) -> Color: return inside)
			outline.append(outline[0])
			add.call(_stroke(outline, thickness * 0.8), 2.0, line)
		"mouth_zigzag":
			# ギザギザの口（歯をくいしばったような線）。
			var zigzag := PackedVector2Array()
			for index in 9:
				zigzag.append(Vector2(lerpf(-width * 0.5, width * 0.5, float(index) / 8.0), -width * 0.1 * float(index % 2)))
			add.call(_stroke(zigzag, thickness), 1.0, line)
		"mouth_bunny":
			# うさぎ口（ㅅ）：まん中から左右下へ下りる2本と、上へのびる短い線。
			var bunny := _stroke(PackedVector2Array([Vector2(-width * 0.42, -width * 0.42), Vector2(-width * 0.18, -width * 0.18), Vector2(0.0, -width * 0.08)]), thickness)
			bunny.append_array(_stroke(PackedVector2Array([Vector2(0.0, -width * 0.08), Vector2(width * 0.18, -width * 0.18), Vector2(width * 0.42, -width * 0.42)]), thickness))
			bunny.append_array(_stroke(PackedVector2Array([Vector2(0.0, -width * 0.08), Vector2(0.0, width * 0.14)]), thickness))
			add.call(bunny, 1.0, line)


## 口の気持ちの形：口のまん中（上はしから幅の4分の1下）を軸に、上下を返し、大きさとたての縮みを変える。
static func _mood_shape(triangles: PackedVector2Array, mood: Dictionary, width: float) -> PackedVector2Array:
	var middle := -width * 0.25
	var flip := float(mood["flip"]) > 0.0
	var scale := float(mood["scale"])
	var squash := float(mood["squash"])
	var shaped := PackedVector2Array()
	for index in triangles.size():
		var point := triangles[index]
		shaped.append(Vector2(point.x * scale, middle + (point.y - middle) * scale * squash * (-1.0 if flip else 1.0)))
	if flip:
		# 上下を返すと面の表が変わるので、点の順を入れ替える。
		for index in range(0, shaped.size(), 3):
			var keep := shaped[index + 1]
			shaped[index + 1] = shaped[index + 2]
			shaped[index + 2] = keep
	return shaped


## 口の弧。sag は、まん中の上下（−で下にふくらむ＝笑う、＋で上にふくらむ＝への字）。
static func _arc_line(width: float, sag: float, base_y: float) -> PackedVector2Array:
	var arc := PackedVector2Array()
	for index in 13:
		var t := float(index) / 12.0
		arc.append(Vector2(lerpf(-width * 0.5, width * 0.5, t), base_y + sin(t * PI) * sag))
	return arc


## 八重歯（fang が 0 なら付けない。＋で体の右、−で体の左）。
static func _add_fang(add: Callable, source: Dictionary, top: Vector2, width: float) -> void:
	if float(source["fang"]) == 0.0:
		return
	var fang_color := Color(str(source["fang_color"]))
	var size := width * 0.2
	add.call(PackedVector2Array([top + Vector2(-size * 0.5, 0.0), top + Vector2(size * 0.5, 0.0), top + Vector2(0.0, -size)]), 4.0, func(_p: Vector2) -> Color: return fang_color)


# ---------------------------------------------------------------- ほっぺ

static func _cheeks(sheet: Sheet, source: Dictionary, face: Dictionary) -> void:
	var color: Color = face["cheek_color"]
	var width := float(source["width"])
	var height := float(source["height"])
	for side: float in [1.0, -1.0]:
		var triangles := PackedVector2Array()
		var paint := color
		match str(source["shape"]):
			"cheek_lines":
				# 斜めの線を3本。
				for index in 3:
					var x := width * (float(index) - 1.0) * 0.7
					triangles.append_array(_stroke(PackedVector2Array([Vector2(x - height * 0.35, -height), Vector2(x + height * 0.35, height)]), width * 0.1))
			"cheek_swirl":
				# うずまき。
				var spiral := PackedVector2Array()
				for index in 37:
					var t := float(index) / 36.0
					spiral.append(Vector2(cos(t * TAU * 2.0) * width, sin(t * TAU * 2.0) * height) * (0.15 + 0.85 * t))
				triangles = _stroke(spiral, width * 0.14)
			"cheek_freckles":
				# そばかす：小さい点を3つ。
				for point: Vector2 in [Vector2(-width * 0.55, height * 0.3), Vector2(0.0, -height * 0.2), Vector2(width * 0.55, height * 0.3)]:
					triangles.append_array(_disc(point, height * 0.4))
				paint = Color(face["eye_colors"][0], 0.55)
			_:
				triangles = Surface.ellipse_triangles(Vector2.ZERO, width, height)
		var fill := paint
		sheet.add(triangles, float(face["cheek_yaw_deg"]) * side, float(face["cheek_height_ratio"]), 1.0, func(_p: Vector2) -> Color: return fill)


# ---------------------------------------------------------------- 効果（汗・涙・キラキラ・怒りのマーク）

static func _effect(sheet: Sheet, source: Dictionary, face: Dictionary) -> void:
	var color := Color(str(source["color"]))
	var size := float(source["size"])
	var w := float(face["eye_size"][0])
	var h := float(face["eye_size"][1])
	var eye_yaw := float(face["eye_yaw_deg"])
	var eye_height := float(face["eye_height_ratio"])
	var solid := func(_p: Vector2) -> Color: return color
	var white := func(_p: Vector2) -> Color: return Color.WHITE
	match str(source["shape"]):
		"effect_sweat":
			# 顔の横（体の左の上）に、しずくを2つ。
			var big := Vector2(0.0, 0.0)
			var small := Vector2(-size * 1.5, size * 1.1)
			var drops := _fill(_rotated(_drop_outline(size), -0.35), Vector2.ZERO)
			drops.append_array(_moved(_fill(_rotated(_drop_outline(size * 0.55), -0.35), Vector2.ZERO), small))
			sheet.add(_moved(drops, big), -(eye_yaw + 22.0), eye_height + 0.17, 4.0, solid)
			sheet.add(_disc(Vector2(-size * 0.3, -size * 0.25), size * 0.2), -(eye_yaw + 22.0), eye_height + 0.17, 5.0, white)
		"effect_tears":
			# 両目の下に、涙のしずく。
			for side: float in [1.0, -1.0]:
				var drops := _moved(_fill(_drop_outline(size), Vector2.ZERO), Vector2(side * w * 0.55, -h * 1.25 - size))
				drops.append_array(_moved(_fill(_drop_outline(size * 0.6), Vector2.ZERO), Vector2(side * w * 1.25, -h * 1.0 - size * 3.0)))
				sheet.add(drops, eye_yaw * side, eye_height, 4.0, solid)
				sheet.add(_disc(Vector2(side * w * 0.55 - size * 0.3, -h * 1.25 - size * 1.25), size * 0.2), eye_yaw * side, eye_height, 5.0, white)
		"effect_sparkle":
			# 両目の外側に、キラキラ。
			for side: float in [1.0, -1.0]:
				var big := Vector2(side * (w + size * 1.6), h * 0.95)
				var small := Vector2(side * (w + size * 2.9), h * 0.1)
				var stars := _fill(_star_outline(big, size, 4, 0.3), big)
				stars.append_array(_fill(_star_outline(small, size * 0.55, 4, 0.3), small))
				sheet.add(stars, eye_yaw * side, eye_height, 4.0, solid)
		"effect_anger":
			# 怒りのマーク（4つの弧）。顔の横（体の左の上）に。
			var gap := size * 0.3
			var arcs := PackedVector2Array()
			for sx: float in [1.0, -1.0]:
				for sy: float in [1.0, -1.0]:
					var arc := PackedVector2Array()
					for index in 9:
						var angle := PI + PI * 0.5 * float(index) / 8.0
						arc.append(Vector2(sx * (size + cos(angle) * (size - gap)), sy * (size + sin(angle) * (size - gap))))
					arcs.append_array(_stroke(arc, size * 0.2))
			sheet.add(arcs, -(eye_yaw + 18.0), eye_height + 0.2, 4.0, solid)


# ---------------------------------------------------------------- 形の道具

## 折れ線を、太さのある線にする。角と両端は丸くする。thickness は、線の幅の半分。
static func _stroke(points: PackedVector2Array, thickness: float) -> PackedVector2Array:
	var triangles := Surface.stroke_triangles(points, thickness)
	for point in points:
		triangles.append_array(_disc(point, thickness))
	return triangles


## 小さい丸。
static func _disc(center: Vector2, radius: float) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	for index in 8:
		var a0 := TAU * float(index) / 8.0
		var a1 := TAU * float(index + 1) / 8.0
		triangles.append_array(PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius]))
	return triangles


## ふちの点の並び（閉じた形）を、中心から輪を重ねて塗る（曲がった表面に沿いやすくする）。
static func _fill(outline: PackedVector2Array, center: Vector2, rings: int = 3) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	for ring in rings:
		var inner := float(ring) / float(rings)
		var outer := float(ring + 1) / float(rings)
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			triangles.append_array(PackedVector2Array([center.lerp(a, inner), center.lerp(a, outer), center.lerp(b, outer), center.lerp(a, inner), center.lerp(b, outer), center.lerp(b, inner)]))
	return triangles


## 星のふち。points は角の数、inner は、へこみの深さ（外の半径に対する割合）。
static func _star_outline(center: Vector2, radius: float, points: int, inner: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in points * 2:
		var angle := PI * 0.5 + TAU * float(index) / float(points * 2)
		outline.append(center + Vector2(cos(angle), sin(angle)) * (radius if index % 2 == 0 else radius * inner))
	return outline


## ハートのふち。size は、中心から左右の端まで。
static func _heart_outline(size: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in 40:
		var t := TAU * float(index) / 40.0
		outline.append(Vector2(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t) + 2.5) * size / 16.0)
	return outline


## しずくのふち（上がとがって、下が丸い）。size は、中心から下の端まで。
static func _drop_outline(size: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in 24:
		var t := TAU * float(index) / 24.0
		outline.append(Vector2(size * 1.25 * sin(t) * pow(sin(t * 0.5), 1.5), size * (0.4 + 1.4 * cos(t)) - size * 0.4))
	return outline


## 円の線（count 個の点。始めと終わりをつなぐ）。
static func _circle(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count + 1:
		points.append(center + Vector2.from_angle(TAU * float(index) / float(count)) * radius)
	return points


## 正多角形の外形（count 個の角。start は、最初の角の向き）。
static func _polygon(radius: float, count: int, start: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		for step in 4:
			var a := Vector2.from_angle(start + TAU * float(index) / float(count)) * radius
			var b := Vector2.from_angle(start + TAU * float(index + 1) / float(count)) * radius
			points.append(a.lerp(b, float(step) / 4.0))
	return points


static func _rotated(triangles: PackedVector2Array, angle: float) -> PackedVector2Array:
	if angle == 0.0:
		return triangles
	var result := PackedVector2Array()
	for point in triangles:
		result.append(point.rotated(angle))
	return result


static func _moved(triangles: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in triangles:
		result.append(point + by)
	return result


## 重ねる面の集まりを、1つの節（メッシュ1つ）にまとめる。
static func _sheet_node(shape: Dictionary, sheet: Sheet, node_name: String) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var see_through := false
	for layer: Array in sheet.layers:
		var arrays := Surface.patch_arrays(shape, layer[0], layer[1], layer[2], Surface.PATCH_OFFSET * float(layer[3]), layer[4])
		vertices.append_array(arrays[0])
		normals.append_array(arrays[1])
		colors.append_array(arrays[2])
	for color in colors:
		if color.a < 1.0:
			see_through = true
			break
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = Surface.triangle_mesh(vertices, normals, colors)
	var material := StandardMaterial3D.new()
	# 色は、頂点の色をそのまま出す（光の当たり方で暗くならない）。
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	# 顔は、影を落とさない。
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## 画像を貼った薄い面。画像の中心が、指定の場所に来る。
static func _image_patch(shape: Dictionary, source: Dictionary, yaw_deg: float, height_ratio: float, node_name: String) -> MeshInstance3D:
	var texture := PartAssets.load_texture(str(source["path"]))
	assert(texture != null, "部品の画像を読めません: %s" % source["path"])
	var rect := Rect2(Vector2(-float(source["width"]) * 0.5, -float(source["height"]) * 0.5), Vector2(float(source["width"]), float(source["height"])))
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = Surface.patch_mesh(shape, Surface.rect_triangles(rect), yaw_deg, height_ratio, Surface.PATCH_OFFSET, func(_uv: Vector2) -> Color: return Color.WHITE, rect)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
