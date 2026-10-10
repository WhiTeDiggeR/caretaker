extends SceneTree
## Loads every prop in res://loads/props and checks it the way the game will use it:
## the scene instantiates, has geometry, every surface has a material, and textured materials resolved their textures.
## Prints "PROPS_CHECK props=<n> errors=<n>" (run_checks.sh looks for errors=0).

const PROPS_DIR := "res://loads/props"
const WRAPPERS_DIR := "res://objects/art"
const NO_COLLISION := ["chain_hanging", "cable_hang", "document_sheet", "personal_key"]
const TEXTURED_MATERIALS := [
	"painted_metal", "steel_bare", "rusted_steel", "diamond_plate", "rubber_black", "plastic_panel",
	"vinyl_worn", "duct_galvanized", "concrete_rubble", "paper_aged",
	"signs_ru", "signs_lit", "hazard_stripes", "panel_labels", "instrument_faces", "screens",
]


func _init() -> void:
	var errors := 0
	var count := 0
	for dir_name in DirAccess.get_directories_at(PROPS_DIR):
		var path := "%s/%s/%s.gltf" % [PROPS_DIR, dir_name, dir_name]
		if not ResourceLoader.exists(path):
			printerr("PROPS_CHECK missing import: ", path)
			errors += 1
			continue
		count += 1
		var scene := load(path) as PackedScene
		if scene == null:
			printerr("PROPS_CHECK cannot load ", path)
			errors += 1
			continue
		var root := scene.instantiate()
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			printerr("PROPS_CHECK no meshes in ", dir_name)
			errors += 1
		for node in meshes:
			var mesh := (node as MeshInstance3D).mesh
			if mesh == null:
				printerr("PROPS_CHECK empty mesh node ", dir_name, "/", node.name)
				errors += 1
				continue
			for i in mesh.get_surface_count():
				var material := mesh.surface_get_material(i) as BaseMaterial3D
				if material == null:
					printerr("PROPS_CHECK surface without material ", dir_name, "/", node.name, "/", i)
					errors += 1
				elif material.resource_name in TEXTURED_MATERIALS and material.albedo_texture == null:
					printerr("PROPS_CHECK texture not resolved: ", dir_name, " ", material.resource_name)
					errors += 1
		root.free()
	# wrapper scenes: instantiate and require a collision shape unless the prop is a hanging decoration
	for file_name in DirAccess.get_files_at(WRAPPERS_DIR):
		if not file_name.ends_with(".tscn"):
			continue
		var wrapper := load("%s/%s" % [WRAPPERS_DIR, file_name]) as PackedScene
		if wrapper == null:
			printerr("PROPS_CHECK cannot load wrapper ", file_name)
			errors += 1
			continue
		var node := wrapper.instantiate()
		var has_shape := not node.find_children("*", "CollisionShape3D", true, false).is_empty()
		if not has_shape and not NO_COLLISION.has(file_name.get_basename()):
			printerr("PROPS_CHECK wrapper without collision: ", file_name)
			errors += 1
		if node.find_child("Model", false, false) == null:
			printerr("PROPS_CHECK wrapper without Model: ", file_name)
			errors += 1
		node.free()
	print("PROPS_CHECK props=%d errors=%d" % [count, errors])
	quit(1 if errors > 0 else 0)
