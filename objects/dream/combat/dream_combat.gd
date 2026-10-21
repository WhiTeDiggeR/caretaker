class_name DreamCombat
extends Node

## The hero's side of dream combat, attached to the player by DreamCombatSetup for the
## length of one dream scene: resolve («устойчивость», health of the mind in the dream),
## focus for ranged images and the weapons taken in this dream. Nothing here is saved or
## leaves the dream: the node goes away with the dream scene (canon: no matter crosses).
## At zero resolve the dream expels the hero (Dreams.die).
## The dodge dash (B-14, #185): `dream_dash` throws the hero a short way along the movement
## (forward without input) with a short invulnerability and a cooldown (`hero.dash` in
## data/dreams/combat.json). It lives here, so it exists only in dream scenes with combat;
## in the complex the action does nothing.
## Busy hands (a key stone of the forge, #234) forbid the strike and the dash; a heavy blow can
## shove the hero a set distance (`shove`), which may carry him over an edge.

signal resolve_changed(value: float, maximum: float)
signal focus_changed(value: float, maximum: float)
signal weapon_added(id: StringName)
signal hurt(amount: float)
signal attacked(id: StringName)
signal expelled
signal dashed(direction: Vector3)
## A hit that fell into the dash's invulnerability.
signal dodged(amount: float)

const GROUP := &"dream_combat"
const ENEMY_GROUP := &"dream_enemies"
const BOLT_SPAWN := 0.6
const DASH_ACTION := &"dream_dash"
const SHOVE_SECONDS := 0.25

var max_resolve := 100.0
var resolve := 100.0
var max_focus := 100.0
var focus := 100.0
var weapons: Array[StringName] = []
## The hero carries something in both hands: no strike, no dash.
var hands_busy := false
## Replaced in tests; called once when resolve reaches zero.
var expel: Callable = func() -> void: Dreams.die()

var _hero: Dictionary = {}
var _since_hit := INF
var _cooldowns: Dictionary[StringName, float] = {}
var _expelled := false
var _dash_left := 0.0
var _dash_velocity := Vector3.ZERO
var _dash_cooldown := 0.0
var _invulnerable_left := 0.0
var _shove_left := 0.0
var _shove_velocity := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	_hero = DreamCombatData.hero()
	max_resolve = float(_hero.get("resolve", max_resolve))
	max_focus = float(_hero.get("focus", max_focus))
	resolve = max_resolve
	focus = max_focus


func player() -> CharacterBody3D:
	return get_parent() as CharacterBody3D


func give_weapon(id: StringName) -> bool:
	if weapons.has(id) or DreamCombatData.weapon(id).is_empty():
		return false
	weapons.append(id)
	weapon_added.emit(id)
	return true


## `shove_distance` > 0 throws the hero that far away from `from` (a heavy blow).
func take_damage(amount: float, from: Vector3, shove_distance: float = 0.0) -> void:
	if _expelled or amount <= 0.0:
		return
	if is_invulnerable():
		dodged.emit(amount)
		return
	resolve = maxf(resolve - amount, 0.0)
	_since_hit = 0.0
	resolve_changed.emit(resolve, max_resolve)
	hurt.emit(amount)
	var body := player()
	if body:
		var push := body.global_position - from
		push.y = 0.0
		if push.length_squared() > 0.0001:
			body.velocity += push.normalized() * float(_hero.get("hit_push", 4.0))
			if shove_distance > 0.0:
				shove(push, shove_distance)
	if resolve <= 0.0:
		_expelled = true
		expelled.emit()
		expel.call()


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_dashing() -> bool:
	return _dash_left > 0.0


## Seconds until the next dash is ready.
func dash_cooldown() -> float:
	return _dash_cooldown


## Dashes along `direction` (flattened; the hero's forward when zero) if the dash is ready.
## Returns true when the dash started.
func dash(direction: Vector3 = Vector3.ZERO) -> bool:
	var body := player()
	if _expelled or hands_busy or body == null or _dash_cooldown > 0.0 or body.get("controls_locked") == true:
		return false
	var config := _dash_config()
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -body.global_basis.z
		direction.y = 0.0
	var time := maxf(float(config.get("time", 0.18)), 0.01)
	_dash_left = time
	_dash_velocity = direction.normalized() * float(config.get("distance", 4.0)) / time
	_dash_cooldown = float(config.get("cooldown", 1.2))
	_invulnerable_left = float(config.get("invulnerable", 0.35))
	dashed.emit(direction.normalized())
	return true


## Uses a weapon now if it is ready. Returns true when the attack happened.
func attack(id: StringName) -> bool:
	var weapon := DreamCombatData.weapon(id)
	if _expelled or hands_busy or not weapons.has(id) or _cooldowns.get(id, 0.0) > 0.0:
		return false
	var cost := float(weapon.get("focus_cost", 0.0))
	if focus < cost:
		return false
	focus -= cost
	if cost > 0.0:
		focus_changed.emit(focus, max_focus)
	_cooldowns[id] = float(weapon.get("cooldown", 0.5))
	if str(weapon.get("kind", "melee")) == "ranged":
		_shoot(weapon)
	else:
		_strike(weapon)
	attacked.emit(id)
	return true


func _physics_process(delta: float) -> void:
	for id: StringName in _cooldowns:
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_dash_step(delta)
	_shove_step(delta)
	_since_hit += delta
	if resolve < max_resolve and _since_hit >= float(_hero.get("regen_delay", 5.0)):
		resolve = minf(resolve + float(_hero.get("regen_per_second", 4.0)) * delta, max_resolve)
		resolve_changed.emit(resolve, max_resolve)
	if focus < max_focus:
		focus = minf(focus + float(_hero.get("focus_per_second", 10.0)) * delta, max_focus)
		focus_changed.emit(focus, max_focus)
	var body := player()
	if body == null or body.get("controls_locked") == true:
		return
	for id in weapons:
		var action := StringName(str(DreamCombatData.weapon(id).get("action", "")))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			attack(id)
	if InputMap.has_action(DASH_ACTION) and Input.is_action_just_pressed(DASH_ACTION):
		dash(_input_direction())


func _dash_config() -> Dictionary:
	return _hero.get("dash", {})


## The dash moves the body itself, on top of the player's own movement; walls stop it.
func _dash_step(delta: float) -> void:
	if _dash_left <= 0.0:
		return
	var step := minf(delta, _dash_left)
	_dash_left -= step
	var body := player()
	if body and body.move_and_collide(_dash_velocity * step) != null:
		_dash_left = 0.0


## Moves the hero `distance` along `direction` (flattened) over `seconds`, whatever he does; walls
## stop it, an edge does not.
func shove(direction: Vector3, distance: float, seconds: float = SHOVE_SECONDS) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or distance <= 0.0:
		return
	seconds = maxf(seconds, 0.01)
	_shove_left = seconds
	_shove_velocity = direction.normalized() * distance / seconds


func _shove_step(delta: float) -> void:
	if _shove_left <= 0.0:
		return
	var step := minf(delta, _shove_left)
	_shove_left -= step
	var body := player()
	if body and body.move_and_collide(_shove_velocity * step) != null:
		_shove_left = 0.0


## The movement input in the hero's frame (the player reads the same actions).
func _input_direction() -> Vector3:
	var body := player()
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return body.global_basis * Vector3(input.x, 0, input.y) if body else Vector3.ZERO


## Melee: every enemy within range and the arc in front of the camera.
func _strike(weapon: Dictionary) -> void:
	var origin := _view()
	var forward := -origin.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach := float(weapon.get("range", 2.0))
	var half_arc := deg_to_rad(float(weapon.get("arc_degrees", 80.0))) * 0.5
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as DreamEnemy
		if enemy == null or enemy.is_dead():
			continue
		var to := enemy.global_position - origin.origin
		to.y = 0.0
		if to.length() > reach + DreamEnemy.RADIUS:
			continue
		if to.length() > 0.3 and forward.angle_to(to.normalized()) > half_arc:
			continue
		enemy.take_hit(float(weapon.get("damage", 0.0)), to.normalized() * float(weapon.get("knockback", 0.0)))


func _shoot(weapon: Dictionary) -> void:
	var origin := _view()
	var bolt := DreamBolt.new()
	bolt.direction = -origin.basis.z
	bolt.speed = float(weapon.get("speed", 18.0))
	bolt.damage = float(weapon.get("damage", 0.0))
	bolt.knockback = float(weapon.get("knockback", 0.0))
	bolt.lifetime = float(weapon.get("lifetime", 2.0))
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	scene.add_child(bolt)
	bolt.global_position = origin.origin - origin.basis.z * BOLT_SPAWN


## The camera transform (or the body's when the player has no camera).
func _view() -> Transform3D:
	var body := player()
	var camera := body.get_node_or_null(^"Camera3D") as Node3D if body else null
	if camera:
		return camera.global_transform
	return body.global_transform if body else Transform3D.IDENTITY
