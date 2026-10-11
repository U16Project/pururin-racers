extends GutTest


## 日本語 UI 用フォントが client に同梱されていること。
func test_noto_sans_jp_regular_exists() -> void:
	var path := "res://fonts/NotoSansJP-Regular.otf"
	assert_true(ResourceLoader.exists(path), "Noto Sans JP Regular が res://fonts にあること")
