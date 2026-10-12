extends Node

## One-time tutorial hints (autoload `Hints`): data/hints/*.json. A hint is shown once per
## playthrough (flag `hint/<id>`), when it is requested (HintTrigger area, Hints.request) or
## when its `when` condition (StateRules) becomes true. `{action}` in the text becomes the
## current key of that input action, so remapped keys are shown. Hints wait while a terminal,
## document, pause or defeat owns the screen, and go to the nodes of the `hint_display`
## group (OpeningHud.show_hint).

signal hint_shown(id: StringName, text: String)

const DATA_DIR := "res://data/hints"
const FLAG_PREFIX := "hint/"
const DISPLAY_GROUP := &"hint_display"
const PLAYER_GROUP := &"player"
## How long a hint stays on screen, and the pause before the next queued one, seconds.
const SHOW_SECONDS := 6.0
const GAP_SECONDS := 1.0

## id -> {"text": String, "when": Dictionary (optional)}
var hints: Dictionary[StringName, Dictionary] = {}
## Off in tests that do not exercise hints.
var enabled := true

var _queue: Array[StringName] = []
var _cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_all()
	GameState.flag_changed.connect(func(_flag: StringName, _value: Variant) -> void: check_conditions())
	GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: check_conditions())
	GameState.state_loaded.connect(func() -> void:
		_queue.clear()
		check_conditions())


func load_all() -> void:
	hints.clear()
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file)))
		if parsed is Dictionary:
			var raw: Dictionary = (parsed as Dictionary).get("hints", {})
			for id: String in raw:
				hints[StringName(id)] = raw[id]


## Problems in the loaded hints: missing text or `{placeholders}` that are not input actions.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var placeholder := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for id: StringName in hints:
		var text := str(hints[id].get("text", ""))
		if text.is_empty():
			errors.append("%s: empty text" % id)
		for found in placeholder.search_all(text):
			if not InputMap.has_action(StringName(found.get_string(1))):
				errors.append("%s: unknown action {%s}" % [id, found.get_string(1)])
	return errors


func was_shown(id: StringName) -> bool:
	return GameState.has_flag(StringName(FLAG_PREFIX + String(id)))


## Queues a hint unless it was already shown or queued.
func request(id: StringName) -> void:
	if not enabled or not hints.has(id) or was_shown(id) or _queue.has(id):
		return
	_queue.append(id)


## Text with the current keys substituted for `{action}` placeholders.
func text_of(id: StringName) -> String:
	var text := str(hints.get(id, {}).get("text", ""))
	for action: StringName in InputMap.get_actions():
		var token := "{%s}" % action
		if text.contains(token):
			text = text.replace(token, InputPromptFormatter.action_label(action))
	return text


## Queues every hint whose `when` condition holds.
func check_conditions() -> void:
	for id: StringName in hints:
		if hints[id].has("when") and StateRules.check(hints[id]["when"]):
			request(id)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _queue.is_empty() or _cooldown > 0.0 or not _screen_free():
		return
	var displays := get_tree().get_nodes_in_group(DISPLAY_GROUP)
	if displays.is_empty():
		return
	var id: StringName = _queue.pop_front()
	if was_shown(id):
		return
	var text := text_of(id)
	GameState.set_flag(StringName(FLAG_PREFIX + String(id)))
	for display in displays:
		display.call("show_hint", text)
	hint_shown.emit(id, text)
	_cooldown = SHOW_SECONDS + GAP_SECONDS


func _screen_free() -> bool:
	if get_tree().paused:
		return false
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	return player != null and player.get("controls_locked") != true
