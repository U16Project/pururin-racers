extends RefCounted
## 太陽の影を出してよいか。
## ブラウザ版では、出さない。ブラウザ版の描き方では、影を付ける光が二重に当たったようになり、
## 画面全体が白っぽく飛んで、地面が見づらくなるため（2026/10/13に、影あり・なしを比べて確かめた）。


static func allowed() -> bool:
	return not OS.has_feature("web")


## 太陽の光に、今の端末に合った影の設定を入れる（出してよい端末では、そのまま）。
static func apply(sun: DirectionalLight3D) -> void:
	if not allowed():
		sun.shadow_enabled = false
