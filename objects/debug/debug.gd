extends Node

## Playtest tools (autoload `Debug`, #169), present in debug builds only: in a release build
## the node removes itself before doing anything. F10 opens the menu (open a test stand of
## the sandbox, jump to a moment of the game, cheats), F12 writes a bug report. Stands come
## from data/debug/stands.json (DebugStands, #239), moments and cheat lists from
## data/debug/moments.json (DebugMoments). Instructions: docs/playtest.md.

signal moment_loaded(id: StringName)
signal stand_loaded(id: StringName)
signal report_written(folder: String)

const MENU_ACTION := &"debug_menu"
const REPORT_ACTION := &"debug_report"
const PLAYER_GROUP := &"player"
const MENU_LAYER := 110
const TOAST_LAYER := 120
const MENU_WIDTH := 1500.0
## Height of the scrolled stand and moment lists of the menu.
const LIST_HEIGHT := 560.0
## Prefix of the stand buttons' node names (the moment buttons are named by the moment id).
const STAND_BUTTON := "stand_"
## Width of the cheat column against the stand and moment lists.
const CHEATS_RATIO := 0.7
const TOAST_SECONDS := 3.0
const SETTLE_FRAMES := 2
const RETURN_FRAMES := 4
const SCENE_TIMEOUT_FRAMES := 1200
const NOCLIP_SPEED := 8.0
const NOCLIP_FAST := 3.0
const ON := "вкл"
const OFF := "выкл"

## False removes the tools; replaced in tests to check the release behaviour.
var enabled := OS.is_debug_build()
var invulnerable := false
var noclip := false
var last_moment: StringName = &""
var last_stand: StringName = &""
var busy := false

var _data: Dictionary = {}
var _moments: Dictionary[StringName, Dictionary] = {}
var _stands: Array[Dictionary] = []
var _time_scales: Array[float] = []
var _time_scale := 1.0
var _instability_module: StringName = &""
var _player: CharacterBody3D
var _menu: CanvasLayer
var _menu_was_paused := false
var _cheat_buttons: Dictionary[StringName, Button] = {}
var _toast_layer: CanvasLayer
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	if not enabled:
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = DebugMoments.read()
	for moment: Dictionary in _data.get("moments", []):
		_moments[StringName(str(moment.get("id", "")))] = moment
	_time_scales = DebugMoments.time_scales(_data)
	_stands = DebugStands.list()
	if not Containment.modules.is_empty():
		_instability_module = Containment.modules.keys()[Containment.modules.size() - 1]
	_build_toast()
	get_tree().scene_changed.connect(_on_scene_changed)
	# Dream combat is attached to the hero after the dream scene is ready.
	get_tree().node_added.connect(_on_node_added)
	_on_scene_changed()


# --- Stands --------------------------------------------------------------------

## The test stands in menu order (data/debug/stands.json).
func stands() -> Array[Dictionary]:
	return _stands


func stand(id: StringName) -> Dictionary:
	for entry in _stands:
		if StringName(str(entry.get("id", ""))) == id:
			return entry
	return {}


## Loads the stand's scene from a clean state; the stand sets its own progress on load.
## True when it got there.
func open_stand(id: StringName) -> bool:
	var entry := stand(id)
	if entry.is_empty() or busy or Shell.loading:
		push_warning("Debug: cannot open stand %s now" % id)
		return false
	busy = true
	close_menu()
	Dreams.in_dream = false
	GameState.reset()
	var scene := str(entry["scene"])
	Shell.change_scene(scene)
	var arrived := await _wait_for_scene(scene)
	busy = false
	if not arrived:
		push_error("Debug: stand %s did not load" % id)
		return false
	last_stand = id
	show_toast("Стенд: %s" % entry.get("title", id))
	stand_loaded.emit(id)
	return true


# --- Moments -------------------------------------------------------------------

func moment_ids() -> Array[StringName]:
	return _moments.keys()


func moment(id: StringName) -> Dictionary:
	return _moments.get(id, {})


func data() -> Dictionary:
	return _data


## Loads the moment: its scene with a fresh state, the hero at the spawn point, then the
## dream entry (or the full trip and back) when the moment has one. True when it got there.
func go_to_moment(id: StringName) -> bool:
	return await go_to(moment(id), id)


## Loads any entry shaped like a moment (scene, state, spawn, dream); the review hall
## (#192) passes its own stations through here.
func go_to(entry: Dictionary, id: StringName) -> bool:
	if entry.is_empty() or busy or Shell.loading:
		push_warning("Debug: cannot load moment %s now" % id)
		return false
	busy = true
	close_menu()
	# A session left open by an earlier dream would refuse the new entry.
	Dreams.in_dream = false
	# Scene scripts set up their own state on load; the moment goes on top of a clean one.
	GameState.reset()
	var scene := str(entry["scene"])
	Shell.change_scene(scene)
	var arrived := await _wait_for_scene(scene)
	if arrived:
		DebugMoments.apply_state(entry.get("state", {}))
		arrived = DebugMoments.place_player(get_tree().current_scene, _find_player(), entry.get("spawn", {}))
	var dream: Dictionary = entry.get("dream", {})
	if arrived and not dream.is_empty():
		arrived = await _enter_dream(dream, scene)
	busy = false
	if not arrived:
		push_error("Debug: moment %s did not load" % id)
		return false
	last_moment = id
	show_toast("Момент: %s" % entry.get("title", id))
	moment_loaded.emit(id)
	return true


func _enter_dream(dream: Dictionary, return_scene: String) -> bool:
	var module := StringName(str(dream["module"]))
	var dream_scene := Dreams.dream_scene_for(module)
	var entered: bool = await Dreams.enter(module, StringName(str(dream.get("chair", ""))))
	if not entered or not await _wait_for_scene(dream_scene):
		return false
	if not DebugMoments.place_player(get_tree().current_scene, _find_player(), dream.get("spawn", {})):
		return false
	if str(dream.get("seal", "")) == "restored":
		_restore_seal(get_tree().current_scene)
	if str(dream.get("exit", "")) == "gate":
		Dreams.exit_through_gate()
		if not await _wait_for_scene(return_scene):
			return false
		# Dreams places the hero at the chair a couple of frames after the scene change.
		for _frame in RETURN_FRAMES:
			await get_tree().process_frame
	return true


## Solves the seal of the dream scene as the hero would (rings turned by their levers, or
## the plain seal completed): moments right after the visit's main task.
func _restore_seal(scene: Node) -> void:
	for node in scene.find_children("*", "StaticBody3D", true, false):
		var rings := node as DreamSealRings
		if rings:
			for ring in rings.ring_count:
				for _turn in DreamSealRings.POSITIONS:
					if rings.is_ring_aligned(ring):
						break
					rings.turn(ring)
		elif node is DreamSeal:
			(node as DreamSeal).complete()


## Waits until `path` is the current scene and has settled for a couple of frames.
func _wait_for_scene(path: String) -> bool:
	var tree := get_tree()
	# The old scene may still be current for a frame after the change was asked.
	await tree.process_frame
	for _i in SCENE_TIMEOUT_FRAMES:
		if tree.current_scene and tree.current_scene.scene_file_path == path and not Shell.loading:
			for _frame in SETTLE_FRAMES:
				await tree.process_frame
			return true
		await tree.process_frame
	return false


# --- Cheats --------------------------------------------------------------------

func set_invulnerable(on: bool) -> void:
	invulnerable = on
	_refresh_cheat_buttons()


func set_noclip(on: bool) -> void:
	noclip = on
	_apply_noclip()
	_refresh_cheat_buttons()


## Grants every access and key flag listed under `cheats` in the moments data.
func grant_all_access() -> void:
	var cheats: Dictionary = _data.get("cheats", {})
	for grant: Variant in cheats.get("access", []):
		GameState.grant_access(StringName(str(grant)))
	for flag: Variant in cheats.get("flags", []):
		GameState.set_flag(StringName(str(flag)))
	show_toast("Допуски и ключи выданы")


func set_instability(module: StringName, value: float) -> void:
	Containment.set_instability(module, value)
	show_toast("%s: нестабильность %d %%" % [module, roundi(Containment.get_instability(module))])


func set_time_scale(scale: float) -> void:
	_time_scale = scale
	Containment.time_scale = scale
	_refresh_cheat_buttons()


func cycle_time_scale() -> void:
	var index := (_time_scales.find(_time_scale) + 1) % _time_scales.size()
	set_time_scale(_time_scales[index])


func cycle_instability_module() -> void:
	var modules := Containment.modules.keys()
	if modules.is_empty():
		return
	_instability_module = modules[(modules.find(_instability_module) + 1) % modules.size()]
	_refresh_cheat_buttons()


func _on_scene_changed() -> void:
	_player = _find_player()
	_apply_noclip()
	# Scenes may reset the containment clock when they leave (the sandbox does).
	Containment.time_scale = _time_scale


func _on_node_added(node: Node) -> void:
	var combat := node as DreamCombat
	if combat:
		combat.hurt.connect(_on_combat_hurt.bind(combat))


func _on_combat_hurt(_amount: float, combat: DreamCombat) -> void:
	# `hurt` comes before the zero check, so a refill here keeps the hero in the dream.
	if invulnerable:
		combat.resolve = combat.max_resolve
		combat.resolve_changed.emit(combat.resolve, combat.max_resolve)


func _apply_noclip() -> void:
	if is_instance_valid(_player):
		_player.set_physics_process(not noclip)
		_player.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not noclip or not is_instance_valid(_player) or get_tree().paused or bool(_player.get(&"controls_locked")):
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var rise := Input.get_axis(&"crouch", &"jump")
	var camera := _player.get_node_or_null(^"Camera3D") as Node3D
	var basis := camera.global_basis if camera else _player.global_basis
	var direction := basis * Vector3(input.x, 0.0, input.y) + Vector3.UP * rise
	var speed := NOCLIP_SPEED * (NOCLIP_FAST if Input.is_action_pressed(&"sprint") else 1.0)
	_player.global_position += direction.limit_length(1.0) * speed * delta


func _find_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as CharacterBody3D


# --- Bug report ----------------------------------------------------------------

## Writes a bug report (screenshot first, before the notice covers the frame) and returns
## its folder, "" on failure.
func write_report() -> String:
	var screenshot: Image = await BugReport.grab_screenshot(get_tree())
	var folder := BugReport.write(get_tree(), screenshot, {"debug": _cheat_state()})
	if folder.is_empty():
		show_toast("Отчёт не сохранён — см. журнал")
		return ""
	show_toast("Отчёт сохранён: %s" % ProjectSettings.globalize_path(folder))
	print("Debug: bug report ", ProjectSettings.globalize_path(folder))
	report_written.emit(folder)
	return folder


func _cheat_state() -> Dictionary:
	return {
		"last_moment": String(last_moment),
		"last_stand": String(last_stand),
		"invulnerable": invulnerable,
		"noclip": noclip,
		"time_scale": _time_scale,
	}


# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(MENU_ACTION):
		toggle_menu()
	elif event.is_action_pressed(REPORT_ACTION):
		write_report()
	elif is_menu_open() and event.is_action_pressed(&"ui_cancel"):
		close_menu()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Menu ----------------------------------------------------------------------

func is_menu_open() -> bool:
	return _menu != null


func toggle_menu() -> void:
	if is_menu_open():
		close_menu()
	elif not busy:
		open_menu()


## The full menu: stands, moments and cheats; `stands_only` (the main menu item «Полигон»)
## shows just the list of stands.
func open_menu(stands_only: bool = false) -> void:
	if is_menu_open():
		return
	_menu_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = CanvasLayer.new()
	_menu.layer = MENU_LAYER
	_menu.name = &"DebugMenu"
	add_child(_menu)
	var title := "Полигон" if stands_only else "Отладка"
	var column := ShellUI.screen(_menu, title, MENU_WIDTH * 0.5 if stands_only else MENU_WIDTH, "ПЛЕЙТЕСТ · ТОЛЬКО DEBUG-СБОРКА")
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override(&"separation", 32)
	column.add_child(sides)
	var stand_list := _side(sides, "Тестовые сцены", true)
	for entry in _stands:
		var id := StringName(str(entry.get("id", "")))
		var button := ShellUI.button(stand_list, str(entry.get("title", id)), func() -> void: open_stand(id))
		button.name = STAND_BUTTON + String(id)
		# Long titles are clipped rather than widening the menu past the screen.
		button.clip_text = true
	if stands_only:
		ShellUI.button(column, "Закрыть", close_menu, "ESC")
		_focus_first(stand_list)
		return
	var moments := _side(sides, "Моменты игры", true)
	for id: StringName in _moments:
		var entry := _moments[id]
		var note := "СЦЕНА %s" % entry["story_scene"] if entry.has("story_scene") else ""
		var button := ShellUI.button(moments, str(entry["title"]), func() -> void: go_to_moment(id), note)
		button.name = String(id)
		button.clip_text = true
	var cheats := _side(sides, "Читы")
	cheats.size_flags_stretch_ratio = CHEATS_RATIO
	_cheat_buttons.clear()
	_cheat_buttons[&"invulnerable"] = ShellUI.button(cheats, "Неуязвимость", func() -> void: set_invulnerable(not invulnerable))
	_cheat_buttons[&"noclip"] = ShellUI.button(cheats, "Ноклип и полёт", func() -> void: set_noclip(not noclip))
	ShellUI.button(cheats, "Выдать допуски и ключи", grant_all_access)
	_cheat_buttons[&"time"] = ShellUI.button(cheats, "Ускорение времени", cycle_time_scale)
	_cheat_buttons[&"module"] = ShellUI.button(cheats, "Нестабильность модуля", cycle_instability_module)
	# Three per row: the cheat column is the narrowest of the three.
	var values := GridContainer.new()
	values.columns = 3
	cheats.add_child(values)
	for value: Variant in (_data.get("cheats", {}) as Dictionary).get("instability_values", []):
		var button := Button.new()
		button.text = "%d %%" % int(value)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: set_instability(_instability_module, float(value)))
		values.add_child(button)
	ShellUI.button(cheats, "Отчёт о баге", write_report, "F12")
	ShellUI.button(cheats, "Закрыть", close_menu, "F10")
	_refresh_cheat_buttons()
	_focus_first(stand_list)


func _focus_first(list: Control) -> void:
	for child in list.get_children():
		if child is ShellButton:
			(child as Control).grab_focus.call_deferred()
			return


func close_menu() -> void:
	if not is_menu_open():
		return
	_menu.queue_free()
	_menu = null
	_cheat_buttons.clear()
	get_tree().paused = _menu_was_paused
	if not _menu_was_paused and _find_player():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A titled column of the menu; `scrolled` puts its items into a scroll box (the column
## returned is the one to fill).
func _side(parent: Control, title: String, scrolled: bool = false) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override(&"separation", ShellUI.COLUMN_GAP)
	parent.add_child(side)
	ShellUI.label(side, title.to_upper(), &"ShellKicker")
	if not scrolled:
		return side
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	side.add_child(scroll)
	var items := VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override(&"separation", 2)
	scroll.add_child(items)
	return items


func _refresh_cheat_buttons() -> void:
	if _cheat_buttons.is_empty():
		return
	(_cheat_buttons[&"invulnerable"] as ShellButton).note = ON if invulnerable else OFF
	(_cheat_buttons[&"noclip"] as ShellButton).note = ON if noclip else OFF
	(_cheat_buttons[&"time"] as ShellButton).note = "×%d" % roundi(_time_scale)
	(_cheat_buttons[&"module"] as ShellButton).note = String(_instability_module)


# --- Notice --------------------------------------------------------------------

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = TOAST_LAYER
	# Kept out of save thumbnails like the HUD.
	_toast_layer.add_to_group(Saves.HUD_GROUP)
	add_child(_toast_layer)
	_toast = Label.new()
	_toast.theme = ShellUI.theme()
	_toast.theme_type_variation = &"ShellKicker"
	_toast.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override(&"outline_size", 4)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.visible = false
	_toast_layer.add_child(_toast)


## A short line in the bottom-right corner that fades out.
func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(_toast.hide)


func toast_text() -> String:
	return _toast.text if _toast.visible else ""
