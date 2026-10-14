extends RefCounted

const TEST_PATH := "user://test_settings.cfg"


func run(c: OpeningCheck) -> void:
	var original_path := Settings.config_path
	Settings.config_path = TEST_PATH
	Settings.reset_all()

	for bus in Settings.BUSES:
		c.is_true(AudioServer.get_bus_index(bus) >= 0, "audio bus %s exists" % bus)
	Settings.set_volume(&"SFX", 50.0)
	c.near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), linear_to_db(0.5), 0.01, "volume percent becomes decibels")
	Settings.set_volume(&"Ambience", 0.0)
	c.is_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")), "zero volume mutes the bus")

	Settings.set_mouse_multiplier(10.0)
	c.near(Settings.mouse_multiplier, Settings.SENSITIVITY_RANGE.y, 0.001, "sensitivity is clamped")
	Settings.set_mouse_multiplier(1.5)
	c.near(Settings.mouse_sensitivity(), Settings.BASE_MOUSE_SENSITIVITY * 1.5, 0.000001, "sensitivity scales the base value")

	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	c.add(player)
	Settings.set_fov(90.0)
	c.near((player.get_node(^"Camera3D") as Camera3D).fov, 90.0, 0.001, "player camera follows the field of view")

	var interact_default := Settings.primary_key(&"interact")
	var forward_default := Settings.primary_key(&"move_forward")
	c.equal(Settings.remap(&"interact", KEY_F), &"", "free key is assigned without a swap")
	c.equal(Settings.primary_key(&"interact"), KEY_F, "interact uses F")
	c.is_true(InputPromptFormatter.format_action(&"interact", "X").begins_with("[F]"), "HUD prompts show the new key")
	c.equal(Settings.remap(&"interact", forward_default), &"move_forward", "taken key swaps with its action")
	c.equal(Settings.primary_key(&"move_forward"), KEY_F, "the other action gets the previous key")
	var crouch_events := InputMap.action_get_events(&"crouch").size()
	Settings.remap(&"crouch", KEY_V)
	c.equal(InputMap.action_get_events(&"crouch").size(), crouch_events, "remap keeps the secondary keys")

	Settings.set_invert_y(true)
	Settings.set_crt_effects(false)
	c.is_true(ScreenStyle.for_era(ScreenStyle.ERA_OLD_CORE).crt_material() == null, "world screens drop the CRT picture when it is off")
	c.equal(Settings.save_settings(), OK, "settings are saved")
	Settings.reset_all()
	c.equal(Settings.primary_key(&"interact"), interact_default, "reset restores the default keys")
	Settings.load_settings()
	c.equal(Settings.primary_key(&"interact"), forward_default, "keys are loaded back")
	c.equal(Settings.primary_key(&"crouch"), KEY_V, "crouch key is loaded back")
	c.is_true(Settings.invert_y and is_equal_approx(Settings.mouse_multiplier, 1.5) and is_equal_approx(Settings.fov, 90.0), "controls are loaded back")
	c.near(Settings.volume[&"SFX"], 50.0, 0.001, "volume is loaded back")
	c.is_true(not Settings.crt_effects, "the CRT effect setting is loaded back")

	var screen := SettingsScreen.open(c.root)
	await c.tree.process_frame
	c.equal(screen.key_buttons.size(), Settings.all_actions().size(), "settings screen lists every action, the dream group too")
	c.is_true(Settings.DREAM_ACTIONS.has(DreamCombat.DASH_ACTION) and screen.key_buttons.has(&"dream_attack"), "dream combat actions are remappable")
	screen.begin_remap(&"journal")
	screen.finish_remap(KEY_K)
	c.equal(Settings.primary_key(&"journal"), KEY_K, "settings screen remaps a key")
	c.equal(screen.key_buttons[&"journal"].text, Settings.key_name(KEY_K), "the row shows the new key")
	c.equal(screen.key_buttons[&"dream_attack"].text, "ЛКМ", "the attack shows its mouse button")
	screen.begin_remap(&"dream_dash")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_XBUTTON1
	click.pressed = true
	screen._input(click)
	c.equal(Settings.primary_key(&"dream_dash"), Settings.mouse_code(MOUSE_BUTTON_XBUTTON1), "a dream action takes a mouse button")
	c.equal(screen.key_buttons[&"dream_dash"].text, "Мышь 4", "the row shows the mouse button")
	screen.close()

	Settings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.config_path = original_path
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
