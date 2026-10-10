class_name ShellUI
extends RefCounted

## Shared look and small builders of the shell screens (menu, pause, settings, saves).

const TITLE := "СМОТРИТЕЛЬ"  # working title, not fixed by the world bible
const ACCENT := Color(0.95, 0.72, 0.32)
const TEXT := Color(0.86, 0.87, 0.85)
const MUTED := Color(0.55, 0.58, 0.57)
const PANEL := Color(0.07, 0.08, 0.085, 0.94)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	var normal := _box(Color(0.13, 0.14, 0.15), Color(0.25, 0.27, 0.28))
	var hover := _box(Color(0.18, 0.19, 0.2), ACCENT)
	var pressed := _box(Color(0.24, 0.2, 0.12), ACCENT)
	var disabled := _box(Color(0.1, 0.1, 0.11), Color(0.18, 0.19, 0.2))
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", hover], ["disabled", disabled]]:
		_theme.set_stylebox(state[0], &"Button", state[1])
	_theme.set_color(&"font_color", &"Button", TEXT)
	_theme.set_color(&"font_hover_color", &"Button", ACCENT)
	_theme.set_color(&"font_focus_color", &"Button", ACCENT)
	_theme.set_color(&"font_disabled_color", &"Button", MUTED)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_theme.set_stylebox(state, &"CheckBox", StyleBoxEmpty.new())
	_theme.set_color(&"font_color", &"CheckBox", TEXT)
	_theme.set_color(&"font_hover_color", &"CheckBox", ACCENT)
	_theme.set_color(&"font_pressed_color", &"CheckBox", TEXT)
	_theme.set_color(&"font_color", &"Label", TEXT)
	_theme.set_stylebox(&"panel", &"PanelContainer", _box(PANEL, Color(0.25, 0.27, 0.28)))
	return _theme


## A full-screen layer with a dimmed background and a centred column.
static func screen(layer: CanvasLayer, title: String, width: float = 520.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = theme()
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override(&"font_size", 30)
	heading.add_theme_color_override(&"font_color", ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	return column


static func button(parent: Control, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(0, 46)
	item.pressed.connect(action)
	parent.add_child(item)
	return item


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	return box
