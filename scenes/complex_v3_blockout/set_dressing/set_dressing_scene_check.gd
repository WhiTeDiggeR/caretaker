extends SceneTree

const MANIFEST_PATH := "res://scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"
const BASELINE_REF := "1157dd8"
const OUTPUT_DIR := "res://scenes/complex_v3_blockout/set_dressing/migration"
const TOLERANCE := 0.00001

var _errors := PackedStringArray()
var _node_count := 0
var _max_delta := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var document := _load_json(MANIFEST_PATH)
	var object_ids := {}
	var object_count := 0
	var world := Node3D.new()
	root.add_child(world)
	for sector_value: Variant in document.get("sectors", []):
		var sector := sector_value as Dictionary
		var resource := load(str(sector.get("dressing_scene", ""))) as PackedScene
		var reference := _baseline_scene(sector)
		if resource == null or reference == null:
			_errors.append("cannot load dressing scene or baseline for %s" % str(sector.get("sector_id", "")))
			continue
		var instance := resource.instantiate()
		var legacy := reference.instantiate()
		world.add_child(instance)
		world.add_child(legacy)
		var old_by_id := {}
		for old_child: Node in legacy.get_children():
			var placement_id := str(old_child.get_meta("placement_id", ""))
			if placement_id.is_empty() or old_by_id.has(placement_id):
				_errors.append("duplicate/missing legacy placement_id")
			old_by_id[placement_id] = old_child
		for child: Node in instance.get_children():
			if not child is AnchoredObject3D:
				_errors.append("%s has non-authored wrapper child %s" % [sector.get("sector_id", ""), child.name])
				continue
			var anchored := child as AnchoredObject3D
			object_count += 1
			if anchored.object_id.is_empty() or object_ids.has(anchored.object_id):
				_errors.append("empty or duplicate object_id: %s" % anchored.object_id)
			object_ids[anchored.object_id] = true
			if not anchored.has_meta("placement_id"):
				_errors.append("%s has no legacy placement_id" % anchored.object_id)
			if not anchored.has_node("Content"):
				_errors.append("%s has no Content child" % anchored.object_id)
			if anchored.apply_on_ready:
				_errors.append("%s must not resolve before a sector registry is supplied" % anchored.object_id)
			var placement_id := str(anchored.get_meta("placement_id", ""))
			if old_by_id.has(placement_id) and anchored.has_node("Content"):
				_compare_subtree(old_by_id[placement_id] as Node, anchored.get_node("Content"), placement_id)
				old_by_id.erase(placement_id)
			else:
				_errors.append("missing legacy object: %s" % placement_id)
		if not old_by_id.is_empty():
			_errors.append("legacy objects disappeared")
		instance.queue_free()
		legacy.queue_free()
		await process_frame
	if object_count != 356:
		_errors.append("object count %d, expected 356" % object_count)
	world.queue_free()
	await process_frame
	if _errors.is_empty() and OS.get_cmdline_user_args().has("--visual"):
		await _render_views(document)
	var report := FileAccess.open(OUTPUT_DIR.path_join("godot_transform_audit.json"), FileAccess.WRITE)
	if report == null:
		_errors.append("cannot write Godot audit report")
	else:
		report.store_string(JSON.stringify({"schema_version": "1.0.0", "baseline_git_ref": BASELINE_REF, "object_count": object_count, "node3d_count": _node_count, "max_matrix_delta": _max_delta, "tolerance": TOLERANCE, "status": "passed" if _errors.is_empty() else "failed", "errors": Array(_errors)}, "  ") + "\n")
		report.close()
	if _errors.is_empty():
		print("SET_DRESSING_GODOT_SCENES_OK sectors=%d objects=%d" % [document.get("sector_count", 0), object_count])
		print("SET_DRESSING_WORLD_TRANSFORMS_OK nodes=%d max_delta=%s" % [_node_count, _max_delta])
	else:
		for error: String in _errors:
			push_error(error)
	quit(0 if _errors.is_empty() else 1)


func _baseline_scene(sector: Dictionary) -> PackedScene:
	var output: Array = []
	var resource_path := str(sector["dressing_scene"]).trim_prefix("res://")
	var result := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "show", BASELINE_REF + ":" + resource_path]), output, true)
	if result != 0 or output.is_empty():
		_errors.append("cannot read committed baseline: %s" % resource_path)
		return null
	var temporary := "user://issue49_baseline_%s.tscn" % str(sector["sector_id"]).replace("-", "_")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(str(output[0]))
	file.close()
	var scene := ResourceLoader.load(temporary, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return scene


func _compare_subtree(before: Node, after: Node, label: String) -> void:
	if before.get_class() != after.get_class():
		_errors.append("node class changed: %s" % label)
	if before is Node3D and after is Node3D:
		_node_count += 1
		var left := (before as Node3D).global_transform
		var right := (after as Node3D).global_transform
		for index: int in range(4):
			var a: Vector3 = left.origin if index == 3 else left.basis[index]
			var b: Vector3 = right.origin if index == 3 else right.basis[index]
			var delta := (a - b).abs()
			_max_delta = maxf(_max_delta, maxf(delta.x, maxf(delta.y, delta.z)))
		if _max_delta > TOLERANCE:
			_errors.append("world transform changed: %s" % label)
	if before.get_child_count() != after.get_child_count():
		_errors.append("descendant count changed: %s" % label)
	for child: Node in before.get_children():
		var counterpart := after.get_node_or_null(NodePath(child.name))
		if counterpart == null:
			_errors.append("missing descendant: %s/%s" % [label, child.name])
		else:
			_compare_subtree(child, counterpart, label + "/" + str(child.name))


func _render_views(document: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		_errors.append("visual mode requires a rendering display driver, not --headless")
		return
	root.size = Vector2i(1280, 900)
	var handoff := _load_json("res://docs/design/complex_v3/handoff/geometry/complex-handoff.json")
	for value: Variant in document["sectors"]:
		var sector := value as Dictionary
		var sector_id := str(sector["sector_id"])
		if sector_id not in ["U-MEDBAY", "T-UTILITIES", "L-OLD-CORE"]:
			continue
		var world := Node3D.new()
		root.add_child(world)
		var environment_node := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.035, 0.045, 0.06)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.WHITE
		environment.ambient_light_energy = 0.8
		environment_node.environment = environment
		world.add_child(environment_node)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-60, -25, 0)
		light.light_energy = 1.0
		world.add_child(light)
		var zone := (load(str(sector["zone_scene"])) as PackedScene).instantiate() as ComplexV3BlockoutPart
		zone.include_ceilings = false
		zone.build_collisions = false
		zone.show_space_labels = false
		world.add_child(zone)
		var bounds: Array = []
		for sector_data: Dictionary in handoff["sectors"]:
			if str(sector_data["id"]) == sector_id:
				bounds = sector_data["bounds_xz"]
		var floor_y := float((sector["placements"] as Array)[0]["position"][1])
		var center := Vector3((float(bounds[0]) + float(bounds[2])) * 0.5, floor_y, (float(bounds[1]) + float(bounds[3])) * 0.5)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1])) * 1.3
		camera.far = 500.0
		world.add_child(camera)
		camera.global_position = center + Vector3(0, 100, 30)
		camera.look_at(center)
		camera.make_current()
		var holder := zone.get_node("AuthoredContent")
		for phase: String in ["after", "before"]:
			if phase == "before":
				holder.get_node("SetDressing").free()
				var baseline := _baseline_scene(sector).instantiate()
				baseline.name = "SetDressing"
				holder.add_child(baseline)
			for _frame: int in range(8):
				await process_frame
			await create_timer(0.5).timeout
			# A hidden window may throttle redraw; explicitly finish a rendered frame.
			RenderingServer.force_draw()
			var path := OUTPUT_DIR.path_join("visuals/%s_%s.png" % [sector_id.to_lower().replace("-", "_"), phase])
			if root.get_texture().get_image().save_png(path) != OK:
				_errors.append("cannot write visual: %s" % path)
			else:
				print("SET_DRESSING_VIEW %s" % path)
		world.queue_free()
		await process_frame


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
