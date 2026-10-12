class_name GeneratorSound
extends Node3D

## Sound of a generator at this node (#137): when `running_flag` is set the start plays
## once (`gen_start`) and the running loop (`gen_run`) fades in under its tail; a generator
## that is already running when a game loads only loops. Clearing the flag stops the loop.
## Files, bus and volume come from data/audio/sfx.json, so final sounds replace these there.

const START_ID := &"gen_start"
const RUN_ID := &"gen_run"
const FADE_FROM_DB := -40.0

@export var running_flag: StringName = &"generator_started"
## When the loop starts after the start sound began (seconds): the start's catch and idle.
@export var run_delay := 5.0
## How long the loop takes to fade in under the tail of the start.
@export var run_fade := 1.5

var _loop: AudioStreamPlayer3D
var _running := false
var _tween: Tween


func _ready() -> void:
	_loop = AudioStreamPlayer3D.new()
	_loop.name = "Loop"
	add_child(_loop)
	_setup_loop()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(_sync)
	_sync()


func is_running() -> bool:
	return _running


func _setup_loop() -> void:
	var entry: Dictionary = Sfx.sounds.get(RUN_ID, {})
	var path := str(entry.get("file", ""))
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_loop.stream = stream
	_loop.bus = StringName(str(entry.get("bus", "SFX")))
	_loop.volume_db = float(entry.get("volume_db", 0.0))
	_loop.max_distance = float(entry.get("max_distance", 40.0))


## Matches a loaded game: running generators hum without the start sound.
func _sync() -> void:
	if GameState.has_flag(running_flag):
		_start_loop(0.0, 0.0)
	else:
		_stop()


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag != running_flag:
		return
	if not GameState.has_flag(running_flag):
		_stop()
	elif not _running:
		Sfx.play(START_ID, self)
		_start_loop(run_delay, run_fade)


func _start_loop(delay: float, fade: float) -> void:
	_running = true
	if _loop.stream == null:
		return
	if _tween:
		_tween.kill()
	var target := float(Sfx.sounds.get(RUN_ID, {}).get("volume_db", 0.0))
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(func() -> void:
		_loop.volume_db = FADE_FROM_DB if fade > 0.0 else target
		_loop.play())
	if fade > 0.0:
		_tween.tween_property(_loop, "volume_db", target, fade)


func _stop() -> void:
	_running = false
	if _tween:
		_tween.kill()
	_loop.stop()
