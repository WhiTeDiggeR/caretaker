class_name DreamMeter
extends Control

## A thin meter of the dream HUD (issue #164): a Cormorant SC caption over a hairline bar in
## the sleeper's colours, no frame and no number (the style guide shows no figures in a
## dream). A loss leaves a bright trail that melts into the bar; below the low mark the fill
## breathes slowly.

const CAPTION_SIZE := 15
const BAR_HEIGHT := 4.0
const CAPTION_GAP := 6.0
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.6
const LOW := 0.25
const LOW_PULSE := 1.4
const GLOW_SIZE := 6
## The empty track: a faint line of the text colour.
const TRACK_ALPHA := 0.16

@export var caption := ""
@export var fill := Color("#ff7a2e")
## Halo of the caption and of the trail.
@export var glow := Color("#ff7a2e")
@export var text := Color("#ffe7cf")

## 0..1.
var ratio := 1.0
## Where the trail of the last loss currently ends (>= ratio).
var trail := 1.0

var _trail_wait := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, UiStyle.FONT_DREAM.get_height(CAPTION_SIZE) + CAPTION_GAP + BAR_HEIGHT + 2.0)


func set_value(value: float, maximum: float) -> void:
	var next := clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
	if next < ratio:
		trail = maxf(trail, ratio)
		_trail_wait = TRAIL_DELAY
	else:
		trail = maxf(trail, next)
	ratio = next
	queue_redraw()


## Jumps to the value with no trail (binding to a fight, the showroom).
func reset(value: float, maximum: float) -> void:
	ratio = clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
	trail = ratio
	queue_redraw()


func is_low() -> bool:
	return ratio < LOW


func _process(delta: float) -> void:
	_time += delta
	if trail > ratio:
		if _trail_wait > 0.0:
			_trail_wait -= delta
		else:
			trail = maxf(ratio, trail - TRAIL_SPEED * delta)
		queue_redraw()
	elif is_low():
		queue_redraw()


func _draw() -> void:
	var font := UiStyle.FONT_DREAM
	var ascent := font.get_ascent(CAPTION_SIZE)
	# A soft halo of the sleeper's light behind the caption, as in the dream HUD.
	draw_string_outline(font, Vector2(0, ascent), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, GLOW_SIZE, Color(glow, 0.22))
	draw_string(font, Vector2(0, ascent), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, Color(text, 0.8))
	var y := font.get_height(CAPTION_SIZE) + CAPTION_GAP
	draw_rect(Rect2(0, y, size.x, BAR_HEIGHT), Color(text, TRACK_ALPHA))
	if trail > ratio:
		draw_rect(Rect2(size.x * ratio, y - 1.0, size.x * (trail - ratio), BAR_HEIGHT + 2.0), Color(text, 0.85))
	var shade := fill
	if is_low():
		shade = fill.lerp(Color(text, 1.0), 0.35 * (0.5 + 0.5 * sin(_time * TAU / LOW_PULSE)))
	draw_rect(Rect2(0, y, size.x * ratio, BAR_HEIGHT), shade)
	# A short bright head marks where the bar ends.
	if ratio > 0.0:
		draw_rect(Rect2(size.x * ratio - 2.0, y - 1.0, 2.0, BAR_HEIGHT + 2.0), Color(text, 0.9))
