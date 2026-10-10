extends Node

## Prints the visual bounding box of prop scenes: `godot --headless --path . res://tools/opening/measure_props.tscn -- <scene> ...`
## Used to keep docs/game_design/02-prop-standard.md in sync with the real assets.


func _ready() -> void:
	for path in OS.get_cmdline_user_args():
		var scene := (load(path) as PackedScene).instantiate()
		add_child(scene)
		var box := AABB()
		var first := true
		for node in [scene] + scene.find_children("*", "VisualInstance3D", true, false):
			var visual := node as VisualInstance3D
			if visual == null or visual is Light3D:
				continue
			var aabb := visual.global_transform * visual.get_aabb()
			box = aabb if first else box.merge(aabb)
			first = false
		print("PROP %s size=%.2fx%.2fx%.2f min_y=%.2f" % [path, box.size.x, box.size.y, box.size.z, box.position.y])
		scene.queue_free()
	get_tree().quit()
