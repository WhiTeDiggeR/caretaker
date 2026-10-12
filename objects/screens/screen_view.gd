class_name ScreenView
extends Control

## Picture of a world screen drawn into a SubViewport (issue #146): a header with the
## screen's code, then rows of text with a status each. The look comes from ScreenStyle;
## the owner feeds rows and power and the view redraws only when they change.

signal changed

const MARGIN := Vector2(36.0, 28.0)
const ROW_GAP := 6.0
const HEADER_GAP := 16.0
const BOOT_SECONDS := 1.2
const BOOT_LINES: Array[String] = ["ПРОВЕРКА ПАМЯТИ ........ ОК", "ШИНА ДАННЫХ ............ ОК", "СВЯЗЬ С МОДУЛЯМИ ....... ОК"]
const STATUSES: Array[StringName] = [&"ok", &"warn", &"alarm", &"none", &""]
## Status words blink on phosphor screens (they have one colour): seconds per phase.
const BLINK_WARN := 0.6
const BLINK_ALARM := 0.3

var style: ScreenStyle
var title := ""
var rows: Array[Dictionary] = []
var powered := true
var booting := 0.0
## Accent of the module (late screens only): a narrow mark in the header.
var module_color := Color.TRANSPARENT
## Screens on models are read from a few metres away: their type is larger than on the
## full-screen terminal.
var text_scale := 1.0

var _blink_time := 0.0


func setup(screen_style: ScreenStyle) -> void:
	style = screen_style
	queue_redraw()


## Rows: [{text, status (ok/warn/alarm/none/""), indent (bool)}]. Returns true if anything changed.
func show_rows(new_title: String, new_rows: Array[Dictionary]) -> bool:
	if new_title == title and new_rows == rows:
		return false
	title = new_title
	rows = new_rows
	_changed()
	return true


func set_powered(on: bool) -> void:
	if on == powered:
		return
	powered = on
	booting = BOOT_SECONDS if on else 0.0
	_changed()


## True while the picture moves (boot sequence or blinking status words).
func is_animated() -> bool:
	return powered and (booting > 0.0 or _has_blinking())


func _process(delta: float) -> void:
	if not is_animated():
		return
	booting = maxf(booting - delta, 0.0)
	_blink_time += delta
	_changed()


func _changed() -> void:
	queue_redraw()
	changed.emit()


func _has_blinking() -> bool:
	if style == null or style.status_colors:
		return false
	for row in rows:
		if row.get("status", &"") in [&"warn", &"alarm"]:
			return true
	return false


func _draw() -> void:
	if style == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), style.background if powered else Color.BLACK)
	if not powered:
		return
	var font := style.font
	var font_size := roundi(style.font_size * text_scale)
	var title_size := roundi(style.title_size * text_scale)
	var line := font.get_height(font_size) + ROW_GAP * text_scale
	var margin := MARGIN * text_scale
	var y := margin.y
	if booting > 0.0:
		var shown := int(ceil((1.0 - booting / BOOT_SECONDS) * BOOT_LINES.size()))
		for index in shown:
			draw_string(font, Vector2(margin.x, y + font.get_ascent(font_size)), BOOT_LINES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, style.phosphor)
			y += line
		return
	var title_font := style.title_font if style.title_font else font
	var x := margin.x
	if module_color.a > 0.0 and style.status_colors:
		draw_rect(Rect2(margin.x, y, 6.0 * text_scale, title_font.get_height(title_size)), module_color)
		x += 18.0 * text_scale
	draw_string(title_font, Vector2(x, y + title_font.get_ascent(title_size)), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - margin.x, title_size, style.title_color)
	y += title_font.get_height(title_size) + HEADER_GAP * text_scale * 0.5
	draw_line(Vector2(margin.x, y), Vector2(size.x - margin.x, y), Color(style.dim, 0.7), 2.0)
	y += HEADER_GAP * text_scale
	for row in rows:
		var status: StringName = row.get("status", &"")
		var text := str(row.get("text", ""))
		var indent := margin.x + (32.0 * text_scale if row.get("indent", false) else 0.0)
		var color := style.status_color(status) if status != &"" else style.phosphor
		if _hidden_by_blink(status):
			color = style.dim
		# Long lines wrap under their own indent.
		var width := size.x - indent - margin.x
		draw_multiline_string(font, Vector2(indent, y + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)
		y += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y + ROW_GAP * text_scale


func _hidden_by_blink(status: StringName) -> bool:
	if style.status_colors:
		return false
	match status:
		&"warn":
			return fmod(_blink_time, BLINK_WARN * 2.0) > BLINK_WARN
		&"alarm":
			return fmod(_blink_time, BLINK_ALARM * 2.0) > BLINK_ALARM
	return false
