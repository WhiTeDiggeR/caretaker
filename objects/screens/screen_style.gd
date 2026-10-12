class_name ScreenStyle
extends Resource

## Look of a world screen of one era of the complex (docs/ui/style-guide.md, issue #145):
## old core — amber CRT, sleep lab — green phosphor, serial modules — flat cyan screen.
## The same status grammar holds on every era; only the display technique changes.

const ERA_OLD_CORE := &"old_core"
const ERA_SLEEP_LAB := &"sleep_lab"
const ERA_MODULE := &"module"
const ERAS: Array[StringName] = [ERA_OLD_CORE, ERA_SLEEP_LAB, ERA_MODULE]
const DEFAULT_ERA := ERA_MODULE
const STYLE_DIR := "res://materials/ui/screens"

@export var era: StringName = DEFAULT_ERA
@export_group("Colours")
@export var background := Color("#041114")
@export var phosphor := Color("#1fb5c8")
@export var dim := Color("#0e505c")
## Screen title: dim on phosphor screens, information cyan on late ones.
@export var title_color := Color("#1fb5c8")
## Monitor casing around the picture.
@export var bezel := Color("#1a1c1d")
## Late screens colour status words; phosphor screens have one colour and blink instead.
@export var status_colors := false
@export_group("Type")
@export var font: Font
@export var font_size := 22
@export var title_font: Font
@export var title_size := 20
@export var hint_font: Font
@export_group("Layout")
@export var corner_radius := 18
@export var bezel_width := 18
## Selected option: inverted line (old CRTs) or a marker in a brighter colour.
@export var invert_selection := false
@export_group("Typing")
@export var chars_per_second := 140.0
## Late screens print whole lines with a short delay instead of characters.
@export var line_by_line := false
@export var line_delay := 0.06
@export_group("Picture")
## Phosphor glow as a text halo, 0 disables it.
@export var glow_size := 6
@export_range(0.0, 1.0) var glow_alpha := 0.35
@export_range(0.0, 1.0) var scanlines := 0.3
@export_range(0.0, 1.0) var vignette := 0.5
@export_range(0.0, 2.0) var bloom := 0.5
@export_range(0.0, 1.0) var roll := 0.0
@export_range(0.0, 1.0) var pixel_grid := 0.0
@export_range(0.0, 1.0) var jitter := 0.0

static var _cache: Dictionary[StringName, ScreenStyle] = {}


static func is_known(name: StringName) -> bool:
	return name in ERAS


## Style of an era; unknown or empty names fall back to the serial-module screen.
static func for_era(name: StringName) -> ScreenStyle:
	if not is_known(name):
		name = DEFAULT_ERA
	if not _cache.has(name):
		_cache[name] = load("%s/%s.tres" % [STYLE_DIR, name]) as ScreenStyle
	return _cache[name]


## Colour of a status word on this screen: status colours on late screens, phosphor otherwise.
func status_color(status: StringName) -> Color:
	if not status_colors:
		return dim if status == &"none" else phosphor
	match status:
		&"ok":
			return UiStyle.STATUS_OK
		&"warn":
			return UiStyle.STATUS_WARN
		&"alarm":
			return UiStyle.STATUS_ALARM
		&"none":
			return dim
	return phosphor


## Panel of the screen: the picture inside its casing.
func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = bezel
	box.set_border_width_all(bezel_width)
	box.set_corner_radius_all(corner_radius)
	box.corner_detail = 6
	box.shadow_color = Color(0, 0, 0, 0.6)
	box.shadow_size = 24
	return box


## Applies font, colour and glow to a label of the screen.
func style_label(label: Control, color: Color, size: int = -1, label_font: Font = null) -> void:
	label.add_theme_font_override(&"font" if label is Label else &"normal_font", label_font if label_font else font)
	label.add_theme_font_size_override(&"font_size" if label is Label else &"normal_font_size", size if size > 0 else font_size)
	label.add_theme_color_override(&"font_color" if label is Label else &"default_color", color)
	if glow_size > 0:
		label.add_theme_color_override(&"font_shadow_color", Color(color, glow_alpha))
		label.add_theme_constant_override(&"shadow_offset_x", 0)
		label.add_theme_constant_override(&"shadow_offset_y", 0)
		label.add_theme_constant_override(&"shadow_outline_size", glow_size)


## Material of the CRT overlay; null when the player switched the effect off.
func crt_material(emergency_power: bool = false) -> ShaderMaterial:
	if not Settings.crt_effects:
		return null
	var material := ShaderMaterial.new()
	material.shader = preload("res://materials/ui/crt_screen.gdshader")
	material.set_shader_parameter(&"scanlines", scanlines)
	material.set_shader_parameter(&"vignette", vignette)
	material.set_shader_parameter(&"bloom", bloom)
	material.set_shader_parameter(&"roll", roll)
	material.set_shader_parameter(&"pixel_grid", pixel_grid)
	material.set_shader_parameter(&"jitter", jitter)
	material.set_shader_parameter(&"tint", phosphor)
	material.set_shader_parameter(&"flicker", 0.6 if emergency_power else 0.0)
	return material
