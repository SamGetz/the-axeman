extends Node
## DEV TOOL. Measures the band/crown radius mismatch at the join, and where it
## comes from. Run: godot --headless --path . --quit-after 600 res://core/tools/seam_probe.tscn

func _ready() -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0
	# THE DEV CAMERA (2026-07-26, first person). The game ships player-driven: WASD,
	# mouse look, and a camera nobody but the player owns. This tool frames its work by
	# driving cam_distance / cam_height / cam_focus_y, so it takes the wheel — the
	# player becomes a puppet posed by those exports, reproducing the fixed orbit
	# camera M5 was built and render-verified with. See forest_player.gd's header.
	game.player_controlled = false
	# ONE TREE, at the origin, unrotated — this tool is about one tree's geometry and it frames
	# its work with the dev camera, which orbits the scene origin. The shipping scene is a
	# scattered stand of 25 with a random yaw each, so without this the tool would be measuring
	# a tree ten metres away from the camera it is aiming with.
	game.tree_count = 1
	# ...and the felled trunk clears itself rather than lying there waiting to be
	# bucked, which is what it does in the game now.
	game.trunk_persists = false
	game.voxel_cell = 0.055
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.trunk()
	var vol: WoodVolume = trunk.volume()
	print("band %.3f..%.3f  crown_base %.3f  radius %.3f  cell %.3f" % [
		trunk.band_lo, trunk.band_hi, trunk._crown_base, trunk.radius, vol.cell])
	print("bark fit: fitted=%s  uv=(%.4f per turn, %.4f per m)  offset=(%.4f, %.4f)" % [
		vol.bark_uv_fitted, vol.bark_uv.x, vol.bark_uv.y,
		vol.bark_uv_offset.x, vol.bark_uv_offset.y])
	# What the SOURCE actually does at the join, for comparison: sample its UV at a ring
	# of points on the trunk surface just above the crown's clip.
	var src0 := _source_mesh()
	var y0: float = trunk._crown_base + 0.02
	var ring := _source_uv_ring(src0, y0, trunk.axis_xz)
	if not ring.is_empty():
		print("source at y=%.3f: u spans %.4f..%.4f, v ~ %.4f" % [
			y0, ring["umin"], ring["umax"], ring["v"]])
		print("band   at y=%.3f: u spans %.4f..%.4f, v = %.4f" % [
			y0, -0.5 * vol.bark_uv.x + vol.bark_uv_offset.x,
			0.5 * vol.bark_uv.x + vol.bark_uv_offset.x,
			y0 * vol.bark_uv.y + vol.bark_uv_offset.y])

	# How many sides is the source trunk's cross-section? Count distinct vertex
	# angles in one thin horizontal slab of the source mesh.
	var src: Mesh = _source_mesh()
	var y := trunk.band_hi - 0.3
	var angs: Array[float] = []
	for v in MeshUtils.vertices(src):
		if absf(v.y - y) < 0.12 and Vector2(v.x, v.z).distance_to(trunk.axis_xz) < trunk.radius * 1.3:
			var a := atan2(v.z - trunk.axis_xz.y, v.x - trunk.axis_xz.x)
			var dup := false
			for b in angs:
				if absf(angle_difference(a, b)) < 0.05:
					dup = true
					break
			if not dup:
				angs.append(a)
	print("source trunk cross-section: %d distinct vertex angles near y=%.2f" % [angs.size(), y])
	if angs.size() >= 3:
		var half := PI / float(angs.size())
		print("  => an N-gon's corner radius exceeds its flat radius by %.1f%% (%.1f mm here)" % [
			(1.0 / cos(half) - 1.0) * 100.0, (1.0 / cos(half) - 1.0) * trunk.radius * 1000.0])

	# The band's ACTUAL rendered radius vs the source mesh's, at the same height.
	print("")
	print(" angle |  source r |  band r  | band - source")
	print("-------+-----------+----------+--------------")
	var probe_y := trunk.band_hi - 0.25
	var worst := 0.0
	for t in range(12):
		var a := TAU * float(t) / 12.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var c := Vector3(trunk.axis_xz.x, probe_y, trunk.axis_xz.y)
		# band: march in from outside through the voxel field
		var hit := vol.first_solid(c + dir * trunk.radius * 2.5, -dir, trunk.radius * 3.0)
		var band_r: float = trunk.radius * 2.5 - hit.dist if hit.hit else 0.0
		var src_r := _mesh_radius(src, probe_y, a, trunk.axis_xz)
		if src_r <= 0.0:
			continue
		var d := band_r - src_r
		worst = maxf(worst, absf(d))
		print(" %5.0f | %9.4f | %8.4f | %+9.4f m" % [rad_to_deg(a), src_r, band_r, d])
	print("worst |band - source| = %.4f m (%.1f mm)" % [worst, worst * 1000.0])
	get_tree().quit()


## Radius of the source mesh at height `y` in direction `ang`, by intersecting the
## ray with its triangles.
func _mesh_radius(mesh: Mesh, y: float, ang: float, axis: Vector2) -> float:
	var c := Vector3(axis.x, y, axis.y)
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var from := c + dir * 5.0
	var best := -1.0
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := WoodVolume.triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var hit = Geometry3D.ray_intersects_triangle(from, -dir,
				verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]])
			if hit == null:
				continue
			var r: float = (hit as Vector3).distance_to(c)
			if r > best:
				best = r
	return best


## The source mesh's UVs on a ring round the trunk at height `y` — what the band's
## fitted wrap has to agree with.
func _source_uv_ring(mesh: Mesh, y: float, axis: Vector2) -> Dictionary:
	var us: Array[float] = []
	var vs: Array[float] = []
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw: Variant = arr[Mesh.ARRAY_TEX_UV]
		if not (raw is PackedVector2Array) or (raw as PackedVector2Array).size() != verts.size():
			continue
		var uvs: PackedVector2Array = raw
		for i in range(verts.size()):
			if absf(verts[i].y - y) < 0.08 and Vector2(verts[i].x, verts[i].z).distance_to(axis) < 0.7:
				us.append(uvs[i].x)
				vs.append(uvs[i].y)
	if us.is_empty():
		return {}
	us.sort()
	vs.sort()
	return {"umin": us[0], "umax": us[us.size() - 1], "v": vs[vs.size() / 2]}


func _source_mesh() -> Mesh:
	var scene: PackedScene = load("res://assets/models/trees_export/tree_01.fbx")
	var inst := scene.instantiate()
	var out: Mesh = null
	var most := -1
	for mi in _meshes(inst):
		var n: int = (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if n > most:
			most = n
			out = mi.mesh
	inst.queue_free()
	return out


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out
