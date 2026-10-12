class_name OpeningHud
extends CanvasLayer

## First-person HUD for the opening: crosshair, interaction prompt, hold progress,
## current objective (flashes when it changes), one-time hints (Hints) and short inspect
## messages. `J` opens the journal of read documents and objectives. The objective follows
## `GameState`; the prompt and hold bar are driven by the player's `Interactor`.

const OBJECTIVE_PREFIX := "ЦЕЛЬ: "
const MESSAGE_SECONDS := 10.0
const MESSAGE_GROUP := &"message_display"
const HINT_GROUP := &"hint_display"
const OBJECTIVE_FLASH := Color(1.0, 0.9, 0.55)
const OBJECTIVE_FLASH_SECONDS := 1.2
const HINT_WIDTH := 900.0
const HINT_BOTTOM := 150.0

@onready var interact_label: Label = $InteractLabel
@onready var hold_progress: ProgressBar = $HoldProgress
@onready var objective_label: Label = $ObjectiveLabel
@onready var message_panel: PanelContainer = $MessagePanel
@onready var message_title: Label = $MessagePanel/Margin/Lines/Title
@onready var message_text: Label = $MessagePanel/Margin/Lines/Text
@onready var message_hint: Label = $MessagePanel/Margin/Lines/Hint
@onready var _message_timer: Timer = $MessageTimer

var hint_label: Label
var _hint_timer: Timer
var _objective_tween: Tween


func _ready() -> void:
	add_to_group(MESSAGE_GROUP)
	add_to_group(HINT_GROUP)
	_build_hint()
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
	hint_label.add_theme_font_size_override(&"font_size", 22)
	hint_label.add_theme_color_override(&"font_color", Color(0.92, 0.94, 0.9))
	hint_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override(&"outline_size", 6)
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
	objective_label.text = OBJECTIVE_PREFIX + text if not text.is_empty() else ""
	objective_label.visible = not text.is_empty()
