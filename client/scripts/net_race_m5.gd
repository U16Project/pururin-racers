extends Node
## M5 WebSocket クライアント。サーバー状態を受信し、入力だけを送る。

signal race_started(payload: Dictionary)
signal race_tick_received(payload: Dictionary)
signal race_result_received(payload: Dictionary)
signal connection_error(message: String)

const WS_URL := "ws://127.0.0.1:18765"
const PROTOCOL_VERSION := 1

var _socket := WebSocketPeer.new()
var _started := false

func connect_race() -> void:
	var error := _socket.connect_to_url(WS_URL)
	if error != OK:
		connection_error.emit("サーバーへ接続できませんでした")

func _process(_delta: float) -> void:
	_socket.poll()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not _started:
		_socket.send_text(JSON.stringify({"v": PROTOCOL_VERSION, "t": "race_join"}))
		_started = true
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		if _socket.was_string_packet():
			_handle_text(packet.get_string_from_utf8())

func send_input(target_speed: float, target_offset: float) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify({
		"v": PROTOCOL_VERSION,
		"t": "race_input",
		"target_speed": target_speed,
		"target_offset": target_offset,
	}))

func _handle_text(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	if int(message.get("v", 0)) != PROTOCOL_VERSION:
		return
	match str(message.get("t", "")):
		"race_start":
			race_started.emit(message)
		"race_tick":
			race_tick_received.emit(message)
		"race_result":
			race_result_received.emit(message)
		"error":
			connection_error.emit(str(message.get("message", "通信エラー")))
