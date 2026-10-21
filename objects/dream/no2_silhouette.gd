class_name No2Silhouette
extends Node3D

## The silhouette of №2 (#240): one figure for every place it is seen — the prologue, the
## terrace of Bowser's first dream, the interdream corridor (canon: 03-first-dream.md,
## 01-opening.md). A dark human shape without face or clothes, its edges smoke and breathe
## (no2_silhouette.gdshader). Origin at the feet; it always turns to the camera around Y.

const DEFAULT_COLOR := Color(0.04, 0.035, 0.05)
const DEFAULT_OPACITY := 0.92

## Tone of the figure (the interdream washes it towards the white of its fog).
@export var color := DEFAULT_COLOR:
	set(value):
		color = value
		_apply()
## How solid the figure is, 0–1.
@export_range(0.0, 1.0) var opacity := DEFAULT_OPACITY:
	set(value):
		opacity = value
		_apply()

@onready var _figure: GeometryInstance3D = $Figure


func _ready() -> void:
	# Each figure breathes and flickers out of step with the others.
	_figure.set_instance_shader_parameter(&"seed", randf() * 100.0)
	_apply()


func _apply() -> void:
	if _figure == null:
		return
	_figure.set_instance_shader_parameter(&"tint", color)
	_figure.set_instance_shader_parameter(&"opacity", opacity)
