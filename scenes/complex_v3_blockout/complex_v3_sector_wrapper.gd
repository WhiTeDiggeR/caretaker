@tool
extends Node3D
class_name ComplexV3SectorWrapper

const CONTRACT_VERSION := "1.0.0"
const GENERATED_NAME := "Generated"
const AUTHORED_NAME := "AuthoredContent"
const PREVIEW_NAME := "EditorPreview"

@export_group("Regeneration contract")
@export var generated_architecture_scene: PackedScene
@export var generated_stairs_scene: PackedScene
@export var authored_content_scene: PackedScene
@export var assemble_contract_on_ready := false
@export var contract_editor_preview_enabled := false


func _ready() -> void:
	if not assemble_contract_on_ready:
		return
	if Engine.is_editor_hint():
		if contract_editor_preview_enabled:
			rebuild_contract_editor_preview()
		return
	var errors := rebuild_contract_generated()
	for error: String in errors:
		push_error(error)


func rebuild_contract_generated() -> PackedStringArray:
	var errors := _validate_configured_resources()
	if not errors.is_empty():
		return errors
	var authored := get_node_or_null(AUTHORED_NAME) as Node3D
	if authored == null:
		authored = authored_content_scene.instantiate() as Node3D
		if authored == null:
			errors.append("Authored content resource root must be Node3D")
			return errors
		authored.name = AUTHORED_NAME
		authored.set_meta("content_owner", "author")
		add_child(authored)
	var staging := Node3D.new()
	staging.name = "GeneratedStaging"
	staging.set_meta("content_owner", "regenerator")
	staging.set_meta("contract_version", CONTRACT_VERSION)
	add_child(staging)
	if not _instantiate_generated_layer(generated_architecture_scene, "Architecture", staging):
		errors.append("Generated architecture resource root must be Node3D")
	if generated_stairs_scene != null and not _instantiate_generated_layer(generated_stairs_scene, "Stairs", staging):
		errors.append("Generated stairs resource root must be Node3D")
	if not errors.is_empty():
		staging.free()
		return errors
	var previous := get_node_or_null(GENERATED_NAME)
	if previous != null:
		previous.free()
	staging.name = GENERATED_NAME
	return validate_regeneration_contract(true)


func rebuild_contract_editor_preview() -> PackedStringArray:
	var errors := _validate_configured_resources()
	if not errors.is_empty():
		return errors
	var previous := get_node_or_null(PREVIEW_NAME)
	if previous != null:
		previous.free()
	var preview := Node3D.new()
	preview.name = PREVIEW_NAME
	preview.set_meta("content_owner", "transient_preview")
	add_child(preview)
	if not _instantiate_generated_layer(generated_architecture_scene, "Architecture", preview):
		errors.append("Preview architecture resource root must be Node3D")
	if generated_stairs_scene != null and not _instantiate_generated_layer(generated_stairs_scene, "Stairs", preview):
		errors.append("Preview stairs resource root must be Node3D")
	_strip_preview_physics(preview)
	if preview.owner != null:
		errors.append("EditorPreview must remain transient and have no scene owner")
	if _contains_physics(preview):
		errors.append("EditorPreview contains collision or physics nodes")
	var authored := get_node_or_null(AUTHORED_NAME)
	if authored != null and authored.find_child(PREVIEW_NAME, true, false) != null:
		errors.append("EditorPreview must never be stored below AuthoredContent")
	return errors


func clear_contract_editor_preview() -> void:
	var preview := get_node_or_null(PREVIEW_NAME)
	if preview != null:
		preview.free()


func validate_regeneration_contract(require_external_authored := false) -> PackedStringArray:
	var errors := PackedStringArray()
	var generated_nodes := find_children(GENERATED_NAME, "", false, false)
	var authored_nodes := find_children(AUTHORED_NAME, "", false, false)
	if generated_nodes.size() != 1:
		errors.append("SectorRoot must contain exactly one direct Generated node")
	if authored_nodes.size() != 1:
		errors.append("SectorRoot must contain exactly one direct AuthoredContent node")
	if generated_nodes.size() == 1:
		var generated := generated_nodes[0]
		if str(generated.get_meta("content_owner", "")) != "regenerator":
			errors.append("Generated must declare regenerator ownership")
		if generated.find_child(AUTHORED_NAME, true, false) != null:
			errors.append("AuthoredContent must not be nested below Generated")
		if generated.find_child(PREVIEW_NAME, true, false) != null:
			errors.append("EditorPreview must not be stored below Generated")
		var architecture := generated.get_node_or_null("Architecture")
		if architecture == null or str(architecture.get_meta("content_owner", "")) != "regenerator":
			errors.append("Generated must contain regenerator-owned Architecture")
		var stairs := generated.get_node_or_null("Stairs")
		if generated_stairs_scene != null and (stairs == null or str(stairs.get_meta("content_owner", "")) != "regenerator"):
			errors.append("Configured generated stairs must remain regenerator-owned")
	if authored_nodes.size() == 1:
		var authored := authored_nodes[0]
		if str(authored.get_meta("content_owner", "")) != "author":
			errors.append("AuthoredContent must declare author ownership")
		if require_external_authored and authored.scene_file_path.is_empty():
			errors.append("AuthoredContent must be the root of a separate PackedScene resource")
		if authored.find_child(GENERATED_NAME, true, false) != null:
			errors.append("Generated must not be nested below AuthoredContent")
		if authored.find_child(PREVIEW_NAME, true, false) != null:
			errors.append("EditorPreview must not be stored below AuthoredContent")
	return errors


func _validate_configured_resources() -> PackedStringArray:
	var errors := PackedStringArray()
	if generated_architecture_scene == null:
		errors.append("generated_architecture_scene is required")
	if authored_content_scene == null and get_node_or_null(AUTHORED_NAME) == null:
		errors.append("authored_content_scene is required when AuthoredContent is absent")
	return errors


func _instantiate_generated_layer(scene: PackedScene, layer_name: String, parent: Node3D) -> bool:
	if scene == null:
		return false
	var layer := scene.instantiate() as Node3D
	if layer == null:
		return false
	layer.name = layer_name
	layer.set_meta("content_owner", "regenerator")
	parent.add_child(layer)
	return true


func _strip_preview_physics(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			child.free()
		else:
			_strip_preview_physics(child)


func _contains_physics(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child: Node in node.get_children():
		if _contains_physics(child):
			return true
	return false
