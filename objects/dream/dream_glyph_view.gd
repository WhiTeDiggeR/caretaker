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
	return width_for(minf(size.x, size.y))


## Stroke width for a glyph `side` pixels wide.
static func width_for(side: float) -> float:
	return maxf(DreamGlyph.MIN_UI_WIDTH, side * DreamGlyph.WIDTH)


func _draw() -> void:
	var side := minf(size.x, size.y)
	draw_glyph(self, glyph_id, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), color)


## Draws glyph `id` into the square `rect` of any canvas item (the panel screen slots draw
## through here, so every place keeps one stroke).
static func draw_glyph(canvas: CanvasItem, id: String, rect: Rect2, glyph_color: Color) -> void:
	var side := minf(rect.size.x, rect.size.y)
	var width := width_for(side)
	for line in DreamGlyph.polylines(id):
		var points := PackedVector2Array()
		for point in line:
			points.append(rect.position + point * side)
		if points.size() == 1:
			canvas.draw_circle(points[0], maxf(width, side * DreamGlyph.DOT_RADIUS), glyph_color)
			continue
		canvas.draw_polyline(points, glyph_color, width, true)
		for point in points:
			canvas.draw_circle(point, width * 0.5, glyph_color)
