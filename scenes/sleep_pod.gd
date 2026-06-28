extends Node3D

@onready var label = $Label3D

@export var villain_name = "Боузер"
@export var max_sleep_time = 30.0
@export var l_color = Color(0.231, 0.447, 0.231, 1.0)
@export var l_rotation = Vector3(0, 0, 0)
@export var l_position = Vector3(0, 0, 0)

var sleep_time = max_sleep_time
var awakened = false

func _ready():
	label.modulate = l_color
	label.rotation_degrees = l_rotation
	label.position = l_position

func _process(delta):
	if awakened:
		return

	sleep_time -= delta
	
	var h = floor(sleep_time / 3600)
	var m = floor((sleep_time - (h * 3600)) / 60)
	var s = round(sleep_time - (h * 3600) - (m * 60))
	label.text = format_str(h) + ":" + format_str(m) + ":" + format_str(s)

	if sleep_time <= 0:
		awakened = true
		label.text = "ПРОСНУЛСЯ!"

func interact():
	if awakened:
		return
	sleep_time += 30
	
func format_str(number) -> String:
	var s = str(number).replace(".0", "")
	if number < 10:
		s = "0" + s
	
	return s
