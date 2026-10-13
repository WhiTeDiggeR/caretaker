class_name CrystalBackdrop
extends ColorRect

## Variant B «Кристалл» of the shell (issue #144): a breathing crystal in the dark behind the
## splash and the loading screen. Fills its parent.

const SHADER := preload("res://materials/ui/crystal_glow.gdshader")
const CENTRE := Vector2(0.5, 0.4)
const SHARD: Array[Vector2] = [Vector2(0, -1), Vector2(0.48, -0.25), Vector2(0.28, 1), Vector2(-0.24, 1), Vector2(-0.5, -0.2)]
const SHARD_SIZE := Vector2(26.0, 60.0)
const SHARD_COLORS := [Color("#f4fbff"), Color("#9fd3e6"), Color("#4a7f9a"), Color("#6aa3bd"), Color("#d9f1fa")]

var _shard: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter(&"centre", CENTRE)
	material = shader_material
	# The shard is drawn by a child: the glow shader of this rect would repaint it.
	_shard = Control.new()
	_shard.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard.draw.connect(_draw_shard)
	add_child(_shard)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	(material as ShaderMaterial).set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	_shard.queue_redraw()


func _draw_shard() -> void:
	var centre := size * CENTRE
	var points := PackedVector2Array()
	for point in SHARD:
		points.append(centre + (point * SHARD_SIZE * 0.5).rotated(deg_to_rad(8.0)))
	_shard.draw_polygon(points, PackedColorArray(SHARD_COLORS))
