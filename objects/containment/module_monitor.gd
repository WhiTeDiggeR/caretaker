class_name ModuleMonitor
extends StaticBody3D

## Wall monitor of the containment modules. Shows the visible modules on a late-era world
## screen (WorldScreen, issue #146): each module with its state coloured by the status
## grammar and its detail lines; dark glass while its section has no power.

const REFRESH_SECONDS := 0.5
const TITLE := "МОНИТОР МОДУЛЕЙ СОДЕРЖАНИЯ"
const NO_POWER := "НЕТ ПИТАНИЯ"

@export var section: StringName = &""

@onready var _screen: WorldScreen = $Screen
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
	_screen.set_powered(powered)
	if powered:
		_screen.show_rows(TITLE, screen_rows())
	_interactable.available = powered
	_interactable.unavailable_prompt = NO_POWER
	_interactable.inspect_text = "\n".join(Containment.monitor_lines()) if powered else NO_POWER


## Rows of the screen: a module header with its status, then its detail lines.
static func screen_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: StringName in Containment.modules:
		if not Containment.is_visible_on_monitor(id):
			continue
		var label := str(Containment.modules[id].get("label", id))
		var state := Containment.STABLE_NAME if Containment.is_stable(id) else Containment.stage_name(Containment.get_stage(id))
		var status := module_status(id)
		rows.append({"text": "%s — %s" % [label, state], "status": status, "indent": false})
		for detail in Containment.status_lines(id):
			rows.append({"text": detail, "status": status if status == &"alarm" else &"", "indent": true})
	rows.append({"text": Containment.MONITOR_HIDDEN_LINE, "status": &"none", "indent": false})
	return rows


## Status grammar of a module: calm sleep is normal, restlessness a warning, the gas phases,
## pre-awakening and an awake prisoner an alarm.
static func module_status(id: StringName) -> StringName:
	if Containment.is_awake(id):
		return &"alarm"
	if Containment.is_stable(id):
		return &"ok"
	if Containment.has_chemical_protocol(id) and Containment.chemical_phase(id) in [Containment.Chemical.WARNING, Containment.Chemical.SEALED]:
		return &"alarm"
	match Containment.get_stage(id):
		Containment.Stage.CALM:
			return &"ok"
		Containment.Stage.RESTLESS, Containment.Stage.ANXIOUS:
			return &"warn"
	return &"alarm"
