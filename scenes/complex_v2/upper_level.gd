extends FacilityGridLevel

const BED := "res://objects/medical_bed.tscn"
const CABINET := "res://objects/loaded_cabinet.tscn"
const LOCKER := "res://objects/loaded_locker.tscn"
const TABLE := "res://objects/staff_table.tscn"
const SERVER := "res://objects/server_rack.tscn"
const CAMERA := "res://objects/security_camera.tscn"
const TERMINAL := "res://objects/wall_terminal.tscn"
const PANEL := "res://scenes/control_panel.tscn"
const MONITOR := "res://scenes/containment_monitor.tscn"
const HEROBRINE_POD := "res://scenes/herobrine_pod.tscn"
const CRATE := "res://objects/industrial_crate.tscn"
const BARRIER := "res://objects/emergency_barrier.tscn"


func _get_zones() -> Array[Dictionary]:
	return [
		{"id": "U01", "rect": Rect2i(-12, -4, 4, 4)},
		{"id": "U03A", "rect": Rect2i(-11, 0, 1, 7)},
		{"id": "U03B", "rect": Rect2i(-11, 7, 2, 2)},
		{"id": "U02", "rect": Rect2i(-7, -4, 3, 3)},
		{"id": "U02_LINK", "rect": Rect2i(-4, -3, 1, 1)},
		{"id": "U05", "rect": Rect2i(-3, -4, 4, 4)},
		{"id": "U05_CONTROL_LINK", "rect": Rect2i(0, 0, 1, 1)},
		{"id": "U04", "rect": Rect2i(-2, 1, 5, 5)},
		{"id": "U07", "rect": Rect2i(2, -3, 3, 2)},
		{"id": "U07_LINK_A", "rect": Rect2i(1, -2, 1, 1)},
		{"id": "U07_LINK_B", "rect": Rect2i(2, -1, 1, 2)},
		{"id": "U06", "rect": Rect2i(4, 1, 3, 4)},
		{"id": "U06_LINK", "rect": Rect2i(3, 3, 1, 1)},
		{"id": "C04_LINK", "rect": Rect2i(7, 1, 1, 1)},
		{"id": "C04", "rect": Rect2i(8, -3, 5, 5)},
		{"id": "C06_LINK", "rect": Rect2i(7, 4, 3, 1)},
		{"id": "C06", "rect": Rect2i(9, 5, 5, 5)},
		{"id": "U08_LINK", "rect": Rect2i(13, -1, 1, 1)},
		{"id": "U08", "rect": Rect2i(14, -2, 3, 4)},
		{"id": "CENTRAL_SHAFT", "rect": Rect2i(1, 6, 2, 2)},
	]


func _get_ceiling_holes() -> Array[Vector2i]:
	return [
		Vector2i(-10, 8), Vector2i(-10, 7),
		Vector2i(2, 7), Vector2i(2, 6),
	]


func _get_wall_openings() -> Array[Dictionary]:
	return [
		{"cell": Vector2i(-10, 8), "direction": Vector2i(0, 1)},
		{"cell": Vector2i(2, 7), "direction": Vector2i(0, 1)},
	]


func _get_doors() -> Array[Dictionary]:
	return [
		{"name": "EmergencyManualDoor", "position": Vector3(-52.5, 0.0, 0.0)},
		{"name": "MedicalDoor", "position": Vector3(-20.0, 0.0, -12.5), "rotation_y": 90.0},
		{"name": "StaffControlDoor", "position": Vector3(2.5, 0.0, 2.5)},
		{"name": "ServerDoor", "position": Vector3(7.5, 0.0, -7.5), "rotation_y": 90.0},
		{"name": "ControlSecurityDoor", "position": Vector3(17.5, 0.0, 17.5), "rotation_y": 90.0},
		{"name": "SecurityC04Door", "position": Vector3(37.5, 0.0, 7.5), "rotation_y": 90.0},
		{"name": "C04InnerDoor", "position": Vector3(42.5, 0.0, 7.5), "rotation_y": 90.0},
		{"name": "SecurityC06Door", "position": Vector3(37.5, 0.0, 22.5), "rotation_y": 90.0},
		{"name": "C06InnerDoor", "position": Vector3(47.5, 0.0, 25.0)},
		{"name": "FreightDoor", "position": Vector3(67.5, 0.0, -2.5), "rotation_y": 90.0},
		{"name": "CentralShortcutDoor", "position": Vector3(10.0, 0.0, 30.0)},
	]


func _get_lights() -> Array[Dictionary]:
	return [
		{"name": "EmergencySleepLightA", "position": Vector3(-55.0, 3.75, -15.0)},
		{"name": "EmergencySleepLightB", "position": Vector3(-45.0, 3.75, -5.0), "flicker": true},
		{"name": "EvacLightA", "position": Vector3(-52.5, 3.75, 7.5), "flicker": true},
		{"name": "EvacLightB", "position": Vector3(-52.5, 3.75, 22.5)},
		{"name": "EvacEmergency", "position": Vector3(-54.7, 2.7, 32.5), "emergency": true, "rotation": Vector3(0.0, 90.0, 0.0)},
		{"name": "MedicalLight", "position": Vector3(-27.5, 3.75, -17.5)},
		{"name": "StaffLightA", "position": Vector3(-10.0, 3.75, -15.0)},
		{"name": "StaffLightB", "position": Vector3(0.0, 3.75, -5.0)},
		{"name": "ControlLightA", "position": Vector3(-2.5, 3.75, 12.5)},
		{"name": "ControlLightB", "position": Vector3(7.5, 3.75, 22.5)},
		{"name": "ServerLight", "position": Vector3(17.5, 3.75, -10.0)},
		{"name": "SecurityLight", "position": Vector3(27.5, 3.75, 15.0)},
		{"name": "C04LightA", "position": Vector3(47.5, 3.75, -7.5)},
		{"name": "C04LightB", "position": Vector3(57.5, 3.75, 2.5), "flicker": true},
		{"name": "C04Emergency", "position": Vector3(40.3, 2.8, 7.5), "emergency": true, "rotation": Vector3(0.0, 90.0, 0.0)},
		{"name": "C06LightA", "position": Vector3(52.5, 3.75, 32.5)},
		{"name": "C06LightB", "position": Vector3(62.5, 3.75, 42.5), "flicker": true},
		{"name": "FreightLight", "position": Vector3(77.5, 3.75, 2.5)},
	]


func _get_props() -> Array[Dictionary]:
	return [
		{"scene": BED, "name": "PersonnelPodPlaceholderA", "position": Vector3(-57.0, 0.0, -16.5), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": BED, "name": "PersonnelPodPlaceholderB", "position": Vector3(-57.0, 0.0, -11.5), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": BED, "name": "PersonnelPodPlaceholderC", "position": Vector3(-43.0, 0.0, -16.5), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": CABINET, "position": Vector3(-57.0, 0.0, -3.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": TERMINAL, "position": Vector3(-47.5, 1.3, -19.65)},
		{"scene": BARRIER, "position": Vector3(-52.5, 0.0, 30.0), "rotation": Vector3(0.0, 0.0, 0.0)},
		{"scene": BED, "position": Vector3(-32.5, 0.0, -22.0)},
		{"scene": BED, "position": Vector3(-25.0, 0.0, -22.0)},
		{"scene": CABINET, "position": Vector3(-21.0, 0.0, -15.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": TABLE, "position": Vector3(-8.5, 0.0, -14.0)},
		{"scene": TABLE, "position": Vector3(-1.5, 0.0, -14.0)},
		{"scene": LOCKER, "position": Vector3(-13.7, 0.0, -3.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": LOCKER, "position": Vector3(-13.7, 0.0, -5.2), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": LOCKER, "position": Vector3(-13.7, 0.0, -7.4), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": PANEL, "position": Vector3(-5.0, 0.0, 12.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": PANEL, "position": Vector3(9.0, 0.0, 12.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": MONITOR, "position": Vector3(2.5, 0.0, 25.0), "rotation": Vector3(0.0, 180.0, 0.0), "scale": 0.68},
		{"scene": SERVER, "position": Vector3(13.0, 0.0, -13.0)},
		{"scene": SERVER, "position": Vector3(17.0, 0.0, -13.0)},
		{"scene": SERVER, "position": Vector3(21.0, 0.0, -13.0)},
		{"scene": CAMERA, "position": Vector3(21.0, 3.0, 7.0), "rotation": Vector3(0.0, 45.0, 0.0), "scale": 0.35},
		{"scene": CABINET, "position": Vector3(32.0, 0.0, 8.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": TERMINAL, "position": Vector3(34.65, 1.35, 17.5), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": HEROBRINE_POD, "name": "Object04Placeholder", "position": Vector3(54.0, 1.0, -2.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": PANEL, "position": Vector3(44.0, 0.0, -11.5)},
		{"scene": MONITOR, "position": Vector3(44.0, 0.0, 4.0), "rotation": Vector3(0.0, 180.0, 0.0), "scale": 0.68},
		{"scene": SERVER, "position": Vector3(62.0, 0.0, -11.5)},
		{"scene": CRATE, "position": Vector3(50.0, 0.0, 45.0)},
		{"scene": CRATE, "position": Vector3(54.0, 0.0, 45.0)},
		{"scene": PANEL, "position": Vector3(66.0, 0.0, 28.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": SERVER, "position": Vector3(66.0, 0.0, 46.0)},
		{"scene": CRATE, "position": Vector3(73.0, 0.0, -7.0)},
		{"scene": CRATE, "position": Vector3(78.0, 0.0, -7.0)},
	]


func _get_signs() -> Array[Dictionary]:
	return [
		{"text": "АВАРИЙНЫЙ БЛОК ПЕРСОНАЛА", "position": Vector3(-50.0, 2.8, -19.7)},
		{"text": "РУЧНОЙ ЭВАКУАЦИОННЫЙ ПУТЬ", "position": Vector3(-52.5, 2.8, 0.3), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "МЕДИЦИНСКИЙ ОТСЕК", "position": Vector3(-27.5, 2.8, -24.7)},
		{"text": "БЫТОВОЕ КРЫЛО", "position": Vector3(-5.0, 2.8, -19.7)},
		{"text": "ЦЕНТРАЛЬНОЕ УПРАВЛЕНИЕ", "position": Vector3(2.5, 2.8, 5.3)},
		{"text": "СЛУЖБА БЕЗОПАСНОСТИ", "position": Vector3(27.5, 2.8, 5.3)},
		{"text": "ОБЪЕКТ №4", "position": Vector3(52.5, 2.8, 9.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "ОБЪЕКТ №6 — СЕКТОР ОТКЛЮЧЁН", "position": Vector3(57.5, 2.8, 25.3)},
		{"text": "ГРУЗОВОЙ ЛИФТ / ПОВЕРХНОСТЬ НЕДОСТУПНА", "position": Vector3(77.5, 2.8, 9.7), "rotation": Vector3(0.0, 180.0, 0.0)},
	]
