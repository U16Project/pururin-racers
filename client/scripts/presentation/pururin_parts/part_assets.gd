extends RefCounted
## 取り替え用の素材（メッシュ・画像）を読み込む。
## Godot に取り込み済みの素材はそのまま使い、取り込んでいないファイル（置いただけの .glb や .png）は、その場で読む。
## 読めないときは、空を返す（呼ぶ側の設定の検査で、起動時に止める）。

static var _texture_cache := {}


## メッシュの素材（.glb / .gltf、または取り込み済みの場面）から、部品の節を1つ作る。読めなければ null。
static func instantiate_mesh(path: String) -> Node3D:
	if ResourceLoader.exists(path, "PackedScene"):
		return (load(path) as PackedScene).instantiate() as Node3D
	if not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D


## 画像（.png など）を、貼るための絵にする。同じ画像は、1回だけ読む。読めなければ null。
static func load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_texture_cache[path] = texture
	return texture


## 素材のファイルがあるか（設定の検査用）。
static func exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
