class_name PowerCascade
extends Node3D

## Sets `cascade_delay` of every PowerConsumer below this node by its distance from this
## node, so power spreads from here (e.g. from the generator) through a room.

@export var speed := 14.0
@export var base_delay := 0.15


func _ready() -> void:
	for node in find_children("*", "PowerConsumer", true, false):
		var consumer := node as PowerConsumer
		var anchor := consumer.get_parent() as Node3D
		if anchor == null:
			continue
		consumer.cascade_delay = base_delay + global_position.distance_to(anchor.global_position) / maxf(speed, 0.01)
