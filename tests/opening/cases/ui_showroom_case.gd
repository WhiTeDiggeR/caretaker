extends RefCounted

## The interface showroom (#151) opens every page and state without errors.

const SHOWROOM := "res://scenes/sandbox/ui_showroom.tscn"


func run(c: OpeningCheck) -> void:
	var showroom: Control = (load(SHOWROOM) as PackedScene).instantiate()
	c.root.add_child(showroom)
	await c.tree.process_frame
	c.equal(showroom.views.size(), ScreenStyle.ERAS.size(), "the first page shows a screen of every era")
	for state in showroom.STATES.size():
		showroom.set_screen_state(state)
	c.is_true(not showroom.views[0].powered, "the last state switches the screens off")
	for page: String in showroom.PAGES:
		showroom.show_page(page)
		await c.tree.process_frame
		c.equal(showroom.page, page, "page %s opens" % page)
	showroom.open_terminal(String(ScreenStyle.ERA_OLD_CORE))
	await c.tree.process_frame
	var screens := c.tree.root.get_children().filter(func(node: Node) -> bool: return node is TerminalScreen)
	c.is_true(screens.size() == 1 and (screens[0] as TerminalScreen).style.era == ScreenStyle.ERA_OLD_CORE, "the showroom opens a terminal of the chosen era")
	for screen: TerminalScreen in screens:
		screen.close()
	showroom.show_veil("Скрыть")
	showroom.queue_free()
	await c.tree.process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
