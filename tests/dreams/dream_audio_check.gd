extends Node

## Headless check of the dream sound (#201): the sounds of data/audio/dream_audio.json are in
## the Sfx catalogue and load, the stage of Bowser's dream switches the background loop
## (alarm on entry, unease at the ambush, alarm after the seal, pre-awakening at a high
## instability stage, calm on a repeat visit, silence outside) and the ambush, the seal, a
## strike of the chain and the exit through the gate start their stingers.
## Prints `DREAM_AUDIO_CHECK_OK checks=<n>` on success.

const MODULE := &"module_4"
const STINGERS: Array[StringName] = [&"ambush", &"seal", &"gate", &"chain_hit"]

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
	for key: String in ["stages", "stingers"]:
		for name: String in cfg.get(key, {}):
			var id := StringName(str(cfg[key][name]))
			_check(Sfx.sounds.has(id), "%s %s: %s is in the Sfx catalogue" % [key, name, id])
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
	_check(_playing() == cfg.stages.alarm, "the alarm loop plays")

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
	_check(_playing() == cfg.stages.unease, "the unease loop plays after the cross-fade")

	# A strike of the chain (and not of another weapon).
	var combat := DreamCombat.new()
	add_child(combat)
	combat.attacked.emit(&"dream_bolt_not_chain")
	combat.attacked.emit(&"dream_chain")

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
	Dreams.abort()
	DreamAudio.refresh()
	_expect(DreamAudio.SILENT, "after abort")

	for event in STINGERS:
		_check(_stingers.count(event) == 1, "stinger %s played once (got %s)" % [event, _stingers])
	_finish()


func _expect(stage: StringName, label: String) -> void:
	_check(DreamAudio.stage == stage, "%s: stage %s (got %s)" % [label, stage, DreamAudio.stage])


## Sfx id of the loop that plays in front (the other player only fades out).
func _playing() -> StringName:
	var player: AudioStreamPlayer = DreamAudio._players[DreamAudio._current]
	var looped := player.stream is AudioStreamWAV and (player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	return DreamAudio.current_sound if player.playing and looped else &""


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
