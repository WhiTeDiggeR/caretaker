extends Resource
class_name ComplexV3AnchorPlacement

const POLICY_NORMALIZED := "normalized"
const POLICY_FROM_START := "from_start_m"
const POLICY_FROM_END := "from_end_m"
const POLICY_CENTERED := "centered"
const POLICIES := [POLICY_NORMALIZED, POLICY_FROM_START, POLICY_FROM_END, POLICY_CENTERED]

@export_enum("normalized", "from_start_m", "from_end_m", "centered") var policy := POLICY_CENTERED
@export_range(0.0, 1.0, 0.001) var normalized_value := 0.5
@export var distance_m := 0.0
@export var centered_offset_m := 0.0
@export var normal_offset_m := 0.0
@export var height_m := 0.0
@export var yaw_pitch_roll_deg := Vector3.ZERO


func along_distance(length_m: float) -> Dictionary:
	match policy:
		POLICY_NORMALIZED:
			return {"ok": true, "distance_m": normalized_value * length_m}
		POLICY_FROM_START:
			return {"ok": true, "distance_m": distance_m}
		POLICY_FROM_END:
			return {"ok": true, "distance_m": length_m - distance_m}
		POLICY_CENTERED:
			return {"ok": true, "distance_m": length_m * 0.5 + centered_offset_m}
		_:
			return {"ok": false, "error": "unknown placement policy: %s" % policy}


func rotation_basis() -> Basis:
	var euler := Vector3(
		deg_to_rad(yaw_pitch_roll_deg.y),
		deg_to_rad(yaw_pitch_roll_deg.x),
		deg_to_rad(yaw_pitch_roll_deg.z)
	)
	return Basis.from_euler(euler, EULER_ORDER_YXZ)
