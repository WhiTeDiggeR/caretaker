extends Node3D

@export var flicker_enabled := false
@export var base_energy := 9.25
@export var fixture_color := Color(0.58, 0.72, 0.92, 1)

@onready var main_light: SpotLight3D = $Light

var _next_change := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_disable_fixture_shadows()
	main_light.light_color = fixture_color
	main_light.light_energy = base_energy

func _disable_fixture_shadows() -> void:
	if $Model is GeometryInstance3D:
		($Model as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in $Model.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if geometry is MeshInstance3D:
			_dim_emissive_materials(geometry as MeshInstance3D)

func _dim_emissive_materials(mesh_instance: MeshInstance3D) -> void:
	if not mesh_instance.mesh:
		return
	for surface_index in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_active_material(surface_index)
		if source is StandardMaterial3D:
			var material := source.duplicate() as StandardMaterial3D
			if material.emission_enabled:
				material.emission_energy_multiplier = minf(material.emission_energy_multiplier, 0.85)
			mesh_instance.set_surface_override_material(surface_index, material)

func _process(delta: float) -> void:
	if not flicker_enabled:
		return
	_next_change -= delta
	if _next_change > 0.0:
		return
	_next_change = _rng.randf_range(0.04, 0.45)
	var dimmed := _rng.randf() < 0.2
	main_light.light_energy = base_energy * (0.18 if dimmed else _rng.randf_range(0.78, 1.0))
