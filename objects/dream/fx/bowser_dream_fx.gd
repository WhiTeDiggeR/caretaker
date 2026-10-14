class_name BowserDreamFx
extends Node3D

## Banners, decals and particles of Bowser's dream (ПР-12, ПР-13; docs/art/dream-bowser-s.md
## §2, §4). Banners (Д-01, emblem Д-7 б), decals (DT-10), the light shaft and the haze of the
## seal hall (Ф-05) are placed in the scene; the particles are built here and follow the
## dream: ash and embers by the stage of `DreamStageMood` (Ф-01), sparks from the hall ceiling
## when a ring turns (Ф-02), the brazier fire with a flickering light (Ф-03), smoke where the
## guards assemble (Ф-04), the white flash of the chain and the faint motes of the operator's
## trace. White only where Б-5 allows it: the chain, the trace and the shaft over the seal.

## Ash per second per 100 m² by stage (calm, alarm, unrest, pre-wake), embers from unrest on.
const ASH_RATE: Array[float] = [5.0, 15.0, 40.0, 80.0]
const EMBER_RATE: Array[float] = [0.0, 0.0, 4.0, 10.0]
const ASH_AREA := Vector2(30.0, 30.0)  # metres around the hero
const ASH_HEIGHT := 12.0
const ASH_LIFETIME := 5.0
const EMBER_LIFETIME := 2.5
const ASH_COLOR := Color("#5a524e")
const EMBER_COLOR := Color("#ff6a1a")
const SPARK_COLOR := Color("#ffa040")
const SPARK_HEIGHT := 11.0  # under the opening of the hall ceiling
const SPARK_AMOUNT := 48
const FIRE_COLOR := Color("#ff8a2a")
const FIRE_AMOUNT := 40
const FIRE_FLICKER := 0.15
const FIRE_FLICKER_HZ := Vector2(7.0, 11.3)
const SMOKE_COLOR := Color(0.08, 0.06, 0.1, 0.7)
const SMOKE_AMOUNT := 60
const ASSEMBLE_SECONDS := 1.5
const WHITE := Color("#eef6ff")
const CHAIN_FLASH_AMOUNT := 24
const TRACE_MOTES_AMOUNT := 8
## Upper bound of all particles alive at once (§5: the scene budget).
const PARTICLE_BUDGET := 6000

@export var mood_path: NodePath = ^"../Mood"
@export var seal_path: NodePath = ^"../SealHall/Seal"
@export var remains_path: NodePath = ^"../Yard/Remains"
@export var ambush_path: NodePath = ^"../Yard/Ambush"

var ash: GPUParticles3D
var embers: GPUParticles3D
var ring_sparks: GPUParticles3D
var brazier_fire: GPUParticles3D
var chain_flash: GPUParticles3D
var trace_motes: GPUParticles3D
var guard_smoke: Array[GPUParticles3D] = []

var _all: Array[GPUParticles3D] = []
var _player: Node3D
var _fire_light: OmniLight3D
var _fire_energy := 0.0

@onready var _mood: DreamStageMood = get_node_or_null(mood_path) as DreamStageMood
@onready var _seal: DreamSealRings = get_node_or_null(seal_path) as DreamSealRings
@onready var _remains: DreamRemains = get_node_or_null(remains_path) as DreamRemains
@onready var _ambush: DreamAmbush = get_node_or_null(ambush_path) as DreamAmbush


func _ready() -> void:
	ash = _particles("Ash", ceili(ASH_RATE[3] * _ash_hundreds() * ASH_LIFETIME), ASH_LIFETIME, ASH_COLOR, 0.0, 0.05)
	_box_emitter(ash, Vector3(ASH_AREA.x, ASH_HEIGHT, ASH_AREA.y) * 0.5, Vector3(0, -0.4, 0), 0.3)
	add_child(ash)
	embers = _particles("Embers", ceili(EMBER_RATE[3] * _ash_hundreds() * EMBER_LIFETIME), EMBER_LIFETIME, EMBER_COLOR, 3.0, 0.04)
	_box_emitter(embers, Vector3(ASH_AREA.x, 1.0, ASH_AREA.y) * 0.5, Vector3(0, 0.6, 0), 1.2)
	embers.position = Vector3.DOWN * ASH_HEIGHT * 0.4
	ash.add_child(embers)
	if _mood:
		_mood.stage_shown.connect(_on_stage_shown)
		_on_stage_shown(_mood.shown_stage)
	else:
		_on_stage_shown(float(DreamStageMood.Stage.ALARM))
	_setup_seal()
	_setup_remains()
	_setup_ambush()
	_fit_haze()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(DreamGate.PLAYER_GROUP) as Node3D
	if _player:
		ash.global_position = _player.global_position + Vector3.UP * ASH_HEIGHT * 0.4


func _process(_delta: float) -> void:
	if _fire_light == null or _fire_energy <= 0.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var flicker := 0.6 * sin(t * TAU * FIRE_FLICKER_HZ.x) + 0.4 * sin(t * TAU * FIRE_FLICKER_HZ.y + 1.7)
	_fire_light.light_energy = _fire_energy * (1.0 + FIRE_FLICKER * flicker)


## Particles alive at most at once, for the budget check.
func particle_capacity() -> int:
	var total := 0
	for particles in _all:
		total += particles.amount
	return total


func _on_stage_shown(stage: float) -> void:
	var a := clampi(floori(stage), 0, 3)
	var b := mini(a + 1, 3)
	var t := stage - a
	ash.amount_ratio = lerpf(ASH_RATE[a], ASH_RATE[b], t) / ASH_RATE[3]
	embers.amount_ratio = lerpf(EMBER_RATE[a], EMBER_RATE[b], t) / EMBER_RATE[3]
	embers.emitting = embers.amount_ratio > 0.0


func _setup_seal() -> void:
	if _seal == null:
		return
	ring_sparks = _particles("RingSparks", SPARK_AMOUNT, 1.2, SPARK_COLOR, 4.0, 0.03)
	_burst(ring_sparks, Vector3(0, -2.0, 0), 75.0, 0.9)
	(ring_sparks.process_material as ParticleProcessMaterial).gravity = Vector3(0, -9.8, 0)
	_seal.add_child(ring_sparks)
	ring_sparks.position = Vector3.UP * SPARK_HEIGHT
	_seal.ring_turned.connect(func(_ring: int, _position: int) -> void: ring_sparks.restart())


func _setup_remains() -> void:
	if _remains == null:
		return
	var brazier := _remains.get_node(_remains.brazier) as Node3D
	brazier_fire = _particles("FireParticles", FIRE_AMOUNT, 0.9, FIRE_COLOR, 3.0, 0.12)
	_box_emitter(brazier_fire, Vector3(0.25, 0.05, 0.25), Vector3(0, 1.4, 0), 0.4)
	brazier_fire.emitting = false
	brazier_fire.position = Vector3.UP * 0.6
	brazier.add_child(brazier_fire)
	chain_flash = _particles("ChainFlash", CHAIN_FLASH_AMOUNT, 0.6, WHITE, 5.0, 0.03)
	_burst(chain_flash, Vector3(0, 2.0, 0), 90.0, 1.0)
	_remains.get_node(_remains.weapon_spot).add_child(chain_flash)
	var trace := _remains.get_node_or_null(_remains.death_trace) as Node3D
	if trace:
		trace_motes = _particles("Motes", TRACE_MOTES_AMOUNT, 3.0, WHITE, 0.6, 0.02)
		_box_emitter(trace_motes, Vector3(0.35, 0.02, 0.35), Vector3(0, 0.25, 0), 0.1)
		trace.add_child(trace_motes)
	_remains.awakened.connect(_on_remains_awakened)
	if _remains.is_awake:
		_on_remains_awakened()


func _on_remains_awakened() -> void:
	brazier_fire.emitting = true
	chain_flash.restart()
	_fire_light = _remains.brazier_light
	get_tree().create_timer(DreamRemains.BRAZIER_LIGHT_SECONDS).timeout.connect(func() -> void:
		_fire_energy = DreamRemains.BRAZIER_ENERGY)


func _setup_ambush() -> void:
	if _ambush == null:
		return
	for path in _ambush.spawn_points:
		var spot := _ambush.get_node(path) as Node3D
		var smoke := _particles("Smoke", SMOKE_AMOUNT, ASSEMBLE_SECONDS, SMOKE_COLOR, 0.0, 0.5)
		_box_emitter(smoke, Vector3(0.6, 0.1, 0.6), Vector3(0, 1.6, 0), 0.4)
		smoke.one_shot = true
		smoke.emitting = false
		smoke.position = Vector3.UP * 0.2
		spot.add_child(smoke)
		guard_smoke.append(smoke)
	_ambush.ambush_started.connect(_on_ambush_started)


func _on_ambush_started() -> void:
	for smoke in guard_smoke:
		smoke.restart()


## The haze of the hall only shows with volumetric fog on; the global density stays zero.
func _fit_haze() -> void:
	if _mood == null:
		return
	_mood.environment.volumetric_fog_enabled = true
	_mood.environment.volumetric_fog_density = 0.0


func _ash_hundreds() -> float:
	return ASH_AREA.x * ASH_AREA.y / 100.0


func _particles(node_name: String, amount: int, lifetime: float, color: Color, glow: float, particle_size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.4
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * particle_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_all.append(particles)
	return particles


func _box_emitter(particles: GPUParticles3D, extents: Vector3, velocity: Vector3, spread: float) -> void:
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = velocity.normalized() if velocity != Vector3.ZERO else Vector3.UP
	process.initial_velocity_min = velocity.length() * 0.6
	process.initial_velocity_max = velocity.length() * 1.2
	process.spread = 30.0
	process.turbulence_enabled = spread > 0.2
	process.turbulence_noise_strength = spread


func _burst(particles: GPUParticles3D, velocity: Vector3, spread: float, explosiveness: float) -> void:
	var process := particles.process_material as ParticleProcessMaterial
	process.direction = velocity.normalized()
	process.spread = spread
	process.initial_velocity_min = velocity.length() * 0.5
	process.initial_velocity_max = velocity.length() * 1.5
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = explosiveness
