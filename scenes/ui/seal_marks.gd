class_name SealMarks
extends Control

## Seals of the dream as diamonds in the dream HUD (issue #149): empty — cracked, filled and
## glowing — restored.

const SIDE := 14.0
const GAP := 12.0
const LINE := 2.0

var count := 1:
	set(value):
		count = maxi(value, 0)
		custom_minimum_size = Vector2(count * (SIDE * 1.42 + GAP), SIDE * 1.6)
		queue_redraw()
var filled := 0:
	set(value):
		filled = value
		queue_redraw()
var color := Color("#ffd6aa")
var glow := Color("#ff7a2e")


func _draw() -> void:
	var half := SIDE * 0.71
	for index in count:
		var centre := Vector2(size.x - half - index * (half * 2.0 + GAP), size.y * 0.5)
		var points := PackedVector2Array([centre + Vector2(0, -half), centre + Vector2(half, 0), centre + Vector2(0, half), centre + Vector2(-half, 0)])
		if count - 1 - index < filled:
			draw_circle(centre, half * 1.6, Color(glow, 0.18))
			draw_colored_polygon(points, Color(color, 0.9))
		points.append(points[0])
		draw_polyline(points, Color(color, 0.75), LINE, true)
