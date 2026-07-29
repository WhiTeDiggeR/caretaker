extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")
const CAPTURES := {
	"U-MEDBAY": "LV-U",
	"U-CHAMBER-6": "LV-U",
	"U-FREIGHT": "LV-U",
	"L-OLD-CORE": "LV-L",
	"T-UTILITIES": "LV-T",
}


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	world.name = "VisualCheckWorld"
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.58, 0.68)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	light.light_color = Color(0.72, 0.82, 1.0)
	light.light_energy = 1.15
	world.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.2
	camera.far = 500.0
	world.add_child(camera)
	camera.make_current()
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	blockout.include_ceilings = false
	blockout.build_collisions = false
	world.add_child(blockout)
	await process_frame

	var output_dir := "user://complex_v3_sector_captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var errors := PackedStringArray()
	for sector_id: String in CAPTURES:
		blockout.show_sector_with_neighbors(sector_id)
		blockout.set_level_filter(str(CAPTURES[sector_id]))
		var focus := blockout.get_sector_focus(sector_id)
		camera.global_position = focus + Vector3(34.0, 48.0, 34.0)
		camera.look_at(focus, Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/%s.png" % [output_dir, sector_id.to_lower().replace("-", "_")]
		var result := image.save_png(path)
		if result != OK:
			errors.append("Failed to save %s: %s" % [path, error_string(result)])
		else:
			print("COMPLEX_V3_VISUAL_CAPTURE %s" % ProjectSettings.globalize_path(path))
	world.queue_free()
	await process_frame
	if errors.is_empty():
		print("COMPLEX_V3_VISUAL_OK captures=%d" % CAPTURES.size())
	else:
		for error: String in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)
