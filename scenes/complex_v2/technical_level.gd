extends FacilityGridLevel

const SHELF := "res://objects/loaded_shelf.tscn"
const CABINET := "res://objects/loaded_cabinet.tscn"
const WORKBENCH := "res://objects/workbench.tscn"
const SERVER := "res://objects/server_rack.tscn"
const TERMINAL := "res://objects/wall_terminal.tscn"
const GENERATOR := "res://objects/generator_unit.tscn"
const CRATE := "res://objects/industrial_crate.tscn"
const BARRIER := "res://objects/emergency_barrier.tscn"
const DEBRIS := "res://objects/debris_pile.tscn"


func _get_zones() -> Array[Dictionary]:
	return [
		{"id": "T01", "rect": Rect2i(-7, -2, 5, 5)},
		{"id": "T01_STAIR", "rect": Rect2i(-4, -3, 1, 1)},
		{"id": "T02", "rect": Rect2i(-1, -2, 5, 4)},
		{"id": "T02_LINK", "rect": Rect2i(-2, 0, 1, 1)},
		{"id": "T03", "rect": Rect2i(-1, -7, 4, 4)},
		{"id": "T03_LINK", "rect": Rect2i(1, -3, 1, 1)},
		{"id": "T04", "rect": Rect2i(5, -2, 4, 4)},
		{"id": "T04_LINK", "rect": Rect2i(4, 0, 1, 1)},
		{"id": "T05", "rect": Rect2i(7, 2, 1, 4)},
		{"id": "T05_ROOM", "rect": Rect2i(5, 6, 4, 3)},
		{"id": "T06_TUNNEL", "rect": Rect2i(9, -1, 3, 1)},
		{"id": "T06", "rect": Rect2i(12, -4, 5, 4)},
	]


func _get_ceiling_holes() -> Array[Vector2i]:
	return [Vector2i(-4, -3)]


func _get_wall_openings() -> Array[Dictionary]:
	return [
		{"cell": Vector2i(-4, -3), "direction": Vector2i(0, -1)},
	]


func _get_connections() -> Array[Dictionary]:
	return [
		{"from": "T01", "to": "T01_STAIR"},
		{"from": "T01", "to": "T02_LINK", "name": "GeneratorWorkshopDoor", "door": true},
		{"from": "T02_LINK", "to": "T02"},
		{"from": "T02", "to": "T03_LINK", "name": "WaterTreatmentDoor", "door": true},
		{"from": "T03_LINK", "to": "T03"},
		{"from": "T02", "to": "T04_LINK", "name": "SubstationDoor", "door": true},
		{"from": "T04_LINK", "to": "T04"},
		{"from": "T04", "to": "T05", "name": "CableTunnelDoor", "door": true},
		{"from": "T05", "to": "T05_ROOM"},
		{"from": "T04", "to": "T06_TUNNEL", "name": "FreightTechnicalDoor", "door": true},
		{"from": "T06_TUNNEL", "to": "T06"},
	]


func _get_lights() -> Array[Dictionary]:
	return [
		{"name": "GeneratorLightA", "position": Vector3(-30.0, 3.75, -2.5)},
		{"name": "GeneratorLightB", "position": Vector3(-20.0, 3.75, 7.5), "flicker": true},
		{"name": "GeneratorEmergency", "position": Vector3(-10.3, 2.8, 2.5), "emergency": true, "rotation": Vector3(0.0, -90.0, 0.0)},
		{"name": "WorkshopLightA", "position": Vector3(2.5, 3.75, -2.5)},
		{"name": "WorkshopLightB", "position": Vector3(12.5, 3.75, 2.5)},
		{"name": "WaterLightA", "position": Vector3(2.5, 3.75, -27.5), "flicker": true},
		{"name": "WaterLightB", "position": Vector3(12.5, 3.75, -17.5)},
		{"name": "SubstationLightA", "position": Vector3(30.0, 3.75, -2.5)},
		{"name": "SubstationLightB", "position": Vector3(40.0, 3.75, 2.5)},
		{"name": "CableLightA", "position": Vector3(37.5, 3.75, 17.5), "flicker": true},
		{"name": "CableLightB", "position": Vector3(37.5, 3.75, 32.5)},
		{"name": "FreightTunnelLight", "position": Vector3(52.5, 3.75, -2.5)},
		{"name": "FreightLightA", "position": Vector3(67.5, 3.75, -12.5)},
		{"name": "FreightLightB", "position": Vector3(77.5, 3.75, -2.5), "flicker": true},
	]


func _get_props() -> Array[Dictionary]:
	return [
		{"scene": GENERATOR, "name": "MainGeneratorA", "position": Vector3(-30.0, 0.0, -5.0)},
		{"scene": GENERATOR, "name": "MainGeneratorB", "position": Vector3(-22.5, 0.0, -5.0)},
		{"scene": GENERATOR, "name": "MainGeneratorC", "position": Vector3(-30.0, 0.0, 7.5), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": GENERATOR, "name": "MainGeneratorD", "position": Vector3(-22.5, 0.0, 7.5), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": TERMINAL, "position": Vector3(-10.35, 1.3, 7.5), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": BARRIER, "position": Vector3(-15.0, 0.0, 12.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"scene": DEBRIS, "position": Vector3(-13.0, 0.0, -7.0)},
		{"scene": WORKBENCH, "position": Vector3(0.0, 0.0, -7.0)},
		{"scene": WORKBENCH, "position": Vector3(8.0, 0.0, -7.0)},
		{"scene": SHELF, "position": Vector3(18.0, 0.0, -6.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": SHELF, "position": Vector3(18.0, 0.0, 1.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": CABINET, "position": Vector3(0.0, 0.0, 8.0), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": CRATE, "position": Vector3(13.0, 0.0, 7.0)},
		{"scene": CRATE, "position": Vector3(16.0, 0.0, 7.0)},
		{"scene": GENERATOR, "name": "WaterPumpA", "position": Vector3(0.0, 0.0, -31.0)},
		{"scene": GENERATOR, "name": "WaterPumpB", "position": Vector3(10.0, 0.0, -31.0)},
		{"scene": CABINET, "position": Vector3(13.0, 0.0, -18.0), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": SERVER, "name": "SubstationRackA", "position": Vector3(28.0, 0.0, -7.0)},
		{"scene": SERVER, "name": "SubstationRackB", "position": Vector3(34.0, 0.0, -7.0)},
		{"scene": SERVER, "name": "SubstationRackC", "position": Vector3(40.0, 0.0, -7.0)},
		{"scene": TERMINAL, "position": Vector3(44.65, 1.3, 2.5), "rotation": Vector3(0.0, -90.0, 0.0)},
		{"scene": BARRIER, "position": Vector3(37.5, 0.0, 17.5)},
		{"scene": DEBRIS, "position": Vector3(37.5, 0.0, 26.0)},
		{"scene": WORKBENCH, "position": Vector3(28.0, 0.0, 33.0)},
		{"scene": CABINET, "position": Vector3(42.0, 0.0, 42.0), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"scene": CRATE, "position": Vector3(63.0, 0.0, -17.0)},
		{"scene": CRATE, "position": Vector3(68.0, 0.0, -17.0)},
		{"scene": CRATE, "position": Vector3(73.0, 0.0, -17.0)},
		{"scene": SHELF, "position": Vector3(82.0, 0.0, -14.0), "rotation": Vector3(0.0, -90.0, 0.0)},
	]


func _get_signs() -> Array[Dictionary]:
	return [
		{"text": "ГЛАВНЫЙ ГЕНЕРАТОР", "position": Vector3(-22.5, 2.8, 14.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "МАСТЕРСКАЯ / СКЛАД", "position": Vector3(7.5, 2.8, 9.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "ВОДА И ВЕНТИЛЯЦИЯ", "position": Vector3(7.5, 2.8, -15.3), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "СЕКТОРНЫЕ ПОДСТАНЦИИ", "position": Vector3(35.0, 2.8, 9.7), "rotation": Vector3(0.0, 180.0, 0.0)},
		{"text": "КАБЕЛЬНЫЙ ТОННЕЛЬ", "position": Vector3(37.5, 2.8, 10.3)},
		{"text": "НИЖНИЙ ГРУЗОВОЙ УЗЕЛ", "position": Vector3(72.5, 2.8, -19.7)},
	]
