extends RefCounted
## 作成済みの個体から送信用の定義を作る。ローカルの path はここだけで扱う。
const Mine := preload("res://scripts/config/my_pururins.gd")
const Looks := preload("res://scripts/config/pururin_look_config.gd")
const Validate := preload("res://scripts/online/online_custom_validation.gd")
const Check := preload("res://scripts/online/online_part_validation.gd")

static func prepare(id: String) -> Dictionary:
	var saved := Mine.entry(id)
	if saved.is_empty():
		return {"error": "作成したぷるりんが見つかりません。"}
	var custom := {}
	for key: String in Validate.FIELDS:
		if key != "parts":
			custom[key] = saved[key].duplicate(true) if saved[key] is Dictionary else saved[key]
	custom["parts"] = {}
	var files := {}
	for part_id: String in Validate.used_parts(custom["look"]):
		if not part_id.begins_with("user/"):
			continue
		if not Looks.parts().has(part_id):
			return {"error": "部品が見つかりません：" + part_id}
		var part: Dictionary = Looks.parts()[part_id].duplicate(true)
		var source: Dictionary = part["source"]
		var path := str(source.get("path", ""))
		var ext := path.get_extension().to_lower()
		if ext not in ["glb", "png"]:
			return {"error": "オンラインの部品は PNG・GLB で保存してください：" + part_id}
		var file := FileAccess.open(path, FileAccess.READ)
		var limit_key := "mesh_bytes" if ext == "glb" else "image_bytes"
		if file == null or file.get_length() > int(load("res://scripts/config/online_config.gd").custom_limits()[limit_key]):
			return {"error": "この部品は大きすぎるか、読めません：" + part_id}
		var bytes := file.get_buffer(file.get_length())
		var reason := Check.check(bytes, ext, true)
		if not reason.is_empty():
			return {"error": "この部品はオンラインで使えません：%s（%s）" % [part_id, reason]}
		var hash_value := Check.sha(bytes)
		source.erase("path")
		source.merge({"hash": hash_value, "ext": ext, "bytes": bytes.size()})
		custom["parts"][part_id] = part
		files[hash_value] = {"ext": ext, "data": bytes}
	var errors := Validate.validate(custom)
	if not errors.is_empty():
		return {"error": "このぷるりんはオンラインで使えません：" + "; ".join(errors)}
	return {"custom": custom, "files": files}
