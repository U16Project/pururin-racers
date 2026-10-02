extends RefCounted
## ローカルCPUの出力判断。共通の開始ノッチを返し、心拍安全ガードはランナー側で適用する。


static func decide(_state: Dictionary, settings: Dictionary) -> Dictionary:
	return {"drive_level": float(settings["cpu_start_drive_level"])}
