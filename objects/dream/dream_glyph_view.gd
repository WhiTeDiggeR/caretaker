class_name DreamGlyphView
extends Control

## A glyph drawn as lines in UI from DreamGlyph (the journal, the panel screen, overlays).
## The stroke keeps DreamGlyph.WIDTH of the size and is never thinner than 2 px (24 px keys).

@export var glyph_id := "":
	set(value):
		glyph_id = value
		queue_redraw()
@export var color := Color(0.9, 0.91, 0.89):
	set(value):
		color = value
		queue_redraw()


func stroke_width() -> float:
	return maxf(DreamGlyph.MIN_UI_WIDTH, minf(size.x, size.y) * DreamGlyph.WIDTH)


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	var width := stroke_width()
	for line in DreamGlyph.polylines(glyph_id):
		var points := PackedVector2Array()
		for point in line:
			points.append(origin + point * side)
		if points.size() == 1:
			draw_circle(points[0], maxf(width, side * DreamGlyph.DOT_RADIUS), color)
			continue
		draw_polyline(points, color, width, true)
		for point in points:
			draw_circle(point, width * 0.5, color)
