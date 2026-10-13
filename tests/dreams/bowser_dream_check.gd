extends Node

## Headless check of the Bowser dream blockout (#182): the scene loads with its wiring and the
## hook nodes of the later tasks, module 4 dreams into it, the side grate and the arch stay shut
## until the seal (#190), the route terrace → bastion is walkable once the grate is open (floor
## rays, no step above the mantle height, no wall across the way, head room) and falling into
## the lava throws the hero out of the dream.
## Prints `BOWSER_DREAM_CHECK_OK checks=<n>` on success.

const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const SAMPLE_STEP := 0.25
const RAY_ABOVE := 3.0
const RAY_BELOW := 8.0
const CHEST := 1.0
const KNEE := 0.5
const HEAD_ROOM := 2.0
const MAX_RISE := 1.25  # Player.MANTLE_MAX_HEIGHT: the ledge is the only climb
const LAVA_DROP := Vector3(38, -2, 6)
const TIMEOUT_FRAMES := 600

var _errors := PackedStringArray()
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# No scene to return to: the session ends without loading the complex back.
	get_tree().current_scene = null
	Containment.set_process(false)
	_check(Dreams.dream_scene_for(&"module_4") == BOWSER_DREAM, "module 4 dreams into Bowser's dream")
	var dream := (load(BOWSER_DREAM) as PackedScene).instantiate() as BowserDream
	_check(dream != null, "the scene root is BowserDream")
	if dream == null:
		_finish()
		return
	add_child(dream)
	await _frames(5)
	_check_wiring(dream)
	_check_shut(dream)
	dream.open_side_door(true)
	await _frames(2)
	_check_route(dream)
	await _check_lava(dream)
	_finish()


func _check_wiring(dream: BowserDream) -> void:
	_check(dream.get_node_or_null(^"Lava") is DreamHazard, "the lava is deadly")
	_check(dream.get_node_or_null(^"Bastion/Gate") is DreamGate, "the gate stands on the bastion")
	var seal := dream.get_node_or_null(BowserDream.SEAL) as DreamSealRings
	_check(seal != null and seal.knowledge_id == &"module_4_seal", "the hall holds the seal of rings that grants module 4 glyphs")
	_check(dream.get_node_or_null(^"Combat") is DreamCombatSetup, "the dream has combat")
	_check(dream.get_node_or_null(^"Mood") is DreamMood, "the dream follows the instability stage")
	var hooks: Array[NodePath] = [BowserDream.SEAL_SLOT, BowserDream.SIDE_DOOR, BowserDream.WAKE_LINE,
			BowserDream.HALL_THRESHOLD, BowserDream.REMAINS, BowserDream.WEAPON_SPOT, BowserDream.SILHOUETTE_SPOT,
			^"Spawn", ^"Yard/Remains/Brazier", ^"Yard/Remains/OperatorMark"]
	hooks.append_array(BowserDream.GUARD_SPAWNS)
	for hook in hooks:
		_check(dream.get_node_or_null(hook) is Node3D, "hook node %s exists" % hook)
	for branch: NodePath in [^"Branches/RubbleSouth", ^"Branches/CollapsedStair", ^"Branches/GrateEast"]:
		_check(dream.get_node_or_null(branch) != null, "closed passage %s exists" % branch)
	var player := dream.get_node(^"Player") as Node3D
	var spawn := dream.get_node(^"Spawn") as Node3D
	_check(Vector2(player.global_position.x - spawn.global_position.x, player.global_position.z - spawn.global_position.z).length() < 0.1,
			"the hero starts at the spawn")
	_check(spawn.global_basis.z.dot(Vector3.LEFT) > 0.99, "the spawn faces the fortress (+X)")


func _check_shut(dream: BowserDream) -> void:
	var gate := dream.get_node(BowserDream.GATE) as DreamGate
	_check(gate.requires_seal and not gate.is_open(), "the arch on the bastion waits for the seal")
	_check(not dream.side_door_open, "the side grate is down before the seal")
	var door := (dream.get_node(BowserDream.SIDE_DOOR) as Node3D).global_position
	var space := dream.get_world_3d().direct_space_state
	var hit := _ray(space, door + Vector3(0, CHEST, 2), door + Vector3(0, CHEST, -2), [])
	_check(not hit.is_empty() and hit["collider"] == dream.get_node(BowserDream.SIDE_GRATE), "the side grate blocks the way to the bastion")
	_check(not BowserDream.silhouette_line().is_empty(), "the silhouette of №2 has its line in the dream data")


func _check_route(dream: BowserDream) -> void:
	var space := dream.get_world_3d().direct_space_state
	var points := BowserDream.route()
	var exclude: Array[RID] = [(dream.get_node(^"Player") as CollisionObject3D).get_rid()]
	var previous := Vector3.INF
	var blocked := 0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var count := maxi(1, ceili(a.distance_to(b) / SAMPLE_STEP))
		for k in count + 1:
			var p := a.lerp(b, float(k) / count)
			var hit := _ray(space, p + Vector3.UP * RAY_ABOVE, p + Vector3.DOWN * RAY_BELOW, exclude)
			if hit.is_empty():
				_check(false, "floor under the route at %s" % p)
				return
			var floor_point: Vector3 = hit["position"]
			if absf(floor_point.y - p.y) > 0.6:
				_check(false, "route floor at %s is %.2f m, expected %.2f" % [p, floor_point.y, p.y])
				return
			if not _ray(space, floor_point + Vector3.UP * 0.05, floor_point + Vector3.UP * HEAD_ROOM, exclude).is_empty():
				_check(false, "head room over the route at %s" % floor_point)
				return
			if previous != Vector3.INF:
				var rise := floor_point.y - previous.y
				if rise > MAX_RISE:
					_check(false, "rise of %.2f m at %s is above the mantle height" % [rise, floor_point])
					return
				var top := maxf(previous.y, floor_point.y)
				for height: float in [KNEE, CHEST]:
					var from := Vector3(previous.x, top + height, previous.z)
					var to := Vector3(floor_point.x, top + height, floor_point.z)
					if not _ray(space, from, to, exclude).is_empty():
						blocked += 1
			previous = floor_point
	_check(blocked == 0, "no wall across the route (%d blocked samples)" % blocked)
	var gate := dream.get_node(^"Bastion/Gate") as Node3D
	_check(Vector2(previous.x - gate.global_position.x, previous.z - gate.global_position.z).length() < 2.0, "the route ends at the gate")


func _check_lava(dream: BowserDream) -> void:
	var original_loader := Dreams.scene_loader
	var loads: Array[String] = []
	Dreams.scene_loader = func(path: String) -> void: loads.append(path)
	await Dreams.enter(&"module_4", &"check_chair")
	_check(loads == ([BOWSER_DREAM] as Array[String]), "the session loads Bowser's dream")
	var reasons: Array[int] = []
	var on_left := func(_id: StringName, reason: int) -> void: reasons.append(reason)
	Dreams.left.connect(on_left)
	var before := Containment.get_instability(&"module_4")
	var player := dream.get_node(^"Player") as CharacterBody3D
	player.global_position = LAVA_DROP
	player.velocity = Vector3.ZERO
	for _i in TIMEOUT_FRAMES:
		if not reasons.is_empty():
			break
		await get_tree().physics_frame
	_check(reasons == ([Dreams.Exit.DEATH] as Array[int]), "falling into the lava throws the hero out (%s)" % [reasons])
	_check(Containment.get_instability(&"module_4") >= before + Dreams.death_penalty - 0.01, "death in the lava raises the instability")
	Dreams.left.disconnect(on_left)
	await get_tree().create_timer(Dreams.FADE_SECONDS * 2.0 + 0.2).timeout
	Dreams.scene_loader = original_loader
	Dreams.abort()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	return space.intersect_ray(query)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)


func _finish() -> void:
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("BOWSER_DREAM_CHECK_OK checks=%d" % _checks)
	get_tree().quit(0 if _errors.is_empty() else 1)
