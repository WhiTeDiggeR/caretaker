class_name HoldRing
extends ProgressBar

## Hold progress as a ring around the crosshair (issue #147). Driven like any Range by the
## Interactor (`value`, `visible`); the bar itself is not drawn.

const RADIUS := 17.0
const WIDTH := 2.5
const TRACK := Color(0.94, 0.94, 0.91, 0.2)
const POINTS := 48


func _ready() -> void:
	show_percentage = false
	add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	add_theme_stylebox_override(&"fill", StyleBoxEmpty.new())
	value_changed.connect(func(_v: float) -> void: queue_redraw())


func _draw() -> void:
	var centre := size * 0.5
	draw_arc(centre, RADIUS, 0.0, TAU, POINTS, TRACK, WIDTH, true)
	var ratio := (value - min_value) / maxf(max_value - min_value, 0.001)
	if ratio > 0.0:
		draw_arc(centre, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * ratio, POINTS, UiStyle.ACCENT, WIDTH, true)
