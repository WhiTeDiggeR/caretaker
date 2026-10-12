class_name WorldScreen
extends MeshInstance3D

## Screen of the complex rendered on a model through a SubViewport (issue #146): the
## ScreenView of its era is drawn into the viewport and shown on this quad with the CRT or
## LCD treatment of world_screen.gdshader. The viewport renders only when the picture
## changes (rows, power, boot, blinking), so idle screens cost nothing.

const SHADER := preload("res://materials/ui/world_screen.gdshader")
## Light the picture adds to the scene; the glass reflects when the screen is off.
const EMISSION_ENERGY := 1.6
## Type size on a model relative to the full-screen terminal.
const TEXT_SCALE := 1.5

@export var era: StringName = ScreenStyle.DEFAULT_ERA
@export var resolution := Vector2i(1280, 720)
@export var quad_size := Vector2(1.84, 1.04)

var view: ScreenView
var _viewport: SubViewport
var _material: ShaderMaterial


func _ready() -> void:
	var style := ScreenStyle.for_era(era)
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.size = resolution
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	view = ScreenView.new()
	view.name = "View"
	view.size = resolution
	view.text_scale = TEXT_SCALE
	view.setup(style)
	_viewport.add_child(view)
	view.changed.connect(_request_render)
	var quad := QuadMesh.new()
	quad.size = quad_size
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"picture", _viewport.get_texture())
	_material.set_shader_parameter(&"emission_energy", EMISSION_ENERGY)
	_material.set_shader_parameter(&"glass", Color(style.bezel, 1.0))
	_apply_crt(style)
	material_override = _material
	Settings.changed.connect(func() -> void: _apply_crt(style))


func show_rows(title: String, rows: Array[Dictionary]) -> void:
	view.show_rows(title, rows)


func set_powered(on: bool) -> void:
	view.set_powered(on)
	_material.set_shader_parameter(&"powered", on)


func _apply_crt(style: ScreenStyle) -> void:
	var crt := Settings.crt_effects
	_material.set_shader_parameter(&"scanlines", style.scanlines if crt else 0.0)
	_material.set_shader_parameter(&"pixel_grid", style.pixel_grid if crt else 0.0)
	_material.set_shader_parameter(&"vignette", style.vignette if crt else 0.0)
	_material.set_shader_parameter(&"scanline_count", float(resolution.y) * 0.5)
	_material.set_shader_parameter(&"grid_cells", Vector2(resolution) * 0.5)


func _request_render() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
