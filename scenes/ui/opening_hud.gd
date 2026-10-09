class_name OpeningHud
extends CanvasLayer

## First-person HUD for the opening: crosshair, interaction prompt and current objective.
## The objective follows `GameState`; the prompt is driven by the player.

const OBJECTIVE_PREFIX := "ЦЕЛЬ: "

@onready var interact_label: Label = $InteractLabel
@onready var objective_label: Label = $ObjectiveLabel


func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	_on_objective_changed(GameState.objective_id, GameState.objective_text)


func _on_objective_changed(_objective_id: StringName, text: String) -> void:
	objective_label.text = OBJECTIVE_PREFIX + text if not text.is_empty() else ""
	objective_label.visible = not text.is_empty()
