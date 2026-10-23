extends RefCounted
## 強化学習：Python とのつなぎ（このPCの中の通信）。1行に1つの JSON を送り合う。
## 返事を待つあいだは、ゲームの時間を止める（画面なしの早回しなので、待っても走りは変わらない）。

var _tcp := StreamPeerTCP.new()
var _buffer := PackedByteArray()
## 先に読んでしまった指示（レースの途中で届いた、step 以外の指示）。次の receive で返す。
var pending := {}


## Python が待っている番号へつなぐ。つながらなければ false。
func open(port: int) -> bool:
	if _tcp.connect_to_host("127.0.0.1", port) != OK:
		return false
	var waited_ms := 0
	while waited_ms < 10000:
		_tcp.poll()
		if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_tcp.set_no_delay(true)
			return true
		if _tcp.get_status() == StreamPeerTCP.STATUS_ERROR:
			return false
		OS.delay_msec(5)
		waited_ms += 5
	return false


func send(message: Dictionary) -> void:
	_tcp.put_data((JSON.stringify(message) + "\n").to_utf8_buffer())


## 次の1行が届くまで待つ。つながりが切れたら空を返す。
func receive() -> Dictionary:
	if not pending.is_empty():
		var held := pending
		pending = {}
		return held
	while true:
		var end := _buffer.find(10)
		if end >= 0:
			var line := _buffer.slice(0, end).get_string_from_utf8()
			_buffer = _buffer.slice(end + 1)
			var parsed: Variant = JSON.parse_string(line)
			return parsed if parsed is Dictionary else {}
		_tcp.poll()
		if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return {}
		var available := _tcp.get_available_bytes()
		if available > 0:
			var got: Array = _tcp.get_partial_data(available)
			if int(got[0]) == OK:
				_buffer.append_array(got[1])
		else:
			OS.delay_usec(50)
	return {}
