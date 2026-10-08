extends RefCounted
## レース開始前に選択した距離と操作個体をシーン間で共有する実行時セッション設定。

const SUPPORTED_DISTANCE_M := [1200.0, 1600.0, 2000.0, 2400.0, 3000.0]
const DEFAULT_DISTANCE_M := 2000.0
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

static var _selected_distance_m := DEFAULT_DISTANCE_M
static var _selected_player_pururin_id := default_player_pururin_id()
## 対戦相手から外した個体。ここに無い候補は、全員出る。
static var _excluded_opponent_ids: Array[String] = []


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


static func selected_player_pururin_id() -> String:
	if PururinRosterConfig.pururin_by_id(_selected_player_pururin_id).is_empty():
		_selected_player_pururin_id = default_player_pururin_id()
	return _selected_player_pururin_id


static func select_player_pururin(identifier: String) -> String:
	if not PururinRosterConfig.pururin_by_id(identifier).is_empty():
		_selected_player_pururin_id = identifier
	else:
		_selected_player_pururin_id = default_player_pururin_id()
	# 自分になった個体は、相手の候補ではなくなる。前に自分だった個体は、相手に入る。
	_excluded_opponent_ids.erase(_selected_player_pururin_id)
	return _selected_player_pururin_id


## 対戦相手の候補（自分が操作する個体のほかの全員）。一覧の順。
static func opponent_candidate_ids() -> Array[String]:
	var player_id := selected_player_pururin_id()
	var ids: Array[String] = []
	for pururin: Variant in PururinRosterConfig.values().get("roster", []):
		if pururin is Dictionary and str(pururin.get("id", "")) != player_id:
			ids.append(str(pururin.get("id", "")))
	return ids


## 今、レースに出る対戦相手。最低1体。
static func selected_opponent_ids() -> Array[String]:
	var ids: Array[String] = []
	for identifier in opponent_candidate_ids():
		if identifier not in _excluded_opponent_ids:
			ids.append(identifier)
	return ids


## 相手を出す・外すを切り替える。最後の1体は外せない（外そうとしたら、何もせず false を返す）。
static func set_opponent_selected(identifier: String, selected: bool) -> bool:
	if identifier not in opponent_candidate_ids():
		return false
	if selected:
		_excluded_opponent_ids.erase(identifier)
		return true
	if identifier in _excluded_opponent_ids:
		return true
	if selected_opponent_ids().size() <= 1:
		return false
	_excluded_opponent_ids.append(identifier)
	return true


static func select_all_opponents() -> void:
	_excluded_opponent_ids.clear()


## 測定などで、選択を一時的に変えて、あとで戻すための控え。
static func excluded_opponent_ids() -> Array[String]:
	return _excluded_opponent_ids.duplicate()


static func restore_excluded_opponent_ids(identifiers: Array) -> void:
	_excluded_opponent_ids.clear()
	for identifier: Variant in identifiers:
		_excluded_opponent_ids.append(str(identifier))


static func default_player_pururin_id() -> String:
	return PururinRosterConfig.default_player_pururin_id()
