@tool
extends Node

const CONTROL_SCENES := {
	"U-CENTRAL-CORE": "res://scenes/complex_v3_blockout/zones/upper/u_central_core.tscn",
	"L-CENTRAL-CORE": "res://scenes/complex_v3_blockout/zones/lower/l_central_core.tscn",
	"U-MEDBAY": "res://scenes/complex_v3_blockout/zones/upper/u_medbay.tscn",
	"L-OLD-CORE": "res://scenes/complex_v3_blockout/zones/lower/l_old_core.tscn",
	"T-UTILITIES": "res://scenes/complex_v3_blockout/zones/technical/t_utilities.tscn",
}
const EXPECTED_SPACES := {
	"U-CENTRAL-CORE": 6,
	"L-CENTRAL-CORE": 6,
	"U-MEDBAY": 7,
	"L-OLD-CORE": 4,
	"T-UTILITIES": 7,
}
const EXPECTED_CEILINGS := {
	"U-CENTRAL-CORE": 4,
	"L-CENTRAL-CORE": 4,
	"U-MEDBAY": 7,
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
		if sector_id == "U-CENTRAL-CORE" and generated != null:
			generated.free()
			await get_tree().process_frame
			await get_tree().process_frame
			generated = part.get_node_or_null("Generated") as Node3D
			if generated == null:
				errors.append("%s did not restore Generated after tool-script preview loss" % sector_id)
			elif part.get_node_or_null("AuthoredContent") == null:
				errors.append("%s self-heal removed AuthoredContent" % sector_id)
		var stats := part.get_build_stats()
		if int(stats.get("spaces", 0)) != int(EXPECTED_SPACES[sector_id]):
			errors.append("%s preview expected %d spaces, built %d" % [sector_id, int(EXPECTED_SPACES[sector_id]), int(stats.get("spaces", 0))])
		if sector_id in ["U-CENTRAL-CORE", "L-CENTRAL-CORE"]:
			if not part.find_children("WestFlight_00", "", true, false).is_empty():
				errors.append("%s preview must not embed the separate stair scene" % sector_id)
			if part.find_children("CabinFloor", "", true, false).is_empty():
				errors.append("%s preview has no passenger elevator cabin" % sector_id)
			if part.find_children("StairOpening*Slab", "", true, false).size() != 4:
				errors.append("%s preview must contain four floor panels around the stair opening" % sector_id)
			if not part.find_children("Datum", "", true, false).is_empty() or not part.find_children("ShaftEnvelope", "", true, false).is_empty():
				errors.append("%s preview exposes vertical debug geometry" % sector_id)
		if int(stats.get("ceilings", 0)) != 0 or not part.find_children("Ceiling", "", true, false).is_empty():
			errors.append("%s editor preview shows ceilings by default" % sector_id)
		part.editor_preview_show_ceilings = true
		part.build_from_handoff()
		stats = part.get_build_stats()
		if int(stats.get("ceilings", 0)) != int(EXPECTED_CEILINGS[sector_id]):
			errors.append("%s ceiling toggle expected %d ceilings, built %d" % [sector_id, int(EXPECTED_CEILINGS[sector_id]), int(stats.get("ceilings", 0))])
		if part.find_children("Ceiling", "", true, false).is_empty():
			errors.append("%s ceiling toggle did not show ceiling nodes" % sector_id)
		part.editor_preview_show_ceilings = false
		part.build_from_handoff()
		if int(part.get_build_stats().get("ceilings", 0)) != 0:
			errors.append("%s ceiling toggle did not hide ceilings again" % sector_id)
		part.free()
	if errors.is_empty():
		print("COMPLEX_V3_EDITOR_PREVIEW_OK zones=%d collisions=0 transient=true ceilings=toggle self_heal=true" % CONTROL_SCENES.size())
	else:
		for error: String in errors:
			push_error(error)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if errors.is_empty() else 1)
