extends "res://scripts/menu/pururin_picker.gd"
var cpu_only := false

func _rebuild() -> void:
	super._rebuild()
	if cpu_only:
		for tile: Button in _tiles.duplicate():
			if str(tile.call("pururin_id")).begins_with(str(load("res://scripts/config/pururin_maker_config.gd").values()["id_prefix"])):
				_tiles.erase(tile)
				var holder := tile.get_parent()
				_grid.remove_child(holder)
				holder.queue_free()
		_link_tiles()
