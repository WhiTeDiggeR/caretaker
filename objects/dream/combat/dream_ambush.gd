class_name DreamAmbush
extends Node3D

## First fight of a dream (Bowser S, Р-3; docs/game_design/06-bowser-dream-world.md §5):
## guards wait in their niches until the hero crosses the wake line, then step out, «assemble»
## for a telegraph (1.5 s, they neither move nor strike) and chase. The hall threshold is a
## forbidden zone: guards stop at it and wait in the yard. Once the dream's seal is restored
## there are no guards. Number and type of the guards come from `ambushes` in
## data/dreams/combat.json. `ambush_started` is the cue for the weapon at the remains (Р-4).
##
## Children: `WakeLine` (Node3D; the hero crosses it moving along its -Z, within
## `wake_half_width` of it), `Niches` (Marker3D children, guards appear there in turn),
## `Threshold` (Node3D; a box of `threshold_size` around it is forbidden to the guards).

signal ambush_started

const GROUP := &"dream_ambushes"
const PLAYER_GROUP := &"player"
const ASSEMBLE_START_SCALE := 0.15
const VANISH_SECONDS := 0.4

@export var ambush_id: StringName = &"bowser_first_fight"
@export var wake_half_width := 9.0
@export var threshold_size := Vector3(4.0, 4.0, 4.0)

## True from the moment the guards step out; for listeners that connect late.
var started := false
var guards: Array[DreamEnemy] = []
var config: Dictionary = {}

var _hero: Node3D
@onready var _wake_line: Node3D = $WakeLine
@onready var _niches: Node3D = $Niches
@onready var _threshold: Node3D = $Threshold


func _ready() -> void:
	add_to_group(GROUP)
	config = ((DreamCombatData.all().get("ambushes", {}) as Dictionary).get(String(ambush_id), {}) as Dictionary)
	Dreams.seal_restored_signal.connect(_on_seal_restored)
	if Dreams.seal_restored:
		set_physics_process(false)


## Whether `point` (global) is inside the threshold the guards must not enter.
func in_threshold(point: Vector3) -> bool:
	var local := _threshold.to_local(point)
	var half := threshold_size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Whether `point` (global) is past the wake line.
func past_wake_line(point: Vector3) -> bool:
	var local := _wake_line.to_local(point)
	return local.z < 0.0 and absf(local.x) <= wake_half_width


func _physics_process(_delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
		if _hero == null:
			return
	if past_wake_line(_hero.global_position):
		start()


## Brings the guards out (once); the wake line calls it, tests and debug moments may too.
func start() -> void:
	if started or Dreams.seal_restored:
		return
	started = true
	set_physics_process(false)
	var niches := _niches.get_children()
	var count := int(config.get("count", 0))
	var assemble := float(config.get("assemble_seconds", 1.5))
	for i in count:
		if niches.is_empty():
			break
		var niche := niches[i % niches.size()] as Node3D
		guards.append(_spawn(niche, i, assemble))
	ambush_started.emit()


func _spawn(niche: Node3D, index: int, assemble: float) -> DreamEnemy:
	var guard := DreamEnemy.new()
	guard.name = "Guard%d" % (index + 1)
	guard.enemy_type = StringName(str(config.get("enemy", "shade")))
	guard.forbidden_zone = in_threshold
	add_child(guard)
	guard.global_transform = niche.global_transform
	guard.set_physics_process(false)
	guard.scale = Vector3.ONE * ASSEMBLE_START_SCALE
	var tween := guard.create_tween()
	tween.tween_property(guard, "scale", Vector3.ONE, assemble)
	tween.tween_callback(guard.set_physics_process.bind(true))
	return guard


func _on_seal_restored(_module_id: StringName) -> void:
	set_physics_process(false)
	for guard in guards:
		if is_instance_valid(guard) and not guard.is_dead():
			guard.vanish(VANISH_SECONDS)
	guards.clear()
