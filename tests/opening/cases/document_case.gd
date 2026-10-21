extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"


func run(c: OpeningCheck) -> void:
	DocumentLibrary.reload()
	c.equal(DocumentLibrary.errors(), PackedStringArray(), "all document catalogues are valid")
	c.is_true(DocumentLibrary.has("sandbox_memo"), "sandbox documents are loaded")
	c.equal(DocumentLibrary.get_document("missing"), {}, "unknown document is empty")
	c.equal(DocumentLibrary._validate_paper({"form": {}, "stamps": ["ДСП"], "note": "x", "handwritten": true}, "ok").size(), 0, "paper fields are accepted")
	c.equal(DocumentLibrary._validate_paper({"form": "x", "stamps": [1], "note": 2, "handwritten": "yes"}, "bad").size(), 4, "malformed paper fields are reported")

	ItemCatalog.reload()
	c.equal(ItemCatalog.errors(), PackedStringArray(), "the item catalogue is valid")
	c.is_true(ItemCatalog.has(&"item_crowbar") and ItemCatalog.has(&"senior_key_taken"), "pickup flags are catalogued items")
	GameState.set_flag(&"senior_key_taken")
	c.equal(ItemCatalog.carried().size(), 1, "a set item flag is carried")
	var carried_save := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	c.equal(ItemCatalog.carried().size(), 0, "reset empties the pockets")
	GameState.from_dict(carried_save)
	c.equal(ItemCatalog.carried()[0].get("title"), "Личный ключ старшего", "carried items survive a save")
	var key_item := ItemCatalog.get_item(&"senior_key_taken")
	c.is_true(key_item.get("tag") == "SE 067" and str(key_item.get("note")).contains("SE 067"), "the key's number is on its tag and in the hero's note")
	c.is_true(str(DocumentLibrary.get_document("senior_note").get("body")).contains("SE 067"), "the senior's note is signed with the key's number")
	GameState.reset()

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
	c.is_true(reader.marks.get_child_count() == 1 and not reader.form_box.visible, "the memo carries a pencil note and no form header")
	reader.show_document("sandbox_log")
	c.is_true(reader.form_box.visible and reader.marks.get_child_count() == 2, "the log has a form header and two stamps")
	reader.show_document("sandbox_memo")
	c.is_true(DocumentLibrary.is_read("sandbox_memo"), "pickup adds the document to the journal")
	reader.close()
	await c.tree.process_frame
	c.is_true(not player.controls_locked and memo.reader == null, "closing the reader unlocks the player")

	# The key that closes the reader must not reopen the document under the crosshair.
	player.global_position = Vector3(memo.global_position.x, 0.9, memo.global_position.z + 1.0)
	player.rotation = Vector3.ZERO
	(player.get_node(^"Camera3D") as Node3D).rotation.x = deg_to_rad(-40.0)
	await c.physics_frames(4)
	c.equal(player.interactor.target, memo.get_node(^"Interactable"), "player looks at the document")
	Input.action_press(&"interact")
	await c.physics_frames(2)
	c.is_true(memo.reader != null, "pressing E opens the document")
	memo.reader.close()
	await c.physics_frames(4)
	c.is_true(memo.reader == null, "holding the closing key does not reopen the document")
	Input.action_release(&"interact")
	await c.physics_frames(2)
	Input.action_press(&"interact")
	await c.physics_frames(2)
	c.is_true(memo.reader != null, "a new press opens it again")
	Input.action_release(&"interact")
	memo.reader.close()
	await c.physics_frames(2)

	var journal := DocumentReader.open_journal_scene(c.tree)
	var lines := journal.document_lines()
	c.is_true(journal.in_journal and lines.size() == 1, "journal lists read documents")
	c.is_true(lines.size() == 1 and lines[0].text.ends_with("Памятка полигона"), "journal shows titles written by hand")
	c.is_true(journal.sheet.ruled and journal.list_scroll.visible, "the journal is a squared notebook page")
	journal.show_document("sandbox_memo", true)
	c.is_true(not journal.in_journal and journal.scroll.visible, "journal opens a document")
	c.is_true(not journal.sheet.ruled and not journal.list_scroll.visible, "a document from the journal lies on its own sheet")
	journal.show_journal()
	journal.show_page(DocumentReader.Page.CARRIED)
	c.equal(journal.carried_titles(), PackedStringArray(), "nothing is carried yet")
	GameState.set_flag(&"item_crowbar")
	journal.show_page(DocumentReader.Page.CARRIED)
	c.equal(journal.carried_titles(), PackedStringArray(["Пожарный лом"]), "the «При себе» page lists a taken item")
	c.is_true(journal.list_box.get_child(0).get_child(0) is ItemSketch, "a carried item has a pencil sketch")
	c.equal(journal.document_lines().size(), 0, "carried items are not selectable documents")
	journal.show_page(DocumentReader.Page.NOTES)
	c.equal(journal.document_lines().size(), 1, "turning back shows the notes")
	journal.close()
	await c.tree.process_frame
	c.is_true(not player.controls_locked, "player is unlocked after the journal")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
