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

var side_door_open := false

@onready var _player: Node3D = $Player
@onready var _side_grate: StaticBody3D = get_node(SIDE_GRATE)
@onready var _silhouette_spot: Node3D = get_node(SILHOUETTE_SPOT)

var _silhouette: MeshInstance3D


func _ready() -> void:
	Dreams.seal_restored_signal.connect(_on_seal_restored)
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
	if id == MODULE:
		open_side_door()


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
