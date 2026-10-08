extends RefCounted
## レース開始前に選んだ距離・ユーザーのぷるりん・対戦相手を、場面の間で受け渡す。

const SUPPORTED_DISTANCE_M := [1200.0, 1600.0, 2000.0, 2400.0, 3000.0]
const DEFAULT_DISTANCE_M := 2000.0
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

## キャラスロットの数。スロットの番号（0〜7）は、そのままスタートの枠（1〜8枠）になる。
const SLOT_COUNT := 8
## 対戦相手（CPU）のスロットの数。ユーザーのスロットが1つあるので、残り。
const OPPONENT_SLOT_COUNT := SLOT_COUNT - 1
## スロットが空（未選択）のときの値。
const EMPTY := ""

static var _selected_distance_m := DEFAULT_DISTANCE_M
## 各スロット（＝各枠）に入っている個体のID。起動した直後は、全部が未選択。
static var _slots: Array[String] = _empty_slots()
## 各スロットが施錠されているか。施錠中は、キャラが変わる操作を受け付けない。
static var _locked: Array[bool] = _no_locks()
## ユーザーのスロットがある枠。起動した直後は、1枠（番号0）。
static var _user_slot := 0
## レースからレース選択へ戻るところか（戻ったとき、選択の枠をレース開始ボタンに置くための印）。
static var _returning_from_race := false


static func _empty_slots() -> Array[String]:
	var slots: Array[String] = []
	slots.resize(SLOT_COUNT)
	slots.fill(EMPTY)
	return slots


static func _no_locks() -> Array[bool]:
	var locks: Array[bool] = []
	locks.resize(SLOT_COUNT)
	locks.fill(false)
	return locks


static func supported_distances_m() -> Array:
	return SUPPORTED_DISTANCE_M.duplicate()


static func selected_distance_m() -> float:
	return _selected_distance_m


static func select_distance(distance_m: float) -> float:
	_selected_distance_m = normalize_distance(distance_m)
	return _selected_distance_m


## 対応距離へ丸める。未対応なら既定距離。選択状態は変更しない。
static func normalize_distance(distance_m: float) -> float:
	for supported_distance in SUPPORTED_DISTANCE_M:
		if is_equal_approx(float(supported_distance), distance_m):
			return float(supported_distance)
	return DEFAULT_DISTANCE_M


## レースからレース選択へ戻るときに、印を付ける。
static func mark_returning_from_race() -> void:
	_returning_from_race = true


## レースから戻ってきたところなら true。印は、1回読んだら消える。
static func take_returning_from_race() -> bool:
	var returning := _returning_from_race
	_returning_from_race = false
	return returning


## ユーザーのスロットがある枠（0〜7）。
static func user_slot() -> int:
	return _user_slot


static func is_user_slot(slot: int) -> bool:
	return slot == _user_slot


## ユーザーが操作する個体。未選択なら空。
static func selected_player_pururin_id() -> String:
	return _slots[_user_slot]


## レースに出る対戦相手。枠の順。
static func selected_opponent_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot in SLOT_COUNT:
		if slot != _user_slot and _slots[slot] != EMPTY:
			ids.append(_slots[slot])
	return ids


## レースに出る個体と、その枠。枠の順。未選択の枠は入らない（その枠は空けたまま走る）。
## 1つぶんの辞書：gate（枠の番号0〜7）、id（個体）、player（ユーザーかどうか）
static func field_entries() -> Array:
	var entries: Array = []
	for slot in SLOT_COUNT:
		if _slots[slot] != EMPTY:
			entries.append({"gate": slot, "id": _slots[slot], "player": slot == _user_slot})
	return entries


static func slot_pururin_id(slot: int) -> String:
	return _slots[slot]


static func is_locked(slot: int) -> bool:
	return _locked[slot]


## 施錠・解錠を切り替える。切り替えたあとの状態（施錠中なら true）を返す。
static func toggle_lock(slot: int) -> bool:
	_locked[slot] = not _locked[slot]
	return _locked[slot]


## スロットに個体を入れる（EMPTY で空にする）。施錠中のスロット、一覧に無い個体、
## 他のスロットで使っている個体は入れない（何もせず false を返す）。
static func set_slot(slot: int, identifier: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or _locked[slot]:
		return false
	if identifier != EMPTY:
		if PururinRosterConfig.pururin_by_id(identifier).is_empty():
			return false
		for other in SLOT_COUNT:
			if other != slot and _slots[other] == identifier:
				return false
	_slots[slot] = identifier
	return true


## 今出ている個体の、次（direction=1）か前（-1）の個体。順番は「未選択 → 一覧の順 → 未選択」で回る。
## 他のスロットで使っている個体も、飛ばさずに返す（入れられるかどうかは、set_slot と slot_holding で決める）。
static func cycle_candidate(current: String, direction: int) -> String:
	var choices: Array[String] = [EMPTY]
	for identifier in roster_ids():
		choices.append(identifier)
	var index := choices.find(current)
	assert(index >= 0, "一覧に無い個体です: %s" % current)
	return choices[posmod(index + (1 if direction >= 0 else -1), choices.size())]


## その個体が入っているスロットの番号。どこにも入っていなければ -1。
static func slot_holding(identifier: String) -> int:
	return _slots.find(identifier) if identifier != EMPTY else -1


## 強制選択。その個体が他のスロットに入っていたら、そちらを空にして、このスロットに入れる。
## このスロットか、先に使っているスロットが施錠中なら、何もせず false を返す。一覧に無い個体も同じ。
static func take_slot(slot: int, identifier: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or _locked[slot] or PururinRosterConfig.pururin_by_id(identifier).is_empty():
		return false
	var holder := slot_holding(identifier)
	if holder >= 0 and holder != slot:
		if _locked[holder]:
			return false
		_slots[holder] = EMPTY
	_slots[slot] = identifier
	return true


## スロットを、上の枠（direction=-1）か下の枠（1）のスロットと入れ替える。
## 中身・ユーザーかどうか・施錠も一緒に動く。動いたあとの枠の番号を返す（端では動かず、元の番号）。
static func move_slot(slot: int, direction: int) -> int:
	var target := slot + (1 if direction >= 0 else -1)
	if slot < 0 or slot >= SLOT_COUNT or target < 0 or target >= SLOT_COUNT:
		return slot
	var identifier := _slots[slot]
	_slots[slot] = _slots[target]
	_slots[target] = identifier
	var locked := _locked[slot]
	_locked[slot] = _locked[target]
	_locked[target] = locked
	if _user_slot == slot:
		_user_slot = target
	elif _user_slot == target:
		_user_slot = slot
	return target


## 枠順ランダム。8つのスロット全部（施錠中・未選択も含む）を、でたらめに並べ替える。
static func shuffle_gate_order() -> void:
	var order: Array = range(SLOT_COUNT)
	order.shuffle()
	var slots := _slots.duplicate()
	var locks := _locked.duplicate()
	var user := _user_slot
	for position in SLOT_COUNT:
		var source: int = order[position]
		_slots[position] = slots[source]
		_locked[position] = locks[source]
		if source == user:
			_user_slot = position


## キャラ選択ランダム。施錠していないスロット全部（ユーザーも含む）に、でたらめに個体を入れる。
## 施錠中のスロットが使っている個体は選ばない。重複なし。個体が足りなければ、残りは未選択。
static func randomize_unlocked() -> void:
	var pool: Array[String] = []
	for identifier in roster_ids():
		var holder := slot_holding(identifier)
		if holder < 0 or not _locked[holder]:
			pool.append(identifier)
	pool.shuffle()
	var next := 0
	for slot in SLOT_COUNT:
		if _locked[slot]:
			continue
		_slots[slot] = pool[next] if next < pool.size() else EMPTY
		next += 1


## キャラ選択全解除。施錠していないスロット全部（ユーザーも含む）を、未選択にする。
static func clear_unlocked() -> void:
	for slot in SLOT_COUNT:
		if not _locked[slot]:
			_slots[slot] = EMPTY


## レースを始められない理由。始められるなら空。"no_player"＝ユーザーが未選択、"no_opponent"＝相手が1体もいない。
static func race_start_problem() -> String:
	if _slots[_user_slot] == EMPTY:
		return "no_player"
	if selected_opponent_ids().is_empty():
		return "no_opponent"
	return ""


## 全部のスロットを、起動した直後の状態にする（全部未選択・全部解錠・ユーザーは1枠）。
static func clear_slots() -> void:
	_slots = _empty_slots()
	_locked = _no_locks()
	_user_slot = 0


## 測定とテスト用。ユーザーを1枠に指定の個体で置き、残りの枠を、ほかの個体で一覧の順に埋める。
## 一覧に無い個体を指定したら、何もせず false を返す。
static func select_full_field(player_id: String) -> bool:
	if PururinRosterConfig.pururin_by_id(player_id).is_empty():
		return false
	clear_slots()
	_slots[0] = player_id
	var slot := 1
	for identifier in roster_ids():
		if identifier != player_id and slot < SLOT_COUNT:
			_slots[slot] = identifier
			slot += 1
	return true


## 選択を一時的に変えて、あとで戻すための控え（個体・施錠・ユーザーの枠）。
static func slots_snapshot() -> Dictionary:
	return {"slots": _slots.duplicate(), "locked": _locked.duplicate(), "user_slot": _user_slot}


static func restore_slots(snapshot: Dictionary) -> void:
	clear_slots()
	for slot in SLOT_COUNT:
		_slots[slot] = str(snapshot["slots"][slot])
		_locked[slot] = bool(snapshot["locked"][slot])
	_user_slot = int(snapshot["user_slot"])


static func roster_ids() -> Array[String]:
	var ids: Array[String] = []
	for pururin: Variant in PururinRosterConfig.values().get("roster", []):
		if pururin is Dictionary:
			ids.append(str(pururin.get("id", "")))
	return ids


## 一覧で、最初の操作個体になっている個体（測定とテストの既定に使う）。
static func default_player_pururin_id() -> String:
	return PururinRosterConfig.default_player_pururin_id()
