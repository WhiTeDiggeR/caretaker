class_name ModuleMonitor
extends StaticBody3D

## Wall monitor of the containment modules. Shows Containment.monitor_lines() while its
## section has power; dark otherwise.

const REFRESH_SECONDS := 0.5
const TITLE := "МОНИТОР МОДУЛЕЙ СОДЕРЖАНИЯ"
const NO_POWER := "НЕТ ПИТАНИЯ"

@export var section: StringName = &""

@onready var _text: Label3D = $Screen/Text
@onready var _interactable: Interactable = $Interactable

var _elapsed := 0.0


func _ready() -> void:
	_interactable.mode = Interactable.Mode.INSPECT
	_interactable.prompt = "ОСМОТРЕТЬ МОНИТОР"
	_interactable.inspect_title = TITLE
	refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0.0
		refresh()


func refresh() -> void:
	var powered := GameState.is_section_powered(section)
	var body := "\n".join(Containment.monitor_lines()) if powered else NO_POWER
	_text.text = TITLE + "\n\n" + body if powered else ""
	_interactable.available = powered
	_interactable.unavailable_prompt = NO_POWER
	_interactable.inspect_text = body
