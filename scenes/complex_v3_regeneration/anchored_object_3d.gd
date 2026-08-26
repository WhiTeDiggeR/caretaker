@tool
extends Node3D
class_name AnchoredObject3D

signal anchor_resolution_changed(valid: bool, errors: PackedStringArray)

@export var object_id := ""
@export var anchor_id := ""
@export_enum("point", "wall", "door", "floor", "ceiling", "shaft", "stair_entry", "stair_exit") var expected_anchor_type := "wall"
@export var placement: ComplexV3AnchorPlacement
@export var author_correction := Transform3D.IDENTITY
@export var anchor_registry: ComplexV3AnchorRegistry
@export var apply_on_ready := true

var _last_errors := PackedStringArray()


func _ready() -> void:
	if anchor_registry == null:
		_last_errors = PackedStringArray(["anchor registry is missing"])
		anchor_resolution_changed.emit(false, _last_errors)
		return
	var registration_errors := anchor_registry.register_object(self)
	if not registration_errors.is_empty():
		_last_errors = registration_errors
		anchor_resolution_changed.emit(false, _last_errors)
		return
	if apply_on_ready:
		apply_anchor_transform()


func _exit_tree() -> void:
	if anchor_registry != null:
		anchor_registry.unregister_object(self)


func apply_anchor_transform() -> PackedStringArray:
	if anchor_registry == null:
		_last_errors = PackedStringArray(["anchor registry is missing"])
		anchor_resolution_changed.emit(false, _last_errors)
		return _last_errors.duplicate()
	var resolved := anchor_registry.resolve_transform(anchor_id, expected_anchor_type, placement, author_correction)
	if not bool(resolved.get("ok", false)):
		_last_errors = resolved.get("errors", PackedStringArray(["anchor resolution failed"])) as PackedStringArray
		anchor_resolution_changed.emit(false, _last_errors)
		return _last_errors.duplicate()
	global_transform = resolved["transform"] as Transform3D
	_last_errors = PackedStringArray()
	anchor_resolution_changed.emit(true, _last_errors)
	return PackedStringArray()


func get_anchor_errors() -> PackedStringArray:
	return _last_errors.duplicate()
