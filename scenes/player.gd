extends CharacterBody3D 

const SPEED = 5.0
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

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	handle_interaction()

func handle_interaction():

	if ray.is_colliding():
		print(ray.get_collider())

		var collider = ray.get_collider()

		if collider:

			var target = collider.get_parent()

			if target.is_in_group("sleep_pods"):

				interact_label.visible = true

				if Input.is_action_just_pressed("interact"):
					target.interact()

				return

	interact_label.visible = false
