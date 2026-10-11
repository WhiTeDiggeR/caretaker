extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const TEST_DIR := "user://test_saves"


func run(c: OpeningCheck) -> void:
	var original_dir := Saves.directory
	Saves.directory = TEST_DIR
	for slot in Saves.SLOTS:
		Saves.delete(slot)
	c.equal(Saves.latest(), "", "no saves yet")
	c.is_true(Saves.describe("slot_1").ends_with("пусто"), "empty slot is described as empty")

	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	await c.physics_frames(2)
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	var door := sandbox.get_node(^"Stations/DoorStation/Hermetic") as FacilityDoor
	var airlock := sandbox.get_node(^"Stations/DoorStation/Airlock") as Airlock
	door.open_time = 0.05
	c.is_true(door.open(), "sandbox door opens")
	await door.opened
	airlock.synced_door = airlock.door_b
	GameState.set_flag(&"saved_flag", 7)
	player.global_position = Vector3(3, 0.9, -2)
	player.rotation.y = 1.0

	c.equal(Saves.write("slot_1", c.tree), OK, "game is saved to slot 1")
	c.equal(Saves.latest(), "slot_1", "slot 1 is the latest save")
	c.is_true(Saves.describe("slot_1").contains("Проверить станции полигона"), "slot line shows the objective")
	var data := Saves.read("slot_1")
	c.equal(data["scene"], c.tree.current_scene.scene_file_path, "save names the scene")

	door.close()
	await door.closed
	airlock.synced_door = airlock.door_a
	GameState.set_flag(&"saved_flag", 1)
	player.global_position = Vector3(-5, 0.9, 5)

	GameState.from_dict(data["state"])
	Saves.apply_to_scene(c.tree, data)
	c.equal(GameState.get_flag(&"saved_flag"), 7, "game state is restored")
	c.is_true(door.is_open(), "door state is restored")
	c.near((door.get_node(^"Leaf") as Node3D).position.x, door.width + FacilityDoor.FRAME_POST * 0.5, 0.001, "door leaf is restored without animation")
	c.equal(airlock.synced_door, airlock.door_b, "airlock side is restored")
	c.near(player.global_position.distance_to(Vector3(3, 0.9, -2)), 0.0, 0.01, "hero position is restored")
	c.near(player.rotation.y, 1.0, 0.001, "hero view is restored")

	var checkpoint := sandbox.get_node(^"Stations/Checkpoint") as Checkpoint
	c.is_true(not checkpoint.is_reached(), "checkpoint not reached yet")
	player.global_position = checkpoint.global_position + Vector3(0, 0.9, 0)
	await c.physics_frames(4)
	c.is_true(checkpoint.is_reached(), "walking in reaches the checkpoint")
	c.is_true(Saves.exists(Saves.AUTO), "checkpoint writes the autosave")
	c.equal(Saves.latest(), Saves.AUTO, "autosave is the latest")

	for slot in Saves.SLOTS:
		Saves.delete(slot)
	Saves.directory = original_dir
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
