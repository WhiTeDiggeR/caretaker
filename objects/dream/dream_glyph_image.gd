class_name DreamGlyphImage
extends Node3D

## A glyph as the dream sees it (07-dream-glyphs.md, З-2 «А»; sketches of #198, З-Р4): a round
## stone medallion with the relief of the dream's image (`loads/dream_images/<dream>/<id>.svg`,
## built from the sketches by tools/dream/dream_image_art.py; it fills a socket of the seal rings)
## and the glyph cut inside it as a crack, at the place and scale of the sketches. The crack stays muted — cut darker into the relief,
## readable up close but not lit — until `revealed` (the ring of the seal has come into place);
## then it shows pale and warm with a soft glow around the strokes, never brighter than the light
## crack of the seal, so it stays a glyph and does not burn into a white spot (#217).
## Without art (another dream) the medallion is a plain disc of the image's tint.

## The glyph spans this share of the medallion's diameter (the sketches: half of the tile, the
## tile scaled by 0.86 into the circle — FIT of dream_image_art.py).
const GLYPH_SHARE := 0.43
const SEGMENTS := 32
const PLATE_HEIGHT := 0.04
const MUTED_DARKEN := 0.5
const REVEALED_COLOR := Color(1.0, 0.95, 0.84)
const REVEALED_ENERGY := 0.45
## A lit rim under the revealed strokes: the same strokes, wider, a warm pale stone that glows
## a little (opaque, so the overlapping pieces of the strokes do not add up into spots).
const GLOW_WIDTH := 2.4
const GLOW_COLOR := Color(0.62, 0.52, 0.38)
const GLOW_ENERGY := 0.12
## Height of the glyph over the tile face; enough to keep the depth test steady at a distance.
const GLYPH_LIFT := 0.006
const DEFAULT_TINT := Color(0.42, 0.38, 0.34)
const BORDER := Color("#4a4036")
const ART_PATH := "res://loads/dream_images/%s/%s.svg"
## Relief depth of the normal map made from the art's brightness.
const RELIEF_STRENGTH := 6.0

## Albedo and normal textures of the art by path: every ring shares them.
static var _art_cache := {}

@export var glyph_id := ""
@export var dream: StringName = &"bowser"
## Width of the glyph, metres; the medallion is `size / GLYPH_SHARE` across.
@export var size := 0.4
@export var revealed := false:
	set(value):
		revealed = value
		_apply()

var _crack_material: StandardMaterial3D
var _glow: MeshInstance3D
var _tint := DEFAULT_TINT


func _ready() -> void:
	var tint: Array = DreamKnowledge.image(dream, glyph_id).get("tint", [])
	if tint.size() >= 3:
		_tint = Color(tint[0], tint[1], tint[2])
	var tile := size / GLYPH_SHARE
	var body := MeshInstance3D.new()
	body.name = "Tile"
	var slab := CylinderMesh.new()
	slab.top_radius = tile * 0.5
	slab.bottom_radius = tile * 0.5
	slab.height = PLATE_HEIGHT
	slab.radial_segments = SEGMENTS
	slab.rings = 1
	var image_material := _image_material()
	var has_art := image_material.albedo_texture != null
	slab.material = _plain_material(BORDER) if has_art else image_material
	body.mesh = slab
	body.rotation.x = PI * 0.5
	body.position.z = -PLATE_HEIGHT * 0.5
	add_child(body)
	if has_art:
		var face := MeshInstance3D.new()
		face.name = "Image"
		var quad := QuadMesh.new()
		quad.size = Vector2(tile, tile)
		quad.material = image_material
		face.mesh = quad
		face.position.z = 0.001
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(face)
	_crack_material = StandardMaterial3D.new()
	_crack_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crack_material.roughness = 0.95
	_crack_material.emission_enabled = true
	var crack := DreamGlyph.mesh_instance(glyph_id, size, _crack_material)
	crack.position.z = GLYPH_LIFT
	add_child(crack)
	_glow = DreamGlyph.mesh_instance(glyph_id, size, _glow_material())
	_glow.name = "Glow"
	_glow.mesh = DreamGlyph.build_mesh(glyph_id, size, GLOW_WIDTH)
	_glow.position.z = GLYPH_LIFT * 0.5
	add_child(_glow)
	_apply()


## Contrast of the crack against the image, 0…1; low while muted.
func crack_contrast() -> float:
	if _crack_material == null:
		return 0.0
	var albedo := _crack_material.albedo_color
	return absf(albedo.get_luminance() - _tint.get_luminance()) + _crack_material.emission_energy_multiplier


## Colour of a muted glyph cut into an image of `tint` (also the afterimage of the dream).
static func muted_color(tint: Color) -> Color:
	return tint.darkened(MUTED_DARKEN)


## The art of `id` in `dream`, or null when the dream has none.
static func art_texture(dream_id: StringName, id: String) -> Texture2D:
	var path := ART_PATH % [dream_id, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _image_material() -> StandardMaterial3D:
	var path := ART_PATH % [dream, glyph_id]
	if not _art_cache.has(path):
		var albedo := art_texture(dream, glyph_id)
		_art_cache[path] = [albedo, _relief(albedo) if albedo else null]
	var art: Array = _art_cache[path]
	var material := _plain_material(_tint)
	if art[0]:
		# Outside its circle the art is transparent: the medallion's edge is the slab's.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.albedo_color = Color.WHITE
		material.albedo_texture = art[0]
		material.normal_enabled = true
		material.normal_texture = art[1]
	return material


## A normal map from the brightness of the art: the light figure stands out of the dark stone.
static func _relief(albedo: Texture2D) -> Texture2D:
	var image := albedo.get_image()
	if image == null:
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	image.bump_map_to_normal_map(RELIEF_STRENGTH)
	image.generate_mipmaps(true)
	return ImageTexture.create_from_image(image)


static func _plain_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


static func _glow_material() -> StandardMaterial3D:
	var material := _plain_material(GLOW_COLOR)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = GLOW_COLOR
	material.emission_energy_multiplier = GLOW_ENERGY
	return material


func _apply() -> void:
	if _crack_material == null:
		return
	_crack_material.albedo_color = REVEALED_COLOR if revealed else muted_color(_tint)
	_crack_material.emission = REVEALED_COLOR
	_crack_material.emission_energy_multiplier = REVEALED_ENERGY if revealed else 0.0
	_glow.visible = revealed
