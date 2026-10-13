extends RefCounted
## オンラインの、場面をまたいで持ち続けるもの（サーバーとのつながりと、今いる部屋のようす）。
## 部屋の画面とレースの画面は、場面が替わるので、つながりはここ（画面のいちばん上の階）に置く。

const OnlineClient := preload("res://scripts/online/online_client.gd")
const Protocol := preload("res://scripts/online/online_protocol.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const CLIENT_NODE_NAME := "OnlineSessionClient"

static var _client: Node
## サーバーに名乗ったときにもらう、自分の番号（名乗る前は0）。
static var peer_id := 0
## 部屋の一覧（サーバーから届いた最後のもの）と、同時に作れる部屋の数の上限。
static var rooms: Array = []
static var max_rooms := 0
## 今いる部屋の、ひとことの記録（新しいものが後ろ。1つぶん：{"name": 名前, "text": 文, "mine": 自分のものか}）。
## 部屋を出ると消える。レースの画面へ行って戻っても、残る。
## 同じ部屋の人の紹介（人の番号 → {"name", "introduction", "kind", "id", "texture"}）。部屋を出ると消える。
static var profiles := {}
## 紹介を聞いている最中の人（同じ人に、何度も聞かないため）。
static var _asked := {}
static var chat_log: Array = []
const CHAT_LOG_LIMIT := 60
## 今いる部屋のようす（サーバーから届いた最後のもの。入っていなければ空）。
static var room := {}


## サーバーとのつながり。無ければ作る。
static func client(tree: SceneTree) -> Node:
	if _client == null or not is_instance_valid(_client):
		_client = OnlineClient.new()
		_client.name = CLIENT_NODE_NAME
		tree.root.add_child(_client)
		_client.message_received.connect(_remember)
		_client.closed.connect(_forget)
	return _client


## つながりを切って、部屋のことも忘れる。
static func close() -> void:
	if _client != null and is_instance_valid(_client):
		_client.disconnect_from_server()
	_forget()


## 名乗り終えて、つながっているか（部屋の一覧の所か、部屋の中にいる）。
static func in_lobby() -> bool:
	return peer_id != 0 and _client != null and is_instance_valid(_client) and _client.is_open()


static func in_room() -> bool:
	return in_lobby() and not room.is_empty()


## まだ紹介を持っていない人のぶんを、サーバーに聞く。
static func _ask_profiles() -> void:
	for member: Dictionary in members():
		var id := int(member["peer_id"])
		if not _asked.has(id) and _client != null and is_instance_valid(_client):
			_asked[id] = true
			_client.send(Protocol.PROFILE, {"peer_id": id})


## 届いた紹介を、画面で使う形にする（自分で入れた画像は、絵に戻す。戻せなければ、画像なし）。
static func profile_from(data: Dictionary) -> Dictionary:
	var icon: Dictionary = data.get("icon", {}) if data.get("icon") is Dictionary else {}
	var kind := str(icon.get("kind", "none"))
	var texture: Texture2D = null
	if kind == "file":
		var image := Image.new()
		if image.load_jpg_from_buffer(Marshalls.base64_to_raw(str(icon.get("image", "")))) == OK and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
		else:
			kind = "none"
	return {"name": str(data.get("name", "")), "introduction": str(data.get("introduction", "")), "kind": kind, "id": str(icon.get("id", "")), "texture": texture}


## サーバーへ送る、自分のアイコン（自分で入れた画像は、小さくして、JPEGを文字にする）。
static func my_icon_to_send() -> Dictionary:
	var icon := TrainerProfile.icon()
	var kind := str(icon["kind"])
	if kind != "file":
		return {"kind": kind, "id": str(icon["id"]), "image": ""}
	var texture := TrainerProfile.icon_texture()
	if texture == null:
		return {"kind": "none", "id": "", "image": ""}
	var image := texture.get_image()
	image.resize(Protocol.ICON_IMAGE_SIDE_PX, Protocol.ICON_IMAGE_SIDE_PX, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	var text := Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.85))
	if text.length() > Protocol.ICON_IMAGE_MAX_CHARS:
		return {"kind": "none", "id": "", "image": ""}
	return {"kind": "file", "id": "", "image": text}


## 出走表を見ている場面か。
static func in_entries() -> bool:
	return in_room() and str(room.get("phase", "")) == Protocol.PHASE_ENTRIES


static func is_host() -> bool:
	return in_room() and int(room.get("host", 0)) == peer_id


static func members() -> Array:
	return room.get("members", [])


## 自分が選んでいるぷるりん（まだなら空）。
static func my_pururin_id() -> String:
	for member: Dictionary in members():
		if int(member["peer_id"]) == peer_id:
			return str(member["pururin_id"])
	return ""


static func _remember(data: Dictionary) -> void:
	match str(data["t"]):
		Protocol.LOBBY:
			# 部屋の一覧の所に入った（部屋を出た・出されたときも、これが届く）。
			peer_id = int(data["peer_id"])
			max_rooms = int(data["max_rooms"])
			rooms = data["rooms"]
			room = {}
			chat_log = []
			profiles = {}
			_asked = {}
		Protocol.ROOMS:
			rooms = data["rooms"]
		Protocol.WELCOME:
			peer_id = int(data["peer_id"])
			room = data
			_ask_profiles()
		Protocol.ROOM:
			room = data
			_ask_profiles()
		Protocol.PROFILE_INFO:
			profiles[int(data["peer_id"])] = profile_from(data)
		Protocol.CHAT_MESSAGE:
			chat_log.append({"name": str(data["name"]), "text": str(data["text"]), "mine": int(data["peer_id"]) == peer_id})
			if chat_log.size() > CHAT_LOG_LIMIT:
				chat_log.pop_front()


static func _forget() -> void:
	peer_id = 0
	room = {}
	rooms = []
	max_rooms = 0
	chat_log = []
	profiles = {}
	_asked = {}
