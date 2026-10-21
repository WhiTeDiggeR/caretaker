class_name BowserForge
extends Node3D

## The branch «Кузница» of Bowser's dream, second visit «Горн» (#234,
## docs/game_design/09-bowser-dream-v2.md §5): a blockout of primitives in the scene's own
## coordinates, added by BowserDream on the second visit only. The gallery carries the lava to
## the Forge; three sluices cool it, and their order is the cooling scheme the hero takes out:
## the bypass (Ш1, a key stone in its socket opens it) → the feed (Ш2, a key stone knocks out
## its stop and the gate falls) → the quench (Ш3, a wheel picks the level, a lever lets the water
## in). The feed closed before the bypass has the lava nowhere to go and knocks the stone back
## out; the quench opened before the feed meets the lava with water — a blast of steam throws
## the hero aside and costs resolve; a wrong level only boils away. The right level is random
## every visit and shows on the gauge in the quench tank. Mistakes cost time, never instability
## (Б-10). The right order records the scheme (DreamKnowledge, journal), cools the Forge — its
## seal can be turned — and freezes the moat to the optional cold workshop with the mark of the
## senior (SE 067). Taking the first key stone wakes the guards of the gallery (DreamAmbush,
## data/dreams/combat.json `bowser_forge`); they never enter the Forge hall or cross the moat.
## The dream remembers within a visit (GameState system data `bowser_forge`): open sluices,
## stones in sockets, the level; loose stones go back home on a reload; the gate ends the visit.

signal sluice_changed(sluice: int)
signal tempered
signal steam_blast

const SYSTEM := &"bowser_forge"
const SCHEME := &"module_4_cooling"
const LEVELS := 3
const MESSAGE_GROUP := &"message_display"
const PLAYER_GROUP := &"player"
const FORGE_TITLE := "ГОРН"
const SEAL_HOT_PROMPT := "РАСКАЛЕНО — НЕ СДВИНУТЬ"
const OVERFLOW_TEXT := "Лаве некуда уйти: канал вздулся, заслонку выбило, камень скатился на место."
const STEAM_TEXT := "Вода встретила лаву — паром отбросило. Закалка сбросилась."
const WRONG_LEVEL_TEXT := "Вода ушла паром, горн не остыл. Ступень не та."
const NO_LEVEL_TEXT := "Штурвал закрыт: воде некуда идти."
const TEMPERED_TEXT := "Лава ушла в отвод, подача перекрыта, вода пошла в горн. Горн остывает.\nПорядок запомнился — схема записана в журнале."
const WHEEL_PROMPT := "ПОВЕРНУТЬ ШТУРВАЛ ЗАКАЛКИ"
const LEVER_PROMPT := "УДЕРЖИВАТЬ: ОТКРЫТЬ ЗАКАЛКУ"
const QUENCH_DONE_PROMPT := "ЗАКАЛКА ОТКРЫТА"
const RELIEF_PROMPT := "ОСМОТРЕТЬ БАРЕЛЬЕФ"
const RELIEF_TITLE := "БАРЕЛЬЕФ"
const RELIEF_TEXT := "Три картинки, вырезанные в камне. Лава из жёлоба сворачивает в сторону. Заслонка падает поперёк жёлоба. Третья сбита — от неё осталась только капля и зарубки, как на мерной рейке."
const MARK_PROMPT := "ОСМОТРЕТЬ МЕТКУ"
const MARK_DOCUMENT := "bowser_senior_mark"
const MARK_FLAG := &"part2/senior_mark"
const LEVER_HOLD := 2.0
const GATE_RISE := 2.0
const GATE_SECONDS := 1.0
const STEAM_PUSH := 3.0
const STEAM_RESOLVE := 10.0
## Water top in the tank (local y of Tank) for each level; 0 is the empty tank.
const WATER_TOPS: Array[float] = [0.3, 0.6, 1.0, 1.4]
const WATER_BOTTOM := 0.2
const HOT_COLOR := Color(1.0, 0.45, 0.15)
const COOL_COLOR := Color(0.8, 0.86, 1.0)
const HOT_ENERGY := 5.0
const COOL_ENERGY := 1.2
const COOL_SECONDS := 3.0
const CRUST_COLOR := Color(0.12, 0.09, 0.08)
## Ground the guards must not step on: the moat and the cold workshop (the hall has the threshold).
const GUARD_FORBIDDEN := AABB(Vector3(83.5, -5.0, 12.0), Vector3(14.0, 15.0, 16.0))
const ROMAN: Array[String] = ["—", "I", "II", "III"]

@onready var ambush: DreamAmbush = $Ambush
@onready var seal: DreamSealRings = $Hall/Seal
@onready var socket_bypass: DreamStoneSocket = $Sluice1/Socket
@onready var socket_feed: DreamStoneSocket = $Sluice2/Socket
@onready var _gate_bypass: Node3D = $Sluice1/Gate
@onready var _gate_feed: Node3D = $Sluice2/Gate
@onready var _bypass_lava: Node3D = $Bypass
@onready var _lava_east: MeshInstance3D = $Channel/LavaEast
@onready var _lava_west: MeshInstance3D = $Channel/LavaWest
@onready var _channel_hazard: Area3D = $Channel/Hazard
@onready var _channel_crust: StaticBody3D = $Channel/Crust
@onready var _wheel: StaticBody3D = $Quench/Wheel
@onready var _wheel_mark: Label3D = $Quench/WheelMark
@onready var _lever: StaticBody3D = $Quench/Lever
@onready var _steam: CPUParticles3D = $Quench/Steam
@onready var _water: MeshInstance3D = $Tank/Water
@onready var _horn_light: OmniLight3D = $Hall/HornLight
@onready var _hot_plate: MeshInstance3D = $Hall/HotPlate
@onready var _moat_lava: MeshInstance3D = $Workshop/Moat/Lava
@onready var _moat_hazard: Area3D = $Workshop/Moat/Hazard
@onready var _moat_crust: StaticBody3D = $Workshop/Moat/Crust
@onready var _heat_wall: StaticBody3D = $Workshop/Moat/HeatWall

## The level of the quench on this visit (1…LEVELS), shown on the tank's gauge.
var level := 0
## The level the wheel is set to (0 — closed).
var dial := 0
var bypass_open := false
var feed_closed := false
var is_tempered := false
var frozen := false

var _stones: Array[DreamKeyStone] = []
var _wheel_interactable: Interactable
var _lever_interactable: Interactable
var _hot_material: StandardMaterial3D
var _gate_bypass_closed := Vector3.ZERO
var _gate_feed_open := Vector3.ZERO


func _ready() -> void:
	_gate_bypass_closed = _gate_bypass.position
	_gate_feed_open = _gate_feed.position
	_hot_material = (_hot_plate.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_hot_plate.material_override = _hot_material
	ambush.forbidden_boxes = [GUARD_FORBIDDEN]
	_build_controls()
	socket_bypass.filled.connect(_on_bypass_filled)
	socket_feed.filled.connect(_on_feed_filled)
	for stone in stones():
		stone.taken.connect(_on_stone_taken)
	_load_state()
	_apply_instant()
	Dreams.seal_restored_signal.connect(_on_seal_restored)
	Dreams.left.connect(_on_dream_left)


## The key stones of the forge, wherever they are now (hands, sockets, floor).
func stones() -> Array[DreamKeyStone]:
	if _stones.is_empty():
		for node in $Stones.get_children():
			if node is DreamKeyStone:
				_stones.append(node)
	return _stones


func stone(id: StringName) -> DreamKeyStone:
	for key in stones():
		if key.stone_id == id:
			return key
	return null


## Ends the visit's memory of the forge (the gate): the next visit starts with a new level.
static func forget() -> void:
	GameState.set_system_data(SYSTEM, {})


# --- Sluices -----------------------------------------------------------------

func _on_stone_taken() -> void:
	ambush.start()


func _on_bypass_filled(_stone: DreamKeyStone) -> void:
	bypass_open = true
	_save()
	_open_bypass(false)
	sluice_changed.emit(1)


func _on_feed_filled(_stone: DreamKeyStone) -> void:
	if not bypass_open:
		# The lava has nowhere to go: the channel swells and the gate is knocked back up.
		Sfx.play(&"breach_hit", _gate_feed)
		_flare(_lava_west)
		_flare(_lava_east)
		var tween := create_tween()
		tween.tween_property(_gate_feed, "position", _gate_feed_open + Vector3.DOWN * 0.6, 0.2)
		tween.tween_property(_gate_feed, "position", _gate_feed_open, 0.3)
		socket_feed.eject()
		_say(OVERFLOW_TEXT)
		return
	feed_closed = true
	_save()
	_close_feed(false)
	sluice_changed.emit(2)


func _open_bypass(instant: bool) -> void:
	var target := _gate_bypass_closed + Vector3.UP * GATE_RISE
	_bypass_lava.visible = true
	if instant:
		_gate_bypass.position = target
		return
	Sfx.play(&"door_mech", _gate_bypass)
	create_tween().tween_property(_gate_bypass, "position", target, GATE_SECONDS)


func _close_feed(instant: bool) -> void:
	var target := _gate_feed_open + Vector3.DOWN * GATE_RISE
	if instant:
		_gate_feed.position = target
		_set_lava_heat(_lava_east, 0.2, true)
		return
	Sfx.play(&"door_stop", _gate_feed)
	create_tween().tween_property(_gate_feed, "position", target, GATE_SECONDS * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_set_lava_heat(_lava_east, 0.2, false)


# --- Quench ------------------------------------------------------------------

## Turns the wheel to the next level (… → III → I).
func turn_wheel() -> void:
	if is_tempered:
		return
	dial = dial % LEVELS + 1
	Sfx.play(&"valve", _wheel)
	var spokes := _wheel.get_node_or_null(^"Spokes") as Node3D
	if spokes:
		create_tween().tween_property(spokes, "rotation:z", spokes.rotation.z - TAU / LEVELS, 0.4)
	_save()
	_refresh_quench()


## The lever of the quench: lets the water in at the wheel's level.
func open_quench() -> void:
	if is_tempered:
		return
	if dial == 0:
		_say(NO_LEVEL_TEXT)
		return
	if not feed_closed:
		_blast()
		return
	if dial != level:
		dial = 0
		_save()
		_puff()
		_say(WRONG_LEVEL_TEXT)
		_refresh_quench()
		return
	_temper(false)


## The water met the lava: steam throws the hero away from the quench and takes resolve.
func _blast() -> void:
	dial = 0
	_save()
	_puff()
	Sfx.play(&"breach_hit", _steam)
	var hero := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	var combat := get_tree().get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	if hero and combat:
		var away := hero.global_position - _steam.global_position
		# Along the walkway, never across it into the channel.
		var along := Vector3(signf(away.x) if absf(away.x) > 0.01 else 1.0, 0, 0)
		combat.take_damage(STEAM_RESOLVE, _steam.global_position)
		combat.shove(along, STEAM_PUSH)
	_say(STEAM_TEXT)
	_refresh_quench()
	steam_blast.emit()


func _puff() -> void:
	_steam.restart()
	_steam.emitting = true
	Sfx.play(&"gas_release", _steam)


## The right order at the right level: the Forge cools, the seal can be turned, the moat
## freezes, and the hero remembers the scheme.
func _temper(instant: bool) -> void:
	is_tempered = true
	dial = level
	_refresh_quench()
	seal.lock("")
	_freeze_moat(instant)
	_cool_horn(instant)
	if instant:
		return
	_save()
	_puff()
	DreamKnowledge.grant_scheme(SCHEME, level)
	get_tree().call_group(MESSAGE_GROUP, "show_message", FORGE_TITLE, TEMPERED_TEXT)
	tempered.emit()


func _refresh_quench() -> void:
	_wheel_mark.text = ROMAN[clampi(dial, 0, LEVELS)]
	_wheel_interactable.available = not is_tempered
	_wheel_interactable.unavailable_prompt = QUENCH_DONE_PROMPT
	_lever_interactable.available = not is_tempered
	_lever_interactable.unavailable_prompt = QUENCH_DONE_PROMPT


func _set_water(value: int) -> void:
	var top := WATER_TOPS[clampi(value, 0, LEVELS)]
	var box := _water.mesh as BoxMesh
	box.size.y = top - WATER_BOTTOM
	_water.position.y = (top + WATER_BOTTOM) * 0.5


# --- Cooling and freezing ----------------------------------------------------

func _cool_horn(instant: bool) -> void:
	if instant:
		_horn_light.light_color = COOL_COLOR
		_horn_light.light_energy = COOL_ENERGY
		_hot_material.emission_energy_multiplier = 0.1
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(_horn_light, "light_color", COOL_COLOR, COOL_SECONDS)
	tween.tween_property(_horn_light, "light_energy", COOL_ENERGY, COOL_SECONDS)
	tween.tween_property(_hot_material, "emission_energy_multiplier", 0.1, COOL_SECONDS)


func _freeze_moat(instant: bool) -> void:
	_set_lava_heat(_moat_lava, 0.0, instant)
	_moat_hazard.set_deferred(&"monitoring", false)
	_enable_body(_moat_crust, true)
	_enable_body(_heat_wall, false)


## After the seal: the lava of the gallery's channel crusts over; the way back is safer.
func _freeze_channel(instant: bool) -> void:
	frozen = true
	_set_lava_heat(_lava_west, 0.0, instant)
	_set_lava_heat(_lava_east, 0.0, instant)
	_channel_hazard.set_deferred(&"monitoring", false)
	_enable_body(_channel_crust, true)


func _enable_body(body: StaticBody3D, on: bool) -> void:
	body.visible = on
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not on)


## Fades a lava surface towards a dark crust (`heat` 1 molten — the lava's own material … 0 cold).
func _set_lava_heat(surface: MeshInstance3D, heat: float, instant: bool) -> void:
	if heat >= 1.0:
		surface.material_override = null
		return
	var material := surface.material_override as StandardMaterial3D
	if material == null:
		material = PropKit.material(CRUST_COLOR, true)
		material.emission = HOT_COLOR
		material.emission_energy_multiplier = HOT_ENERGY
		surface.material_override = material
	var energy := HOT_ENERGY * heat
	if instant:
		material.emission_energy_multiplier = energy
	else:
		create_tween().tween_property(material, "emission_energy_multiplier", energy, COOL_SECONDS)


## The channel swells: the lava surface heaves up and settles.
func _flare(surface: MeshInstance3D) -> void:
	var base := surface.position
	var tween := create_tween()
	tween.tween_property(surface, "position", base + Vector3.UP * 0.6, 0.15)
	tween.tween_property(surface, "position", base, 0.6)


# --- State -------------------------------------------------------------------

func _load_state() -> void:
	var data := GameState.get_system_data(SYSTEM)
	level = int(data.get("level", 0))
	if level < 1 or level > LEVELS:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		level = rng.randi_range(1, LEVELS)
		data = {}
	dial = int(data.get("dial", 0))
	bypass_open = bool(data.get("bypass", false))
	feed_closed = bool(data.get("feed", false)) and bypass_open
	is_tempered = bool(data.get("tempered", false)) and feed_closed
	frozen = bool(data.get("frozen", false))
	_save()


func _save() -> void:
	GameState.set_system_data(SYSTEM, {
		"level": level, "dial": dial, "bypass": bypass_open, "feed": feed_closed,
		"tempered": is_tempered, "frozen": frozen,
	})


## Puts the remembered state on the scene without effects (load, return after a death).
func _apply_instant() -> void:
	_set_water(level)
	_set_lava_heat(_lava_west, 1.0, true)
	_set_lava_heat(_lava_east, 1.0, true)
	_set_lava_heat(_moat_lava, 1.0, true)
	_bypass_lava.visible = false
	_enable_body(_channel_crust, false)
	_enable_body(_moat_crust, false)
	_enable_body(_heat_wall, true)
	seal.lock(SEAL_HOT_PROMPT)
	if bypass_open:
		socket_bypass.place(stone(&"k1"))
		_open_bypass(true)
	if feed_closed:
		socket_feed.place(stone(&"k2"))
		_close_feed(true)
	if is_tempered:
		_temper(true)
	if frozen:
		_freeze_channel(true)
	_refresh_quench()


func _on_seal_restored(_module_id: StringName) -> void:
	_freeze_channel(false)
	_save()


func _on_dream_left(_module_id: StringName, reason: int) -> void:
	if reason == Dreams.Exit.GATE:
		forget()


# --- Controls ----------------------------------------------------------------

func _build_controls() -> void:
	_wheel_interactable = PropKit.interactable(_wheel, Interactable.Mode.PRESS, WHEEL_PROMPT)
	_wheel_interactable.interacted.connect(turn_wheel)
	_lever_interactable = PropKit.interactable(_lever, Interactable.Mode.HOLD, LEVER_PROMPT)
	_lever_interactable.hold_time = LEVER_HOLD
	_lever_interactable.interacted.connect(open_quench)
	var relief := PropKit.interactable($Relief, Interactable.Mode.INSPECT, RELIEF_PROMPT)
	relief.inspect_title = RELIEF_TITLE
	relief.inspect_text = RELIEF_TEXT
	var mark := PropKit.interactable($Workshop/Mark, Interactable.Mode.INSPECT, MARK_PROMPT, MARK_DOCUMENT)
	mark.sets_flag = MARK_FLAG
	mark.interacted.connect(func() -> void: DocumentLibrary.mark_read(MARK_DOCUMENT))


func _say(text: String) -> void:
	get_tree().call_group(MESSAGE_GROUP, "show_message", FORGE_TITLE, text)
