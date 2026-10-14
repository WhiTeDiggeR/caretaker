class_name DreamStageMood
extends DreamMood

## Sky and light of Bowser's dream by the four stages of the sleep (ПР-11 + Р-6 light;
## docs/art/dream-bowser-s.md §2, docs/game_design/06-bowser-dream-world.md §11).
## The stage follows the events of the dream: entry — alarm, the ambush — unrest, the restored
## seal — alarm again, the open gate close by (or a later visit after the seal) — calm; a sleeper
## near awakening forces pre-wake. Every change blends over TRANSITION_SECONDS: the sky shader
## (`stage`), fog, ambient, the back light and the lava surface (glow, pulse, level).
## No preset is white (Б-5): white light stays with the seal, the gate, the chain and the trace.
## The threat grows in colour, the sky, the lava and its pulse, not in darkness: the light and
## the fog keep the level readable at every stage (#217).

## Every shown (possibly fractional) stage, for the particles of the dream (ПР-13).
signal stage_shown(stage: float)

enum Stage { CALM, ALARM, UNREST, PRE_WAKE }

## The stage to show changed (the blend starts); the dream sound follows it (#201).
signal stage_changed(stage: Stage)

const TRANSITION_SECONDS := 2.5
const GATE_CALM_RADIUS := 12.0
const PRE_WAKE_FROM := 3  # Containment stage of the sleeper that forces pre-wake
const FOG_SKY_AFFECT := 0.3  # the haze must not hide the clouds and the far volcano
const SKY_SHADER := preload("res://materials/dream_bowser/sky.gdshader")

const SKY_TOP: Array[Color] = [Color("#4a2436"), Color("#2e1622"), Color("#1c0c16"), Color("#0c060c")]
const SKY_HORIZON: Array[Color] = [Color("#c8642a"), Color("#9a3a22"), Color("#5a1a2a"), Color("#2a0f1f")]
const FOG_COLOR: Array[Color] = [Color("#8a4a32"), Color("#8a3e2c"), Color("#8a3430"), Color("#883036")]
const FOG_DENSITY: Array[float] = [0.010, 0.012, 0.014, 0.016]
const AMBIENT_COLOR := Color("#6b4a48")
const AMBIENT_ENERGY: Array[float] = [0.4, 0.42, 0.44, 0.46]
const SUN_COLOR: Array[Color] = [Color("#ffb070"), Color("#ff8a4a"), Color("#f06a44"), Color("#e04a3a")]
const SUN_ENERGY: Array[float] = [0.6, 0.6, 0.62, 0.64]
const LAVA_COLOR: Array[Color] = [Color("#ff8a2a"), Color("#ff6a1a"), Color("#ff5a1a"), Color("#ff3a12")]
const LAVA_ENERGY: Array[float] = [2.0, 2.6, 3.2, 4.0]
const LAVA_PULSE_HZ: Array[float] = [0.0, 0.0, 0.0, 0.6]
const LAVA_LEVEL: Array[float] = [0.0, 0.5, 1.0, 1.5]

@export var sun_path: NodePath = ^"../Sun"
@export var lava_surface_path: NodePath = ^"../LavaSurface"
@export var ambush_path: NodePath = ^"../Yard/Ambush"
@export var gate_path: NodePath = ^"../Bastion/Gate"

## Stage the events of the dream ask for (before the sleeper's instability is applied).
var event_stage: Stage = Stage.ALARM
## Stage being shown now; fractional while blending.
var shown_stage := float(Stage.ALARM)

var _sky_material: ShaderMaterial
var _lava_material: ShaderMaterial
var _tween: Tween
var _player: Node3D
var _announced: Stage = Stage.ALARM

@onready var _sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var _lava_surface: MeshInstance3D = get_node_or_null(lava_surface_path)
@onready var _ambush: DreamAmbush = get_node_or_null(ambush_path)
@onready var _gate: DreamGate = get_node_or_null(gate_path)


func _ready() -> void:
	environment = environment.duplicate()
	_setup_environment()
	if _lava_surface and _lava_surface.mesh and _lava_surface.mesh.surface_get_material(0) is ShaderMaterial:
		_lava_material = _lava_surface.mesh.surface_get_material(0).duplicate()
		_lava_surface.material_override = _lava_material
	if _ambush:
		_ambush.ambush_started.connect(_on_ambush_started)
	Dreams.seal_restored_signal.connect(_on_seal_restored)
	Containment.stage_changed.connect(func(id: StringName, _stage: int) -> void:
		if id == Dreams.module_id:
			apply())
	if Dreams.in_dream and Dreams.seal_restored:
		event_stage = Stage.CALM  # a later visit, the sleep already resynchronised
	_announced = target_stage()
	shown_stage = float(_announced)
	_show(shown_stage)
	set_physics_process(_gate != null and event_stage != Stage.CALM)


func _physics_process(_delta: float) -> void:
	if not _gate.is_open():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(DreamGate.PLAYER_GROUP) as Node3D
	if _player and _player.global_position.distance_to(_gate.global_position) < GATE_CALM_RADIUS:
		set_physics_process(false)
		set_event_stage(Stage.CALM)


## Re-reads the sleeper's instability (Containment) and blends to the resulting stage.
func apply() -> void:
	if not is_node_ready():
		return
	if target_stage() != _announced:
		_announced = target_stage()
		stage_changed.emit(_announced)
	var target := float(target_stage())
	if is_equal_approx(target, shown_stage):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_show, shown_stage, target, TRANSITION_SECONDS)


## The stage asked by an event of the dream (also for tests and debug moments).
func set_event_stage(stage: Stage) -> void:
	event_stage = stage
	apply()


## Stage to show: the event stage, or pre-wake while the sleeper is close to waking.
func target_stage() -> Stage:
	if Dreams.module_id != &"" and Containment.get_stage(Dreams.module_id) >= PRE_WAKE_FROM:
		return Stage.PRE_WAKE
	return event_stage


## Jumps to the end of a running blend (tests).
func finish_transition() -> void:
	if _tween and _tween.is_valid():
		_tween.custom_step(TRANSITION_SECONDS)


func _setup_environment() -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	_sky_material.set_shader_parameter(&"top_colors", _linear(SKY_TOP))
	_sky_material.set_shader_parameter(&"horizon_colors", _linear(SKY_HORIZON))
	_sky_material.set_shader_parameter(&"lava_colors", _linear(LAVA_COLOR))
	var sky := Sky.new()
	sky.sky_material = _sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_hdr_threshold = 1.0
	environment.glow_bloom = 0.05
	environment.fog_enabled = true
	environment.fog_sky_affect = FOG_SKY_AFFECT


func _show(stage: float) -> void:
	shown_stage = stage
	var a := clampi(floori(stage), 0, 3)
	var b := mini(a + 1, 3)
	var t := stage - a
	_sky_material.set_shader_parameter(&"stage", stage)
	environment.background_color = SKY_HORIZON[a].lerp(SKY_HORIZON[b], t)
	environment.fog_light_color = FOG_COLOR[a].lerp(FOG_COLOR[b], t)
	environment.fog_density = lerpf(FOG_DENSITY[a], FOG_DENSITY[b], t)
	environment.ambient_light_energy = lerpf(AMBIENT_ENERGY[a], AMBIENT_ENERGY[b], t)
	if _sun:
		_sun.light_color = SUN_COLOR[a].lerp(SUN_COLOR[b], t)
		_sun.light_energy = lerpf(SUN_ENERGY[a], SUN_ENERGY[b], t)
	if _lava_material:
		_lava_material.set_shader_parameter(&"glow_color", LAVA_COLOR[a].lerp(LAVA_COLOR[b], t))
		_lava_material.set_shader_parameter(&"emission_energy", lerpf(LAVA_ENERGY[a], LAVA_ENERGY[b], t))
		_lava_material.set_shader_parameter(&"pulse_hz", lerpf(LAVA_PULSE_HZ[a], LAVA_PULSE_HZ[b], t))
		_lava_material.set_shader_parameter(&"level_offset", lerpf(LAVA_LEVEL[a], LAVA_LEVEL[b], t))
	stage_shown.emit(stage)


func _on_ambush_started() -> void:
	if not Dreams.seal_restored:
		set_event_stage(Stage.UNREST)


func _on_seal_restored(id: StringName) -> void:
	if id == Dreams.module_id or Dreams.module_id == &"":
		set_event_stage(Stage.ALARM)


static func _linear(colors: Array[Color]) -> PackedVector3Array:
	var result := PackedVector3Array()
	for color in colors:
		var linear := color.srgb_to_linear()
		result.append(Vector3(linear.r, linear.g, linear.b))
	return result
