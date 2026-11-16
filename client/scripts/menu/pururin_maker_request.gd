extends RefCounted
## ぷるりん管理コーナーと、作る画面のあいだの受け渡し。
## mode：new（イチから作る）・edit（自分のぷるりんを直す）・copy（どれかの個体を複製する）。
## pururin_id：直す・複製する個体のID（new では空）。
## focus_id：管理コーナーに戻ったとき、選んでおくカードのID（空なら先頭の「＋新規作成」）。

static var mode := "new"
static var pururin_id := ""
static var focus_id := ""


static func open(next_mode: String, identifier: String) -> void:
	mode = next_mode
	pururin_id = identifier
