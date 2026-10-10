extends SceneTree
## Loads every prop in res://loads/props and checks it the way the game will use it:
## the scene instantiates, has geometry, every surface has a material, and textured materials resolved their textures.
## Prints "PROPS_CHECK props=<n> errors=<n>" (run_checks.sh looks for errors=0).

const PROPS_DIR := "res://loads/props"
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
	print("PROPS_CHECK props=%d errors=%d" % [count, errors])
	quit(1 if errors > 0 else 0)
