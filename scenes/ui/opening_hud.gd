class_name OpeningHud
extends CanvasLayer

## First-person HUD for the opening: crosshair, interaction prompt, hold progress,
## current objective and short inspect messages. `J` opens the journal of read documents. The objective follows `GameState`;
## the prompt and hold bar are driven by the player's `Interactor`.

const OBJECTIVE_PREFIX := "ЦЕЛЬ: "
const MESSAGE_SECONDS := 10.0
const MESSAGE_GROUP := &"message_display"

@onready var interact_label: Label = $InteractLabel
@onready var hold_progress: ProgressBar = $HoldProgress
@onready var objective_label: Label = $ObjectiveLabel
@onready var message_panel: PanelContainer = $MessagePanel
@onready var message_title: Label = $MessagePanel/Margin/Lines/Title
@onready var message_text: Label = $MessagePanel/Margin/Lines/Text
@onready var message_hint: Label = $MessagePanel/Margin/Lines/Hint
@onready var _message_timer: Timer = $MessageTimer


func _ready() -> void:
	add_to_group(MESSAGE_GROUP)
	GameState.objective_changed.connect(_on_objective_changed)
	_on_objective_changed(GameState.objective_id, GameState.objective_text)
	_message_timer.timeout.connect(hide_message)
	hide_message()


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
	objective_label.text = OBJECTIVE_PREFIX + text if not text.is_empty() else ""
	objective_label.visible = not text.is_empty()
