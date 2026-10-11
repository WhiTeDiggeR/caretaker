extends RefCounted

## #127: dream combat — resolve, images (weapons), shades and the test dream arena.

const PLAYER := "res://scenes/player.tscn"
const TEST_DREAM := "res://scenes/dreams/test_dream.tscn"


func run(c: OpeningCheck) -> void:
	var world := Node3D.new()
	c.add(world)
	_box(world, Vector3(0, -0.1, 0), Vector3(30, 0.2, 30))
	var player := (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	player.position = Vector3(0, 0.9, 0)
	world.add_child(player)
	var combat := DreamCombat.new()
	var expelled := [0]
	combat.expel = func() -> void: expelled[0] += 1
	player.add_child(combat)
	await c.physics_frames(3)
	c.near(combat.resolve, 100.0, 0.001, "the hero enters with full resolve")
	c.is_true(not combat.attack(&"dream_blade"), "no attack without an image")

	# Melee: arc in front, two hits destroy a shade.
	c.is_true(combat.give_weapon(&"dream_blade") and not combat.give_weapon(&"dream_blade"), "an image is taken once")
	var shade := _enemy(world, Vector3(0, 0.9, -1.6), "ShadeMelee")
	var behind := _enemy(world, Vector3(0, 0.9, 1.8), "ShadeBehind")
	await c.physics_frames(2)
	behind.global_position = Vector3(0, 0.9, 1.8)
	shade.global_position = Vector3(0, 0.9, -1.6)
	c.is_true(combat.attack(&"dream_blade"), "the blade strikes")
	c.near(shade.health, 60.0 - 34.0, 0.001, "a hit takes 34")
	c.equal(shade.state, DreamEnemy.State.STAGGER, "a hit staggers the shade")
	c.near(behind.health, 60.0, 0.001, "a shade behind the hero is not hit")
	c.is_true(not combat.attack(&"dream_blade"), "the blade has a cooldown")
	var died := [false]
	shade.died.connect(func() -> void: died[0] = true)
	await c.tree.create_timer(0.55).timeout
	shade.global_position = Vector3(0, 0.9, -1.6)
	combat.attack(&"dream_blade")
	c.is_true(died[0] and shade.is_dead(), "the second hit destroys the shade")
	behind.queue_free()
	await c.physics_frames(2)

	# Ranged: the pulse spends focus and hits at a distance.
	combat.give_weapon(&"dream_pulse")
	var far := _enemy(world, Vector3(0, 0.9, -7), "ShadeFar")
	await c.physics_frames(2)
	far.global_position = Vector3(0, 0.9, -7)
	far.set_physics_process(false)
	player.camera.rotation.x = 0.0
	c.is_true(combat.attack(&"dream_pulse"), "the pulse fires")
	c.near(combat.focus, 75.0, 0.5, "the pulse spends focus")
	for _i in 40:
		await c.physics_frames(1)
		if far.health < 60.0:
			break
	c.near(far.health, 40.0, 0.001, "the pulse hits the shade at 7 m")
	combat.focus = 10.0
	await c.tree.create_timer(0.85).timeout
	combat.focus = 10.0
	c.is_true(not combat.attack(&"dream_pulse"), "no pulse without focus")
	far.queue_free()

	# A shade sees, chases, winds up and strikes.
	var hunter := _enemy(world, Vector3(0, 0.9, -6), "ShadeHunter")
	await c.physics_frames(2)
	hunter.global_position = Vector3(0, 0.9, -6)
	combat.resolve = combat.max_resolve
	var hurt := [0.0]
	combat.hurt.connect(func(amount: float) -> void: hurt[0] += amount)
	for _i in 240:
		await c.physics_frames(1)
		if hurt[0] > 0.0:
			break
	c.near(hurt[0], 18.0, 0.001, "the shade reaches the hero and strikes for 18")
	c.near(combat.resolve, 100.0 - 18.0, 0.5, "resolve drops")
	hunter.queue_free()

	# Edges: a shade does not walk off its platform.
	var island := Node3D.new()
	world.add_child(island)
	island.position = Vector3(40, 0, 0)
	_box(island, Vector3(0, -0.1, 0), Vector3(4, 0.2, 4))
	var guard := _enemy(world, Vector3(40, 0.9, 0), "ShadeEdge")
	await c.physics_frames(2)
	guard.global_position = Vector3(40, 0.9, 0)
	player.global_position = Vector3(47, 0.9, 0)
	_box(world, Vector3(47, -0.1, 0), Vector3(4, 0.2, 4))
	await c.physics_frames(120)
	c.is_true(guard.global_position.y > 0.5 and guard.global_position.x < 42.2, "a chasing shade stops at the edge")
	guard.queue_free()

	# Regeneration and being expelled.
	combat._since_hit = 10.0
	var before := combat.resolve
	await c.physics_frames(30)
	c.is_true(combat.resolve > before, "resolve recovers after a quiet spell")
	combat.take_damage(1000.0, Vector3.ZERO)
	combat.take_damage(10.0, Vector3.ZERO)
	c.equal(expelled[0], 1, "zero resolve expels the hero once")

	# Nothing of the fight is saved.
	c.is_true(not GameState.to_dict().has("combat") and not str(GameState.to_dict()).contains("dream_blade"), "images are not saved with the game")
	world.queue_free()
	await c.physics_frames(3)
	c.equal(c.tree.get_nodes_in_group(DreamCombat.GROUP).size(), 0, "the fight ends with the dream scene")

	# The test dream: setup, images and shades.
	var dream := (load(TEST_DREAM) as PackedScene).instantiate() as Node3D
	c.add(dream)
	await c.physics_frames(3)
	var dream_combat := c.tree.get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	c.is_true(dream_combat != null and dream_combat.get_parent() == dream.get_node(^"Player"), "the test dream arms its hero with resolve")
	c.equal(c.tree.get_nodes_in_group(DreamEnemy.GROUP).size(), 4, "four shades: three in the arena, one at the gate")
	var hud := dream.get_node(^"Combat").get("hud") as DreamCombatHud
	c.equal(hud.weapons_text(), "Оружия нет — ищите образы сна", "the HUD asks to find images")
	(dream.get_node(^"BladeImage") as DreamWeaponPickup).take()
	c.equal(hud.weapons_text(), "ЛКМ — Клинок сна", "taking an image arms the hero and names the key")
	dream.queue_free()
	await c.physics_frames(2)


func _enemy(parent: Node3D, position: Vector3, enemy_name: String) -> DreamEnemy:
	var enemy := DreamEnemy.new()
	enemy.name = enemy_name
	enemy.position = position
	parent.add_child(enemy)
	return enemy


func _box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body
