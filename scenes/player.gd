extends CharacterBody3D 

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.5
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002

@onready var camera = $Camera3D
@onready var ray = $Camera3D/RayCast3D

@export var interact_label: Label

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)

		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-89),
			deg_to_rad(89)
		)

func _physics_process(delta):

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_back"
	)

	var direction = (
		transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()
	handle_interaction()

func handle_interaction():
	if not ray.is_colliding():
		interact_label.visible = false
		return

	var target: Node = ray.get_collider()
	while target:
		if target.has_method("interact"):
			interact_label.visible = true
			if target.has_method("get_interaction_text"):
				interact_label.text = target.get_interaction_text()
			else:
				interact_label.text = "[E] ВЗАИМОДЕЙСТВОВАТЬ"
			if Input.is_action_just_pressed("interact"):
				target.interact()
			return
		target = target.get_parent()

	interact_label.visible = false
