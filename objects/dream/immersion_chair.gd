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
const HOOP_UP_Y := 2.05
const HOOP_DOWN_Y := 1.62
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
		_crystal.position.y = 2.45 + sin(_time * 1.3) * 0.04
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


# --- Placeholder geometry ----------------------------------------------------

func _build() -> void:
	for child in get_children():
		if child.has_meta(&"chair_generated"):
			child.free()
	var metal := _material(Color(0.3, 0.32, 0.34))
	var dark := _material(Color(0.16, 0.17, 0.18))
	_box(Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.7), dark, true)
	_box(Vector3(0, 0.55, 0), Vector3(0.62, 0.1, 0.62), metal, false)
	_box(Vector3(0, 1.05, -0.32), Vector3(0.62, 1.0, 0.1), metal, true)
	_box(Vector3(-0.36, 0.75, 0), Vector3(0.08, 0.06, 0.5), metal, false)
	_box(Vector3(0.36, 0.75, 0), Vector3(0.08, 0.06, 0.5), metal, false)
	_box(Vector3(0, 1.4, -0.48), Vector3(0.12, 2.8, 0.12), dark, true)
	_box(Vector3(0, 2.8, -0.2), Vector3(0.9, 0.1, 0.7), dark, false)
	_hoop = Node3D.new()
	_hoop.position = Vector3(0, HOOP_UP_Y, -0.05)
	_generated(_hoop)
	var hoop_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.11
	torus.outer_radius = 0.14
	torus.material = _material(Color(0.7, 0.72, 0.75))
	hoop_mesh.mesh = torus
	_hoop.add_child(hoop_mesh)
	_crystal = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.18, 0.3, 0.18)
	_crystal_material = _material(Color(0.6, 0.85, 1.0))
	_crystal_material.emission_enabled = true
	_crystal_material.emission = Color(0.5, 0.8, 1.0)
	_crystal_material.emission_energy_multiplier = 1.5
	prism.material = _crystal_material
	_crystal.mesh = prism
	_crystal.position = Vector3(0, 2.45, -0.15)
	_generated(_crystal)
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


func _box(position: Vector3, size: Vector3, material: Material, collide: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	_generated(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = position
		_generated(shape)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.4
	return material
