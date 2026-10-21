class_name DreamStoneSocket
extends StaticBody3D

## A socket for a key stone of the forge (#234): takes the stone the hero carries with the
## interact key and holds it (`filled`). What a filled socket does is the scene's business —
## a sluice opens, or knocks the stone back out (`eject`: the stone rolls home).

signal filled(stone: DreamKeyStone)

const GROUP := &"dream_stone_sockets"
const PROMPT_PUT := "ВСТАВИТЬ КЛЮЧ-КАМЕНЬ"
const PROMPT_EMPTY := "ГНЕЗДО ДЛЯ КЛЮЧ-КАМНЯ"
const PROMPT_FULL := "КЛЮЧ-КАМЕНЬ НА МЕСТЕ"
const BASE_SIZE := Vector3(0.9, 1.0, 0.9)
const SLOT_HEIGHT := 1.18
const STONE_COLOR := Color(0.2, 0.17, 0.15)
const RIM_COLOR := Color(1.0, 0.6, 0.25)
const EJECT_SECONDS := 0.6

@export var socket_id: StringName = &"s1"

var stone: DreamKeyStone
var interactable: Interactable
var _slot: Node3D
var _rim: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	PropKit.box(self, Vector3(0, BASE_SIZE.y * 0.5, 0), BASE_SIZE, PropKit.material(STONE_COLOR), true)
	_rim = PropKit.material(RIM_COLOR, true)
	_rim.emission_energy_multiplier = 0.6
	PropKit.box(self, Vector3(0, BASE_SIZE.y + 0.01, 0), Vector3(DreamKeyStone.SIZE.x + 0.12, 0.02, DreamKeyStone.SIZE.z + 0.12), _rim)
	_slot = Node3D.new()
	_slot.name = "Slot"
	_slot.position = Vector3(0, SLOT_HEIGHT, 0)
	add_child(_slot)
	interactable = PropKit.interactable(self, Interactable.Mode.PRESS, PROMPT_PUT)
	interactable.interacted.connect(insert)
	refresh()


func is_filled() -> bool:
	return stone != null


## Takes the stone the hero holds.
func insert() -> bool:
	var held := DreamKeyStone.held_stone
	if held == null or stone != null:
		return false
	place(held)
	filled.emit(held)
	return true


## Puts `key` into the socket without the signal (a remembered state on load).
func place(key: DreamKeyStone) -> void:
	stone = key
	key.settle_in(self, _slot)
	_rim.emission_energy_multiplier = 2.5
	refresh()


## Knocks the stone out: it jumps up and rolls back to its place.
func eject() -> void:
	var key := stone
	stone = null
	_rim.emission_energy_multiplier = 0.6
	refresh()
	if key == null:
		return
	var tween := key.create_tween()
	tween.tween_property(key, "position", key.position + Vector3(0, 0.8, 0), EJECT_SECONDS * 0.5)
	tween.tween_callback(key.return_home)


func refresh() -> void:
	if interactable == null:
		return
	interactable.available = stone == null and DreamKeyStone.held_stone != null
	interactable.unavailable_prompt = PROMPT_FULL if stone else PROMPT_EMPTY
