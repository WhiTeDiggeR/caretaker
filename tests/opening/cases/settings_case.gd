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

	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
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
	c.equal(Settings.save_settings(), OK, "settings are saved")
	Settings.reset_all()
	c.equal(Settings.primary_key(&"interact"), interact_default, "reset restores the default keys")
	Settings.load_settings()
	c.equal(Settings.primary_key(&"interact"), forward_default, "keys are loaded back")
	c.equal(Settings.primary_key(&"crouch"), KEY_V, "crouch key is loaded back")
	c.is_true(Settings.invert_y and is_equal_approx(Settings.mouse_multiplier, 1.5) and is_equal_approx(Settings.fov, 90.0), "controls are loaded back")
	c.near(Settings.volume[&"SFX"], 50.0, 0.001, "volume is loaded back")

	var screen := SettingsScreen.open(c.root)
	await c.tree.process_frame
	c.equal(screen.key_buttons.size(), Settings.ACTIONS.size(), "settings screen lists every action")
	screen.begin_remap(&"journal")
	screen.finish_remap(KEY_K)
	c.equal(Settings.primary_key(&"journal"), KEY_K, "settings screen remaps a key")
	c.equal(screen.key_buttons[&"journal"].text, Settings.key_name(KEY_K), "the row shows the new key")
	screen.close()

	Settings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.config_path = original_path
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
