extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")
const HANDOFF_PATH := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const DEFAULT_OUTPUT_DIR := "user://complex_v3_sector_multiview"


func _initialize() -> void:
	root.size = Vector2i(1280, 900)
	var sector_id := "U-SECURITY"
	var output_dir := DEFAULT_OUTPUT_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sector-id="):
			sector_id = argument.trim_prefix("--sector-id=").to_upper().replace("_", "-")
		elif argument.begins_with("--sector-output="):
			output_dir = argument.trim_prefix("--sector-output=")

	var handoff := _load_json(HANDOFF_PATH)
	var sector_bounds := _index_sector_bounds(handoff)
	if not sector_bounds.has(sector_id):
		push_error("Unknown sector for visual check: %s" % sector_id)
		quit(1)
		return

	var world := Node3D.new()
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.76)
	environment.ambient_light_energy = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	light.light_color = Color(0.84, 0.9, 1.0)
	light.light_energy = 1.45
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.near = 0.15
	camera.far = 500.0
	camera.fov = 48.0
	world.add_child(camera)
	camera.make_current()
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	blockout.include_ceilings = false
	blockout.build_collisions = false
	blockout.show_space_labels = false
	world.add_child(blockout)
	await process_frame
	blockout.show_sector(sector_id)
	var level_id := _sector_level(handoff, sector_id)
	blockout.set_level_filter(level_id)
	await process_frame
	await process_frame

	var bounds: Array = sector_bounds[sector_id]
	var center := Vector2((float(bounds[0]) + float(bounds[2])) * 0.5, (float(bounds[1]) + float(bounds[3])) * 0.5)
	var width := float(bounds[2]) - float(bounds[0])
	var depth := float(bounds[3]) - float(bounds[1])
	var extent := maxf(width, depth)
	var focus := blockout.get_sector_focus(sector_id)
	var target := Vector3(center.x, focus.y + 1.1, center.y)
	var distance := maxf(extent * 1.15, 18.0)
	var height := maxf(extent * 0.72, 12.0)
	var views := [
		{"name": "01_top", "orthogonal": true, "position": Vector3(center.x, focus.y + 90.0, center.y)},
		{"name": "02_north_east", "orthogonal": false, "position": target + Vector3(distance, height, -distance)},
		{"name": "03_south_west", "orthogonal": false, "position": target + Vector3(-distance, height, distance)},
		{"name": "04_route_axis", "orthogonal": false, "position": target + Vector3(0.0, height * 0.6, -distance * 1.35)},
	]
	var sector_dir := output_dir.path_join(sector_id.to_lower().replace("-", "_"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sector_dir))
	var errors := PackedStringArray()
	for view: Dictionary in views:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if bool(view["orthogonal"]) else Camera3D.PROJECTION_PERSPECTIVE
		camera.size = maxf(extent * 1.18, 12.0)
		camera.global_position = view["position"] as Vector3
		camera.look_at(target, Vector3.FORWARD if bool(view["orthogonal"]) else Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := sector_dir.path_join("%s.png" % str(view["name"]))
		var result := root.get_texture().get_image().save_png(path)
		if result != OK:
			errors.append("Failed to save %s: %s" % [path, error_string(result)])
		else:
			print("COMPLEX_V3_SECTOR_VIEW %s" % ProjectSettings.globalize_path(path))
	world.queue_free()
	await process_frame
	if errors.is_empty():
		print("COMPLEX_V3_SECTOR_VISUAL_OK sector=%s views=%d" % [sector_id, views.size()])
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


func _sector_level(handoff: Dictionary, sector_id: String) -> String:
	for sector_value: Variant in handoff.get("sectors", []):
		var sector := sector_value as Dictionary
		if str(sector["id"]) == sector_id:
			return str(sector["level"])
	return ""
