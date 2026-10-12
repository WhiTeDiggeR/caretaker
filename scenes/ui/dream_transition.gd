class_name DreamTransition
extends CanvasLayer

## Veil between reality and a dream (docs/ui/style-guide.md, «Сон и нейроинтерфейс», issue
## #149). Entering and leaving through the gate wash the frame white with the last system line
## in monospace and one word of the dream in Cormorant; death in the dream is noise and red
## with the system's dry line about the consequence; the chemical awakening is amber.
## Dreams fades it in and out through `veil`.

enum Mode { ENTER, GATE, DEATH, WOKEN }

const WORD_SIZE := 54
const VERDICT_SIZE := 40
const LINE_SIZE := 18
const LETTER_SPACING := 14
const NOISE_ALPHA := 0.35
const WORDS: Array[String] = ["погружение", "возвращение", "", ""]
const DEATH_TITLE := "СВЯЗЬ С СОЗНАНИЕМ ПРЕРВАНА"
const WOKEN_TITLE := "ЭКСТРЕННОЕ ПРОБУЖДЕНИЕ"
## Veil colour per mode.
const VEILS: Array[Color] = [Color(1, 1, 1), Color(1, 1, 1), Color(0.03, 0.0, 0.0), Color(0.08, 0.05, 0.01)]
const INKS: Array[Color] = [Color("#1d2a33"), Color("#1d2a33"), Color("#ff6a52"), Color("#e8a21c")]

## Opacity of the whole veil, 0 — hidden.
var veil := 0.0:
	set(value):
		veil = value
		if _root:
			_root.modulate.a = value
			_root.visible = value > 0.0
var mode := Mode.ENTER

var _root: Control
var _back: ColorRect
var _noise: TextureRect
var _word: Label
var _line: Label
var _dream_font: FontVariation


func _init() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_back = ColorRect.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_back)
	_noise = TextureRect.new()
	_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise.stretch_mode = TextureRect.STRETCH_TILE
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.9
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	_noise.texture = texture
	_root.add_child(_noise)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 14)
	_root.add_child(column)
	_word = Label.new()
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dream_font = UiStyle.FONT_DREAM.duplicate() as FontVariation
	_dream_font.spacing_glyph = LETTER_SPACING
	column.add_child(_word)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_override(&"font", UiStyle.FONT_MONO_MEDIUM)
	_line.add_theme_font_size_override(&"font_size", LINE_SIZE)
	column.add_child(_line)
	veil = 0.0


## Sets what the veil says. `system_line` is the monospace line of the system.
func show_mode(new_mode: Mode, system_line: String) -> void:
	mode = new_mode
	_back.color = VEILS[mode]
	var ink := INKS[mode]
	var harsh := mode == Mode.DEATH or mode == Mode.WOKEN
	_noise.visible = mode == Mode.DEATH
	_noise.modulate = Color(1.0, 0.35, 0.3, NOISE_ALPHA)
	_word.text = WORDS[mode] if not harsh else (DEATH_TITLE if mode == Mode.DEATH else WOKEN_TITLE)
	# The dream speaks in Cormorant; the system's verdicts stay in its own late typeface.
	_word.add_theme_font_override(&"font", UiStyle.FONT_SCREEN_LATE_STRONG if harsh else _dream_font)
	_word.add_theme_font_size_override(&"font_size", VERDICT_SIZE if harsh else WORD_SIZE)
	_word.add_theme_color_override(&"font_color", ink)
	_line.text = system_line
	_line.add_theme_color_override(&"font_color", Color(ink, 0.65))


func word_text() -> String:
	return _word.text


func line_text() -> String:
	return _line.text


func _process(_delta: float) -> void:
	# The death noise crawls while it is visible.
	if _noise.visible and veil > 0.0:
		var noise_texture := _noise.texture as NoiseTexture2D
		(noise_texture.noise as FastNoiseLite).offset.z += 3.0
