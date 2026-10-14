extends RefCounted

## #134: footsteps by distance and surface, landing, breathing, head bob and its setting,
## screen effects of the hero's states.

const PLAYER := "res://scenes/player/player.tscn"
const TEST_SETTINGS := "user://test_feel_settings.cfg"
const PHYSICS_FPS := 60.0


func run(c: OpeningCheck) -> void:
	await _surfaces(c)
	await _steps(c)
	await _landing_and_breath(c)
	await _bob(c)
	await _settings(c)
	await _screen_effects(c)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _surfaces(c: OpeningCheck) -> void:
	var plain := _box(c, Vector3(0, -50, 0), Vector3(1, 0.2, 1))
	c.equal(FirstPersonFeel.surface_of(plain), &"concrete", "an unmarked floor is concrete")
	var metal := _box(c, Vector3(2, -50, 0), Vector3(1, 0.2, 1))
	metal.set_meta(FirstPersonFeel.SURFACE_META, "metal")
	c.equal(FirstPersonFeel.surface_of(metal), &"metal", "the surface meta names the surface")
	var grate := _box(c, Vector3(4, -50, 0), Vector3(1, 0.2, 1))
	grate.add_to_group(&"surface_grate")
	c.equal(FirstPersonFeel.surface_of(grate), &"grate", "a surface group names the surface")
	var parent := Node3D.new()
	parent.set_meta(FirstPersonFeel.SURFACE_META, &"metal")
	c.add(parent)
	var child := StaticBody3D.new()
	parent.add_child(child)
	c.equal(FirstPersonFeel.surface_of(child), &"metal", "the collider's parent can name the surface")
	var odd := Node3D.new()
	odd.set_meta(FirstPersonFeel.SURFACE_META, "glass")
	c.add(odd)
	c.equal(FirstPersonFeel.surface_of(odd), &"concrete", "an unknown surface falls back to concrete")
	c.equal(FirstPersonFeel.step_sound(FirstPersonFeel.Gait.WALK, &"grate"), &"step_grate", "walking sounds the surface")
	c.equal(FirstPersonFeel.step_sound(FirstPersonFeel.Gait.CRAWL, &"metal"), &"step_crawl", "crawling rustles on any surface")
	c.equal(FirstPersonFeel.step_sound(FirstPersonFeel.Gait.LADDER, &"concrete"), &"step_ladder", "ladder rungs clank")
	var station := (load("res://scenes/sandbox/stations/surface_station.tscn") as PackedScene).instantiate() as Node3D
	station.position = Vector3(0, -60, 0)
	c.add(station)
	for strip: String in ["Concrete", "Metal", "Grate"]:
		c.equal(FirstPersonFeel.surface_of(station.get_node(strip)), StringName(strip.to_lower()), "the sandbox track %s sounds as its surface" % strip)
	for sound: StringName in [&"step_concrete", &"step_metal", &"step_grate", &"step_crawl", &"step_ladder", &"land", &"breath"]:
		c.is_true(Sfx.sounds.has(sound), "the catalogue has %s" % sound)


func _steps(c: OpeningCheck) -> void:
	var floor_body := _box(c, Vector3(100, -0.1, 0), Vector3(20, 0.2, 200))
	floor_body.set_meta(FirstPersonFeel.SURFACE_META, "metal")
	var player := _spawn_player(c, Vector3(100, 0.9, 80))
	var feel := player.get_node(^"Feel") as FirstPersonFeel
	await c.physics_frames(5)
	var steps: Array[StringName] = []
	feel.stepped.connect(func(sound: StringName) -> void: steps.append(sound))

	var walk := await _walk(c, player, 120, false)
	c.equal(steps.size() > 0 and steps.all(func(s: StringName) -> bool: return s == &"step_metal"), true, "steps on a metal floor sound metal")
	c.equal(feel.surface, &"metal", "the surface underfoot is probed")
	var walk_expected := walk / FirstPersonFeel.STRIDE[FirstPersonFeel.Gait.WALK]
	c.near(steps.size(), walk_expected, 1.0, "one walking step per stride (%.1f m)" % walk)
	var walk_rate := steps.size() / (120 / PHYSICS_FPS)

	await c.physics_frames(30)
	steps.clear()
	var still := player.global_position
	await c.physics_frames(60)
	c.equal(steps.size(), 0, "standing still makes no steps")
	c.is_true(player.global_position.distance_to(still) < 0.01, "the hero stands still")

	var run := await _walk(c, player, 120, true)
	var run_rate := steps.size() / (120 / PHYSICS_FPS)
	c.near(steps.size(), run / FirstPersonFeel.STRIDE[FirstPersonFeel.Gait.RUN], 1.0, "one running step per longer stride (%.1f m)" % run)
	c.is_true(run_rate > walk_rate, "running steps come faster (%.2f/s against %.2f/s)" % [run_rate, walk_rate])

	await c.physics_frames(30)
	steps.clear()
	Input.action_press(&"crouch")
	await c.physics_frames(20)
	var crouched := await _walk(c, player, 120, false)
	Input.action_release(&"crouch")
	c.near(steps.size(), crouched / FirstPersonFeel.STRIDE[FirstPersonFeel.Gait.CROUCH], 1.0, "crouched steps follow the short stride")
	c.is_true(steps.size() / (120 / PHYSICS_FPS) < walk_rate, "crouched steps are slower than walking")

	# A teleport (checkpoint, load) is not a walk.
	await c.physics_frames(40)
	steps.clear()
	player.global_position += Vector3(0, 0, -20)
	await c.physics_frames(3)
	c.equal(steps.size(), 0, "a teleport makes no steps")
	player.queue_free()


func _landing_and_breath(c: OpeningCheck) -> void:
	_box(c, Vector3(200, -0.1, 0), Vector3(10, 0.2, 10))
	var player := _spawn_player(c, Vector3(200, 4.0, 0))
	var feel := player.get_node(^"Feel") as FirstPersonFeel
	var heard: Array[StringName] = []
	var on_sound := func(id: StringName) -> void: heard.append(id)
	Sfx.requested.connect(on_sound)
	var falls: Array[float] = []
	feel.landed.connect(func(speed: float) -> void: falls.append(speed))
	await c.physics_frames(90)
	c.equal(falls.size(), 1, "a fall ends in one landing")
	c.is_true(not falls.is_empty() and falls[0] > FirstPersonFeel.LAND_MIN_SPEED, "the landing reports the fall speed")
	c.is_true(heard.has(&"land"), "a landing thuds")

	heard.clear()
	feel.exertion = 0.9
	await c.physics_frames(3)
	c.is_true(feel.breathing, "an exhausted hero breathes heavily")
	c.is_true(heard.has(&"breath"), "heavy breathing is heard")
	feel.exertion = 0.1
	await c.physics_frames(3)
	c.is_true(not feel.breathing, "breathing calms down with rest")
	Sfx.requested.disconnect(on_sound)
	player.queue_free()


func _bob(c: OpeningCheck) -> void:
	Settings.set_head_bob(1.0)
	_box(c, Vector3(300, -0.1, 0), Vector3(20, 0.2, 200))
	var player := _spawn_player(c, Vector3(300, 0.9, 80))
	var camera := player.get_node(^"Camera3D") as Camera3D
	await c.physics_frames(5)
	var rest := camera.position.y
	var lowest := rest
	var highest := rest
	Input.action_press(&"move_forward")
	Input.action_press(&"move_right")
	var roll := 0.0
	for _i in 90:
		await c.tree.physics_frame
		lowest = minf(lowest, camera.position.y)
		highest = maxf(highest, camera.position.y)
		roll = minf(roll, camera.rotation.z)
	c.is_true(rest - lowest > 0.01, "walking bobs the camera (%.3f m)" % (rest - lowest))
	c.is_true(rest - lowest <= FirstPersonFeel.BOB_HEIGHT[FirstPersonFeel.Gait.WALK] + 0.001, "the bob stays small")
	c.is_true(roll < -0.001, "strafing right rolls the view")

	Settings.set_head_bob(0.0)
	await c.physics_frames(5)
	var still_y := camera.position.y
	var moved := false
	for _i in 60:
		await c.tree.physics_frame
		moved = moved or not is_equal_approx(camera.position.y, still_y) or not is_zero_approx(camera.position.x)
	Input.action_release(&"move_forward")
	Input.action_release(&"move_right")
	c.is_true(not moved, "the setting switches the bob off")
	c.near(camera.position.y, rest, 0.0001, "without the bob the eyes stay at their height")
	c.near(camera.rotation.z, 0.0, 0.0001, "without the bob there is no roll")
	Settings.set_head_bob(Settings.DEFAULT_HEAD_BOB)
	player.queue_free()


func _settings(c: OpeningCheck) -> void:
	var original_path := Settings.config_path
	Settings.config_path = TEST_SETTINGS
	Settings.set_head_bob(3.0)
	c.near(Settings.head_bob, 1.0, 0.0001, "head bob strength is clamped")
	Settings.set_head_bob(0.4)
	c.equal(Settings.save_settings(), OK, "settings with head bob are saved")
	Settings.set_head_bob(1.0)
	Settings.load_settings()
	c.near(Settings.head_bob, 0.4, 0.0001, "head bob strength is loaded")
	Settings.reset_all()
	c.near(Settings.head_bob, Settings.DEFAULT_HEAD_BOB, 0.0001, "reset restores the head bob")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Settings.config_path = original_path
	Settings.load_settings()


func _screen_effects(c: OpeningCheck) -> void:
	for id: StringName in [&"wake_up", &"gas", &"dream_exit", &"dream_eject", &"dream_woken", &"dream_hit"]:
		c.is_true(ScreenEffects.duration(id) > 0.0, "screen effect %s is defined" % id)
	var keys := [{"t": 0.0, "blur": 1.0}, {"t": 2.0, "blur": 0.0, "darken": 1.0}]
	c.near(ScreenEffects._sample(keys, "blur", 1.0), 0.5, 0.0001, "keyframes interpolate")
	c.near(ScreenEffects._sample(keys, "darken", 1.0), 0.5, 0.0001, "a missing key counts as zero")
	c.near(ScreenEffects._sample(keys, "blur", 5.0), 0.0, 0.0001, "after the last key its value holds")

	var started: Array[StringName] = []
	var finished: Array[StringName] = []
	var on_start := func(id: StringName) -> void: started.append(id)
	var on_finish := func(id: StringName) -> void: finished.append(id)
	ScreenEffects.effect_started.connect(on_start)
	ScreenEffects.effect_finished.connect(on_finish)

	ScreenEffects.play(&"dream_hit")
	c.is_true(ScreenEffects.is_playing(&"dream_hit"), "an effect starts")
	c.near(ScreenEffects.value("vignette"), 0.6, 0.0001, "the effect starts on its first keyframe")
	await c.tree.create_timer(ScreenEffects.duration(&"dream_hit") + 0.2).timeout
	c.is_true(not ScreenEffects.is_playing(), "the effect fades out by itself")
	c.equal(finished, [&"dream_hit"] as Array[StringName], "the end of the effect is announced")

	Shell.new_game_started.emit()
	c.is_true(ScreenEffects.is_playing(&"wake_up"), "a new game wakes the hero in the capsule")
	c.near(ScreenEffects.value("darken"), 1.0, 0.0001, "waking starts in the dark")
	Containment.hero_gassed.emit(&"module_4")
	c.is_true(ScreenEffects.is_playing(&"gas"), "the chemical protocol's gas clouds the view")
	ScreenEffects.elapsed = ScreenEffects.duration(&"gas") + 1.0
	await c.tree.process_frame
	c.is_true(ScreenEffects.is_playing(&"gas"), "the gas holds until the hero is out")
	GameState.state_loaded.emit()
	c.is_true(not ScreenEffects.is_playing(), "loading clears the screen")
	Dreams.left.emit(&"module_4", Dreams.Exit.GATE)
	c.is_true(not ScreenEffects.is_playing(), "leaving a dream draws nothing under the veil")
	Dreams.arrived.emit(&"module_4", Dreams.Exit.GATE)
	c.is_true(ScreenEffects.is_playing(&"dream_exit"), "coming back through the gate flashes softly")
	c.near(ScreenEffects.value("flash"), 0.9, 0.0001, "the gate aftertaste continues the white veil")
	Dreams.arrived.emit(&"module_4", Dreams.Exit.DEATH)
	c.is_true(ScreenEffects.is_playing(&"dream_eject"), "being thrown out of the dream is harsh")
	c.near(ScreenEffects.value("flash"), 0.0, 0.0001, "the death aftertaste has no white flash over the dark red veil")
	Dreams.arrived.emit(&"module_4", Dreams.Exit.WOKEN)
	c.is_true(ScreenEffects.is_playing(&"dream_woken"), "the forced awakening has its own dim aftertaste")
	ScreenEffects.stop()
	c.equal(started, [&"dream_hit", &"wake_up", &"gas", &"dream_exit", &"dream_eject", &"dream_woken"] as Array[StringName], "every hook starts its effect")
	# Layers (#166): the effects never cover the dream veil or the loading screen.
	c.is_true(ScreenEffects.layer < Dreams._fade.layer and Dreams._fade.layer < Shell._loading_layer.layer, "effects lie under the dream veil and the loading screen")
	ScreenEffects.effect_started.disconnect(on_start)
	ScreenEffects.effect_finished.disconnect(on_finish)


## Walks forward (sprinting if asked) for `frames` physics frames; returns the distance.
func _walk(c: OpeningCheck, player: CharacterBody3D, frames: int, sprint: bool) -> float:
	var start := player.global_position
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint")
	await c.physics_frames(frames)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var moved := player.global_position - start
	return Vector2(moved.x, moved.z).length()


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
