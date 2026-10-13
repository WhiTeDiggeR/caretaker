extends SceneTree
## Renders first-person views of the v4 complex for visual checks (needs a renderer, so run without --headless).
## godot --path . --resolution 1280x720 --script res://tools/complex_v4/render_view.gd -- [--debug] [--ceilings] x y z yaw pitch out.png ...
## Player feet at (x, y, z); yaw/pitch in degrees. --debug paints walls red, floors green, ceilings blue, shaft walls yellow,
## landings magenta, steps cyan, railings grey on a white background, so any hole shows up white.

const TEST_SCENE := "res://scenes/complex_v4/complex_v4_blockout_test.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _debug_color(path: String) -> Color:
	if path.contains("/Shaft"):
		return Color(1, 0.9, 0.1)
	if path.contains("/Landings"):
		return Color(0.9, 0.2, 0.9)
	if path.contains("/Railings"):
		return Color(0.4, 0.4, 0.4)
	if path.contains("/Stairs/"):
		return Color(0.1, 0.8, 0.9)
	if path.contains("/Walls/"):
		return Color(0.9, 0.25, 0.2)
	if path.contains("/Floors/"):
		return Color(0.2, 0.7, 0.2)
	if path.contains("/Ceilings/"):
		return Color(0.2, 0.3, 0.9)
	return Color(0.6, 0.6, 0.6)


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var debug := args.has("--debug")
	var ceilings := args.has("--ceilings")
	args = args.filter(func(value: String) -> bool: return not value.begins_with("--"))
	var test: Node = (load(TEST_SCENE) as PackedScene).instantiate()
	var blockout: Node = test.get_node("ComplexV4Blockout")
	blockout.set("include_ceilings", ceilings)
	root.add_child(test)
	await process_frame
	(test.get_node("CanvasLayer") as CanvasLayer).visible = false
	if debug:
		var environment := (test.get_node("WorldEnvironment") as WorldEnvironment).environment
		environment.background_color = Color(1, 1, 1)
		environment.fog_enabled = false
		for node: Node in test.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if str(mesh.get_path()).contains("/Player"):
				continue
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = _debug_color(str(mesh.get_path()))
			mesh.material_override = material
	var player: Node3D = test.get_node("Player")
	var camera: Camera3D = test.get_node("Player/Camera3D")
	player.set_physics_process(false)
	player.set_process(false)
	var index := 0
	while index + 5 < args.size():
		player.global_position = Vector3(float(args[index]), float(args[index + 1]), float(args[index + 2]))
		player.rotation_degrees = Vector3(0, float(args[index + 3]), 0)
		camera.rotation_degrees = Vector3(float(args[index + 4]), 0, 0)
		camera.make_current()
		for _frame in 5:
			await process_frame
		root.get_texture().get_image().save_png(str(args[index + 5]))
		index += 6
	quit()
