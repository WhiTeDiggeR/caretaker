extends StaticBody3D

@export var animation_time := 0.8
@export var open_offset_y := 3.8

@onready var collision: CollisionShape3D = $Collision
@onready var moving_parts: Array[Node3D] = [
	$LeftPanel,
	$RightPanel,
	$LeftAccent,
	$RightAccent,
	$LeftRearPanel,
	$RightRearPanel,
	$LeftRearAccent,
	$RightRearAccent,
	$LeftLowerAccent,
	$RightLowerAccent,
	$LeftRearLowerAccent,
	$RightRearLowerAccent,
]

var is_open := false
var is_moving := false
var closed_y_positions: Array[float] = []

func _ready() -> void:
	for part in moving_parts:
		closed_y_positions.append(part.position.y)

func get_interaction_text() -> String:
	return "[E] ЗАКРЫТЬ ДВЕРЬ" if is_open else "[E] ОТКРЫТЬ ДВЕРЬ"

func interact() -> void:
	if is_moving:
		return
	is_moving = true
	var opening := not is_open
	if opening:
		collision.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for index in moving_parts.size():
		var target_y := closed_y_positions[index] + open_offset_y if opening else closed_y_positions[index]
		tween.tween_property(moving_parts[index], "position:y", target_y, animation_time)
	await tween.finished
	is_open = opening
	if not is_open:
		collision.set_deferred("disabled", false)
	is_moving = false
