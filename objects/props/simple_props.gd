@tool
class_name SimpleProp
extends StaticBody3D

## Props of the opening without their own logic (docs/game_design/02-prop-standard.md): the
## emergency cabinet, a debris blockage, a fallen duct, an evacuation sign and the old
## control point's mnemonic board. Each shows its art model from loads/props (#241) with a
## simple box collision; inspect texts come from data/documents/opening.json.

enum Kind { EMERGENCY_CABINET, DEBRIS_BLOCKAGE, FALLEN_DUCT, EVAC_SIGN, MNEMONIC_BOARD }

const CABINET_MODEL := preload("res://loads/props/emergency_cabinet/emergency_cabinet.gltf")
const RUBBLE_MODEL := preload("res://loads/props/rubble_set/rubble_set.gltf")
const DUCT_MODEL := preload("res://loads/props/fallen_duct/fallen_duct.gltf")
const SIGN_MODEL := preload("res://loads/props/evac_sign/evac_sign.gltf")
const BOARD_MODEL := preload("res://loads/props/mnemonic_panel/mnemonic_panel.gltf")
## Width of the rubble model; a blockage of another `span` stretches it.
const RUBBLE_WIDTH := 4.5
const RUBBLE_SIZE := Vector3(RUBBLE_WIDTH, 2.5, 1.8)

@export var kind: Kind = Kind.EMERGENCY_CABINET
## Width of a blockage.
@export var span := 4.5
@export var sign_text := "МАРШРУТ A\nК АВАРИЙНОМУ БЛОКУ  →"


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
	PropKit.art(self, CABINET_MODEL)
	PropKit.collider(self, Vector3(0, 0.95, 0.027), Vector3(0.81, 1.9, 0.454))
	if not Engine.is_editor_hint():
		PropKit.interactable(self, Interactable.Mode.INSPECT, "ОТКРЫТЬ АВАРИЙНЫЙ ШКАФ", "emergency_cabinet_scheme")


func _debris() -> void:
	var stretch := span / RUBBLE_WIDTH
	PropKit.art(self, RUBBLE_MODEL, Vector3.ZERO, Vector3.ZERO, Vector3(stretch, 1, 1))
	PropKit.collider(self, Vector3(0, RUBBLE_SIZE.y * 0.5, 0), Vector3(span, RUBBLE_SIZE.y, RUBBLE_SIZE.z))


## The model's lower end hangs at 1.25 m: the hero passes under it crouching.
func _duct() -> void:
	PropKit.art(self, DUCT_MODEL)
	PropKit.collider(self, Vector3(-0.083, 2.025, 0), Vector3(3.4, 0.5, 0.6), Vector3(0, 0, deg_to_rad(-18.0)))


## Lit exit pictogram on the left, the route text on a plate to its right; centred on the
## origin as before (1.2 x 0.36 m).
func _sign() -> void:
	PropKit.art(self, SIGN_MODEL, Vector3(-0.4, -0.1, -0.015))
	PropKit.box(self, Vector3(0.2, 0, 0), Vector3(0.8, 0.36, 0.03), PropKit.material(Color(0.08, 0.38, 0.2), true), true)
	var text := PropKit.label(self, Vector3(0.2, 0, 0.02), sign_text, 30, Color(0.92, 1.0, 0.94))
	text.pixel_size = 0.0024


## Centred on the origin as before; the model's back stands on the wall plane at z = -0.025.
func _board() -> void:
	PropKit.art(self, BOARD_MODEL, Vector3(0, -0.6, -0.025))
	PropKit.collider(self, Vector3(0, 0, 0.061), Vector3(2.0, 1.2, 0.172))
	PropKit.label(self, Vector3(0, 0.66, 0.0), "СТАРОЕ ЯДРО · ТЕХНИЧЕСКИЙ УРОВЕНЬ", 30, Color(0.15, 0.17, 0.2))
	if not Engine.is_editor_hint():
		PropKit.interactable(self, Interactable.Mode.INSPECT, "ОСМОТРЕТЬ МНЕМОСХЕМУ", "old_cp_mnemonic")
