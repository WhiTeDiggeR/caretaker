extends SceneTree

## Every door object of U-ROUTE-A must sit exactly on its bound door anchor after the
## sector controller applies the bindings, and its frame width must follow the door opening.
const SECTOR_SCENE := "res://scenes/complex_v3_blockout/zones/upper/u_route_a.tscn"
const ANCHOR_FRAMES := "res://gen/u/u_route_a/anchor_frames.json"
const EXPECTED_DOORS := 4
const TOLERANCE_M := 0.0001
const SCALE_TOLERANCE := 0.001


func _init() -> void:
	var errors := PackedStringArray()
	var root := (load(SECTOR_SCENE) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	var controller := root.get_node("AnchorController")
	errors.append_array(controller.apply_bindings() as PackedStringArray)
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_FRAMES))
	var origins := {}
	var widths := {}
	for anchor: Dictionary in (document as Dictionary)["anchors"]:
		origins[str(anchor["anchor_id"])] = anchor["origin"]
		widths[str(anchor["anchor_id"])] = float((anchor.get("bounds", {}) as Dictionary).get("width_m", 0.0))
	var doors := 0
	for node: Node in root.get_node("AuthoredContent/SetDressing").get_children():
		var object := node as AnchoredObject3D
		if object == null or object.expected_anchor_type != "door":
			continue
		doors += 1
		if not origins.has(object.anchor_id):
			errors.append("%s is not bound to a door anchor" % object.name)
			continue
		var origin := origins[object.anchor_id] as Array
		var expected := Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
		if object.global_position.distance_to(expected) > TOLERANCE_M:
			errors.append("%s is at %s, expected %s" % [object.name, object.global_position, expected])
		var expected_scale := float(widths[object.anchor_id]) / ComplexV3DoorBindingBuilder.DOOR_FRAME_POST_SPACING_M
		if absf(object.global_transform.basis.get_scale().x - expected_scale) > SCALE_TOLERANCE:
			errors.append("%s frame width scale is %.4f, expected %.4f" % [object.name, object.global_transform.basis.get_scale().x, expected_scale])
	if doors != EXPECTED_DOORS:
		errors.append("expected %d door objects, found %d" % [EXPECTED_DOORS, doors])
	for line: String in errors:
		printerr("ERROR: ", line)
	print("DOOR_BINDING_CHECK doors=%d errors=%d" % [doors, errors.size()])
	quit(0 if errors.is_empty() else 1)
