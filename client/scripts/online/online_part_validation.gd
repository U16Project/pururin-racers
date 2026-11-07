extends RefCounted
## ファイルをエンジンのデコーダーへ渡す前の検査。サーバーではヘッダーとJSONだけを見る。
const Config := preload("res://scripts/config/online_config.gd")

static func sha(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

static func whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and floorf(float(value)) == float(value)

static func check(data: PackedByteArray, ext: String, decode_image: bool = false) -> String:
	var limits := Config.custom_limits()
	if ext == "png":
		if data.size() > int(limits["image_bytes"]):
			return "image_bytes"
		var error := image_check(data)
		if error.is_empty() and decode_image:
			var image := Image.new()
			if image.load_png_from_buffer(data) != OK or image.is_empty():
				return "image_decode"
		return error
	if ext != "glb":
		return "extension"
	if data.size() > int(limits["mesh_bytes"]):
		return "mesh_bytes"
	if data.size() < 28 or data.decode_u32(0) != 0x46546c67 or data.decode_u32(4) != 2 or data.decode_u32(8) != data.size():
		return "glb_header"
	var length := int(data.decode_u32(12))
	if length < 2 or length % 4 != 0 or 28 + length > data.size() or data.decode_u32(16) != 0x4e4f534a:
		return "glb_json"
	var parsed: Variant = JSON.parse_string(data.slice(20, 20 + length).get_string_from_utf8())
	if not parsed is Dictionary:
		return "glb_json"
	var doc: Dictionary = parsed
	if not doc.get("asset") is Dictionary or doc["asset"].get("version", "") != "2.0" or _unsafe_tree(doc):
		return "glb_external_or_values"
	var bin_start := 28 + length
	if data.decode_u32(24 + length) != 0x004e4942 or bin_start + int(data.decode_u32(20 + length)) != data.size():
		return "glb_bin"
	for key: String in ["nodes", "meshes", "materials", "accessors", "bufferViews", "buffers", "images"]:
		if not doc.get(key, []) is Array:
			return "glb_array"
		for value: Variant in doc.get(key, []):
			if not value is Dictionary:
				return "glb_object"
	for key: String in ["nodes", "meshes", "materials"]:
		if doc.get(key, []).size() > int(limits[key]):
			return "glb_" + key
	if doc.get("buffers", []).size() != 1:
		return "glb_buffers"
	var buffer: Dictionary = doc["buffers"][0]
	if not whole(buffer.get("byteLength")) or int(buffer["byteLength"]) > data.size() - bin_start:
		return "glb_buffer"
	var views: Array = doc.get("bufferViews", [])
	for view: Dictionary in views:
		if view.get("buffer") != 0 or not whole(view.get("byteLength")) or not whole(view.get("byteOffset", 0)) or int(view.get("byteOffset", 0)) + int(view["byteLength"]) > int(buffer["byteLength"]):
			return "glb_view"
	for img: Dictionary in doc.get("images", []):
		if not whole(img.get("bufferView")) or int(img["bufferView"]) >= views.size():
			return "glb_image"
		var view: Dictionary = views[int(img["bufferView"])]
		var start := bin_start + int(view.get("byteOffset", 0))
		if image_check(data.slice(start, start + int(view["byteLength"])), true) != "":
			return "glb_image_size"
	var accessors: Array = doc.get("accessors", [])
	var widths := {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
	var elements := {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
	for accessor: Dictionary in accessors:
		if not whole(accessor.get("count")) or int(accessor["count"]) > int(limits["triangles"]) * 3 or not whole(accessor.get("bufferView")) or int(accessor["bufferView"]) >= views.size() or accessor.has("sparse"):
			return "glb_accessor"
		if not whole(accessor.get("componentType")) or not widths.has(int(accessor.get("componentType", -1))) or not elements.has(str(accessor.get("type", ""))):
			return "glb_accessor_type"
		var width := int(widths[int(accessor["componentType"])]) * int(elements[str(accessor["type"])])
		var view: Dictionary = views[int(accessor["bufferView"])]
		if not whole(accessor.get("byteOffset", 0)) or not whole(view.get("byteStride", width)):
			return "glb_accessor_offset"
		var stride := int(view.get("byteStride", width))
		var end := int(accessor.get("byteOffset", 0)) + maxi(0, int(accessor["count"]) - 1) * stride + width
		if stride < width or end > int(view["byteLength"]):
			return "glb_accessor_bounds"
	var mesh_triangles: Array[int] = []
	for mesh: Dictionary in doc.get("meshes", []):
		if not mesh.get("primitives") is Array:
			return "glb_primitives"
		var tris := 0
		for primitive: Variant in mesh["primitives"]:
			if not primitive is Dictionary or primitive.get("mode", 4) != 4 or not primitive.get("attributes") is Dictionary:
				return "glb_primitive"
			for idx: Variant in primitive["attributes"].values():
				if not whole(idx) or int(idx) >= accessors.size():
					return "glb_attribute"
			var idx: Variant = primitive.get("indices", primitive["attributes"].get("POSITION", -1))
			if not whole(idx) or int(idx) >= accessors.size() or not primitive["attributes"].has("POSITION"):
				return "glb_indices"
			var count := int(accessors[int(idx)]["count"])
			if count % 3 != 0:
				return "glb_triangle_count"
			tris += count / 3
		mesh_triangles.append(tris)
	var total := 0
	for count: int in mesh_triangles:
		total += count
	if total > int(limits["triangles"]):
		return "glb_triangles"
	# 同じメッシュを多数のノードで使う場合も数える。循環・多重親は読み込まない。
	total = 0
	var parents := {}
	var nodes: Array = doc.get("nodes", [])
	for i in nodes.size():
		var node: Dictionary = nodes[i]
		if node.has("mesh"):
			if not whole(node["mesh"]) or int(node["mesh"]) >= mesh_triangles.size():
				return "glb_mesh"
			total += mesh_triangles[int(node["mesh"])]
		if not node.get("children", []) is Array:
			return "glb_children"
		for child: Variant in node.get("children", []):
			if not whole(child) or int(child) >= nodes.size() or parents.has(int(child)):
				return "glb_child"
			parents[int(child)] = i
	for i: int in parents:
		var seen := {}
		var cursor := i
		while parents.has(cursor):
			if seen.has(cursor):
				return "glb_cycle"
			seen[cursor] = true
			cursor = int(parents[cursor])
	if total > int(limits["triangles"]):
		return "glb_triangles"
	if decode_image:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_buffer(data, "", state) != OK:
			return "glb_decode"
		var scene := document.generate_scene(state)
		if scene == null:
			return "glb_scene"
		scene.free()
	return ""

static func _unsafe_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return true
	if value is Dictionary:
		for key: String in value:
			if key in ["uri", "extensions", "extensionsUsed", "extensionsRequired"] or _unsafe_tree(value[key], depth + 1):
				return true
	elif value is Array:
		for item: Variant in value:
			if _unsafe_tree(item, depth + 1):
				return true
	elif value is float or value is int:
		return not is_finite(float(value)) or absf(float(value)) > 10000000
	return false

static func image_check(data: PackedByteArray, jpeg_allowed: bool = false) -> String:
	var width := 0
	var height := 0
	if data.size() >= 33 and data.slice(0, 8).hex_encode() == "89504e470d0a1a0a" and data.slice(12, 16).get_string_from_ascii() == "IHDR":
		width = _be32(data, 16)
		height = _be32(data, 20)
		var pos := 8
		var ended := false
		var has_pixels := false
		while pos + 12 <= data.size():
			var count := _be32(data, pos)
			if count < 0 or count > data.size() - pos - 12:
				return "png_chunk"
			var kind := data.slice(pos + 4, pos + 8).get_string_from_ascii()
			has_pixels = has_pixels or kind == "IDAT"
			pos += 12 + count
			if kind == "IEND":
				ended = count == 0 and pos == data.size()
				break
		if not ended or not has_pixels:
			return "png_incomplete"
	elif jpeg_allowed and data.size() > 4 and data[0] == 255 and data[1] == 216:
		var pos := 2
		while pos + 4 < data.size():
			if data[pos] != 255:
				return "jpeg_header"
			var marker := data[pos + 1]
			var length := int(data[pos + 2]) * 256 + int(data[pos + 3])
			if length < 2 or pos + 2 + length > data.size():
				return "jpeg_segment"
			if marker in [192, 193, 194] and length >= 8:
				height = int(data[pos + 5]) * 256 + int(data[pos + 6])
				width = int(data[pos + 7]) * 256 + int(data[pos + 8])
				break
			pos += 2 + length
	else:
		return "image_header"
	var side := int(Config.custom_limits()["image_side_px"])
	return "" if width > 0 and height > 0 and width <= side and height <= side else "image_dimensions"

static func _be32(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) * 16777216 + int(data[offset + 1]) * 65536 + int(data[offset + 2]) * 256 + int(data[offset + 3])
