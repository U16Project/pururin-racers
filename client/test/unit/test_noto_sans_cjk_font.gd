extends GutTest


## 日本語 UI 用フォントが client に同梱されていること。
func test_noto_sans_cjk_regular_exists() -> void:
	var path := "res://fonts/NotoSansCJK-Regular.ttc"
	assert_true(ResourceLoader.exists(path), "Noto Sans CJK Regular が res://fonts にあること")
