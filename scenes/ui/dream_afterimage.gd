class_name DreamAfterimage
extends CanvasLayer

## Afterimage of the assembled seal (З-Р5, #197; docs/game_design/07-dream-glyphs.md, section 9):
## after the gate the seal the hero restored lingers over the frame for about two seconds and
## melts away — concentric rings with the code's images at the reading mark. The glyph inside
## an image is drawn as faint as in the dream: the afterimage must not point out that the image
## is the phase mark (author's note to З-3). Above the dream veil, so it shows through the white
## and stays while the veil lifts over the complex.

const LAYER := 51
## Seconds the afterimage stays on screen, of them the last FADE_SECONDS fading out.
const SECONDS := 2.0
const FADE_SECONDS := 1.4
const START_ALPHA := 0.7
const DIAMETER := 360.0
const CORE_RATIO := 0.18
const IMAGE_RATIO := 0.8
const LINE_WIDTH := 2.0
const INK := Color("#1d2a33")
const DEFAULT_TINT := Color(0.42, 0.38, 0.34)

var dream: StringName = &""
## The glyphs of the seal, outer ring first.
var code := PackedStringArray()

var _canvas: Control
var _tween: Tween


func _init() -> void:
	layer = LAYER
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_seal)
	add_child(_canvas)
	hide_now()


## Shows the seal of `seal_code` as `seal_dream` saw it and lets it melt over SECONDS.
func play(seal_dream: StringName, seal_code: PackedStringArray) -> void:
	dream = seal_dream
	code = seal_code
	if _tween and _tween.is_valid():
		_tween.kill()
	_canvas.modulate.a = START_ALPHA
	visible = true
	_canvas.queue_redraw()
	_tween = create_tween()
	_tween.tween_interval(SECONDS - FADE_SECONDS)
	_tween.tween_property(_canvas, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide_now)


func hide_now() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	_canvas.modulate.a = 0.0


func is_showing() -> bool:
	return visible and _canvas.modulate.a > 0.0


## Opacity of the afterimage now, 0…START_ALPHA.
func alpha() -> float:
	return _canvas.modulate.a if visible else 0.0


## Colour of the glyph inside the image of `id`: muted as in the dream (DreamGlyphImage).
func glyph_color(id: String) -> Color:
	return DreamGlyphImage.muted_color(image_tint(id))


func image_tint(id: String) -> Color:
	var tint: Array = DreamKnowledge.image(dream, id).get("tint", [])
	return Color(tint[0], tint[1], tint[2]) if tint.size() >= 3 else DEFAULT_TINT


func _draw_seal() -> void:
	if code.is_empty():
		return
	var center := _canvas.size * 0.5
	var outer := DIAMETER * 0.5
	var core := outer * CORE_RATIO
	var width := (outer - core) / code.size()
	_canvas.draw_arc(center, core, 0.0, TAU, 48, INK, LINE_WIDTH, true)
	for ring in code.size():
		var ring_outer := outer - width * ring
		_canvas.draw_arc(center, ring_outer, 0.0, TAU, 64, INK, LINE_WIDTH, true)
		# The image of the ring's glyph stands at the reading mark, on top.
		var side := width * IMAGE_RATIO
		var at := center + Vector2(0, -(ring_outer - width * 0.5))
		_draw_image(code[ring], at, side)


## A pale hexagonal image with its glyph inside, as faint as on the unlit ring.
func _draw_image(id: String, at: Vector2, side: float) -> void:
	var hexagon := PackedVector2Array()
	for corner in 6:
		var angle := TAU * corner / 6.0
		hexagon.append(at + Vector2(cos(angle), sin(angle)) * side * 0.62)
	_canvas.draw_colored_polygon(hexagon, image_tint(id))
	hexagon.append(hexagon[0])
	_canvas.draw_polyline(hexagon, INK, LINE_WIDTH, true)
	var color := glyph_color(id)
	var width := maxf(DreamGlyph.MIN_UI_WIDTH, side * DreamGlyph.WIDTH)
	var origin := at - Vector2(side, side) * 0.5
	for line in DreamGlyph.polylines(id):
		var points := PackedVector2Array()
		for point in line:
			points.append(origin + point * side)
		if points.size() == 1:
			_canvas.draw_circle(points[0], maxf(width, side * DreamGlyph.DOT_RADIUS), color)
		else:
			_canvas.draw_polyline(points, color, width, true)
