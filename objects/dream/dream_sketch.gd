class_name DreamSketch
extends Control

## A journal sketch of a dream's knowledge (З-Р6, #196): a pencil drawing of what the hero saw,
## never the phase codes. `SKETCH_SEAL` draws the whole assembled seal — concentric rings with
## the code's images standing at the top mark; `SKETCH_IMAGES` draws the images one by one in
## code order. The glyph inside an image stays as faint as in the dream (images are pale
## plates; a reader may notice the shape, the sketch does not point at it).
## `SKETCH_SCHEME` (#234) draws a scheme as three pictograms in order — lava turned aside, a
## gate dropped, a drop of water over a gauge with the level marked — like the forge's relief.

const HEIGHT_SEAL := 220.0
const HEIGHT_IMAGES := 120.0
const HEIGHT_SCHEME := 120.0
const SCHEME_LEVELS := 3
const LINE := Color(0.78, 0.74, 0.64)
const PALE := 0.55
const GLYPH_MIX := 0.32
const RING_WIDTH := 2.0
const SPENT_ALPHA := 0.45

var sketch: StringName = DreamKnowledge.SKETCH_SEAL
var dream: StringName = &""
var code := PackedStringArray()
var spent := false
## The level of a scheme (1…3).
var level := 0
## Stroke colour: pale on a dark plate, pencil when drawn on the journal's paper (#223).
var line_color := LINE


static func create(entry: Dictionary) -> DreamSketch:
	var view := DreamSketch.new()
	view.sketch = entry.get("sketch", DreamKnowledge.SKETCH_SEAL)
	view.dream = entry.get("dream", &"")
	view.code = entry.get("code", PackedStringArray())
	view.spent = bool(entry.get("used", false))
	view.level = int(entry.get("level", 0))
	match view.sketch:
		DreamKnowledge.SKETCH_SEAL:
			view.custom_minimum_size.y = HEIGHT_SEAL
		DreamKnowledge.SKETCH_SCHEME:
			view.custom_minimum_size.y = HEIGHT_SCHEME
		_:
			view.custom_minimum_size.y = HEIGHT_IMAGES
	view.modulate.a = SPENT_ALPHA if view.spent else 1.0
	return view


func _draw() -> void:
	match sketch:
		DreamKnowledge.SKETCH_SEAL:
			_draw_seal()
		DreamKnowledge.SKETCH_SCHEME:
			_draw_scheme()
		_:
			_draw_images()


## Three frames left to right with arrows between them: the order of the scheme.
func _draw_scheme() -> void:
	var side := size.y * 0.8
	var top := size.y * 0.1
	var step := side * 1.45
	for frame in 3:
		var origin := Vector2(8.0 + frame * step, top)
		draw_rect(Rect2(origin, Vector2(side, side)), line_color, false, 1.5, true)
		match frame:
			0:
				_draw_bypass(origin, side)
			1:
				_draw_gate(origin, side)
			2:
				_draw_quench(origin, side)
		if frame < 2:
			var from := origin + Vector2(side + side * 0.1, side * 0.5)
			var to := from + Vector2(side * 0.25, 0)
			draw_line(from, to, line_color, 2.0, true)
			draw_line(to, to + Vector2(-6, -5), line_color, 2.0, true)
			draw_line(to, to + Vector2(-6, 5), line_color, 2.0, true)


## A channel running right whose flow bends off down a side branch.
func _draw_bypass(origin: Vector2, side: float) -> void:
	var y := origin.y + side * 0.35
	draw_line(origin + Vector2(side * 0.1, y - origin.y), origin + Vector2(side * 0.9, y - origin.y), line_color, 1.5, true)
	draw_line(origin + Vector2(side * 0.1, y - origin.y + side * 0.2), origin + Vector2(side * 0.4, y - origin.y + side * 0.2), line_color, 1.5, true)
	draw_line(origin + Vector2(side * 0.6, y - origin.y + side * 0.2), origin + Vector2(side * 0.9, y - origin.y + side * 0.2), line_color, 1.5, true)
	var bend := PackedVector2Array([origin + Vector2(side * 0.15, side * 0.45), origin + Vector2(side * 0.5, side * 0.45), origin + Vector2(side * 0.5, side * 0.85)])
	draw_polyline(bend, line_color, 2.5, true)
	var tip := bend[2]
	draw_line(tip, tip + Vector2(-5, -7), line_color, 2.5, true)
	draw_line(tip, tip + Vector2(5, -7), line_color, 2.5, true)


## A gate dropped across the channel, an arrow down above it.
func _draw_gate(origin: Vector2, side: float) -> void:
	draw_line(origin + Vector2(side * 0.1, side * 0.7), origin + Vector2(side * 0.9, side * 0.7), line_color, 1.5, true)
	draw_rect(Rect2(origin + Vector2(side * 0.42, side * 0.35), Vector2(side * 0.16, side * 0.45)), line_color * Color(1, 1, 1, 0.6), true)
	var arrow_top := origin + Vector2(side * 0.5, side * 0.08)
	var arrow_tip := origin + Vector2(side * 0.5, side * 0.28)
	draw_line(arrow_top, arrow_tip, line_color, 2.0, true)
	draw_line(arrow_tip, arrow_tip + Vector2(-5, -6), line_color, 2.0, true)
	draw_line(arrow_tip, arrow_tip + Vector2(5, -6), line_color, 2.0, true)


## A drop beside a gauge of SCHEME_LEVELS notches; the scheme's level is marked heavy.
func _draw_quench(origin: Vector2, side: float) -> void:
	var drop := PackedVector2Array()
	var center := origin + Vector2(side * 0.32, side * 0.6)
	var radius := side * 0.16
	drop.append(center + Vector2(0, -radius * 2.4))
	for i in 13:
		var angle := -PI * 0.1 + PI * 1.2 * i / 12.0
		drop.append(center + Vector2(cos(angle), sin(angle)) * radius)
	drop.append(drop[0])
	draw_polyline(drop, line_color, 1.5, true)
	var rod_x := origin.x + side * 0.72
	var bottom := origin.y + side * 0.85
	var top := origin.y + side * 0.15
	draw_line(Vector2(rod_x, top), Vector2(rod_x, bottom), line_color, 1.5, true)
	for notch in range(1, SCHEME_LEVELS + 1):
		var y := lerpf(bottom, top, float(notch) / (SCHEME_LEVELS + 1))
		var heavy := notch == level
		draw_line(Vector2(rod_x - side * (0.12 if heavy else 0.06), y), Vector2(rod_x + side * (0.12 if heavy else 0.06), y), line_color, 3.0 if heavy else 1.0, true)
	if level > 0:
		var y := lerpf(bottom, top, float(level) / (SCHEME_LEVELS + 1))
		draw_line(Vector2(rod_x - side * 0.2, y), Vector2(rod_x - side * 0.12, y), line_color * Color(1, 1, 1, 0.6), 1.0, true)


func _draw_seal() -> void:
	var center := Vector2(size.y * 0.5 + 8.0, size.y * 0.5)
	var outer := size.y * 0.47
	var count := maxi(code.size(), 1)
	var band := outer / (count + 0.6)
	for index in code.size():
		var radius := outer - band * index
		draw_arc(center, radius, 0.0, TAU, 64, line_color, RING_WIDTH, true)
		_draw_image(code[index], center - Vector2(0, radius - band * 0.5), band * 0.42)
	draw_arc(center, outer - band * count, 0.0, TAU, 32, line_color, RING_WIDTH, true)
	draw_line(center - Vector2(0, outer + 6.0), center - Vector2(0, outer - band * count), line_color * Color(1, 1, 1, 0.35), 1.0)


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
	draw_polyline(hexagon, line_color, 1.5, true)
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
