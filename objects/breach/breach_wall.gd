@tool
class_name BreachWall
extends StaticBody3D

## A wall cracked by a fallen load (#178): a crack the player notices, then breaks open with a
## tool. States: CRACK — the plug in the opening blocks the way, inspecting it tells that the
## hands are not enough; with the tool flag the plug is broken by holding the interact action,
## one hit per hold, `hits_required` hits in all; OPEN — a hole one can walk through.
## The state lives in GameState flags (`flag`, and the hits done in `<flag>_hits`), so it is
## saved and loaded with the playthrough. The room behind the wall has its own light that turns
## on with the power of `section`; while the crack is closed it glows through the crack.
## Local frame: the wall runs along X, the player's side (relay room) is +Z, the room is -Z;
## the origin is on the floor at the centre of the opening.

signal hit(hits_done: int)
signal broken

const PROMPT_INSPECT := "ОСМОТРЕТЬ ТРЕЩИНУ"
const PROMPT_BREAK := "ВЫЛОМАТЬ ЛОМОМ"
## Inspect texts (data/documents/opening.json): dark and lit room behind the crack.
const TEXT_DARK := "relay_crack_dark"
const TEXT_LIT := "relay_crack_lit"
const WALL_COLOR := Color(0.36, 0.36, 0.34)
const PLUG_COLOR := Color(0.4, 0.39, 0.36)
const CRACK_DARK := Color(0.03, 0.03, 0.03)
const CRACK_LIT := Color(1.0, 0.82, 0.55)
const DEBRIS_COLOR := Color(0.33, 0.32, 0.3)
const ROOM_LIGHT_COLOR := Color(1.0, 0.86, 0.66)
const ROOM_LIGHT_ENERGY := 1.6
const ROOM_LIGHT_RANGE := 6.0
const LEAK_LIGHT_ENERGY := 0.5
const LEAK_LIGHT_RANGE := 2.5
## Each hit widens the crack by this share of its size.
const CRACK_GROWTH := 0.35
const SHAKE_OFFSET := 0.025
const SHAKE_TIME := 0.18
const DUST_AMOUNT := 40

## Story flag set when the wall is broken open.
@export var flag: StringName = &"opening/senior_breach_open"
## The tool the player must carry (an item flag, e.g. the crowbar pickup).
@export var tool_flag: StringName = &"item_crowbar"
@export var hits_required := 3
## Hold time of one hit.
@export var hit_time := 0.9
## Power section of the room behind the wall and the power level that lights it.
@export var section: StringName = &""
@export_enum("Выкл.", "Аварийное", "Основное") var light_power := 2
@export var width := 4.0
@export var height := 3.0
@export var thickness := 0.25
@export var opening_width := 1.0
@export var opening_height := 1.9
@export var hit_sound: StringName = &"door_stop"
@export var break_sound: StringName = &"land"

var interactable: Interactable
var room_light: OmniLight3D
var _plug: StaticBody3D
var _crack: Node3D
var _crack_material: StandardMaterial3D
var _leak_light: OmniLight3D
var _rubble: Node3D
var _dust: CPUParticles3D
var _shake: Tween


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	interactable = PropKit.interactable(_plug, Interactable.Mode.INSPECT, PROMPT_INSPECT)
	interactable.hold_time = hit_time
	interactable.interacted.connect(_on_interacted)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.section_power_changed.connect(_on_section_power_changed)
	GameState.state_loaded.connect(_refresh)
	_refresh()


func hits_flag() -> StringName:
	return StringName(String(flag) + "_hits")


func is_open() -> bool:
	return GameState.has_flag(flag)


func hits_done() -> int:
	return int(GameState.get_flag(hits_flag(), 0))


func has_tool() -> bool:
	return tool_flag.is_empty() or GameState.has_flag(tool_flag)


func is_lit() -> bool:
	return GameState.get_section_power(section) >= light_power


## One hit with the tool; the last one breaks the wall open. Returns false without the tool.
func strike() -> bool:
	if is_open() or not has_tool():
		return false
	var hits := hits_done() + 1
	GameState.set_flag(hits_flag(), hits)
	_play(hit_sound)
	_burst_dust()
	_shake_plug()
	hit.emit(hits)
	if hits >= hits_required:
		_play(break_sound)
		GameState.set_flag(flag)
		broken.emit()
	return true


func _on_interacted() -> void:
	if interactable.mode == Interactable.Mode.HOLD:
		strike()


func _on_flag_changed(changed: StringName, _value: Variant) -> void:
	if changed == flag or changed == tool_flag or changed == hits_flag():
		_refresh()


func _on_section_power_changed(changed: StringName, _power: int) -> void:
	if changed == section:
		_refresh()


func _refresh() -> void:
	var open := is_open()
	var lit := is_lit()
	_plug.visible = not open
	_plug.collision_layer = 0 if open else 1
	_rubble.visible = open
	room_light.visible = lit
	_leak_light.visible = lit and not open
	_crack_material.albedo_color = CRACK_LIT if lit else CRACK_DARK
	_crack_material.emission_enabled = lit
	var growth := 1.0 + CRACK_GROWTH * mini(hits_done(), hits_required)
	_crack.scale = Vector3(growth, growth, 1.0)
	interactable.available = not open
	interactable.unavailable_prompt = ""
	if has_tool():
		interactable.mode = Interactable.Mode.HOLD
		interactable.prompt = PROMPT_BREAK
	else:
		interactable.mode = Interactable.Mode.INSPECT
		interactable.prompt = PROMPT_INSPECT
		interactable.inspect_text_id = TEXT_LIT if lit else TEXT_DARK


func _play(id: StringName) -> void:
	if not id.is_empty():
		Sfx.play(id, _plug)


func _burst_dust() -> void:
	_dust.restart()
	_dust.emitting = true


func _shake_plug() -> void:
	if _shake:
		_shake.kill()
	_plug.position = Vector3(0, 0, SHAKE_OFFSET)
	_shake = create_tween()
	_shake.tween_property(_plug, "position", Vector3.ZERO, SHAKE_TIME)


func _build() -> void:
	var wall := PropKit.material(WALL_COLOR)
	var side_width := (width - opening_width) * 0.5
	var side_x := (opening_width + side_width) * 0.5
	for side: float in [-1.0, 1.0]:
		PropKit.box(self, Vector3(side * side_x, height * 0.5, 0), Vector3(side_width, height, thickness), wall, true)
	var lintel := height - opening_height
	PropKit.box(self, Vector3(0, opening_height + lintel * 0.5, 0), Vector3(opening_width, lintel, thickness), wall, true)
	# Jagged rim of the opening, seen once the plug is gone.
	var rim := PropKit.material(DEBRIS_COLOR)
	PropKit.box(self, Vector3(-opening_width * 0.42, opening_height - 0.08, 0), Vector3(0.22, 0.2, thickness + 0.02), rim, false, Vector3(0, 0, 0.5))
	PropKit.box(self, Vector3(opening_width * 0.45, opening_height * 0.6, 0), Vector3(0.14, 0.4, thickness + 0.02), rim, false, Vector3(0, 0, -0.3))

	_plug = StaticBody3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	PropKit.box(_plug, Vector3(0, opening_height * 0.5, 0), Vector3(opening_width, opening_height, thickness), PropKit.material(PLUG_COLOR), true)
	_crack = Node3D.new()
	_crack.name = "Crack"
	_crack.position = Vector3(0, opening_height * 0.55, 0)
	_plug.add_child(_crack)
	_crack_material = PropKit.material(CRACK_DARK)
	_crack_material.emission = CRACK_LIT
	_crack_material.emission_energy_multiplier = 3.0
	# A zigzag slit through the whole plug, visible from both sides.
	var depth := thickness + 0.02
	PropKit.box(_crack, Vector3(-0.08, 0.32, 0), Vector3(0.04, 0.42, depth), _crack_material, false, Vector3(0, 0, 0.35))
	PropKit.box(_crack, Vector3(0.02, 0.0, 0), Vector3(0.12, 0.34, depth), _crack_material, false, Vector3(0, 0, -0.25))
	PropKit.box(_crack, Vector3(0.1, -0.32, 0), Vector3(0.05, 0.4, depth), _crack_material, false, Vector3(0, 0, 0.3))

	room_light = OmniLight3D.new()
	room_light.name = "RoomLight"
	room_light.position = Vector3(0, height - 0.4, -ROOM_LIGHT_RANGE * 0.4)
	room_light.light_color = ROOM_LIGHT_COLOR
	room_light.light_energy = ROOM_LIGHT_ENERGY
	room_light.omni_range = ROOM_LIGHT_RANGE
	# Shadows keep the room light from shining through the wall into the relay room.
	room_light.shadow_enabled = true
	room_light.visible = false
	add_child(room_light)
	_leak_light = OmniLight3D.new()
	_leak_light.name = "LeakLight"
	_leak_light.position = Vector3(0, opening_height * 0.55, thickness * 0.5 + 0.3)
	_leak_light.light_color = CRACK_LIT
	_leak_light.light_energy = LEAK_LIGHT_ENERGY
	_leak_light.omni_range = LEAK_LIGHT_RANGE
	_leak_light.visible = false
	add_child(_leak_light)

	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	_rubble.visible = false
	add_child(_rubble)
	var debris := PropKit.material(DEBRIS_COLOR)
	var pieces: Array[Vector3] = [Vector3(-0.3, 0.06, 0.45), Vector3(0.25, 0.05, 0.6), Vector3(0.05, 0.08, -0.5), Vector3(-0.4, 0.05, -0.7), Vector3(0.45, 0.04, -0.35)]
	for index in pieces.size():
		var size := Vector3(0.22, 0.12, 0.18) * (1.0 - 0.12 * index)
		PropKit.box(_rubble, pieces[index], size, debris, false, Vector3(0, 0.6 * index, 0.2))

	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.position = Vector3(0, opening_height * 0.55, thickness * 0.5 + 0.05)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = 1.2
	_dust.explosiveness = 0.9
	_dust.direction = Vector3(0, 0, 1)
	_dust.spread = 50.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, -2.0, 0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(opening_width * 0.4, opening_height * 0.3, 0.02)
	var grain := BoxMesh.new()
	grain.size = Vector3(0.03, 0.03, 0.03)
	grain.material = PropKit.material(Color(0.55, 0.53, 0.5))
	_dust.mesh = grain
	add_child(_dust)
