@tool
class_name SimpleProp
extends StaticBody3D

## Placeholder props of the opening without their own logic (docs/game_design/02-prop-standard.md):
## the emergency cabinet, a debris blockage, a fallen duct, an evacuation sign and the
## old control point's mnemonic board. Sizes follow the standard; inspect texts come from
## data/documents/opening.json.

enum Kind { EMERGENCY_CABINET, DEBRIS_BLOCKAGE, FALLEN_DUCT, EVAC_SIGN, MNEMONIC_BOARD }

@export var kind: Kind = Kind.EMERGENCY_CABINET
## Width of a blockage or the span of a duct.
@export var span := 4.5
## Free height under a fallen duct (crouch: 1.05–1.8 m).
@export var clearance := 1.25
@export var sign_text := "МАРШРУТ A\nК АВАРИЙНОМУ БЛОКУ  →"
@export var layout_seed := 7


func _ready() -> void:
	match kind:
		Kind.EMERGENCY_CABINET:
			_cabinet()
		Kind.DEBRIS_BLOCKAGE:
			_debris()
		Kind.FALLEN_DUCT:
			_duct()
		Kind.EVAC_SIGN:
			_sign()
		Kind.MNEMONIC_BOARD:
			_board()


func _cabinet() -> void:
	var red := PropKit.material(Color(0.6, 0.12, 0.1))
	PropKit.box(self, Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.4), PropKit.material(Color(0.32, 0.34, 0.33)), true)
	PropKit.box(self, Vector3(0, 0.95, 0.205), Vector3(0.72, 1.8, 0.02), PropKit.material(Color(0.42, 0.44, 0.43)))
	PropKit.box(self, Vector3(0, 1.62, 0.22), Vector3(0.72, 0.16, 0.02), red)
	PropKit.label(self, Vector3(0, 1.62, 0.235), "АВАРИЙНЫЙ ШКАФ", 36)
	if not Engine.is_editor_hint():
		PropKit.interactable(self, Interactable.Mode.INSPECT, "ОТКРЫТЬ АВАРИЙНЫЙ ШКАФ", "emergency_cabinet_scheme")


func _debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var concrete := PropKit.material(Color(0.4, 0.39, 0.37))
	var steel := PropKit.material(Color(0.28, 0.24, 0.22))
	var height := 2.6
	var shape := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(span, height, 1.6)
	shape.shape = block
	shape.position = Vector3(0, height * 0.5, 0)
	add_child(shape)
	for index in 9:
		var size := Vector3(rng.randf_range(1.2, 2.4), rng.randf_range(0.25, 0.5), rng.randf_range(0.8, 1.6))
		var position := Vector3(rng.randf_range(-span * 0.4, span * 0.4), rng.randf_range(0.2, height - 0.3), rng.randf_range(-0.4, 0.4))
		PropKit.box(self, position, size, concrete, false, Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.7, 0.7)))
	for index in 3:
		PropKit.box(self, Vector3(rng.randf_range(-span * 0.3, span * 0.3), rng.randf_range(0.8, 2.0), 0.3), Vector3(span * 0.7, 0.18, 0.18), steel, false,
				Vector3(0, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.5)))


func _duct() -> void:
	var metal := PropKit.material(Color(0.5, 0.52, 0.53))
	PropKit.box(self, Vector3(0, clearance + 0.3, 0), Vector3(span, 0.6, 0.6), metal, true, Vector3(0, 0, deg_to_rad(4.0)))
	PropKit.box(self, Vector3(-span * 0.5 + 0.2, (clearance + 0.3) * 0.5, 0), Vector3(0.08, clearance + 0.3, 0.08), PropKit.material(Color(0.3, 0.3, 0.3)), true)
	PropKit.box(self, Vector3(span * 0.5 - 0.2, clearance + 1.4, 0), Vector3(0.08, 1.6, 0.08), PropKit.material(Color(0.3, 0.3, 0.3)))


func _sign() -> void:
	PropKit.box(self, Vector3(0, 0, 0), Vector3(1.2, 0.36, 0.03), PropKit.material(Color(0.08, 0.38, 0.2), true), true)
	var text := PropKit.label(self, Vector3(0, 0, 0.02), sign_text, 30, Color(0.92, 1.0, 0.94))
	text.pixel_size = 0.0024


func _board() -> void:
	PropKit.box(self, Vector3(0, 0, 0), Vector3(2.0, 1.2, 0.05), PropKit.material(Color(0.82, 0.8, 0.72)), true)
	var ink := PropKit.material(Color(0.15, 0.17, 0.2))
	for segment: Array in [[Vector3(-0.5, 0.25, 0.03), Vector3(0.6, 0.03, 0.01)], [Vector3(0.1, 0.0, 0.03), Vector3(0.03, 0.5, 0.01)],
			[Vector3(0.35, -0.25, 0.03), Vector3(0.5, 0.03, 0.01)], [Vector3(-0.6, -0.1, 0.03), Vector3(0.22, 0.18, 0.01)],
			[Vector3(0.65, 0.3, 0.03), Vector3(0.22, 0.18, 0.01)]]:
		PropKit.box(self, segment[0], segment[1], ink)
	PropKit.box(self, Vector3(0.55, -0.2, 0.031), Vector3(0.7, 0.55, 0.005), PropKit.material(Color(0.4, 0.38, 0.35)))
	PropKit.label(self, Vector3(0, 0.5, 0.03), "СТАРОЕ ЯДРО · ТЕХНИЧЕСКИЙ УРОВЕНЬ", 30, Color(0.15, 0.17, 0.2))
	if not Engine.is_editor_hint():
		PropKit.interactable(self, Interactable.Mode.INSPECT, "ОСМОТРЕТЬ МНЕМОСХЕМУ", "old_cp_mnemonic")
