class_name Terminal
extends StaticBody3D

## World terminal: a console the player uses to open a TerminalProgram on screen.
## Needs section power; without it the screen is dark and the prompt says so.

signal event_triggered(event: StringName)
signal opened
signal closed

const SCREEN_SCENE := preload("res://objects/terminal/terminal_screen.tscn")
const PROMPT := "ИСПОЛЬЗОВАТЬ ТЕРМИНАЛ"
const SCREEN_ON := Color(0.1, 0.5, 0.36)
const SCREEN_OFF := Color(0.02, 0.02, 0.02)

@export_file("*.json") var program_path := ""
@export var section: StringName = &""

@onready var _interactable: Interactable = $Interactable
@onready var _screen_mesh: MeshInstance3D = $Screen

var program: TerminalProgram
var screen: TerminalScreen
var _screen_material: StandardMaterial3D


func _ready() -> void:
	program = TerminalProgram.load_file(program_path)
	for error in program.errors:
		push_error("Terminal %s: %s" % [name, error])
	program.event_triggered.connect(event_triggered.emit)
	_screen_material = (_screen_mesh.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_screen_mesh.set_surface_override_material(0, _screen_material)
	_interactable.prompt = PROMPT
	_interactable.interacted.connect(open)
	GameState.section_power_changed.connect(func(_s: StringName, _p: int) -> void: _refresh())
	GameState.state_loaded.connect(_refresh)
	_refresh()


func is_powered() -> bool:
	return GameState.is_section_powered(section)


func open() -> void:
	if screen or not is_powered() or not program.errors.is_empty():
		return
	screen = SCREEN_SCENE.instantiate()
	get_tree().root.add_child(screen)
	screen.closed.connect(_on_screen_closed)
	screen.open(program)
	opened.emit()


func _on_screen_closed() -> void:
	screen = null
	closed.emit()


func _refresh() -> void:
	var powered := is_powered()
	_interactable.available = powered
	_interactable.unavailable_prompt = FacilityDoor.REASON_NO_POWER
	_screen_material.albedo_color = SCREEN_ON if powered else SCREEN_OFF
	_screen_material.emission = SCREEN_ON if powered else SCREEN_OFF
