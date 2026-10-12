extends RefCounted
## 今動いているゲームが、いつ書き出された版かを知らせる（ブラウザ版で、古い版が出ていないかを見分けるため）。
## 書き出すときに、tools/export-pururin-web.sh が `res://data/build_info.json` に日時を書く。
## このファイルは、書き出しのたびに作るもので、Git には入れない。エディタからそのまま動かしたときは、無い。

const PATH := "res://data/build_info.json"
## 書き出した版でないとき（エディタやテストから動かしたとき）に出す文。
const DEVELOPMENT_TEXT := "開発中（書き出していない版）"


## 書き出した日時（例：2026-10-13 12:34）。書き出した版でなければ、空。
static func built_at() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK or not (json.data is Dictionary):
		push_error("build_info.json を読めません")
		return ""
	return str((json.data as Dictionary).get("built_at", ""))


## 画面に出す文。
static func label_text() -> String:
	var built := built_at()
	return "版 %s" % built if not built.is_empty() else DEVELOPMENT_TEXT
