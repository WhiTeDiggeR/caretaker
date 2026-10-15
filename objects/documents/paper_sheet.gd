class_name PaperSheet
extends Control

## A sheet of paper behind the document reader and the journal (#223): warm paper with grain,
## a slightly torn uneven edge, a darker rim and, for the hero's notebook, the squared ruling
## of a school exercise book with a red margin. Drawn, not a texture, so it fits any size.

const GRAIN_SIZE := 256.0
const GRAIN_COLOR := Color(0.35, 0.27, 0.16, 0.16)
const RIM_COLOR := Color(0.45, 0.38, 0.26, 0.55)
const EDGE_STEP := 18.0
const EDGE_JITTER := 2.6
const CORNER_CUT := 5.0
const GRID_STEP := 26.0
const GRID_COLOR := Color(0.36, 0.5, 0.66, 0.16)
const MARGIN_X := 64.0
const MARGIN_COLOR := Color(0.72, 0.24, 0.2, 0.32)
const NOTEBOOK_PAPER := Color(0.88, 0.86, 0.79)
const EDGE_SEED := 223

## Squared notebook page instead of a plain document sheet.
var ruled := false:
	set(value):
		ruled = value
		queue_redraw()

var _grain: NoiseTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_repeat = TEXTURE_REPEAT_ENABLED
	var noise := FastNoiseLite.new()
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	_grain = NoiseTexture2D.new()
	_grain.width = int(GRAIN_SIZE)
	_grain.height = int(GRAIN_SIZE)
	_grain.seamless = true
	_grain.noise = noise
	_grain.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var outline := edge_points(size)
	if outline.size() < 3:
		return
	draw_colored_polygon(outline, NOTEBOOK_PAPER if ruled else UiStyle.PAPER)
	if ruled:
		_draw_ruling()
	var uvs := PackedVector2Array()
	for point in outline:
		uvs.append(point / GRAIN_SIZE)
	draw_colored_polygon(outline, GRAIN_COLOR, uvs, _grain)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, RIM_COLOR, 1.5, true)


## Outline of the sheet: the rectangle with every edge broken into short jittered steps and the
## corners slightly cut. The same seed gives the same sheet every time it opens.
static func edge_points(sheet: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	if sheet.x <= CORNER_CUT * 2.0 or sheet.y <= CORNER_CUT * 2.0:
		return points
	var rng := RandomNumberGenerator.new()
	rng.seed = EDGE_SEED
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(sheet.x, 0.0), sheet, Vector2(0.0, sheet.y)]
	for side in 4:
		var from := corners[side]
		var to := corners[(side + 1) % 4]
		var direction := (to - from).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var length := from.distance_to(to)
		var steps := maxi(int(length / EDGE_STEP), 2)
		for step in steps:
			var along := lerpf(CORNER_CUT, length - CORNER_CUT, float(step) / (steps - 1))
			var inward := absf(rng.randf_range(-EDGE_JITTER, EDGE_JITTER))
			points.append(from + direction * along + normal * inward)
	return points


func _draw_ruling() -> void:
	var y := GRID_STEP
	while y < size.y - 2.0:
		draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), GRID_COLOR, 1.0)
		y += GRID_STEP
	var x := GRID_STEP
	while x < size.x - 2.0:
		draw_line(Vector2(x, 2.0), Vector2(x, size.y - 2.0), GRID_COLOR, 1.0)
		x += GRID_STEP
	draw_line(Vector2(MARGIN_X, 2.0), Vector2(MARGIN_X, size.y - 2.0), MARGIN_COLOR, 2.0)
