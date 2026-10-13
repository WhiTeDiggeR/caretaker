class_name DreamWeaponPickup
extends StaticBody3D

## An image of a weapon made by the dream: a floating crystal the hero takes with the
## interact key. It lasts for this dream only (DreamCombat goes away with the scene).
## The crystal takes the sleeper's colours (#164): melee images glow, ranged ones are text-coloured.
## A dormant pickup (#186) is a dark chain lying on the floor, without glow or spin, until
## `awaken()` makes it flash white. A weapon's `hint` (data/hints) is requested once it is taken.

signal taken

const SPIN_SPEED := 1.2
const DORMANT_COLOR := Color(0.16, 0.15, 0.15)
const AWAKE_COLOR := Color(1.0, 1.0, 1.0)
const FLASH_ENERGY := 4.0
const AWAKE_ENERGY := 1.2
const FLASH_SECONDS := 0.8
const LINK_SIZE := Vector3(0.14, 0.05, 0.08)
const LINK_COUNT := 6

@export var weapon_id: StringName = &"dream_blade"
## Lies dark on the floor until awakened; the prompt does not call it a weapon.
@export var dormant := false

var interactable: Interactable
var awake := false
var _crystal: Node3D
var _chain_material: StandardMaterial3D


func _ready() -> void:
	var weapon := DreamCombatData.weapon(weapon_id)
	var title := str(weapon.get("title", weapon_id)).to_upper()
	if dormant:
		_build_chain()
		interactable = PropKit.interactable(self, Interactable.Mode.PRESS, "ВЗЯТЬ: %s" % title)
		set_process(false)
	else:
		_build_crystal(str(weapon.get("kind", "melee")))
		interactable = PropKit.interactable(self, Interactable.Mode.PRESS, "ВЗЯТЬ ОБРАЗ: %s" % title)
	interactable.interacted.connect(take)


static func crystal_color(kind: String, profile: DreamProfile) -> Color:
	return profile.text if kind == "ranged" else profile.glow


func _process(delta: float) -> void:
	_crystal.rotate_y(SPIN_SPEED * delta)


## The dream remembers the chain: it flashes white and keeps a faint glow (dormant pickups only).
func awaken() -> void:
	if not dormant or awake or _chain_material == null:
		return
	awake = true
	_chain_material.albedo_color = AWAKE_COLOR
	_chain_material.emission_enabled = true
	_chain_material.emission = AWAKE_COLOR
	_chain_material.emission_energy_multiplier = FLASH_ENERGY
	create_tween().tween_property(_chain_material, "emission_energy_multiplier", AWAKE_ENERGY, FLASH_SECONDS)


func take() -> void:
	var combat := get_tree().get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	if combat and combat.give_weapon(weapon_id):
		var hint := str(DreamCombatData.weapon(weapon_id).get("hint", ""))
		if not hint.is_empty():
			Hints.request(StringName(hint))
		taken.emit()
		queue_free()


func _build_crystal(kind: String) -> void:
	var color := crystal_color(kind, DreamProfile.current())
	_crystal = Node3D.new()
	_crystal.position = Vector3(0, 1.2, 0)
	add_child(_crystal)
	PropKit.box(_crystal, Vector3.ZERO, Vector3(0.25, 0.6, 0.25), PropKit.material(color, true), false, Vector3(0, 0, deg_to_rad(45)))
	PropKit.box(self, Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), PropKit.material(Color(0.2, 0.15, 0.15)), true)
	PropKit.box(self, Vector3(0, 1.2, 0), Vector3(0.6, 0.8, 0.6), null, true).visible = false


## A run of links ending in a weight, flat on the floor; one shared material so it flashes as one.
func _build_chain() -> void:
	_chain_material = PropKit.material(DORMANT_COLOR)
	for i in LINK_COUNT:
		var turn := Vector3(0, deg_to_rad(15.0 * (i % 2)), deg_to_rad(90.0 * (i % 2)))
		PropKit.box(self, Vector3(-0.35 + i * 0.12, LINK_SIZE.y * 0.5, 0.02 * (i % 3)), LINK_SIZE, _chain_material, false, turn)
	PropKit.box(self, Vector3(0.42, 0.09, 0.03), Vector3(0.18, 0.18, 0.18), _chain_material)
	# Low invisible box the interaction ray hits.
	PropKit.box(self, Vector3(0.05, 0.15, 0.0), Vector3(1.0, 0.3, 0.4), null, true).visible = false
