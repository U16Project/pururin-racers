extends RefCounted
## このPCをサーバーにする：同じアプリを、画面なしで、もう1つ起動して、サーバーとして動かす（起動の印 --server）。
## ゲームの中でサーバーを動かさないのは、サーバーの上のレースの音や絵が、自分の画面に混ざらないようにするため。
## 書き出したゲームでも、エディタから動かしたゲームでも使える。ブラウザ版では使えない（ほかの人からのつながりを待ち受けられない）。

const Protocol := preload("res://scripts/online/online_protocol.gd")
const SERVER_FLAG := "--server"
const SERVER_SCENE_PATH := "res://scenes/online_server.tscn"

static var _pid := -1


## 起動の印で、サーバーとして始めるように頼まれているか。
static func requested() -> bool:
	return OS.get_cmdline_user_args().has(SERVER_FLAG)


## このPCでサーバーを動かせるか（ブラウザ版では、できない）。
static func is_supported() -> bool:
	return not OS.has_feature("web")


static func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


## サーバーを起動する。ゲームを閉じるときに、一緒に止める。
static func start(tree: SceneTree) -> Error:
	if is_running():
		return OK
	if not is_supported():
		return ERR_UNAVAILABLE
	_pid = OS.create_process(OS.get_executable_path(), start_arguments())
	if _pid <= 0:
		_pid = -1
		return FAILED
	# ゲームを閉じたら、サーバーも止める（場面が替わっても残るよう、いちばん上に置く）。
	if tree.root.get_node_or_null("LocalServerKeeper") == null:
		var keeper := Keeper.new()
		keeper.name = "LocalServerKeeper"
		tree.root.add_child(keeper)
	return OK


## 起動するときの指定。エディタの本体で動かしているときは、このプロジェクトの場所も渡す。
static func start_arguments() -> PackedStringArray:
	var arguments := PackedStringArray(["--headless"])
	if not OS.has_feature("template"):
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--", SERVER_FLAG])
	return arguments


static func stop() -> void:
	if is_running():
		OS.kill(_pid)
	_pid = -1


## 自分がつなぐ場所。
static func local_url() -> String:
	return "ws://127.0.0.1:%d" % Protocol.server_port()


## ほかの人がつなぐ場所（同じネットワークの中の、このPCの番号）。家のWi-Fiでよく使う 192.168 を先に。見つからなければ空。
static func lan_urls() -> PackedStringArray:
	var addresses: Array[String] = []
	for address: String in IP.get_local_addresses():
		if is_private_address(address):
			addresses.append(address)
	addresses.sort_custom(func(a: String, b: String) -> bool:
		return (0 if a.begins_with("192.168.") else 1) < (0 if b.begins_with("192.168.") else 1))
	var urls := PackedStringArray()
	for address: String in addresses:
		urls.append("ws://%s:%d" % [address, Protocol.server_port()])
	return urls


## 家や学校の中だけで使う番号か（192.168.x.x・10.x.x.x・172.16〜31.x.x）。
static func is_private_address(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	if address.begins_with("192.168.") or address.begins_with("10."):
		return true
	return parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31


## ゲームを閉じるときに、サーバーを止める係。
class Keeper extends Node:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
			var script: Script = load("res://scripts/online/local_server.gd")
			script.call("stop")
