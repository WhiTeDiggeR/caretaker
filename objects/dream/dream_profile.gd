class_name DreamProfile
extends Resource

## Look of one sleeper's dream for the interface (docs/ui/style-guide.md, «Сон и
## нейроинтерфейс», issue #149): colours of the dream HUD and its edge vignette, colour
## split, and how far the sleeper's unrest leaks into other dreams and late screens.
## The profile of a module is named in data/dreams/dreams.json ("profile").

const PROFILE_DIR := "res://materials/ui/dream"
const FALLBACK := &"neutral"

@export var id: StringName = FALLBACK
## Labels of the dream HUD (task heading, task text).
@export var text := Color("#ffe7cf")
## Halo of the dream text and the light of the filled seal marks.
@export var glow := Color("#ff7a2e")
## Colour of the module (narrow marks).
@export var mark := Color("#3f8f4a")
## Edges of the frame; their strength follows the instability of the sleep.
@export var vignette := Color("#2a0e05")
## Colour split of the picture (anomaly), 0 for none.
@export_range(0.0, 1.0) var split := 0.0
## The unrest of `leak_module` above `leak_from` % splits other dreams and late screens.
@export var leak_module: StringName = &""
@export_range(0.0, 100.0) var leak_from := 75.0

static var _cache: Dictionary[StringName, DreamProfile] = {}


static func load_profile(name: StringName) -> DreamProfile:
	if not _cache.has(name):
		var path := "%s/%s.tres" % [PROFILE_DIR, name]
		_cache[name] = load(path) as DreamProfile if ResourceLoader.exists(path) else null
		if _cache[name] == null and name != FALLBACK:
			_cache[name] = load_profile(FALLBACK)
	return _cache[name]


## Profile of the dream of `module_id` (the neutral one when none is configured).
static func for_module(module_id: StringName) -> DreamProfile:
	var entry: Dictionary = Dreams.dreams.get(String(module_id), {})
	return load_profile(StringName(str(entry.get("profile", FALLBACK))))


## 0..1: how strongly an anomalous sleeper (Herobrine) currently leaks into other dreams and
## late screens. Zero while every such sleeper stays below its threshold.
static func leak_strength() -> float:
	var strongest := 0.0
	for module_id: String in Dreams.dreams:
		var profile := for_module(StringName(module_id))
		if profile == null or profile.leak_module == &"" or not Containment.modules.has(profile.leak_module):
			continue
		var unrest := Containment.get_instability(profile.leak_module)
		strongest = maxf(strongest, clampf((unrest - profile.leak_from) / maxf(100.0 - profile.leak_from, 1.0), 0.0, 1.0))
	return strongest
