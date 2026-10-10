extends SceneTree

## Every sector has an (empty) set-dressing sub-scene: it loads, carries the sector id and contains no placed objects.
## The old placed objects were removed on purpose (sectors were redrawn); objects are placed again from scratch.
const MANIFEST_PATH := "res://scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"


func _initialize() -> void:
	var errors := PackedStringArray()
	var document := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var count := 0
	for sector_value: Variant in document.get("sectors", []):
		var sector := sector_value as Dictionary
		var sector_id := str(sector.get("sector_id", ""))
		var scene := load(str(sector.get("dressing_scene", ""))) as PackedScene
		if scene == null:
			errors.append("cannot load the dressing scene of %s" % sector_id)
			continue
		var instance := scene.instantiate()
		if str(instance.get_meta("sector_id", "")) != sector_id:
			errors.append("%s: dressing scene carries sector id %s" % [sector_id, str(instance.get_meta("sector_id", ""))])
		if instance.get_child_count() != 0:
			errors.append("%s: %d placed objects remain" % [sector_id, instance.get_child_count()])
		if not (sector.get("placements", [null]) as Array).is_empty():
			errors.append("%s: manifest still lists placements" % sector_id)
		instance.free()
		count += 1
	if count != int(document.get("sector_count", -1)):
		errors.append("sector count %d does not match the manifest" % count)
	if errors.is_empty():
		print("SET_DRESSING_GODOT_SCENES_OK sectors=%d objects=0" % count)
		quit(0)
	else:
		for error: String in errors:
			push_error(error)
		quit(1)
