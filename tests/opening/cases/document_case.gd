extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"


func run(c: OpeningCheck) -> void:
	DocumentLibrary.reload()
	c.equal(DocumentLibrary.errors(), PackedStringArray(), "all document catalogues are valid")
	c.is_true(DocumentLibrary.has("sandbox_memo"), "sandbox documents are loaded")
	c.equal(DocumentLibrary.get_document("missing"), {}, "unknown document is empty")

	c.equal(DocumentLibrary.read_ids(), [] as Array[String], "journal starts empty")
	c.is_true(DocumentLibrary.mark_read("sandbox_log"), "first reading is new")
	c.is_true(DocumentLibrary.mark_read("sandbox_memo"), "second document is new")
	c.is_true(not DocumentLibrary.mark_read("sandbox_log"), "re-reading is not new")
	c.is_true(not DocumentLibrary.mark_read("missing"), "unknown documents are ignored")
	c.equal(DocumentLibrary.read_ids(), ["sandbox_log", "sandbox_memo"] as Array[String], "journal keeps reading order")
	c.is_true(GameState.has_flag(&"sandbox_memo_read"), "on_read effects apply")
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	GameState.from_dict(saved)
	c.equal(DocumentLibrary.read_ids(), ["sandbox_log", "sandbox_memo"] as Array[String], "journal survives a save")
	GameState.reset()

	# Inspect-only texts stay out of the journal and feed Interactable.
	c.is_true(not DocumentLibrary.mark_read("pod_staff_occupied"), "inspect text is not a journal entry")
	var panel := Interactable.new()
	panel.mode = Interactable.Mode.INSPECT
	panel.inspect_text_id = "pod_hero"
	c.equal(panel.get_inspect_title(), "КАПСУЛА АВАРИЙНОГО СНА", "inspect title comes from the library")
	c.is_true(panel.get_inspect_text().contains("ТАБ. № 2-117"), "inspect text comes from the library")
	panel.free()

	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	await c.physics_frames(2)
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	var memo := sandbox.get_node(^"Stations/DocumentStation/Memo") as DocumentPickup
	memo.read()
	var reader := memo.reader
	c.is_true(reader != null and reader.body_label.text.begins_with("Этот документ"), "pickup opens the reader")
	c.is_true(player.controls_locked, "player is locked while reading")
	c.is_true(DocumentLibrary.is_read("sandbox_memo"), "pickup adds the document to the journal")
	reader.close()
	await c.tree.process_frame
	c.is_true(not player.controls_locked and memo.reader == null, "closing the reader unlocks the player")

	var journal := DocumentReader.open_journal_scene(c.tree)
	c.is_true(journal.in_journal and journal.list_box.get_child_count() == 1, "journal lists read documents")
	c.is_true((journal.list_box.get_child(0) as Label).text.ends_with("ПАМЯТКА ПОЛИГОНА"), "journal shows titles")
	journal.show_document("sandbox_memo", true)
	c.is_true(not journal.in_journal and journal.scroll.visible, "journal opens a document")
	journal.close()
	await c.tree.process_frame
	c.is_true(not player.controls_locked, "player is unlocked after the journal")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
