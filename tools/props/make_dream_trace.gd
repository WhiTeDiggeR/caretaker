extends SceneTree

## Builds Н-05, the operator's death trace (#199, docs/art/dream-bowser-s.md §4, Д-5): a glass crack
## Ø 0.8 m flat on the floor with three raised chips, as an ArrayMesh the scene sets on
## Yard/Ambush/OperatorTrace. The glass material (materials/dream_bowser/operator_trace.tres) is the
## scene's surface override, so DreamRemains' white material_override still wins once the ambush starts.
## godot --headless --path . --script res://tools/props/make_dream_trace.gd

const OUT := "res://objects/dream/operator_trace_mesh.tres"
const RADIUS := 0.4
const CRACKS := 9
const LIFT := 0.004
const SEED := 199


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1, 1, 1))
	# radial cracks: jagged ribbons thinning to the tip, a branch on every other one
	for i in CRACKS:
		var angle := TAU * i / CRACKS + rng.randf_range(-0.2, 0.2)
		var length := RADIUS * rng.randf_range(0.7, 1.0)
		var points := _jagged(Vector2.ZERO, angle, length, 6, rng)
		_ribbon(st, points, 0.018, 0.004)
		if i % 2 == 0:
			var from: Vector2 = points[2]
			_ribbon(st, _jagged(from, angle + rng.randf_range(0.5, 0.9) * (1 if i % 4 == 0 else -1), length * 0.4, 3, rng), 0.01, 0.003)
	# a broken ring of shatter around the centre
	for i in 7:
		var a0 := TAU * i / 7.0 + rng.randf_range(0.0, 0.3)
		var r := RADIUS * rng.randf_range(0.35, 0.5)
		_ribbon(st, [Vector2.from_angle(a0) * r, Vector2.from_angle(a0 + 0.45) * r * 1.05, Vector2.from_angle(a0 + 0.8) * r], 0.008, 0.006)
	# raised chips
	st.set_color(Color(0.5, 0.5, 0.5))
	for i in 3:
		var c := Vector2.from_angle(rng.randf() * TAU) * RADIUS * rng.randf_range(0.2, 0.8)
		_chip(st, Vector3(c.x, 0.0, c.y), rng.randf_range(0.03, 0.05), rng)
	st.generate_normals()
	var mesh := st.commit()
	mesh.resource_name = "dream_operator_trace"
	var err := ResourceSaver.save(mesh, OUT)
	print("DREAM_TRACE %s tris=%d err=%d" % [OUT, mesh.get_faces().size() / 3, err])
	quit(err)


func _jagged(from: Vector2, angle: float, length: float, steps: int, rng: RandomNumberGenerator) -> Array:
	var points := [from]
	for s in steps:
		var dir := Vector2.from_angle(angle + rng.randf_range(-0.35, 0.35))
		points.append(points[-1] + dir * length / steps)
	return points


func _ribbon(st: SurfaceTool, points: Array, w0: float, w1: float) -> void:
	for s in points.size() - 1:
		var a: Vector2 = points[s]
		var b: Vector2 = points[s + 1]
		var side := (b - a).normalized().orthogonal()
		var t0 := lerpf(w0, w1, float(s) / (points.size() - 1)) * 0.5
		var t1 := lerpf(w0, w1, float(s + 1) / (points.size() - 1)) * 0.5
		var q := [a + side * t0, a - side * t0, b - side * t1, b + side * t1]
		var v: Array[Vector3] = []
		for p: Vector2 in q:
			v.append(Vector3(p.x, LIFT, p.y))
		_quad(st, v)


func _chip(st: SurfaceTool, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var tip := at + Vector3(rng.randf_range(-0.3, 0.3) * size, size * 0.8, rng.randf_range(-0.3, 0.3) * size)
	var base: Array[Vector3] = []
	for k in 3:
		var d := Vector2.from_angle(TAU * k / 3.0 + rng.randf()) * size
		base.append(at + Vector3(d.x, LIFT, d.y))
	for k in 3:
		st.add_vertex(base[k])
		st.add_vertex(base[(k + 1) % 3])
		st.add_vertex(tip)


func _quad(st: SurfaceTool, v: Array[Vector3]) -> void:
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[idx])
