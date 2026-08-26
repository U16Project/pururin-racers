extends Node
## M2: WebSocket で控室 join（shared/protocol_m2.md）。

const WS_URL := "ws://127.0.0.1:18765"
const PROTOCOL_VERSION := 1

@export var status_label_path: NodePath = ^"../UI/StatusLabel"

var _socket := WebSocketPeer.new()
var _label: Label
var _join_sent: bool = false


func _ready() -> void:
	_label = get_node_or_null(status_label_path) as Label
	_set_status("サーバーに接続しています…")
	print("ぷるりんレーサーズ — M2 控室へ向かいます")
	var err := _socket.connect_to_url(WS_URL)
	if err != OK:
		_set_status("接続を始められませんでした")
		push_error("net_room_m2: connect_to_url failed: %s" % error_string(err))
		set_process(false)


func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _join_sent:
				_send_join()
			while _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				if _socket.was_string_packet():
					_handle_text(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if not _join_sent:
				_set_status("サーバーに届きませんでした（:18765）")
			set_process(false)


func _send_join() -> void:
	var payload := {"v": PROTOCOL_VERSION, "t": "join_room"}
	var err := _socket.send_text(JSON.stringify(payload))
	if err != OK:
		_set_status("控室への入室依頼を送れませんでした")
		push_error("net_room_m2: send_text failed: %s" % error_string(err))
		return
	_join_sent = true
	_set_status("控室への入室を待っています…")


func _handle_text(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = data
	if int(msg.get("v", 0)) != PROTOCOL_VERSION:
		return
	var msg_t := str(msg.get("t", ""))
	if msg_t == "room_welcome":
		var room_id := str(msg.get("room_id", ""))
		var member_count := int(msg.get("member_count", 0))
		var line := "控室に入りました（%s・いま %d 人）" % [room_id, member_count]
		_set_status(line)
		print("ぷるりんレーサーズ — %s" % line)
	elif msg_t == "error":
		var code := str(msg.get("code", ""))
		var message := str(msg.get("message", ""))
		var line: String
		if code == "room_full":
			line = "控室が満員です"
			if message != "":
				line = message
		else:
			line = "控室に入れませんでした"
			if message != "":
				line = message
		_set_status(line)
		push_warning("net_room_m2: %s (%s)" % [line, code])


func _set_status(text: String) -> void:
	if _label:
		_label.text = text
