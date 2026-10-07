extends RefCounted
## レース開始前に選択した距離と操作個体をシーン間で共有する実行時セッション設定。

const SUPPORTED_DISTANCE_M := [1200.0, 1600.0, 2000.0, 2400.0, 3000.0]
const DEFAULT_DISTANCE_M := 2000.0
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

static var _selected_distance_m := DEFAULT_DISTANCE_M
static var _selected_player_pururin_id := default_player_pururin_id()


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
	return _selected_player_pururin_id


static func default_player_pururin_id() -> String:
	return PururinRosterConfig.default_player_pururin_id()
