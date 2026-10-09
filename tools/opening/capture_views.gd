extends Node

## Renders still frames of a scene for visual review (needs a display, e.g. xvfb-run).
## godot --path . --rendering-driver opengl3 res://tools/opening/capture_views.tscn -- \
##     <scene.tscn> <out_dir> <name>:<x>,<y>,<z>:<yaw_deg>,<pitch_deg>[:<setting>,...] ...
## Each view moves the scene's `Player`, applies the settings and saves a PNG. Settings:
##   <section>=<off|emergency|main>   load section power instantly
##   @call=<node path>.<method>       call a method on a node of the scene (e.g. open a terminal)
##   @wait=<seconds>                  wait before the capture

const SETTLE_FRAMES := 20


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: <scene> <out_dir> <name>:<x,y,z>:<yaw,pitch> ...")
		get_tree().quit(2)
		return
	var scene := (load(args[0]) as PackedScene).instantiate()
	add_child(scene)
	DirAccess.make_dir_recursive_absolute(args[1])
	await _frames(SETTLE_FRAMES)
	var player := scene.get_node_or_null(^"Player") as Node3D
	for view in args.slice(2):
		var parts := view.split(":")
		var pos := parts[1].split_floats(",")
		var angles := parts[2].split_floats(",")
		if player:
			player.set_physics_process(false)
			player.global_position = Vector3(pos[0], pos[1], pos[2])
			player.rotation = Vector3(0, deg_to_rad(angles[0]), 0)
			(player.get_node(^"Camera3D") as Node3D).rotation = Vector3(deg_to_rad(angles[1]), 0, 0)
		var wait := 0.0
		if parts.size() > 3:
			wait = _apply_settings(scene, parts[3])
		await _frames(SETTLE_FRAMES)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		var path := "%s/%s.png" % [args[1], parts[0]]
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURED ", path)
	get_tree().quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _apply_settings(scene: Node, spec: String) -> float:
	var state := GameState.to_dict()
	var wait := 0.0
	for pair in spec.split(","):
		var entry := pair.split("=")
		match entry[0]:
			"@wait":
				wait = float(entry[1])
			"@call":
				var target := entry[1].rsplit(".", true, 1)
				scene.get_node(target[0]).call(target[1])
			_:
				(state["section_power"] as Dictionary)[entry[0]] = entry[1]
	GameState.from_dict(state)
	return wait
