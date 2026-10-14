extends Node

## Dream sound (autoload `DreamAudio`, #201): a background loop per stage of the dream (calm,
## alarm, unease, pre-awakening — docs/art/dream-bowser-s.md §2), cross-faded on a change, and
## stingers on the dream's events: the ambush (#184), the seal restored (#183/#197), the exit
## through the gate (#190) and a strike of the chain (#186). Stingers are ids of the Sfx
## catalogue. A stage loop is a drone synthesised here when the dream is entered (under the
## veil; placeholder within the sound budget) or, once recorded, a Sfx id (`sound`). Which
## dream uses what and the stage thresholds — data/audio/dream_audio.json.
## It only listens to existing signals: the dream scenes do not refer to it.
## Stage of a configured dream: pre-awakening at a high instability stage of the sleeper,
## unease while the ambush is on (until the seal), calm on a repeat visit (V2+) to a quiet
## sleeper, alarm otherwise (the entry, the way to the seal and after it).

signal stage_changed(stage: StringName)
signal stinger_played(event: StringName, id: StringName)

const DATA_PATH := "res://data/audio/dream_audio.json"
const SILENT := &""
const CALM := &"calm"
const ALARM := &"alarm"
const UNEASE := &"unease"
const PREAWAKE := &"preawake"
const SILENT_DB := -60.0
const DEFAULT_CROSSFADE := 2.5
const DRONE_RATE := 11025
const DRONE_SECONDS := 8.0  # every tone and pulse of a drone makes whole cycles in it
const DRONE_SEAM := 0.5
const DRONE_PEAK := 0.7
const DRONE_SEED := 201

var crossfade_seconds := DEFAULT_CROSSFADE
## module id -> {stages, calm_max_stage, preawake_min_stage, stingers, chain_weapons}
var dreams: Dictionary = {}
var stage: StringName = SILENT
## Stage whose loop plays now (empty in silence or when the stage has no sound).
var current_sound: StringName = &""
var ambush_active := false
## Instability stage of a module; replaced in tests.
var instability_stage: Callable = func(id: StringName) -> int: return Containment.get_stage(id)

var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _fade: Tween
## "<module>/<stage>" -> looping stream
var _loops: Dictionary[String, AudioStream] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_config(FileAccess.get_file_as_string(DATA_PATH))
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	Dreams.entered.connect(_on_entered)
	Dreams.left.connect(_on_left)
	Dreams.seal_restored_signal.connect(_on_seal_restored)
	Containment.stage_changed.connect(func(id: StringName, _stage: int) -> void:
		if id == Dreams.module_id:
			refresh())
	get_tree().node_added.connect(_on_node_added)


func load_config(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	crossfade_seconds = float(data.get("crossfade_seconds", DEFAULT_CROSSFADE))
	dreams = data.get("dreams", {})


func config(module_id: StringName) -> Dictionary:
	return dreams.get(String(module_id), {})


## The stage the current dream should sound at; SILENT outside a configured dream.
func desired_stage() -> StringName:
	var cfg := config(Dreams.module_id)
	if not Dreams.in_dream or cfg.is_empty():
		return SILENT
	var level: int = instability_stage.call(Dreams.module_id)
	if level >= int(cfg.get("preawake_min_stage", 3)):
		return PREAWAKE
	if ambush_active:
		return UNEASE
	var returned := GameState.has_flag(StringName(Dreams.RETURNED_PREFIX + String(Dreams.module_id)))
	if returned and level <= int(cfg.get("calm_max_stage", 0)):
		return CALM
	return ALARM


func refresh() -> void:
	var next := desired_stage()
	if next == stage:
		return
	stage = next
	_crossfade(stage)
	stage_changed.emit(stage)


## Looping stream of `stage_id` in the dream `module_id` (built once and kept).
func stage_stream(module_id: StringName, stage_id: StringName) -> AudioStream:
	var key := "%s/%s" % [module_id, stage_id]
	if not _loops.has(key):
		var spec: Dictionary = (config(module_id).get("stages", {}) as Dictionary).get(String(stage_id), {})
		var sound := StringName(str(spec.get("sound", "")))
		if sound != &"":
			_loops[key] = _looped(sound)
		elif spec.has("drone"):
			_loops[key] = synth_drone(spec["drone"])
		else:
			_loops[key] = null
	return _loops[key]


## Plays the stinger of `event` (ambush, seal, gate, chain_hit) of the dream `module_id`.
func stinger(event: StringName, module_id: StringName = Dreams.module_id) -> void:
	var id := StringName(str((config(module_id).get("stingers", {}) as Dictionary).get(String(event), "")))
	if id == &"":
		return
	Sfx.play(id)
	stinger_played.emit(event, id)


func _crossfade(stage_id: StringName) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	var old := _players[_current]
	_fade = create_tween().set_parallel()
	_fade.tween_property(old, "volume_db", SILENT_DB, crossfade_seconds)
	var stream := stage_stream(Dreams.module_id, stage_id) if stage_id != SILENT else null
	current_sound = stage_id if stream else &""
	if stream:
		var spec: Dictionary = (config(Dreams.module_id).get("stages", {}) as Dictionary).get(String(stage_id), {})
		var entry: Dictionary = Sfx.sounds.get(StringName(str(spec.get("sound", ""))), {})
		_current = 1 - _current
		var player := _players[_current]
		player.stream = stream
		player.bus = StringName(str(entry.get("bus", "Ambience")))
		if AudioServer.get_bus_index(player.bus) < 0:
			player.bus = &"Master"
		player.volume_db = SILENT_DB
		player.play()
		var volume := float(spec.get("volume_db", entry.get("volume_db", 0.0)))
		_fade.tween_property(player, "volume_db", volume, crossfade_seconds)
	_fade.chain().tween_callback(old.stop)


## The catalogue sound of `id` set to loop (a copy: the one-shot use stays as it is).
func _looped(id: StringName) -> AudioStream:
	var path := str((Sfx.sounds.get(id, {}) as Dictionary).get("file", ""))
	var source := load(path) as AudioStream if ResourceLoader.exists(path) else null
	var stream: AudioStream = source.duplicate() if source else null
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream and &"loop" in stream:
		stream.set(&"loop", true)
	return stream


## A seamless drone loop: `tones` (Hz, each 1/k as loud), low-passed noise as wind (`wind`
## loud, `wind_cutoff` Hz) and a pulse of the whole (`pulse` Hz, `depth` 0–1). The noise
## rendered past the loop is faded into its head, so the seam does not click.
static func synth_drone(spec: Dictionary) -> AudioStreamWAV:
	var n := int(DRONE_SECONDS * DRONE_RATE)
	var seam := int(DRONE_SEAM * DRONE_RATE)
	var tones: Array = spec.get("tones", [])
	var alpha := 1.0 - exp(-TAU * float(spec.get("wind_cutoff", 400.0)) / DRONE_RATE)
	var wind := float(spec.get("wind", 2.0))
	var pulse := float(spec.get("pulse", 0.5))
	var depth := float(spec.get("depth", 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = DRONE_SEED
	var raw := PackedFloat32Array()
	raw.resize(n + seam)
	var air := 0.0
	for i in n + seam:
		var t := float(i) / DRONE_RATE
		var value := 0.0
		for k in tones.size():
			value += sin(TAU * float(tones[k]) * t) / (k + 1)
		air += alpha * (rng.randf_range(-1.0, 1.0) - air)
		raw[i] = (value + air * wind) * (1.0 - depth + depth * sin(TAU * pulse * t))
	var peak := 0.0001
	for i in n:
		if i < seam:
			var w := float(i) / seam
			raw[i] = raw[i] * w + raw[n + i] * (1.0 - w)
		peak = maxf(peak, absf(raw[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var gain := DRONE_PEAK * 32767.0 / peak
	for i in n:
		data.encode_s16(i * 2, int(raw[i] * gain))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = DRONE_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _on_entered(id: StringName) -> void:
	ambush_active = false
	# Build the stage loops while the veil covers the entry, not in the middle of a fight.
	for stage_id: String in config(id).get("stages", {}):
		stage_stream(id, StringName(stage_id))
	refresh()


func _on_left(id: StringName, reason: int) -> void:
	if reason == Dreams.Exit.GATE:
		stinger(&"gate", id)
	ambush_active = false
	refresh()


func _on_seal_restored(id: StringName) -> void:
	ambush_active = false
	stinger(&"seal", id)
	refresh()


## Ambushes and the hero's combat come and go with the dream scenes.
func _on_node_added(node: Node) -> void:
	if node is DreamAmbush:
		(node as DreamAmbush).ambush_started.connect(_on_ambush_started)
	elif node is DreamCombat:
		(node as DreamCombat).attacked.connect(_on_attacked)


func _on_ambush_started() -> void:
	if not Dreams.in_dream or Dreams.seal_restored:
		return
	ambush_active = true
	stinger(&"ambush")
	refresh()


func _on_attacked(weapon_id: StringName) -> void:
	var weapons: Array = config(Dreams.module_id).get("chain_weapons", [])
	if Dreams.in_dream and weapons.has(String(weapon_id)):
		stinger(&"chain_hit")
