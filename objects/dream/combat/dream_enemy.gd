class_name DreamEnemy
extends CharacterBody3D

## Projection of the sleeper's unrest (a guard of the dream): patrols around its post,
## chases the hero it can see, never walks off an edge, attacks after a visible wind-up and
## is staggered by hits. Parameters by `enemy_type` from data/dreams/combat.json.

signal died

enum State { PATROL, CHASE, WINDUP, STAGGER, DEAD }

const GROUP := &"dream_enemies"
const PLAYER_GROUP := &"player"
const RADIUS := 0.35
const HEIGHT := 1.8
const EYE_HEIGHT := 0.6  # above the body centre
const EDGE_PROBE := 0.7
const EDGE_DROP := 1.5
const LOSE_SIGHT_SECONDS := 3.0
const PATROL_PAUSE := 2.5
const DEATH_SECONDS := 0.5
const BODY_COLOR := Color(0.12, 0.08, 0.16)
const EYE_COLOR := Color(1.0, 0.45, 0.1)
const WINDUP_COLOR := Color(1.0, 0.95, 0.6)

@export var enemy_type: StringName = &"shade"
## Optional `func(point: Vector3) -> bool`: ground the shade must not step on (a hall threshold
## of an ambush, DreamAmbush); it stops at the border as at an edge.
var forbidden_zone: Callable = Callable()

var state := State.PATROL
var health := 1.0
var config: Dictionary = {}

var _home := Vector3.ZERO
var _patrol_point := Vector3.ZERO
var _timer := 0.0
var _cooldown := 0.0
var _unseen := 0.0
var _rng := RandomNumberGenerator.new()
var _eye_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	config = DreamCombatData.enemy(enemy_type)
	health = float(config.get("health", 60.0))
	_rng.seed = hash(String(name))
	_home = global_position
	_patrol_point = _home
	_build()


func is_dead() -> bool:
	return state == State.DEAD


func take_hit(damage: float, push: Vector3) -> void:
	if is_dead():
		return
	health -= damage
	if health <= 0.0:
		_die()
		return
	state = State.STAGGER
	_timer = float(config.get("stagger", 0.35))
	velocity.x = push.x
	velocity.z = push.z
	_set_eyes(EYE_COLOR)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var hero := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	var sees := hero != null and _can_see(hero)
	match state:
		State.PATROL:
			if sees:
				state = State.CHASE
			else:
				_patrol(delta)
		State.CHASE:
			_unseen = 0.0 if sees else _unseen + delta
			if hero == null or _unseen > LOSE_SIGHT_SECONDS:
				state = State.PATROL
				_patrol_point = _home
			elif _flat_distance(hero) <= float(config.get("attack_range", 1.6)) and _cooldown <= 0.0:
				state = State.WINDUP
				_timer = float(config.get("windup", 0.45))
				_set_eyes(WINDUP_COLOR)
				_stop()
			else:
				_walk_to(hero.global_position, float(config.get("chase_speed", 4.0)))
		State.WINDUP:
			_stop()
			_timer -= delta
			if _timer <= 0.0:
				_strike(hero)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
	move_and_slide()


func _strike(hero: Node3D) -> void:
	_set_eyes(EYE_COLOR)
	_cooldown = float(config.get("attack_cooldown", 1.2))
	state = State.CHASE
	if hero == null or _flat_distance(hero) > float(config.get("attack_range", 1.6)) + 0.3:
		return
	var combat := _combat_of(hero)
	if combat:
		combat.take_damage(float(config.get("damage", 15.0)), global_position)


func _patrol(delta: float) -> void:
	var to := _patrol_point - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_stop()
		_timer -= delta
		if _timer <= 0.0:
			_timer = PATROL_PAUSE
			var radius := float(config.get("patrol_radius", 4.0))
			var angle := _rng.randf() * TAU
			_patrol_point = _home + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(radius * 0.4, radius)
		return
	_walk_to(_patrol_point, float(config.get("patrol_speed", 1.6)))


## Steers towards `target` on the ground plane; stops at edges instead of falling.
func _walk_to(target: Vector3, speed: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		_stop()
		return
	var direction := to.normalized()
	look_at(global_position + direction, Vector3.UP)
	if not _ground_ahead(direction) or _forbidden_ahead(direction):
		_stop()
		return
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _forbidden_ahead(direction: Vector3) -> bool:
	return forbidden_zone.is_valid() and bool(forbidden_zone.call(global_position + direction * (RADIUS + EDGE_PROBE)))


func _ground_ahead(direction: Vector3) -> bool:
	var from := global_position + direction * (RADIUS + EDGE_PROBE)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (HEIGHT * 0.5 + EDGE_DROP), collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _can_see(hero: Node3D) -> bool:
	if _flat_distance(hero) > float(config.get("sight", 14.0)):
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := hero.global_position + Vector3.UP * EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(eye, target, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == hero


func _flat_distance(node: Node3D) -> float:
	var to := node.global_position - global_position
	to.y = 0.0
	return to.length()


func _combat_of(hero: Node) -> DreamCombat:
	for child in hero.get_children():
		if child is DreamCombat:
			return child
	return null


func _die() -> void:
	_fade_out(DEATH_SECONDS)
	died.emit()


## Dissolves without dying (the dream calmed down, e.g. its seal is restored): no `died`.
func vanish(seconds: float) -> void:
	if not is_dead():
		_fade_out(seconds)


func _fade_out(seconds: float) -> void:
	state = State.DEAD
	health = 0.0
	_stop()
	collision_layer = 0
	collision_mask = 0
	remove_from_group(GROUP)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), seconds)
	tween.tween_callback(queue_free)


func _set_eyes(color: Color) -> void:
	if _eye_material:
		_eye_material.albedo_color = color
		_eye_material.emission = color


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS
	mesh.height = HEIGHT
	mesh.material = PropKit.material(BODY_COLOR)
	body.mesh = mesh
	add_child(body)
	_eye_material = PropKit.material(EYE_COLOR, true)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		sphere.material = _eye_material
		eye.mesh = sphere
		eye.position = Vector3(side * 0.11, EYE_HEIGHT, -RADIUS + 0.03)
		add_child(eye)
