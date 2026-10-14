extends Node

## Dream sound (autoload `DreamAudio`, #201): a background loop per stage of the dream (calm,
## alarm, unease, pre-awakening — docs/art/dream-bowser-s.md §2), cross-faded on a change, and
## stingers on the dream's events: the ambush (#184), the seal restored (#183/#197), the exit
## through the gate (#190) and a strike of the chain (#186). Sounds are ids of the Sfx
## catalogue; which dream uses which and the stage thresholds — data/audio/dream_audio.json.
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

var crossfade_seconds := DEFAULT_CROSSFADE
## module id -> {stages, calm_max_stage, preawake_min_stage, stingers, chain_weapons}
var dreams: Dictionary = {}
var stage: StringName = SILENT
## Sfx id of the loop playing now (empty in silence).
var current_sound: StringName = &""
var ambush_active := false
## Instability stage of a module; replaced in tests.
var instability_stage: Callable = func(id: StringName) -> int: return Containment.get_stage(id)

var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _fade: Tween
var _loops: Dictionary[StringName, AudioStream] = {}


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
	var stages: Dictionary = config(Dreams.module_id).get("stages", {})
	_crossfade(StringName(str(stages.get(String(stage), ""))) if stage != SILENT else &"")
	stage_changed.emit(stage)


## Plays the stinger of `event` (ambush, seal, gate, chain_hit) of the dream `module_id`.
func stinger(event: StringName, module_id: StringName = Dreams.module_id) -> void:
	var id := StringName(str((config(module_id).get("stingers", {}) as Dictionary).get(String(event), "")))
	if id == &"":
		return
	Sfx.play(id)
	stinger_played.emit(event, id)


func _crossfade(id: StringName) -> void:
	current_sound = id
	if _fade and _fade.is_valid():
		_fade.kill()
	var old := _players[_current]
	_fade = create_tween().set_parallel()
	_fade.tween_property(old, "volume_db", SILENT_DB, crossfade_seconds)
	var stream := _loop(id)
	if stream:
		_current = 1 - _current
		var entry: Dictionary = Sfx.sounds[id]
		var player := _players[_current]
		player.stream = stream
		player.bus = StringName(str(entry.get("bus", "Ambience")))
		if AudioServer.get_bus_index(player.bus) < 0:
			player.bus = &"Master"
		player.volume_db = SILENT_DB
		player.play()
		_fade.tween_property(player, "volume_db", float(entry.get("volume_db", 0.0)), crossfade_seconds)
	_fade.chain().tween_callback(old.stop)


## The catalogue sound of `id` set to loop (a copy: the one-shot use stays as it is).
func _loop(id: StringName) -> AudioStream:
	if id == &"" or not Sfx.sounds.has(id):
		return null
	if not _loops.has(id):
		var path := str(Sfx.sounds[id].get("file", ""))
		var source := load(path) as AudioStream if ResourceLoader.exists(path) else null
		var stream: AudioStream = source.duplicate() if source else null
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif stream and &"loop" in stream:
			stream.set(&"loop", true)
		_loops[id] = stream
	return _loops[id]


func _on_entered(_id: StringName) -> void:
	ambush_active = false
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
