class_name CoolingTuningPanel
extends Node3D

## Tuning panel of a module's cooling in its technical gallery (#234,
## docs/game_design/09-bowser-dream-v2.md §7): after the emergency repair the cooling runs on
## the make-up until it is tuned by the scheme from the second visit of the module's dream.
## Three valves with the roles of the Forge's sluices, named in the complex's own words — the
## hero has to recognise them himself: «Перепуск» (open), «Подача горячего контура» (close),
## «Охлаждение» (a level 1–3 on the selector, then its valve). The order matters as in the
## dream: the feed closed before the bypass, or the cooling opened before the feed or at a wrong
## level, is a water hammer — the needles jump, the valves go back, and the panel waits
## `SHOCK_SECONDS`; the instability does not grow (the mistake costs real time, which runs
## anyway). The right order spends the scheme and tunes the cooling for good (Cooling.tune).
## Without the scheme (DreamKnowledge) the panel stays shut; the stand beside it opens the
## journal at the scheme. The valves' state is saved (GameState system data `cooling_tuning`).

signal tuned
signal water_hammer

const SYSTEM := &"cooling_tuning"
const SHOCK_SECONDS := 30.0
const LEVELS := 3
const COOLING_HOLD := 1.5
const DARK := Color(0.2, 0.24, 0.26)
const PIPE := Color(0.36, 0.42, 0.46)
const RED := Color(0.55, 0.16, 0.1)
const BLUE := Color(0.16, 0.3, 0.55)
const TITLE := "ОХЛАЖДЕНИЕ · НАСТРОЙКА"
const LABEL_BYPASS := "ПЕРЕПУСК"
const LABEL_FEED := "ПОДАЧА ГОРЯЧЕГО КОНТУРА"
const LABEL_COOLING := "ОХЛАЖДЕНИЕ"
const LEVEL_TEXT := "СТУПЕНЬ %s"
const PROMPT_OPEN := "ОТКРЫТЬ ВЕНТИЛЬ: %s"
const PROMPT_CLOSE := "ЗАКРЫТЬ ВЕНТИЛЬ: %s"
const PROMPT_LEVEL := "ПЕРЕКЛЮЧИТЬ СТУПЕНЬ ОХЛАЖДЕНИЯ"
const PROMPT_COOLING := "УДЕРЖИВАТЬ: ОТКРЫТЬ ОХЛАЖДЕНИЕ"
const PROMPT_JOURNAL := "ОТКРЫТЬ ЖУРНАЛ: СХЕМА ИЗ СНА"
const PROMPT_SHUT_CRISIS := "КОНТУР НА АВАРИЙНОЙ ПОДПИТКЕ"
const PROMPT_SHUT_SCHEME := "НЕТ СХЕМЫ НАСТРОЙКИ"
const PROMPT_SHOCK := "ГИДРОУДАР · ЖДАТЬ"
const PROMPT_DONE := "НАСТРОЕНО"
const BOARD_CRISIS := "НАСТРОЙКА ОХЛАЖДЕНИЯ\nнедоступна: идёт ремонт контура"
const BOARD_NO_SCHEME := "НАСТРОЙКА ОХЛАЖДЕНИЯ\nпорядок неизвестен"
const BOARD_READY := "НАСТРОЙКА ОХЛАЖДЕНИЯ\nконтур на аварийной подпитке"
const BOARD_SHOCK := "ГИДРОУДАР\nвентили возвращены · ждать %d с"
const BOARD_DONE := "ОХЛАЖДЕНИЕ: НОРМА\nнастроено"
const HAMMER_TITLE := "ОХЛАЖДЕНИЕ · ГИДРОУДАР"
const HAMMER_TEXT := "Стрелки скачут, вентили сорвало в исходное. Контур успокоится через %d с."
const MESSAGE_GROUP := &"message_display"

@export var module_id: StringName = &"module_4"
@export var scheme_id: StringName = &"module_4_cooling"

var bypass_open := false
var feed_closed := false
var level := 0

var _shock_left := 0.0
var _bypass: Interactable
var _feed: Interactable
var _selector: Interactable
var _cooling: Interactable
var _journal: Interactable
var _bypass_wheel: Node3D
var _feed_wheel: Node3D
var _cooling_wheel: Node3D
var _level_label: Label3D
var _board: Label3D
var _gauge: RepairGauge


func _ready() -> void:
	_build()
	_load()
	Cooling.phase_changed.connect(func(_id: StringName, _phase: int) -> void: refresh())
	GameState.flag_changed.connect(func(_flag: StringName, _value: Variant) -> void: refresh())
	GameState.state_loaded.connect(func() -> void:
		_load()
		refresh())
	refresh()
	set_process(false)


func _process(delta: float) -> void:
	_shock_left = maxf(_shock_left - delta, 0.0)
	if _shock_left <= 0.0:
		set_process(false)
	refresh()


## The panel can be worked: the crisis is over, the scheme is known, no water hammer pending.
func is_open() -> bool:
	return Cooling.can_tune(module_id) and has_scheme() and _shock_left <= 0.0


func has_scheme() -> bool:
	return DreamKnowledge.active_scheme_for(module_id) == scheme_id


func shock_left() -> float:
	return _shock_left


func toggle_bypass() -> void:
	if not is_open():
		return
	bypass_open = not bypass_open
	Sfx.play(&"valve", _bypass_wheel)
	_turn(_bypass_wheel, bypass_open)
	_save()
	refresh()


func toggle_feed() -> void:
	if not is_open():
		return
	if not feed_closed and not bypass_open:
		# The hot circuit has nowhere to go.
		_water_hammer()
		return
	feed_closed = not feed_closed
	Sfx.play(&"valve", _feed_wheel)
	_turn(_feed_wheel, feed_closed)
	_save()
	refresh()


func next_level() -> void:
	if not is_open():
		return
	level = level % LEVELS + 1
	Sfx.play(&"switch", _level_label)
	_save()
	refresh()


## Opens the cooling at the selected level: right only after the bypass and the feed.
func open_cooling() -> void:
	if not is_open():
		return
	var scheme_level := DreamKnowledge.scheme_level(scheme_id)
	if not bypass_open or not feed_closed or level != scheme_level:
		_water_hammer()
		return
	_turn(_cooling_wheel, true)
	DreamKnowledge.use_scheme(scheme_id)
	Cooling.tune(module_id)
	_save()
	refresh()
	tuned.emit()


func refresh() -> void:
	var open := is_open()
	var done := Cooling.is_tuned(module_id)
	var shut_prompt := _shut_prompt(done)
	for control: Interactable in [_bypass, _feed, _selector, _cooling]:
		control.available = open
		control.unavailable_prompt = shut_prompt
	_bypass.prompt = (PROMPT_CLOSE if bypass_open else PROMPT_OPEN) % LABEL_BYPASS
	_feed.prompt = (PROMPT_OPEN if feed_closed else PROMPT_CLOSE) % LABEL_FEED
	_level_label.text = LEVEL_TEXT % (str(level) if level > 0 else "—")
	_journal.available = has_scheme()
	_journal.unavailable_prompt = ""
	_board.text = _board_text(done)
	_gauge.value = 1.0 if done else (0.55 if _shock_left <= 0.0 else _gauge.value)


func _shut_prompt(done: bool) -> String:
	if done:
		return PROMPT_DONE
	if _shock_left > 0.0:
		return PROMPT_SHOCK
	if not Cooling.can_tune(module_id):
		return PROMPT_SHUT_CRISIS
	return PROMPT_SHUT_SCHEME


func _board_text(done: bool) -> String:
	if done:
		return BOARD_DONE
	if _shock_left > 0.0:
		return BOARD_SHOCK % ceili(_shock_left)
	if not Cooling.can_tune(module_id):
		return BOARD_CRISIS
	if not has_scheme():
		return BOARD_NO_SCHEME
	return BOARD_READY


## A wrong order: the needles jump, the valves go back, the circuit settles for SHOCK_SECONDS.
func _water_hammer() -> void:
	bypass_open = false
	feed_closed = false
	level = 0
	_turn(_bypass_wheel, false)
	_turn(_feed_wheel, false)
	_turn(_cooling_wheel, false)
	_save()
	_shock_left = SHOCK_SECONDS
	set_process(true)
	Sfx.play(&"breach_hit", _gauge)
	var tween := create_tween()
	for value: float in [1.0, 0.1, 0.9, 0.25, 0.75, 0.4, 0.55]:
		tween.tween_property(_gauge, "value", value, 0.12)
	get_tree().call_group(MESSAGE_GROUP, "show_message", HAMMER_TITLE, HAMMER_TEXT % int(SHOCK_SECONDS))
	refresh()
	water_hammer.emit()


func _turn(wheel: Node3D, on: bool) -> void:
	create_tween().tween_property(wheel, "rotation:z", -TAU * 1.5 if on else 0.0, 0.35)


func _load() -> void:
	var data := GameState.get_system_data(SYSTEM)
	bypass_open = bool(data.get("bypass", false))
	feed_closed = bool(data.get("feed", false)) and bypass_open
	level = clampi(int(data.get("level", 0)), 0, LEVELS)
	_bypass_wheel.rotation.z = -TAU * 1.5 if bypass_open else 0.0
	_feed_wheel.rotation.z = -TAU * 1.5 if feed_closed else 0.0
	_cooling_wheel.rotation.z = -TAU * 1.5 if Cooling.is_tuned(module_id) else 0.0


func _save() -> void:
	GameState.set_system_data(SYSTEM, {"bypass": bypass_open, "feed": feed_closed, "level": level})


# --- Placeholder geometry ------------------------------------------------------

func _build() -> void:
	var dark := PropKit.material(DARK)
	var cabinet := StaticBody3D.new()
	cabinet.name = "Cabinet"
	add_child(cabinet)
	PropKit.box(cabinet, Vector3(0, 1.1, -0.2), Vector3(4.2, 2.2, 0.3), dark, true)
	var pipe := PropKit.material(PIPE)
	PropKit.box(self, Vector3(0, 2.45, -0.3), Vector3(4.6, 0.18, 0.18), pipe)
	_bypass_wheel = _valve("Bypass", Vector3(-1.3, 1.2, 0), LABEL_BYPASS, RED)
	_bypass = _bypass_wheel.get_meta(&"interactable")
	_bypass.interacted.connect(toggle_bypass)
	_feed_wheel = _valve("Feed", Vector3(0.0, 1.2, 0), LABEL_FEED, RED)
	_feed = _feed_wheel.get_meta(&"interactable")
	_feed.interacted.connect(toggle_feed)
	_cooling_wheel = _valve("Cooling", Vector3(1.5, 1.2, 0), LABEL_COOLING, BLUE)
	_cooling = _cooling_wheel.get_meta(&"interactable")
	_cooling.mode = Interactable.Mode.HOLD
	_cooling.hold_time = COOLING_HOLD
	_cooling.prompt = PROMPT_COOLING
	_cooling.interacted.connect(open_cooling)
	var selector := StaticBody3D.new()
	selector.name = "Selector"
	selector.position = Vector3(1.5, 1.75, 0.0)
	add_child(selector)
	PropKit.box(selector, Vector3.ZERO, Vector3(0.5, 0.22, 0.12), PropKit.material(Color(0.12, 0.12, 0.13)), true)
	_selector = PropKit.interactable(selector, Interactable.Mode.PRESS, PROMPT_LEVEL)
	_selector.interacted.connect(next_level)
	_level_label = PropKit.label(selector, Vector3(0, 0, 0.07), "", 36, Color(0.95, 0.85, 0.5))
	var stand := StaticBody3D.new()
	stand.name = "JournalStand"
	stand.position = Vector3(-2.5, 0, 0.2)
	add_child(stand)
	PropKit.box(stand, Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.4), dark, true)
	PropKit.box(stand, Vector3(0, 1.15, 0), Vector3(0.45, 0.04, 0.32), PropKit.material(Color(0.75, 0.7, 0.58)), true)
	_journal = PropKit.interactable(stand, Interactable.Mode.PRESS, PROMPT_JOURNAL)
	_journal.interacted.connect(func() -> void: DocumentReader.open_journal_scene(get_tree()))
	_gauge = RepairGauge.new()
	_gauge.name = "Gauge"
	_gauge.caption = "ДАВЛЕНИЕ КОНТУРА"
	_gauge.green_from = 0.45
	_gauge.green_to = 0.65
	_gauge.position = Vector3(-0.7, 1.95, -0.02)
	add_child(_gauge)
	_board = PropKit.label(self, Vector3(0, 2.85, -0.1), "", 40)
	_board.pixel_size = 0.004
	PropKit.label(self, Vector3(0, 3.35, -0.1), TITLE, 44).pixel_size = 0.004


## A hand wheel on a stub of pipe with its caption below; the interactable is kept in meta.
func _valve(valve_name: String, at: Vector3, caption: String, color: Color) -> Node3D:
	var body := StaticBody3D.new()
	body.name = valve_name
	body.position = at
	add_child(body)
	PropKit.box(body, Vector3(0, 0, -0.1), Vector3(0.14, 0.14, 0.2), PropKit.material(PIPE))
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(0, 0, 0.02)
	body.add_child(wheel)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.22
	torus.material = PropKit.material(color)
	rim.mesh = torus
	rim.rotation = Vector3(PI * 0.5, 0, 0)
	wheel.add_child(rim)
	PropKit.box(wheel, Vector3.ZERO, Vector3(0.4, 0.04, 0.04), PropKit.material(color))
	PropKit.box(wheel, Vector3.ZERO, Vector3(0.04, 0.4, 0.04), PropKit.material(color))
	var reach := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.3)
	reach.shape = shape
	body.add_child(reach)
	var label := PropKit.label(body, Vector3(0, -0.38, 0.0), caption, 28)
	label.pixel_size = 0.004
	var interactable := PropKit.interactable(body, Interactable.Mode.PRESS, "")
	wheel.set_meta(&"interactable", interactable)
	return wheel
