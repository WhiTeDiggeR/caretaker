extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")
const CATALOG_PATH := "res://scenes/complex_v3_blockout/sector_catalog.json"
const HANDOFF_PATH := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const OUTPUT_DIR := "user://complex_v3_sector_captures"


func _initialize() -> void:
	root.size = Vector2i(1024, 1024)
	var catalog := _load_json(CATALOG_PATH)
	var handoff := _load_json(HANDOFF_PATH)
	var sector_bounds := _index_sector_bounds(handoff)
	var world := Node3D.new()
	world.name = "VisualCheckWorld"
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.76)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-72.0, -24.0, 0.0)
	light.light_color = Color(0.82, 0.88, 1.0)
	light.light_energy = 1.25
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.2
	camera.far = 220.0
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	world.add_child(camera)
	camera.make_current()
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	blockout.include_ceilings = false
	blockout.build_collisions = false
	blockout.show_space_labels = false
	world.add_child(blockout)
	await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var errors := PackedStringArray()
	var capture_count := 0
	for sector_value: Variant in catalog.get("sectors", []):
		var sector := sector_value as Dictionary
		var sector_id := str(sector["sector_id"])
		var level_id := str(sector["level"])
		blockout.show_sector(sector_id)
		blockout.set_level_filter(level_id)
		var bounds: Array = sector_bounds.get(sector_id, _fallback_bounds(sector_id))
		var center := Vector2((float(bounds[0]) + float(bounds[2])) * 0.5, (float(bounds[1]) + float(bounds[3])) * 0.5)
		var extent := maxf(float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1]))
		var focus := blockout.get_sector_focus(sector_id)
		camera.size = maxf(extent * 1.16, 12.0)
		camera.global_position = Vector3(center.x, focus.y + 80.0, center.y)
		await process_frame
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/%s.png" % [OUTPUT_DIR, sector_id.to_lower().replace("-", "_")]
		var result := image.save_png(path)
		if result != OK:
			errors.append("Failed to save %s: %s" % [path, error_string(result)])
		else:
			capture_count += 1
			print("COMPLEX_V3_VISUAL_CAPTURE %s" % ProjectSettings.globalize_path(path))
	world.queue_free()
	await process_frame
	if errors.is_empty():
		print("COMPLEX_V3_VISUAL_OK captures=%d" % capture_count)
	else:
		for error: String in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _index_sector_bounds(handoff: Dictionary) -> Dictionary:
	var result := {}
	for sector_value: Variant in handoff.get("sectors", []):
		var sector := sector_value as Dictionary
		result[str(sector["id"])] = sector["bounds_xz"]
	return result


func _fallback_bounds(sector_id: String) -> Array:
	if sector_id == "T-CIRCULATION":
		return [-110.0, 15.0, 32.0, 82.0]
	return [-8.0, -8.0, 8.0, 8.0]
