extends SceneTree

const MANIFEST_PATH := "res://tools/complex_v3_regeneration/rollouts/upper_generation_manifest.json"
const DRESSING_PATH := "res://scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"
const HANDOFF_PATH := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const OUTPUT := "res://scenes/complex_v3_regeneration/rollout/upper/reports/visuals"
const VISUAL_SECTORS := ["U-CONTROL", "U-EMERGENCY", "U-FREIGHT"]

var _errors := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest := _load_json(MANIFEST_PATH)
	var dressing := _load_json(DRESSING_PATH)
	var dressing_by_sector := {}
	for value: Variant in dressing.get("sectors", []):
		var item := value as Dictionary
		dressing_by_sector[str(item.get("sector_id", ""))] = item
	var loaded := 0
	var object_count := 0
	for value: Variant in manifest.get("sectors", []):
		var sector := value as Dictionary
		var sector_id := str(sector.get("sector_id", ""))
		var architecture_path := str(sector.get("output_resource_dir", "")) + "/Generated/Architecture/" + str(sector.get("scene_name", "")) + ".tscn"
		var architecture := load(architecture_path) as PackedScene
		var dressing_data := dressing_by_sector.get(sector_id, {}) as Dictionary
		var authored := load(str(dressing_data.get("dressing_scene", ""))) as PackedScene
		if architecture == null or authored == null:
			_errors.append("cannot load architecture or dressing for %s" % sector_id)
			continue
		var architecture_instance := architecture.instantiate()
		var authored_instance := authored.instantiate()
		root.add_child(architecture_instance)
		root.add_child(authored_instance)
		loaded += 1
		object_count += authored_instance.get_child_count()
		_validate_shapes(architecture_instance, sector_id)
		architecture_instance.free()
		authored_instance.free()
	if loaded != int(manifest.get("sector_count", -1)):
		_errors.append("loaded %d sectors, expected %s" % [loaded, manifest.get("sector_count", -1)])
	if object_count != 149:
		_errors.append("loaded %d authored objects, expected 149" % object_count)
	if _errors.is_empty() and OS.get_cmdline_user_args().has("--visual"):
		await _render_comparisons(manifest, dressing_by_sector)
	if _errors.is_empty():
		print("UPPER_ROLLOUT_GODOT_OK sectors=%d authored_objects=%d" % [loaded, object_count])
	else:
		for message: String in _errors:
			push_error(message)
	quit(0 if _errors.is_empty() else 1)


func _validate_shapes(node: Node, sector_id: String) -> void:
	if node is CollisionShape3D and (node as CollisionShape3D).shape == null:
		_errors.append("empty collision shape in %s: %s" % [sector_id, node.get_path()])
	for child: Node in node.get_children():
		_validate_shapes(child, sector_id)


func _render_comparisons(manifest: Dictionary, dressing_by_sector: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		_errors.append("visual comparison requires a rendering display")
		return
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var handoff := _load_json(HANDOFF_PATH)
	var manifest_by_sector := {}
	for value: Variant in manifest.get("sectors", []):
		var item := value as Dictionary
		manifest_by_sector[str(item["sector_id"])] = item
	for sector_id: String in VISUAL_SECTORS:
		var sector_bounds: Array = []
		for value: Variant in handoff.get("sectors", []):
			var handoff_sector := value as Dictionary
			if str(handoff_sector["id"]) == sector_id:
				sector_bounds = handoff_sector["bounds_xz"]
		var center := Vector3((float(sector_bounds[0]) + float(sector_bounds[2])) * 0.5, 0.0, (float(sector_bounds[1]) + float(sector_bounds[3])) * 0.5)
		var extent := maxf(float(sector_bounds[2]) - float(sector_bounds[0]), float(sector_bounds[3]) - float(sector_bounds[1]))
		for phase: String in ["before", "after"]:
			var world := Node3D.new()
			root.add_child(world)
			_add_lighting(world)
			if phase == "before":
				var zone_path := str((dressing_by_sector[sector_id] as Dictionary)["zone_scene"])
				var zone := (load(zone_path) as PackedScene).instantiate() as ComplexV3BlockoutPart
				zone.include_ceilings = false
				zone.build_collisions = false
				world.add_child(zone)
			else:
				var rollout := manifest_by_sector[sector_id] as Dictionary
				var architecture_path := str(rollout["output_resource_dir"]) + "/Generated/Architecture/" + str(rollout["scene_name"]) + ".tscn"
				var architecture := (load(architecture_path) as PackedScene).instantiate()
				world.add_child(architecture)
				_hide_ceilings(architecture)
				var authored := (load(str((dressing_by_sector[sector_id] as Dictionary)["dressing_scene"])) as PackedScene).instantiate()
				world.add_child(authored)
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = maxf(extent * 1.25, 12.0)
			camera.far = 500.0
			world.add_child(camera)
			camera.global_position = center + Vector3(extent * 0.35, 70.0, extent * 0.25)
			camera.look_at(center, Vector3.FORWARD)
			camera.make_current()
			for _frame: int in range(4):
				await process_frame
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			var path := OUTPUT.path_join("%s_%s.png" % [sector_id.to_lower().replace("-", "_"), phase])
			if root.get_texture().get_image().save_png(path) != OK:
				_errors.append("cannot save %s" % path)
			else:
				print("UPPER_ROLLOUT_VIEW %s" % ProjectSettings.globalize_path(path))
			world.free()
			await process_frame


func _add_lighting(world: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.025, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.76, 0.86)
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -30, 0)
	light.light_energy = 1.2
	world.add_child(light)


func _hide_ceilings(node: Node) -> void:
	if node is MeshInstance3D and "ceiling" in str(node.get_path()).to_lower():
		(node as MeshInstance3D).visible = false
	for child: Node in node.get_children():
		_hide_ceilings(child)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value as Dictionary if value is Dictionary else {}
