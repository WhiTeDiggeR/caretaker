extends SceneTree

## Binds a sector's authored door objects to door anchors by exact ID and writes the
## sector bindings document. Usage:
##   godot --headless --path . --script res://scenes/complex_v3_regeneration/bind_doors_cli.gd -- --sector-id U-ROUTE-A [--dry-run]

const MANIFEST_PATH := "res://tools/complex_v3_regeneration/sector_generation_manifest.json"
const BINDINGS_DIR := "res://scenes/complex_v3_blockout/bindings"


func _init() -> void:
	var sector_id := ""
	var dry_run := false
	var arguments := OS.get_cmdline_user_args()
	for index: int in arguments.size():
		if arguments[index] == "--sector-id" and index + 1 < arguments.size():
			sector_id = arguments[index + 1]
		elif arguments[index] == "--dry-run":
			dry_run = true
	if sector_id.is_empty():
		_fail("--sector-id is required")
		return
	var manifest := _load_json(MANIFEST_PATH)
	var sector := {}
	for item: Variant in manifest.get("sectors", []) as Array:
		if str((item as Dictionary).get("sector_id", "")) == sector_id:
			sector = item as Dictionary
	if sector.is_empty():
		_fail("unknown sector: %s" % sector_id)
		return
	var authored_scene_path := str(sector["authored_scene"])
	var authored := (load(authored_scene_path) as PackedScene).instantiate() as Node3D
	if authored == null or not authored.transform.is_equal_approx(Transform3D.IDENTITY):
		_fail("authored scene root must be Node3D at identity: %s" % authored_scene_path)
		return
	var objects: Array = []
	_collect(authored, objects)
	var anchor_document := _load_json("%s/anchor_frames.json" % str(sector["output_resource_dir"]))
	var result := ComplexV3DoorBindingBuilder.build_bindings(
		objects,
		anchor_document,
		ProjectSettings.globalize_path("res://%s" % str(sector["source_svg"])),
		authored_scene_path,
		sector_id
	)
	for line: Variant in result["skipped"] as Array:
		print("SKIPPED: ", line)
	if not bool(result["ok"]):
		for line: String in result["errors"] as PackedStringArray:
			printerr("ERROR: ", line)
		_fail("door binding failed")
		return
	var bindings_path := "%s/%s.bindings.json" % [BINDINGS_DIR, sector_id.to_lower().replace("-", "_")]
	var merged := ComplexV3DoorBindingBuilder.merge_document(
		_load_json(bindings_path), str(anchor_document.get("map_id", "")), sector_id, result["bindings"] as Array
	)
	print("DOOR_BINDINGS sector=%s bound=%d total=%d dry_run=%s" % [sector_id, (result["bindings"] as Array).size(), (merged["bindings"] as Array).size(), str(dry_run)])
	if not dry_run:
		var file := FileAccess.open(bindings_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(merged, "  ") + "\n")
		file.close()
	authored.free()
	quit(0)


func _collect(node: Node, objects: Array) -> void:
	for child: Node in node.get_children():
		if child is AnchoredObject3D:
			objects.append(child)
		_collect(child, objects)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(2)
