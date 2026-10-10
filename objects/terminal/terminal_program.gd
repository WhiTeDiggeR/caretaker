class_name TerminalProgram
extends RefCounted

## Data model of a terminal program loaded from JSON (see data/terminals/README.md).
## Resolves screens against GameState: conditional lines, options with requirements,
## redirects and effects. Has no UI, so it is fully testable headless.

signal event_triggered(event: StringName)

var id := ""
var title := ""
var start := ""
var screens: Dictionary = {}
var errors := PackedStringArray()


static func load_file(path: String) -> TerminalProgram:
	var program := TerminalProgram.new()
	if not FileAccess.file_exists(path):
		program.errors.append("%s: file not found" % path)
		return program
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		program.errors.append("%s: not a JSON object" % path)
		return program
	program.load_data(parsed)
	return program


func load_data(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	title = str(data.get("title", ""))
	start = str(data.get("start", ""))
	screens = data.get("screens", {})
	errors.append_array(validate())


## Structural problems of the program: missing screens, unknown targets and effects.
func validate() -> PackedStringArray:
	var found := PackedStringArray()
	if id.is_empty():
		found.append("program has no id")
	if not screens.has(start):
		found.append("%s: start screen '%s' is missing" % [id, start])
	for screen_id: String in screens:
		var screen: Dictionary = screens[screen_id]
		var targets: Array[String] = []
		for option: Dictionary in screen.get("options", []):
			if option.has("goto"):
				targets.append(str(option["goto"]))
			elif str(option.get("action", "")) != "exit":
				found.append("%s/%s: option '%s' has neither goto nor exit" % [id, screen_id, option.get("text", "")])
			found.append_array(_validate_effects(option.get("effects", []), "%s/%s option" % [id, screen_id]))
		for redirect: Dictionary in screen.get("redirects", []):
			targets.append(str(redirect.get("goto", "")))
		if screen.has("next"):
			targets.append(str(screen["next"]))
		for target in targets:
			if not screens.has(target):
				found.append("%s/%s: unknown screen '%s'" % [id, screen_id, target])
		found.append_array(_validate_effects(screen.get("effects", []), "%s/%s" % [id, screen_id]))
	return found


func _validate_effects(effects: Array, where: String) -> PackedStringArray:
	return StateRules.validate_effects(effects, where)


## Screen id to show when entering `screen_id`, following redirects whose condition holds.
func resolve_screen(screen_id: String) -> String:
	var seen := {}
	while screens.has(screen_id) and not seen.has(screen_id):
		seen[screen_id] = true
		var redirected := false
		for redirect: Dictionary in (screens[screen_id] as Dictionary).get("redirects", []):
			if check(redirect.get("if", {})):
				screen_id = str(redirect["goto"])
				redirected = true
				break
		if not redirected:
			break
	return screen_id


## Enters a screen and returns what to display:
## {id, lines: [{text, wait}], options: [{index, text, available, locked_text}], next}
## Screen effects are applied by `complete()` once its lines have been shown.
func enter(screen_id: String) -> Dictionary:
	screen_id = resolve_screen(screen_id)
	var screen: Dictionary = screens.get(screen_id, {})
	var lines: Array[Dictionary] = []
	for entry: Variant in screen.get("lines", []):
		if entry is String:
			lines.append({"text": entry, "wait": 0.0})
		elif check((entry as Dictionary).get("if", {})):
			lines.append({"text": str(entry.get("text", "")), "wait": float(entry.get("wait", 0.0))})
	var options := _options_for(screen)
	return {"id": screen_id, "lines": lines, "options": options, "next": str(screen.get("next", ""))}


## Applies the effects of a screen after its lines were shown and returns its options
## re-evaluated against the new state.
func complete(screen_id: String) -> Array[Dictionary]:
	var screen: Dictionary = screens.get(screen_id, {})
	apply_effects(screen.get("effects", []))
	return _options_for(screen)


func _options_for(screen: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var raw_options: Array = screen.get("options", [])
	for index in raw_options.size():
		var option: Dictionary = raw_options[index]
		if not check(option.get("visible_if", {})):
			continue
		var available := check(option.get("requires", {}))
		options.append({
			"index": index,
			"text": str(option.get("text", "")),
			"available": available,
			"locked_text": str(option.get("locked_text", "")) if not available else "",
		})
	return options


## Chooses an option of a screen. Returns the screen to enter next, "" to stay, or "exit".
func choose(screen_id: String, option_index: int) -> String:
	var raw_options: Array = (screens.get(screen_id, {}) as Dictionary).get("options", [])
	if option_index < 0 or option_index >= raw_options.size():
		return ""
	var option: Dictionary = raw_options[option_index]
	if not check(option.get("visible_if", {})) or not check(option.get("requires", {})):
		return ""
	apply_effects(option.get("effects", []))
	if str(option.get("action", "")) == "exit":
		return "exit"
	return str(option.get("goto", ""))


func check(condition: Dictionary) -> bool:
	return StateRules.check(condition)


func apply_effects(effects: Array) -> void:
	StateRules.apply(effects, event_triggered.emit)
