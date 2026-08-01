extends Node
## res://core/tools/trunk_collider_probe.gd — attaches to the root Node of
## trunk_collider_probe.tscn.
##
## DEV DIAGNOSTIC for handoff/09 §1: "when a tree falls, the top half penetrates
## through the floor."
##
## It fells each species and asks two questions about the timber that comes down:
##
##   1. IN THE BODY'S OWN FRAME, does the collider actually contain the wood? Not
##      "does it span the wood" — a cylinder can span the whole trunk and still sit
##      beside it, which is precisely what was happening. Every wood vertex is
##      tested against the collider shapes and the worst miss is reported.
##   2. ONCE IT HAS SETTLED, how far below the dirt is the lowest wood VERTEX?
##
## Both halves run twice per species: once with the fitted slab stack the game now
## builds, and once with the legacy single cylinder swapped in mid-fall, so the A/B
## is one run and one asset (the `bark_ab_shot` pattern).
##
## MEASUREMENT TRAP, and it produced a confident wrong answer here first: never
## measure a fallen trunk with `xform * mesh.get_aabb()`. Transforming an AABB gives
## the box that bounds the ROTATED BOX, not the rotated mesh, so a horizontal trunk
## reads as metres deeper than it is. Sample vertices.
##
## Run: godot --headless --path . --quit-after 400000 \
##   res://core/tools/trunk_collider_probe.tscn

## Flip to measure the same thing with the root voxeliser on (handoff/09 §2). It ships
## OFF, so the default here is the shipping config; `band_lo` moves to the ground with it
## and that changes what `detach_above` hands over, so the two are worth comparing.
const VOXEL_ROOTS := true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	print("=== TRUNK COLLIDER PROBE ===")
	for species in [0, 1]:
		for legacy in [true, false]:
			await _probe(species, legacy)
	print("=== TRUNK COLLIDER PROBE DONE ===")
	get_tree().quit()


func _probe(species: int, legacy: bool) -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = species
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.tree_count = 1
	game.trunk_persists = true
	game.auto_respawn = false
	# Pinned exactly as m5_acceptance and felling_smoke pin them: this reports on the
	# MECHANIC, not on whatever Sam currently has dialled into the .tscn (whose
	# cut_span of 0.50 cannot fell either trunk at all).
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.voxel_roots = VOXEL_ROOTS
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.trunk()
	if trunk == null or not trunk.is_built():
		print("FAIL: no trunk built for species %d" % species)
		game.queue_free()
		return
	print("\n--- species %d (%s) — %s ---" % [species, trunk.species_id,
		"LEGACY one cylinder" if legacy else "FITTED slab stack"])
	print("tree: height=%.2f radius=%.3f band=%.2f..%.2f" % [
		trunk.height, trunk.radius, trunk.band_lo, trunk.band_hi])

	var blows := 0
	while blows < 60 and not game.is_felling():
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
		blows += 1
	if not game.is_felling():
		print("FAIL: never came down in %d blows" % blows)
		game.queue_free()
		return

	var body: RigidBody3D = null
	for i in range(400):
		await _wait(0.02)
		body = _find_body(game)
		if body != null:
			break
	if body == null:
		print("FAIL: no FallenTrunk rigid body appeared")
		game.queue_free()
		return

	if legacy:
		_install_legacy(body, game.debug_fallen_length(), trunk.radius)

	var slabs := _slabs(body)
	print("collider: %d cylinder(s), local y %.3f .. %.3f" % [
		slabs.size(), _stack_lo(slabs), _stack_hi(slabs)])
	print("felled in %d blows, timber %.3f m" % [blows, game.debug_fallen_length()])

	# --- 1. does it contain the wood, in the body's own frame? ----------------
	var total := 0
	var outside := 0
	var worst := 0.0
	for p in _wood_points(body):
		total += 1
		var miss := _miss(p, slabs)
		if miss > 0.0005:
			outside += 1
			worst = maxf(worst, miss)
	print(">>> wood vertices OUTSIDE the collider: %d of %d (%.1f%%), worst miss %.3f m" % [
		outside, total, 100.0 * float(outside) / maxf(float(total), 1.0), worst])

	# --- 2. where does it end up? --------------------------------------------
	for i in range(600):
		await _wait(0.05)
		if game.has_settled():
			break
	if not is_instance_valid(body):
		print("(the body is gone before it settled)")
		game.queue_free()
		await get_tree().process_frame
		return
	var deepest := INF
	var deepest_local := Vector3.ZERO
	var gx := body.global_transform
	for p in _wood_points(body):
		var w: Vector3 = gx * p
		if w.y < deepest:
			deepest = w.y
			deepest_local = p
	var ground := _ground_under(body, gx * deepest_local)
	print("settled: tilt %.1f deg, lowest wood vertex at y %.3f, dirt at y %.3f" % [
		game.fall_tilt_deg(), deepest, ground])
	print(">>> wood BELOW THE DIRT: %.3f m   %s" % [
		maxf(ground - deepest, 0.0),
		"<<< SINKING" if ground - deepest > 0.05 else "(resting on it)"])
	game.queue_free()
	await get_tree().process_frame


## Strip the fitted stack and put back the collider the game built before
## 2026-07-30 — one cylinder of the trunk's radius on the body's local Y axis,
## running from the origin (the hinge) to the length of the timber.
func _install_legacy(body: RigidBody3D, length: float, radius: float) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			body.remove_child(child)
			child.queue_free()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = maxf(length, 0.05)
	cs.shape = cyl
	cs.position = Vector3(0.0, length * 0.5, 0.0)
	body.add_child(cs)


func _slabs(body: RigidBody3D) -> Array:
	var out: Array = []
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs != null and cs.shape is CylinderShape3D:
			var c: CylinderShape3D = cs.shape
			out.append({"y": cs.position.y, "h": c.height, "r": c.radius,
				"c": Vector2(cs.position.x, cs.position.z)})
	return out


func _stack_lo(slabs: Array) -> float:
	var lo := INF
	for s in slabs:
		lo = minf(lo, (s.y as float) - (s.h as float) * 0.5)
	return lo


func _stack_hi(slabs: Array) -> float:
	var hi := -INF
	for s in slabs:
		hi = maxf(hi, (s.y as float) + (s.h as float) * 0.5)
	return hi


## How far outside the collider a body-local point is (0 = inside). A point above or
## below every slab counts as its horizontal miss from the nearest one by height,
## so an end sticking out past the stack is not scored as covered.
func _miss(p: Vector3, slabs: Array) -> float:
	var best := INF
	for s in slabs:
		var dy: float = absf(p.y - (s.y as float)) - (s.h as float) * 0.5
		var dr: float = Vector2(p.x, p.z).distance_to(s.c) - (s.r as float)
		best = minf(best, maxf(maxf(dy, dr), 0.0))
	return 0.0 if is_inf(best) else best


## Every vertex of the TIMBER, in the body's own frame. The shed canopy is excluded:
## it is visual only and is removed on the landing frame.
func _wood_points(body: RigidBody3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in body.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi: MeshInstance3D = child
		if mi.mesh == null or mi.name == "ShedCanopy":
			continue
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				out.append(mi.transform * v)
	return out


## The height of whatever is under a world point, ignoring the trunk itself —
## "below y = 0" is not the same as "below the dirt", which sits a few mm up.
func _ground_under(body: RigidBody3D, at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 4.0)
	q.exclude = [body.get_rid()]
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _find_body(node: Node) -> RigidBody3D:
	if node is RigidBody3D and node.name == "FallenTrunk":
		return node
	for c in node.get_children():
		var hit := _find_body(c)
		if hit != null:
			return hit
	return null
