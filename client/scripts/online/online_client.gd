extends Node
## オンライン対戦の、ゲーム側の通信。サーバーへつなぎ、文を送り、届いた文を知らせる。

const Protocol := preload("res://scripts/online/online_protocol.gd")

## サーバーにつながった。
signal connected
## サーバーから文が届いた（決まりの形の辞書）。
signal message_received(data: Dictionary)
## 切れた（つなげなかったときも、これ）。
signal closed

var _socket: WebSocketPeer
var _was_open := false
var _asset_packets: Array = []
var _custom := preload("res://scripts/online/online_custom_transfer.gd").new(self)
var last_error: String:
	get: return _custom.last_error

func local_id(id: String) -> String:
	return _custom.local_id(id)


## サーバーへつなぐ。url は `ws://127.0.0.1:18766` の形。
func connect_to(url: String) -> Error:
	disconnect_from_server()
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = int(load("res://scripts/config/online_config.gd").custom_limits()["message_bytes"])
	_socket.outbound_buffer_size = _socket.inbound_buffer_size * 2
	_was_open = false
	var error := _socket.connect_to_url(url)
	if error != OK:
		_socket = null
	return error


func disconnect_from_server() -> void:
	_custom.reset()
	_asset_packets.clear()
	if _socket != null:
		_socket.close()
	_socket = null
	_was_open = false


func is_open() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


## 文を送る。つながっていなければ、送らずに false。
func send(type: String, fields: Dictionary = {}) -> bool:
	if not is_open():
		return false
	if type == Protocol.CONFIRM and bool(fields.get("on", false)) and _custom.has_pending_pick():
		_custom.fail("部品を送信しています。完了してから確定してください。")
		return false
	_custom.before_send(type, fields)
	if type in [Protocol.PICK, Protocol.FREE_ENTRY] and str(fields.get("pururin_id", "")).begins_with(str(load("res://scripts/config/pururin_maker_config.gd").values()["id_prefix"])):
		return _custom.send_custom(type, fields)
	return _send_now(type, fields)

func _send_now(type: String, fields: Dictionary = {}) -> bool:
	if not is_open():
		return false
	var text := Protocol.encode(Protocol.message(type, fields))
	if text.to_utf8_buffer().size() > int(load("res://scripts/config/online_config.gd").custom_limits()["message_bytes"]):
		return false
	return _socket.send_text(text) == OK


## 名乗って、部屋の一覧の所に入る。
## introduction＝自己紹介、icon＝{kind, id, image}（相手の画面に出す、自分の紹介）。
func hello(player_name: String, introduction: String = "", icon: Dictionary = {}) -> bool:
	return send(Protocol.HELLO, {"name": player_name, "introduction": introduction, "icon": icon})


## 部屋を作る（パスワードが空なら、だれでも入れる部屋）。description＝部屋の紹介文。
func create_room(room_name: String, password: String = "", description: String = "") -> bool:
	return send(Protocol.CREATE, {"room_name": room_name, "password": password, "description": description})


## 一覧の部屋の、くわしい紹介を聞く（返事は room_info）。
func peek_room(room_id: int) -> bool:
	return send(Protocol.PEEK, {"room_id": room_id})


## 部屋に入る。
func join_room(room_id: int, password: String = "") -> bool:
	return send(Protocol.JOIN, {"room_id": room_id, "password": password})


## 待機室の「準備OK」を押す・外す。
func set_lobby_ready(on: bool) -> bool:
	return send(Protocol.LOBBY_READY, {"on": on})


func _exit_tree() -> void:
	disconnect_from_server()


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				connected.emit()
			while _socket != null and _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				if packet.size() > int(load("res://scripts/config/online_config.gd").custom_limits()["message_bytes"]):
					continue
				var data := Protocol.decode(packet.get_string_from_utf8())
				if data.is_empty() or int(data.get("v", 0)) != Protocol.VERSION:
					continue
				if str(data["t"]) == Protocol.ASSET_DATA:
					if packet.size() <= int(load("res://scripts/config/online_config.gd").custom_limits()["chunk_bytes"]) * 2 + 512 and _asset_packets.size() < int(load("res://scripts/config/online_config.gd").custom_limits()["pending_count"]):
						_asset_packets.append(data)
				elif _custom.receive(data):
					message_received.emit(data)
			if not _asset_packets.is_empty() and is_open():
				var asset: Dictionary = _asset_packets.pop_front()
				_custom.receive(asset)
			if is_open():
				_custom.tick(_socket)
		WebSocketPeer.STATE_CLOSED:
			_custom.reset()
			_asset_packets.clear()
			_socket = null
			_was_open = false
			closed.emit()
