extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"


func run(c: OpeningCheck) -> void:
	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	await c.physics_frames(2)
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	c.is_true(player != null, "sandbox has the player")
	c.is_true(player.interact_label != null, "player prompt is bound to the HUD")
	var hud := sandbox.get_node(^"OpeningHud") as OpeningHud
	c.equal(hud.objective_label.text, "ЦЕЛЬ: Прочитать памятку на станции документов", "HUD shows the objective from GameState")
	c.equal(GameState.get_section_power(&"sandbox_a"), GameState.Power.EMERGENCY, "sandbox sections start on emergency power")
	GameState.set_objective(&"next", "Следующая цель")
	c.equal(hud.objective_label.text, "ЦЕЛЬ: Следующая цель", "HUD follows objective changes")
	hud.show_hint("Проверка подсказки")
	await c.tree.process_frame
	var screen := Rect2(Vector2.ZERO, hud.get_viewport().get_visible_rect().size)
	c.is_true(hud.hint_label.visible and screen.encloses(hud.hint_label.get_global_rect()), "the hint is drawn inside the screen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
