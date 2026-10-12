class_name DreamBolt
extends Area3D

## Projectile of a ranged dream image: flies straight, hurts the first enemy it touches and
## disappears on anything solid or when its lifetime ends. Ignores the hero.

const RADIUS := 0.15
const COLOR := Color(0.55, 0.85, 1.0)

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 20.0
var knockback := 2.5
var lifetime := 2.0


func _ready() -> void:
	direction = direction.normalized()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.material = PropKit.material(COLOR, true)
	mesh.mesh = sphere
	add_child(mesh)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		return
	if body is DreamEnemy:
		(body as DreamEnemy).take_hit(damage, direction * knockback)
	queue_free()
