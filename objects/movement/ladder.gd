@tool
class_name Ladder
extends StaticBody3D

## Vertical ladder (rungs between two rails). The origin is at the foot of the ladder on its
## plane; the climbing side faces +Z and the landing lies behind it, towards -Z, at `height`.
## The rails continue HANDRAIL above the landing so the ladder can be grabbed from the top.
## The hero grabs it with the interact key (Player.attach_ladder): from below to climb up,
## from the landing to climb down. Sizes: docs/game_design/02-prop-standard.md.

const WIDTH := 0.6
const RAIL := 0.05
const RUNG_STEP := 0.3
const RUNG_RADIUS := 0.02
## Distance of the hero's body axis from the ladder plane while climbing.
const STANDOFF := 0.45
const HANDRAIL := 1.0
## How far onto the landing the hero steps at the top.
const EXIT_DEPTH := 0.6
const GRAB_DEPTH := 0.1

@export_range(1.0, 12.0, 0.1) var height := 3.0:
	set(value):
		height = value
		if is_inside_tree():
			_build()

var grab: Interactable
var top_grab: Interactable


func _ready() -> void:
	_build()


## World height of the landing.
func top_y() -> float:
	return global_position.y + height


func bottom_y() -> float:
	return global_position.y


## Body origin of a climbing hero whose feet are at `feet_y`.
func body_position(feet_y: float, half_height: float) -> Vector3:
	var point := global_position + global_basis.z * STANDOFF
	return Vector3(point.x, feet_y + half_height, point.z)


## Body origin of a hero standing on the landing after climbing up.
func exit_position(half_height: float) -> Vector3:
	var point := global_position - global_basis.z * EXIT_DEPTH
	return Vector3(point.x, top_y() + half_height + 0.01, point.z)


func _build() -> void:
	for child in get_children():
		if not child.owner:
			remove_child(child)
			child.queue_free()
	var metal := PropKit.material(Color(0.55, 0.5, 0.2))
	var total := height + HANDRAIL
	for side: float in [-1.0, 1.0]:
		PropKit.box(self, Vector3(side * WIDTH * 0.5, total * 0.5, 0), Vector3(RAIL, total, RAIL), metal)
	var rung := height - RUNG_STEP * 0.5
	var y := RUNG_STEP
	while y <= rung + 0.001:
		PropKit.box(self, Vector3(0, y, 0), Vector3(WIDTH, RUNG_RADIUS * 2.0, RUNG_RADIUS * 2.0), metal)
		y += RUNG_STEP
	# One flat grab box over the ladder plane (easy to aim at) and one over the handrails.
	PropKit.box(self, Vector3(0, height * 0.5, 0), Vector3(WIDTH + RAIL, height, GRAB_DEPTH), null, true).visible = false
	var top := StaticBody3D.new()
	top.name = "TopGrab"
	add_child(top)
	PropKit.box(top, Vector3(0, height + HANDRAIL * 0.5, 0), Vector3(WIDTH + RAIL, HANDRAIL, GRAB_DEPTH), null, true).visible = false
	if Engine.is_editor_hint():
		return
	grab = PropKit.interactable(self, Interactable.Mode.PRESS, "ВЗЯТЬСЯ ЗА ЛЕСТНИЦУ")
	grab.interacted.connect(_on_grab)
	top_grab = PropKit.interactable(top, Interactable.Mode.PRESS, "СПУСТИТЬСЯ ПО ЛЕСТНИЦЕ")
	top_grab.interacted.connect(_on_grab)


func _on_grab() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.has_method("attach_ladder"):
		player.call("attach_ladder", self)
