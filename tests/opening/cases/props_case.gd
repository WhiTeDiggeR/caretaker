extends RefCounted

const P := "res://objects/props/"


func run(c: OpeningCheck) -> void:
	DocumentLibrary.reload()
	for variant: int in StaffCapsule.PANEL_TEXT:
		c.is_true(DocumentLibrary.has(StaffCapsule.PANEL_TEXT[variant]), "capsule panel text %s exists" % StaffCapsule.PANEL_TEXT[variant])

	var occupied := _add(c, "staff_capsule_occupied", Vector3(-6, 0, 0)) as StaffCapsule
	var empty := _add(c, "staff_capsule_empty", Vector3(-4, 0, 0)) as StaffCapsule
	var hero := _add(c, "staff_capsule_hero", Vector3(-2, 0, 0)) as StaffCapsule
	await c.tree.process_frame
	c.equal(occupied.panel_interactable.get_inspect_title(), "КАПСУЛА АВАРИЙНОГО СНА", "capsule panel is inspected")
	c.is_true(occupied.panel_interactable.get_inspect_text().contains("Штатное пробуждение: нет команды"), "occupied capsule tells why the staff stays asleep")
	c.is_true(not occupied.is_open() and empty.is_open(), "occupied capsule is closed, empty one is open")
	# Р-16: a large occupant (2.0 m, 0.6 m shoulders) lies under the closed lid with room to
	# turn and raise the head.
	await c.tree.physics_frame
	await c.tree.physics_frame
	var bed_top := StaffCapsule.BASE_HEIGHT + StaffCapsule.BED_THICKNESS
	var occupant := BoxShape3D.new()
	occupant.size = Vector3(StaffCapsule.DESIGN_OCCUPANT_SHOULDERS + 0.3, 0.7, StaffCapsule.DESIGN_OCCUPANT_HEIGHT + 0.25)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = occupant
	query.transform = Transform3D(Basis.IDENTITY, occupied.global_position + Vector3(0, bed_top + 0.37, 0))
	c.is_true(occupied.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "a large occupant fits in the closed capsule with room to move")
	c.is_true(StaffCapsule.BED_LENGTH >= StaffCapsule.DESIGN_OCCUPANT_HEIGHT + 0.3 and StaffCapsule.BED_WIDTH >= StaffCapsule.DESIGN_OCCUPANT_SHOULDERS + 0.4, "the bed is sized for the design occupant")
	c.is_true(hero.panel_interactable.get_inspect_text().contains("ОШИБКА КОНТУРА"), "hero capsule shows the damaged contour")
	c.equal(hero.lid_interactable.mode, Interactable.Mode.HOLD, "hero lid is pushed open by holding")
	hero.lid_interactable.trigger()
	c.is_true(GameState.has_flag(StaffCapsule.HERO_LID_FLAG) and hero.is_open(), "pushing the lid opens the hero capsule")
	await c.tree.create_timer(0.8).timeout
	c.near(hero.lid.rotation.z, StaffCapsule.LID_OPEN_ANGLE, 0.01, "hero lid swung open")
	c.is_true(hero.lid.rotation.z < 0.0, "lid lifts its free edge upwards")

	var key := _add(c, "key_pickup", Vector3(0, 1, 0)) as KeyPickup
	await c.tree.process_frame
	(key.get_meta(Interactable.META) as Interactable).trigger()
	c.is_true(GameState.has_flag(&"senior_key_taken") and not key.visible, "the key is taken and disappears")
	GameState.reset()
	c.is_true(key.visible and not key.is_taken(), "loading a state without the flag brings the key back")

	var duct := _add(c, "fallen_duct", Vector3(10, 0, 0)) as SimpleProp
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.2, 20)
	floor_shape.shape = floor_box
	floor.add_child(floor_shape)
	floor.position = Vector3(10, -0.1, 0)
	c.add(floor)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	player.position = Vector3(14, 0.9, 3)
	c.add(player)
	await c.physics_frames(3)
	var under_duct := Vector3(10, 0.9, 0)
	c.is_true(not player._capsule_fits(under_duct, player.STAND_HEIGHT), "standing hero does not fit under the fallen duct")
	c.is_true(player._capsule_fits(under_duct, player.CROUCH_HEIGHT), "crouching hero fits under the fallen duct")

	# Open capsules at the hall pitch: the upright lid stays in the gap, and the hero stands
	# steadily on the bed (no sinking, no bouncing, no forced crouch).
	var left := _add(c, "staff_capsule_empty", Vector3(10, 0, 6)) as StaffCapsule
	var right := _add(c, "staff_capsule_empty", Vector3(10 + StaffCapsule.HALL_PITCH, 0, 6)) as StaffCapsule
	await c.physics_frames(2)
	var lid_box := AABB()
	for mesh: MeshInstance3D in left.lid.find_children("*", "MeshInstance3D", false, false):
		var box := mesh.global_transform * mesh.get_aabb()
		lid_box = box if lid_box.size == Vector3.ZERO else lid_box.merge(box)
	var neighbour_edge := right.global_position.x - StaffCapsule.WIDTH * 0.5
	c.is_true(lid_box.end.x < neighbour_edge, "an open lid does not reach the neighbouring capsule")
	c.is_true(lid_box.position.x >= left.global_position.x + StaffCapsule.WIDTH * 0.5 - 0.01, "an open lid does not hang over the bed")
	var bed_y := StaffCapsule.BASE_HEIGHT + StaffCapsule.BED_THICKNESS
	player.global_position = left.global_position + Vector3(0, bed_y + player.STAND_HEIGHT * 0.5 + 0.05, 0)
	player.velocity = Vector3.ZERO
	await c.physics_frames(30)
	var feet: float = player.global_position.y - player.STAND_HEIGHT * 0.5
	c.near(feet, bed_y, 0.02, "the hero stands on the bed of an open capsule")
	c.is_true(player.is_on_floor() and player.can_stand() and not player.is_crouching, "standing on the bed is steady and upright")

	var debris := _add(c, "debris_blockage", Vector3(20, 0, 0)) as SimpleProp
	var blocking := false
	for node in debris.get_children():
		var shape := node as CollisionShape3D
		if shape and shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.x >= 4.5 and (shape.shape as BoxShape3D).size.y >= 2.5:
			blocking = true
	c.is_true(blocking, "debris closes a 4.5 m passage to full height")

	var cabinet := _add(c, "emergency_cabinet", Vector3(24, 0, 0))
	var board := _add(c, "mnemonic_board", Vector3(26, 1.6, 0))
	await c.tree.process_frame
	c.equal((cabinet.get_meta(Interactable.META) as Interactable).get_inspect_title(), "СХЕМА ЭВАКУАЦИИ · АВАРИЙНЫЙ БЛОК", "cabinet shows the evacuation scheme")
	c.equal((board.get_meta(Interactable.META) as Interactable).get_inspect_title(), "МНЕМОСХЕМА · СТАРОЕ ЯДРО", "board shows the mnemonic text")

	var door := (load("res://objects/doors/service_door.tscn") as PackedScene).instantiate() as FacilityDoor
	door.open_time = 0.05
	c.add(door)
	c.equal(door.lock_reason(), "", "a manual service door needs no power")
	var handle := door.get_node(^"ControlFront").get_meta(Interactable.META) as Interactable
	c.is_true(handle.mode == Interactable.Mode.PRESS and handle.get_prompt_text().ends_with("ОТКРЫТЬ ДВЕРЬ"), "service door opens with a press")
	handle.trigger()
	await door.opened
	c.near((door.get_node(^"Leaf") as Node3D).rotation.y, -FacilityDoor.SWING_ANGLE, 0.001, "service door is hinged")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add(c: OpeningCheck, name: String, position: Vector3) -> Node3D:
	var node := (load(P + name + ".tscn") as PackedScene).instantiate() as Node3D
	node.position = position
	c.add(node)
	return node
