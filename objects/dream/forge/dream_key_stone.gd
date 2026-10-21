class_name DreamKeyStone
extends StaticBody3D

## A key stone of the forge (#234, docs/game_design/09-bowser-dream-v2.md §5.2): matter of the
## dream the hero may carry while he dreams; it never leaves the dream. Taken with the interact
## key in both hands, one at a time: the hero walks at CARRY_SPEED_SCALE and can neither strike
## nor dodge (DreamCombat.hands_busy). Interact on nothing puts it down in front of him, the
## strike throws it THROW_DISTANCE ahead; a throw into lava brings it back to its place. A
## socket (DreamStoneSocket) takes the carried stone with the interact key. A stone left on the
## floor stays there while the scene lives; a reload (death) puts loose stones back home — the
## forge restores the ones in sockets from its state.

signal taken
signal released
signal socketed(socket: DreamStoneSocket)

enum State { GROUND, HELD, SOCKETED }

const PLAYER_GROUP := &"player"
const GROUP := &"dream_key_stones"
const SOCKET_GROUP := &"dream_stone_sockets"
const STRIKE_ACTION := &"dream_attack"
const INTERACT_ACTION := &"interact"
const CARRY_HINT := &"dream_stone_carry"
const CARRY_SPEED_SCALE := 0.8
const THROW_DISTANCE := 2.0
const THROW_SECONDS := 0.45
const THROW_ARC := 0.8
const PUT_DISTANCE := 1.1
const FLOOR_PROBE := 3.0
const CARRY_OFFSET := Vector3(0.0, -0.42, -0.75)
const SIZE := Vector3(0.5, 0.36, 0.36)
const STONE_COLOR := Color(0.14, 0.11, 0.1)
const RUNE_COLOR := Color(1.0, 0.55, 0.2)
const PROMPT_TAKE := "ВЗЯТЬ КЛЮЧ-КАМЕНЬ"
const PROMPT_BUSY := "РУКИ ЗАНЯТЫ"

## The stone the hero holds now (one at a time), or null.
static var held_stone: DreamKeyStone

@export var stone_id: StringName = &"k1"

var state := State.GROUND
var socket: DreamStoneSocket
var interactable: Interactable

var _home_parent: Node
var _home: Transform3D
var _wait_release := false
var _tween: Tween


func _ready() -> void:
	_home_parent = get_parent()
	_home = transform
	_build()
	interactable = PropKit.interactable(self, Interactable.Mode.PRESS, PROMPT_TAKE)
	interactable.interacted.connect(take)
	interactable.unavailable_prompt = PROMPT_BUSY


func _notification(what: int) -> void:
	# The dream scene goes away with the stone in the hands (a death, the gate).
	if what == NOTIFICATION_PREDELETE and held_stone == self:
		held_stone = null


func is_held() -> bool:
	return state == State.HELD


## Into both hands of the hero (when they are free).
func take() -> bool:
	if state != State.GROUND or held_stone != null:
		return false
	var hero := _hero()
	if hero == null:
		return false
	var camera := hero.get_node_or_null(^"Camera3D") as Node3D
	_stop_tween()
	state = State.HELD
	collision_layer = 0
	reparent(camera if camera else hero, false)
	# After the move: leaving the tree on the way clears a held stone.
	held_stone = self
	position = CARRY_OFFSET
	rotation = Vector3.ZERO
	_wait_release = true
	_set_hands(true)
	Sfx.play(&"dream_chain_hit", self)
	Hints.request(CARRY_HINT)
	_refresh()
	taken.emit()
	return true


## Lays the held stone on the floor at `point` (global; the floor under it is looked for).
func put_down(point: Vector3) -> void:
	if state != State.HELD:
		return
	_leave_hands()
	var floor_point: Variant = _floor_under(point)
	if floor_point == null:
		return_home()
		return
	global_position = floor_point + Vector3.UP * SIZE.y * 0.5
	_land()


## Throws the held stone THROW_DISTANCE ahead of the hero; into lava it goes back home.
func throw() -> void:
	if state != State.HELD:
		return
	var hero := _hero()
	var forward := -hero.global_basis.z if hero else Vector3.FORWARD
	forward.y = 0.0
	var start := global_position
	_leave_hands()
	global_position = start
	var target := (hero.global_position if hero else start) + forward.normalized() * THROW_DISTANCE
	var floor_point: Variant = _floor_under(target)
	var landing: Vector3 = floor_point + Vector3.UP * SIZE.y * 0.5 if floor_point != null else target + Vector3.DOWN * 2.0
	_stop_tween()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(landing, t) + Vector3.UP * THROW_ARC * sin(PI * t), 0.0, 1.0, THROW_SECONDS)
	if floor_point == null:
		_tween.tween_callback(return_home)
	else:
		_tween.tween_callback(_land)


## Placed into `target` (the socket calls it): fixed there, no longer taken.
func settle_in(target: DreamStoneSocket, slot: Node3D) -> void:
	if state == State.HELD:
		_leave_hands()
	_stop_tween()
	state = State.SOCKETED
	socket = target
	reparent(slot, false)
	transform = Transform3D.IDENTITY
	collision_layer = 0
	_refresh()
	socketed.emit(target)


## Back where the dream keeps it (a throw into lava, a gate that knocked it out).
func return_home() -> void:
	if state == State.HELD:
		_leave_hands()
	_stop_tween()
	state = State.GROUND
	socket = null
	reparent(_home_parent, false)
	transform = _home
	collision_layer = 1
	_refresh()


func _physics_process(_delta: float) -> void:
	if state != State.HELD:
		return
	var interact := InputMap.has_action(INTERACT_ACTION) and Input.is_action_just_pressed(INTERACT_ACTION)
	if _wait_release:
		if InputMap.has_action(INTERACT_ACTION) and Input.is_action_pressed(INTERACT_ACTION):
			return
		_wait_release = false
	var hero := _hero()
	if hero == null:
		return
	if interact and _aimed_at_nothing(hero):
		var forward := -hero.global_basis.z
		forward.y = 0.0
		put_down(hero.global_position + forward.normalized() * PUT_DISTANCE)
	elif InputMap.has_action(STRIKE_ACTION) and Input.is_action_just_pressed(STRIKE_ACTION):
		throw()


func _aimed_at_nothing(hero: Node) -> bool:
	var interactor := hero.get_node_or_null(^"Interactor") as Interactor
	return interactor == null or interactor.target == null


func _leave_hands() -> void:
	state = State.GROUND
	if held_stone == self:
		held_stone = null
	_set_hands(false)
	reparent(_home_parent, true)
	rotation = Vector3.ZERO
	released.emit()


func _land() -> void:
	collision_layer = 1
	Sfx.play(&"dream_chain_hit", self)
	_refresh()


## Prompts of every stone and socket follow who holds what.
func _refresh() -> void:
	get_tree().call_group(GROUP, &"refresh_prompt")
	get_tree().call_group(SOCKET_GROUP, &"refresh")


func refresh_prompt() -> void:
	interactable.available = state == State.GROUND and held_stone == null
	interactable.unavailable_prompt = PROMPT_BUSY if state == State.GROUND else ""


func _set_hands(busy: bool) -> void:
	var hero := _hero()
	if hero == null:
		return
	hero.set(&"speed_scale", CARRY_SPEED_SCALE if busy else 1.0)
	for child in hero.get_children():
		if child is DreamCombat:
			(child as DreamCombat).hands_busy = busy


func _hero() -> Node3D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D if is_inside_tree() else null


## The floor point under `point` (global), or null over lava and the abyss.
func _floor_under(point: Vector3) -> Variant:
	var from := Vector3(point.x, point.y + FLOOR_PROBE * 0.5, point.z)
	var exclude: Array[RID] = [get_rid()]
	# The hero and the guards are not the floor: look past them.
	for _attempt in 4:
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE, 1, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return null
		if not hit.get("collider") is CharacterBody3D:
			return hit["position"]
		exclude.append(hit["rid"])
	return null


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


## A dark block with a glowing rune band and a collision box.
func _build() -> void:
	add_to_group(GROUP)
	PropKit.box(self, Vector3.ZERO, SIZE, PropKit.material(STONE_COLOR), true)
	var rune := PropKit.material(RUNE_COLOR, true)
	PropKit.box(self, Vector3(0, 0, SIZE.z * 0.5 + 0.005), Vector3(SIZE.x * 0.7, 0.05, 0.01), rune)
	PropKit.box(self, Vector3(0, 0, -SIZE.z * 0.5 - 0.005), Vector3(SIZE.x * 0.7, 0.05, 0.01), rune)
	PropKit.box(self, Vector3(0, SIZE.y * 0.5 + 0.005, 0), Vector3(0.05, 0.01, SIZE.z * 0.7), rune)
