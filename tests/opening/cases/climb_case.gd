extends RefCounted

## #124: crawling through low passages and vertical ladders.

const PLAYER := "res://scenes/player.tscn"
const LADDER := "res://objects/movement/ladder.tscn"
const TIMEOUT_FRAMES := 400


func run(c: OpeningCheck) -> void:
	_box(c, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60))
	await _crawl(c)
	await _ladder(c)
	for action: StringName in [&"crawl", &"crouch", &"jump", &"move_forward", &"move_back"]:
		Input.action_release(action)


func _crawl(c: OpeningCheck) -> void:
	var player := _spawn_player(c, Vector3(-10, 0.9, 0))
	await c.physics_frames(5)
	await _tap(c, &"crawl")
	await c.physics_frames(40)
	c.is_true(player.is_crawling and not player.is_crouching, "the crawl action lies the hero down")
	var shape := player.get_node(^"CollisionShape3D").shape as CapsuleShape3D
	c.near(shape.height, player.CRAWL_HEIGHT, 0.001, "crawling capsule height")
	c.near(player.camera.global_position.y, 0.5, 0.05, "eyes 0.5 m above the floor while crawling")

	# A 0.8 m passage: only crawling fits.
	var ceiling := _box(c, Vector3(-10, 0.9, 0), Vector3(3, 0.2, 3))
	await c.physics_frames(2)
	c.is_true(player._capsule_fits(player.global_position, player.CRAWL_HEIGHT), "a 0.8 m passage fits a crawling hero")
	c.is_true(not player._capsule_fits(player.global_position, player.CROUCH_HEIGHT), "a 0.8 m passage does not fit a crouch")
	await _tap(c, &"crawl")
	await c.physics_frames(30)
	c.is_true(player.is_crawling, "cannot get up under a 0.8 m ceiling")
	await _tap(c, &"jump")
	await c.physics_frames(3)
	c.is_true(player.velocity.y <= 0.0, "no jumping while crawling")

	# Crawling moves slowly.
	var start := player.global_position
	Input.action_press(&"move_forward")
	await c.physics_frames(60)
	Input.action_release(&"move_forward")
	var travelled := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	c.is_true(travelled > 0.6 and travelled < 1.5, "crawling is slow (%.2f m in 1 s)" % travelled)

	ceiling.queue_free()
	await c.physics_frames(60)
	c.is_true(not player.is_crawling and not player.is_crouching, "the hero gets up once there is room (requested earlier)")
	c.near(shape.height, player.STAND_HEIGHT, 0.001, "standing capsule height restored")
	player.queue_free()


func _ladder(c: OpeningCheck) -> void:
	# A 3 m landing behind a ladder facing +Z.
	_box(c, Vector3(10, 1.5, -3.5), Vector3(3, 3, 3))
	var ladder := (load(LADDER) as PackedScene).instantiate() as Ladder
	ladder.position = Vector3(10, 0, -1.97)
	c.add(ladder)
	var player := _spawn_player(c, Vector3(10, 0.9, 0))
	await c.physics_frames(5)

	ladder.grab.trigger()
	await c.physics_frames(30)
	c.is_true(player.is_climbing, "grabbing the ladder from below starts climbing")
	var line := ladder.body_position(0.0, player.STAND_HEIGHT * 0.5)
	c.near(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(line.x, line.z)), 0.0, 0.05, "the hero hangs on the ladder line")

	Input.action_press(&"move_forward")
	await c.physics_frames(30)
	c.is_true(player.global_position.y > 1.2 and player.is_climbing, "forward climbs up")
	await _until(c, func() -> bool: return not player.is_climbing and not player.is_mantling)
	Input.action_release(&"move_forward")
	await c.physics_frames(10)
	c.near(_feet(player), 3.0, 0.05, "the hero steps onto the 3 m landing")
	c.is_true(player.global_position.z < ladder.global_position.z - 0.3, "the hero stands behind the ladder on the landing")

	ladder.top_grab.trigger()
	await c.physics_frames(30)
	c.is_true(player.is_climbing, "grabbing the handrails from the landing starts climbing down")
	c.near(_feet(player), 3.0 - player.LADDER_TOP_START, 0.1, "climbing down starts below the landing")
	Input.action_press(&"move_back")
	await _until(c, func() -> bool: return not player.is_climbing)
	Input.action_release(&"move_back")
	await c.physics_frames(10)
	c.near(_feet(player), 0.0, 0.05, "back on the floor after climbing down")

	ladder.grab.trigger()
	await c.physics_frames(30)
	Input.action_press(&"move_forward")
	await c.physics_frames(30)
	Input.action_release(&"move_forward")
	await _tap(c, &"jump")
	await c.physics_frames(60)
	c.is_true(not player.is_climbing, "jump lets go of the ladder")
	c.near(_feet(player), 0.0, 0.05, "the hero falls back to the floor")
	c.is_true(player.global_position.z > ladder.global_position.z + Ladder.STANDOFF, "letting go pushes the hero away from the ladder")

	player.is_crawling = true
	c.is_true(not await player.attach_ladder(ladder), "a crawling hero cannot grab a ladder")
	player.is_crawling = false


func _feet(player: CharacterBody3D) -> float:
	return player.global_position.y - player.STAND_HEIGHT * 0.5


func _tap(c: OpeningCheck, action: StringName) -> void:
	Input.action_press(action)
	await c.physics_frames(2)
	Input.action_release(action)


func _until(c: OpeningCheck, condition: Callable) -> void:
	for _i in TIMEOUT_FRAMES:
		if condition.call():
			return
		await c.physics_frames(1)
	c.is_true(false, "timed out")


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
