extends SceneTree

const DEFAULT_OUTPUT := "res://gen/shared/Generated/Infrastructure/shared_infrastructure_generated.tscn"
const EXTERNAL_GEOMETRY_OWNERS := {
	"horizontal_routes": "sector_rollouts",
	"connectors": "sector_rollouts",
	"VT-ROUTE-A": "route_a_vertical_pilot",
}
const BLOCKED_VERTICALS := [
	"VT-MAIN-ELEVATOR",
	"VT-MAIN-STAIR",
	"VT-OLD-INCLINE",
	"VT-OLD-STAIR",
	"VT-SERVICE-STAIR",
	"VT-EAST-STAIR",
	"VT-FREIGHT-LIFT",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := DEFAULT_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var generated := Node3D.new()
	generated.name = "SharedInfrastructureGenerated"
	root.add_child(generated)
	generated.set_meta("content_owner", "complex_v3_shared_rollout")
	generated.set_meta("contract_version", "1.0.0")
	generated.set_meta("geometry_policy", "external_single_owner")
	generated.set_meta("external_geometry_owners", EXTERNAL_GEOMETRY_OWNERS)
	generated.set_meta("blocked_vertical_geometry", PackedStringArray(BLOCKED_VERTICALS))
	generated.set_meta("anchor_frames", "res://gen/shared/anchor_frames.json")
	var generated_contract := Node3D.new()
	generated_contract.name = "Generated"
	generated_contract.set_meta("contains_collision_geometry", false)
	generated.add_child(generated_contract)
	generated_contract.owner = generated
	var packed := PackedScene.new()
	var pack_error := packed.pack(generated)
	if pack_error != OK:
		push_error("Cannot pack shared infrastructure contract: %s" % error_string(pack_error))
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var save_error := ResourceSaver.save(packed, output)
	if save_error != OK:
		push_error("Cannot save shared infrastructure contract: %s" % error_string(save_error))
		quit(1)
		return
	print("SHARED_PACKAGE_OK path=%s geometry_owner=external" % output)
	generated.queue_free()
	await process_frame
	quit(0)
