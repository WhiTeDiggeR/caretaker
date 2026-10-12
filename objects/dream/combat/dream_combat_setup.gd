class_name DreamCombatSetup
extends Node

## Put into a dream scene where combat happens: gives the hero a DreamCombat for this dream
## and shows its HUD. Dreams without it (or with fewer fights, like Herobrine's) stay calm.

@export var starting_weapons: Array[StringName] = []

var combat: DreamCombat
var hud: DreamCombatHud


func _ready() -> void:
	_attach.call_deferred()


func _attach() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not get_parent().is_ancestor_of(player):
		return
	combat = DreamCombat.new()
	combat.name = "DreamCombat"
	player.add_child(combat)
	for id in starting_weapons:
		combat.give_weapon(id)
	hud = DreamCombatHud.new()
	add_child(hud)
	hud.bind(combat)
