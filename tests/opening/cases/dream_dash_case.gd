extends RefCounted

## #185: the dodge dash in the dream (B-14) — moves the hero, invulnerability, cooldown, the
## action works only with dream combat (not in the complex).

const PLAYER := "res://scenes/player.tscn"


func run(c: OpeningCheck) -> void:
	var dash := DreamCombatData.hero().get("dash", {}) as Dictionary
	c.is_true(InputMap.has_action(DreamCombat.DASH_ACTION), "the dash has its input action")
	c.is_true(float(dash.get("distance", 0.0)) > 0.0 and float(dash.get("cooldown", 0.0)) > float(dash.get("invulnerable", 0.0)), "dash parameters come from combat.json")
	var distance := float(dash["distance"])
	var world := Node3D.new()
	c.add(world)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0, -0.1, 0)
	world.add_child(floor)

	# In the complex the hero has no dream combat: the action does nothing.
	var walker := (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	walker.position = Vector3(-10, 0.9, 0)
	world.add_child(walker)
	await c.physics_frames(10)
	var start := walker.global_position
	Input.action_press(DreamCombat.DASH_ACTION)
	await c.physics_frames(10)
	Input.action_release(DreamCombat.DASH_ACTION)
	c.near(Vector2(walker.global_position.x, walker.global_position.z).distance_to(Vector2(start.x, start.z)), 0.0, 0.01, "outside a dream the dash key does nothing")
	walker.queue_free()

	var player := (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	player.position = Vector3(0, 0.9, 0)
	world.add_child(player)
	var combat := DreamCombat.new()
	combat.expel = func() -> void: pass
	player.add_child(combat)
	await c.physics_frames(10)

	# The dash key in a dream: along the movement, forward without input.
	start = player.global_position
	# A press during a physics step counts as just pressed on the next one.
	Input.action_press(DreamCombat.DASH_ACTION)
	await c.physics_frames(2)
	Input.action_release(DreamCombat.DASH_ACTION)
	c.is_true(combat.is_dashing() and combat.is_invulnerable(), "the dash key starts a dash with invulnerability")
	var dodged := [0.0]
	combat.dodged.connect(func(amount: float) -> void: dodged[0] += amount)
	combat.take_damage(30.0, player.global_position + Vector3(0, 0, 2))
	c.near(combat.resolve, combat.max_resolve, 0.001, "damage does not pass during the dash's invulnerability")
	c.near(dodged[0], 30.0, 0.001, "the dodged hit is reported")
	c.is_true(not combat.dash(Vector3.RIGHT), "the dash has a cooldown")
	await c.physics_frames(30)
	var moved := player.global_position - start
	c.near(-moved.z, distance, 0.3, "without movement input the dash goes forward by its distance")
	c.near(moved.x, 0.0, 0.05, "the dash keeps its line")
	c.is_true(not combat.is_invulnerable() and not combat.is_dashing(), "invulnerability is short")
	combat.take_damage(10.0, player.global_position + Vector3(0, 0, 2))
	c.near(combat.resolve, combat.max_resolve - 10.0, 0.001, "after the invulnerability damage passes again")

	# Cooldown, then a dash to the side.
	await c.tree.create_timer(float(dash["cooldown"])).timeout
	c.is_true(combat.dash_cooldown() <= 0.0, "the cooldown runs out")
	player.velocity = Vector3.ZERO
	start = player.global_position
	c.is_true(combat.dash(Vector3.RIGHT), "a ready dash starts again")
	await c.physics_frames(30)
	c.near(player.global_position.x - start.x, distance, 0.3, "the dash goes along the given direction")

	# A wall stops the dash.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.4, 3, 6)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = player.global_position + Vector3(1.5, 1, 0)
	world.add_child(wall)
	await c.tree.create_timer(float(dash["cooldown"])).timeout
	start = player.global_position
	combat.dash(Vector3.RIGHT)
	await c.physics_frames(30)
	c.is_true(player.global_position.x < wall.position.x - 0.2, "a wall stops the dash")
	world.queue_free()
