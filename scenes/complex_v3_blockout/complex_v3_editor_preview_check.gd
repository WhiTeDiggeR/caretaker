@tool
extends Node

const CONTROL_SCENES := {
	"U-MEDBAY": "res://scenes/complex_v3_blockout/zones/upper/u_medbay.tscn",
	"L-OLD-CORE": "res://scenes/complex_v3_blockout/zones/lower/l_old_core.tscn",
	"T-UTILITIES": "res://scenes/complex_v3_blockout/zones/technical/t_utilities.tscn",
}
const EXPECTED_SPACES := {
	"U-MEDBAY": 5,
	"L-OLD-CORE": 4,
	"T-UTILITIES": 7,
}


func _ready() -> void:
	if not Engine.is_editor_hint():
		push_error("Editor preview check must run in the Godot editor")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	var errors := PackedStringArray()
	for sector_id: String in CONTROL_SCENES:
		var packed := load(str(CONTROL_SCENES[sector_id])) as PackedScene
		if packed == null:
			errors.append("Cannot load editor preview scene for %s" % sector_id)
			continue
		var part := packed.instantiate() as ComplexV3BlockoutPart
		part.editor_preview_enabled = true
		add_child(part)
		var generated := part.get_node_or_null("Generated") as Node3D
		if generated == null:
			errors.append("%s did not build Generated in editor" % sector_id)
		else:
			if generated.owner != null:
				errors.append("%s editor preview is serializable" % sector_id)
			if not generated.find_children("*", "StaticBody3D", true, false).is_empty():
				errors.append("%s editor preview contains physics bodies" % sector_id)
		if part.get_node_or_null("AuthoredContent") == null:
			errors.append("%s lost AuthoredContent" % sector_id)
		var stats := part.get_build_stats()
		if int(stats.get("spaces", 0)) != int(EXPECTED_SPACES[sector_id]):
			errors.append("%s preview expected %d spaces, built %d" % [sector_id, int(EXPECTED_SPACES[sector_id]), int(stats.get("spaces", 0))])
		part.free()
	if errors.is_empty():
		print("COMPLEX_V3_EDITOR_PREVIEW_OK zones=%d collisions=0 transient=true" % CONTROL_SCENES.size())
	else:
		for error: String in errors:
			push_error(error)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if errors.is_empty() else 1)
