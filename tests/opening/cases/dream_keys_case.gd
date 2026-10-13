extends RefCounted

## #189: dream combat actions in the remappable keys — their own group, mouse buttons, swaps
## only within the group, prompts with the current binding, saved and loaded.

const TEST_PATH := "user://test_dream_keys.cfg"


func run(c: OpeningCheck) -> void:
	var original_path := Settings.config_path
	Settings.config_path = TEST_PATH
	Settings.reset_all()
	var attack_default := Settings.primary_key(&"dream_attack")
	var dash_default := Settings.primary_key(&"dream_dash")
	c.equal(attack_default, Settings.mouse_code(MOUSE_BUTTON_LEFT), "the attack is on the left mouse button by default")
	c.equal(dash_default, KEY_Q, "the dash is on Q by default")
	c.equal(InputPromptFormatter.action_label(&"dream_attack"), "ЛКМ", "prompts name the mouse button")
	c.equal(InputPromptFormatter.action_label(&"dream_alt_attack"), "ПКМ", "prompts name the right mouse button")
	c.equal(Settings.group_of(&"dream_dash"), Settings.DREAM_ACTIONS, "the dash belongs to the dream group")

	# Across groups a binding may repeat: dream actions work only in a dream.
	var interact_key := Settings.primary_key(&"interact")
	c.equal(Settings.remap(&"dream_dash", interact_key), &"", "a key of the complex is taken without a swap")
	c.is_true(Settings.primary_key(&"dream_dash") == interact_key and Settings.primary_key(&"interact") == interact_key, "the complex keeps its key")
	c.equal(InputPromptFormatter.action_label(&"dream_dash"), InputPromptFormatter.action_label(&"interact"), "the dash prompt shows the new key")

	# Within the group a taken binding swaps, as for the complex.
	c.equal(Settings.remap(&"dream_dash", Settings.mouse_code(MOUSE_BUTTON_LEFT)), &"dream_attack", "a taken dream binding swaps")
	c.equal(Settings.primary_key(&"dream_attack"), interact_key, "the attack gets the dash's previous key")
	c.equal(InputPromptFormatter.action_label(&"dream_dash"), "ЛКМ", "the dash prompt shows the mouse button")
	c.is_true(InputMap.action_get_events(&"dream_dash").size() == 1 and InputMap.action_get_events(&"dream_attack")[0] is InputEventKey, "the actions hold the new bindings")

	# Pressing the new binding triggers the action.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	c.is_true(click.is_action_pressed(&"dream_dash") and not click.is_action_pressed(&"dream_attack"), "the left button now dashes, not attacks")

	# Saved and loaded.
	c.equal(Settings.save_settings(), OK, "settings are saved")
	Settings.reset_all()
	c.is_true(Settings.primary_key(&"dream_attack") == attack_default and Settings.primary_key(&"dream_dash") == dash_default, "reset restores the dream bindings")
	Settings.load_settings()
	c.equal(Settings.primary_key(&"dream_dash"), Settings.mouse_code(MOUSE_BUTTON_LEFT), "a mouse binding is loaded back")
	c.equal(Settings.primary_key(&"dream_attack"), interact_key, "a key binding is loaded back")

	Settings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.config_path = original_path
