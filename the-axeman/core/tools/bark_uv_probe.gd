extends Node
## DEV TOOL. Is the band's bark the same bark as the crown's and the roots', and do the
## three meet without a step? The band is regenerated from a voxel field and can only
## ever INFER the artist's mapping and approximate their silhouette, so when a chopped
## tree looks wrong at the join this is the tool that says WHICH of the two it is.
##
##   godot --headless --path . --quit-after 3000 res://core/tools/bark_uv_probe.tscn
##
## Optional: `-- species=0` (0 = tree_02, 1 = tree_01).
##
## MEASURE AGAINST THE SOURCE'S OWN VERTICES, never against a ray fired at it. The first
## version of this tool cast one ray per bearing and kept the farthest hit — the rule
## `WoodVolume._build_profile` uses — and reported the trunk's mapping as repeating twice
## round the ring, which sent a day's work after a phantom. The mesh's vertices say
## plainly that it wraps once. A ray keeps whichever of several coincident surfaces it
## happens to hit; a vertex is the art.

@export var species := 1


func _ready() -> void:
	var forced := species
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("species="):
			forced = int(arg.split("=")[1])

	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = forced
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.tree_count = 1
	game.trunk_persists = false
	game.voxel_cell = 0.055
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.debug_nearest_tree()
	var vol: WoodVolume = trunk.volume()
	print("species %d  band %.3f..%.3f  crown_base %.3f  radius %.3f  cell %.3f" % [
		forced, trunk.band_lo, trunk.band_hi, trunk.crown_base(), trunk.radius, vol.cell])
	print("bark fit: fitted=%s  u/turn %.4f  v/m %.4f  offset (%.4f, %.4f)" % [
		vol.bark_uv_fitted, vol.bark_uv.x, vol.bark_uv.y,
		vol.bark_uv_offset.x, vol.bark_uv_offset.y])
	print("")
	_uv_against_source(trunk, vol)
	print("")
	_join_step(trunk)
	get_tree().quit()


## THE BAND'S MAPPING AGAINST THE ARTIST'S. Every trunk-surface vertex in the band's
## range, at its own height and bearing. u is compared modulo one texture repeat —
## landing a whole repeat away is the same texel — and v is not, because a repeat of v
## is a whole texture's height of slide and would be plainly visible.
## Sampled at every TRIANGLE CENTROID of the trunk surface, not at its vertices. These
## trunks are lofted prisms with rings a metre apart, so the whole band holds only a few
## dozen vertices — a sample far too thin to conclude anything from, and concluding "the
## mapping is exact" from 26 of them is exactly the mistake that sent 2026-07-29 after
## the wrong bug. A centroid is on the bark by construction and there are thousands.
func _uv_against_source(trunk: TreeTrunk, vol: WoodVolume) -> void:
	var src: Mesh = trunk.source_mesh
	var worst_u := 0.0
	var worst_v := 0.0
	var n := 0
	var off := 0
	# ...and the SIGNED u error, binned, because a systematic offset is a ROTATION of the
	# bark round the trunk and reads completely differently from scattered noise.
	var mean_du := 0.0
	var mean_dv := 0.0
	for si in trunk._trunk_surfaces(src):
		var arr := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw: Variant = arr[Mesh.ARRAY_TEX_UV]
		if not (raw is PackedVector2Array):
			continue
		var uvs: PackedVector2Array = raw
		var idx := WoodVolume.triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var ia := idx[t]
			var ib := idx[t + 1]
			var ic := idx[t + 2]
			var p := (verts[ia] + verts[ib] + verts[ic]) / 3.0
			if p.y < trunk.band_lo + 0.05 or p.y > trunk.crown_base() - 0.05:
				continue
			var d := Vector2(p.x - trunk.axis_xz.x, p.z - trunk.axis_xz.y)
			if d.length() < trunk.radius * 0.6:
				continue          # inside the wood: a branch stub or a root, not bark
			# A triangle straddling the artist's own UV seam has no single sensible UV;
			# skip it rather than let it dominate the worst case.
			if absf(uvs[ia].x - uvs[ib].x) > 0.4 or absf(uvs[ia].x - uvs[ic].x) > 0.4:
				continue
			var su := (uvs[ia] + uvs[ib] + uvs[ic]) / 3.0
			var b: Vector2 = vol.debug_bark_uv_at(p.y, atan2(d.y, d.x))
			var du: float = b.x - su.x
			du -= floorf(du + 0.5)
			var dv: float = b.y - su.y
			worst_u = maxf(worst_u, absf(du))
			worst_v = maxf(worst_v, absf(dv))
			mean_du += du
			mean_dv += dv
			n += 1
			if absf(du) > 0.02 or absf(dv) > 0.02:
				off += 1
	if n == 0:
		print("bark UV: no bark triangles in the band to sample")
		return
	print("bark UV vs the source, at %d trunk-triangle centroids: %d off by >2%% of a repeat"
		% [n, off])
	print("  worst |du| %.4f  |dv| %.4f   MEAN du %+.4f  dv %+.4f" % [
		worst_u, worst_v, mean_du / n, mean_dv / n])
	print("  a mean du of %+.4f of a repeat is the bark sitting %+.0f degrees round the trunk"
		% [mean_du / n, (mean_du / n) / absf(vol.bark_uv.x) * 360.0])


## THE RADIAL STEP WHERE THE BAND TAKES OVER FROM AN IMPORTED PIECE. Two surfaces meeting
## at a plane show a line if their radii differ there, whatever their UVs do — and this,
## not the mapping, is what the join has always been. `WoodVolume.rim_pin` is the fix, so
## this is the number that says whether it is working.
func _join_step(trunk: TreeTrunk) -> void:
	var roots: MeshInstance3D = trunk.get_node_or_null("Roots")
	var band: Node3D = trunk.get_node_or_null("Butt")
	if roots == null or band == null or roots.mesh == null:
		print("join: no Roots / Butt to measure")
		return
	var top := -INF
	for si in range(roots.mesh.get_surface_count()):
		for v in (roots.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			top = maxf(top, v.y)
	# The roots' rim, per bearing, from the vertices the slicer made AT the clip plane.
	var bins := 48
	var r_src := PackedFloat32Array()
	r_src.resize(bins)
	r_src.fill(0.0)
	for si in range(roots.mesh.get_surface_count()):
		for v in (roots.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.y - top) < 0.002:
				_keep(r_src, bins, v, trunk.axis_xz)
	var worst := 0.0
	var sum := 0.0
	var n := 0
	var line := ""
	for b in range(bins):
		if r_src[b] <= 0.0:
			continue
		var ang := -PI + TAU * float(b) / float(bins)
		var rb := _band_radius(band, trunk.axis_xz, ang, top, trunk.volume().cell)
		if rb <= 0.0:
			continue
		var d: float = (rb - r_src[b]) * 1000.0
		worst = maxf(worst, absf(d))
		sum += absf(d)
		n += 1
		line += " %+.0f" % d
	if n == 0:
		print("join: nothing measurable at y=%.3f" % top)
		return
	print("join at y=%.3f (the roots' rim, where the band takes over)" % top)
	print("  band minus roots, mm:" + line)
	print("  worst %.1f mm, mean %.1f mm over %d bearings" % [worst, sum / float(n), n])


## The band's rendered radius on one bearing at height `y`: the surface vertex within
## half a cell of that height whose bearing is nearest, which at this spacing is the
## wall itself.
func _band_radius(band: Node3D, axis: Vector2, ang: float, y: float, cell: float) -> float:
	var best := -1.0
	var best_d := INF
	for c in band.get_children():
		var m: Mesh = (c as MeshInstance3D).mesh
		if m == null:
			continue
		for si in range(m.get_surface_count()):
			for v in (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if absf(v.y - y) > cell * 0.5:
					continue
				var d := Vector2(v.x - axis.x, v.z - axis.y)
				var da := absf(angle_difference(atan2(d.y, d.x), ang))
				if da < best_d:
					best_d = da
					best = d.length()
	return best if best_d < TAU / 48.0 else -1.0


func _keep(out: PackedFloat32Array, bins: int, v: Vector3, axis: Vector2) -> void:
	var d := Vector2(v.x - axis.x, v.z - axis.y)
	var b := posmod(int(round((atan2(d.y, d.x) + PI) / TAU * float(bins))), bins)
	out[b] = maxf(out[b], d.length())
