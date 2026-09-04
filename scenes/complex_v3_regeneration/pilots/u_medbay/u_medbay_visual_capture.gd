extends SceneTree

const PILOT_SCENE := "res://scenes/complex_v3_regeneration/pilots/u_medbay/pilot_scene.tscn"
const ANCHORS_PATH := "res://scenes/complex_v3_regeneration/pilots/u_medbay/live/anchor_frames.json"
const OUTPUT_DIR := "res://scenes/complex_v3_regeneration/pilots/u_medbay/reports/visuals"


func _initialize() -> void:
	var packed := load(PILOT_SCENE) as PackedScene
	if packed == null:
		push_error("cannot load pilot scene")
		quit(1)
		return
	var pilot := packed.instantiate()
	root.add_child(pilot)
	var ceiling_visual := pilot.get_node_or_null("Generated/Ceilings/Visual") as Node3D
	if ceiling_visual != null:
		ceiling_visual.visible = false
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not await _capture("baseline.png"):
		quit(1)
		return
	var document := _read_json(ANCHORS_PATH)
	_shift_anchor(document, "svg:u-medbay-wall-west-corridor:wall", Vector3(0.2, 0, 0))
	_shift_anchor(document, "svg:u-medbay-door-external-east:door:threshold_inside", Vector3(0, 0, 0.3))
	_shift_anchor(document, "svg:u-medbay-floor-procedure-room:floor", Vector3(0.5, 0, 0))
	document["generation_id"] = "visual-after"
	var registry := pilot.get_node("AnchorRegistry") as ComplexV3AnchorRegistry
	var errors := registry.load_anchor_document(document)
	errors.append_array(registry.refresh_registered_objects())
	if not errors.is_empty():
		push_error("cannot resolve visual after state: %s" % errors)
		quit(1)
		return
	await process_frame
	await process_frame
	if not await _capture("anchors-moved.png"):
		quit(1)
		return
	print("U_MEDBAY_VISUALS_OK baseline.png anchors-moved.png")
	quit(0)


func _capture(file_name: String) -> bool:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("cannot save %s: %s" % [file_name, error_string(error)])
		return false
	return true


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _shift_anchor(document: Dictionary, anchor_id: String, delta: Vector3) -> void:
	for frame_value: Variant in document.get("anchors", []):
		var frame := frame_value as Dictionary
		if str(frame.get("anchor_id", "")) == anchor_id:
			var origin := frame["origin"] as Array
			frame["origin"] = [float(origin[0]) + delta.x, float(origin[1]) + delta.y, float(origin[2]) + delta.z]
			var bounds := frame["bounds"] as Dictionary
			for point: Array in bounds.get("polygon_xz", []):
				point[0] = float(point[0]) + delta.x
				point[1] = float(point[1]) + delta.z
			return
