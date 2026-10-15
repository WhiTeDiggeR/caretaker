extends SceneTree

## Every door object of every sector set dressing must instance a frame prefab that declares its post
## spacing, and `scale.x * spacing` must equal the width of the handoff portal the object belongs to.
## This is what lets the door binding fit any frame type to the door opening.
## A working door (`FacilityDoor` as the door object's `Door`, bound by stable ID, #224) is built at its own `width`:
## it must equal the width of its binding footprint, which `tools/complex_v4/check_bindings.py` fits to the opening.
const HANDOFF := "res://docs/design/complex_v4/handoff/geometry/complex-handoff.json"
const MANIFEST := "res://tools/complex_v4/sector_generation_manifest.json"
const TOLERANCE_M := 0.001


## Runs at main-loop start, not in _init: the door scripts use autoloads (GameState), which do not exist before it.
func _initialize() -> void:
	var errors := PackedStringArray()
	var handoff := JSON.parse_string(FileAccess.get_file_as_string(HANDOFF)) as Dictionary
	var widths := {}
	for key: String in ["internal_portals", "external_portals"]:
		for portal: Dictionary in handoff[key]:
			widths[str(portal["id"])] = float(portal["width"])
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	var checked := 0
	var working := 0
	var by_prefab := {}
	for sector: Dictionary in manifest["sectors"]:
		var authored := (load(str(sector["authored_scene"])) as PackedScene).instantiate()
		var objects: Array = []
		_collect(authored, objects)
		var footprints := _binding_widths(str(sector["safe_regeneration"]["bindings_input"]))
		for object: AnchoredObject3D in objects:
			if object.expected_anchor_type != "door":
				continue
			var label := "%s/%s" % [sector["sector_id"], object.name]
			var door := object.get_node_or_null("Door")
			if door != null and door.get_script() != null and (door.get_script() as Script).get_global_name() == &"FacilityDoor":
				working += 1
				if not footprints.has(object.object_id):
					errors.append("%s: working door has no binding" % label)
				elif absf(float(door.get("width")) * object.scale.x - float(footprints[object.object_id])) > TOLERANCE_M:
					errors.append("%s: door width %.3f m, binding footprint %.3f m" % [label, float(door.get("width")), footprints[object.object_id]])
				continue
			checked += 1
			var spacing := ComplexV4DoorBindingBuilder.frame_post_spacing(object)
			if spacing <= 0.0:
				errors.append("%s: its prefab declares no door_frame_post_spacing_m" % label)
				continue
			var portal_id := str(object.get_meta("placement_id", ""))
			if not widths.has(portal_id):
				errors.append("%s: no handoff portal %s" % [label, portal_id])
				continue
			var fitted := object.scale.x * spacing
			if absf(fitted - float(widths[portal_id])) > TOLERANCE_M:
				errors.append("%s: scale %.4f x spacing %.2f = %.3f m, portal %s is %.3f m" % [label, object.scale.x, spacing, fitted, portal_id, widths[portal_id]])
			var prefab := str(object.get_node("Content").scene_file_path.get_file())
			by_prefab[prefab] = int(by_prefab.get(prefab, 0)) + 1
		authored.free()
	for line: String in errors:
		printerr("ERROR: ", line)
	print("DOOR_FRAME_PREFAB_CHECK doors=%d working_doors=%d prefabs=%s errors=%d" % [checked, working, JSON.stringify(by_prefab), errors.size()])
	quit(0 if errors.is_empty() else 1)


func _collect(node: Node, objects: Array) -> void:
	for child: Node in node.get_children():
		if child is AnchoredObject3D:
			objects.append(child)
		_collect(child, objects)


## object_id -> footprint width (x) of the sector's bindings.
func _binding_widths(path: String) -> Dictionary:
	var result := {}
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://" + path))
	if document is Dictionary:
		for binding: Dictionary in (document as Dictionary).get("bindings", []):
			result[str((binding["object_ref"] as Dictionary)["object_id"])] = float((binding["footprint_m"] as Array)[0])
	return result
