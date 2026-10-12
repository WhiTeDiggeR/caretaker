class_name OpeningHud
extends CanvasLayer

## First-person HUD for the opening: crosshair, interaction prompt, hold ring, current
## objective (flashes when it changes), one-time hints (Hints), short inspect messages and a
## notice when a document joins the journal. `J` opens the journal of read documents and
## objectives. The objective follows `GameState`; the prompt and hold ring are driven by the
## player's `Interactor`. Look: docs/ui/style-guide.md (HUD) — no plates but the notice and
## the message, text readable through its shadow.

const MESSAGE_SECONDS := 10.0
const TOAST_SECONDS := 5.0
const TOAST_TAG := "ЖУРНАЛ"
const TOAST_TEXT := "Документ добавлен: «%s» · %s"
const MESSAGE_GROUP := &"message_display"
const HINT_GROUP := &"hint_display"
const OBJECTIVE_FLASH := Color(1.0, 0.9, 0.55)
const TEXT_SIZE := 22
const LABEL_SIZE := 13
const MESSAGE_TITLE_SIZE := 20
const MESSAGE_TEXT_SIZE := 19
const MESSAGE_WIDTH := 720.0
const MESSAGE_MARGINS := 48.0
## Height of the message plate without its text: margins, title, hint and gaps.
const MESSAGE_CHROME := 104.0
const DREAM_HEADING := "ЗАДАЧА СНА"
const DREAM_TEXT_SIZE := 24
const DREAM_HEADING_SIZE := 17
const DREAM_GLOW_ALPHA := 0.3
const DREAM_GLOW_SIZE := 8
## Vignette of a dream: always a little, closing in with the instability of the sleep.
const VIGNETTE_BASE := 0.25
const VIGNETTE_RANGE := 0.6
const VIGNETTE_REFRESH := 0.5
const ALERT_SECONDS := 8.0
const ALERT_WARNING := "ХИМИЧЕСКИЙ ПРОТОКОЛ · %s · ГЕРМЕТИЗАЦИЯ ЧЕРЕЗ %s"
const ALERT_SEALED := "%s ЗАПОЛНЕН СНОТВОРНЫМ · ОКНО РЕМОНТА %s"
const SAVE_ICON_SIZE := 52.0
const SAVE_WRITING := "ЗАПИСЬ ЖУРНАЛА СМЕНЫ"
const SAVE_DONE := "ЗАПИСАНО"
## The record itself is instant; the arc runs this long so the player sees it, then closes.
const SAVE_WRITE_SECONDS := 0.9
const SAVE_HOLD_SECONDS := 1.6
const SAVE_FADE_SECONDS := 0.5
const PLATE := Color(0.04, 0.047, 0.05, 0.72)
const OBJECTIVE_FLASH_SECONDS := 1.2
const HINT_WIDTH := 900.0
const HINT_BOTTOM := 150.0

@onready var interact_label: Label = $InteractLabel
@onready var hold_progress: ProgressBar = $HoldProgress
@onready var objective_label: Label = $ObjectiveLabel
@onready var objective_heading: Label = $ObjectiveHeading
@onready var journal_toast: PanelContainer = $JournalToast
@onready var toast_text: Label = $JournalToast/Margin/Row/Text
@onready var _toast_tag: Label = $JournalToast/Margin/Row/Tag
@onready var _toast_timer: Timer = $ToastTimer
@onready var message_panel: PanelContainer = $MessagePanel
@onready var message_title: Label = $MessagePanel/Margin/Lines/Title
@onready var message_text: Label = $MessagePanel/Margin/Lines/Text
@onready var message_hint: Label = $MessagePanel/Margin/Lines/Hint
@onready var _message_timer: Timer = $MessageTimer

var hint_label: Label
var _hint_timer: Timer
var _objective_tween: Tween
var _journal_size := 0
## Profile of the dream the HUD is in; null in reality.
var dream_profile: DreamProfile
var seal_marks: SealMarks
var alert_label: Label
var _vignette: ColorRect
var _vignette_timer: Timer
var _alert_timer: Timer
var save_indicator: Control
var save_icon: SaveIcon
var save_label: Label
var _save_tween: Tween


func _ready() -> void:
	add_to_group(MESSAGE_GROUP)
	add_to_group(HINT_GROUP)
	add_to_group(Saves.HUD_GROUP)
	add_to_group(Saves.DISPLAY_GROUP)
	_build_hint()
	_apply_style()
	_journal_size = DocumentLibrary.read_ids().size()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(func() -> void: _journal_size = DocumentLibrary.read_ids().size())
	_toast_timer.timeout.connect(func() -> void: journal_toast.visible = false)
	_build_save_indicator()
	if Dreams.in_dream:
		_enter_dream_mode(DreamProfile.for_module(Dreams.module_id))
	else:
		_build_alert()
	GameState.objective_changed.connect(_on_objective_changed)
	_set_objective_text(GameState.objective_text)
	_message_timer.timeout.connect(hide_message)
	hide_message()


func show_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true
	_hint_timer.start(Hints.SHOW_SECONDS)


func _build_hint() -> void:
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadowed(hint_label, UiStyle.FONT_BODY, TEXT_SIZE, UiStyle.TEXT)
	add_child(hint_label)
	# Bottom centre, above the interaction prompt.
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -HINT_WIDTH * 0.5
	hint_label.offset_right = HINT_WIDTH * 0.5
	hint_label.offset_top = -HINT_BOTTOM - 60.0
	hint_label.offset_bottom = -HINT_BOTTOM
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_label.visible = false
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(func() -> void: hint_label.visible = false)
	add_child(_hint_timer)


func show_message(title: String, text: String) -> void:
	message_title.text = title
	message_title.visible = not title.is_empty()
	message_text.text = text
	message_hint.text = InputPromptFormatter.format_action(&"ui_cancel", "ЗАКРЫТЬ")
	message_panel.visible = true
	# Grows upwards from its bottom edge to fit the text, above the hint line.
	# Wrapped labels report their height only after layout, so measure the text here.
	var text_height := UiStyle.FONT_BODY.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, MESSAGE_WIDTH - MESSAGE_MARGINS, MESSAGE_TEXT_SIZE).y
	message_panel.offset_top = message_panel.offset_bottom - text_height - MESSAGE_CHROME
	_message_timer.start(MESSAGE_SECONDS)


func hide_message() -> void:
	message_panel.visible = false
	_message_timer.stop()


func _unhandled_input(event: InputEvent) -> void:
	if message_panel.visible and event.is_action_pressed(&"ui_cancel"):
		hide_message()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal"):
		var player := get_tree().get_first_node_in_group(&"player")
		if player == null or not player.get("controls_locked"):
			DocumentReader.open_journal_scene(get_tree())
			get_viewport().set_input_as_handled()


func _on_objective_changed(_objective_id: StringName, text: String) -> void:
	_set_objective_text(text)
	if text.is_empty():
		return
	if _objective_tween:
		_objective_tween.kill()
	objective_label.modulate = OBJECTIVE_FLASH * 1.4
	_objective_tween = create_tween()
	_objective_tween.tween_property(objective_label, "modulate", Color.WHITE, OBJECTIVE_FLASH_SECONDS)


func _set_objective_text(text: String) -> void:
	objective_label.text = text
	objective_label.visible = not text.is_empty()
	objective_heading.visible = objective_label.visible


## Shows the notice for the document that just joined the journal.
func show_journal_notice(title: String) -> void:
	toast_text.text = TOAST_TEXT % [title, InputPromptFormatter.action_label(&"journal")]
	journal_toast.visible = true
	_toast_timer.start(TOAST_SECONDS)


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag != DocumentLibrary.JOURNAL_FLAG:
		return
	var ids := DocumentLibrary.read_ids()
	if ids.size() > _journal_size:
		show_journal_notice(_sentence_case(str(DocumentLibrary.get_document(ids[-1]).get("title", ""))))
	_journal_size = ids.size()


func _apply_style() -> void:
	_shadowed(objective_heading, UiStyle.FONT_MONO_MEDIUM, LABEL_SIZE, Color(UiStyle.ACCENT, 0.85))
	_shadowed(objective_label, UiStyle.FONT_BODY, TEXT_SIZE, UiStyle.TEXT)
	message_panel.add_theme_stylebox_override(&"panel", _plate())
	message_title.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY)
	message_title.add_theme_font_size_override(&"font_size", MESSAGE_TITLE_SIZE)
	message_title.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	message_text.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	message_text.add_theme_font_size_override(&"font_size", MESSAGE_TEXT_SIZE)
	message_text.add_theme_color_override(&"font_color", UiStyle.TEXT)
	message_hint.add_theme_font_override(&"font", UiStyle.FONT_MONO)
	message_hint.add_theme_font_size_override(&"font_size", LABEL_SIZE)
	message_hint.add_theme_color_override(&"font_color", UiStyle.MUTED)
	journal_toast.add_theme_stylebox_override(&"panel", _plate())
	_toast_tag.text = TOAST_TAG
	_toast_tag.add_theme_font_override(&"font", UiStyle.FONT_MONO_MEDIUM)
	_toast_tag.add_theme_font_size_override(&"font_size", LABEL_SIZE)
	_toast_tag.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	toast_text.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	toast_text.add_theme_font_size_override(&"font_size", 18)
	toast_text.add_theme_color_override(&"font_color", UiStyle.TEXT)


## Dark plate with the amber edge on the left: the inspect message and the journal notice.
func _plate() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE
	box.border_color = UiStyle.ACCENT
	box.border_width_left = 3
	return box


func _shadowed(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_shadow_color", UiStyle.SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.add_theme_constant_override(&"shadow_outline_size", 6)
	label.remove_theme_constant_override(&"outline_size")


## Journal titles are written in capitals; the notice quotes them in sentence case.
static func _sentence_case(title: String) -> String:
	return title.substr(0, 1).to_upper() + title.substr(1).to_lower() if not title.is_empty() else title


# --- Dream (type 5 of the style guide) ---------------------------------------------------

## The HUD of a dream: no frames, Cormorant heading, the task in italics, seal diamonds and the
## sleeper's colour closing in at the edges as the sleep grows unstable.
func _enter_dream_mode(profile: DreamProfile) -> void:
	dream_profile = profile
	objective_heading.text = DREAM_HEADING
	_shadowed(objective_heading, UiStyle.FONT_DREAM, DREAM_HEADING_SIZE, Color(profile.text, 0.75))
	_shadowed(objective_label, UiStyle.FONT_BODY_ITALIC, DREAM_TEXT_SIZE, profile.text)
	# No hard shadows in a dream: a soft halo of the sleeper's light instead.
	for label: Label in [objective_heading, objective_label]:
		label.add_theme_color_override(&"font_shadow_color", Color(profile.glow, DREAM_GLOW_ALPHA))
		label.add_theme_constant_override(&"shadow_offset_y", 0)
		label.add_theme_constant_override(&"shadow_outline_size", DREAM_GLOW_SIZE)
	seal_marks = SealMarks.new()
	seal_marks.name = "SealMarks"
	seal_marks.color = profile.text
	seal_marks.glow = profile.glow
	seal_marks.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	seal_marks.offset_left = -240.0
	seal_marks.offset_right = -40.0
	seal_marks.offset_top = 34.0
	seal_marks.offset_bottom = 60.0
	add_child(seal_marks)
	_count_seals.call_deferred()
	Dreams.seal_restored_signal.connect(func(_id: StringName) -> void: seal_marks.filled = seal_marks.count)
	_vignette = ColorRect.new()
	_vignette.name = "DreamVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://materials/ui/dream_vignette.gdshader")
	material.set_shader_parameter(&"tint", profile.vignette)
	_vignette.material = material
	add_child(_vignette)
	move_child(_vignette, 0)
	_vignette_timer = Timer.new()
	_vignette_timer.wait_time = VIGNETTE_REFRESH
	_vignette_timer.timeout.connect(_refresh_vignette)
	add_child(_vignette_timer)
	_vignette_timer.start()
	_refresh_vignette()


## Seals of this dream (all show the visit's state, see DreamSeal); counted once.
func _count_seals() -> void:
	var scene := get_tree().current_scene
	var seals := scene.find_children("*", "DreamSeal", true, false).size() if scene else 0
	seal_marks.count = maxi(seals, 1)
	seal_marks.filled = seal_marks.count if Dreams.seal_restored else 0


func _refresh_vignette() -> void:
	var material := _vignette.material as ShaderMaterial
	var unrest := Containment.get_instability(Dreams.module_id) / 100.0 if Containment.modules.has(Dreams.module_id) else 0.0
	material.set_shader_parameter(&"strength", VIGNETTE_BASE + VIGNETTE_RANGE * clampf(unrest, 0.0, 1.0))
	# An anomalous sleeper splits its own dream and, when close to waking, the others too.
	material.set_shader_parameter(&"split", maxf(dream_profile.split, DreamProfile.leak_strength()))


# --- Chemical protocol (reality) -----------------------------------------------------------

func _build_alert() -> void:
	alert_label = Label.new()
	alert_label.name = "AlertLabel"
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.offset_left = -560.0
	alert_label.offset_right = 560.0
	alert_label.offset_top = 96.0
	alert_label.offset_bottom = 128.0
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadowed(alert_label, UiStyle.FONT_DISPLAY, 21, UiStyle.STATUS_WARN)
	alert_label.visible = false
	add_child(alert_label)
	_alert_timer = Timer.new()
	_alert_timer.one_shot = true
	_alert_timer.timeout.connect(func() -> void: alert_label.visible = false)
	add_child(_alert_timer)
	Containment.chemical_warning.connect(func(id: StringName, seconds: float) -> void:
		show_alert(ALERT_WARNING % [_module_label(id), _clock(seconds)]))
	Containment.module_sealed.connect(func(id: StringName) -> void:
		show_alert(ALERT_SEALED % [_module_label(id), _clock(Containment.chemical_timer(id))]))


## Amber line of the chemical protocol: the same system voice, slower and warmer.
func show_alert(text: String) -> void:
	alert_label.text = text
	alert_label.visible = true
	alert_label.modulate.a = 0.0
	create_tween().tween_property(alert_label, "modulate:a", 1.0, 1.2)
	_alert_timer.start(ALERT_SECONDS)


static func _module_label(id: StringName) -> String:
	return str((Containment.modules.get(id, {}) as Dictionary).get("label", id)).to_upper()


static func _clock(seconds: float) -> String:
	var total := maxi(int(ceil(seconds)), 0)
	return "%02d:%02d" % [total / 60, total % 60]


# --- Save indicator (issue #152) ------------------------------------------------------------

## Bottom right: the save icon with a mono line. Runs while the game is paused too.
func _build_save_indicator() -> void:
	save_indicator = HBoxContainer.new()
	save_indicator.name = "SaveIndicator"
	save_indicator.process_mode = Node.PROCESS_MODE_ALWAYS
	save_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_indicator.alignment = BoxContainer.ALIGNMENT_END
	save_indicator.add_theme_constant_override(&"separation", 10)
	save_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	save_indicator.offset_left = -460.0
	save_indicator.offset_right = -36.0
	save_indicator.offset_top = -36.0 - SAVE_ICON_SIZE
	save_indicator.offset_bottom = -36.0
	save_indicator.visible = false
	add_child(save_indicator)
	save_label = Label.new()
	save_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_label.size_flags_vertical = Control.SIZE_FILL
	_shadowed(save_label, UiStyle.FONT_MONO_MEDIUM, LABEL_SIZE, Color(UiStyle.TEXT, 0.8))
	save_indicator.add_child(save_label)
	save_icon = SaveIcon.new()
	save_icon.custom_minimum_size = Vector2(SAVE_ICON_SIZE, SAVE_ICON_SIZE)
	save_indicator.add_child(save_icon)


## Called through the `save_display` group after every successful save.
func show_saved(_slot: String) -> void:
	if _save_tween:
		_save_tween.kill()
	save_indicator.visible = true
	save_indicator.modulate.a = 1.0
	save_label.text = SAVE_WRITING
	save_icon.start()
	_save_tween = save_indicator.create_tween()
	_save_tween.tween_interval(SAVE_WRITE_SECONDS)
	_save_tween.tween_callback(func() -> void:
		save_icon.complete()
		save_label.text = SAVE_DONE)
	_save_tween.tween_interval(SAVE_HOLD_SECONDS)
	_save_tween.tween_property(save_indicator, "modulate:a", 0.0, SAVE_FADE_SECONDS)
	_save_tween.tween_callback(func() -> void: save_indicator.visible = false)
