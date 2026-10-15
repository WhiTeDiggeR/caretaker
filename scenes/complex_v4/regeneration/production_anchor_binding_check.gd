extends Node

## Every production sector scene must instantiate, find its generated anchor frames and apply its object bindings
## without errors, and applying them must not move any placed object (the authored scene already stands where its
## bindings put it). A sector whose package was generated from an older canonical SVG waits for regeneration by the
## author: its bindings name anchors of the new SVG and are checked by `tools/complex_v4/check_bindings.py` instead.
## The binding mechanics themselves are covered by sector_anchor_controller_check.tscn.
const ZONES := ["upper", "lower", "technical"]
const MANIFEST := "res://tools/complex_v4/sector_generation_manifest.json"
## An object may end up this far from its authored position after applying its binding (metres).
const POSITION_TOLERANCE := 0.02


func _ready() -> void:
	var errors := PackedStringArray()
	var checked := 0
	var bound := 0
	var pending := PackedStringArray()
	var stale := _stale_sectors()
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
				var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(controller.object_bindings_path))
				var bindings := ((document as Dictionary).get("bindings", []) as Array) if document is Dictionary else []
				var sector_id := str(sector.get_meta("complex_v4_sector_id", ""))
				if not bindings.is_empty() and stale.has(sector_id):
					pending.append(sector_id)
				else:
					var before := _authored_transforms(sector)
					errors.append_array(controller.apply_bindings())
					if not controller.is_ready_for_use():
						errors.append("%s controller is not ready" % file_name)
					errors.append_array(_moved(sector, before, file_name))
					bound += bindings.size()
			checked += 1
			sector.queue_free()
			await get_tree().process_frame
	if checked != 32:
		errors.append("expected 32 sector scenes, found %d" % checked)
	if errors.is_empty():
		print("COMPLEX_V4_PRODUCTION_ANCHOR_BINDINGS_OK sectors=%d bindings=%d pending_regeneration=%s" % [checked, bound, ",".join(pending)])
		get_tree().quit(0)
	else:
		for error: String in errors:
			push_error(error)
		get_tree().quit(1)


func _authored_transforms(sector: Node) -> Dictionary:
	var result := {}
	for node: Node in sector.find_children("*", "AnchoredObject3D", true, false):
		result[(node as AnchoredObject3D).object_id] = (node as Node3D).global_transform
	return result


func _moved(sector: Node, before: Dictionary, file_name: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for node: Node in sector.find_children("*", "AnchoredObject3D", true, false):
		var anchored := node as AnchoredObject3D
		var was := before[anchored.object_id] as Transform3D
		if was.origin.distance_to(anchored.global_transform.origin) > POSITION_TOLERANCE or not was.basis.is_equal_approx(anchored.global_transform.basis):
			errors.append("%s: %s moves when its binding is applied" % [file_name, anchored.object_id])
	return errors


## Sector IDs whose generated package was built from another version of the canonical SVG.
func _stale_sectors() -> Dictionary:
	var stale := {}
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	for sector: Dictionary in manifest["sectors"]:
		var generation := JSON.parse_string(FileAccess.get_file_as_string(str(sector["output_resource_dir"]) + "/generation_manifest.json")) as Dictionary
		var built := str((generation.get("source", {}) as Dictionary).get("sha256", "")) if generation else ""
		if built != "sha256:" + FileAccess.get_sha256("res://" + str(sector["source_svg"])):
			stale[str(sector["sector_id"])] = true
	return stale
