extends Node

## Every production sector scene must instantiate, find its generated anchor frames and apply its (currently empty)
## object bindings without errors. The old placed objects were removed on purpose, so there are no real bindings to
## move or block; the binding mechanics themselves are covered by sector_anchor_controller_check.tscn.
const ZONES := ["upper", "lower", "technical"]


func _ready() -> void:
	var errors := PackedStringArray()
	var checked := 0
	for level: String in ZONES:
		var directory := "res://scenes/complex_v4/zones/%s" % level
		for file_name: String in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".tscn"):
				continue
			var scene := load("%s/%s" % [directory, file_name]) as PackedScene
			if scene == null:
				errors.append("cannot load %s" % file_name)
				continue
			var sector := scene.instantiate()
			add_child(sector)
			await get_tree().process_frame
			var controller := sector.get_node_or_null("AnchorController") as ComplexV4SectorAnchorController
			if controller == null:
				errors.append("%s has no AnchorController" % file_name)
			else:
				errors.append_array(controller.apply_bindings())
				if not controller.is_ready_for_use():
					errors.append("%s controller is not ready" % file_name)
				var bindings := FileAccess.get_file_as_string(controller.object_bindings_path)
				var document: Variant = JSON.parse_string(bindings)
				if not (document is Dictionary) or not ((document as Dictionary).get("bindings", [null]) as Array).is_empty():
					errors.append("%s still has object bindings" % file_name)
			checked += 1
			sector.queue_free()
			await get_tree().process_frame
	if checked != 32:
		errors.append("expected 32 sector scenes, found %d" % checked)
	if errors.is_empty():
		print("COMPLEX_V4_PRODUCTION_ANCHOR_BINDINGS_OK sectors=%d" % checked)
		get_tree().quit(0)
	else:
		for error: String in errors:
			push_error(error)
		get_tree().quit(1)
