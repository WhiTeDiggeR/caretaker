class_name DreamSealRings
extends DreamSeal

## Seal of three rings (#183; docs/game_design/06-bowser-dream-world.md, section 6, B-7).
## Each ring carries the six glyphs of DreamKnowledge and turns by 1/6 with its own lever at
## the edge of the disc. The correct positions come from the visit's code
## (`DreamKnowledge.prepare`): ring i is right when the glyph code[i] stands under the
## reading mark (outer → inner), and then its piece of the light crack lies on the mark too.
## When all three are right the crack runs unbroken from the edge to the core and the seal
## ends in the same chain as `DreamSeal` (`complete()`). A wrong turn costs only time (B-10):
## a hum and sparks. The glow is white (B-5). The ring positions are kept in GameState system
## data, so the dream remembers them across saves and returns within a visit; a new visit
## (a new code) scrambles them again.

signal ring_turned(ring: int, position: int)

const RING_COUNT := 3
const POSITIONS := 6
## Each ring lists the glyphs from its own place in the set, so the rings do not read alike.
const RING_OFFSETS: Array[int] = [0, 2, 4]
const RING_NAMES: Array[String] = ["НАРУЖНОЕ", "СРЕДНЕЕ", "ВНУТРЕННЕЕ"]
const SYSTEM := &"dream_seal_rings"
const WHITE := Color(1.0, 1.0, 1.0)
const STONE := Color(0.3, 0.27, 0.25)
const RING_STONE := Color(0.36, 0.33, 0.3)
const CRACK_DIM := 0.6
const CRACK_BRIGHT := 3.5
const RESTORED_LIGHT_ENERGY := 2.5
const TURN_TIME := 0.45
const RING_HEIGHT := 0.12
const DISC_HEIGHT := 0.3
const CORE_RADIUS := 0.6
const LEVER_GAP := 0.7
const PROMPT_TURN := "ПОВЕРНУТЬ %s КОЛЬЦО"
const PROMPT_DONE := "ПЕЧАТЬ ВОССТАНОВЛЕНА"
const INSPECT_TITLE := "ПЕЧАТЬ"
const INSPECT_TEXT := "Три кольца со знаками, в каждом — трещина. Под меткой у края сходятся знаки колец. Трещина света должна пройти от края до ядра."

## Radius of the disc; the rings share it evenly outside the core.
@export var radius := 3.0
@export var turn_sound: StringName = &"valve"
@export var wrong_sound: StringName = &"breaker"
@export var aligned_sound: StringName = &"switch"

## Positions of the rings, 0…5 sixths of a turn.
var positions: Array[int] = [0, 0, 0]
var levers: Array[Interactable] = []
var _code := PackedStringArray()
var _pivots: Array[Node3D] = []
var _crack_materials: Array[StandardMaterial3D] = []
var _glyph_labels: Array[Label3D] = []
var _sparks: Array[CPUParticles3D] = []
var _tweens: Array[Tween] = [null, null, null]
var _light: OmniLight3D


func _ready() -> void:
	_material = (_glow.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_glow.set_surface_override_material(0, _material)
	_interactable.mode = Interactable.Mode.INSPECT
	_interactable.inspect_title = INSPECT_TITLE
	_interactable.inspect_text = INSPECT_TEXT
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
	return result


## The glyph under the reading mark for each ring, outer first.
func glyphs_under_mark() -> PackedStringArray:
	var result := PackedStringArray()
	for ring in RING_COUNT:
		result.append(ring_glyphs(ring)[positions[ring]])
	return result


func is_ring_aligned(ring: int) -> bool:
	return positions[ring] == correct_position(ring)


func is_solved() -> bool:
	for ring in RING_COUNT:
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
		for ring in RING_COUNT:
			positions[ring] = correct_position(ring)
			_pivots[ring].rotation.y = _angle(positions[ring])
	for ring in RING_COUNT:
		var lit := restored or is_ring_aligned(ring)
		_crack_materials[ring].emission_energy_multiplier = CRACK_BRIGHT if lit else CRACK_DIM
		levers[ring].available = not restored
		levers[ring].unavailable_prompt = PROMPT_DONE if restored else ""
	for label in _glyph_labels:
		label.modulate = WHITE if restored else Color(0.85, 0.8, 0.72)
	_show(restored)


func _visit_code() -> PackedStringArray:
	var result := PackedStringArray()
	if not knowledge_id.is_empty():
		result = DreamKnowledge.code(knowledge_id) if is_restored() else DreamKnowledge.prepare(knowledge_id)
	if result.size() < RING_COUNT:
		# Without knowledge (a decorative seal) the first glyphs of the set are the code.
		result = DreamKnowledge.glyphs().slice(0, RING_COUNT)
	return result


func _state_key() -> String:
	return String(knowledge_id) if not knowledge_id.is_empty() else String(name)


func _load_positions() -> void:
	var saved: Dictionary = GameState.get_system_data(SYSTEM).get(_state_key(), {})
	if PackedStringArray(saved.get("code", [])) == _code and (saved.get("positions", []) as Array).size() == RING_COUNT:
		for ring in RING_COUNT:
			positions[ring] = posmod(int(saved["positions"][ring]), POSITIONS)
	else:
		_scramble()
	for ring in RING_COUNT:
		_pivots[ring].rotation.y = _angle(positions[ring])


## A new code starts with every ring off its place.
func _scramble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for ring in RING_COUNT:
		positions[ring] = posmod(correct_position(ring) + rng.randi_range(1, POSITIONS - 1), POSITIONS)
	_save_positions()


func _save_positions() -> void:
	var data := GameState.get_system_data(SYSTEM).duplicate(true)
	data[_state_key()] = {"code": Array(_code), "positions": positions.duplicate()}
	GameState.set_system_data(SYSTEM, data)


func _on_state_loaded() -> void:
	_code = _visit_code()
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
	_tweens[ring] = tween


## Ring rotation that brings sector `position` under the mark (+Z).
static func _angle(position: int) -> float:
	return -float(position) * TAU / POSITIONS


func _ring_radii(ring: int) -> Vector2:
	var width := (radius - CORE_RADIUS) / RING_COUNT
	var outer := radius - width * ring
	return Vector2(outer - width, outer)


func _build() -> void:
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
	cylinder.radius = radius
	cylinder.height = DISC_HEIGHT
	shape.shape = cylinder
	shape.position.y = DISC_HEIGHT * 0.5
	add_child(shape)
	# The reading mark at the edge facing the levers.
	PropKit.box(self, Vector3(0, DISC_HEIGHT + 0.02, radius + 0.15), Vector3(0.12, 0.04, 0.3), PropKit.material(WHITE, true))
	for ring in RING_COUNT:
		_build_ring(ring)
		_build_lever(ring)
	_place_cracks()
	_light = OmniLight3D.new()
	_light.light_color = WHITE
	_light.light_energy = RESTORED_LIGHT_ENERGY
	_light.omni_range = radius * 2.5
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
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radii.x + 0.04
	torus.outer_radius = radii.y - 0.04
	torus.material = PropKit.material(RING_STONE)
	band.mesh = torus
	band.scale = Vector3(1, RING_HEIGHT / maxf(radii.y - radii.x, 0.01), 1)
	pivot.add_child(band)
	var glyphs := ring_glyphs(ring)
	var middle := (radii.x + radii.y) * 0.5
	for sector in POSITIONS:
		var angle := float(sector) * TAU / POSITIONS
		var label := Label3D.new()
		label.text = glyphs[sector]
		label.font_size = 40
		label.pixel_size = 0.004 * (1.0 + 0.3 * (RING_COUNT - 1 - ring) / float(RING_COUNT))
		label.outline_size = 8
		# Lies flat on the ring, read from the edge looking at the core.
		label.position = Vector3(sin(angle) * (middle + 0.12), RING_HEIGHT * 0.5 + 0.01, cos(angle) * (middle + 0.12))
		label.rotation = Vector3(-PI * 0.5, angle, 0)
		pivot.add_child(label)
		_glyph_labels.append(label)
	var crack := MeshInstance3D.new()
	crack.name = "Crack"
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(0.08, 0.03, radii.y - radii.x)
	var material := PropKit.material(WHITE, true)
	material.emission_energy_multiplier = CRACK_DIM
	crack_mesh.material = material
	crack.mesh = crack_mesh
	pivot.add_child(crack)
	_crack_materials.append(material)


## Each ring's piece of the crack lies on the sector of its code glyph.
func _place_cracks() -> void:
	for ring in RING_COUNT:
		var crack := _pivots[ring].get_node(^"Crack") as Node3D
		var radii := _ring_radii(ring)
		var middle := (radii.x + radii.y) * 0.5
		var angle := float(correct_position(ring)) * TAU / POSITIONS
		crack.position = Vector3(sin(angle) * (middle - 0.12), RING_HEIGHT * 0.5 + 0.02, cos(angle) * (middle - 0.12))
		crack.rotation = Vector3(0, angle, 0)


func _build_lever(ring: int) -> void:
	var lever := StaticBody3D.new()
	lever.name = "Lever%d" % ring
	lever.position = Vector3((ring - 1) * 1.2, 0, radius + LEVER_GAP)
	add_child(lever)
	var dark := PropKit.material(Color(0.22, 0.2, 0.19))
	PropKit.box(lever, Vector3(0, 0.5, 0), Vector3(0.2, 1.0, 0.2), dark, true)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.3
	torus.material = PropKit.material(RING_STONE)
	wheel.mesh = torus
	wheel.position = Vector3(0, 1.05, 0.12)
	wheel.rotation = Vector3(PI * 0.5, 0, 0)
	lever.add_child(wheel)
	var reach := CollisionShape3D.new()
	var reach_shape := BoxShape3D.new()
	reach_shape.size = Vector3(0.7, 0.7, 0.4)
	reach.shape = reach_shape
	reach.position = Vector3(0, 1.05, 0.1)
	lever.add_child(reach)
	PropKit.label(lever, Vector3(0, 1.5, 0.12), RING_NAMES[ring], 28)
	var interactable := PropKit.interactable(lever, Interactable.Mode.PRESS, PROMPT_TURN % RING_NAMES[ring])
	interactable.interacted.connect(turn.bind(ring))
	levers.append(interactable)
	var sparks := CPUParticles3D.new()
	var radii := _ring_radii(ring)
	sparks.position = Vector3(0, DISC_HEIGHT + 0.1, (radii.x + radii.y) * 0.5)
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
