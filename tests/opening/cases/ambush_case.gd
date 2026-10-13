extends RefCounted

## #184: the first-fight ambush in the test dream — guards wait until the wake line, assemble,
## chase, keep off the hall threshold, wait in the yard and are gone once the seal is restored.

const TEST_DREAM := "res://scenes/dreams/test_dream.tscn"
const YARD_EAST := Vector3(-12.0, 0.9, -18.0)  # in the yard, before the wake line (x = -14)
const YARD_PAST_LINE := Vector3(-16.0, 0.9, -18.0)
const IN_THRESHOLD := Vector3(-23.5, 0.9, -18.0)
const YARD_MIDDLE := Vector3(-18.0, 0.9, -18.0)


func run(c: OpeningCheck) -> void:
	var dream := (load(TEST_DREAM) as PackedScene).instantiate() as Node3D
	c.add(dream)
	await c.physics_frames(3)
	var ambush := dream.get_node(^"Ambush") as DreamAmbush
	var hero := dream.get_node(^"Player") as CharacterBody3D
	var combat := c.tree.get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	combat.expel = func() -> void: pass
	var cues := [0]
	ambush.ambush_started.connect(func() -> void: cues[0] += 1)
	c.equal(ambush.config.get("count"), 2.0, "the ambush size comes from combat.json")
	c.equal(ambush.config.get("enemy"), "shade", "the guard type comes from combat.json")
	c.is_true(ambush.in_threshold(IN_THRESHOLD) and not ambush.in_threshold(YARD_MIDDLE), "the threshold box covers the hall door only")

	# Before the wake line nothing stirs.
	hero.global_position = YARD_EAST
	await c.physics_frames(30)
	c.is_true(not ambush.started and ambush.guards.is_empty(), "no guards before the wake line")
	c.equal(c.tree.get_nodes_in_group(DreamEnemy.GROUP).size(), 4, "only the arena and gate shades exist")

	# Crossing it brings two shades out; they assemble before moving.
	hero.global_position = YARD_PAST_LINE
	await c.physics_frames(3)
	c.is_true(ambush.started, "crossing the wake line starts the ambush")
	c.equal(cues[0], 1, "ambush_started is emitted once (cue for the weapon, Р-4)")
	c.equal(ambush.guards.size(), 2, "two guards step out")
	var guard := ambush.guards[0]
	c.near(guard.health, 60.0, 0.001, "a guard is a shade with 60 health")
	var niche := guard.global_position
	c.is_true(not guard.is_physics_processing() and guard.scale.x < 1.0, "a guard assembles first (telegraph)")
	await c.tree.create_timer(0.8).timeout
	c.is_true(guard.global_position.distance_to(niche) < 0.05, "a guard does not move while assembling")
	await c.tree.create_timer(0.9).timeout
	c.is_true(guard.is_physics_processing() and guard.scale.x > 0.99, "after 1.5 s the guard is assembled")
	var start_distance := guard.global_position.distance_to(hero.global_position)
	await c.physics_frames(30)
	c.is_true(guard.global_position.distance_to(hero.global_position) < start_distance - 0.5, "an assembled guard chases the hero")
	hero.global_position = YARD_PAST_LINE
	ambush.start()
	c.equal(cues[0], 1, "the ambush does not start twice")

	# The hall threshold: guards stay at its border, never inside.
	hero.global_position = IN_THRESHOLD
	var entered := false
	for _i in 180:
		await c.physics_frames(1)
		hero.global_position = IN_THRESHOLD
		for g in ambush.guards:
			if is_instance_valid(g) and ambush.in_threshold(g.global_position):
				entered = true
	c.is_true(not entered, "guards never step onto the threshold")
	var nearest := INF
	for g in ambush.guards:
		nearest = minf(nearest, _flat(g.global_position - IN_THRESHOLD))
	c.is_true(nearest < 4.5, "guards wait at the threshold (nearest %.1f m)" % nearest)

	# Back in the yard, the guards come for the hero.
	hero.global_position = YARD_MIDDLE + Vector3(2.0, 0.0, 0.0)
	var reached := false
	for _i in 240:
		await c.physics_frames(1)
		for g in ambush.guards:
			if is_instance_valid(g) and _flat(g.global_position - hero.global_position) < 2.0:
				reached = true
		if reached:
			break
	c.is_true(reached, "a guard reaches the hero who came back to the yard")

	# The seal restored: the guards are gone.
	var died := [0]
	for g in ambush.guards:
		g.died.connect(func() -> void: died[0] += 1)
	Dreams.seal_restored = true
	Dreams.seal_restored_signal.emit(&"test")
	await c.tree.create_timer(0.6).timeout
	c.equal(c.tree.get_nodes_in_group(DreamEnemy.GROUP).size(), 4, "a restored seal dissolves the ambush guards")
	c.equal(died[0], 0, "dissolved guards do not count as killed")
	dream.queue_free()
	await c.physics_frames(2)

	# A dream whose seal is already restored has no ambush at all.
	var calm := (load(TEST_DREAM) as PackedScene).instantiate() as Node3D
	c.add(calm)
	await c.physics_frames(3)
	var calm_ambush := calm.get_node(^"Ambush") as DreamAmbush
	(calm.get_node(^"Player") as Node3D).global_position = YARD_PAST_LINE
	await c.physics_frames(10)
	calm_ambush.start()
	c.is_true(not calm_ambush.started and calm_ambush.guards.is_empty(), "after the seal is restored no guards appear")
	Dreams.seal_restored = false
	calm.queue_free()
	await c.physics_frames(2)


func _flat(vector: Vector3) -> float:
	return Vector2(vector.x, vector.z).length()
