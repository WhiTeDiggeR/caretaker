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
const THUMB_SIZE := Vector2(96.0, 54.0)
const THUMB_GAP := 14.0
const FLASH_SECONDS := 0.9
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]

## "01", "02"... Empty hides the column.
@export var index_text := ""
## Quiet note on the right (where a save leads, why an item is unavailable).
@export var note := "":
	set(value):
		note = value
		queue_redraw()
## Leaving the game, overwriting: red instead of amber.
@export var danger := false
## Save slots (issue #152): a frame of the save between the number and the label; an empty
## dark frame while there is none.
@export var show_thumbnail := false:
	set(value):
		show_thumbnail = value
		_apply_margins()
@export var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		queue_redraw()

## 1 right after a record, fading to 0: the item flashes amber.
var _flash := 0.0


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_apply_margins()


## Amber flash of the item after a record was written into it.
func flash() -> void:
	_flash = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_flash", 0.0, FLASH_SECONDS)
	tween.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, FLASH_SECONDS)


## Moves the label right of the thumbnail; the theme's margins otherwise.
func _apply_margins() -> void:
	if not is_inside_tree():
		return
	for state in STATES:
		remove_theme_stylebox_override(state)
	if not show_thumbnail:
		return
	for state in STATES:
		var box := get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_left += THUMB_SIZE.x + THUMB_GAP
		add_theme_stylebox_override(state, box)
	custom_minimum_size.y = maxf(custom_minimum_size.y, THUMB_SIZE.y + 12.0)


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
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.35 * _flash))
	if show_thumbnail:
		var frame := Rect2(Vector2(INDEX_WIDTH + EDGE, (size.y - THUMB_SIZE.y) * 0.5), THUMB_SIZE)
		draw_rect(frame, Color(0.03, 0.035, 0.04))
		if thumbnail:
			draw_texture_rect(thumbnail, frame, false, Color(1, 1, 1, 0.55 if disabled else 0.9))
		draw_rect(frame, Color(UiStyle.TEXT, 0.18), false, 1.0)
	var muted := Color(UiStyle.TEXT, 0.3 if disabled else 0.42)
	var mono := UiStyle.FONT_MONO
	var baseline := (size.y + mono.get_ascent(INDEX_SIZE) - mono.get_descent(INDEX_SIZE)) * 0.5
	if not index_text.is_empty():
		draw_string(mono, Vector2(EDGE + 12.0, baseline), index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, INDEX_SIZE, accent if lit else muted)
	if not note.is_empty():
		var width := mono.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE).x
		draw_string(mono, Vector2(size.x - width - NOTE_GAP, baseline), note, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE, muted)
