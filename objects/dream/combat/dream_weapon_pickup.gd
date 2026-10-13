class_name DreamWeaponPickup
extends StaticBody3D

## An image of a weapon made by the dream: a floating crystal the hero takes with the
## interact key. It lasts for this dream only (DreamCombat goes away with the scene).
## The crystal takes the sleeper's colours (#164): melee images glow, ranged ones are text-coloured.

const SPIN_SPEED := 1.2

@export var weapon_id: StringName = &"dream_blade"

var interactable: Interactable
var _crystal: Node3D


func _ready() -> void:
	var weapon := DreamCombatData.weapon(weapon_id)
	var color := crystal_color(str(weapon.get("kind", "melee")), DreamProfile.current())
	_crystal = Node3D.new()
	_crystal.position = Vector3(0, 1.2, 0)
	add_child(_crystal)
	PropKit.box(_crystal, Vector3.ZERO, Vector3(0.25, 0.6, 0.25), PropKit.material(color, true), false, Vector3(0, 0, deg_to_rad(45)))
	PropKit.box(self, Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), PropKit.material(Color(0.2, 0.15, 0.15)), true)
	PropKit.box(self, Vector3(0, 1.2, 0), Vector3(0.6, 0.8, 0.6), null, true).visible = false
	interactable = PropKit.interactable(self, Interactable.Mode.PRESS, "ВЗЯТЬ ОБРАЗ: %s" % str(weapon.get("title", weapon_id)).to_upper())
	interactable.interacted.connect(take)


static func crystal_color(kind: String, profile: DreamProfile) -> Color:
	return profile.text if kind == "ranged" else profile.glow


func _process(delta: float) -> void:
	_crystal.rotate_y(SPIN_SPEED * delta)


func take() -> void:
	var combat := get_tree().get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	if combat and combat.give_weapon(weapon_id):
		queue_free()
