class_name ShellButton
extends Button

## Menu item of the shell, variant A «Протокол» (docs/ui/style-guide.md, issue #144): a number
## on the left like a terminal option, the label, a quiet note on the right. Hover and focus
## light an amber edge and a fading band; a dangerous item turns red. `text` stays the label,
## so code and tests find items by it.

const INDEX_WIDTH := 46.0
const EDGE := 3.0
const BAND_ALPHA := 0.16
const PRESSED_ALPHA := 0.28
const NOTE_SIZE := 13
const INDEX_SIZE := 12
const NOTE_GAP := 18.0

## "01", "02"... Empty hides the column.
@export var index_text := ""
## Quiet note on the right (where a save leads, why an item is unavailable).
@export var note := "":
	set(value):
		note = value
		queue_redraw()
## Leaving the game, overwriting: red instead of amber.
@export var danger := false


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var accent := UiStyle.STATUS_ALARM if danger else UiStyle.ACCENT
	var lit := not disabled and (has_focus() or is_hovered())
	if lit or (button_pressed and not disabled):
		var alpha := PRESSED_ALPHA if get_draw_mode() == DRAW_PRESSED else BAND_ALPHA
		var band := Color(accent, alpha)
		var clear := Color(accent, 0.0)
		var w := size.x * 0.85
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
				PackedColorArray([band, clear, clear, band]))
		draw_rect(Rect2(0, 0, EDGE, size.y), accent)
	var muted := Color(UiStyle.TEXT, 0.3 if disabled else 0.42)
	var mono := UiStyle.FONT_MONO
	var baseline := (size.y + mono.get_ascent(INDEX_SIZE) - mono.get_descent(INDEX_SIZE)) * 0.5
	if not index_text.is_empty():
		draw_string(mono, Vector2(EDGE + 12.0, baseline), index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, INDEX_SIZE, accent if lit else muted)
	if not note.is_empty():
		var width := mono.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE).x
		draw_string(mono, Vector2(size.x - width - NOTE_GAP, baseline), note, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE, muted)
