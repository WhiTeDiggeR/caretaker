class_name SaveIcon
extends Control

## The one save icon of the game (issue #152): the crystal of the immersion chair turns and
## floats, an amber arc runs along a hoop around it and passes behind it. When the record is
## written the arc closes into the whole hoop and flashes. Drawn in code, any size (the
## control's size), keeps moving while the game is paused.

enum State { IDLE, WRITING, DONE }

const SIDES := 6
## Proportions relative to the smaller side of the control.
const CRYSTAL_HEIGHT := 0.36
const CRYSTAL_RADIUS := 0.13
const HOOP_RADIUS := 0.42
const HOOP_TILT := 0.32
const BOB := 0.025
const TURN_SPEED := 1.6
const RUN_SPEED := 4.2
const ARC_LENGTH := 0.32
const CLOSE_SECONDS := 0.35
const FLASH_SECONDS := 0.6
const POINTS := 48
const LIGHT := Vector2(-0.55, -0.8)
const CORE := Color("#f4fbff")
const EDGE := Color("#9fd3e6")
const DEEP := Color("#2f5f7a")
const GLOW := Color(0.75, 0.9, 1.0)

var state := State.IDLE

var _time := 0.0
var _turn := 0.0
var _run := 0.0
var _done_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Starts the running arc: a record is being written.
func start() -> void:
	state = State.WRITING
	_done_time = 0.0
	queue_redraw()


## Closes the arc into the hoop and flashes: the record is written.
func complete() -> void:
	if state == State.IDLE:
		start()
	state = State.DONE
	_done_time = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_turn += delta * TURN_SPEED
	_run = fmod(_run + delta * RUN_SPEED / TAU, 1.0)
	if state == State.DONE:
		_done_time += delta
	queue_redraw()


func _draw() -> void:
	var unit := minf(size.x, size.y)
	var centre := size * 0.5 + Vector2(0, sin(_time * 2.2) * BOB * unit)
	draw_circle(centre, unit * 0.3, Color(GLOW, 0.06))
	draw_circle(centre, unit * 0.18, Color(GLOW, 0.1))
	_draw_hoop(centre, unit, false)
	_draw_crystal(centre, unit)
	_draw_hoop(centre, unit, true)


## The hoop is an ellipse; its back half is drawn before the crystal, the front half after.
func _draw_hoop(centre: Vector2, unit: float, front: bool) -> void:
	var radius := Vector2(HOOP_RADIUS, HOOP_RADIUS * HOOP_TILT) * unit
	var width := maxf(unit * 0.035, 1.0)
	var track := Color(UiStyle.ACCENT, 0.22)
	var lit := UiStyle.ACCENT
	var closing := clampf(_done_time / CLOSE_SECONDS, 0.0, 1.0) if state == State.DONE else 0.0
	var arc := lerpf(ARC_LENGTH, 1.0, closing)
	var flash := 1.0 - clampf((_done_time - CLOSE_SECONDS) / FLASH_SECONDS, 0.0, 1.0) if state == State.DONE and _done_time > CLOSE_SECONDS else 0.0
	# One continuous polyline per half with a colour per point: no seams between segments.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var first := 0 if front else POINTS / 2
	for step in POINTS / 2 + 1:
		var a := float(first + step) / POINTS
		points.append(centre + Vector2(cos(a * TAU), sin(a * TAU)) * radius)
		var color := track
		if state != State.IDLE:
			var behind := fposmod(_run - a, 1.0)
			if behind < arc:
				color = Color(lit, lerpf(1.0, 0.25, behind / arc) if closing < 1.0 else 1.0)
		if flash > 0.0:
			color = color.lerp(Color(1.0, 0.92, 0.75), flash)
		colors.append(color)
	draw_polyline_colors(points, colors, width, true)


## A hexagonal bipyramid turning round its vertical axis, faces lit from the upper left.
func _draw_crystal(centre: Vector2, unit: float) -> void:
	var height := CRYSTAL_HEIGHT * unit
	var radius := CRYSTAL_RADIUS * unit
	var top := centre + Vector2(0, -height * 0.5)
	var bottom := centre + Vector2(0, height * 0.5)
	var faces: Array[Dictionary] = []
	for index in SIDES:
		var a0 := _turn + TAU * index / SIDES
		var a1 := _turn + TAU * (index + 1) / SIDES
		var mid := (a0 + a1) * 0.5
		var depth := sin(mid)
		if depth < -0.05:
			continue
		var v0 := centre + Vector2(cos(a0) * radius, sin(a0) * radius * HOOP_TILT * 0.5)
		var v1 := centre + Vector2(cos(a1) * radius, sin(a1) * radius * HOOP_TILT * 0.5)
		var facing := clampf(0.5 + 0.5 * Vector2(cos(mid), -0.4).normalized().dot(LIGHT.normalized()), 0.0, 1.0)
		faces.append({"depth": depth, "upper": [top, v0, v1], "lower": [bottom, v1, v0], "light": facing})
	faces.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["depth"] < y["depth"])
	for face in faces:
		var light: float = face["light"]
		draw_colored_polygon(PackedVector2Array(face["upper"]), DEEP.lerp(CORE, 0.35 + 0.65 * light))
		draw_colored_polygon(PackedVector2Array(face["lower"]), DEEP.lerp(EDGE, 0.2 + 0.6 * light))
		var outline := Color(CORE, 0.55)
		draw_polyline(PackedVector2Array(face["upper"] + [face["upper"][0]]), outline, 1.0, true)
		draw_polyline(PackedVector2Array(face["lower"] + [face["lower"][0]]), outline, 1.0, true)
