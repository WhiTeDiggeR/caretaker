class_name Interactable
extends Node

## Interaction component. Add it as a child of the physics body the player looks at;
## the owner script reacts to `interacted` and may change the prompt or availability.
##
## PRESS   — one press of the interact action.
## HOLD    — keep the action held for `hold_time` seconds while looking at the object.
## INSPECT — one press shows `inspect_title`/`inspect_text` in the message display.

signal interacted
signal hold_progress_changed(ratio: float)
signal hold_cancelled

enum Mode { PRESS, HOLD, INSPECT }

const META := &"interactable"
const DEFAULT_PROMPT := "ВЗАИМОДЕЙСТВОВАТЬ"

@export var mode: Mode = Mode.PRESS
@export var prompt := DEFAULT_PROMPT
@export var hold_time := 1.2
@export var available := true
## Shown without a key hint when the object is unavailable; empty hides the prompt.
@export var unavailable_prompt := ""
@export var one_shot := false
@export var inspect_title := ""
@export_multiline var inspect_text := ""
## Takes the inspect title and text from a DocumentLibrary entry (data/documents) instead.
@export var inspect_text_id := ""
## Story flag set in GameState when the object is used (e.g. a read diagnostic panel).
@export var sets_flag: StringName = &""

var used := false


func _enter_tree() -> void:
	get_parent().set_meta(META, self)


func _exit_tree() -> void:
	if get_parent().get_meta(META, null) == self:
		get_parent().remove_meta(META)


func is_available() -> bool:
	return available and not (one_shot and used)


## Prompt line for the HUD, or an empty string when nothing should be shown.
func get_prompt_text() -> String:
	if is_available():
		return InputPromptFormatter.format_action(&"interact", prompt)
	return unavailable_prompt


func get_inspect_title() -> String:
	if not inspect_text_id.is_empty():
		return str(DocumentLibrary.get_document(inspect_text_id).get("title", inspect_title))
	return inspect_title


func get_inspect_text() -> String:
	if not inspect_text_id.is_empty():
		return str(DocumentLibrary.get_document(inspect_text_id).get("body", inspect_text))
	return inspect_text


func trigger() -> void:
	if not is_available():
		return
	used = true
	if not sets_flag.is_empty():
		GameState.set_flag(sets_flag)
	interacted.emit()
