class_name InterdreamOverlay
extends CanvasLayer

## The interdream on screen (docs/game_design/10-interdream.md, #228): the white corridor
## (InterdreamCorridor) in its own world over everything, so the complex loads underneath.
## Through the gate it rises out of the white veil, walks, shows the echo and washes back to
## white; death and the chemical awakening tear it — a white cut with a ring, flicker and
## torn bands, amber when object 2 pulled the hero out (with a short flash of the plate «2»).
## Skipping (holding «Взаимодействие» or Esc) works after `skip_after_seconds`, never for a
## mandatory echo.
## #240: the corridor is built while the hero is still in the dream (`prepare`), so the gate
## opens straight into it — the dream glows white for a moment and the corridor is there, the
## walk going on at the hero's pace; the complex loads only after the corridor washes out.
## A screen pass blurs the frame towards soft white edges by the corridor's look.

signal finished(echo_id: String, seen_seconds: float)
## The corridor covers the whole screen now (#240): what lies under it can change unseen.
signal covered

const CORRIDOR_SCENE := "res://scenes/dreams/interdream.tscn"
## Above the veil (50) and the seal's afterimage (51).
const LAYER := 52
const WASH_SECONDS := 0.8
## Through the gate the dream dissolves into the white glow of the gate this fast, and the
## corridor shows out of the glow from half of it on.
const ENTER_SECONDS := 0.35
const SKIP_WASH_SECONDS := 0.3
const SKIP_HOLD_SECONDS := 0.4
const MOUSE_DEGREES := 0.06
const TORN_JITTER := 0.035
const TORN_BANDS := 5
const TORN_FLASH := Vector2(0.45, 0.85)
const WHITE := Color(1, 1, 1)
const AMBER := Color(1.0, 0.78, 0.42)
const HUM := {"tones": [55.0, 110.0, 165.0], "wind": 1.6, "wind_cutoff": 300.0, "pulse": 0.25, "depth": 0.2}
const HUM_DB := -16.0
const RING_DB := -8.0
const BUS := &"SFX"
const DREAM_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur_center = 0.0;
uniform float blur_edge = 0.0;
uniform float haze = 0.0;
uniform float edge_white = 0.0;
uniform float swim = 0.0;
uniform float bloom = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = (uv - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = clamp(length(c) * 1.5, 0.0, 1.0);
	uv += vec2(sin(TIME * 0.6 + uv.y * 5.0), cos(TIME * 0.45 + uv.x * 4.0)) * 0.002 * swim * (0.3 + r);
	float lod = mix(blur_center, blur_edge, smoothstep(0.2, 0.95, r));
	vec3 col = textureLod(screen, uv, lod).rgb;
	vec3 glow = textureLod(screen, uv, lod + 2.5).rgb;
	col = mix(col, max(col, glow), bloom);
	col = mix(col, vec3(1.0), clamp(haze + edge_white * smoothstep(0.4, 1.0, r), 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

var playing := false
var skippable := false
var skipped := false
var torn := false
var elapsed := 0.0
var duration := 0.0
var seen_seconds := 0.0
var echo: Dictionary = {}
var corridor: InterdreamCorridor

var _root: Control
var _viewport: SubViewport
var _wash: ColorRect
var _dream: ColorRect
var _entering := false
var _dream_look := false
var _bands: Array[ColorRect] = []
var _hum: AudioStreamPlayer
var _ring: AudioStreamPlayer
var _sounds: Array = []
var _hold := 0.0
var _out_from := -1.0
var _rng := RandomNumberGenerator.new()

static var _hum_stream: AudioStreamWAV
static var _ring_stream: AudioStreamWAV


func _init() -> void:
	layer = LAYER
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	container.add_child(_viewport)
	_dream = ColorRect.new()
	_dream.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dream_material := ShaderMaterial.new()
	dream_material.shader = Shader.new()
	dream_material.shader.code = DREAM_SHADER
	_dream.material = dream_material
	_root.add_child(_dream)
	for i in TORN_BANDS:
		var band := ColorRect.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.visible = false
		_root.add_child(band)
		_bands.append(band)
	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wash)
	_hum = AudioStreamPlayer.new()
	_ring = AudioStreamPlayer.new()
	for player in [_hum, _ring]:
		add_child(player)
	_root.visible = false


func _ready() -> void:
	var bus := BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	_hum.bus = bus
	_ring.bus = bus


## Builds the corridor ahead, hidden and not drawn, while the hero is in the dream (#240):
## the gate then shows it without a hitch. `look` — one of InterdreamCorridor.LOOKS.
func prepare(look: String = InterdreamEchoes.look()) -> void:
	if playing:
		return
	if corridor and corridor.look == look:
		return
	_free_corridor()
	corridor = (load(CORRIDOR_SCENE) as PackedScene).instantiate() as InterdreamCorridor
	corridor.look = look
	_viewport.add_child(corridor)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Plays the interdream for leaving through `exit` (Dreams.Exit) with `with_echo` (from
## InterdreamEchoes.pick, empty — quiet). Returns when it is over; `finished` tells how long
## the echo was seen. Through the gate it shows over the dream at once and goes on at the
## hero's pace (`carry`: {speed m/s, pitch degrees}); it ends on white. A torn one ends abruptly.
func play(with_echo: Dictionary, exit: int, carry: Dictionary = {}) -> void:
	var prepared := corridor if not playing and corridor and not corridor.torn else null
	if prepared:
		corridor = null
	stop()
	if prepared:
		corridor = prepared
	echo = with_echo
	torn = exit != Dreams.Exit.GATE
	elapsed = 0.0
	seen_seconds = 0.0
	skipped = false
	_hold = 0.0
	_out_from = -1.0
	duration = InterdreamEchoes.seconds("torn_seconds", 1.5) if torn \
			else InterdreamEchoes.seconds("echo_seconds" if not echo.is_empty() else "quiet_seconds", 3.0)
	skippable = not torn and not bool(echo.get("mandatory", false))
	if torn or corridor == null:
		_free_corridor()
		corridor = (load(CORRIDOR_SCENE) as PackedScene).instantiate() as InterdreamCorridor
		corridor.look = InterdreamEchoes.look()
		corridor.torn = torn
		_viewport.add_child(corridor)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not torn:
		corridor.carry(float(carry.get("speed", 0.0)), float(carry.get("pitch", 0.0)), duration)
	_apply_look()
	corridor.show_props([] if torn else echo.get("props", []), str(echo.get("tag", "")))
	corridor.progress = 0.0
	_wash.color = AMBER if exit == Dreams.Exit.WOKEN else WHITE
	_wash.modulate.a = 1.0
	_entering = not torn
	_root.modulate.a = 0.0 if _entering else 1.0
	# Under the glow of the gate the pass would blur the dream itself: it starts once covered.
	_dream.visible = _dream_look and not _entering
	_sounds = (echo.get("sounds", []) as Array).duplicate()
	_root.visible = true
	playing = true
	if torn:
		_ring.stream = _ring_tone()
		_ring.volume_db = RING_DB + (-6.0 if exit == Dreams.Exit.WOKEN else 0.0)
		_ring.play()
	else:
		_hum.stream = _hum_tone()
		_hum.volume_db = HUM_DB
		_hum.play()
	await finished


## Hides the interdream at once (a loaded save, an aborted session).
func stop() -> void:
	var was_playing := playing
	playing = false
	_root.visible = false
	_hum.stop()
	_ring.stop()
	for band in _bands:
		band.visible = false
	_free_corridor()
	if was_playing:
		finished.emit(str(echo.get("id", "")), seen_seconds)


func _free_corridor() -> void:
	if corridor:
		corridor.queue_free()
		corridor = null


## The screen pass follows the corridor's look; a torn interdream stays sharp and harsh.
func _apply_look() -> void:
	var settings := corridor.look_settings()
	var material := _dream.material as ShaderMaterial
	for key in ["blur_center", "blur_edge", "haze", "edge_white", "swim", "bloom"]:
		material.set_shader_parameter(StringName(key), float(settings.get(key, 0.0)))
	_dream_look = not torn and (float(settings.get("blur_edge", 0.0)) > 0.0 or float(settings.get("haze", 0.0)) > 0.0)


## Ends early: washes out to white now. Ignored where skipping is not allowed yet.
func skip() -> bool:
	if not playing or not skippable or skipped or elapsed < InterdreamEchoes.seconds("skip_after_seconds", 1.0):
		return false
	skipped = true
	_out_from = elapsed
	return true


func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	corridor.progress = elapsed / duration
	if torn:
		_tear()
	else:
		_walk(delta)
	while not _sounds.is_empty() and elapsed >= float((_sounds[0] as Dictionary).get("at", 0.0)):
		if not skipped:
			Sfx.play(StringName(str((_sounds[0] as Dictionary).get("sfx", ""))))
		_sounds.pop_front()
	if elapsed >= duration or (skipped and elapsed >= _out_from + SKIP_WASH_SECONDS):
		stop()


func _walk(delta: float) -> void:
	if _out_from < 0.0 and elapsed >= duration - WASH_SECONDS:
		_out_from = elapsed
	# Through the gate: the dream dissolves into the glow, the corridor comes out of it.
	var reveal_from := ENTER_SECONDS * 0.5 if not torn else 0.0
	var wash := 1.0 - clampf((elapsed - reveal_from) / WASH_SECONDS, 0.0, 1.0)
	if _entering:
		_root.modulate.a = sqrt(clampf(elapsed / ENTER_SECONDS, 0.0, 1.0))
		if _root.modulate.a >= 1.0:
			_entering = false
			_dream.visible = _dream_look
			covered.emit()
	if _out_from >= 0.0:
		var out_seconds := SKIP_WASH_SECONDS if skipped else WASH_SECONDS
		wash = maxf(wash, clampf((elapsed - _out_from) / out_seconds, 0.0, 1.0))
	_wash.modulate.a = wash
	_hum.volume_db = lerpf(HUM_DB, -60.0, wash * wash) if _out_from >= 0.0 else HUM_DB
	if not echo.is_empty() and wash < 0.5:
		seen_seconds += delta
	if Input.is_action_pressed(&"interact"):
		_hold += delta
		if _hold >= SKIP_HOLD_SECONDS:
			skip()
	else:
		_hold = 0.0


## The torn interdream: the corridor shows through a flickering white (amber) cut, shaken and
## crossed by torn bands; the plate «2» flashes only when the echo asks for it.
func _tear() -> void:
	corridor.jitter = TORN_JITTER
	_wash.modulate.a = _rng.randf_range(0.15, 0.85) if elapsed > 0.12 else 1.0
	var size := _root.get_rect().size
	for band in _bands:
		band.visible = _rng.randf() < 0.6
		band.color = Color(_wash.color, _rng.randf_range(0.5, 1.0))
		band.position = Vector2(_rng.randf_range(-0.2, 0.2) * size.x, _rng.randf() * size.y)
		band.size = Vector2(size.x * 1.4, _rng.randf_range(4.0, 40.0))
	var flash: bool = not echo.is_empty() and elapsed >= TORN_FLASH.x and elapsed <= TORN_FLASH.y
	corridor.show_props(echo.get("props", []) if flash else [])
	if flash:
		seen_seconds = elapsed - TORN_FLASH.x


func _input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseMotion and corridor and not torn:
		var motion := (event as InputEventMouseMotion).relative * MOUSE_DEGREES
		corridor.look_offset += Vector2(motion.x, motion.y)
	elif event.is_action_pressed(&"ui_cancel"):
		skip()
	# Nothing reaches the complex while the hero is between the dreams (pause, journal).
	get_viewport().set_input_as_handled()


static func _hum_tone() -> AudioStreamWAV:
	if _hum_stream == null:
		_hum_stream = DreamAudio.synth_drone(HUM)
	return _hum_stream


## The ring of the torn interdream: two high partials dying out.
static func _ring_tone() -> AudioStreamWAV:
	if _ring_stream:
		return _ring_stream
	var rate := 22050
	var n := int(rate * 1.4)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var value := (sin(TAU * 1480.0 * t) + 0.5 * sin(TAU * 2230.0 * t)) * exp(-3.2 * t) * minf(1.0, t * 400.0)
		data.encode_s16(i * 2, int(value * 0.55 * 32767.0))
	_ring_stream = AudioStreamWAV.new()
	_ring_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_ring_stream.mix_rate = rate
	_ring_stream.data = data
	return _ring_stream
