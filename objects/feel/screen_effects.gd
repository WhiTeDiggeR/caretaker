extends CanvasLayer

## Full-screen state effects (autoload `ScreenEffects`, #134): waking in the capsule, the
## chemical protocol's gas, leaving a dream, a hit in the dream. An effect is a list of
## keyframes over its duration (data/feel/screen_effects.json); the layer interpolates the
## shader parameters and hides itself when nothing plays. `play()` replaces the current one.
## An effect with `"hold": true` stays on its last keyframe until `stop()` or a load (gas
## knocks the hero out; the defeat screen or the reloaded save takes over).

signal effect_started(id: StringName)
signal effect_finished(id: StringName)

const DATA_PATH := "res://data/feel/screen_effects.json"
const SHADER := preload("res://objects/feel/screen_effects.gdshader")
const PARAMETERS: Array[String] = ["blur", "darken", "tint", "vignette", "flash"]
const COLORS: Array[String] = ["tint_color", "vignette_color"]

var effects: Dictionary = {}
var current: StringName = &""
var elapsed := 0.0

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	effects = (parsed as Dictionary).get("effects", {}) if parsed is Dictionary else {}
	Containment.hero_gassed.connect(func(_id: StringName) -> void: play(&"gas"))
	Dreams.left.connect(func(_id: StringName, reason: int) -> void:
		play(&"dream_exit" if reason == Dreams.Exit.GATE else &"dream_eject"))
	GameState.state_loaded.connect(stop)
	Shell.scene_changed.connect(func(_path: String) -> void: stop())
	Shell.new_game_started.connect(play.bind(&"wake_up"))


func play(id: StringName) -> void:
	if not effects.has(String(id)):
		push_warning("ScreenEffects: unknown effect %s" % id)
		return
	current = id
	elapsed = 0.0
	var effect: Dictionary = effects[String(id)]
	for key in COLORS:
		if effect.has(key):
			_material.set_shader_parameter(key, Color(str(effect[key])))
	_rect.visible = true
	_apply()
	effect_started.emit(id)


func stop() -> void:
	if current.is_empty():
		return
	var id := current
	current = &""
	_rect.visible = false
	effect_finished.emit(id)


func is_playing(id: StringName = &"") -> bool:
	return not current.is_empty() and (id.is_empty() or id == current)


func duration(id: StringName) -> float:
	return float((effects.get(String(id), {}) as Dictionary).get("seconds", 0.0))


## Current value of a shader parameter (tests, debugging).
func value(parameter: String) -> float:
	return float(_material.get_shader_parameter(parameter))


func _process(delta: float) -> void:
	if current.is_empty():
		return
	elapsed += delta
	if elapsed >= duration(current):
		if not bool((effects[String(current)] as Dictionary).get("hold", false)):
			stop()
			return
		elapsed = duration(current)
	_apply()


func _apply() -> void:
	var keys: Array = (effects[String(current)] as Dictionary).get("keys", [])
	var t := elapsed
	for parameter in PARAMETERS:
		_material.set_shader_parameter(parameter, _sample(keys, parameter, t))


## Linear interpolation of one parameter between the keyframes around `t` (missing = 0).
static func _sample(keys: Array, parameter: String, t: float) -> float:
	if keys.is_empty():
		return 0.0
	var previous: Dictionary = keys[0]
	if t <= float(previous.get("t", 0.0)):
		return float(previous.get(parameter, 0.0))
	for key: Dictionary in keys:
		var key_t := float(key.get("t", 0.0))
		if t <= key_t:
			var from_t := float(previous.get("t", 0.0))
			var weight := 0.0 if is_equal_approx(key_t, from_t) else (t - from_t) / (key_t - from_t)
			return lerpf(float(previous.get(parameter, 0.0)), float(key.get(parameter, 0.0)), weight)
		previous = key
	return float(previous.get(parameter, 0.0))
