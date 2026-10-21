@tool
class_name ImmersionChair
extends StaticBody3D

## Immersion chair of a containment module (canon: a metal chair, a crystal floating in a
## technical device above it, a hoop lowered onto the head and another on the arm).
## Sitting down starts the dream of `module_id` through the `Dreams` autoload.

signal sequence_started

const GROUP := &"immersion_chairs"
const PROMPT := "ЗАНЯТЬ КРЕСЛО ПОГРУЖЕНИЯ"
const REASON_NO_POWER := "НЕТ ПИТАНИЯ"
const REASON_NO_ACCESS := "НЕТ ДОПУСКА"
const REASON_AWAKE := "ОБЪЕКТ НЕ СПИТ"
const REASON_IN_DREAM := "ИДЁТ ПОГРУЖЕНИЕ"
## Head hoop of the art model (P-016): hangs ready above the head, lowered onto it on sitting.
const HOOP_UP_Y := 1.62
const HOOP_DOWN_Y := 1.42
## The crystal floats around its rest height in the arch above the head.
const CRYSTAL_Y := 1.78
const CRYSTAL_BOB := 0.03
const MODEL := preload("res://loads/props/immersion_chair/immersion_chair.gltf")
const SEQUENCE_SECONDS := 1.2

@export var chair_id: StringName = &"chair"
@export var module_id: StringName = &"module_4"
@export_file("*.tscn") var dream_scene := ""
@export var section: StringName = &""
@export var required_access: StringName = &""
## Flag set by preparation (e.g. the post checklist); empty — no preparation needed.
@export var required_flag: StringName = &""
@export var required_flag_prompt := "ТРЕБУЕТСЯ ПОДГОТОВКА НА ПОСТУ КОНТРОЛЯ"

var interactable: Interactable
var _hoop: Node3D
var _crystal: MeshInstance3D
var _crystal_material: StandardMaterial3D
var _exit_point: Marker3D
var _time := 0.0


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	interactable.interacted.connect(sit_down)
	GameState.section_power_changed.connect(func(_s: StringName, _p: int) -> void: refresh())
	GameState.access_changed.connect(func(_a: StringName, _g: bool) -> void: refresh())
	GameState.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	Containment.stage_changed.connect(func(_id: StringName, _st: int) -> void: refresh())
	refresh()


func _process(delta: float) -> void:
	_time += delta
	if _crystal:
		_crystal.position.y = CRYSTAL_Y + sin(_time * 1.3) * CRYSTAL_BOB
		_crystal.rotation.y = _time * 0.6


func lock_reason() -> String:
	if not GameState.is_section_powered(section):
		return REASON_NO_POWER
	if not GameState.has_access(required_access):
		return REASON_NO_ACCESS
	if Containment.is_awake(module_id):
		return REASON_AWAKE
	if Dreams.in_dream:
		return REASON_IN_DREAM
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		return required_flag_prompt
	return ""


func refresh() -> void:
	if interactable == null or Engine.is_editor_hint():
		return
	var reason := lock_reason()
	interactable.available = reason.is_empty()
	interactable.unavailable_prompt = reason
	_crystal_material.emission_energy_multiplier = 1.5 if reason.is_empty() else 0.2


## Where the hero stands after returning from the dream: in front of the chair, facing out.
func exit_transform() -> Transform3D:
	return _exit_point.global_transform


func sit_down() -> void:
	if not lock_reason().is_empty():
		return
	sequence_started.emit()
	get_tree().call_group(&"player", "set_controls_locked", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_hoop, "position:y", HOOP_DOWN_Y, SEQUENCE_SECONDS)
	tween.tween_property(_crystal_material, "emission_energy_multiplier", 6.0, SEQUENCE_SECONDS)
	await tween.finished
	await Dreams.enter(module_id, chair_id, dream_scene)
	if is_inside_tree():
		_hoop.position.y = HOOP_UP_Y
		get_tree().call_group(&"player", "set_controls_locked", false)
		refresh()


# --- Art model -----------------------------------------------------------------

## Art model P-016 (loads/props/immersion_chair, #241): its Crystal glows and floats, Hoop1
## (the head hoop) is lowered on sitting; the arm hoop stays. Collision is one simple box.
func _build() -> void:
	for child in get_children():
		if child.has_meta(&"chair_generated"):
			child.free()
	var model := MODEL.instantiate() as Node3D
	_generated(model)
	_hoop = model.get_node(^"Hoop1") as Node3D
	_hoop.position.y = HOOP_UP_Y
	_crystal = model.get_node(^"Crystal") as MeshInstance3D
	_crystal_material = (_crystal.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_crystal_material.emission_enabled = true
	_crystal_material.emission_energy_multiplier = 1.5
	for surface in _crystal.mesh.get_surface_count():
		_crystal.set_surface_override_material(surface, _crystal_material)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.16, 1.095)
	shape.shape = box
	shape.position = Vector3(0, 1.08, -0.0275)
	_generated(shape)
	_exit_point = Marker3D.new()
	_exit_point.position = Vector3(0, 0.9, 1.0)
	_exit_point.rotation.y = PI  # the hero stands up facing away from the chair
	_generated(_exit_point)
	interactable = Interactable.new()
	interactable.prompt = PROMPT
	interactable.set_meta(&"chair_generated", true)
	add_child(interactable)


func _generated(node: Node) -> void:
	node.set_meta(&"chair_generated", true)
	add_child(node)
