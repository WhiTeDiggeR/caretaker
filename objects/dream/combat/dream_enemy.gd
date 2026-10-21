class_name DreamEnemy
extends CharacterBody3D

## Projection of the sleeper's unrest (a guard of the dream): patrols around its post,
## chases the hero it can see, never walks off an edge, attacks after a visible wind-up and
## is staggered by hits. Parameters by `enemy_type` from data/dreams/combat.json.
## A `push` in the parameters shoves the hero that far on a hit; the look `hammer` (the forge's
## hammerer, #234) is a bulky figure of primitives with a hammer that rises over the wind-up and
## glows with it — the telegraph of a slow heavy blow.

signal died
## A hit that did not kill (the death is `died`).
signal hit_taken(damage: float)

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
const LOOK_HAMMER := "hammer"
const HAMMER_BODY_COLOR := Color(0.16, 0.11, 0.1)
const HAMMER_IRON := Color(0.3, 0.27, 0.26)
const HAMMER_REST := Vector3(deg_to_rad(20.0), 0, 0)
const HAMMER_RAISED := Vector3(deg_to_rad(-110.0), 0, 0)
const HAMMER_SLAM := Vector3(deg_to_rad(75.0), 0, 0)
const HAMMER_SLAM_SECONDS := 0.12
const HAMMER_GLOW := 3.0

@export var enemy_type: StringName = &"shade"
## Optional look (#199, С-01): a model standing on the floor with its front to +Z, drawn with
## `art_material`; the eyes move to `art_eye_height` over the body centre. Collision and
## behaviour stay the capsule's. Without it the shade is the plain capsule.
@export var art: PackedScene
@export var art_material: Material
@export var art_eye_height := EYE_HEIGHT
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
var _hammer: Node3D
var _hammer_material: StandardMaterial3D
var _hammer_tween: Tween


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
	hit_taken.emit(damage)
	state = State.STAGGER
	_timer = float(config.get("stagger", 0.35))
	velocity.x = push.x
	velocity.z = push.z
	_set_eyes(EYE_COLOR)
	_swing(HAMMER_REST, 0.2, false)


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
				_swing(HAMMER_RAISED, _timer, true)
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
	_slam()
	_cooldown = float(config.get("attack_cooldown", 1.2))
	state = State.CHASE
	if hero == null or _flat_distance(hero) > float(config.get("attack_range", 1.6)) + 0.3:
		return
	var combat := _combat_of(hero)
	if combat:
		combat.take_damage(float(config.get("damage", 15.0)), global_position, float(config.get("push", 0.0)))


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
	if art:
		_build_art()
	elif str(config.get("look", "")) == LOOK_HAMMER:
		_build_hammerer()
	else:
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = RADIUS
		mesh.height = HEIGHT
		mesh.material = PropKit.material(BODY_COLOR)
		body.mesh = mesh
		add_child(body)
	var eye_height := art_eye_height if art else float(config.get("eye_height", EYE_HEIGHT))
	_eye_material = PropKit.material(EYE_COLOR, true)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		sphere.material = _eye_material
		eye.mesh = sphere
		eye.position = Vector3(side * 0.11, eye_height, -RADIUS + 0.03)
		add_child(eye)


func _build_art() -> void:
	var look := art.instantiate() as Node3D
	look.name = "Art"
	look.position = Vector3(0, -HEIGHT * 0.5, 0)
	look.rotation.y = PI
	add_child(look)
	if art_material:
		for mesh: Node in look.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = art_material


## The hammerer of the forge (#234), primitives until its model: a broad hunched body, a head
## and a hammer on the right shoulder; the eyes stay where the shade has them.
func _build_hammerer() -> void:
	var body_material := PropKit.material(HAMMER_BODY_COLOR)
	var body := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.55
	torso.height = HEIGHT + 0.3
	torso.material = body_material
	body.mesh = torso
	body.scale = Vector3(1.0, 1.0, 0.75)
	body.position.y = 0.15
	add_child(body)
	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.24
	skull.height = 0.44
	skull.material = body_material
	head.mesh = skull
	head.position = Vector3(0, float(config.get("eye_height", EYE_HEIGHT)) + 0.05, -0.12)
	add_child(head)
	_hammer_material = PropKit.material(HAMMER_IRON)
	_hammer_material.emission_enabled = true
	_hammer_material.emission = WINDUP_COLOR
	_hammer_material.emission_energy_multiplier = 0.0
	_hammer = Node3D.new()
	_hammer.name = "Hammer"
	_hammer.position = Vector3(0.62, 0.55, 0.0)
	_hammer.rotation = HAMMER_REST
	add_child(_hammer)
	PropKit.box(_hammer, Vector3(0, 0, -0.55), Vector3(0.08, 0.08, 1.2), PropKit.material(Color(0.22, 0.15, 0.1)))
	PropKit.box(_hammer, Vector3(0, 0, -1.2), Vector3(0.36, 0.36, 0.6), _hammer_material, false, Vector3(0, deg_to_rad(90.0), 0))


## Raises (or lowers) the hammer over `seconds`; a raised hammer glows brighter as it goes up.
func _swing(pose: Vector3, seconds: float, glow: bool) -> void:
	if _hammer == null:
		return
	if _hammer_tween and _hammer_tween.is_valid():
		_hammer_tween.kill()
	_hammer_tween = create_tween().set_parallel()
	_hammer_tween.tween_property(_hammer, "rotation", pose, maxf(seconds, 0.01))
	_hammer_tween.tween_property(_hammer_material, "emission_energy_multiplier", HAMMER_GLOW if glow else 0.0, maxf(seconds, 0.01))


## The blow: the hammer comes down at once and settles back on the shoulder.
func _slam() -> void:
	if _hammer == null:
		return
	if _hammer_tween and _hammer_tween.is_valid():
		_hammer_tween.kill()
	_hammer_tween = create_tween()
	_hammer_tween.tween_property(_hammer, "rotation", HAMMER_SLAM, HAMMER_SLAM_SECONDS)
	_hammer_tween.parallel().tween_property(_hammer_material, "emission_energy_multiplier", 0.0, HAMMER_SLAM_SECONDS * 3.0)
	_hammer_tween.tween_interval(0.35)
	_hammer_tween.tween_property(_hammer, "rotation", HAMMER_REST, 0.4)
