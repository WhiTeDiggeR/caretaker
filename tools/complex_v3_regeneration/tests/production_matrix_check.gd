extends SceneTree

const MANIFEST := "res://tools/complex_v3_regeneration/sector_generation_manifest.json"
const ASSEMBLY := "res://scenes/complex_v3_blockout/complex_v3_blockout.tscn"

var _errors := PackedStringArray()
var _generated_loaded := 0
var _sectors_loaded := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest := _read_json(MANIFEST)
	var sectors_value: Variant = manifest.get("sectors", [])
	if not sectors_value is Array or (sectors_value as Array).size() != 30:
		_errors.append("production manifest does not contain 30 sectors")
		_finish()
		return
	for value: Variant in sectors_value:
		if not value is Dictionary:
			_errors.append("manifest sector entry is not an object")
			continue
		var sector := value as Dictionary
		var sector_id := str(sector.get("sector_id", ""))
		var output := str(sector.get("output_resource_dir", "")).trim_suffix("/")
		var architecture_path := "%s/Generated/Architecture/%s.tscn" % [output, str(sector.get("scene_name", ""))]
		var architecture := _instantiate(architecture_path, "%s generated" % sector_id)
		if architecture != null:
			_generated_loaded += 1
			architecture.free()
		var sector_root := _instantiate(str(sector.get("sector_scene", "")), "%s sector" % sector_id)
		if sector_root == null:
			continue
		root.add_child(sector_root)
		await process_frame
		_sectors_loaded += 1
		if str(sector_root.get_meta("complex_v3_sector_id", "")) != sector_id:
			_errors.append("%s root metadata mismatch" % sector_id)
		for path: String in ["Generated", "Generated/Architecture", "Generated/Stairs", "AuthoredContent", "AnchorRegistry", "AnchorController"]:
			if sector_root.get_node_or_null(path) == null:
				_errors.append("%s missing %s" % [sector_id, path])
		var generated := sector_root.get_node_or_null("Generated")
		if generated != null:
			if _direct_child_count(generated, "Architecture") != 1:
				_errors.append("%s has duplicate/missing generated Architecture" % sector_id)
			if _direct_child_count(generated, "Stairs") != 1:
				_errors.append("%s has duplicate/missing generated Stairs" % sector_id)
		sector_root.queue_free()
		await process_frame

	var assembly := _instantiate(ASSEMBLY, "30-sector assembly")
	if assembly != null:
		root.add_child(assembly)
		await process_frame
		await process_frame
		if not assembly.has_method("get_sector_ids"):
			_errors.append("assembly has no get_sector_ids()")
		else:
			var ids := assembly.call("get_sector_ids") as PackedStringArray
			if ids.size() != 30:
				_errors.append("assembly loaded %d sector IDs instead of 30" % ids.size())
			var unique := {}
			for sector_id: String in ids:
				unique[sector_id] = true
			if unique.size() != 30:
				_errors.append("assembly contains duplicate sector IDs")
		if assembly.has_method("validate_against_handoff"):
			_errors.append_array(assembly.call("validate_against_handoff") as PackedStringArray)
		assembly.queue_free()
	_finish()


func _instantiate(path: String, label: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		_errors.append("cannot load %s: %s" % [label, path])
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		_errors.append("%s root is not Node3D: %s" % [label, path])
	return instance


func _direct_child_count(parent: Node, child_name: String) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child.name == child_name:
			count += 1
	return count


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("cannot read %s" % path)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		_errors.append("JSON root is not an object: %s" % path)
		return {}
	return value as Dictionary


func _finish() -> void:
	print("PRODUCTION_MATRIX generated=%d sectors=%d errors=%d" % [_generated_loaded, _sectors_loaded, _errors.size()])
	for error: String in _errors:
		push_error(error)
	quit(0 if _errors.is_empty() else 1)
