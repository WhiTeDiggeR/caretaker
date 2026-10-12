class_name FirstPersonFeel
extends Node

## The hero's body (#134): footsteps by distance travelled with the surface underfoot, head
## bob and strafe roll, landing, breathing after a run. Runs after the player each physics
## frame (it is the player's child) and hands the camera motion to `set_view_motion`.
## Surfaces: `surface` meta or a `surface_<name>` group on the floor collider or its parent;
## anything else is concrete. Sounds: data/audio/sfx.json (`step_<surface>`, `step_crawl`,
## `step_ladder`, `land`, `breath`). Camera motion scales with Settings.head_bob (0 = off).

signal stepped(sound: StringName)
signal landed(fall_speed: float)

enum Gait { IDLE, WALK, RUN, CROUCH, CRAWL, LADDER, AIR }

const SURFACES: Array[StringName] = [&"concrete", &"metal", &"grate"]
const DEFAULT_SURFACE := &"concrete"
const SURFACE_META := &"surface"
const SURFACE_GROUP_PREFIX := "surface_"

## Metres travelled per footstep.
const STRIDE := {Gait.WALK: 2.0, Gait.RUN: 2.7, Gait.CROUCH: 1.3, Gait.CRAWL: 0.7, Gait.LADDER: 0.6}
## Loudness of a step against the catalogue volume, dB.
const STEP_VOLUME := {Gait.WALK: 0.0, Gait.RUN: 3.0, Gait.CROUCH: -8.0, Gait.CRAWL: -4.0, Gait.LADDER: 0.0}
## Head bob: vertical dip at each footfall and side sway over two steps, metres.
const BOB_HEIGHT := {Gait.WALK: 0.035, Gait.RUN: 0.06, Gait.CROUCH: 0.02, Gait.CRAWL: 0.03}
const BOB_SWAY := {Gait.WALK: 0.02, Gait.RUN: 0.03, Gait.CROUCH: 0.012, Gait.CRAWL: 0.025}
const RUN_MIN_SPEED := 6.0  # faster than walking: running
const MOVE_MIN_SPEED := 0.3  # slower is standing still
const BOB_BLEND_SPEED := 6.0  # how fast the bob fades in and out, 1/s
const MAX_ROLL := deg_to_rad(1.6)  # strafing at sprint speed
const ROLL_SPEED := 6.0
const ROLL_REFERENCE_SPEED := 8.5
const FIRST_STEP := 0.5  # of a stride: the first footfall comes soon after starting
const LAND_MIN_SPEED := 3.0  # softer landings are silent
const LAND_DIP_PER_SPEED := 0.018  # metres of camera dip per m/s of fall speed
const LAND_DIP_MAX := 0.16
const LAND_RECOVERY := 0.6  # metres per second
const LAND_LOUD_SPEED := 8.0  # full volume at this fall speed
const LAND_QUIET_DB := -10.0
## Breathing: running fills exertion, walking or standing drains it; above the threshold
## the hero breathes heavily until it drops below the calm level.
const EXERTION_RUN_SECONDS := 4.0
const EXERTION_RECOVERY_SECONDS := 6.0
const BREATH_START := 0.6
const BREATH_CALM := 0.25
const BREATH_INTERVAL := 1.5
const FEET_BELOW_ORIGIN := 0.9  # the player's feet stay at -STAND_HEIGHT / 2
const FLOOR_PROBE := 0.4  # below the feet

var gait: Gait = Gait.IDLE
var surface: StringName = DEFAULT_SURFACE
var exertion := 0.0
var breathing := false
var bob_offset := Vector3.ZERO
var roll := 0.0

var _player: CharacterBody3D
var _last_position := Vector3.ZERO
var _stride_progress := 0.0
var _step_count := 0
## Stood still: the next walk starts half a stride before its first footfall.
var _resting := true
var _bob_weight := 0.0
## Gait whose bob is fading out after the hero stopped.
var _bob_gait: Gait = Gait.WALK
var _land_dip := 0.0
var _airborne := false
var _fall_speed := 0.0
var _breath_timer := 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_last_position = _player.global_position


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := _player.global_position - _last_position
	_last_position = _player.global_position
	var climbing := bool(_player.get(&"is_climbing"))
	var grounded := bool(_player.call(&"is_grounded"))
	var horizontal := Vector2(moved.x, moved.z).length()
	var distance := absf(moved.y) if climbing else horizontal
	gait = _gait_for(distance / delta, climbing, grounded)
	if moved.length() > STRIDE[Gait.RUN]:
		distance = 0.0  # teleport (checkpoint, load), not a walk
	_update_landing(grounded, climbing, delta)
	_update_steps(distance, grounded)
	_update_breathing(delta)
	_update_view(delta)


## Surface of the floor under the hero (concrete when unknown).
func probe_surface() -> StringName:
	var feet := _player.global_position + Vector3.DOWN * FEET_BELOW_ORIGIN
	var query := PhysicsRayQueryParameters3D.create(_player.global_position, feet + Vector3.DOWN * FLOOR_PROBE)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	return surface_of(hit.get("collider") as Node) if not hit.is_empty() else DEFAULT_SURFACE


static func surface_of(node: Node) -> StringName:
	for candidate: Node in [node, node.get_parent() if node else null]:
		if candidate == null:
			continue
		if candidate.has_meta(SURFACE_META):
			var value := StringName(str(candidate.get_meta(SURFACE_META)))
			if value in SURFACES:
				return value
		for name in SURFACES:
			if candidate.is_in_group(StringName(SURFACE_GROUP_PREFIX + name)):
				return name
	return DEFAULT_SURFACE


## Sound of a footstep for a gait on a surface.
static func step_sound(step_gait: Gait, on: StringName) -> StringName:
	match step_gait:
		Gait.CRAWL:
			return &"step_crawl"
		Gait.LADDER:
			return &"step_ladder"
	return StringName("step_%s" % on)


func _gait_for(speed: float, climbing: bool, grounded: bool) -> Gait:
	if climbing:
		return Gait.LADDER if speed > MOVE_MIN_SPEED else Gait.IDLE
	if not grounded:
		return Gait.AIR
	if speed < MOVE_MIN_SPEED:
		return Gait.IDLE
	if bool(_player.get(&"is_crawling")):
		return Gait.CRAWL
	if bool(_player.get(&"is_crouching")):
		return Gait.CROUCH
	return Gait.RUN if speed > RUN_MIN_SPEED else Gait.WALK


func _update_steps(distance: float, grounded: bool) -> void:
	if not STRIDE.has(gait):
		_resting = _resting or (gait == Gait.IDLE and grounded)
		return
	var stride: float = STRIDE[gait]
	if _resting:
		_resting = false
		_stride_progress = stride * FIRST_STEP
	_stride_progress += distance
	if _stride_progress < stride:
		return
	_stride_progress = fmod(_stride_progress, stride)
	_step_count += 1
	if gait != Gait.LADDER:
		surface = probe_surface()
	var sound := step_sound(gait, surface)
	Sfx.play(sound, null, STEP_VOLUME[gait])
	stepped.emit(sound)


func _update_landing(grounded: bool, climbing: bool, delta: float) -> void:
	if not grounded and not climbing:
		_airborne = true
		_fall_speed = maxf(_fall_speed, -_player.velocity.y)
	elif _airborne:
		_airborne = false
		if _fall_speed >= LAND_MIN_SPEED:
			_land_dip = minf(_fall_speed * LAND_DIP_PER_SPEED, LAND_DIP_MAX)
			var loudness := clampf((_fall_speed - LAND_MIN_SPEED) / (LAND_LOUD_SPEED - LAND_MIN_SPEED), 0.0, 1.0)
			Sfx.play(&"land", null, lerpf(LAND_QUIET_DB, 0.0, loudness))
			landed.emit(_fall_speed)
			_stride_progress = 0.0
		_fall_speed = 0.0
	_land_dip = move_toward(_land_dip, 0.0, LAND_RECOVERY * delta)


func _update_breathing(delta: float) -> void:
	if gait == Gait.RUN:
		exertion = minf(exertion + delta / EXERTION_RUN_SECONDS, 1.0)
	elif gait != Gait.AIR:
		exertion = maxf(exertion - delta / EXERTION_RECOVERY_SECONDS, 0.0)
	if not breathing and exertion >= BREATH_START and gait != Gait.RUN:
		breathing = true
		_breath_timer = 0.0
	elif breathing and exertion <= BREATH_CALM:
		breathing = false
	if not breathing:
		return
	_breath_timer -= delta
	if _breath_timer <= 0.0:
		_breath_timer = BREATH_INTERVAL
		Sfx.play(&"breath", null, lerpf(-12.0, 0.0, exertion))


func _update_view(delta: float) -> void:
	var strength := Settings.head_bob
	var moving := BOB_HEIGHT.has(gait)
	_bob_weight = move_toward(_bob_weight, 1.0 if moving else 0.0, BOB_BLEND_SPEED * delta)
	if moving:
		_bob_gait = gait
	var stride: float = STRIDE.get(_bob_gait, STRIDE[Gait.WALK])
	var phase := clampf(_stride_progress / stride, 0.0, 1.0)
	var height: float = BOB_HEIGHT.get(_bob_gait, 0.0)
	var sway: float = BOB_SWAY.get(_bob_gait, 0.0)
	var side := 1.0 if _step_count % 2 == 0 else -1.0
	bob_offset = Vector3(
		sway * side * sin(PI * phase),
		-height * (0.5 + 0.5 * cos(TAU * phase)),
		0.0) * _bob_weight
	bob_offset.y -= _land_dip
	bob_offset *= strength
	var lateral := _player.velocity.dot(_player.global_basis.x) if gait != Gait.LADDER else 0.0
	var target_roll := -clampf(lateral / ROLL_REFERENCE_SPEED, -1.0, 1.0) * MAX_ROLL * strength
	roll = move_toward(roll, target_roll, ROLL_SPEED * MAX_ROLL * delta)
	_player.call(&"set_view_motion", bob_offset, roll)
