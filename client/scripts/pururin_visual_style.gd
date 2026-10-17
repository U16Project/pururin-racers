extends RefCounted
## 個体の表示色。体の色（見た目の設定の第一カラー）を、操作盤・順位表・着順の丸などにも使う。
## 個体の配列順・ゲート・順位には依存させない。

const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")


static func color_for_pururin(pururin: Dictionary) -> Color:
	return PururinLookConfig.primary_color_for(str(pururin["id"]))


## 走者の番号の色。同じプルの2体目からの番号（「番号#2」など）も、そのプルの色。
static func color_for_racer_id(racer_id: String) -> Color:
	return PururinLookConfig.primary_color_for(racer_id.get_slice("#", 0))
