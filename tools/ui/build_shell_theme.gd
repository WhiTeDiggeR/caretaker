extends SceneTree

## Builds materials/ui/shell_theme.tres, the theme of the shell (variant A «Протокол»,
## docs/ui/style-guide.md, issue #144), from the UiStyle tokens. Run after changing a token:
##   godot --headless --path . --script res://tools/ui/build_shell_theme.gd
## Prints SHELL_THEME_OK on success. The .tres is generated: do not edit it by hand.

const OUT := "res://materials/ui/shell_theme.tres"
const PLATE := Color(0.055, 0.063, 0.068, 0.97)
const LINE := Color(0.19, 0.21, 0.23)
const FIELD := Color(0.08, 0.09, 0.095)
const BASE_SIZE := 21
const ITEM_MARGIN_LEFT := 58


func _init() -> void:
	var theme := Theme.new()
	theme.default_font = UiStyle.FONT_BODY
	theme.default_font_size = BASE_SIZE
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_controls(theme)
	var error := ResourceSaver.save(theme, OUT)
	print("SHELL_THEME_OK" if error == OK else "SHELL_THEME_FAILED %d" % error)
	quit(0 if error == OK else 1)


func _labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", UiStyle.TEXT)
	_variation(theme, &"ShellTitle", &"Label", UiStyle.FONT_DISPLAY_STRONG, 92, UiStyle.TEXT)
	_variation(theme, &"ShellHeading", &"Label", UiStyle.FONT_DISPLAY, 32, UiStyle.ACCENT)
	_variation(theme, &"ShellSection", &"Label", UiStyle.FONT_DISPLAY, 19, UiStyle.ACCENT)
	_variation(theme, &"ShellKicker", &"Label", UiStyle.FONT_MONO_MEDIUM, 13, Color(UiStyle.TEXT, 0.5))
	_variation(theme, &"ShellNote", &"Label", UiStyle.FONT_MONO, 14, UiStyle.MUTED)
	_variation(theme, &"ShellSubtitle", &"Label", UiStyle.FONT_BODY, 21, UiStyle.MUTED)


func _variation(theme: Theme, name: StringName, base: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, color)


func _buttons(theme: Theme) -> void:
	# Menu items draw their own band and edge (ShellButton); the boxes only hold the margins.
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = ITEM_MARGIN_LEFT
		box.content_margin_right = 24
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		theme.set_stylebox(state, &"Button", box)
	theme.set_font(&"font", &"Button", UiStyle.FONT_BODY)
	theme.set_font_size(&"font_size", &"Button", BASE_SIZE)
	theme.set_color(&"font_color", &"Button", Color(UiStyle.TEXT, 0.92))
	theme.set_color(&"font_hover_color", &"Button", UiStyle.ACCENT)
	theme.set_color(&"font_focus_color", &"Button", UiStyle.ACCENT)
	theme.set_color(&"font_pressed_color", &"Button", Color("#fff3d6"))
	theme.set_color(&"font_hover_pressed_color", &"Button", Color("#fff3d6"))
	theme.set_color(&"font_disabled_color", &"Button", Color(UiStyle.TEXT, 0.3))
	# Keys of the controls: a framed cap, like the key hints.
	theme.set_type_variation(&"KeyButton", &"Button")
	theme.set_stylebox(&"normal", &"KeyButton", _box(FIELD, LINE, 1, 8))
	theme.set_stylebox(&"hover", &"KeyButton", _box(FIELD, UiStyle.ACCENT, 1, 8))
	theme.set_stylebox(&"focus", &"KeyButton", _box(Color(0, 0, 0, 0), UiStyle.ACCENT, 1, 8))
	theme.set_stylebox(&"pressed", &"KeyButton", _box(Color(UiStyle.ACCENT, 0.28), UiStyle.ACCENT, 1, 8))
	theme.set_stylebox(&"hover_pressed", &"KeyButton", _box(Color(UiStyle.ACCENT, 0.28), UiStyle.ACCENT, 1, 8))
	theme.set_font(&"font", &"KeyButton", UiStyle.FONT_MONO_MEDIUM)
	theme.set_font_size(&"font_size", &"KeyButton", 16)


func _panels(theme: Theme) -> void:
	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE
	plate.border_color = UiStyle.ACCENT
	plate.border_width_left = 3
	plate.content_margin_left = 44
	plate.content_margin_right = 40
	plate.content_margin_top = 34
	plate.content_margin_bottom = 30
	theme.set_stylebox(&"panel", &"PanelContainer", plate)


func _controls(theme: Theme) -> void:
	# Slider: a hairline track filled with amber up to a narrow bar grabber.
	var track := _box(LINE, Color.TRANSPARENT, 0, 0)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	theme.set_stylebox(&"slider", &"HSlider", track)
	var filled := _box(UiStyle.ACCENT, Color.TRANSPARENT, 0, 0)
	filled.content_margin_top = 1
	filled.content_margin_bottom = 1
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	theme.set_icon(&"grabber", &"HSlider", _bar_icon(Vector2i(8, 20), UiStyle.ACCENT))
	theme.set_icon(&"grabber_highlight", &"HSlider", _bar_icon(Vector2i(8, 20), Color("#ffd28a")))
	theme.set_icon(&"grabber_disabled", &"HSlider", _bar_icon(Vector2i(8, 20), UiStyle.MUTED))
	# Check box: an empty frame, filled amber when on.
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"CheckBox", StyleBoxEmpty.new())
	theme.set_icon(&"unchecked", &"CheckBox", _check_icon(false))
	theme.set_icon(&"checked", &"CheckBox", _check_icon(true))
	theme.set_constant(&"h_separation", &"CheckBox", 14)
	theme.set_color(&"font_color", &"CheckBox", UiStyle.TEXT)
	theme.set_color(&"font_hover_color", &"CheckBox", UiStyle.ACCENT)
	theme.set_color(&"font_focus_color", &"CheckBox", UiStyle.ACCENT)
	theme.set_color(&"font_pressed_color", &"CheckBox", UiStyle.TEXT)
	theme.set_color(&"font_hover_pressed_color", &"CheckBox", UiStyle.ACCENT)
	# Loading bar: a hairline.
	theme.set_stylebox(&"background", &"ProgressBar", _box(LINE, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _box(UiStyle.ACCENT, Color.TRANSPARENT, 0, 0))
	# Scrollbars: thin and dark.
	theme.set_stylebox(&"scroll", &"VScrollBar", _thin(FIELD))
	theme.set_stylebox(&"grabber", &"VScrollBar", _thin(LINE))
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", _thin(UiStyle.ACCENT))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _thin(UiStyle.ACCENT))


func _box(fill: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(margin)
	return box


func _thin(color: Color) -> StyleBoxFlat:
	var box := _box(color, Color.TRANSPARENT, 0, 0)
	box.content_margin_left = 3
	box.content_margin_right = 3
	return box


func _bar_icon(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _check_icon(on: bool) -> ImageTexture:
	var side := 20
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for i in side:
		for edge in [0, side - 1]:
			image.set_pixel(i, edge, UiStyle.MUTED)
			image.set_pixel(edge, i, UiStyle.MUTED)
	if on:
		image.fill_rect(Rect2i(4, 4, side - 8, side - 8), UiStyle.ACCENT)
	return ImageTexture.create_from_image(image)
