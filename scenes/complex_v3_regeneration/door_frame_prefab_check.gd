extends SceneTree

## Every door object of every sector set dressing must instance a frame prefab that declares its post
## spacing, and `scale.x * spacing` must equal the width of the handoff portal the object belongs to.
## This is what lets the door binding fit any frame type to the door opening.
const HANDOFF := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const MANIFEST := "res://tools/complex_v3_regeneration/sector_generation_manifest.json"
const TOLERANCE_M := 0.001


func _init() -> void:
	var errors := PackedStringArray()
	var handoff := JSON.parse_string(FileAccess.get_file_as_string(HANDOFF)) as Dictionary
	var widths := {}
	for key: String in ["internal_portals", "external_portals"]:
		for portal: Dictionary in handoff[key]:
			widths[str(portal["id"])] = float(portal["width"])
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	var checked := 0
	var by_prefab := {}
	for sector: Dictionary in manifest["sectors"]:
		var authored := (load(str(sector["authored_scene"])) as PackedScene).instantiate()
		var objects: Array = []
		_collect(authored, objects)
		for object: AnchoredObject3D in objects:
			if object.expected_anchor_type != "door":
				continue
			checked += 1
			var label := "%s/%s" % [sector["sector_id"], object.name]
			var spacing := ComplexV3DoorBindingBuilder.frame_post_spacing(object)
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
	print("DOOR_FRAME_PREFAB_CHECK doors=%d prefabs=%s errors=%d" % [checked, JSON.stringify(by_prefab), errors.size()])
	quit(0 if errors.is_empty() else 1)


func _collect(node: Node, objects: Array) -> void:
	for child: Node in node.get_children():
		if child is AnchoredObject3D:
			objects.append(child)
		_collect(child, objects)
