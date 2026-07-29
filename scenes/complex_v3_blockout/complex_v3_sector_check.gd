extends SceneTree

const CATALOG_PATH := "res://scenes/complex_v3_blockout/sector_catalog.json"
const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")


func _initialize() -> void:
	var catalog := _load_json(CATALOG_PATH)
	var errors := PackedStringArray()
	var total_spaces := 0
	var total_portals := 0
	for sector_value: Variant in catalog.get("sectors", []):
		var sector := sector_value as Dictionary
		var packed := load(str(sector["scene"])) as PackedScene
		if packed == null:
			errors.append("Cannot load %s" % sector["scene"])
			continue
		var part := packed.instantiate() as ComplexV3BlockoutPart
		part.include_ceilings = false
		part.preview_shared_infrastructure_when_standalone = false
		root.add_child(part)
		await process_frame
		for error: String in part.validate_against_handoff():
			errors.append("%s: %s" % [sector["sector_id"], error])
		var stats := part.get_build_stats()
		if int(stats.get("spaces", 0)) != int(sector["space_count"]):
			errors.append("%s expected %d spaces, built %d" % [sector["sector_id"], int(sector["space_count"]), int(stats.get("spaces", 0))])
		if int(stats.get("route_spaces", 0)) + int(stats.get("anchors", 0)) + int(stats.get("transitions", 0)) != 0:
			errors.append("%s duplicated shared infrastructure" % sector["sector_id"])
		total_spaces += int(stats.get("spaces", 0))
		total_portals += part.get_portal_passages().size()
		part.queue_free()
		await process_frame

	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	blockout.include_ceilings = false
	root.add_child(blockout)
	await process_frame
	for error: String in blockout.validate_against_handoff():
		errors.append(error)
	var sector_ids := blockout.get_sector_ids()
	if not sector_ids.is_empty():
		var selected := sector_ids[0]
		blockout.show_sector(selected)
		if _visible_zone_count(blockout) != 1:
			errors.append("Sector view must show exactly one zone")
		blockout.show_sector_with_neighbors(selected)
		var expected_context := 1 + blockout.get_sector_neighbors(selected).size()
		if _visible_zone_count(blockout) != expected_context:
			errors.append("Neighbor view expected %d zones, found %d" % [expected_context, _visible_zone_count(blockout)])
		blockout.show_full_complex()
		if _visible_zone_count(blockout) != 30:
			errors.append("Full view must show 30 zones")
	if total_spaces != 139:
		errors.append("Sector scenes total %d spaces instead of 139" % total_spaces)
	if total_portals != 147:
		errors.append("Sector scenes total %d passages instead of 147" % total_portals)

	if errors.is_empty():
		print("COMPLEX_V3_SECTORS_OK sectors=30 spaces=%d portals=%d modes=3" % [total_spaces, total_portals])
	else:
		for error: String in errors:
			push_error(error)
	blockout.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _visible_zone_count(blockout: ComplexV3Blockout) -> int:
	var count := 0
	for child: Node in blockout.get_node("Zones").get_children():
		if child.visible:
			count += 1
	return count
