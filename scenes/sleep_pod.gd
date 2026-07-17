class_name SleepPod
extends Node3D

signal sleep_time_changed(current_seconds: float, maximum_seconds: float)
signal pod_awakened

const DEFAULT_INTERACTION_EXTENSION := 30.0

@onready var _label: Label3D = $Label3D

@export var villain_name: String = "Боузер"
@export var max_sleep_time: float = 30.0
@export var interaction_extension: float = DEFAULT_INTERACTION_EXTENSION
@export var l_color: Color = Color(0.231, 0.447, 0.231, 1.0)
@export var l_rotation: Vector3 = Vector3.ZERO
@export var l_position: Vector3 = Vector3.ZERO

var sleep_time: float = 0.0
var awakened: bool = false
var _displayed_seconds := -1


func _ready() -> void:
	sleep_time = maxf(max_sleep_time, 0.0)
	_label.modulate = l_color
	_label.rotation_degrees = l_rotation
	_label.position = l_position
	_refresh_display(true)


func _process(delta: float) -> void:
	if awakened:
		return

	sleep_time = maxf(sleep_time - delta, 0.0)
	_refresh_display()
	if sleep_time <= 0.0:
		awakened = true
		_label.text = "ПРОСНУЛСЯ!"
		pod_awakened.emit()


func interact() -> void:
	if awakened:
		return
	sleep_time += interaction_extension
	_refresh_display(true)


func _refresh_display(force_update: bool = false) -> void:
	var seconds_left := maxi(ceili(sleep_time), 0)
	if not force_update and seconds_left == _displayed_seconds:
		return

	_displayed_seconds = seconds_left
	var hours := seconds_left / 3600
	var minutes := (seconds_left % 3600) / 60
	var seconds := seconds_left % 60
	_label.text = "%02d:%02d:%02d" % [hours, minutes, seconds]
	sleep_time_changed.emit(sleep_time, max_sleep_time)
