extends CharacterBody3D

## First-person hero: walking, sprinting, jumping, crouching and climbing over low obstacles.
## The body origin is the centre of the standing capsule; feet stay at -STAND_HEIGHT / 2
## while crouching because the collision shape is lowered together with its height.

signal crouch_changed(crouching: bool)
signal mantle_started(target: Vector3)
signal mantle_finished

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.5
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const CROUCH_TRANSITION_SPEED := 5.0  # metres of capsule height per second
const STAND_CAMERA_Y := 0.3

const MANTLE_MIN_HEIGHT := 0.35  # lower edges are stepped over by jumping
const MANTLE_MAX_HEIGHT := 1.25  # canon: only low obstacles, no parkour
const MANTLE_PROBE_HEIGHT := 0.3  # forward probe height above the feet
const MANTLE_REACH := 0.6  # distance in front of the capsule surface
const MANTLE_DEPTH := 0.45  # how far onto the obstacle the hero lands
const MANTLE_RISE_TIME := 0.3
const MANTLE_MOVE_TIME := 0.2
const CLEARANCE_SKIN := 0.03

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var interactor: Interactor = $Interactor

@export var interact_label: Label
@export var hold_progress_bar: Range

var is_crouching := false
var is_mantling := false

var _shape: CapsuleShape3D
var _current_height := STAND_HEIGHT
var _forced_crouch := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interactor.prompt_label = interact_label
	interactor.hold_bar = hold_progress_bar
	# The capsule changes height at runtime, so every player owns its shape.
	_shape = (_collision.shape as CapsuleShape3D).duplicate()
	_collision.shape = _shape
	_apply_height(STAND_HEIGHT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		rotate_y(-mouse_event.relative.x * MOUSE_SENS)

		camera.rotate_x(-mouse_event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-89),
			deg_to_rad(89)
		)

func _physics_process(delta: float) -> void:
	if is_mantling:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_crouch(delta)

	if Input.is_action_just_pressed("jump"):
		if not try_mantle() and is_on_floor() and not is_crouching:
			velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := (
		transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()
	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()


# --- Crouch ----------------------------------------------------------------

func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch") or _forced_crouch
	if not wants_crouch and is_crouching and not can_stand():
		wants_crouch = true
	if _forced_crouch and can_stand() and not Input.is_action_pressed("crouch"):
		_forced_crouch = false

	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		crouch_changed.emit(is_crouching)

	var target_height := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	if not is_equal_approx(_current_height, target_height):
		_apply_height(move_toward(_current_height, target_height, CROUCH_TRANSITION_SPEED * delta))


func _apply_height(height: float) -> void:
	_current_height = height
	_shape.height = height
	_collision.position.y = (height - STAND_HEIGHT) * 0.5
	camera.position.y = STAND_CAMERA_Y - (STAND_HEIGHT - height)


## True when the standing capsule fits at the current position.
func can_stand() -> bool:
	return _capsule_fits(global_position, STAND_HEIGHT)


func _capsule_fits(origin: Vector3, height: float) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = _shape.radius - CLEARANCE_SKIN
	probe.height = height - CLEARANCE_SKIN * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var centre := origin + Vector3.UP * ((height - STAND_HEIGHT) * 0.5 + CLEARANCE_SKIN)
	query.transform = Transform3D(Basis.IDENTITY, centre)
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Mantle ----------------------------------------------------------------

## Climbs onto the obstacle in front of the hero when it is low enough and there is room
## on top. Returns false and changes nothing otherwise.
func try_mantle() -> bool:
	if is_mantling:
		return false
	var target := find_mantle_target()
	if target == Vector3.INF:
		return false
	_perform_mantle(target)
	return true


## Body origin after climbing the obstacle ahead, or Vector3.INF when it cannot be climbed.
func find_mantle_target() -> Vector3:
	var space := get_world_3d().direct_space_state
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3.INF
	forward = forward.normalized()
	var feet_y := global_position.y - STAND_HEIGHT * 0.5

	var probe_from := Vector3(global_position.x, feet_y + MANTLE_PROBE_HEIGHT, global_position.z)
	var wall := _ray(space, probe_from, probe_from + forward * (_shape.radius + MANTLE_REACH))
	if wall.is_empty() or absf((wall["normal"] as Vector3).y) > 0.3:
		return Vector3.INF

	var over := (wall["position"] as Vector3) + forward * MANTLE_DEPTH
	var top_from := Vector3(over.x, feet_y + MANTLE_MAX_HEIGHT + 0.05, over.z)
	var top := _ray(space, top_from, Vector3(over.x, feet_y + MANTLE_MIN_HEIGHT * 0.5, over.z))
	if top.is_empty() or (top["normal"] as Vector3).y < 0.7:
		return Vector3.INF
	var top_y := (top["position"] as Vector3).y
	var climb := top_y - feet_y
	if climb < MANTLE_MIN_HEIGHT or climb > MANTLE_MAX_HEIGHT:
		return Vector3.INF

	var target := Vector3(over.x, top_y + STAND_HEIGHT * 0.5 + 0.01, over.z)
	var raised := Vector3(global_position.x, target.y, global_position.z)
	if not _capsule_fits(raised, CROUCH_HEIGHT) or not _capsule_fits(target, CROUCH_HEIGHT):
		return Vector3.INF
	return target


func _perform_mantle(target: Vector3) -> void:
	is_mantling = true
	interactor.set_physics_process(false)
	velocity = Vector3.ZERO
	if not _capsule_fits(target, STAND_HEIGHT):
		_forced_crouch = true
		is_crouching = true
		_apply_height(CROUCH_HEIGHT)
		crouch_changed.emit(true)
	mantle_started.emit(target)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", target.y, MANTLE_RISE_TIME)
	tween.tween_property(self, "global_position", target, MANTLE_MOVE_TIME)
	await tween.finished
	is_mantling = false
	interactor.set_physics_process(true)
	mantle_finished.emit()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return space.intersect_ray(query)
