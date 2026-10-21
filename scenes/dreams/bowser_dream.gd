class_name BowserDream
extends Node3D

## Bowser's dream, first dive S (docs/game_design/06-bowser-dream-world.md, sections 4–5):
## terrace → ledge and chain bridge → yard of the first fight → seal hall → bridge → bastion
## with the gate. Blockout of primitives (#182); the ambush and the remains are wired by later
## tasks through the named hook nodes below, the seal of rings (#183) builds its own levers.
## Falling below the world counts as death (the lava area catches it first).
## The cycle (#190): the silhouette of №2 speaks once on the terrace (text in
## data/dreams/dreams.json), the side grate of the hall and the arch on the bastion open only
## after the seal is restored — also when the scene loads with the seal already restored.
## The visit is chosen by the story flags (Б-11, #234): once the overheating of module 4 has
## cracked the seal of the Forge (`OVERHEAT_FLAG`), every dive is the second visit «Горн»
## (docs/game_design/09-bowser-dream-v2.md): the core is the same but hot — the yard is quiet
## (its ambush disarmed), the burnt-out south rubble lets the hero into the branch «Кузница»
## (BowserForge, added here), the chains of the bridge glow, the throne seal stands restored
## (its `held_flag`) and its grate to the bastion is open from the start, no silhouette. The
## stage at entry follows the crisis: believed №2 — alarm, otherwise unrest (one more shade).
## The restored seal of the Forge sets `V2_SEAL_FLAG`, the gate after it `V2_DONE_FLAG`.

signal silhouette_spoke
signal side_door_opened

const MODULE := &"module_4"
const FALL_LIMIT_Y := -20.0
const MESSAGE_GROUP := &"message_display"
const SILHOUETTE_DELAY := 1.5  # after the veil of the entry has lifted
const SILHOUETTE_SECONDS := 5.0
const SILHOUETTE_FLICKER := 0.08
const SILHOUETTE_SIZE := Vector3(0.6, 1.9, 0.35)
const SILHOUETTE_COLOR := Color(0.05, 0.04, 0.06, 0.85)
const SIDE_GRATE_DROP := 5.2
const SIDE_GRATE_SECONDS := 1.2

## Hook nodes of the later tasks (R-2 seal, R-3 ambush, R-4 weapon by the remains).
const SEAL := ^"SealHall/Seal"
const SEAL_SLOT := ^"SealHall/SealSlot"
const SIDE_DOOR := ^"SealHall/SideDoor"
const SIDE_GRATE := ^"SealHall/SideGrate"
const GATE := ^"Bastion/Gate"
const WAKE_LINE := ^"Yard/Ambush/WakeLine"
const GUARD_SPAWNS: Array[NodePath] = [^"Yard/Ambush/GuardSpawnNorth", ^"Yard/Ambush/GuardSpawnSouth"]
const HALL_THRESHOLD := ^"Yard/Ambush/HallThreshold"
const REMAINS := ^"Yard/Remains"
const WEAPON_SPOT := ^"Yard/Remains/WeaponSpot"
const SILHOUETTE_SPOT := ^"Terrace/SilhouetteSpot"
const MOOD := ^"Mood"
const RUBBLE_SOUTH := ^"Branches/RubbleSouth"
const BRIDGE_ART := ^"Path/Bridge/Art"

const VISIT_FIRST := &"v1"
const VISIT_SECOND := &"v2"
const OVERHEAT_FLAG := &"part2/module4_overheat"
const BELIEVED_FLAG := &"part2/n2_believed"
const V2_SEAL_FLAG := &"part2/bowser_v2_seal"
const V2_DONE_FLAG := &"part2/v2_done"
const FORGE_SCENE := "res://scenes/dreams/bowser_forge.tscn"
const FORGE_ECHO_HINT := &"dream_remains_echo_far"
const STAGE_ALARM := "alarm"
const STAGE_UNREST := "unrest"
const HOT_IRON := Color(1.0, 0.38, 0.12)
const HOT_IRON_ENERGY := 1.6

var side_door_open := false
## The visit of the story (VISIT_FIRST, VISIT_SECOND), chosen on load.
var visit: StringName = VISIT_FIRST
## The branch «Кузница» on the second visit, null on the first.
var forge: BowserForge

@onready var _player: Node3D = $Player
@onready var _side_grate: StaticBody3D = get_node(SIDE_GRATE)
@onready var _silhouette_spot: Node3D = get_node(SILHOUETTE_SPOT)

var _silhouette: MeshInstance3D


func _ready() -> void:
	visit = story_visit()
	DreamKnowledge.visit_version = visit
	Dreams.seal_restored_signal.connect(_on_seal_restored)
	if visit == VISIT_SECOND:
		_setup_second_visit()
		return
	if Dreams.in_dream and Dreams.seal_restored:
		open_side_door(true)
	if not silhouette_line().is_empty() and not GameState.has_flag(_silhouette_flag()):
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = SILHOUETTE_DELAY
		timer.timeout.connect(_speak)
		add_child(timer)
		timer.start()


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < FALL_LIMIT_Y:
		set_physics_process(false)
		Dreams.die()


## The one line of the silhouette of №2 on the terrace: {title, text, flag} from the dream data.
static func silhouette_line() -> Dictionary:
	return (Dreams.dreams.get(String(MODULE), {}) as Dictionary).get("silhouette", {})


## Opens the grate between the seal hall and the bridge to the bastion.
func open_side_door(instant: bool = false) -> void:
	if side_door_open:
		return
	side_door_open = true
	var collision := _side_grate.get_node(^"Collision") as CollisionShape3D
	collision.set_deferred(&"disabled", true)
	var lowered := _side_grate.position + Vector3.DOWN * SIDE_GRATE_DROP
	if instant:
		_side_grate.position = lowered
	else:
		create_tween().tween_property(_side_grate, "position", lowered, SIDE_GRATE_SECONDS)
	side_door_opened.emit()


func _on_seal_restored(id: StringName) -> void:
	if id != MODULE:
		return
	open_side_door()
	if visit == VISIT_SECOND:
		GameState.set_flag(V2_SEAL_FLAG)


## Which visit the story is at (Б-11): the second once the overheating cracked the Forge's seal.
static func story_visit() -> StringName:
	return VISIT_SECOND if GameState.has_flag(OVERHEAT_FLAG) else VISIT_FIRST


## Stage name of the dream at entry of the second visit, for the guards of the forge.
static func second_visit_stage() -> String:
	return STAGE_ALARM if GameState.has_flag(BELIEVED_FLAG) else STAGE_UNREST


func _setup_second_visit() -> void:
	forge = (load(FORGE_SCENE) as PackedScene).instantiate() as BowserForge
	forge.name = "Forge"
	add_child(forge)
	var stage := second_visit_stage()
	forge.ambush.stage = stage
	(get_node(WAKE_LINE).get_parent() as DreamAmbush).disarm()
	var remains := get_node(REMAINS) as DreamRemains
	remains.echo_hint = FORGE_ECHO_HINT
	remains.listen_to(forge.ambush)
	var mood := get_node_or_null(MOOD) as DreamStageMood
	if mood:
		mood.watch_ambush(forge.ambush)
		if not (Dreams.in_dream and Dreams.seal_restored):
			mood.set_event_stage(DreamStageMood.Stage.UNREST if stage == STAGE_UNREST else DreamStageMood.Stage.ALARM)
	open_side_door(true)
	_burn_through_rubble()
	_heat_chains()
	Dreams.left.connect(_on_left)


## The south rubble of the yard burnt out: its stones no longer block the way to the forge.
func _burn_through_rubble() -> void:
	var rubble := get_node(RUBBLE_SOUTH)
	for child in rubble.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D:
					(shape as CollisionShape3D).disabled = true
		elif child is Node3D:
			(child as Node3D).visible = false


## The iron of the chain bridge glows with the heat (no damage, only light).
func _heat_chains() -> void:
	var art := get_node_or_null(BRIDGE_ART)
	if art == null:
		return
	for node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or not material.resource_name.contains("iron"):
				continue
			var hot := material.duplicate() as StandardMaterial3D
			hot.emission_enabled = true
			hot.emission = HOT_IRON
			hot.emission_energy_multiplier = HOT_IRON_ENERGY
			mesh_node.set_surface_override_material(surface, hot)


func _on_left(id: StringName, reason: int) -> void:
	if id == MODULE and reason == Dreams.Exit.GATE and Dreams.seal_restored:
		GameState.set_flag(V2_DONE_FLAG)


func _silhouette_flag() -> StringName:
	return StringName(str(silhouette_line().get("flag", "")))


## A figure without details (as in the prologue) appears as interference, speaks and falls apart.
func _speak() -> void:
	var line := silhouette_line()
	GameState.set_flag(_silhouette_flag())
	_silhouette = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = SILHOUETTE_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = SILHOUETTE_COLOR
	mesh.material = material
	_silhouette.mesh = mesh
	_silhouette.position = Vector3.UP * SILHOUETTE_SIZE.y * 0.5
	_silhouette_spot.add_child(_silhouette)
	get_tree().call_group(MESSAGE_GROUP, "show_message", str(line.get("title", "")), str(line.get("text", "")))
	silhouette_spoke.emit()
	var tween := create_tween()
	var steps := int(SILHOUETTE_SECONDS / SILHOUETTE_FLICKER)
	for step in steps:
		# Interference: the figure blinks more often towards the end and falls apart.
		var visible_now := step * 2 < steps or step % 2 == 0
		tween.tween_callback(func() -> void: _silhouette.visible = visible_now)
		tween.tween_interval(SILHOUETTE_FLICKER)
	tween.tween_callback(_silhouette.queue_free)


## Waypoints of the main route on the walking surface, terrace to gate (used by checks and bots).
static func route() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(4, 0, 0), Vector3(25, 0, 0), Vector3(27, 1.2, 0), Vector3(46, 1.2, 0),
		Vector3(56, 1.2, 0), Vector3(70, 1.2, 0), Vector3(75, 1.2, -5), Vector3(80, 1.2, -6),
		Vector3(80, 1.2, -20), Vector3(80, 1.2, -24),
	])
