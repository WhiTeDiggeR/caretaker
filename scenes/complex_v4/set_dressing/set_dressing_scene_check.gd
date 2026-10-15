extends SceneTree

## Every sector has a set-dressing sub-scene: it loads and carries the sector id. The old placed objects were removed on
## purpose (sectors were redrawn); objects are placed again from scratch, only through stable-ID bindings (#224): every
## object is an AnchoredObject3D with an object and an anchor ID, grouped under plain Node3D folders, nothing stands free.
const MANIFEST_PATH := "res://scenes/complex_v4/set_dressing/set_dressing_manifest.json"


func _initialize() -> void:
	var errors := PackedStringArray()
	var document := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var count := 0
	var objects := 0
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
		var placed := _bound_objects(instance, sector_id, errors)
		objects += placed
		if not (sector.get("placements", [null]) as Array).is_empty():
			errors.append("%s: manifest still lists placements" % sector_id)
		instance.free()
		count += 1
	if count != int(document.get("sector_count", -1)):
		errors.append("sector count %d does not match the manifest" % count)
	if errors.is_empty():
		print("SET_DRESSING_GODOT_SCENES_OK sectors=%d objects=%d" % [count, objects])
		quit(0)
	else:
		for error: String in errors:
			push_error(error)
		quit(1)


## Counts the AnchoredObject3D objects below `folder`; anything else placed outside them is an error.
func _bound_objects(folder: Node, sector_id: String, errors: PackedStringArray) -> int:
	var found := 0
	for child: Node in folder.get_children():
		if child is AnchoredObject3D:
			var anchored := child as AnchoredObject3D
			if anchored.object_id.is_empty() or anchored.anchor_id.is_empty():
				errors.append("%s: %s has no object or anchor ID" % [sector_id, child.name])
			found += 1
		elif child.get_class() == "Node3D" and child.get_script() == null:
			found += _bound_objects(child, sector_id, errors)
		else:
			errors.append("%s: %s is placed without a binding" % [sector_id, folder.get_path_to(child)])
	return found
