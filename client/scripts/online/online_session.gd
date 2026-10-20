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
## さっき選んだプル（このアプリを開いているあいだ覚えておく）。プル選択に入ったとき、まずこれにする。
static var last_pick := ""
## オンラインフリー対戦の画面から来たか（レースのあと、フリー対戦のロビーへ戻る）。
static var free_mode := false
## オンラインフリー対戦のロビーのようす（サーバーから届いた最後の free_lobby。届いていなければ空）。
static var free_lobby := {}
## オンラインフリー対戦のルームの画像（ルームのID → 絵）。つながっているあいだ覚えておく。
static var free_images := {}
## 今走っている（走った）オンラインフリー対戦のルームのID。
static var free_race_room := ""
## レースの結果の画面で選んだこと（room_id、entry＝"on"・"hold"・"off"、top＝優先をいちばん前に、stay＝そのルームの画面に残る）。
## ロビーに戻ったときに、サーバーへ送って消す。
static var free_after := {}


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


static func _add_chat_line(line: Dictionary) -> void:
	chat_log.append(line)
	if chat_log.size() > CHAT_LOG_LIMIT:
		chat_log.pop_front()


## 部屋のできごとの知らせを、画面に出す文にする。
static func notice_text(data: Dictionary) -> String:
	var player_name := str(data.get("name", ""))
	match str(data.get("kind", "")):
		Protocol.NOTICE_JOINED:
			return "%s さんが、部屋に入りました。" % player_name
		Protocol.NOTICE_LEFT:
			return "%s さんが、部屋を出ました。" % player_name
		Protocol.NOTICE_DISCONNECTED:
			return "%s さんの、つながりが切れました。" % player_name
		Protocol.NOTICE_KICKED:
			return "%s さんが、%sによって退出しました。" % [player_name, "サーバーの管理人" if str(data.get("by", "")) == Protocol.KICKED_BY_ADMIN else "部屋の主"]
		Protocol.NOTICE_HOST:
			return "%s さんが、部屋の主になりました。" % player_name
		Protocol.NOTICE_RACE_OPEN:
			return "部屋主（%s さん）が「レース設定へ」を押しました。" % player_name
	return ""


## まだ紹介を持っていない人のぶんを、サーバーに聞く。
static func _ask_profiles() -> void:
	for member: Dictionary in all_members():
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


## 部屋の場面（待機室・レース設定・ぷるりんを選ぶ所・出走表）。
static func phase() -> String:
	return str(room.get("phase", Protocol.PHASE_LOBBY))


## 自分が、今のレースに出る人か（待機室でレース開始が押されたときに、準備OKだった人と主）。
static func am_racer() -> bool:
	if not in_room():
		return false
	# JSON で届いた番号は小数になっているので、整数にそろえて比べる。
	for id: Variant in room.get("racers", []):
		if int(id) == peer_id:
			return true
	return false


## 待機室の画面を出す場面か（待機室の場面、または、レースに出ない人）。
static func in_waiting_room() -> bool:
	return in_room() and (phase() == Protocol.PHASE_LOBBY or not am_racer())


## 部屋にいる全員（入った順）。待機室の席に使う。
static func all_members() -> Array:
	return room.get("members", [])


## レースを決める画面（ぷるりんを選ぶ所・出走表）で扱う人。待機室では全員、それ以外は、レースに出る人（レース開始のときの並び）。
static func members() -> Array:
	if phase() == Protocol.PHASE_LOBBY:
		return all_members()
	var by_id := {}
	for member: Dictionary in all_members():
		by_id[int(member["peer_id"])] = member
	var result: Array = []
	for id: Variant in room.get("racers", []):
		if by_id.has(int(id)):
			result.append(by_id[int(id)])
	return result


## 自分が、待機室で準備OKを押しているか。
static func my_lobby_ready() -> bool:
	for member: Dictionary in all_members():
		if int(member["peer_id"]) == peer_id:
			return bool(member.get("ready", false))
	return false


## 自分が選んでいるぷるりん（まだなら空）。
static func my_pururin_id() -> String:
	for member: Dictionary in all_members():
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
		Protocol.FREE_LOBBY:
			peer_id = int(data["peer_id"])
			free_lobby = data
		Protocol.WELCOME:
			peer_id = int(data["peer_id"])
			room = data
			_ask_profiles()
		Protocol.ROOM:
			room = data
			_ask_profiles()
		Protocol.PROFILE_INFO:
			profiles[int(data["peer_id"])] = profile_from(data)
		Protocol.NOTICE:
			# 部屋のできごとは、ひとことの記録にも残す。
			_add_chat_line({"system": true, "text": notice_text(data)})
		Protocol.CHAT_MESSAGE:
			_add_chat_line({"name": str(data["name"]), "text": str(data["text"]), "mine": int(data["peer_id"]) == peer_id})


static func _forget() -> void:
	peer_id = 0
	free_lobby = {}
	free_images = {}
	free_after = {}
	free_race_room = ""
	room = {}
	rooms = []
	max_rooms = 0
	chat_log = []
	profiles = {}
	_asked = {}
