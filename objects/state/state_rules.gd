class_name StateRules
extends RefCounted

## Shared conditions and effects over GameState, used by terminal programs, repair
## procedures and documents. Format: data/terminals/README.md («Условия», «Действия»).

const POWER_LEVELS: Array[String] = ["off", "emergency", "main"]
const EFFECT_KEYS: Array[String] = ["set_flag", "clear_flag", "grant_access", "revoke_access", "set_objective", "set_power", "event"]


## Every given key must hold; an empty condition always holds.
static func check(condition: Dictionary) -> bool:
	if condition.has("flag") and not GameState.has_flag(StringName(str(condition["flag"]))):
		return false
	if condition.has("not_flag") and GameState.has_flag(StringName(str(condition["not_flag"]))):
		return false
	if condition.has("access") and not GameState.has_access(StringName(str(condition["access"]))):
		return false
	if condition.has("not_access") and GameState.has_access(StringName(str(condition["not_access"]))):
		return false
	if condition.has("power"):
		var power: Dictionary = condition["power"]
		var current := GameState.get_section_power(StringName(str(power.get("section", ""))))
		if current < POWER_LEVELS.find(str(power.get("min", "off"))):
			return false
		if current > POWER_LEVELS.find(str(power.get("max", "main"))):
			return false
	for sub: Dictionary in condition.get("all", []):
		if not check(sub):
			return false
	if condition.has("any"):
		var any_true := false
		for sub: Dictionary in condition["any"]:
			any_true = any_true or check(sub)
		if not any_true:
			return false
	return true


## Applies effects in order. `on_event` receives the names of `event` effects.
static func apply(effects: Array, on_event: Callable = Callable()) -> void:
	for effect: Dictionary in effects:
		if effect.has("set_flag"):
			var value: Variant = effect["set_flag"]
			if value is Dictionary:
				GameState.set_flag(StringName(str(value["flag"])), value.get("value", true))
			else:
				GameState.set_flag(StringName(str(value)))
		if effect.has("clear_flag"):
			GameState.clear_flag(StringName(str(effect["clear_flag"])))
		if effect.has("grant_access"):
			GameState.grant_access(StringName(str(effect["grant_access"])))
		if effect.has("revoke_access"):
			GameState.revoke_access(StringName(str(effect["revoke_access"])))
		if effect.has("set_objective"):
			var objective: Dictionary = effect["set_objective"]
			GameState.set_objective(StringName(str(objective.get("id", ""))), str(objective.get("text", "")))
		if effect.has("set_power"):
			var power: Dictionary = effect["set_power"]
			GameState.set_section_power(StringName(str(power["section"])), POWER_LEVELS.find(str(power["power"])))
		if effect.has("event") and on_event.is_valid():
			on_event.call(StringName(str(effect["event"])))


static func validate_effects(effects: Array, where: String) -> PackedStringArray:
	var found := PackedStringArray()
	for effect: Dictionary in effects:
		for key: String in effect:
			if not key in EFFECT_KEYS:
				found.append("%s: unknown effect '%s'" % [where, key])
	return found
