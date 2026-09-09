extends SceneTree

const PILOT := "res://scenes/complex_v3_regeneration/pilots/route_a_vertical/pilot_scene.tscn"
const OUTPUT := "res://scenes/complex_v3_regeneration/pilots/route_a_vertical/reports/visuals"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pilot := (load(PILOT) as PackedScene).instantiate() as Node3D
	root.add_child(pilot)
	var lighting := WorldEnvironment.new()
	lighting.environment = Environment.new()
	lighting.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	lighting.environment.ambient_light_energy = 0.7
	pilot.add_child(lighting)
	var camera := Camera3D.new()
	pilot.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_hide_ceilings(pilot)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for view: Dictionary in [
		{"name": "overview", "eye": Vector3(-38, 22, 29), "target": Vector3(-53, -2, 2), "size": 38.0},
		{"name": "shaft", "eye": Vector3(-46, 9, 2), "target": Vector3(-52.5, -2.8, 9.5), "size": 13.0},
		{"name": "lower-entry", "eye": Vector3(-53.6, -3.8, 3.2), "target": Vector3(-53.6, -4, 9), "size": 6.0},
	]:
		camera.global_position = view["eye"]
		camera.look_at(view["target"])
		camera.size = view["size"]
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await process_frame
		var result := root.get_texture().get_image().save_png(OUTPUT.path_join(view["name"] + ".png"))
		if result != OK:
			push_error("Review capture failed: %s" % error_string(result))
			quit(1)
			return
	print("ROUTE_A_REVIEW_RENDERS_OK")
	quit(0)


func _hide_ceilings(node: Node) -> void:
	if node is MeshInstance3D and "ceiling" in str(node.get_path()).to_lower():
		(node as MeshInstance3D).visible = false
	for child: Node in node.get_children():
		_hide_ceilings(child)
