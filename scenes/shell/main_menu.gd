class_name MainMenu
extends Control

## Main menu, variant A «Протокол» (docs/ui/style-guide.md, issue #144): a service title page
## of the complex — mono kicker, the title in Oswald, numbered items with one amber rail —
## over a dark backdrop with grain and a flickering lamp line. The first time in a session
## it opens behind the splash of variant B «Кристалл»: any key or click dismisses it.
## Items: continue, load a chosen save, new game, settings, quit; the test range in debug
## builds.

const KICKER := "КОМПЛЕКС СОДЕРЖАНИЯ · АВАРИЙНЫЙ ДОСТУП"
const SUBTITLE := "Временный смотритель комплекса"
const SPLASH_HINT := "НАЖМИТЕ ЛЮБУЮ КЛАВИШУ"
const SPLASH_LINE := "чужой сон нужно удержать"
const FOOTER := "СБОРКА %s"
const DEFAULT_VERSION := "0.1"
const BACKGROUND := Color(0.035, 0.04, 0.045)
const RAIL_X := 96.0
const COLUMN := Vector2(150.0, 190.0)
const COLUMN_WIDTH := 520.0
const GRAIN_ALPHA := 0.05
const FLICKER_SECONDS := 7.0
const SPLASH_FADE := 0.6
const SPLASH_TITLE_SIZE := 86
const SPLASH_SPACING := 26

## The splash is shown once per run of the game, before the first menu.
static var splash_seen := false

var continue_button: ShellButton
var load_button: ShellButton
var buttons: VBoxContainer
var splash: Control

var _flicker: ColorRect
var _flicker_time := 0.0


func _ready() -> void:
	theme = ShellUI.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	var column := VBoxContainer.new()
	column.position = COLUMN
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)
	ShellUI.label(column, KICKER, &"ShellKicker")
	ShellUI.label(column, ShellUI.TITLE, &"ShellTitle").add_theme_font_override(&"font", _spaced(UiStyle.FONT_DISPLAY_STRONG, 10))
	ShellUI.label(column, SUBTITLE, &"ShellSubtitle")
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	column.add_child(spacer)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 2)
	column.add_child(buttons)
	continue_button = ShellUI.button(buttons, "Продолжить", _on_continue)
	load_button = ShellUI.button(buttons, "Загрузить игру", open_load)
	var new_game := ShellUI.button(buttons, "Новая игра", Shell.new_game)
	if OS.is_debug_build():
		ShellUI.button(buttons, "Полигон (отладка)", Shell.start_sandbox, "ОТЛАДКА")
	ShellUI.button(buttons, "Настройки", func() -> void: SettingsScreen.open(self))
	ShellUI.button(buttons, "Выход", Shell.quit_game)
	_build_footer()
	refresh()
	(continue_button if not continue_button.disabled else new_game).grab_focus.call_deferred()
	if not splash_seen:
		_build_splash()


func refresh() -> void:
	var latest := Saves.latest()
	continue_button.disabled = latest.is_empty()
	load_button.disabled = continue_button.disabled
	continue_button.note = Saves.stamp(latest).to_upper() if not latest.is_empty() else ""


## Slot list for loading; focus returns to the menu when it is closed.
func open_load() -> SaveSlotsScreen:
	var screen := SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.LOAD)
	screen.closed.connect(func() -> void:
		if is_inside_tree():
			load_button.grab_focus())
	return screen


func dismiss_splash() -> void:
	if splash == null:
		return
	splash_seen = true
	var leaving := splash
	splash = null
	leaving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(leaving, "modulate:a", 0.0, SPLASH_FADE)
	tween.tween_callback(leaving.queue_free)


func _process(delta: float) -> void:
	# A lamp at the top edge drops out now and then, like the fluorescent tubes of the complex.
	_flicker_time = fmod(_flicker_time + delta, FLICKER_SECONDS)
	var phase := _flicker_time / FLICKER_SECONDS
	_flicker.modulate.a = 0.2 if (phase > 0.61 and phase < 0.62) or (phase > 0.64 and phase < 0.65) else 1.0


func _input(event: InputEvent) -> void:
	if splash == null:
		return
	var key := event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
	if key and event.is_pressed():
		dismiss_splash()
		get_viewport().set_input_as_handled()


func _on_continue() -> void:
	Shell.load_game(Saves.latest())


func _build_backdrop() -> void:
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.7))
	var vignette := GradientTexture2D.new()
	vignette.gradient = gradient
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.62, 0.45)
	vignette.fill_to = Vector2(1.25, 1.1)
	shade.texture = vignette
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var grain := TextureRect.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.8
	var grain_texture := NoiseTexture2D.new()
	grain_texture.width = 256
	grain_texture.height = 256
	grain_texture.noise = noise
	grain.texture = grain_texture
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate = Color(1, 1, 1, GRAIN_ALPHA)
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grain)
	_flicker = ColorRect.new()
	_flicker.color = Color(0.86, 0.94, 1.0, 0.22)
	_flicker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_flicker.custom_minimum_size = Vector2(0, 1)
	add_child(_flicker)
	var rail := ColorRect.new()
	rail.color = Color(UiStyle.ACCENT, 0.55)
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = RAIL_X
	rail.offset_right = RAIL_X + 2.0
	add_child(rail)


func _build_footer() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var left := ShellUI.label(self, FOOTER % (version if not version.is_empty() else DEFAULT_VERSION), &"ShellKicker")
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = COLUMN.x
	left.offset_top = -64.0
	left.offset_bottom = -40.0
	var right := ShellUI.label(self, "[Enter] выбрать    [Esc] назад", &"ShellKicker")
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.offset_left = -560.0
	right.offset_right = -56.0
	right.offset_top = -64.0
	right.offset_bottom = -40.0


## Variant B before the first menu: the crystal of the immersion device breathes in the dark.
func _build_splash() -> void:
	splash = Control.new()
	splash.name = "Splash"
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash)
	splash.add_child(CrystalBackdrop.new())
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 520.0
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override(&"separation", 12)
	splash.add_child(column)
	var title := Label.new()
	title.text = ShellUI.TITLE.to_lower().capitalize()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", _spaced(UiStyle.FONT_DREAM, SPLASH_SPACING))
	title.add_theme_font_size_override(&"font_size", SPLASH_TITLE_SIZE)
	title.add_theme_color_override(&"font_color", Color("#eef6f9"))
	title.add_theme_color_override(&"font_shadow_color", Color(0.78, 0.92, 1.0, 0.18))
	title.add_theme_constant_override(&"shadow_outline_size", 10)
	title.add_theme_constant_override(&"shadow_offset_y", 0)
	column.add_child(title)
	var line := Label.new()
	line.text = SPLASH_LINE
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_override(&"font", UiStyle.FONT_BODY_ITALIC)
	line.add_theme_color_override(&"font_color", Color(0.86, 0.91, 0.93, 0.55))
	column.add_child(line)
	var hint := Label.new()
	hint.text = SPLASH_HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80.0
	hint.offset_bottom = -50.0
	hint.add_theme_font_override(&"font", _spaced(UiStyle.FONT_MONO, 6))
	hint.add_theme_font_size_override(&"font_size", 13)
	hint.add_theme_color_override(&"font_color", Color(0.86, 0.91, 0.93, 0.35))
	splash.add_child(hint)


static func _spaced(font: FontVariation, spacing: int) -> FontVariation:
	var spaced := font.duplicate() as FontVariation
	spaced.spacing_glyph = spacing
	return spaced
