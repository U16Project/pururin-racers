extends GutTest


## GUT がプロジェクトに載っていることの確認（本番ロジックのテストではない）。
func test_gut_is_ready() -> void:
	assert_eq(1 + 1, 2, "GUT の assert が動くこと")
