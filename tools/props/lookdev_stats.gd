extends Node
## Prints render statistics of a scene from several player positions (needs a display, e.g. xvfb-run).
## godot --path . res://tools/props/lookdev_stats.tscn -- <scene.tscn> <name>:<x,y,z>:<yaw_deg> ...
## Output: LOOKDEV_STATS <name> draw_calls=<n> objects=<n> primitives=<n> video_mem_mb=<n> texture_mem_mb=<n>

const SETTLE_FRAMES := 30


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := (load(args[0]) as PackedScene).instantiate()
	add_child(scene)
	await _frames(SETTLE_FRAMES)
	var player := scene.get_node_or_null(^"Player") as Node3D
	for view in args.slice(1):
		var parts := view.split(":")
		var pos := parts[1].split_floats(",")
		if player:
			player.set_physics_process(false)
			player.global_position = Vector3(pos[0], pos[1], pos[2])
			player.rotation = Vector3(0, deg_to_rad(float(parts[2])), 0)
		await _frames(SETTLE_FRAMES)
		print("LOOKDEV_STATS %s draw_calls=%d objects=%d primitives=%d video_mem_mb=%.0f texture_mem_mb=%.0f" % [
			parts[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	get_tree().quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
