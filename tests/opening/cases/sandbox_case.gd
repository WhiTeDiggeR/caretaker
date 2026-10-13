extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"


func run(c: OpeningCheck) -> void:
	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	await c.physics_frames(2)
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	c.is_true(player != null, "sandbox has the player")
	c.is_true(player.interact_label != null, "player prompt is bound to the HUD")
	var hud := sandbox.get_node(^"OpeningHud") as OpeningHud
	c.equal(hud.objective_label.text, "Прочитать памятку на станции документов", "HUD shows the objective from GameState")
	c.is_true(hud.objective_heading.visible, "the objective has its heading")
	c.equal(GameState.get_section_power(&"sandbox_a"), GameState.Power.EMERGENCY, "sandbox sections start on emergency power")
	# Debug keys 7 and 8 (F7/F8 belong to the editor: pause and stop the project).
	sandbox._unhandled_input(_key(KEY_7))
	c.near(Containment.time_scale, 10.0, 0.001, "key 7 speeds up containment time")
	Containment.time_scale = 1.0
	sandbox._unhandled_input(_key(KEY_8))
	c.is_true(GameState.has_flag(Containment.CATASTROPHE_FLAG), "key 8 wakes modules 3 and 4 (catastrophe)")
	GameState.set_objective(&"next", "Следующая цель")
	c.equal(hud.objective_label.text, "Следующая цель", "HUD follows objective changes")
	hud.show_hint("Проверка подсказки")
	await c.tree.process_frame
	var screen := Rect2(Vector2.ZERO, hud.get_viewport().get_visible_rect().size)
	c.is_true(hud.hint_label.visible and screen.encloses(hud.hint_label.get_global_rect()), "the hint is drawn inside the screen")
	var prompt := hud.interact_label as HudPrompt
	prompt.text = "[E] ОТКРЫТЬ ГЕРМОДВЕРЬ"
	c.equal(prompt.parts(), PackedStringArray(["E", "ОТКРЫТЬ ГЕРМОДВЕРЬ"]), "the prompt splits into the key and the action")
	prompt.text = "НЕТ ПИТАНИЯ"
	c.equal(prompt.parts(), PackedStringArray(["", "НЕТ ПИТАНИЯ"]), "an unavailable prompt has no key")
	DocumentLibrary.mark_read("sandbox_memo")
	c.is_true(hud.journal_toast.visible and hud.toast_text.text.contains("«Памятка полигона»"), "a new journal document shows the notice")
	c.is_true(hud.dream_profile == null and hud.alert_label != null, "the HUD in reality has no dream look and listens to the chemical protocol")
	hud.show_saved("auto")
	c.is_true(hud.save_indicator.visible and hud.save_label.text == OpeningHud.SAVE_WRITING and hud.save_icon.state == SaveIcon.State.WRITING, "a save shows the running crystal in the HUD")
	var save_layer := hud.save_indicator.get_parent() as CanvasLayer
	c.is_true(save_layer.layer > ScreenEffects.layer and save_layer.layer < Dreams._fade.layer and save_layer.is_in_group(Saves.HUD_GROUP), "the save indicator stays above gas and waking, under the dream veil, out of thumbnails")
	c.is_true(hud.is_in_group(Saves.DISPLAY_GROUP) and hud.is_in_group(Saves.HUD_GROUP), "the HUD hears saves and hides for thumbnails")
	Containment.chemical_warning.emit(&"module_4", 10.0)
	c.is_true(hud.alert_label.visible and hud.alert_label.text.contains("МОДУЛЬ 4") and hud.alert_label.text.contains("00:10"), "the chemical warning shows the module and the countdown")
	# #123: the gas chamber floor lights up and the overlay says whether the hero stands in it.
	Containment.set_hero_inside(&"module_4", true)
	sandbox._refresh_overlay()
	c.is_true(sandbox._overlay.text.contains("ВЫ ВНУТРИ") and sandbox._zone_material.albedo_color == sandbox.ZONE_INSIDE_COLOR, "the sandbox shows the hero inside the gas chamber")
	Containment.set_hero_inside(&"module_4", false)
	sandbox._refresh_overlay()
	c.is_true(sandbox._overlay.text.contains("вы снаружи") and sandbox._zone_material.albedo_color == sandbox.ZONE_OUTSIDE_COLOR, "the sandbox shows the hero outside the gas chamber")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
