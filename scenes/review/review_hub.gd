class_name ReviewHub
extends Node3D

## Review hall (#192): one place for the author's manual check of everything delivered.
## A ring of stations, one per item of ReviewStations; stepping on a station's pad loads its
## scene and spot through Debug.go_to, F9 (ReviewReturn) brings the hero back here.
## Opened from the main menu in debug builds («Проверка») or with the `--review` argument.

const SCENE := "res://scenes/review/review_hub.tscn"
const REVIEW_ARG := "--review"
const RING_RADIUS := 9.0
const PAD_SIZE := Vector3(2.4, 0.1, 2.4)
const TRIGGER_SIZE := Vector3(2.4, 2.0, 2.4)
const LABEL_HEIGHT := 2.6
const LABEL_WIDTH := 900.0
const LABEL_PIXEL := 0.0035
const PAD_COLOR := Color(0.95, 0.65, 0.2)
const PLAYER_GROUP := &"player"

## Station id → its pad (Area3D); filled in `_ready`.
var pads: Dictionary[String, Area3D] = {}

var _moments: Dictionary = {}
var _travelling := false


## True when the hall may be opened in this build.
static func available() -> bool:
	return OS.is_debug_build()


## True when the game was started with `--review` (before or after `--`).
static func requested() -> bool:
	return REVIEW_ARG in OS.get_cmdline_user_args() or REVIEW_ARG in OS.get_cmdline_args()


static func open() -> void:
	if not available():
		return
	GameState.reset()
	Shell.change_scene(SCENE)


func _ready() -> void:
	_moments = ReviewStations.moment_index()
	ReviewReturn.ensure(get_tree())
	var stations := ReviewStations.STATIONS
	for index in stations.size():
		var angle := TAU * float(index) / float(stations.size())
		_build_station(stations[index], Vector3(sin(angle), 0.0, -cos(angle)) * RING_RADIUS)


## Loads `station`; false when it has no entry or another load is under way.
func travel(station: Dictionary) -> bool:
	var entry := ReviewStations.entry(station, _moments)
	if entry.is_empty() or _travelling:
		return false
	_travelling = true
	var arrived: bool = await Debug.go_to(entry, StringName("review_" + str(station["id"])))
	_travelling = false
	return arrived


func _build_station(station: Dictionary, at: Vector3) -> void:
	var pad := Area3D.new()
	pad.name = "Station_" + str(station["id"])
	pad.position = at
	add_child(pad)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	shape.shape = box
	shape.position.y = TRIGGER_SIZE.y * 0.5
	pad.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = PAD_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = PAD_COLOR
	material.emission_enabled = true
	material.emission = PAD_COLOR
	material.emission_energy_multiplier = 0.4
	plate.material = material
	mesh.mesh = plate
	pad.add_child(mesh)
	var label := Label3D.new()
	label.position.y = LABEL_HEIGHT
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.pixel_size = LABEL_PIXEL
	label.width = LABEL_WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.outline_size = 10
	label.font_size = 36
	label.text = "#%d · %s\n\nЧто проверить: %s\n\nОжидается: %s" % [
		int(station["issue"]), String(station["title"]).to_upper(), station["check"], station["expect"]]
	pad.add_child(label)
	pad.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(PLAYER_GROUP):
			travel(station))
	pads[str(station["id"])] = pad
