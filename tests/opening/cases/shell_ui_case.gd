extends RefCounted

## Shell in variant A with the splash and loading of variant B (#144).

const TEST_DIR := "user://test_shell_saves"
const MENU := "res://scenes/shell/main_menu.tscn"


func run(c: OpeningCheck) -> void:
	var theme := ShellUI.theme()
	c.is_true(theme != null and theme.resource_path == ShellUI.THEME_PATH, "the shell theme is the generated resource")
	c.is_true(theme.has_font(&"font", &"ShellTitle") and theme.get_type_variation_base(&"KeyButton") == &"Button", "the theme carries the shell type variations")

	var column := VBoxContainer.new()
	c.root.add_child(column)
	var first := ShellUI.button(column, "Первый", func() -> void: pass)
	var second := ShellUI.button(column, "Второй", func() -> void: pass, "ЗАМЕТКА")
	c.is_true(first.index_text == "01" and second.index_text == "02" and second.note == "ЗАМЕТКА", "menu items are numbered and keep their note")

	var original_dir := Saves.directory
	Saves.directory = TEST_DIR
	for slot in Saves.SLOTS:
		Saves.delete(slot)
	MainMenu.splash_seen = false
	var menu := (load(MENU) as PackedScene).instantiate() as MainMenu
	c.root.add_child(menu)
	await c.tree.process_frame
	c.is_true(menu.splash != null, "the first menu opens behind the crystal splash")
	c.is_true(menu.continue_button.disabled and menu.continue_button.note.is_empty(), "continue is off and silent without saves")
	menu.dismiss_splash()
	c.is_true(MainMenu.splash_seen and menu.splash == null, "any key dismisses the splash for the rest of the run")

	var frame := Image.create(640, 360, false, Image.FORMAT_RGB8)
	frame.fill(Color(0.2, 0.3, 0.4))
	c.equal(Saves.write("slot_1", c.tree, frame), OK, "a slot is written with a thumbnail")
	var thumb := Saves.thumbnail("slot_1")
	c.is_true(thumb != null and thumb.get_size() == Vector2(Saves.THUMBNAIL_SIZE), "the thumbnail is stored small next to the slot")
	c.equal(Saves.write("slot_3", c.tree), OK, "a slot without a frame is still written")
	c.is_true(Saves.thumbnail("slot_3") == null, "a slot without a frame has no thumbnail")
	var slots := SaveSlotsScreen.open(menu, SaveSlotsScreen.Mode.SAVE)
	await c.tree.process_frame
	c.is_true(slots.slot_buttons["slot_1"].note == Saves.stamp("slot_1") and slots.slot_buttons["slot_2"].note == "ПУСТО", "slots show their date or emptiness on the right")
	c.is_true(slots.slot_buttons["slot_1"].thumbnail != null and slots.slot_buttons["slot_2"].thumbnail == null, "slots show their thumbnails")
	slots.choose("slot_2")
	c.equal(slots.slot_buttons["slot_2"].note, SaveSlotsScreen.WRITTEN_NOTE, "a written slot says so on the right")
	slots.choose("slot_1")
	var dialogs := slots.find_children("*", "ShellConfirm", false, false)
	c.equal(dialogs.size(), 1, "saving over a used slot asks first")
	(dialogs[0] as ShellConfirm).answer(false)
	slots.close()

	var settings := SettingsScreen.open(menu)
	await c.tree.process_frame
	settings.crt_toggle.button_pressed = false
	c.is_true(not Settings.crt_effects, "the settings screen switches the CRT effect")
	settings.crt_toggle.button_pressed = true
	settings.queue_free()

	Saves.delete("slot_1")
	c.is_true(not FileAccess.file_exists(Saves.thumbnail_path("slot_1")), "deleting a slot removes its thumbnail")
	for slot in Saves.SLOTS:
		Saves.delete(slot)
	Saves.directory = original_dir
	menu.queue_free()
	column.queue_free()
	await c.tree.process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
