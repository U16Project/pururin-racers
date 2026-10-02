extends RefCounted
## レース開始前に選択した距離と操作個体をシーン間で共有する実行時セッション設定。

const SUPPORTED_DISTANCE_M := [1200.0, 1600.0, 2000.0, 2400.0, 3000.0]
const DEFAULT_DISTANCE_M := 2000.0
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LocalRaceConfig := preload("res://scripts/config/local_race_config.gd")
const STAMINA_LOAD_PRESETS := [
	{"id": "standard", "label": "標準", "multiplier": 1.15},
	{"id": "high", "label": "高負荷", "multiplier": 1.30},
	{"id": "strong", "label": "強高負荷", "multiplier": 1.45},
]

static var _selected_distance_m := DEFAULT_DISTANCE_M
static var _selected_player_pururin_id := default_player_pururin_id()
## config は共通シミュレータのconfig_overridesで使う。実機比較で選んだ時だけ preset へ切り替える。
static var _selected_stamina_load_preset_id := "config"


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


static func stamina_load_presets() -> Array:
	return STAMINA_LOAD_PRESETS.duplicate(true)


static func selected_stamina_load_preset_id() -> String:
	return _selected_stamina_load_preset_id


static func selected_stamina_load_multiplier() -> float:
	for preset: Dictionary in STAMINA_LOAD_PRESETS:
		if str(preset.id) == _selected_stamina_load_preset_id:
			return float(preset.multiplier)
	return LocalRaceConfig.number("stamina_consumption_load_multiplier")


static func selected_stamina_load_preset_index() -> int:
	var multiplier := selected_stamina_load_multiplier()
	for index in STAMINA_LOAD_PRESETS.size():
		if is_equal_approx(float(STAMINA_LOAD_PRESETS[index].multiplier), multiplier):
			return index
	return 1


static func select_stamina_load_preset(identifier: String) -> String:
	for preset: Dictionary in STAMINA_LOAD_PRESETS:
		if str(preset.id) == identifier:
			_selected_stamina_load_preset_id = identifier
			return _selected_stamina_load_preset_id
	_selected_stamina_load_preset_id = "config"
	return _selected_stamina_load_preset_id


static func reset_stamina_load_preset() -> void:
	_selected_stamina_load_preset_id = "config"
