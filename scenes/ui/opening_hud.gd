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


func _ready() -> void:
	add_to_group(MESSAGE_GROUP)
	add_to_group(HINT_GROUP)
	_build_hint()
	_apply_style()
	_journal_size = DocumentLibrary.read_ids().size()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(func() -> void: _journal_size = DocumentLibrary.read_ids().size())
	_toast_timer.timeout.connect(func() -> void: journal_toast.visible = false)
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
