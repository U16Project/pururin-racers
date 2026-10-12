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


## サーバーへつなぐ。url は `ws://127.0.0.1:18766` の形。
func connect_to(url: String) -> Error:
	disconnect_from_server()
	_socket = WebSocketPeer.new()
	_was_open = false
	var error := _socket.connect_to_url(url)
	if error != OK:
		_socket = null
	return error


func disconnect_from_server() -> void:
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
	return _socket.send_text(Protocol.encode(Protocol.message(type, fields))) == OK


## 合言葉の部屋に入る。
func join_room(player_name: String, room: String) -> bool:
	return send(Protocol.HELLO, {"name": player_name, "room": room})


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
				var data := Protocol.decode(_socket.get_packet().get_string_from_utf8())
				if not data.is_empty():
					message_received.emit(data)
		WebSocketPeer.STATE_CLOSED:
			_socket = null
			_was_open = false
			closed.emit()
