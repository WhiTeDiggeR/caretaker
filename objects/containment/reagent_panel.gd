class_name ReagentPanel
extends StaticBody3D

## Service panel of a module's chemical protocol: state, ventilation and recharge from the
## reagent stock. The state is shown on a late-era world screen in the status grammar
## (issue #165); dark while the panel's section has no power.

const REFRESH_SECONDS := 0.3
const VENT_CAPTION := "ВЕНТИЛЯЦИЯ"
const RECHARGE_CAPTION := "РЕАГЕНТ"
const CAPTION_SIZE := 26
const TITLE := "ХИМИЧЕСКИЙ ПРОТОКОЛ · %s"
## Status of each chemical phase (Containment.Chemical).
const PHASE_STATUS: Array[StringName] = [&"ok", &"alarm", &"alarm", &"warn"]

@export var module_id: StringName = &"module_4"
## Power section of the panel; none keeps the screen always on.
@export var section: StringName = &""

@onready var _screen: WorldScreen = $Screen
@onready var _vent: Interactable = $VentButton/Interactable
@onready var _recharge: Interactable = $RechargeButton/Interactable

var _elapsed := 0.0


func _ready() -> void:
	_vent.prompt = "ЗАПУСТИТЬ ВЕНТИЛЯЦИЮ МОДУЛЯ"
	_recharge.prompt = "ЗАРЯДИТЬ ПРОТОКОЛ РЕАГЕНТОМ"
	_caption($VentButton, VENT_CAPTION)
	_caption($RechargeButton, RECHARGE_CAPTION)
	_vent.interacted.connect(func() -> void:
		Containment.vent(module_id)
		refresh())
	_recharge.interacted.connect(func() -> void:
		Containment.recharge(module_id)
		refresh())
	Containment.reagent_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0.0
		refresh()


func refresh() -> void:
	var powered := section.is_empty() or GameState.is_section_powered(section)
	_screen.set_powered(powered)
	if powered:
		_screen.show_rows(TITLE % str(Containment.modules.get(module_id, {}).get("label", module_id)), screen_rows())
	_apply(_vent, Containment.vent_lock_reason(module_id))
	_apply(_recharge, Containment.recharge_lock_reason(module_id))


## Rows of the screen: the phase, its timer, the gas and the reagent stock.
func screen_rows() -> Array[Dictionary]:
	var phase := Containment.chemical_phase(module_id)
	var rows: Array[Dictionary] = [{"text": Containment.CHEMICAL_NAMES[phase], "status": PHASE_STATUS[phase]}]
	if phase in [Containment.Chemical.WARNING, Containment.Chemical.SEALED]:
		rows.append({"text": Containment._clock(Containment.chemical_timer(module_id)), "status": &"alarm", "large": true})
	var gas := "вентиляция" if Containment.is_venting(module_id) else ("да" if Containment.has_gas(module_id) else "нет")
	rows.append({"text": "Газ в модуле: %s" % gas, "status": &"warn" if gas != "нет" else &""})
	var stock := Containment.reagent_stock()
	rows.append({"text": "Запас реагента: %d" % stock, "status": &"warn" if stock <= 0 else &""})
	return rows


## Everything the screen shows as plain lines (tests).
func screen_text() -> String:
	return _screen.text()


## A sign under a button.
static func _caption(button: Node3D, text: String) -> void:
	var label := UiStyle.sign_label(text, CAPTION_SIZE)
	label.position = Vector3(0, -0.14, 0.045)
	button.add_child(label)


func _apply(control: Interactable, reason: String) -> void:
	control.available = reason.is_empty()
	control.unavailable_prompt = reason
