extends Node3D

@export var default_visibility_distance := 48.0
@export var visibility_margin := 7.0

func _ready() -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry.visibility_range_end <= 0.0:
			geometry.visibility_range_end = default_visibility_distance
			geometry.visibility_range_end_margin = visibility_margin
