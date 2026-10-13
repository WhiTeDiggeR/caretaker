class_name DreamGate
extends Area3D

## Arch gate out of the dream (canon: the silhouette stays recognisable in every dream).
## Walking through it returns the hero to the chair. With `requires_seal` the arch stays dark
## and lets nobody through until the visit's seal is restored (Bowser's dream, #190).

const PLAYER_GROUP := &"player"

## Opens only after `Dreams.seal_restored`; off keeps the gate always open (test dream).
@export var requires_seal := false

@onready var _portal: Node3D = get_node_or_null(^"Portal")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if requires_seal:
		Dreams.seal_restored_signal.connect(func(_id: StringName) -> void: _refresh())
	_refresh()


func is_open() -> bool:
	return not requires_seal or (Dreams.in_dream and Dreams.seal_restored)


func _refresh() -> void:
	if _portal:
		_portal.visible = is_open()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP) and is_open():
		Dreams.exit_through_gate()
