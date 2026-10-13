extends Node

## Sound effects (autoload `Sfx`): plays sounds of the catalogue data/audio/sfx.json by id,
## in 3D at a node or point, or flat. Systems only name the id, so final sounds replace the
## generated placeholders (loads/audio/sfx, tools/audio/make_sfx.py) in the catalogue alone.
## Global events (containment, dreams, defeat, hints) are connected here.

signal requested(id: StringName)

const DATA_PATH := "res://data/audio/sfx.json"
const MAX_FLAT := 6
const MAX_SPATIAL := 12
## Pitch range a retimed sound (`play_on`) may be stretched to.
const PITCH_MIN := 0.6
const PITCH_MAX := 2.0

## id -> {"file", "bus", "volume_db", "positional", "max_distance", "pitch_jitter"}
var sounds: Dictionary[StringName, Dictionary] = {}

var _streams: Dictionary[StringName, AudioStream] = {}
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _stages: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_catalogue()
	Containment.stage_changed.connect(_on_stage_changed)
	Containment.chemical_warning.connect(func(_id: StringName, _seconds: float) -> void: play(&"chem_warning"))
	Containment.module_sealed.connect(func(_id: StringName) -> void: play(&"gas_release"))
	Dreams.entered.connect(func(_id: StringName) -> void: play(&"dream_enter"))
	Dreams.left.connect(func(_id: StringName, _reason: int) -> void: play(&"dream_exit"))
	# Defeat (#123) and hints (#125) are delivered separately: connect when present.
	if Shell.has_signal(&"defeated"):
		Shell.connect(&"defeated", func(_reason: StringName) -> void: play(&"defeat"))
	var hints := get_node_or_null(^"/root/Hints")
	if hints and hints.has_signal(&"hint_shown"):
		hints.connect(&"hint_shown", func(_id: StringName, _text: String) -> void: play(&"hint"))
	GameState.state_loaded.connect(_remember_stages)
	_remember_stages()


func load_catalogue() -> void:
	sounds.clear()
	_streams.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var raw: Dictionary = (parsed as Dictionary).get("sounds", {}) if parsed is Dictionary else {}
	for id: String in raw:
		sounds[StringName(id)] = raw[id]


## Problems in the catalogue: unknown buses and files that do not load.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in sounds:
		var entry := sounds[id]
		if AudioServer.get_bus_index(StringName(str(entry.get("bus", "SFX")))) < 0:
			errors.append("%s: unknown bus %s" % [id, entry.get("bus")])
		if _stream(id) == null:
			errors.append("%s: cannot load %s" % [id, entry.get("file")])
	return errors


## Plays a sound; `at` is a Node3D or a Vector3 for positional sounds, null for flat ones.
## `volume_offset_db` is added to the catalogue volume (quiet steps, soft landings).
func play(id: StringName, at: Variant = null, volume_offset_db: float = 0.0) -> void:
	requested.emit(id)
	var stream := _stream(id)
	if stream == null:
		return
	var entry := sounds[id]
	var position: Variant = null
	if at is Node3D and (at as Node3D).is_inside_tree():
		position = (at as Node3D).global_position
	elif at is Vector3:
		position = at
	if bool(entry.get("positional", false)) and position != null:
		var player := _free_spatial()
		player.global_position = position
		player.max_distance = float(entry.get("max_distance", 25.0))
		_start(player, stream, entry, volume_offset_db)
	else:
		_start(_free_flat(), stream, entry, volume_offset_db)


## Plays a sound on a player the caller owns and may stop (a hand wheel let go mid-turn).
## `duration` > 0 retimes the sound to last that long by its pitch.
func play_on(player: AudioStreamPlayer3D, id: StringName, duration: float = 0.0, volume_offset_db: float = 0.0) -> void:
	requested.emit(id)
	var stream := _stream(id)
	if stream == null:
		return
	var entry := sounds[id]
	player.max_distance = float(entry.get("max_distance", 25.0))
	_start(player, stream, entry, volume_offset_db)
	if duration > 0.0 and stream.get_length() > 0.0:
		player.pitch_scale = clampf(stream.get_length() / duration, PITCH_MIN, PITCH_MAX)


## Repeated sounds (footsteps) vary their pitch by up to `pitch_jitter` either way.
func _start(player: Node, stream: AudioStream, entry: Dictionary, volume_offset_db: float) -> void:
	var jitter := float(entry.get("pitch_jitter", 0.0))
	player.set("stream", stream)
	player.set("bus", StringName(str(entry.get("bus", "SFX"))))
	player.set("volume_db", float(entry.get("volume_db", 0.0)) + volume_offset_db)
	player.set("pitch_scale", 1.0 + randf_range(-jitter, jitter))
	player.call("play")


func _stream(id: StringName) -> AudioStream:
	if not sounds.has(id):
		push_warning("Sfx: unknown sound %s" % id)
		return null
	if not _streams.has(id):
		var path := str(sounds[id].get("file", ""))
		_streams[id] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[id]


func _free_flat() -> AudioStreamPlayer:
	for player in _flat:
		if not player.playing:
			return player
	if _flat.size() < MAX_FLAT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_flat.append(player)
		return player
	var oldest: AudioStreamPlayer = _flat.pop_front()
	_flat.append(oldest)
	return oldest


func _free_spatial() -> AudioStreamPlayer3D:
	for player in _spatial:
		if not player.playing:
			return player
	if _spatial.size() < MAX_SPATIAL:
		var player := AudioStreamPlayer3D.new()
		add_child(player)
		_spatial.append(player)
		return player
	var oldest: AudioStreamPlayer3D = _spatial.pop_front()
	_spatial.append(oldest)
	return oldest


func _remember_stages() -> void:
	_stages.clear()
	for id: StringName in Containment.modules:
		_stages[id] = Containment.get_stage(id)


## A module getting worse sounds the alarm; calming down is silent.
func _on_stage_changed(id: StringName, stage: int) -> void:
	var previous: int = _stages.get(id, stage)
	_stages[id] = stage
	if stage > previous:
		play(&"alarm_stage")
