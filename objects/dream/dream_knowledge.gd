class_name DreamKnowledge
extends RefCounted

## Knowledge carried out of a dream (docs/game_design/03-first-dream.md, D4 and D7): nothing
## material leaves a dream, but the hero remembers what he saw. A restored seal grants a
## knowledge entry with a random sequence of glyphs; the journal shows it, and the module's
## resync panel takes it as input. Every visit grants a new sequence, and a used one is spent.
## Glyphs are the eight capsule phase marks Ф-1…Ф-8, kept by id (f1…f8; 07-dream-glyphs.md,
## sections 5–6); each dream sees them as its own images (`image`). The shapes are drawn by
## DreamGlyph. Definitions: data/dreams/knowledge.json. State: GameState system data (saved
## with the game); entries from older saves with unknown glyphs are dropped without an error.

enum Result { SYNCED, WRONG, NO_KNOWLEDGE, AWAKE }

const DATA_PATH := "res://data/dreams/knowledge.json"
const SYSTEM := &"dream_knowledge"
const SEPARATOR := " · "
const SKETCH_SEAL := &"seal"
const SKETCH_IMAGES := &"images"

static var _data: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_data = parsed if parsed is Dictionary else {}
	_loaded = true


## A player-facing text of the glyph screens (panel, seal, journal; #200): `texts.<key>` of
## the data. A missing key is reported and shown as the key itself, so the gap is visible.
static func text(key: String) -> Variant:
	_ensure()
	var texts: Dictionary = _data.get("texts", {})
	if not texts.has(key):
		push_error("DreamKnowledge: no text '%s' in %s" % [key, DATA_PATH])
		return key
	return texts[key]


static func has_text(key: String) -> bool:
	_ensure()
	return (_data.get("texts", {}) as Dictionary).has(key)


## Story version of the current visit (v1…v4); picks `length_by_version` of a knowledge.
static var visit_version: StringName = &""


## Ids of the glyph set, Ф-1 first.
static func glyphs() -> PackedStringArray:
	_ensure()
	var result := PackedStringArray()
	for glyph: Dictionary in _data.get("glyphs", []):
		result.append(str(glyph.get("id", "")))
	return result


static func glyph(id: String) -> Dictionary:
	_ensure()
	for entry: Dictionary in _data.get("glyphs", []):
		if str(entry.get("id", "")) == id:
			return entry
	return {}


## The service code of a glyph shown in the complex ("Ф-2"); the id for an unknown one.
static func label(id: String) -> String:
	return str(glyph(id).get("code", id))


static func labels_text(ids: PackedStringArray) -> String:
	var result := PackedStringArray()
	for id in ids:
		result.append(label(id))
	return SEPARATOR.join(result)


## How `dream` sees the glyph `id`: {"title", "tint"}; empty when the dream has no image.
static func image(dream: StringName, id: String) -> Dictionary:
	_ensure()
	return ((_data.get("dream_images", {}) as Dictionary).get(String(dream), {}) as Dictionary).get(id, {})


## Code length of knowledge `id` on this visit: by `visit_version`, else `length`.
static func code_length(id: StringName) -> int:
	var config := definition(id)
	var by_version: Dictionary = config.get("length_by_version", {})
	return int(by_version.get(String(visit_version), config.get("length", 3)))


static func definition(id: StringName) -> Dictionary:
	_ensure()
	return (_data.get("knowledge", {}) as Dictionary).get(String(id), {})


static func resync_param(key: String, default: float) -> float:
	_ensure()
	return float((_data.get("resync", {}) as Dictionary).get(key, default))


## The sequence the seal of `id` will grant on this visit, rolled once and kept until it is
## granted (#183: the ring seal shows it before it is solved). Empty for an unknown id.
static func prepare(id: StringName, rng: RandomNumberGenerator = null) -> PackedStringArray:
	var state := _state()
	var pending: Dictionary = state.get("pending", {})
	if pending.has(String(id)):
		return PackedStringArray(pending[String(id)])
	var code := _roll(id, rng)
	if code.is_empty():
		return code
	pending[String(id)] = Array(code)
	state["pending"] = pending
	GameState.set_system_data(SYSTEM, state)
	return code


## Grants `id` with the prepared sequence or a fresh random one of distinct glyphs (replacing
## an earlier visit's one). Returns the sequence; empty for an unknown id.
static func grant(id: StringName, rng: RandomNumberGenerator = null) -> PackedStringArray:
	var state := _state()
	var pending: Dictionary = state.get("pending", {})
	var code := PackedStringArray(pending.get(String(id), []))
	if code.is_empty():
		code = _roll(id, rng)
		if code.is_empty():
			return code
	pending.erase(String(id))
	state["pending"] = pending
	var order: Array = state.get("order", [])
	order.erase(String(id))
	order.append(String(id))
	state["order"] = order
	var visits := int(_entry(id).get("visits", 0)) + 1
	(state["entries"] as Dictionary)[String(id)] = {"code": Array(code), "used": false, "visits": visits}
	GameState.set_system_data(SYSTEM, state)
	return code


static func has(id: StringName) -> bool:
	return (_state()["entries"] as Dictionary).has(String(id))


static func is_used(id: StringName) -> bool:
	return bool(_entry(id).get("used", false))


static func code(id: StringName) -> PackedStringArray:
	return PackedStringArray(_entry(id).get("code", []))


static func code_text(id: StringName) -> String:
	return labels_text(code(id))


## The unspent knowledge for `module`, or an empty id.
static func active_for(module: StringName) -> StringName:
	for id: String in _state().get("order", []):
		if StringName(str(definition(StringName(id)).get("module", ""))) == module and not is_used(StringName(id)):
			return StringName(id)
	return &""


## Journal entries, newest first: {"text", "used", "sketch", "dream", "code"}. The hero sketches
## what he saw, not the phase codes (#188, З-3): after the first visit — the whole assembled
## seal (`SKETCH_SEAL`; he does not yet know what he will need), on later visits — the images
## of the code one by one (`SKETCH_IMAGES`). Texts: `journal` of the knowledge in the data.
static func journal_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var order: Array = _state().get("order", [])
	for index in range(order.size() - 1, -1, -1):
		var id := StringName(str(order[index]))
		var config := definition(id)
		var sketch := SKETCH_SEAL if int(_entry(id).get("visits", 1)) <= 1 else SKETCH_IMAGES
		var texts: Dictionary = config.get("journal", {})
		var text := "%s. %s" % [config.get("title", id), texts.get(String(sketch), "")]
		result.append({"text": text, "used": is_used(id), "sketch": sketch,
			"dream": StringName(str(config.get("dream", ""))), "code": code(id)})
	return result


## Checks an entered sequence against the module's active knowledge and applies the effect
## on Containment: a match calms the sleep and spends the knowledge, a mistake disturbs it.
static func resync(module: StringName, entered: PackedStringArray) -> Result:
	if Containment.is_awake(module):
		return Result.AWAKE
	var id := active_for(module)
	if id.is_empty():
		return Result.NO_KNOWLEDGE
	if entered != code(id):
		Containment.add_instability(module, resync_param("failure_penalty", 5.0))
		return Result.WRONG
	Containment.stabilize(module, resync_param("success_relief", 100.0))
	var state := _state()
	((state["entries"] as Dictionary)[String(id)] as Dictionary)["used"] = true
	GameState.set_system_data(SYSTEM, state)
	return Result.SYNCED


static func _roll(id: StringName, rng: RandomNumberGenerator) -> PackedStringArray:
	var config := definition(id)
	if config.is_empty():
		push_error("DreamKnowledge: unknown knowledge '%s'" % id)
		return PackedStringArray()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool := glyphs()
	var code := PackedStringArray()
	for _i in mini(code_length(id), pool.size()):
		var index := rng.randi_range(0, pool.size() - 1)
		code.append(pool[index])
		pool.remove_at(index)
	return code


static func _entry(id: StringName) -> Dictionary:
	return (_state()["entries"] as Dictionary).get(String(id), {})


static func _state() -> Dictionary:
	var state := GameState.get_system_data(SYSTEM).duplicate(true)
	if not state.has("entries"):
		state["entries"] = {}
	_drop_unknown(state, "pending")
	_drop_unknown(state, "entries")
	return state


## Removes sequences with glyphs outside the set (saves from the word glyphs, before #194).
static func _drop_unknown(state: Dictionary, key: String) -> void:
	var known := glyphs()
	var section: Dictionary = state.get(key, {})
	for id: String in section.keys():
		var value: Variant = section[id]
		var sequence: Array = value.get("code", []) if value is Dictionary else value
		for item: Variant in sequence:
			if not str(item) in known:
				section.erase(id)
				var order: Array = state.get("order", [])
				order.erase(id)
				break


static func _ensure() -> void:
	if not _loaded:
		reload()
