class_name UiStyle
extends RefCounted

## Tokens of the interface style (docs/ui/style-guide.md, issue #141): fonts by role and the
## colours shared by every interface type. Screens and HUDs read them from here instead of
## repeating literals, so a change of the shell variant touches one file.

# --- Fonts by role (materials/ui/fonts, files in loads/fonts) ------------------------
const FONT_DISPLAY: FontVariation = preload("res://materials/ui/fonts/ui_display.tres")
const FONT_DISPLAY_STRONG: FontVariation = preload("res://materials/ui/fonts/ui_display_strong.tres")
const FONT_BODY: FontVariation = preload("res://materials/ui/fonts/ui_body.tres")
const FONT_BODY_BOLD: FontVariation = preload("res://materials/ui/fonts/ui_body_bold.tres")
const FONT_BODY_ITALIC: FontVariation = preload("res://materials/ui/fonts/ui_body_italic.tres")
const FONT_MONO: FontVariation = preload("res://materials/ui/fonts/ui_mono.tres")
const FONT_MONO_MEDIUM: FontVariation = preload("res://materials/ui/fonts/ui_mono_medium.tres")
const FONT_SCREEN_OLD: FontVariation = preload("res://materials/ui/fonts/screen_mono_old.tres")
const FONT_SCREEN_LATE: FontVariation = preload("res://materials/ui/fonts/screen_late.tres")
const FONT_SCREEN_LATE_MEDIUM: FontVariation = preload("res://materials/ui/fonts/screen_late_medium.tres")
const FONT_SCREEN_LATE_STRONG: FontVariation = preload("res://materials/ui/fonts/screen_late_strong.tres")
const FONT_DREAM: FontVariation = preload("res://materials/ui/fonts/dream_display.tres")
const FONT_DREAM_STRONG: FontVariation = preload("res://materials/ui/fonts/dream_display_strong.tres")
const FONT_HAND: FontVariation = preload("res://materials/ui/fonts/hand.tres")

# --- Shell and HUD -----------------------------------------------------------------
const ACCENT := Color(0.95, 0.72, 0.32)  # #f2b852, the shell accent (ShellUI.ACCENT)
const TEXT := Color(0.86, 0.87, 0.85)
const MUTED := Color(0.55, 0.58, 0.57)
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)

# --- Status grammar, the same on every screen and lamp (docs/art/style-guide.md) -----
const STATUS_OK := Color("#3ed36b")
const STATUS_WARN := Color("#e8a21c")
const STATUS_ALARM := Color("#d8341f")
const STATUS_INFO := Color("#1fb5c8")

# --- Module colours (late screens, dreams) ---------------------------------------------
const MODULE_BOWSER := Color("#3f8f4a")
const MODULE_HEROBRINE := Color("#2f5fa8")

# --- Paper -------------------------------------------------------------------------
const PAPER := Color(0.86, 0.83, 0.72)
const INK := Color("#221f1b")
const STAMP := Color("#a8321f")
const PENCIL := Color("#3d4150")

# --- Signs on equipment ------------------------------------------------------------
const SIGN_TEXT := Color("#e6e8e3")
## World size of one pixel of sign type.
const SIGN_PIXEL := 0.0015


## A caption on equipment in the type of the signs (light condensed on a dark plate, no
## outline): glyph buttons, button captions. Faces +Z of its parent.
static func sign_label(text: String, font_size: int = 34) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT_SCREEN_LATE_STRONG
	label.font_size = font_size
	label.modulate = SIGN_TEXT
	label.pixel_size = SIGN_PIXEL
	label.outline_size = 0
	return label
