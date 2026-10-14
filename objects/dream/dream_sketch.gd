class_name DreamSketch
extends Control

## A journal sketch of a dream's knowledge (З-Р6, #196): a pencil drawing of what the hero saw,
## never the phase codes. `SKETCH_SEAL` draws the whole assembled seal — concentric rings with
## the code's images standing at the top mark; `SKETCH_IMAGES` draws the images one by one in
## code order. The glyph inside an image stays as faint as in the dream (images are pale
## plates; a reader may notice the shape, the sketch does not point at it).

const HEIGHT_SEAL := 220.0
const HEIGHT_IMAGES := 120.0
const LINE := Color(0.78, 0.74, 0.64)
const PALE := 0.55
const GLYPH_MIX := 0.32
const RING_WIDTH := 2.0
const SPENT_ALPHA := 0.45

var sketch: StringName = DreamKnowledge.SKETCH_SEAL
var dream: StringName = &""
var code := PackedStringArray()
var spent := false


static func create(entry: Dictionary) -> DreamSketch:
	var view := DreamSketch.new()
	view.sketch = entry.get("sketch", DreamKnowledge.SKETCH_SEAL)
	view.dream = entry.get("dream", &"")
	view.code = entry.get("code", PackedStringArray())
	view.spent = bool(entry.get("used", false))
	view.custom_minimum_size.y = HEIGHT_SEAL if view.sketch == DreamKnowledge.SKETCH_SEAL else HEIGHT_IMAGES
	view.modulate.a = SPENT_ALPHA if view.spent else 1.0
	return view


func _draw() -> void:
	if sketch == DreamKnowledge.SKETCH_SEAL:
		_draw_seal()
	else:
		_draw_images()


func _draw_seal() -> void:
	var center := Vector2(size.y * 0.5 + 8.0, size.y * 0.5)
	var outer := size.y * 0.47
	var count := maxi(code.size(), 1)
	var band := outer / (count + 0.6)
	for index in code.size():
		var radius := outer - band * index
		draw_arc(center, radius, 0.0, TAU, 64, LINE, RING_WIDTH, true)
		_draw_image(code[index], center - Vector2(0, radius - band * 0.5), band * 0.42)
	draw_arc(center, outer - band * count, 0.0, TAU, 32, LINE, RING_WIDTH, true)
	draw_line(center - Vector2(0, outer + 6.0), center - Vector2(0, outer - band * count), LINE * Color(1, 1, 1, 0.35), 1.0)


func _draw_images() -> void:
	var side := size.y * 0.8
	for index in code.size():
		_draw_image(code[index], Vector2(8.0 + side * 0.5 + index * side * 1.25, size.y * 0.5), side * 0.5)


## A pale hexagonal plate in the image's tint with the glyph faint inside it.
func _draw_image(glyph_id: String, center: Vector2, radius: float) -> void:
	var tint := Color(0.42, 0.38, 0.34)
	var data: Array = DreamKnowledge.image(dream, glyph_id).get("tint", [])
	if data.size() >= 3:
		tint = Color(data[0], data[1], data[2])
	var plate := tint.lerp(LINE, PALE)
	var hexagon := PackedVector2Array()
	for corner in 6:
		hexagon.append(center + Vector2.from_angle(TAU * corner / 6.0 - PI * 0.5) * radius)
	draw_colored_polygon(hexagon, plate)
	hexagon.append(hexagon[0])
	draw_polyline(hexagon, LINE, 1.5, true)
	var side := radius * 1.1
	var origin := center - Vector2(side, side) * 0.5
	var glyph_color := plate.lerp(tint.darkened(0.4), GLYPH_MIX)
	var width := maxf(DreamGlyph.MIN_UI_WIDTH, side * DreamGlyph.WIDTH)
	for line in DreamGlyph.polylines(glyph_id):
		var points := PackedVector2Array()
		for point in line:
			points.append(origin + point * side)
		if points.size() == 1:
			draw_circle(points[0], maxf(width, side * DreamGlyph.DOT_RADIUS), glyph_color)
		else:
			draw_polyline(points, glyph_color, width, true)
