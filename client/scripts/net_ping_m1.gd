extends Node
## M1: WebSocket で ping → pong（shared/protocol_m1.md）。

const WS_URL := "ws://127.0.0.1:18765"
const PROTOCOL_VERSION := 1

@export var status_label_path: NodePath = ^"../UI/StatusLabel"

var _socket := WebSocketPeer.new()
var _label: Label
var _ping_sent: bool = false


func _ready() -> void:
	_label = get_node_or_null(status_label_path) as Label
	_set_status("サーバーに接続しています…")
	print("ぷるりんレーサーズ — M1 コースを走ります")
	var err := _socket.connect_to_url(WS_URL)
	if err != OK:
		_set_status("接続を始められませんでした")
		push_error("net_ping_m1: connect_to_url failed: %s" % error_string(err))
		set_process(false)


func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _ping_sent:
				_send_ping()
			while _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				if _socket.was_string_packet():
					_handle_text(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if not _ping_sent:
				_set_status("サーバーに届きませんでした（:18765）")
			set_process(false)


func _send_ping() -> void:
	var payload := {"v": PROTOCOL_VERSION, "t": "ping"}
	var err := _socket.send_text(JSON.stringify(payload))
	if err != OK:
		_set_status("ping を送れませんでした")
		push_error("net_ping_m1: send_text failed: %s" % error_string(err))
		return
	_ping_sent = true
	_set_status("ping を送りました…")


func _handle_text(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = data
	if int(msg.get("v", 0)) != PROTOCOL_VERSION:
		return
	if str(msg.get("t", "")) != "pong":
		return
	var server_time: float = float(msg.get("server_time", 0.0))
	var line := "pong を受け取ったよ（server_time=%.3f）" % server_time
	_set_status(line)
	print("ぷるりんレーサーズ — %s" % line)


func _set_status(text: String) -> void:
	if _label:
		_label.text = text
