class_name ReagentPanel
extends StaticBody3D

## Service panel of a module's chemical protocol: state, ventilation and recharge from the
## reagent stock.

const REFRESH_SECONDS := 0.3

@export var module_id: StringName = &"module_4"

@onready var _status: Label3D = $Status
@onready var _vent: Interactable = $VentButton/Interactable
@onready var _recharge: Interactable = $RechargeButton/Interactable

var _elapsed := 0.0


func _ready() -> void:
	_vent.prompt = "ЗАПУСТИТЬ ВЕНТИЛЯЦИЮ МОДУЛЯ"
	_recharge.prompt = "ЗАРЯДИТЬ ПРОТОКОЛ РЕАГЕНТОМ"
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
	var phase := Containment.chemical_phase(module_id)
	var lines := PackedStringArray([
		"ХИМИЧЕСКИЙ ПРОТОКОЛ · %s" % str(Containment.modules.get(module_id, {}).get("label", module_id)),
		Containment.CHEMICAL_NAMES[phase],
	])
	if phase in [Containment.Chemical.WARNING, Containment.Chemical.SEALED]:
		lines.append(Containment._clock(Containment.chemical_timer(module_id)))
	lines.append("Газ в модуле: %s" % ("вентиляция" if Containment.is_venting(module_id) else ("да" if Containment.has_gas(module_id) else "нет")))
	lines.append("Запас реагента: %d" % Containment.reagent_stock())
	_status.text = "\n".join(lines)
	_apply(_vent, Containment.vent_lock_reason(module_id))
	_apply(_recharge, Containment.recharge_lock_reason(module_id))


func _apply(control: Interactable, reason: String) -> void:
	control.available = reason.is_empty()
	control.unavailable_prompt = reason
