class_name ShellUI
extends RefCounted

## Shared look and small builders of the shell screens (menu, pause, settings, saves) in the
## chosen variant A «Протокол» (docs/ui/style-guide.md, issue #144). The theme is the
## generated resource materials/ui/shell_theme.tres (tools/ui/build_shell_theme.gd).

const TITLE := "СМОТРИТЕЛЬ"  # working title approved by the author
const THEME_PATH := "res://materials/ui/shell_theme.tres"
const ACCENT := UiStyle.ACCENT
const TEXT := UiStyle.TEXT
const MUTED := UiStyle.MUTED
const DIM := Color(0.02, 0.024, 0.027, 0.82)
const KICKER := "КОМПЛЕКС СОДЕРЖАНИЯ"
const ITEM_HEIGHT := 46.0
const COLUMN_GAP := 4

static var _theme: Theme


static func theme() -> Theme:
	if not _theme:
		_theme = load(THEME_PATH) as Theme
	return _theme


## A full-screen layer with a dimmed background and a centred plate: a mono kicker line,
## the heading in Oswald, then the column the caller fills.
static func screen(layer: CanvasLayer, title: String, width: float = 560.0, kicker: String = KICKER) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = theme()
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", COLUMN_GAP)
	panel.add_child(column)
	label(column, kicker.to_upper(), &"ShellKicker")
	var heading := label(column, title.to_upper(), &"ShellHeading")
	heading.name = "Heading"
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)
	return column


## Menu item: numbered in the order of the items of its parent, with an optional right note.
static func button(parent: Control, text: String, action: Callable, note: String = "") -> ShellButton:
	var item := ShellButton.new()
	item.text = text
	item.note = note
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	var number := parent.get_children().filter(func(node: Node) -> bool: return node is ShellButton).size() + 1
	item.index_text = "%02d" % number
	item.pressed.connect(action)
	parent.add_child(item)
	return item


static func label(parent: Control, text: String, variation: StringName = &"") -> Label:
	var line := Label.new()
	line.text = text
	line.theme_type_variation = variation
	parent.add_child(line)
	return line


## Confirmation over everything: the question, what happens, and two items. `on_yes` runs
## when the first item is chosen; Esc or «Отмена» closes the dialog.
static func confirm(parent: Node, title: String, text: String, yes_text: String, on_yes: Callable) -> ShellConfirm:
	var layer := ShellConfirm.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var column := screen(layer, title, 520.0, "ПОДТВЕРЖДЕНИЕ")
	var body := label(column, text, &"ShellSubtitle")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := button(column, yes_text, layer.answer.bind(true))
	yes.danger = true
	button(column, "Отмена", layer.answer.bind(false))
	layer.answered.connect(func(agreed: bool) -> void:
		if agreed:
			on_yes.call())
	yes.grab_focus.call_deferred()
	return layer
