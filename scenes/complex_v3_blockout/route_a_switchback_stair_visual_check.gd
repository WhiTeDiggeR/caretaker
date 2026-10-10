extends Node3D

const DEFAULT_OUTPUT_DIR := "user://route_a_stair_visual"

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stair-output="):
			output_dir = argument.trim_prefix("--stair-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await get_tree().process_frame
	await get_tree().process_frame
	var views := [
		{"name": "01_upper_approach", "position": Vector3(1.1, 1.7, -5.5), "target": Vector3(1.1, -1.0, 0.0)},
		{"name": "02_lower_approach", "position": Vector3(-1.1, -4.3, -5.5), "target": Vector3(-1.1, -4.9, 0.0)},
		{"name": "03_intermediate_landing", "position": Vector3(0.0, -2.0, 2.9), "target": Vector3(0.0, -3.2, -2.0)},
		{"name": "04_top_oblique", "position": Vector3(-8.0, 12.5, 9.0), "target": Vector3(0.0, -2.4, 0.0)},
		{"name": "05_upper_fall_protection", "position": Vector3(0.0, 1.7, -2.7), "target": Vector3(0.0, 0.2, 0.5)},
	]
	for view: Dictionary in views:
		camera.global_position = view["position"] as Vector3
		camera.look_at(view["target"] as Vector3, Vector3.UP)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var output_path := output_dir.path_join("%s.png" % str(view["name"]))
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Cannot save Route A stair visual check %s: %s" % [output_path, error_string(error)])
			get_tree().quit(1)
			return
	print("ROUTE_A_STAIR_VISUAL_OK views=%d output=%s" % [views.size(), ProjectSettings.globalize_path(output_dir)])
	get_tree().quit(0)
