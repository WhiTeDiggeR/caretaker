class_name ItemSketch
extends Control

## A pencil sketch of a carried item in the journal (#223): a few wobbly strokes, as the hero
## would draw it in the margin. Shapes by `sketch` id; unknown ids draw a wrapped bundle.

const SIZE := Vector2(132, 84)
const LINE := UiStyle.PENCIL
const WIDTH := 2.0
const WOBBLE := 1.2

var sketch := ""


static func create(sketch_id: String) -> ItemSketch:
	var view := ItemSketch.new()
	view.sketch = sketch_id
	view.custom_minimum_size = SIZE
	view.mouse_filter = MOUSE_FILTER_IGNORE
	return view


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sketch)
	match sketch:
		"key":
			_ring(rng, Vector2(0.24, 0.5), 0.16)
			_ring(rng, Vector2(0.24, 0.5), 0.06)
			_stroke(rng, [Vector2(0.4, 0.5), Vector2(0.9, 0.5)])
			_stroke(rng, [Vector2(0.4, 0.58), Vector2(0.9, 0.58)])
			_stroke(rng, [Vector2(0.9, 0.5), Vector2(0.9, 0.58)])
			_stroke(rng, [Vector2(0.72, 0.58), Vector2(0.72, 0.72), Vector2(0.78, 0.72), Vector2(0.78, 0.58)])
			_stroke(rng, [Vector2(0.84, 0.58), Vector2(0.84, 0.68), Vector2(0.88, 0.68)])
		"crowbar":
			_stroke(rng, [Vector2(0.16, 0.18), Vector2(0.08, 0.26), Vector2(0.12, 0.34), Vector2(0.2, 0.3)])
			_stroke(rng, [Vector2(0.2, 0.3), Vector2(0.86, 0.74)])
			_stroke(rng, [Vector2(0.17, 0.38), Vector2(0.82, 0.82)])
			_stroke(rng, [Vector2(0.86, 0.74), Vector2(0.94, 0.74), Vector2(0.9, 0.84), Vector2(0.82, 0.82)])
		"card":
			_stroke(rng, [Vector2(0.18, 0.18), Vector2(0.82, 0.18), Vector2(0.82, 0.82), Vector2(0.18, 0.82), Vector2(0.18, 0.18)])
			_stroke(rng, [Vector2(0.28, 0.3), Vector2(0.44, 0.3), Vector2(0.44, 0.52), Vector2(0.28, 0.52), Vector2(0.28, 0.3)])
			_stroke(rng, [Vector2(0.52, 0.34), Vector2(0.74, 0.34)])
			_stroke(rng, [Vector2(0.52, 0.46), Vector2(0.7, 0.46)])
			_stroke(rng, [Vector2(0.28, 0.68), Vector2(0.74, 0.68)])
		"cylinder":
			_stroke(rng, [Vector2(0.3, 0.3), Vector2(0.3, 0.86), Vector2(0.7, 0.86), Vector2(0.7, 0.3)])
			_stroke(rng, [Vector2(0.3, 0.3), Vector2(0.4, 0.2), Vector2(0.6, 0.2), Vector2(0.7, 0.3)])
			_stroke(rng, [Vector2(0.44, 0.2), Vector2(0.44, 0.1), Vector2(0.56, 0.1), Vector2(0.56, 0.2)])
			_stroke(rng, [Vector2(0.3, 0.5), Vector2(0.7, 0.5)])
			_stroke(rng, [Vector2(0.3, 0.6), Vector2(0.7, 0.6)])
		"tool":
			_ring(rng, Vector2(0.2, 0.5), 0.14)
			_stroke(rng, [Vector2(0.3, 0.44), Vector2(0.82, 0.44), Vector2(0.88, 0.5), Vector2(0.82, 0.56), Vector2(0.3, 0.56)])
			_stroke(rng, [Vector2(0.6, 0.44), Vector2(0.6, 0.56)])
			_stroke(rng, [Vector2(0.66, 0.44), Vector2(0.66, 0.56)])
		_:
			_stroke(rng, [Vector2(0.2, 0.3), Vector2(0.8, 0.26), Vector2(0.84, 0.76), Vector2(0.18, 0.78), Vector2(0.2, 0.3)])
			_stroke(rng, [Vector2(0.2, 0.3), Vector2(0.5, 0.52), Vector2(0.8, 0.26)])


## A stroke through points given in fractions of the sketch box, each point slightly shaken.
func _stroke(rng: RandomNumberGenerator, points: Array) -> void:
	var line := PackedVector2Array()
	for point: Vector2 in points:
		line.append(point * size + Vector2(rng.randf_range(-WOBBLE, WOBBLE), rng.randf_range(-WOBBLE, WOBBLE)))
	draw_polyline(line, LINE, WIDTH, true)


func _ring(rng: RandomNumberGenerator, center: Vector2, radius: float) -> void:
	var points := []
	for step in 21:
		points.append(center + Vector2.from_angle(TAU * step / 20.0) * radius * Vector2(size.y / size.x, 1.0))
	_stroke(rng, points)
