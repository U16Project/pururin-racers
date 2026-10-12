extends RefCounted
## オンラインの、場面をまたいで持ち続けるもの（サーバーとのつながりと、今いる部屋のようす）。
## 部屋の画面とレースの画面は、場面が替わるので、つながりはここ（画面のいちばん上の階）に置く。

const OnlineClient := preload("res://scripts/online/online_client.gd")
const Protocol := preload("res://scripts/online/online_protocol.gd")
const CLIENT_NODE_NAME := "OnlineSessionClient"

static var _client: Node
## 部屋に入れたときの、自分の番号（入っていなければ0）。
static var peer_id := 0
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


static func in_room() -> bool:
	return peer_id != 0 and _client != null and is_instance_valid(_client) and _client.is_open()


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
		Protocol.WELCOME:
			peer_id = int(data["peer_id"])
			room = data
		Protocol.ROOM:
			room = data


static func _forget() -> void:
	peer_id = 0
	room = {}
