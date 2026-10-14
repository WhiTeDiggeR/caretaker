class_name DreamSealRings
extends DreamSeal

## Seal of rings (#183; docs/game_design/06-bowser-dream-world.md, section 6, B-7): one ring per
## glyph of the visit's code — three in V1–V2, four from V3 (#197, `length_by_version`).
## Each ring carries six of the eight glyphs of DreamKnowledge as images of the dream
## (DreamGlyphImage) and turns by 1/6 with its own lever at
## the edge of the disc. The correct positions come from the visit's code
## (`DreamKnowledge.prepare`): ring i is right when the glyph code[i] stands under the
## reading mark (outer → inner), and then its piece of the light crack lies on the mark too.
## The glyph inside an image stays muted until its ring is right; then the code glyph under
## the mark shows (#194, author's note to З-2). The levers carry no names (#208): which wheel
## turns which ring is for the player to find out. When all three are right the crack runs unbroken from the edge to the core and the seal
## ends in the same chain as `DreamSeal` (`complete()`). The art (#195) has three rings; a longer
## code adds plain stone rings outside it, so the code still reads outer → inner. A wrong turn costs only time (B-10):
## a hum and sparks. The glow is white (B-5). The ring positions are kept in GameState system
## data, so the dream remembers them across saves and returns within a visit; a new visit
## (a new code) scrambles them again.

signal ring_turned(ring: int, position: int)

## Rings of the base seal (a three-glyph code) and of its art; a longer code adds rings up to MAX_RINGS.
const RING_COUNT := 3
const MAX_RINGS := 4
const POSITIONS := 6
## Each ring lists six glyphs from its own place in the set, so the rings do not read alike;
## the code glyph replaces the last one when the ring's six lack it.
const RING_OFFSETS: Array[int] = [0, 2, 4, 6]
const SYSTEM := &"dream_seal_rings"
const WHITE := Color(1.0, 1.0, 1.0)
const STONE := Color(0.3, 0.27, 0.25)
const RING_STONE := Color(0.36, 0.33, 0.3)
const CRACK_DIM := 0.6
const CRACK_BRIGHT := 4.0
## The crack lies under the glyph plates (#208): its light shows on both sides of an image
## and does not run over the glyph. A soft additive halo around it makes it read as light.
const CRACK_HEIGHT := 0.015
const CRACK_WIDTH := 0.07
const HALO_WIDTH := 0.5
const HALO_LIFT := 0.004
const HALO_DIM := 0.15
const HALO_BRIGHT := 0.9
const HALO_COLOR := Color(1.0, 0.96, 0.88)
## Height of the glyph images over the ring top: clear of the ring and of the crack.
const GLYPH_LIFT := 0.03
const RESTORED_LIGHT_ENERGY := 2.5
const TURN_TIME := 0.45
const RING_HEIGHT := 0.12
const DISC_HEIGHT := 0.3
const CORE_RADIUS := 0.6
const LEVER_GAP := 0.7
## The art (#195) is modelled for a disc of this radius; another radius scales it.
const ART_RADIUS := 4.0
## Tops of the art rings above the floor, outer first (stepped, docs/art/dream-bowser-s.md ПЧ-1).
const ART_RING_TOPS: Array[float] = [0.45, 0.6, 0.75]
const ART_WHEEL_OFFSET := Vector3(0, 0, -0.15)
## An added ring outside the art steps down by this much from the art's outer ring.
const ART_RING_STEP := 0.15
const LEVER_SPACING := 1.2
## Texts (prompts, inspection) are the `seal_*` keys of data/dreams/knowledge.json (#200).

## Radius of the disc; the rings share it evenly outside the core.
@export var radius := 3.0
@export var turn_sound: StringName = &"valve"
@export var wrong_sound: StringName = &"breaker"
@export var aligned_sound: StringName = &"switch"
## Art of the disc and rings (loads/props/dream_seal): its nodes Ring1…Ring3 turn with the rings;
## each ring has empty sockets where the glyphs lie (#188). Without it the seal is built of primitives.
@export var art: PackedScene
## Art of a lever (loads/props/dream_seal_wheel): its node Wheel spins with every turn.
@export var wheel_art: PackedScene

## Positions of the rings, 0…5 sixths of a turn.
var positions: Array[int] = []
## Rings of this visit's seal: the code length (RING_COUNT…MAX_RINGS).
var ring_count := RING_COUNT
var levers: Array[Interactable] = []
var _code := PackedStringArray()
var _pivots: Array[Node3D] = []
var _crack_materials: Array[StandardMaterial3D] = []
var _halo_materials: Array[StandardMaterial3D] = []
var _glyph_images: Array[Array] = []
var _sparks: Array[CPUParticles3D] = []
var _tweens: Array[Tween] = []
## Children of the scene itself; everything else is built from the code and rebuilt with it.
var _scene_children: Array[Node] = []
var _light: OmniLight3D
var _art: Node3D
var _wheels: Array[Node3D] = []


func _ready() -> void:
	_material = (_glow.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_glow.set_surface_override_material(0, _material)
	_interactable.mode = Interactable.Mode.INSPECT
	_interactable.inspect_title = str(DreamKnowledge.text("seal_inspect_title"))
	_scene_children = get_children()
	_code = _visit_code()
	_build()
	_load_positions()
	GameState.state_loaded.connect(_on_state_loaded)
	_refresh()


## The glyphs of the visit, outer ring first.
func code() -> PackedStringArray:
	return _code


## The position at which `ring` shows its glyph of the code under the reading mark.
func correct_position(ring: int) -> int:
	return posmod(ring_glyphs(ring).find(_code[ring]), POSITIONS)


## The glyphs of `ring` by sector; sector k stands under the mark at position k.
func ring_glyphs(ring: int) -> PackedStringArray:
	var pool := DreamKnowledge.glyphs()
	var result := PackedStringArray()
	for sector in POSITIONS:
		result.append(pool[(sector + RING_OFFSETS[ring]) % pool.size()])
	if ring < _code.size() and not _code[ring] in result:
		result[POSITIONS - 1] = _code[ring]
	return result


## Whether the glyph of `ring` at `sector` shows (its ring is right and it is under the mark).
func is_glyph_revealed(ring: int, sector: int) -> bool:
	return (_glyph_images[ring][sector] as DreamGlyphImage).revealed


## The glyph under the reading mark for each ring, outer first.
func glyphs_under_mark() -> PackedStringArray:
	var result := PackedStringArray()
	for ring in ring_count:
		result.append(ring_glyphs(ring)[positions[ring]])
	return result


func is_ring_aligned(ring: int) -> bool:
	return positions[ring] == correct_position(ring)


func is_solved() -> bool:
	for ring in ring_count:
		if not is_ring_aligned(ring):
			return false
	return true


func is_restored() -> bool:
	return Dreams.in_dream and Dreams.seal_restored


## Turns `ring` by 1/6. A wrong result costs nothing but the hum and sparks; the last right
## ring restores the seal. A turn during the previous one finishes that one at once. Returns
## false once the seal is restored.
func turn(ring: int) -> bool:
	if is_restored():
		return false
	positions[ring] = (positions[ring] + 1) % POSITIONS
	_save_positions()
	_animate(ring)
	ring_turned.emit(ring, positions[ring])
	_play(turn_sound, ring)
	if is_ring_aligned(ring):
		_play(aligned_sound, ring)
	else:
		_play(wrong_sound, ring)
		_sparks[ring].restart()
		_sparks[ring].emitting = true
	_refresh()
	if is_solved():
		complete()
		_refresh()
	return true


func _show(restored: bool) -> void:
	_interactable.available = true
	_material.albedo_color = WHITE if restored else STONE
	_material.emission = WHITE
	_material.emission_energy_multiplier = CRACK_BRIGHT if restored else CRACK_DIM
	if _light:
		_light.visible = restored


func _refresh() -> void:
	var restored := is_restored()
	if restored:
		# A restored seal stands aligned: the crack runs whole (also after a reload).
		for ring in ring_count:
			positions[ring] = correct_position(ring)
			_pivots[ring].rotation.y = _angle(positions[ring])
	for ring in ring_count:
		var lit := restored or is_ring_aligned(ring)
		_crack_materials[ring].emission_energy_multiplier = CRACK_BRIGHT if lit else CRACK_DIM
		_halo_materials[ring].albedo_color = _halo(HALO_BRIGHT if lit else HALO_DIM)
		levers[ring].available = not restored
		levers[ring].unavailable_prompt = str(DreamKnowledge.text("seal_prompt_done")) if restored else ""
	for ring in ring_count:
		for sector in POSITIONS:
			var lit := (restored or is_ring_aligned(ring)) and sector == positions[ring]
			(_glyph_images[ring][sector] as DreamGlyphImage).revealed = lit
	_show(restored)


func _visit_code() -> PackedStringArray:
	var result := PackedStringArray()
	if not knowledge_id.is_empty():
		result = DreamKnowledge.code(knowledge_id) if is_restored() else DreamKnowledge.prepare(knowledge_id)
	if result.size() < RING_COUNT:
		# Without knowledge (a decorative seal) the first glyphs of the set are the code.
		result = DreamKnowledge.glyphs().slice(0, RING_COUNT)
	return result.slice(0, MAX_RINGS)


func _state_key() -> String:
	return String(knowledge_id) if not knowledge_id.is_empty() else String(name)


func _load_positions() -> void:
	var saved: Dictionary = GameState.get_system_data(SYSTEM).get(_state_key(), {})
	if PackedStringArray(saved.get("code", [])) == _code and (saved.get("positions", []) as Array).size() == ring_count:
		for ring in ring_count:
			positions[ring] = posmod(int(saved["positions"][ring]), POSITIONS)
	else:
		_scramble()
	for ring in ring_count:
		_pivots[ring].rotation.y = _angle(positions[ring])


## A new code starts with every ring off its place.
func _scramble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for ring in ring_count:
		positions[ring] = posmod(correct_position(ring) + rng.randi_range(1, POSITIONS - 1), POSITIONS)
	_save_positions()


func _save_positions() -> void:
	var data := GameState.get_system_data(SYSTEM).duplicate(true)
	data[_state_key()] = {"code": Array(_code), "positions": positions.duplicate()}
	GameState.set_system_data(SYSTEM, data)


func _on_state_loaded() -> void:
	_code = _visit_code()
	if _code.size() != ring_count:
		# Another visit's code with another length: the rings are built anew.
		_clear()
		_build()
	_place_cracks()
	_load_positions()
	_refresh()


func _play(id: StringName, ring: int) -> void:
	if not id.is_empty():
		Sfx.play(id, levers[ring].get_parent())


func _animate(ring: int) -> void:
	var pivot := _pivots[ring]
	if _tweens[ring] and _tweens[ring].is_valid():
		_tweens[ring].kill()
	# From the previous position, so an interrupted turn does not skip its sixth.
	pivot.rotation.y = _angle(posmod(positions[ring] - 1, POSITIONS))
	var tween := create_tween()
	tween.tween_property(pivot, "rotation:y", pivot.rotation.y - TAU / POSITIONS, TURN_TIME)
	tween.tween_callback(func() -> void: pivot.rotation.y = _angle(positions[ring]))
	var wheel := _wheels[ring]
	if wheel:
		tween.parallel().tween_property(wheel, "rotation:z", wheel.rotation.z + TAU / POSITIONS, TURN_TIME)
	_tweens[ring] = tween


## Ring rotation that brings sector `position` under the mark (+Z).
static func _angle(position: int) -> float:
	return -float(position) * TAU / POSITIONS


## Rings added outside the art (a code longer than the art's rings); 0 without art.
func _extra_rings() -> int:
	return ring_count - RING_COUNT if _art else 0


func _ring_radii(ring: int) -> Vector2:
	# Without art the rings share the disc evenly; the art keeps its three and the added
	# rings lie outside the disc with the same width.
	var width := (radius - CORE_RADIUS) / (RING_COUNT if _art else ring_count)
	var outer := radius - width * (ring - _extra_rings())
	return Vector2(outer - width, outer)


func _outer_radius() -> float:
	return _ring_radii(0).y


## Height of the top of `ring` above its pivot (the disc top): glyphs and cracks lie on it.
func _ring_top(ring: int) -> float:
	if not _art:
		return RING_HEIGHT * 0.5
	var art_ring := ring - _extra_rings()
	if art_ring >= 0:
		return ART_RING_TOPS[art_ring] - DISC_HEIGHT
	return ART_RING_TOPS[0] + ART_RING_STEP * art_ring - DISC_HEIGHT


## Removes what `_build()` made, for a code of another length.
func _clear() -> void:
	for child in get_children():
		if not child in _scene_children:
			remove_child(child)
			child.queue_free()
	_art = null
	_light = null
	_pivots.clear()
	_crack_materials.clear()
	_halo_materials.clear()
	_glyph_images.clear()
	_sparks.clear()
	_tweens.clear()
	_wheels.clear()
	levers.clear()


func _build() -> void:
	ring_count = clampi(_code.size(), RING_COUNT, MAX_RINGS)
	positions.resize(ring_count)
	positions.fill(0)
	_tweens.resize(ring_count)
	_interactable.inspect_text = str(DreamKnowledge.text("seal_inspect_text")) % str(DreamKnowledge.text("seal_count_%d" % ring_count))
	if art:
		_art = art.instantiate() as Node3D
		_art.scale = Vector3(radius / ART_RADIUS, 1.0, radius / ART_RADIUS)
		add_child(_art)
	else:
		var disc := MeshInstance3D.new()
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = radius
		disc_mesh.bottom_radius = radius + 0.1
		disc_mesh.height = DISC_HEIGHT
		disc_mesh.material = PropKit.material(STONE)
		disc.mesh = disc_mesh
		disc.position.y = DISC_HEIGHT * 0.5
		add_child(disc)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = _outer_radius()
	cylinder.height = DISC_HEIGHT
	shape.shape = cylinder
	shape.position.y = DISC_HEIGHT * 0.5
	add_child(shape)
	# The reading mark at the edge facing the levers.
	PropKit.box(self, Vector3(0, DISC_HEIGHT + 0.02, _outer_radius() + 0.15), Vector3(0.12, 0.04, 0.3), PropKit.material(WHITE, true))
	for ring in ring_count:
		_build_ring(ring)
		_build_lever(ring)
	_place_cracks()
	_light = OmniLight3D.new()
	_light.light_color = WHITE
	_light.light_energy = RESTORED_LIGHT_ENERGY
	_light.omni_range = _outer_radius() * 2.5
	_light.position.y = 1.5
	_light.visible = false
	add_child(_light)


func _build_ring(ring: int) -> void:
	var radii := _ring_radii(ring)
	var pivot := Node3D.new()
	pivot.name = "Ring%d" % ring
	pivot.position.y = DISC_HEIGHT
	add_child(pivot)
	_pivots.append(pivot)
	var art_ring := ring - _extra_rings()
	var ring_art := _art.get_node_or_null(NodePath("Ring%d" % (art_ring + 1))) as Node3D if _art and art_ring >= 0 else null
	if ring_art:
		ring_art.reparent(pivot, false)
		ring_art.transform = Transform3D(Basis.from_scale(_art.scale), Vector3.ZERO)
	else:
		var band := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radii.x + 0.04
		torus.outer_radius = radii.y - 0.04
		torus.material = PropKit.material(RING_STONE)
		band.mesh = torus
		# A ring added outside the art stands on the floor like the art's rings.
		var height := DISC_HEIGHT + _ring_top(ring) if _art else RING_HEIGHT
		band.scale = Vector3(1, height / maxf(radii.y - radii.x, 0.01), 1)
		band.position.y = _ring_top(ring) - height * 0.5
		pivot.add_child(band)
	_glyph_images.append([])
	var glyphs := ring_glyphs(ring)
	var middle := (radii.x + radii.y) * 0.5
	for sector in POSITIONS:
		var angle := float(sector) * TAU / POSITIONS
		var image := DreamGlyphImage.new()
		image.glyph_id = glyphs[sector]
		image.size = minf(radii.y - radii.x, 0.9) * 0.8
		# Lies flat on the ring, read from the edge looking at the core.
		image.position = Vector3(sin(angle) * middle, _ring_top(ring) + GLYPH_LIFT, cos(angle) * middle)
		image.rotation = Vector3(-PI * 0.5, angle, 0)
		pivot.add_child(image)
		_glyph_images[ring].append(image)
	var crack := MeshInstance3D.new()
	crack.name = "Crack"
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(CRACK_WIDTH, CRACK_HEIGHT, radii.y - radii.x)
	var material := PropKit.material(WHITE, true)
	material.albedo_color = Color.BLACK  # all of its look is the light it gives
	material.emission_energy_multiplier = CRACK_DIM
	crack_mesh.material = material
	crack.mesh = crack_mesh
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(crack)
	_crack_materials.append(material)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(HALO_WIDTH, radii.y - radii.x)
	halo_mesh.orientation = PlaneMesh.FACE_Y
	halo_mesh.material = _halo_material()
	halo.mesh = halo_mesh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Under the crack, so it moves and turns with it.
	halo.position.y = HALO_LIFT - CRACK_HEIGHT * 0.5
	crack.add_child(halo)
	_halo_materials.append(halo_mesh.material)


## Additive glow fading out across the crack (bright in the middle, nothing at the edges).
static func _halo_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color.BLACK, Color.WHITE, Color.BLACK])
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = _halo(HALO_DIM)
	return material


static func _halo(energy: float) -> Color:
	return Color(HALO_COLOR * energy, 1.0)


## Each ring's piece of the crack lies on the sector of its code glyph.
func _place_cracks() -> void:
	for ring in ring_count:
		var crack := _pivots[ring].get_node(^"Crack") as Node3D
		var radii := _ring_radii(ring)
		var middle := (radii.x + radii.y) * 0.5
		var angle := float(correct_position(ring)) * TAU / POSITIONS
		crack.position = Vector3(sin(angle) * (middle - 0.12), _ring_top(ring) + CRACK_HEIGHT * 0.5, cos(angle) * (middle - 0.12))
		crack.rotation = Vector3(0, angle, 0)


func _build_lever(ring: int) -> void:
	var lever := StaticBody3D.new()
	lever.name = "Lever%d" % ring
	lever.position = Vector3((ring - (ring_count - 1) * 0.5) * LEVER_SPACING, 0, _outer_radius() + LEVER_GAP)
	add_child(lever)
	var dark := PropKit.material(Color(0.22, 0.2, 0.19))
	var post := PropKit.box(lever, Vector3(0, 0.5, 0), Vector3(0.2, 1.0, 0.2), dark, true)
	var wheel_node: Node3D = null
	if wheel_art:
		post.visible = false
		var lever_art := wheel_art.instantiate() as Node3D
		lever_art.position = ART_WHEEL_OFFSET
		lever.add_child(lever_art)
		wheel_node = lever_art.get_node_or_null(^"Wheel") as Node3D
	else:
		var wheel := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.22
		torus.outer_radius = 0.3
		torus.material = PropKit.material(RING_STONE)
		wheel.mesh = torus
		wheel.position = Vector3(0, 1.05, 0.12)
		wheel.rotation = Vector3(PI * 0.5, 0, 0)
		lever.add_child(wheel)
	_wheels.append(wheel_node)
	var reach := CollisionShape3D.new()
	var reach_shape := BoxShape3D.new()
	reach_shape.size = Vector3(0.7, 0.7, 0.4)
	reach.shape = reach_shape
	reach.position = Vector3(0, 1.05, 0.1)
	lever.add_child(reach)
	var interactable := PropKit.interactable(lever, Interactable.Mode.PRESS, str(DreamKnowledge.text("seal_prompt_turn")))
	interactable.interacted.connect(turn.bind(ring))
	levers.append(interactable)
	var sparks := CPUParticles3D.new()
	var radii := _ring_radii(ring)
	sparks.position = Vector3(0, DISC_HEIGHT + (_ring_top(ring) if _art else 0.0) + 0.1, (radii.x + radii.y) * 0.5)
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.explosiveness = 1.0
	sparks.spread = 70.0
	sparks.direction = Vector3(0, 1, 0)
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.5
	var grain := BoxMesh.new()
	grain.size = Vector3(0.03, 0.03, 0.03)
	grain.material = PropKit.material(Color(1.0, 0.9, 0.7), true)
	sparks.mesh = grain
	add_child(sparks)
	_sparks.append(sparks)
