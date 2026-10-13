class_name DreamSeal
extends StaticBody3D

## Seal holding the prisoner asleep. Restoring it (hold) calms the dream and, with a
## `knowledge_id`, makes the hero remember its glyphs (DreamKnowledge). Puzzle seals
## (`DreamSealRings`) end in the same `complete()`.

const CRACKED := Color(0.9, 0.35, 0.1)
const RESTORED := Color(0.55, 0.85, 1.0)
const MESSAGE_GROUP := &"message_display"
const REMEMBERED_TITLE := "ПЕЧАТЬ ВОССТАНОВЛЕНА"
const REMEMBERED_TEXT := "Знаки на печати сложились: %s.\nЗапомните их — в реальности капсулу нужно ресинхронизировать. Запись появилась в журнале."

## Knowledge granted when the seal is restored (data/dreams/knowledge.json); empty for none.
@export var knowledge_id: StringName = &""

@onready var _interactable: Interactable = $Interactable
@onready var _glow: MeshInstance3D = $Glow

var _material: StandardMaterial3D


func _ready() -> void:
	_material = (_glow.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_glow.set_surface_override_material(0, _material)
	_interactable.interacted.connect(complete)
	_show(Dreams.in_dream and Dreams.seal_restored)


## Restores the seal: the visit's main task (`Dreams.restore_seal()`) and, the first time in
## the visit, the glyphs remembered (journal) with a message.
func complete() -> void:
	var first := Dreams.in_dream and not Dreams.seal_restored
	Dreams.restore_seal()
	_show(true)
	if first and not knowledge_id.is_empty():
		var code := DreamKnowledge.grant(knowledge_id)
		get_tree().call_group(MESSAGE_GROUP, "show_message", REMEMBERED_TITLE, REMEMBERED_TEXT % DreamKnowledge.SEPARATOR.join(code))


func _show(restored: bool) -> void:
	_interactable.available = not restored
	_interactable.unavailable_prompt = "ПЕЧАТЬ ВОССТАНОВЛЕНА" if restored else ""
	var color := RESTORED if restored else CRACKED
	_material.albedo_color = color
	_material.emission = color
