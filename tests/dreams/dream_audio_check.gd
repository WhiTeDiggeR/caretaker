extends Node

## Headless check of the dream sound (#201): the stingers of data/audio/dream_audio.json are
## in the Sfx catalogue and load, every stage builds a looping stream, the stage of Bowser's dream switches the background loop
## (alarm on entry, unease at the ambush, alarm after the seal, pre-awakening at a high
## instability stage, calm on a repeat visit, silence outside) and the ambush, the seal, a
## swing of the chain, the fight (#218: a blow on an enemy, its death, the hero hurt) and the
## exit through the gate start their stingers. With the sky and
## light of the dream (DreamStageMood, #202) in the scene the sound follows its stage.
## Prints `DREAM_AUDIO_CHECK_OK checks=<n>` on success.

const MODULE := &"module_4"
const STINGERS: Array[StringName] = [&"ambush", &"seal", &"gate", &"chain_hit", &"strike", &"enemy_died", &"hurt"]

var _errors := PackedStringArray()
var _checks := 0
var _stingers: Array[StringName] = []
var _level := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	Containment.set_process(false)
	Dreams.scene_loader = func(_path: String) -> void: pass
	DreamAudio.crossfade_seconds = 0.05
	DreamAudio.instability_stage = func(_id: StringName) -> int: return _level
	DreamAudio.stinger_played.connect(func(event: StringName, _id: StringName) -> void: _stingers.append(event))
	var cfg := DreamAudio.config(MODULE)
	_check(not cfg.is_empty(), "Bowser's dream has a sound config")
	for event: String in cfg.get("stingers", {}):
		var id := StringName(str(cfg.stingers[event]))
		_check(Sfx.sounds.has(id), "stinger %s: %s is in the Sfx catalogue" % [event, id])
	for stage_id: String in [DreamAudio.CALM, DreamAudio.ALARM, DreamAudio.UNEASE, DreamAudio.PREAWAKE]:
		var stream := DreamAudio.stage_stream(MODULE, StringName(stage_id))
		var loops := _loops(stream) and stream.get_length() > 1.0
		_check(loops, "stage %s has a looping background" % stage_id)
	_check(Sfx.validate().is_empty(), "the Sfx catalogue loads: %s" % [Sfx.validate()])
	_check(DreamAudio.stage == DreamAudio.SILENT, "silent outside a dream")

	# Entry (first visit): alarm.
	GameState.clear_flag(StringName(Dreams.RETURNED_PREFIX + String(MODULE)))
	Dreams.in_dream = true
	Dreams.module_id = MODULE
	Dreams.seal_restored = false
	Dreams.entered.emit(MODULE)
	await _frames(10)
	_expect(DreamAudio.ALARM, "entry")
	_check(_playing() == DreamAudio.ALARM, "the alarm loop plays")

	# Ambush: unease and its stinger.
	var ambush := DreamAmbush.new()
	for child: String in ["WakeLine", "Threshold"]:
		var marker := Node3D.new()
		marker.name = child
		ambush.add_child(marker)
	add_child(ambush)
	ambush.ambush_started.emit()
	await _frames(10)
	_expect(DreamAudio.UNEASE, "ambush")
	_check(_playing() == DreamAudio.UNEASE, "the unease loop plays after the cross-fade")

	# A strike of the chain (and not of another weapon).
	var combat := DreamCombat.new()
	add_child(combat)
	combat.attacked.emit(&"dream_bolt_not_chain")
	combat.attacked.emit(&"dream_chain")
	# The fight (#218): a blow that lands, the enemy dissolving, the hero hurt.
	var enemy := DreamEnemy.new()
	add_child(enemy)
	enemy.hit_taken.emit(10.0)
	enemy.died.emit()
	enemy.queue_free()
	combat.hurt.emit(5.0)

	# Seal: back to alarm, stinger.
	Dreams.restore_seal()
	await _frames(10)
	_expect(DreamAudio.ALARM, "seal restored")

	# High instability: pre-awakening.
	_level = int(cfg.get("preawake_min_stage", 3))
	Containment.stage_changed.emit(MODULE, _level)
	_expect(DreamAudio.PREAWAKE, "high instability")
	_level = 0
	Containment.stage_changed.emit(MODULE, _level)

	# Gate: stinger and silence.
	Dreams.exit_through_gate()
	await _frames(10)
	_expect(DreamAudio.SILENT, "after the gate")

	# Repeat visit to a quiet sleeper: calm.
	Dreams.in_dream = true
	Dreams.module_id = MODULE
	Dreams.seal_restored = false
	Dreams.entered.emit(MODULE)
	_expect(DreamAudio.CALM, "repeat visit")

	# The sky and light of the dream lead: the sound follows their stage.
	var mood := DreamStageMood.new()
	mood.environment = Environment.new()
	add_child(mood)
	_expect(DreamAudio.ALARM, "the mood's entry stage")
	mood.set_event_stage(DreamStageMood.Stage.UNREST)
	_expect(DreamAudio.UNEASE, "the mood's unrest")
	mood.set_event_stage(DreamStageMood.Stage.CALM)
	_expect(DreamAudio.CALM, "the mood's calm by the gate")
	mood.queue_free()
	await _frames(2)
	Dreams.abort()
	DreamAudio.refresh()
	_expect(DreamAudio.SILENT, "after abort")

	for event in STINGERS:
		_check(_stingers.count(event) == 1, "stinger %s played once (got %s)" % [event, _stingers])
	_finish()


func _expect(stage: StringName, label: String) -> void:
	_check(DreamAudio.stage == stage, "%s: stage %s (got %s)" % [label, stage, DreamAudio.stage])


## Stage of the loop that plays in front (the other player only fades out).
func _playing() -> StringName:
	var player: AudioStreamPlayer = DreamAudio._players[DreamAudio._current]
	return DreamAudio.current_sound if player.playing and _loops(player.stream) else &""


## A synthesised drone (WAV) or a recorded stage loop (#209, Ogg Vorbis) set to loop.
func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(message)
		push_error("DREAM_AUDIO_CHECK FAIL: " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("DREAM_AUDIO_CHECK_OK checks=%d" % _checks)
	else:
		print("DREAM_AUDIO_CHECK_FAILED %s" % "; ".join(_errors))
	get_tree().quit(0 if _errors.is_empty() else 1)
