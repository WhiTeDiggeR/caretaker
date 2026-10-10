extends SceneTree

const ASSEMBLY_SCENE := preload("res://scenes/complex_v3_blockout/review/u_emergency_plan_assembly.tscn")
const OUTPUT_DIR := "user://complex_v3_plan_assembly/u_emergency"


func _initialize() -> void:
	root.size = Vector2i(1280, 900)
	var assembly := ASSEMBLY_SCENE.instantiate()
	root.add_child(assembly)
	await process_frame
	await process_frame
	var camera := assembly.get_node("ReviewCamera") as Camera3D
	var target := Vector3(-39.0, 0.8, 2.0)
	var views := [
		{"name": "01_top", "orthogonal": true, "top": true, "position": Vector3(-39.0, 120.0, 2.0)},
		{"name": "02_angle", "orthogonal": true, "top": false, "position": target + Vector3(95.0, 82.0, 92.0)},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var errors := PackedStringArray()
	for view: Dictionary in views:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if bool(view["orthogonal"]) else Camera3D.PROJECTION_PERSPECTIVE
		camera.size = 105.0
		camera.global_position = view["position"] as Vector3
		camera.look_at(target, Vector3.FORWARD if bool(view.get("top", false)) else Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := OUTPUT_DIR.path_join("%s.png" % str(view["name"]))
		var result := root.get_texture().get_image().save_png(path)
		if result != OK:
			errors.append("Failed to save %s: %s" % [path, error_string(result)])
		else:
			print("U_EMERGENCY_PLAN_VIEW %s" % ProjectSettings.globalize_path(path))
	assembly.queue_free()
	await process_frame
	if errors.is_empty():
		print("U_EMERGENCY_PLAN_VISUAL_OK views=%d" % views.size())
	else:
		for error: String in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)
