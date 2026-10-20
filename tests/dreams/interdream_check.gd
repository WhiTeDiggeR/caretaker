extends Node

## Headless check of the interdream (#228, docs/game_design/10-interdream.md): the echo data
## is valid; echoes are picked by the progress flags and their priority (the plate «2» on the
## first gate, nothing on death, the flash of the plate on the chemical awakening); an echo
## counts as shown only after `min_seen_seconds` and then sets its flags and adds the plate to
## the journal; the gate plays the corridor with the echo before the hero arrives, the first
## one cannot be skipped, a quiet one can; death tears it without an echo.
## Prints `INTERDREAM_CHECK_OK checks=<n>` on success.

const MODULE := &"module_4"

var _errors := PackedStringArray()
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	Containment.set_process(false)
	Dreams.scene_loader = func(_path: String) -> void: pass
	InterdreamEchoes.reload()
	var problems := InterdreamEchoes.validate()
	_check(problems.is_empty(), "interdream data is valid: %s" % "; ".join(problems))

	GameState.reset()
	var first := InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE)
	_check(first.get("id") == "plate_2_first" and bool(first.get("mandatory")), "the first gate shows the plate «2», not skippable")
	_check(InterdreamEchoes.pick(&"module_3", Dreams.Exit.GATE).is_empty(), "another dream's first exit is quiet")
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.DEATH).is_empty(), "death never gets an echo")
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.WOKEN).get("id") == "plate_2_flash", "the awakening by object 2 flashes the plate")
	GameState.set_flag(&"part2/n2_first_text")
	GameState.set_flag(&"part2/senior_mark")
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE).get("id") == "plate_2_first", "the plate outranks every other echo")
	GameState.set_flag(&"part2/recovery_map")
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE).get("id") == "senior_key", "the key outranks the near silhouette")
	GameState.set_flag(InterdreamEchoes.shown_flag("senior_key"))
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE).get("id") == "silhouette_near", "a shown echo is not repeated")
	GameState.set_flag(&"part2/module4_crisis_resolved")
	GameState.set_flag(&"part2/chem_protocol_fired")
	_check(InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE).get("id") == "plate_2_turned", "the chemical protocol turns the plate away")

	GameState.reset()
	var echo := InterdreamEchoes.pick(MODULE, Dreams.Exit.GATE)
	_check(not InterdreamEchoes.report_seen(echo, 1.0), "an echo seen too briefly does not count")
	_check(not GameState.has_flag(&"part2/dream_trace_2"), "and sets nothing")
	_check(InterdreamEchoes.report_seen(echo, 2.0), "an echo seen long enough counts")
	_check(GameState.has_flag(&"part2/dream_trace_2") and GameState.has_flag(InterdreamEchoes.shown_flag("plate_2_first")), "the plate sets the trace of object 2")
	_check(DocumentLibrary.is_read("dream_plate_2"), "the plate from the dream is in the journal")

	# The gate: the corridor with the plate, before the hero arrives; no skipping.
	GameState.reset()
	var finished: Array = []
	Dreams.interdream_finished.connect(func(_id: StringName, _reason: int, echo_id: String, seen: float) -> void: finished.append([echo_id, seen]))
	var arrived: Array[int] = []
	var veils: Array[float] = []
	Dreams.arrived.connect(func(_id: StringName, reason: int) -> void:
		arrived.append(reason)
		veils.append(Dreams._fade.veil))
	_start_visit()
	Dreams.exit_through_gate()
	await _seconds(Dreams.FADE_SECONDS + 1.6)
	var overlay := Dreams.interdream()
	_check(overlay.playing and overlay.corridor != null, "the corridor plays after the white veil")
	_check(overlay.corridor and overlay.corridor.is_prop_visible("plate_2") and overlay.corridor.is_prop_visible("silhouette_far"), "the plate and the far silhouette stand in the corridor")
	_check(not overlay.skip(), "the first interdream cannot be skipped")
	_check(arrived.is_empty(), "the hero is not in the chair while the corridor plays")
	await _until(func() -> bool: return not arrived.is_empty())
	_check(finished.size() == 1 and finished[0][0] == "plate_2_first" and float(finished[0][1]) >= 1.5, "the plate was seen: %s" % [finished])
	_check(GameState.has_flag(&"part2/dream_trace_2"), "the gate exit leaves the trace of object 2")
	_check(veils.size() == 1 and veils[0] > 0.99, "the corridor washes back into the white veil before the chair")
	await _seconds(Dreams.FADE_SECONDS + 0.2)

	# A later quiet interdream can be skipped after a second.
	GameState.set_flag(&"part2/recovery_map")
	_start_visit()
	var started := Time.get_ticks_msec()
	Dreams.exit_through_gate()
	await _seconds(Dreams.FADE_SECONDS + 0.4)
	_check(overlay.playing and not overlay.skip(), "no skipping in the first second")
	await _seconds(0.8)
	_check(overlay.skip(), "a quiet interdream can be skipped")
	await _until(func() -> bool: return arrived.size() == 2)
	_check(finished.size() == 2 and finished[1][0] == "", "the second interdream was quiet")
	var took := (Time.get_ticks_msec() - started) / 1000.0
	_check(took < Dreams.FADE_SECONDS + InterdreamEchoes.seconds("quiet_seconds", 3.0), "skipping shortens it (%.1f s)" % took)
	await _seconds(Dreams.FADE_SECONDS + 0.2)

	# Death: torn at once, no echo, then the red veil.
	_start_visit()
	Dreams.die()
	await _seconds(0.3)
	_check(overlay.playing and overlay.torn, "death tears the interdream at once")
	_check(overlay.corridor and not overlay.corridor.is_prop_visible("plate_2_flash"), "death shows no echo")
	await _until(func() -> bool: return arrived.size() == 3)
	_check(finished.size() == 3 and finished[2][0] == "", "death had no echo")
	await _seconds(Dreams.FADE_SECONDS + 0.2)

	# The chemical awakening: torn, amber, with a short flash of the plate.
	_start_visit()
	Dreams._leave(Dreams.Exit.WOKEN)
	var flashed := false
	for i in 120:
		await get_tree().process_frame
		if overlay.corridor and overlay.corridor.is_prop_visible("plate_2_flash"):
			flashed = true
			break
	_check(flashed, "object 2 pulling the hero out flashes the plate «2»")
	await _until(func() -> bool: return arrived.size() == 4)
	var expected: Array[int] = [Dreams.Exit.GATE, Dreams.Exit.GATE, Dreams.Exit.DEATH, Dreams.Exit.WOKEN]
	_check(arrived == expected, "every exit arrives after its interdream")
	_finish()


func _start_visit() -> void:
	Dreams.in_dream = true
	Dreams.module_id = MODULE
	Dreams.seal_restored = false


func _seconds(value: float) -> void:
	await get_tree().create_timer(value).timeout


func _until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not condition.call():
		_check(false, "timed out")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_errors.append(message)
		push_error("INTERDREAM_CHECK FAIL: " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("INTERDREAM_CHECK_OK checks=%d" % _checks)
	else:
		print("INTERDREAM_CHECK_FAILED %s" % "; ".join(_errors))
	get_tree().quit(0 if _errors.is_empty() else 1)
