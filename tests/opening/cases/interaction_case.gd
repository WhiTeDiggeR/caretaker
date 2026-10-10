extends RefCounted

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const DT := 0.25


class LegacyProp:
	extends StaticBody3D
	var calls := 0
	func interact() -> void:
		calls += 1
	func get_interaction_text() -> String:
		return "СТАРЫЙ ОБЪЕКТ"


func run(c: OpeningCheck) -> void:
	var interactor: Interactor = c.add(Interactor.new())
	var label := Label.new()
	c.add(label)
	interactor.prompt_label = label
	var bar := ProgressBar.new()
	c.add(bar)
	interactor.hold_bar = bar

	# Target lookup through the collider and its parents.
	var press := _make(c, Interactable.Mode.PRESS, "НАЖАТЬ")
	var body := press.get_parent()
	var child_collider := StaticBody3D.new()
	body.add_child(child_collider)
	c.equal(Interactor.find_target(body), press, "component is found on its body")
	c.equal(Interactor.find_target(child_collider), press, "component is found from a child collider")
	c.equal(Interactor.find_target(null), null, "nothing under the ray")

	# PRESS triggers once per press.
	var presses := [0]
	press.interacted.connect(func() -> void: presses[0] += 1)
	interactor.step(press, true, true, DT)
	interactor.step(press, true, false, DT)
	c.equal(presses[0], 1, "press triggers once")
	c.is_true(label.visible and label.text.ends_with("НАЖАТЬ"), "press prompt is shown")
	interactor.step(null, false, false, DT)
	c.is_true(not label.visible, "prompt hides without a target")

	# HOLD triggers after hold_time and is cancelled by release or by looking away.
	var hold := _make(c, Interactable.Mode.HOLD, "ПОВЕРНУТЬ")
	hold.hold_time = 1.0
	hold.one_shot = true
	var holds := [0, 0]
	hold.interacted.connect(func() -> void: holds[0] += 1)
	hold.hold_cancelled.connect(func() -> void: holds[1] += 1)
	interactor.step(hold, true, true, DT)
	interactor.step(hold, true, false, DT)
	c.near(interactor.hold_progress, 0.5, 0.001, "hold progress grows")
	c.is_true(bar.visible, "hold bar is visible while holding")
	interactor.step(hold, false, false, DT)
	c.equal(interactor.hold_progress, 0.0, "release resets the hold")
	c.equal(holds[1], 1, "release cancels the hold")
	interactor.step(hold, true, true, DT)
	interactor.step(press, true, false, DT)
	c.equal(holds[1], 2, "looking away cancels the hold")
	for _i in 4:
		interactor.step(hold, true, false, DT)
	c.equal(holds[0], 1, "hold completes after hold_time")
	c.is_true(not bar.visible, "hold bar hides after completion")
	for _i in 8:
		interactor.step(hold, true, false, DT)
	c.equal(holds[0], 1, "one-shot hold does not repeat")
	c.is_true(not label.visible, "used one-shot object has no prompt")

	# INSPECT shows its text.
	var inspect := _make(c, Interactable.Mode.INSPECT, "ОСМОТРЕТЬ")
	inspect.inspect_title = "ПАНЕЛЬ"
	inspect.inspect_text = "Текст"
	var messages: Array[String] = []
	interactor.message_requested.connect(func(title: String, text: String) -> void: messages.append(title + "|" + text))
	interactor.step(inspect, true, true, DT)
	c.equal(messages, ["ПАНЕЛЬ|Текст"] as Array[String], "inspect requests its message")

	# Unavailable objects show a reason and do nothing.
	var dead := _make(c, Interactable.Mode.PRESS, "ВКЛЮЧИТЬ")
	dead.available = false
	dead.unavailable_prompt = "НЕТ ПИТАНИЯ"
	var dead_calls := [0]
	dead.interacted.connect(func() -> void: dead_calls[0] += 1)
	interactor.step(dead, true, true, DT)
	c.equal(dead_calls[0], 0, "unavailable object is not triggered")
	c.equal(label.text, "НЕТ ПИТАНИЯ", "unavailable prompt has no key hint")

	# Older props with interact() still work.
	var legacy := LegacyProp.new()
	c.add(legacy)
	c.equal(Interactor.find_target(legacy), legacy, "legacy prop is a target")
	interactor.step(legacy, true, true, DT)
	c.equal(legacy.calls, 1, "legacy prop is triggered by a press")
	c.is_true(label.text.ends_with("СТАРЫЙ ОБЪЕКТ"), "legacy prompt text is used")

	await _sandbox_case(c)


func _sandbox_case(c: OpeningCheck) -> void:
	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	await c.physics_frames(3)
	var button := sandbox.get_node(^"Stations/InteractionStation/Button") as Node3D
	player.global_position = Vector3(button.global_position.x, 0.9, button.global_position.z - 1.6)
	player.rotation = Vector3(0, PI, 0)
	(player.get_node(^"Camera3D") as Node3D).rotation.x = deg_to_rad(-30.0)
	await c.physics_frames(4)
	c.equal(player.interactor.target, button.get_node(^"Interactable"), "player ray finds the sandbox button")
	var hud := sandbox.get_node(^"OpeningHud") as OpeningHud
	c.is_true(hud.interact_label.visible and hud.interact_label.text.ends_with("НАЖАТЬ КНОПКУ"), "HUD shows the button prompt")
	player.interactor.show_message("ЗАГОЛОВОК", "Сообщение")
	c.is_true(hud.message_panel.visible and hud.message_text.text == "Сообщение", "HUD displays inspect messages")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _make(c: OpeningCheck, mode: Interactable.Mode, prompt: String) -> Interactable:
	var body := StaticBody3D.new()
	var interactable := Interactable.new()
	interactable.mode = mode
	interactable.prompt = prompt
	body.add_child(interactable)
	c.add(body)
	return interactable
