class_name DreamGlyphImage
extends Node3D

## A glyph as the dream sees it (07-dream-glyphs.md, З-2 «А»): the dream's image — for now a
## flat tinted plate standing in for the relief art of З-Р4 — with the glyph cut inside as a
## crack. The crack stays muted, close to the plate and hard to read, until `revealed` (the
## ring of the seal has come into place); then it shows white (Б-5).

const PLATE_HEIGHT := 0.02
const MUTED_MIX := 0.18
const REVEALED_ENERGY := 2.5
const DEFAULT_TINT := Color(0.42, 0.38, 0.34)

@export var glyph_id := ""
@export var dream: StringName = &"bowser"
@export var size := 0.4
@export var revealed := false:
	set(value):
		revealed = value
		_apply()

var _crack_material: StandardMaterial3D
var _tint := DEFAULT_TINT


func _ready() -> void:
	var tint: Array = DreamKnowledge.image(dream, glyph_id).get("tint", [])
	if tint.size() >= 3:
		_tint = Color(tint[0], tint[1], tint[2])
	var plate := MeshInstance3D.new()
	plate.name = "Image"
	var disc := CylinderMesh.new()
	disc.top_radius = size * 0.62
	disc.bottom_radius = size * 0.62
	disc.height = PLATE_HEIGHT
	disc.radial_segments = 6
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = _tint
	plate_material.roughness = 0.9
	disc.material = plate_material
	plate.mesh = disc
	plate.rotation.x = PI * 0.5
	plate.position.z = -PLATE_HEIGHT * 0.5
	add_child(plate)
	_crack_material = StandardMaterial3D.new()
	_crack_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crack_material.emission_enabled = true
	_crack_material.emission = Color.WHITE
	var crack := DreamGlyph.mesh_instance(glyph_id, size, _crack_material)
	crack.position.z = 0.002
	add_child(crack)
	_apply()


## Contrast of the crack against the image, 0…1; low while muted.
func crack_contrast() -> float:
	if _crack_material == null:
		return 0.0
	var albedo := _crack_material.albedo_color
	return absf(albedo.get_luminance() - _tint.get_luminance()) + _crack_material.emission_energy_multiplier


func _apply() -> void:
	if _crack_material == null:
		return
	_crack_material.albedo_color = Color.WHITE if revealed else _tint.lerp(Color.WHITE, MUTED_MIX)
	_crack_material.emission_energy_multiplier = REVEALED_ENERGY if revealed else 0.0
