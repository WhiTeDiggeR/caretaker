class_name BowserDream
extends Node3D

## Bowser's dream, first dive S (docs/game_design/06-bowser-dream-world.md, sections 4–5):
## terrace → ledge and chain bridge → yard of the first fight → seal hall → bridge → bastion
## with the gate. Blockout of primitives (#182); the seal, the ambush and the remains are wired
## by later tasks through the named hook nodes below. Falling below the world counts as death
## (the lava area catches it first).

const FALL_LIMIT_Y := -20.0

## Hook nodes of the later tasks (R-2 seal, R-3 ambush, R-4 weapon by the remains).
const SEAL_SLOT := ^"SealHall/SealSlot"
const LEVER_SLOTS: Array[NodePath] = [^"SealHall/LeverSlot1", ^"SealHall/LeverSlot2", ^"SealHall/LeverSlot3"]
const SIDE_DOOR := ^"SealHall/SideDoor"
const WAKE_LINE := ^"Yard/Ambush/WakeLine"
const GUARD_SPAWNS: Array[NodePath] = [^"Yard/Ambush/GuardSpawnNorth", ^"Yard/Ambush/GuardSpawnSouth"]
const HALL_THRESHOLD := ^"Yard/Ambush/HallThreshold"
const REMAINS := ^"Yard/Remains"
const WEAPON_SPOT := ^"Yard/Remains/WeaponSpot"
const SILHOUETTE_SPOT := ^"Terrace/SilhouetteSpot"

@onready var _player: Node3D = $Player


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < FALL_LIMIT_Y:
		set_physics_process(false)
		Dreams.die()


## Waypoints of the main route on the walking surface, terrace to gate (used by checks and bots).
static func route() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(4, 0, 0), Vector3(25, 0, 0), Vector3(27, 1.2, 0), Vector3(46, 1.2, 0),
		Vector3(56, 1.2, 0), Vector3(70, 1.2, 0), Vector3(75, 1.2, -5), Vector3(80, 1.2, -6),
		Vector3(80, 1.2, -20), Vector3(80, 1.2, -24),
	])
