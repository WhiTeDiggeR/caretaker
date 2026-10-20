extends RefCounted

## #230: the terminal of post 2 on the sandbox station — ambiguous images until the link
## board from the early lab is installed, then the text channel: the first text of №2 sets
## `part2/n2_first_text` once; after the module 4 crisis №2 replies (aware of whether the hero
## believed him) and sets `part2/n2_reply`. The channel lives in flags, so a save keeps it.

const STATION := "res://scenes/sandbox/stations/lower_station.tscn"
const PART_FLAG := &"item_n2_link_part"
const INSTALLED_FLAG := &"part2/n2_link_installed"
const FIRST_FLAG := &"part2/n2_first_text"
const RESOLVED_FLAG := &"part2/module4_crisis_resolved"
const REPLY_FLAG := &"part2/n2_reply"
const FIRST_TEXT := "МОДУЛЬ 4. ОХЛАЖДЕНИЕ. ЧАС."
const REPLY_TEXT := "ОБЪЕКТ 2. КАМЕРА ПОВРЕЖДЕНА. МНЕ НУЖЕН ОПЕРАТОР."


func run(c: OpeningCheck) -> void:
	GameState.reset()
	var station := c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	var terminal := station.get_node(^"Post2/Terminal") as Terminal
	var program := terminal.program
	c.equal(program.errors, PackedStringArray(), "the post 2 channel loads")
	c.equal(program.era, ScreenStyle.ERA_OLD_CORE, "post 2 runs on an old queue screen")
	c.is_true(not terminal.is_powered(), "the post terminal is dark until the lower circuit has power")
	GameState.set_section_power(&"lower_main", GameState.Power.MAIN)
	c.is_true(terminal.is_powered(), "the lower circuit powers the post terminal")

	# Images before the repair: the scheme of the link node with a cross.
	var images := program.enter(program.start)
	c.equal(images["id"], "images", "before the repair the post shows images")
	c.is_true(_text(images).contains("X") and _text(images).contains("УЗЕЛ"), "the images show the link node crossed out")
	c.is_true(not _text(images).contains(FIRST_TEXT), "no text before the repair")
	var node := program.enter(program.choose("images", 0))
	c.is_true(not node["options"][0]["available"], "nothing to install without the board")
	c.equal(program.choose("node", 0), "", "installing without the board does nothing")

	# The board lies in the early lab of the same direction.
	var pickup := station.get_node(^"EarlyLab/LinkPart") as ItemPickup
	c.equal(pickup.flag, PART_FLAG, "the lab holds the link board")
	c.is_true(ItemCatalog.has(PART_FLAG), "the board is a carried item")
	pickup.take()
	c.is_true(_carried(PART_FLAG), "the board is carried")
	c.is_true(program.enter("node")["options"][0]["available"], "the board can be installed")
	var target := program.choose("node", 0)
	c.is_true(GameState.has_flag(INSTALLED_FLAG) and not _carried(PART_FLAG), "the board is installed and leaves the pockets")

	# First text: once.
	var first := program.enter(target)
	c.equal(first["id"], "first_text", "the repaired channel prints the first text")
	c.is_true(_text(first).contains(FIRST_TEXT), "the first text warns about module 4 cooling")
	c.is_true(not GameState.has_flag(FIRST_FLAG), "the flag waits for the text to be printed")
	var changes := [0]
	var count := func(flag: StringName, _value: Variant) -> void:
		if flag == FIRST_FLAG:
			changes[0] += 1
	GameState.flag_changed.connect(count)
	program.complete("first_text")
	c.is_true(GameState.has_flag(FIRST_FLAG), "the first text sets its flag")
	var waiting := program.enter(program.start)
	c.equal(waiting["id"], "main", "afterwards the channel waits")
	program.complete(waiting["id"])
	c.equal(changes[0], 1, "the first text is received exactly once")
	GameState.flag_changed.disconnect(count)
	c.is_true(not _text(waiting).contains("ОБЪЕКТ 2"), "no reply before the crisis is over")

	# Reply after the crisis, aware of trust.
	GameState.set_flag(RESOLVED_FLAG)
	var reply := program.enter(program.start)
	c.equal(reply["id"], "reply", "after the crisis №2 replies")
	c.is_true(_text(reply).contains("СРАЗУ"), "a hero who hesitated hears a reproach")
	GameState.set_flag(&"part2/n2_believed")
	c.is_true(_text(program.enter("reply")).contains("ТЫ УСПЕЛ"), "a hero who believed hears it")
	var who := program.enter(program.choose("reply", 0))
	c.is_true(_text(who).contains(REPLY_TEXT), "№2 names himself only as an object")
	program.complete(who["id"])
	c.is_true(GameState.has_flag(REPLY_FLAG), "the reply is remembered")
	c.equal(program.enter(program.start)["id"], "after_reply", "the channel keeps the last message")

	# Save and load keep the channel.
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	await c.tree.process_frame
	c.equal(program.enter(program.start)["id"], "images", "a fresh state has no channel")
	GameState.from_dict(saved)
	await c.tree.process_frame
	c.equal(program.enter(program.start)["id"], "after_reply", "a save keeps the channel state")
	c.is_true(not pickup.visible, "a save keeps the board taken")
	station.queue_free()
	GameState.reset()
	await c.tree.process_frame


func _text(view: Dictionary) -> String:
	return "\n".join((view["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"]))


func _carried(flag: StringName) -> bool:
	return ItemCatalog.carried().any(func(item: Dictionary) -> bool: return item["flag"] == String(flag))
