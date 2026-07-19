extends FacilityGridLevel

const SHELF := "res://objects/loaded_shelf.tscn"
const CABINET := "res://objects/loaded_cabinet.tscn"
const BED := "res://objects/medical_bed.tscn"
const SERVER := "res://objects/server_rack.tscn"
const TERMINAL := "res://objects/wall_terminal.tscn"
const PANEL := "res://scenes/control_panel.tscn"
const MONITOR := "res://scenes/containment_monitor.tscn"
const BOWSER_POD := "res://scenes/bowser_pod.tscn"
const GENERATOR := "res://objects/generator_unit.tscn"
const CRATE := "res://objects/industrial_crate.tscn"
const BARRIER := "res://objects/emergency_barrier.tscn"
const DEBRIS := "res://objects/debris_pile.tscn"
const DOCUMENT := "res://objects/facility_document.tscn"
const CAMERA := "res://objects/security_camera.tscn"


func _get_zones() -> Array[Dictionary]:
	return [
		{"id": "C01", "rect": Rect2i(-13, -2, 5, 5)},
		{"id": "L01_LANDING", "rect": Rect2i(-11, 7, 2, 2)},
		{"id": "L01_VERTICAL", "rect": Rect2i(-11, 3, 1, 4)},
		{"id": "L01_HORIZONTAL", "rect": Rect2i(-10, 3, 5, 1)},
		{"id": "L01_CONTROL_LINK", "rect": Rect2i(-5, 3, 1, 1)},
		{"id": "L02", "rect": Rect2i(-5, 4, 3, 3)},
		{"id": "L02_CORE_LINK", "rect": Rect2i(-4, 3, 1, 1)},
		{"id": "L03", "rect": Rect2i(-7, -2, 4, 5)},
		{"id": "L04", "rect": Rect2i(-1, 4, 3, 3)},
		{"id": "L04_LINK", "rect": Rect2i(-2, 5, 1, 1)},
		{"id": "L05", "rect": Rect2i(0, -2, 5, 5)},
		{"id": "L05_LINK", "rect": Rect2i(0, 3, 1, 1)},
		{"id": "C02", "rect": Rect2i(1, -7, 4, 4)},
		{"id": "C02_LINK", "rect": Rect2i(2, -3, 1, 1)},
		{"id": "C03", "rect": Rect2i(6, -2, 5, 5)},
		{"id": "C03_LINK", "rect": Rect2i(5, 0, 1, 1)},
		{"id": "C05", "rect": Rect2i(11, 3, 5, 5)},
		{"id": "C05_LINK", "rect": Rect2i(11, 2, 1, 1)},
		{"id": "L06", "rect": Rect2i(12, -4, 5, 4)},
		{"id": "L06_LINK", "rect": Rect2i(11, -1, 1, 1)},
		{"id": "CENTRAL_SHAFT", "rect": Rect2i(1, 7, 2, 2)},
		{"id": "GENERATOR_STAIR", "rect": Rect2i(-5, -3, 1, 1)},
	]


func _get_ceiling_holes() -> Array[Vector2i]:
	return [
		Vector2i(-11, 7), Vector2i(-10, 7),
		Vector2i(1, 7), Vector2i(2, 7),
	]


func _get_wall_openings() -> Array[Dictionary]:
	return [
		{"cell": Vector2i(-10, 8), "direction": Vector2i(0, 1)},
		{"cell": Vector2i(2, 8), "direction": Vector2i(0, 1)},
		{"cell": Vector2i(-5, -3), "direction": Vector2i(0, -1)},
	]


func _get_connections() -> Array[Dictionary]:
	return [
		{"from": "C01", "to": "L01_VERTICAL", "name": "C01BrokenOuterDoor", "door": true},
		{"from": "L01_VERTICAL", "to": "L01_LANDING"},
		{"from": "L01_VERTICAL", "to": "L01_HORIZONTAL"},
		{"from": "L01_HORIZONTAL", "to": "L01_CONTROL_LINK"},
		{"from": "L01_CONTROL_LINK", "to": "L02", "name": "OldControlDoor", "door": true},
		{"from": "L02", "to": "L02_CORE_LINK", "name": "OldCoreDoor", "door": true},
		{"from": "L02_CORE_LINK", "to": "L03"},
		{"from": "L02", "to": "L04_LINK", "name": "ArchiveDoor", "door": true},
		{"from": "L04_LINK", "to": "L04"},
		{"from": "L04", "to": "L05_LINK", "name": "LaboratoryDoor", "door": true},
		{"from": "L05_LINK", "to": "L05"},
		{"from": "L05", "to": "C02_LINK"},
		{"from": "C02_LINK", "to": "C02", "name": "C02Door", "door": true},
		{"from": "L05", "to": "C03_LINK", "name": "C03OuterDoor", "door": true},
		{"from": "C03_LINK", "to": "C03", "name": "C03InnerDoor", "door": true},
		{"from": "C03", "to": "C05_LINK", "name": "C05Door", "door": true},
		{"from": "C05_LINK", "to": "C05"},
		{"from": "C03", "to": "L06_LINK", "name": "FreightDoor", "door": true},
		{"from": "L06_LINK", "to": "L06"},
		{"from": "L04", "to": "CENTRAL_SHAFT", "name": "CentralShortcutDoor", "door": true},
		{"from": "L03", "to": "GENERATOR_STAIR", "name": "GeneratorStairDoor", "door": true},
	]


func _get_lights() -> Array[Dictionary]:
	return [
		{"name": "EvacLandingLight", "position": Vector3(-50.0, 3.75, 40.0), "flicker": true},
		{"name": "EvacCorridorLightA", "position": Vector3(-52.5, 3.75, 27.5)},
		{"name": "EvacCorridorLightB", "position": Vector3(-42.5, 3.75, 17.5), "flicker": true},
		{"name": "EvacCorridorLightC", "position": Vector3(-27.5, 3.75, 17.5)},
		{"name": "OldControlEntryLight", "position": Vector3(-22.5, 3.75, 22.5)},
		{"name": "C01Emergency", "position": Vector3(-52.5, 2.8, 14.65), "emergency": true},
		{"name": "C01Light", "position": Vector3(-52.5, 3.75, 2.5), "flicker": true},
		{"name": "OldControlLight", "position": Vector3(-17.5, 3.75, 27.5)},
		{"name": "OldCoreLightA", "position": Vector3(-30.0, 3.75, 7.5)},
		{"name": "OldCoreLightB", "position": Vector3(-20.0, 3.75, -2.5), "flicker": true},
		{"name": "ArchiveLight", "position": Vector3(2.5, 3.75, 27.5)},
		{"name": "LabLightA", "position": Vector3(7.5, 3.75, 7.5)},
		{"name": "LabLightB", "position": Vector3(17.5, 3.75, -2.5)},
		{"name": "C02Light", "position": Vector3(15.0, 3.75, -25.0), "flicker": true},
		{"name": "C03LightA", "position": Vector3(37.5, 3.75, -2.5)},
		{"name": "C03LightB", "position": Vector3(47.5, 3.75, 7.5)},
		{"name": "C03Emergency", "position": Vector3(30.3, 2.8, 2.5), "emergency": true, "rotation": Vector3(0.0, 90.0, 0.0)},
		{"name": "C05LightA", "position": Vector3(62.5, 3.75, 22.5)},
		{"name": "C05LightB", "position": Vector3(72.5, 3.75, 32.5), "flicker": true},
		{"name": "FreightLightA", "position": Vector3(67.5, 3.75, -12.5)},
		{"name": "FreightLightB", "position": Vector3(77.5, 3.75, -2.5)},
	]


func _get_props() -> Array[Dictionary]:
	return [
		{"scene": BARRIER, "position": Vector3(-57.0, 0.0, 10.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": BARRIER, "position": Vector3(-57.0, 0.0, 4.5), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": BARRIER, "position": Vector3(-47.0, 0.0, 10.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": DEBRIS, "position": Vector3(-51.0, 0.0, 12.5), "scale": 1.4},
		{"scene": DEBRIS, "position": Vector3(-48.0, 0.0, 13.0), "scale": 1.2},
		{"scene": CRATE, "position": Vector3(-61.0, 0.0, -6.0)},
		{"scene": PANEL, "position": Vector3(-23.0, 0.0, 23.0)},
		{"scene": PANEL, "position": Vector3(-12.0, 0.0, 23.0), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": MONITOR, "position": Vector3(-17.5, 0.0, 32.0), "rotation": Vector3(0.0, 180.0, 0.0), "scale": 0.68},
		{"scene": TERMINAL, "position": Vector3(-10.35, 1.3, 27.5), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": DEBRIS, "position": Vector3(-32.0, 0.0, 10.0)},
		{"scene": GENERATOR, "position": Vector3(-31.0, 0.0, -5.0)},
		{"scene": CABINET, "position": Vector3(-16.0, 0.0, -7.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": SHELF, "position": Vector3(-3.5, 0.0, 22.0)},
		{"scene": SHELF, "position": Vector3(2.5, 0.0, 22.0)},
		{"scene": SHELF, "position": Vector3(7.5, 0.0, 22.0)},
		{"scene": CABINET, "position": Vector3(-3.5, 0.0, 33.0), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": DOCUMENT, "position": Vector3(2.5, 1.0, 25.0)},
		{"scene": PANEL, "position": Vector3(3.0, 0.0, 10.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": PANEL, "position": Vector3(20.0, 0.0, 10.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": SERVER, "position": Vector3(3.0, 0.0, -7.0)},
		{"scene": SERVER, "position": Vector3(7.0, 0.0, -7.0)},
		{"scene": TERMINAL, "position": Vector3(12.5, 1.3, 14.65), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": BED, "name": "ChemicalSleepRig", "position": Vector3(15.0, 0.0, -25.0)},
		{"scene": GENERATOR, "position": Vector3(7.5, 0.0, -31.0)},
		{"scene": CABINET, "position": Vector3(23.0, 0.0, -31.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": BOWSER_POD, "name": "Object03Placeholder", "position": Vector3(44.0, 1.0, 2.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": PANEL, "position": Vector3(33.0, 0.0, -7.0)},
		{"scene": MONITOR, "position": Vector3(33.0, 0.0, 10.0), "rotation": Vector3(0.0, 180.0, 0.0), "scale": 0.68},
		{"scene": SERVER, "position": Vector3(52.0, 0.0, -7.0)},
		{"scene": CAMERA, "position": Vector3(31.0, 3.0, 12.0), "rotation": Vector3(0.0, 135.0, 0.0), "scale": 0.35},
		{"scene": PANEL, "position": Vector3(58.0, 0.0, 20.0)},
		{"scene": SERVER, "position": Vector3(77.0, 0.0, 37.0)},
		{"scene": CRATE, "position": Vector3(61.5, 0.0, 36.0)},
		{"scene": CRATE, "position": Vector3(65.5, 0.0, 36.0)},
		{"scene": CRATE, "position": Vector3(64.0, 0.0, -17.0)},
		{"scene": CRATE, "position": Vector3(69.0, 0.0, -17.0)},
		{"scene": SHELF, "position": Vector3(82.0, 0.0, -15.0), "rotation": Vector3(0.0, -90.0, 0.0)},
	]


func _get_signs() -> Array[Dictionary]:
	return [
		{"text": "ВНЕШНИЙ ШЛЮЗ №1 — ОПАСНО", "position": Vector3(-52.5, 2.8, 14.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "РЕЗЕРВНЫЙ ПУНКТ УПРАВЛЕНИЯ", "position": Vector3(-17.5, 2.8, 20.3)},
		{"text": "СТАРОЕ ЯДРО", "position": Vector3(-25.0, 2.8, 14.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "АРХИВ", "position": Vector3(2.5, 2.8, 20.3)},
		{"text": "ЛАБОРАТОРИЯ СНА", "position": Vector3(12.5, 2.8, 14.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "ОБЪЕКТ №2 — ХИМИЧЕСКИЙ СОН", "position": Vector3(15.0, 2.8, -15.3), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "ОБЪЕКТ №3 — ОПЫТНЫЙ МОДУЛЬ", "position": Vector3(42.5, 2.8, 14.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "ОБЪЕКТ №5 — СЕКТОР ОТКЛЮЧЁН", "position": Vector3(67.5, 2.8, 15.3)},
		{"text": "ГРУЗОВОЙ ТОННЕЛЬ", "position": Vector3(72.5, 2.8, -19.7)},
	]
