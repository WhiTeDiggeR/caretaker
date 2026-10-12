class_name HudPrompt
extends Label

## Interaction prompt of the HUD (docs/ui/style-guide.md, issue #147). The Interactor keeps
## writing plain text such as "[E] ОТКРЫТЬ"; this label draws it as a key in a frame and the
## action in capitals. Text without a key is an unavailable action: a red square and its
## reason. The native text stays in `text` (tests, other scripts) but is drawn transparent.

const KEY_PATTERN := "^\\[(.+?)\\]\\s*(.*)$"
const FONT_SIZE := 19
const KEY_FONT_SIZE := 15
const KEY_PADDING := Vector2(7.0, 3.0)
const GAP := 10.0
const SQUARE := 8.0
const LETTER_SPACING := 2
const OUTLINE := 3
const UNAVAILABLE_COLOR := Color(1.0, 0.55, 0.47)

var _regex := RegEx.create_from_string(KEY_PATTERN)
var _font: FontVariation


func _ready() -> void:
	_font = UiStyle.FONT_DISPLAY.duplicate() as FontVariation
	_font.spacing_glyph = LETTER_SPACING
	add_theme_color_override(&"font_color", Color.TRANSPARENT)
	add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	add_theme_color_override(&"font_shadow_color", Color.TRANSPARENT)


## Key and action parsed from the prompt text; the key is empty for an unavailable action.
func parts() -> PackedStringArray:
	var found := _regex.search(text)
	if found:
		return PackedStringArray([found.get_string(1), found.get_string(2)])
	return PackedStringArray(["", text])


func _draw() -> void:
	if text.is_empty():
		return
	var split := parts()
	var key := split[0]
	var action := split[1].to_upper()
	var action_width := _font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var key_size := Vector2.ZERO
	if not key.is_empty():
		key_size = UiStyle.FONT_MONO_MEDIUM.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FONT_SIZE) + KEY_PADDING * 2.0
	var lead := key_size.x if not key.is_empty() else SQUARE
	var x := (size.x - lead - GAP - action_width) * 0.5
	var baseline := size.y * 0.5 + _font.get_ascent(FONT_SIZE) * 0.38
	if key.is_empty():
		var square := Rect2(x, size.y * 0.5 - SQUARE * 0.5, SQUARE, SQUARE)
		draw_rect(square.grow(1.0), UiStyle.SHADOW)
		draw_rect(square, UiStyle.STATUS_ALARM)
	else:
		var frame := Rect2(Vector2(x, (size.y - key_size.y) * 0.5), key_size)
		draw_rect(frame, Color(0.04, 0.045, 0.05, 0.6))
		draw_rect(frame, UiStyle.ACCENT, false, 1.0)
		draw_line(frame.position + Vector2(0, frame.size.y), frame.end, UiStyle.ACCENT, 2.0)
		var key_baseline := frame.position.y + KEY_PADDING.y + UiStyle.FONT_MONO_MEDIUM.get_ascent(KEY_FONT_SIZE)
		draw_string(UiStyle.FONT_MONO_MEDIUM, Vector2(frame.position.x + KEY_PADDING.x, key_baseline), key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FONT_SIZE, UiStyle.ACCENT)
	var origin := Vector2(x + lead + GAP, baseline)
	draw_string_outline(_font, origin, action, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE, Color(UiStyle.SHADOW, 0.7))
	draw_string(_font, origin, action, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UNAVAILABLE_COLOR if key.is_empty() else UiStyle.TEXT)
