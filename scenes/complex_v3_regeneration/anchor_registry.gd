@tool
extends Node
class_name ComplexV3AnchorRegistry

signal registry_changed(generation_id: String)

const SCHEMA_ID := "caretaker.anchor_frames"
const SUPPORTED_MAJOR := 1
const ALLOWED_TYPES := ["point", "wall", "door", "floor", "ceiling", "shaft", "stair_entry", "stair_exit"]
const LINEAR_TYPES := ["wall", "door", "stair_entry", "stair_exit"]
const EPS := 1.0e-6

@export_file("*.json") var anchor_frames_path := ""
@export var load_on_ready := true

var _anchors: Dictionary = {}
var _objects: Dictionary = {}
var _map_id := ""
var _sector_id := ""
var _generation_id := ""
var _last_errors := PackedStringArray()


func _ready() -> void:
	if load_on_ready and not anchor_frames_path.is_empty():
		load_anchor_frames(anchor_frames_path)


func load_anchor_frames(path: String = anchor_frames_path) -> PackedStringArray:
	var errors := PackedStringArray()
	if path.is_empty() or not FileAccess.file_exists(path):
		errors.append("anchor_frames file is missing: %s" % path)
		_last_errors = errors
		return errors
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open anchor_frames: %s" % path)
		_last_errors = errors
		return errors
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("anchor_frames root must be an object")
		_last_errors = errors
		return errors
	return load_anchor_document(parsed as Dictionary)


func load_anchor_document(document: Dictionary) -> PackedStringArray:
	var errors := _validate_document(document)
	if not errors.is_empty():
		_last_errors = errors
		return errors
	var staged: Dictionary = {}
	for frame_value: Variant in document["anchors"]:
		var frame := frame_value as Dictionary
		staged[str(frame["anchor_id"])] = frame.duplicate(true)
	_anchors = staged
	_map_id = str(document["map_id"])
	_sector_id = str(document["sector_id"])
	_generation_id = str(document["generation_id"])
	_last_errors = PackedStringArray()
	registry_changed.emit(_generation_id)
	return PackedStringArray()


func _validate_document(document: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(document.get("schema_id", "")) != SCHEMA_ID:
		errors.append("unsupported anchor schema_id")
	var version := str(document.get("schema_version", ""))
	var major_text := version.split(".")[0] if not version.is_empty() else ""
	if not major_text.is_valid_int() or int(major_text) != SUPPORTED_MAJOR:
		errors.append("unsupported anchor schema major: %s" % version)
	for key: String in ["map_id", "sector_id", "generation_id"]:
		if str(document.get(key, "")).is_empty():
			errors.append("anchor document is missing %s" % key)
	var coordinate := document.get("coordinate_space", {}) as Dictionary
	if str(coordinate.get("units", "")) != "m" or str(coordinate.get("horizontal_plane", "")) != "XZ" or str(coordinate.get("up_axis", "")) != "+Y" or str(coordinate.get("space", "")) != "world":
		errors.append("anchor document coordinate_space must be world metres with XZ/+Y")
	var anchors_value: Variant = document.get("anchors", null)
	if not anchors_value is Array:
		errors.append("anchor document anchors must be an array")
		return errors
	var ids: Dictionary = {}
	for frame_value: Variant in anchors_value:
		if not frame_value is Dictionary:
			errors.append("anchor frame must be an object")
			continue
		var frame := frame_value as Dictionary
		var anchor_id := str(frame.get("anchor_id", ""))
		if anchor_id.is_empty():
			errors.append("anchor frame has no anchor_id")
		elif ids.has(anchor_id):
			errors.append("duplicate anchor_id: %s" % anchor_id)
		else:
			ids[anchor_id] = true
		_validate_frame(frame, anchor_id, errors)
	return errors


func _validate_frame(frame: Dictionary, anchor_id: String, errors: PackedStringArray) -> void:
	var anchor_type := str(frame.get("type", ""))
	if anchor_type not in ALLOWED_TYPES:
		errors.append("%s has unsupported anchor type: %s" % [anchor_id, anchor_type])
	if str(frame.get("status", "")) != "active":
		errors.append("%s is not active" % anchor_id)
	var vectors: Dictionary = {}
	for key: String in ["origin", "forward", "normal", "up"]:
		var result: Variant = _read_vector3(frame.get(key), "%s.%s" % [anchor_id, key], errors)
		if result != null:
			vectors[key] = result
	if vectors.size() != 4:
		return
	var forward := vectors["forward"] as Vector3
	var normal := vectors["normal"] as Vector3
	var up := vectors["up"] as Vector3
	if absf(forward.length() - 1.0) > EPS or absf(normal.length() - 1.0) > EPS or absf(up.length() - 1.0) > EPS:
		errors.append("%s basis vectors must be normalized" % anchor_id)
	if absf(forward.dot(up)) > EPS or absf(normal.dot(forward)) > EPS:
		errors.append("%s basis vectors are not orthogonal" % anchor_id)
	if anchor_type in LINEAR_TYPES and not forward.cross(up).is_equal_approx(normal):
		errors.append("%s linear basis must satisfy forward cross up = normal" % anchor_id)
	if not frame.get("bounds") is Dictionary or not frame.get("placement_limits") is Dictionary:
		errors.append("%s must declare bounds and placement_limits" % anchor_id)


func _read_vector3(value: Variant, label: String, errors: PackedStringArray) -> Variant:
	if not value is Array or (value as Array).size() != 3:
		errors.append("%s must contain three numbers" % label)
		return null
	var values := value as Array
	for item: Variant in values:
		if not item is float and not item is int:
			errors.append("%s must contain only numbers" % label)
			return null
	var result := Vector3(float(values[0]), float(values[1]), float(values[2]))
	if not result.is_finite():
		errors.append("%s must be finite" % label)
		return null
	return result


func resolve_transform(anchor_id: String, expected_type: String, placement: ComplexV3AnchorPlacement, author_correction := Transform3D.IDENTITY) -> Dictionary:
	if not _anchors.has(anchor_id):
		return {"ok": false, "errors": PackedStringArray(["missing anchor_id: %s" % anchor_id])}
	var frame := _anchors[anchor_id] as Dictionary
	var anchor_type := str(frame["type"])
	if anchor_type != expected_type:
		return {"ok": false, "errors": PackedStringArray(["anchor %s has type %s, expected %s" % [anchor_id, anchor_type, expected_type]])}
	if placement == null:
		return {"ok": false, "errors": PackedStringArray(["placement resource is missing"])}
	if anchor_type not in LINEAR_TYPES:
		return {"ok": false, "errors": PackedStringArray(["anchor type %s has no linear placement in contract v1" % anchor_type])}
	var bounds := frame["bounds"] as Dictionary
	var length_m := float(bounds.get("length_m", -1.0))
	if length_m < 0.0:
		return {"ok": false, "errors": PackedStringArray(["anchor %s has no valid length_m" % anchor_id])}
	var along := placement.along_distance(length_m)
	if not bool(along.get("ok", false)):
		return {"ok": false, "errors": PackedStringArray([str(along.get("error", "invalid placement"))])}
	var distance := float(along["distance_m"])
	var errors := PackedStringArray()
	if distance < -EPS or distance > length_m + EPS:
		errors.append("placement is outside anchor length")
	var limits := frame["placement_limits"] as Dictionary
	_validate_scalar_limit(placement.normal_offset_m, limits.get("normal_offset_m"), "normal_offset_m", errors)
	_validate_scalar_limit(placement.height_m, limits.get("height_m"), "height_m", errors)
	_validate_rotation_limits(placement.yaw_pitch_roll_deg, limits.get("rotation_deg"), errors)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var origin := _vector_from_frame(frame, "origin")
	var forward := _vector_from_frame(frame, "forward")
	var normal := _vector_from_frame(frame, "normal")
	var up := _vector_from_frame(frame, "up")
	var anchor_basis := Basis(forward, up, normal)
	var position := origin + forward * distance + normal * placement.normal_offset_m + up * placement.height_m
	var resolved := Transform3D(anchor_basis * placement.rotation_basis(), position) * author_correction
	return {"ok": true, "transform": resolved, "anchor_id": anchor_id, "generation_id": _generation_id}


func _validate_scalar_limit(value: float, raw_limit: Variant, label: String, errors: PackedStringArray) -> void:
	if not raw_limit is Array or (raw_limit as Array).size() != 2:
		errors.append("placement_limits.%s is missing" % label)
		return
	var limit := raw_limit as Array
	if value < float(limit[0]) - EPS or value > float(limit[1]) + EPS:
		errors.append("%s is outside placement limits" % label)


func _validate_rotation_limits(value: Vector3, raw_limits: Variant, errors: PackedStringArray) -> void:
	if not raw_limits is Dictionary:
		errors.append("placement_limits.rotation_deg is missing")
		return
	var limits := raw_limits as Dictionary
	for item: Dictionary in [
		{"name": "yaw", "value": value.x},
		{"name": "pitch", "value": value.y},
		{"name": "roll", "value": value.z},
	]:
		var raw: Variant = limits.get(item["name"])
		if not raw is Array or (raw as Array).size() != 2:
			errors.append("rotation limit %s is missing" % item["name"])
		elif float(item["value"]) < float(raw[0]) - EPS or float(item["value"]) > float(raw[1]) + EPS:
			errors.append("rotation %s is outside placement limits" % item["name"])


func _vector_from_frame(frame: Dictionary, key: String) -> Vector3:
	var value := frame[key] as Array
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func register_object(object: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var object_id := str(object.get("object_id"))
	if object_id.is_empty():
		errors.append("anchored object has no object_id")
		return errors
	if _objects.has(object_id):
		var existing := (_objects[object_id] as WeakRef).get_ref() as Node
		if existing != null and existing != object:
			errors.append("duplicate object_id: %s" % object_id)
			return errors
	_objects[object_id] = weakref(object)
	return errors


func unregister_object(object: Node) -> void:
	var object_id := str(object.get("object_id"))
	if _objects.has(object_id) and (_objects[object_id] as WeakRef).get_ref() == object:
		_objects.erase(object_id)


func refresh_registered_objects() -> PackedStringArray:
	var errors := PackedStringArray()
	for object_id: String in _objects.keys():
		var object := (_objects[object_id] as WeakRef).get_ref() as Node
		if object == null:
			_objects.erase(object_id)
			continue
		var object_errors: PackedStringArray = object.call("apply_anchor_transform")
		for error: String in object_errors:
			errors.append("%s: %s" % [object_id, error])
	return errors


func get_anchor_frame(anchor_id: String) -> Dictionary:
	if not _anchors.has(anchor_id):
		return {}
	return (_anchors[anchor_id] as Dictionary).duplicate(true)


func find_compatible_candidates(expected_type: String, world_position: Vector3, tolerance_m: float) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if expected_type not in LINEAR_TYPES or tolerance_m < 0.0:
		return candidates
	for anchor_id: String in _anchors.keys():
		var frame := _anchors[anchor_id] as Dictionary
		if str(frame.get("type", "")) != expected_type:
			continue
		var origin := _vector_from_frame(frame, "origin")
		var forward := _vector_from_frame(frame, "forward")
		var up := _vector_from_frame(frame, "up")
		var bounds := frame.get("bounds", {}) as Dictionary
		var length_m := float(bounds.get("length_m", bounds.get("width_m", bounds.get("clear_width_m", -1.0))))
		if length_m < 0.0:
			continue
		var along_m := clampf((world_position - origin).dot(forward), 0.0, length_m)
		var height_extent_m := maxf(float(bounds.get("height_m", 0.0)), 0.0)
		var height_m := clampf((world_position - origin).dot(up), 0.0, height_extent_m)
		var closest := origin + forward * along_m + up * height_m
		var distance_m := world_position.distance_to(closest)
		if distance_m <= tolerance_m + EPS:
			candidates.append({
				"anchor_id": anchor_id,
				"type": expected_type,
				"distance_m": distance_m,
				"along_m": along_m,
				"height_m": height_m,
				"closest_point": closest,
			})
	candidates.sort_custom(_candidate_less)
	return candidates


func _candidate_less(left: Dictionary, right: Dictionary) -> bool:
	var distance_delta := float(left["distance_m"]) - float(right["distance_m"])
	if absf(distance_delta) > EPS:
		return distance_delta < 0.0
	return str(left["anchor_id"]) < str(right["anchor_id"])


func can_register_object_id(object_id: String, object: Node) -> bool:
	if object_id.is_empty() or not _objects.has(object_id):
		return not object_id.is_empty()
	var existing := (_objects[object_id] as WeakRef).get_ref() as Node
	return existing == null or existing == object


func get_last_errors() -> PackedStringArray:
	return _last_errors.duplicate()


func get_generation_id() -> String:
	return _generation_id
