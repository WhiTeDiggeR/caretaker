extends CharacterBody3D

## First-person hero: walking (up and down stairs), sprinting, jumping, crouching, crawling,
## climbing over low obstacles and up and down vertical ladders (canon:
## docs/world/03-complex.md).
## The body origin is the centre of the standing capsule; feet stay at -STAND_HEIGHT / 2
## while crouching or crawling because the collision shape is lowered with its height.

signal crouch_changed(crouching: bool)
signal crawl_changed(crawling: bool)
signal ladder_changed(climbing: bool)
signal mantle_started(target: Vector3)
signal mantle_finished

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.5
const CROUCH_SPEED = 2.5
const CRAWL_SPEED = 1.2
const JUMP_VELOCITY = 4.5

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
## The smallest capsule (2 × radius): a crawl passage needs 0.75 m (prop standard).
const CRAWL_HEIGHT := 0.7
const CROUCH_TRANSITION_SPEED := 5.0  # metres of capsule height per second
const STAND_CAMERA_Y := 0.7  # eyes 1.6 m above the floor (docs/game_design/02-prop-standard.md)

const MANTLE_MIN_HEIGHT := 0.35  # up to STEP_MAX_HEIGHT edges are walked up; between, jump
const MANTLE_MAX_HEIGHT := 1.25  # canon: only low obstacles, no parkour
const MANTLE_PROBE_HEIGHT := 0.3  # forward probe height above the feet
const MANTLE_REACH := 0.6  # distance in front of the capsule surface
const MANTLE_DEPTH := 0.45  # how far onto the obstacle the hero lands
const MANTLE_RISE_TIME := 0.3
const MANTLE_MOVE_TIME := 0.2
const CLEARANCE_SKIN := 0.03

## Steps up to this height are walked up (stairs of the complex: 0.17-0.19 m risers);
## higher edges are jumped or climbed (MANTLE_MIN_HEIGHT).
const STEP_MAX_HEIGHT := 0.3
const STEP_PROBE := 0.1  # how far ahead a step is looked for, beyond this frame's motion
const STEP_TOP_INSET := 0.05  # the step top is probed this far past the blocking edge
const STEP_SNAP_MIN_NORMAL_Y := 0.3  # stair edges count for the snap, walls do not
## Keeps the hero on the stairs while walking down instead of hopping off every step.
const FLOOR_SNAP := STEP_MAX_HEIGHT + 0.05
## The camera catches up with a step instead of jumping with it.
const STEP_CAMERA_SMOOTHING := 14.0

const CLIMB_SPEED := 2.0
const LADDER_SNAP := 10.0  # how fast the hero is pulled onto the ladder line, 1/s
const LADDER_GRAB_TIME := 0.25
const LADDER_TOP_START := 1.0  # feet below the top when climbing down from the landing
const LADDER_EXIT_MARGIN := 0.35  # feet this close to the top step onto the landing
const LADDER_RELEASE_PUSH := 2.0

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var interactor: Interactor = $Interactor

@export var interact_label: Label
@export var hold_progress_bar: Range

var is_crouching := false
var is_crawling := false
var is_mantling := false
var is_climbing := false
## Set while a full-screen UI (terminal, document) owns the input.
var controls_locked := false

var _shape: CapsuleShape3D
var _current_height := STAND_HEIGHT
var _forced_crouch := false
var _leave_crawl := false
## Camera lag after stepping up, metres; decays to zero.
var _step_offset := 0.0
var _snapped := false
var _ladder: Ladder
## Head bob and landing dip (FirstPersonFeel, #134), added to the camera position.
var _view_offset := Vector3.ZERO
var _feel: FirstPersonFeel


func _ready() -> void:
	add_to_group(&"player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	interactor.prompt_label = interact_label
	interactor.hold_bar = hold_progress_bar
	# The capsule changes height at runtime, so every player owns its shape.
	_shape = (_collision.shape as CapsuleShape3D).duplicate()
	_collision.shape = _shape
	floor_snap_length = FLOOR_SNAP
	_apply_height(STAND_HEIGHT)
	_feel = FirstPersonFeel.new()
	_feel.name = &"Feel"
	add_child(_feel)


func _apply_settings() -> void:
	camera.fov = Settings.fov


func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	interactor.set_physics_process(not locked)
	if not locked:
		interactor.suppress_until_release()
	if locked and interact_label:
		interact_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var sensitivity := Settings.mouse_sensitivity()
		rotate_y(-mouse_event.relative.x * sensitivity)

		var vertical := -1.0 if Settings.invert_y else 1.0
		camera.rotate_x(-mouse_event.relative.y * sensitivity * vertical)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-89),
			deg_to_rad(89)
		)

func _physics_process(delta: float) -> void:
	if is_mantling:
		return
	if is_climbing:
		_climb()
		return

	if not is_grounded():
		velocity += get_gravity() * delta

	if controls_locked:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		move_and_slide()
		return

	_update_crouch(delta)

	if Input.is_action_just_pressed("jump") and not is_crawling:
		if not try_mantle() and is_grounded() and not is_crouching:
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
	if is_crawling:
		speed = CRAWL_SPEED
	elif is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	var was_grounded := is_grounded()
	_try_step_up(delta)
	move_and_slide()
	_snap_down(was_grounded)
	_update_step_camera(delta)


# --- Crouch ----------------------------------------------------------------

func _update_crouch(delta: float) -> void:
	_update_crawl()
	if is_crawling:
		_approach_height(CRAWL_HEIGHT, delta)
		return
	var wants_crouch := Input.is_action_pressed("crouch") or _forced_crouch
	if not wants_crouch and is_crouching and not can_stand():
		wants_crouch = true
	if _forced_crouch and can_stand() and not Input.is_action_pressed("crouch"):
		_forced_crouch = false

	if wants_crouch != is_crouching:
		is_crouching = wants_crouch
		crouch_changed.emit(is_crouching)

	_approach_height(CROUCH_HEIGHT if is_crouching else STAND_HEIGHT, delta)


func _approach_height(target_height: float, delta: float) -> void:
	if not is_equal_approx(_current_height, target_height):
		_apply_height(move_toward(_current_height, target_height, CROUCH_TRANSITION_SPEED * delta))


# --- Steps -------------------------------------------------------------------

## A capsule meets a stair riser low on its rounded bottom, where the contact counts as a
## wall: walking straight into 0.17 m steps stops the hero. When the motion ahead is blocked,
## a ray just past the blocking point finds the top of the step; if it is walkable, no
## higher than STEP_MAX_HEIGHT and there is head room, the body is lifted onto it and
## move_and_slide carries it forward.
func _try_step_up(delta: float) -> bool:
	if not is_grounded() or velocity.y > 0.0:
		return false
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return false
	var direction := motion.normalized()
	motion += direction * STEP_PROBE
	var blocked := KinematicCollision3D.new()
	if not test_move(global_transform, motion, blocked):
		return false
	var feet := global_position.y - STAND_HEIGHT * 0.5
	var point := blocked.get_position() + direction * STEP_TOP_INSET
	var from := Vector3(point.x, feet + STEP_MAX_HEIGHT + 0.05, point.z)
	var hit := _ray(get_world_3d().direct_space_state, from, Vector3(point.x, feet - 0.01, point.z))
	if hit.is_empty() or (hit["normal"] as Vector3).angle_to(Vector3.UP) > floor_max_angle:
		return false
	var height := (hit["position"] as Vector3).y - feet
	if height <= 0.01 or height > STEP_MAX_HEIGHT:
		return false
	if test_move(global_transform, Vector3.UP * (height + 0.02)):
		return false
	global_position.y += height + 0.005
	_step_offset = minf(_step_offset + height, STEP_MAX_HEIGHT)
	_apply_height(_current_height)
	return true


## Walking down stairs: when the floor drops away by no more than a step, the body is
## pulled down onto the next step instead of sliding off the edges in a long fall.
func _snap_down(was_grounded: bool) -> void:
	_snapped = false
	if not was_grounded or is_on_floor() or velocity.y > 0.0:
		return
	if Vector2(velocity.x, velocity.z).length_squared() < 0.0001:
		return
	var down := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * STEP_MAX_HEIGHT, down):
		return
	if down.get_normal().y < STEP_SNAP_MIN_NORMAL_Y:
		return
	global_position += down.get_travel()
	velocity.y = 0.0
	_snapped = true


## On the floor, or held on a stair edge by the step snap this frame.
func is_grounded() -> bool:
	return is_on_floor() or _snapped


func _update_step_camera(delta: float) -> void:
	if _step_offset <= 0.0:
		return
	_step_offset = move_toward(_step_offset, 0.0, maxf(_step_offset, 0.02) * STEP_CAMERA_SMOOTHING * delta)
	_apply_height(_current_height)


# --- Crawl -------------------------------------------------------------------

## The crawl action toggles lying down; crouch while crawling also asks to get up. Getting up
## waits until there is room for a crouch, then the usual crouch rules raise the hero further.
func _update_crawl() -> void:
	if Input.is_action_just_pressed("crawl") or (is_crawling and Input.is_action_just_pressed("crouch")):
		if is_crawling:
			_leave_crawl = true
		else:
			_set_crawling(true)
	if is_crawling and _leave_crawl and _capsule_fits(global_position, CROUCH_HEIGHT):
		_set_crawling(false)
		is_crouching = true
		crouch_changed.emit(true)


func _set_crawling(crawling: bool) -> void:
	_leave_crawl = false
	if is_crawling == crawling:
		return
	is_crawling = crawling
	if crawling and is_crouching:
		is_crouching = false
		_forced_crouch = false
		crouch_changed.emit(false)
	crawl_changed.emit(crawling)


func _apply_height(height: float) -> void:
	_current_height = height
	_shape.height = height
	_collision.position.y = (height - STAND_HEIGHT) * 0.5
	_update_camera()


## Camera motion of the body: `offset` in metres (bob, landing), `roll` in radians (strafe).
func set_view_motion(offset: Vector3, roll: float) -> void:
	_view_offset = offset
	camera.rotation.z = roll
	_update_camera()


func _update_camera() -> void:
	var eyes := STAND_CAMERA_Y - (STAND_HEIGHT - _current_height) - _step_offset
	camera.position = Vector3(_view_offset.x, eyes + _view_offset.y, 0.0)


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


# --- Ladder ----------------------------------------------------------------

## Grabs a vertical ladder: from below, or from its landing when the feet are near the top.
func attach_ladder(ladder: Ladder) -> bool:
	if is_climbing or is_mantling or is_crawling or controls_locked:
		return false
	var feet := global_position.y - STAND_HEIGHT * 0.5
	var from_top := feet >= ladder.top_y() - LADDER_EXIT_MARGIN
	var start_feet := ladder.top_y() - LADDER_TOP_START if from_top else maxf(feet, ladder.bottom_y())
	var start := ladder.body_position(start_feet, STAND_HEIGHT * 0.5)
	if is_crouching:
		is_crouching = false
		_forced_crouch = false
		crouch_changed.emit(false)
	_apply_height(STAND_HEIGHT)
	_ladder = ladder
	is_climbing = true
	velocity = Vector3.ZERO
	rotation.y = ladder.global_rotation.y
	ladder_changed.emit(true)
	is_mantling = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", start, LADDER_GRAB_TIME)
	await tween.finished
	is_mantling = false
	return true


## Lets go of the ladder; `push` moves the hero away from it (a jump).
func detach_ladder(push: float = 0.0) -> void:
	if not is_climbing:
		return
	if push > 0.0:
		velocity = _ladder.global_basis.z * push
	is_climbing = false
	_ladder = null
	ladder_changed.emit(false)


func _climb() -> void:
	if Input.is_action_just_pressed("jump"):
		detach_ladder(LADDER_RELEASE_PUSH)
		return
	var climb := Input.get_axis("move_back", "move_forward")
	var feet := global_position.y - STAND_HEIGHT * 0.5
	if climb > 0.0 and feet >= _ladder.top_y() - LADDER_EXIT_MARGIN:
		_exit_ladder_top()
		return
	var line := _ladder.body_position(feet, STAND_HEIGHT * 0.5)
	velocity = Vector3((line.x - global_position.x) * LADDER_SNAP, climb * CLIMB_SPEED, (line.z - global_position.z) * LADDER_SNAP)
	move_and_slide()
	if climb < 0.0 and (is_on_floor() or feet <= _ladder.bottom_y() + 0.01):
		detach_ladder()


func _exit_ladder_top() -> void:
	var target := _ladder.exit_position(STAND_HEIGHT * 0.5)
	detach_ladder()
	_perform_mantle(target)


# --- Mantle ----------------------------------------------------------------

## Climbs onto the obstacle in front of the hero when it is low enough and there is room
## on top. Returns false and changes nothing otherwise.
func try_mantle() -> bool:
	# Only from the floor: a jump must not add height to the climb (no parkour, canon).
	if is_mantling or is_crawling or not is_on_floor():
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
	interactor.set_physics_process(not controls_locked)
	mantle_finished.emit()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return space.intersect_ray(query)
