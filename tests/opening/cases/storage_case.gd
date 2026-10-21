extends RefCounted

## #231: the storage of the technical level — the reagent cylinder goes into the stock and
## recharges module 4 after its protocol fired, the gallery tool shortens the ventilation,
## the storage log gives the «более трёх лет» term, and the three finds close the direction.

const C := &"module_4"
const KIT := "res://objects/storage/storage_kit.tscn"
const CYLINDER := &"item_reagent_cylinder"
const TOOL := &"item_gallery_tool"
const DONE := &"part2/dir_storage_done"


func run(c: OpeningCheck) -> void:
	GameState.reset()
	Containment.set_process(false)
	var kit: Node3D = c.add((load(KIT) as PackedScene).instantiate())
	await c.tree.process_frame
	var cylinder := kit.get_node(^"ReagentCylinder") as ItemPickup
	var tool := kit.get_node(^"GalleryTool") as ItemPickup
	var log_pickup := kit.get_node(^"StorageLog") as DocumentPickup

	c.is_true(ItemCatalog.has(CYLINDER) and ItemCatalog.has(TOOL), "the storage finds are catalogued items")
	var log_body := str(DocumentLibrary.get_document(log_pickup.document_id).get("body", ""))
	c.is_true(log_body.contains("более трёх лет") and not log_body.contains("дней назад"), "the log gives the term without an exact number")

	# The protocol of module 4 fires and the module is vented without the tool: 30 s.
	Containment.add_instability(C, 95.0 - Containment.get_instability(C))
	Containment.tick(0.1)
	Containment.tick(10.0)
	Containment.tick(180.0)
	c.equal(Containment.chemical_phase(C), Containment.Chemical.SPENT, "module 4 spent its reagent")
	c.equal(Containment.recharge_lock_reason(C), Containment.REASON_GAS, "the spent module needs ventilation")
	Containment.vent(C)
	c.near(float(Containment._chem(C)["venting"]), 30.0, 0.001, "ventilation without the tool takes the full time")
	Containment.tick(30.0)
	c.equal(Containment.recharge_lock_reason(C), Containment.REASON_NO_STOCK, "no reagent before the storage")

	(tool.get_meta(Interactable.META) as Interactable).trigger()
	c.is_true(GameState.has_flag(TOOL) and not tool.visible, "the tool is taken and disappears")
	c.near(Containment.service_seconds(30.0), 15.0, 0.001, "the tool halves the service procedures")
	(cylinder.get_meta(Interactable.META) as Interactable).trigger()
	c.is_true(GameState.has_flag(CYLINDER) and not cylinder.visible, "the cylinder is taken and disappears")
	c.equal(Containment.reagent_stock(), 1, "the cylinder is one reagent charge in stock")
	c.is_true(ItemCatalog.carried().any(func(item: Dictionary) -> bool: return item["flag"] == String(CYLINDER)), "the cylinder is carried")
	c.is_true(not GameState.has_flag(DONE), "the direction is not closed before the log is read")

	DocumentLibrary.mark_read(log_pickup.document_id)
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(GameState.has_flag(DONE), "cylinder, tool and log close the storage direction")

	c.is_true(Containment.recharge(C), "the cylinder recharges module 4")
	c.is_true(Containment.is_charged(C) and Containment.reagent_stock() == 0, "module 4 is armed again, the stock is empty")
	c.is_true(GameState.has_flag(&"item_reagent_cylinder/used"), "the cylinder is marked used")
	c.is_true(not ItemCatalog.carried().any(func(item: Dictionary) -> bool: return item["flag"] == String(CYLINDER)), "a used cylinder is no longer carried")

	# The next ventilation with the tool is shorter.
	Containment.add_instability(C, 95.0 - Containment.get_instability(C))
	Containment.tick(0.1)
	Containment.tick(10.0)
	Containment.tick(180.0)
	Containment.vent(C)
	c.near(float(Containment._chem(C)["venting"]), 15.0, 0.001, "ventilation with the tool takes half the time")

	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	await c.tree.process_frame
	c.is_true(cylinder.visible and tool.visible, "a fresh state puts the finds back")
	GameState.from_dict(saved)
	await c.tree.process_frame
	c.is_true(not cylinder.visible and not tool.visible and GameState.has_flag(DONE), "a save keeps the finds taken and the direction closed")

	GameState.reset()
	Containment.set_process(true)
	await c.tree.process_frame
