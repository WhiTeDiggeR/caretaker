extends RefCounted

const PLAYER := "res://scenes/player.tscn"
const FLOOR_SIZE := Vector3(40, 0.2, 40)


func run(c: OpeningCheck) -> void:
	_box(c, Vector3(0, -0.1, 0), FLOOR_SIZE)
	var player := _spawn_player(c, Vector3(0, 0.9, 0))
	await c.physics_frames(5)

	# Crouch while the action is held.
	Input.action_press(&"crouch")
	await c.physics_frames(30)
	c.is_true(player.is_crouching, "holding crouch crouches")
	var shape := player.get_node(^"CollisionShape3D").shape as CapsuleShape3D
	c.near(shape.height, player.CROUCH_HEIGHT, 0.001, "crouched capsule height")
	var collision := player.get_node(^"CollisionShape3D") as CollisionShape3D
	c.near(player.global_position.y + collision.position.y - shape.height * 0.5, 0.0, 0.05, "feet stay on the floor while crouched")

	# A low ceiling keeps the hero crouched after the action is released.
	var ceiling := _box(c, Vector3(0, 1.45, 0), Vector3(3, 0.2, 3))
	Input.action_release(&"crouch")
	await c.physics_frames(30)
	c.is_true(player.is_crouching, "cannot stand up under a low ceiling")
	ceiling.queue_free()
	await c.physics_frames(40)
	c.is_true(not player.is_crouching, "stands up when there is room")
	c.near(shape.height, player.STAND_HEIGHT, 0.001, "standing capsule height restored")

	# Climb a 0.9 m crate in front (-Z).
	_box(c, Vector3(0, 0.45, -1.4), Vector3(1.2, 0.9, 1.2))
	await c.physics_frames(2)
	c.is_true(player.find_mantle_target() != Vector3.INF, "0.9 m crate can be climbed")
	c.is_true(player.try_mantle(), "mantle starts")
	await player.mantle_finished
	await c.physics_frames(5)
	c.near(player.global_position.y - player.STAND_HEIGHT * 0.5, 0.9, 0.05, "hero stands on the crate")
	c.is_true(not player.is_crouching, "hero stands after an open mantle")

	# A 1.6 m wall is too high.
	var high := _spawn_player(c, Vector3(10, 0.9, 0))
	_box(c, Vector3(10, 0.8, -1.4), Vector3(1.2, 1.6, 1.2))
	await c.physics_frames(5)
	c.equal(high.find_mantle_target(), Vector3.INF, "1.6 m wall cannot be climbed")
	c.is_true(not high.try_mantle(), "mantle is refused for a high wall")

	# A low gap above the crate forces a crouch after climbing.
	var gap := _spawn_player(c, Vector3(-10, 0.9, 0))
	_box(c, Vector3(-10, 0.45, -1.4), Vector3(1.2, 0.9, 1.2))
	_box(c, Vector3(-10, 0.9 + 1.3 + 0.1, -2.0), Vector3(1.2, 0.2, 1.4))
	await c.physics_frames(5)
	c.is_true(gap.try_mantle(), "mantle into a low gap starts")
	await gap.mantle_finished
	await c.physics_frames(5)
	c.is_true(gap.is_crouching, "hero is crouched in a low gap after climbing")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_player(c: OpeningCheck, position: Vector3) -> CharacterBody3D:
	var player := (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	player.position = position
	c.add(player)
	return player


func _box(c: OpeningCheck, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	c.add(body)
	return body
