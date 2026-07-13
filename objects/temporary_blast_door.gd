extends StaticBody3D

@export var animation_time := 0.65
@export var open_panel_x := 2.22

@onready var left_panel: MeshInstance3D = $LeftPanel
@onready var right_panel: MeshInstance3D = $RightPanel
@onready var left_accent: MeshInstance3D = $LeftAccent
@onready var right_accent: MeshInstance3D = $RightAccent
@onready var left_rear_panel: MeshInstance3D = $LeftRearPanel
@onready var right_rear_panel: MeshInstance3D = $RightRearPanel
@onready var left_rear_accent: MeshInstance3D = $LeftRearAccent
@onready var right_rear_accent: MeshInstance3D = $RightRearAccent
@onready var left_lower_accent: MeshInstance3D = $LeftLowerAccent
@onready var right_lower_accent: MeshInstance3D = $RightLowerAccent
@onready var left_rear_lower_accent: MeshInstance3D = $LeftRearLowerAccent
@onready var right_rear_lower_accent: MeshInstance3D = $RightRearLowerAccent
@onready var collision: CollisionShape3D = $Collision

var is_open := false
var is_moving := false
var closed_left_x := 0.0
var closed_right_x := 0.0

func _ready() -> void:
	closed_left_x = left_panel.position.x
	closed_right_x = right_panel.position.x

func get_interaction_text() -> String:
	return "[E] ЗАКРЫТЬ ДВЕРЬ" if is_open else "[E] ОТКРЫТЬ ДВЕРЬ"

func interact() -> void:
	if is_moving:
		return
	is_moving = true
	var opening := not is_open
	if opening:
		collision.set_deferred("disabled", true)
	var left_target := -open_panel_x if opening else closed_left_x
	var right_target := open_panel_x if opening else closed_right_x
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(left_panel, "position:x", left_target, animation_time)
	tween.tween_property(left_accent, "position:x", left_target, animation_time)
	tween.tween_property(right_panel, "position:x", right_target, animation_time)
	tween.tween_property(right_accent, "position:x", right_target, animation_time)
	tween.tween_property(left_rear_panel, "position:x", left_target, animation_time)
	tween.tween_property(right_rear_panel, "position:x", right_target, animation_time)
	tween.tween_property(left_rear_accent, "position:x", left_target, animation_time)
	tween.tween_property(right_rear_accent, "position:x", right_target, animation_time)
	tween.tween_property(left_lower_accent, "position:x", left_target, animation_time)
	tween.tween_property(right_lower_accent, "position:x", right_target, animation_time)
	tween.tween_property(left_rear_lower_accent, "position:x", left_target, animation_time)
	tween.tween_property(right_rear_lower_accent, "position:x", right_target, animation_time)
	await tween.finished
	is_open = opening
	if not is_open:
		collision.set_deferred("disabled", false)
	is_moving = false
