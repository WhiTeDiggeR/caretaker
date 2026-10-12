class_name DreamCombat
extends Node

## The hero's side of dream combat, attached to the player by DreamCombatSetup for the
## length of one dream scene: resolve («устойчивость», health of the mind in the dream),
## focus for ranged images and the weapons taken in this dream. Nothing here is saved or
## leaves the dream: the node goes away with the dream scene (canon: no matter crosses).
## At zero resolve the dream expels the hero (Dreams.die).

signal resolve_changed(value: float, maximum: float)
signal focus_changed(value: float, maximum: float)
signal weapon_added(id: StringName)
signal hurt(amount: float)
signal attacked(id: StringName)
signal expelled

const GROUP := &"dream_combat"
const ENEMY_GROUP := &"dream_enemies"
const BOLT_SPAWN := 0.6

var max_resolve := 100.0
var resolve := 100.0
var max_focus := 100.0
var focus := 100.0
var weapons: Array[StringName] = []
## Replaced in tests; called once when resolve reaches zero.
var expel: Callable = func() -> void: Dreams.die()

var _hero: Dictionary = {}
var _since_hit := INF
var _cooldowns: Dictionary[StringName, float] = {}
var _expelled := false


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


func take_damage(amount: float, from: Vector3) -> void:
	if _expelled or amount <= 0.0:
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
	if resolve <= 0.0:
		_expelled = true
		expelled.emit()
		expel.call()


## Uses a weapon now if it is ready. Returns true when the attack happened.
func attack(id: StringName) -> bool:
	var weapon := DreamCombatData.weapon(id)
	if _expelled or not weapons.has(id) or _cooldowns.get(id, 0.0) > 0.0:
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
