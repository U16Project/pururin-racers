extends RefCounted
## レース開始前に選択した距離をシーン間で共有する実行時セッション設定。

const SUPPORTED_DISTANCE_M := [1200.0, 1600.0, 2000.0, 2400.0, 3000.0]
const DEFAULT_DISTANCE_M := 2000.0

static var _selected_distance_m := DEFAULT_DISTANCE_M


static func supported_distances_m() -> Array:
	return SUPPORTED_DISTANCE_M.duplicate()


static func selected_distance_m() -> float:
	return _selected_distance_m


static func select_distance(distance_m: float) -> float:
	for supported_distance in SUPPORTED_DISTANCE_M:
		if is_equal_approx(float(supported_distance), distance_m):
			_selected_distance_m = float(supported_distance)
			return _selected_distance_m
	_selected_distance_m = DEFAULT_DISTANCE_M
	return _selected_distance_m
