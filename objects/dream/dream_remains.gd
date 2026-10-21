class_name DreamRemains
extends Node3D

## The remains by the first fight (Bowser S, Р-4; docs/game_design/06-bowser-dream-world.md §5,
## author's decision in #186): a hero of this world the master beat, his chain with a weight
## lying dormant beside him and the predecessor's note (a document, it joins the journal).
## When the ambush starts, at once: the chain flashes white, the brazier lights, a chain rings
## from the niche and the trace of the operator's death by the wake line glows white. Safety net:
## if the chain is not taken `echo_seconds` after the ambush, or the hero's resolve falls below
## `echo_resolve_ratio`, the hint `ECHO_HINT` is requested once. Texts live in data/documents
## (`inspect_text_id`) and data/hints. On the second visit (#234) the yard stays quiet and the
## remains answer the ambush of the forge instead (`listen_to`), with a hint of their own.

signal awakened
signal echoed

const ECHO_HINT := &"dream_remains_echo"
const RING_SOUND := &"dream_chain_ring"
const INSPECT_PROMPT := "ОСМОТРЕТЬ ОСТАНКИ"
const BRAZIER_COLOR := Color(1.0, 0.62, 0.3)
const BRAZIER_ENERGY := 3.0
const BRAZIER_RANGE := 7.0
const BRAZIER_LIGHT_SECONDS := 0.6
const TRACE_COLOR := Color(1.0, 1.0, 1.0)
const TRACE_ENERGY := 2.5

@export var weapon_id: StringName = &"dream_chain"
@export var inspect_text_id := "bowser_hero_remains"
@export var echo_hint: StringName = ECHO_HINT
@export var echo_seconds := 15.0
@export_range(0.0, 1.0) var echo_resolve_ratio := 0.5
@export var ambush: NodePath = ^"../Ambush"
@export var body: NodePath = ^"Body"
@export var weapon_spot: NodePath = ^"WeaponSpot"
@export var brazier: NodePath = ^"Brazier"
@export var death_trace: NodePath = ^"../Ambush/OperatorTrace"

var pickup: DreamWeaponPickup
var is_awake := false
var weapon_taken := false
var echo_shown := false
var brazier_light: OmniLight3D

var _ambush: DreamAmbush
var _echo_timer: Timer
@onready var _weapon_spot: Node3D = get_node(weapon_spot)
@onready var _trace: GeometryInstance3D = get_node_or_null(death_trace) as GeometryInstance3D


func _ready() -> void:
	_make_inspectable(get_node(body) as Node3D)
	pickup = DreamWeaponPickup.new()
	pickup.name = "Chain"
	pickup.weapon_id = weapon_id
	pickup.dormant = true
	_weapon_spot.add_child(pickup)
	pickup.taken.connect(_on_taken)
	brazier_light = OmniLight3D.new()
	brazier_light.name = "Fire"
	brazier_light.light_color = BRAZIER_COLOR
	brazier_light.omni_range = BRAZIER_RANGE
	brazier_light.light_energy = 0.0
	brazier_light.position = Vector3(0, 0.8, 0)
	brazier_light.visible = false
	(get_node(brazier) as Node3D).add_child(brazier_light)
	_echo_timer = Timer.new()
	_echo_timer.one_shot = true
	_echo_timer.timeout.connect(_echo)
	add_child(_echo_timer)
	listen_to(get_node_or_null(ambush) as DreamAmbush)


## The ambush whose start wakes the chain (the yard's by default); replaces the previous one.
func listen_to(source: DreamAmbush) -> void:
	if _ambush and _ambush.ambush_started.is_connected(awaken):
		_ambush.ambush_started.disconnect(awaken)
	_ambush = source
	if _ambush:
		_ambush.ambush_started.connect(awaken)
		if _ambush.started:
			awaken.call_deferred()


## The dream remembers the old fight; the ambush calls it, tests may too.
func awaken() -> void:
	if is_awake:
		return
	is_awake = true
	if is_instance_valid(pickup):
		pickup.awaken()
	brazier_light.visible = true
	create_tween().tween_property(brazier_light, "light_energy", BRAZIER_ENERGY, BRAZIER_LIGHT_SECONDS)
	Sfx.play(RING_SOUND, _weapon_spot)
	if _trace:
		_trace.material_override = _awake_trace_material()
	if not weapon_taken:
		_echo_timer.start(echo_seconds)
		var combat := get_tree().get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
		if combat:
			combat.resolve_changed.connect(_on_resolve_changed)
	awakened.emit()


func _on_resolve_changed(value: float, maximum: float) -> void:
	if maximum > 0.0 and value < maximum * echo_resolve_ratio:
		_echo()


func _echo() -> void:
	if echo_shown or weapon_taken:
		return
	echo_shown = true
	Hints.request(echo_hint)
	echoed.emit()


func _on_taken() -> void:
	weapon_taken = true
	_echo_timer.stop()


## The trace keeps its dim flicker (its own shader), only brighter; plain white otherwise.
func _awake_trace_material() -> Material:
	var mesh := _trace as MeshInstance3D
	var base := mesh.get_active_material(0) if mesh and mesh.mesh else null
	if base is ShaderMaterial:
		var flicker := base.duplicate() as ShaderMaterial
		flicker.set_shader_parameter(&"glow_energy", TRACE_ENERGY)
		return flicker
	var glow := PropKit.material(TRACE_COLOR, true)
	glow.emission_energy_multiplier = TRACE_ENERGY
	return glow


## A body to look at (the remains are a plain mesh in the scene) with the inspect text.
func _make_inspectable(mesh: Node3D) -> void:
	var holder := StaticBody3D.new()
	holder.name = "Inspect"
	mesh.add_child(holder)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var visual := mesh as MeshInstance3D
	box.size = visual.get_aabb().size if visual and visual.mesh else Vector3.ONE * 0.5
	shape.shape = box
	holder.add_child(shape)
	var inspect := PropKit.interactable(holder, Interactable.Mode.INSPECT, INSPECT_PROMPT, inspect_text_id)
	inspect.name = "Interactable"
