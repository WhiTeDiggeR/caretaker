extends Node3D

const DEFAULT_OUTPUT_DIR := "user://main_core_stair_visual"

@onready var camera: Camera3D = $Camera3D
@onready var stair: MainCoreSwitchbackStair = $MainCoreSwitchbackStair


func _ready() -> void:
	var output_dir := DEFAULT_OUTPUT_DIR
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stair-output="):
			output_dir = argument.trim_prefix("--stair-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await get_tree().process_frame
	await get_tree().process_frame
	var views := [
		{"name": "01_upper_entrance", "position": Vector3(-1.8, 1.65, 8.5), "target": Vector3(-1.8, -1.4, -1.0)},
		{"name": "02_lower_entrance", "position": Vector3(1.8, -4.35, 8.5), "target": Vector3(1.8, -4.8, -0.8)},
		{"name": "03_intermediate_inside", "position": Vector3(0.0, -1.2, 0.6), "target": Vector3(0.0, -3.0, -4.15)},
		{"name": "04_top_oblique", "position": Vector3(-8.5, 13.5, 9.5), "target": Vector3(0.0, -2.4, -0.8)},
		{"name": "05_upper_guard", "position": Vector3(2.2, 1.65, 6.4), "target": Vector3(0.6, 0.35, 1.8)},
	]
	for view: Dictionary in views:
		camera.global_position = view["position"] as Vector3
		camera.look_at(view["target"] as Vector3, Vector3.UP)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var output_path := output_dir.path_join("%s.png" % str(view["name"]))
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Cannot save stair visual check %s: %s" % [output_path, error_string(error)])
			get_tree().quit(1)
			return
	print("MAIN_CORE_STAIR_VISUAL_OK views=%d output=%s" % [views.size(), ProjectSettings.globalize_path(output_dir)])
	get_tree().quit(0)
