class_name WoodVolume
extends RefCounted
## FILE: res://scenes/3d_action/wood_volume.gd
## ATTACHES TO: nothing — a data structure, created by its owner
## (`WoodVolume.new()`). No nodes, no gameplay, no input.
##
## THE WOOD, AS WOOD. A signed-distance VOXEL field covering the felling band at
## the foot of a tree, plus the surface-nets mesher that turns it back into
## geometry after every blow. `_d[s] < 0` is wood, `>= 0` is air, and everything
## the felling game needs to know — how deep the notch is, how much holding wood
## is left, which way the neck is weakest, whether a chunk has come loose — is
## MEASURED off this field rather than tracked alongside it.
##
## WHY THIS REPLACED PLANE-SLICING (Amendment 13): a plane cut removes a
## half-space, so no single slice can carve a concave pocket into a trunk. The
## old code worked around that by splitting the trunk into thin horizontal slabs
## and taking a convex bite out of each — which is why the carve read as
## scattered chunks and floating disks, and why every fix bred another special
## case. A voxel field has no such limit: a blow subtracts an arbitrary convex
## solid from a single continuous volume, so ONE notch deepens, the hinge is real
## wood at a real place, and a wedge that has been cut free simply falls out
## because nothing is holding it up any more.
##
## The field is only the BAND — the bottom `y_hi - y_lo` metres, where felling
## cuts land. Everything above keeps its imported mesh; the owner slices it off
## at the band top once, at build.
##
## Cost notes (this runs inside a hit-pause, at the moment of impact, so a few
## milliseconds of hitch reads as the blow landing):
##   * `carve` only touches the samples inside the blade's own bounds.
##   * Surface extraction is CACHED per cell and only re-evaluated where the
##     field changed, so remeshing walks the surface (~a thousand cells) rather
##     than the volume.

## Angular resolution of the trunk profile measured off the source mesh.
##
## Raised from 24 on 2026-07-26 along with the switch to measuring each bin at its OWN
## angle (see `_build_profile`). 24 bins against tree_01's 16-sided trunk aliased badly;
## 64 is a multiple of both 16 and 8, so it lands the same way on every facet of the
## prisms these trees are modelled as. It costs build time only.
const _PROFILE_BINS := 64
## How many horizontal directions each section's REACH is measured in — how far
## the wood at that height sticks out that way, from the trunk axis. Callers need
## it exactly (not inferred from the second moments): it is both the extreme
## fibre a bending calculation divides by and, for the felling game, the test for
## whether the trunk overhangs the stump underneath it. An estimate is fine for
## one shape and wrong for another, and comparing two different shapes is the
## entire question.
const SUPPORT_DIRS := 16
## Sample-to-surface fill weight is clamped over one cell, so a chop moves the
## measured section smoothly instead of in whole-voxel steps.
const _NEIGHBOURS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## `remove_floating`'s mark for a sample proven to be holding itself up.
const _HELD := -2
## Which chunks of the band's geometry have changed since the owner last surfaced them.
var _dirty_chunks := PackedByteArray()

## Grid geometry — read-only for the owner.
var cell := 0.06                ## sample spacing (m)
var nx := 0
var ny := 0
var nz := 0
var origin := Vector3.ZERO      ## local position of sample (0,0,0)
var axis_xz := Vector2.ZERO     ## trunk centre line in the ground plane (local)

## Texture placeholders (Directive 3 — the owner overrides them).
var bark_uv := Vector2(2.0, 0.6)   ## repeats around the trunk, repeats per metre
## ...and where u = 0 and v = 0 sit. MEASURED off the source mesh at build
## (`_fit_bark_uv`), so the band's bark is not merely the same SIZE as the crown's but
## starts in the same place. Without it the pattern restarts at the join, which reads
## as a line right round the trunk.
var bark_uv_offset := Vector2.ZERO
## True once `_fit_bark_uv` has measured the two above off the source mesh. False means
## the source carries no usable trunk UVs and the owner should supply its own scale.
var bark_uv_fitted := false
var cut_uv := 3.0                  ## repeats per metre on a cut face

## THE RIM INSET: how far the band's RENDERED surface is pulled in toward the trunk
## axis near an imported piece, so that piece's mesh laps cleanly over it.
##
## This is geometry the eye sees, NOT the field — `_d` is untouched, so `level_stats`,
## the holding wood and the whole load model measure the wood that is really there. It
## exists because the two surfaces can never agree exactly: the crown and the roots are
## imported mesh and the band is surface-netted off a voxel field, so the band's radius
## lands within about a quarter of a cell of theirs and lands on EITHER side of it around
## the ring. Pulling the band in over the lap means the imported piece wins there.
##
## IT ONLY CHOOSES WHICH RIM YOU SEE, and that is the honest limit of it. Whichever
## surface is outermost AT the hand-over shows its own cut rim, and surface nets is a DUAL
## method — its vertices sit inside cells — so the band cannot be made to pass through the
## imported mesh's rim by construction. Five arrangements were measured on 2026-07-30 and
## every one traded one visible edge for another; see the log before trying a sixth. The
## remaining line is structural and wants the hybrid removing, not another ramp.
##
## Zero (the default) disables it. The owner sets all five.
var rim_inset := 0.0     ## how far in, at rim_hi and above (m)
var rim_lo := INF        ## no inset at or below this height (m, local)
var rim_hi := INF        ## ...ramping to the full inset by here
## ...and the same at the BOTTOM, where the tree's authored root flare laps UP over the
## band's lower rim. Full inset at or below `rim_base_lo`, none at or above `rim_base_hi`.
var rim_base_lo := -INF
var rim_base_hi := -INF
## RINGS. When `ring_radius` > 0 the cut faces are mapped as END GRAIN: the trunk's
## cross-section is projected straight onto the texture, centred on the trunk's own axis
## and scaled so `ring_radius` lands at `ring_fit` of the way out — so a growth-ring
## texture reads as one log round, centred where the tree's centre actually is, with its
## bark ring at the bark. That is what an axe exposes when it cuts ACROSS a trunk, and it
## is why the cut faces cannot use a tiling projection: the ring texture is a single disc
## on a white field, and tiling it three to the metre gives a grid of little discs.
##
## The projection is horizontal for every cut face regardless of its tilt. A felling cut
## is a near-horizontal cut — the manual's notch runs 16 to 45 degrees — so it is end
## grain, foreshortened by its own slope, which is exactly what it should look like.
## ...BUT ONLY FOR THE FACES THAT ARE ACTUALLY CROSS-CUT, and that distinction is the
## whole of the 2026-07-30 fix. A ring projection is a projection onto the HORIZONTAL
## plane, so it is right for the roof and floor of a notch (which is what "we would see
## rings if this is how we were really cutting it" meant) and catastrophic for the wall
## at the back of a kerf, which is very nearly VERTICAL: a vertical surface projected
## onto a horizontal plane has almost no UV variation up its height, so one row of texels
## is smeared the full height of the wall. On the shipping ring texture — a single log
## round on a WHITE field with `texture_repeat` off — the row it smears is the pale
## surround, which is why every chop wore a bright, streaky ribbon right across the trunk.
##
## `side_mat` is the material for cut faces that run ALONG the grain: the near-vertical
## walls a chop leaves in the side of a trunk. They get the ordinary axis-aligned planar
## mapping in metres (the `cut_uv` path below, which was written for exactly this and has
## been dead for trees ever since `ring_radius` was introduced), so nothing is stretched
## and the wood reads as long grain — which is what a cut down the length of a trunk
## exposes. It is the same reasoning that already gives SPLINTERS their own long-grain
## material rather than rings.
##
## Null leaves every cut face on the ring path, which is what a bare test cylinder wants.
var side_mat: Material = null
## THE ROOT FLARE'S BARK, which cannot use the trunk's wrap. The band's bark is a
## CYLINDRICAL mapping — u from the bearing round the trunk axis, v from height — and that
## is exact on a stem and degenerate on a buttress: a root spreading away from the axis
## swings through a huge range of bearings while its height barely changes, so the wrap
## collapses into contour banding. `root_mat` is a TRIPLANAR bark material for the surface
## below `root_below`, which has no such failure because it does not care about the axis at
## all. Null routes everything to the ordinary wrap.
var root_mat: Material = null
var root_below := -INF
## How far a cut face's normal has to tip away from horizontal before it counts as a
## cross-cut and takes the rings. 0.5 is 30 degrees of tilt off the horizontal plane —
## comfortably below the manual's own notch angles (16 to 45 degrees from horizontal put
## a face's normal 45 to 74 degrees UP) and comfortably above a kerf wall, whose normal is
## horizontal.
const _END_GRAIN_TILT := 0.5
## How far a BARK quad's normal may tip away from horizontal-facing before the trunk's
## cylindrical wrap is abandoned for triplanar. Same threshold and same reasoning as
## `_END_GRAIN_TILT`: past 30 degrees of tilt a wrap that takes v from height is smearing.
const _BARK_TRIPLANAR_TILT := 0.5
var ring_radius := 0.0
## ...and the same thing fitted PER LEVEL, indexed by `level_of`. Set by the owner from the
## UNCUT wood at build. Empty falls back to `ring_radius`, which is what every caller that
## does not carve a root flare gets. See `ring_at` and `TreeTrunk`'s note where it is filled.
var ring_prof := PackedFloat32Array()
var ring_fit := 0.48               ## where the trunk's bark sits in the texture, 0..0.5
## The widest wood in the band, measured off the profile at build. Read-only for the
## owner, which fits `ring_radius` to it — see `_build_profile`.
var profile_max_radius := 0.0

var _d := PackedFloat32Array()     ## the field: < 0 inside the wood
var _cut := PackedByteArray()      ## 1 once a blow turned this sample from wood to air
## Source-mesh UV per (level, bin), alive only during build — `_fit_bark_uv` reads the
## mapping's scale and phase off it and it is dropped.
var _uv_tab := PackedVector2Array()
## Scratch for `_edge_cross`, a member so it can actually be written to (see there).
var _cross_buf := PackedFloat32Array()

# The measured sections, and which of them are stale. `_lv_hi < _lv_lo` means every
# level is up to date. See `level_stats`.
var _lv: Array[Dictionary] = []
var _lv_lo := 0
var _lv_hi := -1
## cos/sin of the SUPPORT_DIRS reach directions, interleaved. Built once — it was being
## rebuilt on every measurement.
var _trig := PackedFloat32Array()

# The grid box the last carve actually changed. `remove_floating` only has to look
# next to this: wood cannot come loose anywhere else, because nothing else moved.
var _cut_lo := Vector3i.ZERO
var _cut_hi := Vector3i(-1, -1, -1)   # hi < lo means "nothing has been carved"

# Cached surface (one dual vertex per straddling cell), indexed exactly like the
# samples so one index scheme serves both. Cells are valid for i<nx-1 etc.
var _cell_on := PackedByteArray()
var _cell_v := PackedVector3Array()
var _cell_n := PackedVector3Array()
## The source mesh's bark UV at each cell's vertex, sampled when the cell is evaluated
## rather than when it is meshed — see `_bark_vertex`.
var _cell_uv := PackedVector2Array()
## ...and the vertex's angle round the trunk, cached for the same reason: `_quad` asks
## for it on all four corners of every bark quad, so it was running a couple of thousand
## atan2 calls per remesh to answer a question about the texture seam.
var _cell_ang := PackedFloat32Array()
var _active := PackedInt32Array()

# Scratch for _emit, kept between remeshes (see the note there).
var _slot_bark := PackedInt32Array()
var _slot_seam := PackedInt32Array()
var _slot_cut := PackedInt32Array()
## ...and the long-grain cut faces, which are their own surface because they wear their
## own material. A cell on the corner between a notch's floor and its back wall genuinely
## belongs to both and gets a vertex in each, which is correct: the two faces meet at a
## hard edge in the wood and should meet at a hard edge in the texture.
var _slot_side := PackedInt32Array()
## ...and the root flare's bark, which is its own surface for its own material.
var _slot_root := PackedInt32Array()


# ------------------------------------------------------------------- build
## Fill the band from `mesh`, between local heights `y_lo` and `y_hi`. The trunk
## shape is taken from the mesh itself as a radial profile per level, so taper
## and root flare survive; anything wider than `max_radius` (a branch crossing
## the band) is clamped back to the trunk rather than modelled, which is exactly
## what the old slicer needed a whole branch-dodging search to avoid.
##
## `surfaces` names the mesh surfaces that ARE the trunk; empty means "all of them",
## which is what a bare test cylinder wants. NOT optional for real art: the generator
## hangs leaf cards down past the stem and grows roots out of the butt, and both are
## geometry a ray cast round the trunk will happily land on. A leaf card measured as
## bark drags the band's radius out and — worse — feeds the leaf atlas's UVs into the
## bark fit, which is torn bark. See `_build_profile`.
## `mesh_below` is the local height under which the field is taken FROM THE MESH ITSELF
## rather than from the radial profile — the root flare, which a radial field cannot
## represent at all (one radius per angle cannot describe a buttress you can see daylight
## under, which is why the roots used to be a separate imported piece and why that piece's
## cut rim was the seam round the butt of every tree). Zero keeps the whole band radial.
##
## SPLICING TWO FILL METHODS INSIDE ONE FIELD CREATES NO SEAM. That is the whole point:
## the surface is generated from one continuous field by one mesher, so there is no rim
## anywhere. The seam only ever came from two separate MESHES handing over.
func build(mesh: Mesh, y_lo: float, y_hi: float, axis: Vector2, max_radius: float,
		cell_size: float, surfaces := PackedInt32Array(), mesh_below := 0.0) -> bool:
	if mesh == null or y_hi <= y_lo or max_radius <= 0.0:
		return false
	cell = maxf(cell_size, 0.015)
	axis_xz = axis
	var half := max_radius + cell * 2.0
	nx = int(ceil(half * 2.0 / cell)) + 1
	nz = nx
	ny = int(ceil((y_hi - y_lo) / cell)) + 1
	if nx < 5 or ny < 5:
		return false
	origin = Vector3(axis.x - float(nx - 1) * cell * 0.5, y_lo,
		axis.y - float(nz - 1) * cell * 0.5)

	var prof := _build_profile(mesh, max_radius, surfaces, mesh_below)
	var total := nx * ny * nz
	_d.resize(total)
	_cut.resize(total)
	_cut.fill(0)
	var plane := nx * ny
	for k in range(nz):
		var z := origin.z + float(k) * cell - axis.y
		for i in range(nx):
			var x := origin.x + float(i) * cell - axis.x
			var r := sqrt(x * x + z * z)
			var ang := atan2(z, x)
			var base := i + plane * k
			for j in range(ny):
				_d[base + nx * j] = r - _profile_at(prof, j, ang)
	if mesh_below > y_lo:
		_fill_from_mesh(mesh, surfaces, mesh_below)
	_lv.clear()   # a fresh field: every section wants measuring
	_refresh_all()
	return true


## THE ROOT FLARE, TAKEN FROM THE MESH. Overwrites the radial fill below `y_top` with a
## signed distance measured against the trunk's own triangles, so buttresses — and the
## daylight under them — survive into the voxels instead of being flattened into a skirt.
##
## THREE AXIS SWEEPS, because one is not enough for either half of the answer. A line
## through the grid is intersected with the mesh; the crossings along it give both the
## SIGN (how many surfaces are still ahead of this sample: odd means inside) and a
## DISTANCE (to the nearest crossing on that line). Sweeping only up the Y axis gets an
## arch right but leaves the SIDES of a buttress stair-stepped, because a vertical line
## says nothing useful about how far away a vertical wall is. Taking the smallest distance
## of the three, and the majority vote of the three signs, gives a usable field and is
## robust to the small holes generated art always has.
##
## Bucketed by grid footprint first. Testing every line against every triangle is
## 1600 x 1000 ray casts and would take seconds per tree in GDScript; each line only needs
## the triangles whose own footprint covers it, which is a couple of dozen.
func _fill_from_mesh(mesh: Mesh, surfaces: PackedInt32Array, y_top: float) -> void:
	var j_top := mini(int(ceil((y_top - origin.y) / cell)), ny - 1)
	if j_top < 1:
		return
	# ---- the triangles that reach into the slab, flattened for cheap indexing.
	var tri := PackedVector3Array()
	for si in range(mesh.get_surface_count()):
		if surfaces.size() > 0 and not surfaces.has(si):
			continue
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			if minf(a.y, minf(b.y, c.y)) > y_top + cell:
				continue
			tri.append(a)
			tri.append(b)
			tri.append(c)
	if tri.size() < 3:
		return

	# ---- the three sweeps. Each writes a signed distance and a vote into scratch.
	var n := nx * ny * nz
	var dist := PackedFloat32Array()
	var votes := PackedByteArray()
	dist.resize(n)
	dist.fill(INF)
	votes.resize(n)
	votes.fill(0)
	_sweep(tri, j_top, dist, votes, 1)   # +Y, the one that finds the arches
	_sweep(tri, j_top, dist, votes, 0)   # +X
	_sweep(tri, j_top, dist, votes, 2)   # +Z

	# ---- and the result, over the radial fill.
	var plane := nx * ny
	for k in range(nz):
		for i in range(nx):
			for j in range(j_top + 1):
				var s := i + nx * j + plane * k
				if is_inf(dist[s]):
					continue          # no line reached it: leave the radial answer
				# Two of three axes agreeing is the vote. A single axis can be fooled by
				# a hole in the mesh or by a line that grazes an edge; two cannot easily.
				var inside := votes[s] >= 2
				_d[s] = -dist[s] if inside else dist[s]


## Trunk radius, and the source mesh's bark UV, per level per angular bin.
##
## MEASURED AT EACH BIN'S OWN ANGLE, by assembling every level's cross-section as real
## segments and casting one ray per bin. That is the fix for the band being visibly
## WIDER than the crown at the join (2026-07-26).
##
## The old version binned every edge CROSSING by whatever angle it happened to land at
## and kept the widest in each bin. These trees are modelled as prisms — tree_01's trunk
## has a 16-sided cross-section — and 24 bins do not divide 16, so some bins caught a
## facet CORNER and some only a facet FLAT. The band's radius wobbled by up to 14 mm
## against the crown's, in both directions round the ring, on a 471 mm trunk. Where it
## came out wider the band poked out through the crown's bark and the crown's clip plane
## read as a hard ledge with the band's ragged top row of cells showing below it: the
## seam Sam reported as the voxel and non-voxel parts looking disconnected.
##
## Casting a ray at exactly the angle `_profile_at` will read the bin back at removes
## the aliasing entirely — the profile is now the trunk's true silhouette sampled at
## known angles rather than a histogram of whatever the tessellation offered.
##
## The same pass carries the source's UVs down to the hit points. They are not used as
## geometry; `_fit_bark_uv` reads the mapping's SCALE and PHASE off them so the band's
## bark comes out the same size as the crown's and starts in the same place.
##
## ONLY THE DECLARED TRUNK SURFACES ARE MEASURED (2026-07-29). This used to read every
## surface in the mesh, which was fine for as long as a tree's non-trunk geometry stayed
## clear of the band. The current generator's trees do not: leaf cards droop to 1.1 m and
## roots arch out of the butt, both crossing the band's levels, and the FARTHEST-hit rule
## below picks them in preference to the stem every time. The band came out as wide as the
## foliage (then clamped flat by `_PROFILE_CLAMP`, which is the root flare vanishing), and
## the UVs carried down to `_fit_bark_uv` were the LEAF ATLAS's, which is why the bottom of
## every trunk wore a smeared, torn texture that bore no relation to its bark.
## `skip_below` drops every level under it from the measurement — the ROOT FLARE, when the
## flare is being filled from the mesh instead. Both halves of what this function produces
## are meaningless down there and one of them is actively harmful: the radius is overwritten
## by `_fill_from_mesh`, and the UVs belong to the artist's ROOT ISLAND, which has nothing to
## do with the trunk's cylindrical wrap. Feeding those into the bark fit is what put a band
## of torn, contour-striped bark round the flare the moment the band was extended to the
## ground — the same failure, from the same cause, as the leaf cards on 2026-07-29.
func _build_profile(mesh: Mesh, max_radius: float,
		surfaces := PackedInt32Array(), skip_below := 0.0) -> PackedFloat32Array:
	# Every level's cross-section, as segments: 8 floats each — x0,z0,u0,v0,x1,z1,u1,v1.
	# A triangle crossing a level contributes exactly one, which is what makes this a
	# real polygon to cast against rather than a scatter of points.
	var segs: Array = []
	segs.resize(ny)
	for j in range(ny):
		segs[j] = PackedFloat32Array()
	for si in range(mesh.get_surface_count()):
		if surfaces.size() > 0 and not surfaces.has(si):
			continue
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var uvs := PackedVector2Array()
		if raw_uv is PackedVector2Array and (raw_uv as PackedVector2Array).size() == verts.size():
			uvs = raw_uv
		var has_uv := uvs.size() > 0
		var idx := triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var ia := idx[t]
			var ib := idx[t + 1]
			var ic := idx[t + 2]
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var lo := minf(a.y, minf(b.y, c.y))
			var hi := maxf(a.y, maxf(b.y, c.y))
			var j0 := maxi(int(ceil((lo - origin.y) / cell)), 0)
			var j1 := mini(int(floor((hi - origin.y) / cell)), ny - 1)
			if j1 < j0:
				continue
			var ua := uvs[ia] if has_uv else Vector2.ZERO
			var ub := uvs[ib] if has_uv else Vector2.ZERO
			var uc := uvs[ic] if has_uv else Vector2.ZERO
			for j in range(j0, j1 + 1):
				var y := origin.y + float(j) * cell
				_cross_buf.clear()
				_edge_cross(y, a, b, ua, ub)
				_edge_cross(y, b, c, ub, uc)
				_edge_cross(y, c, a, uc, ua)
				# Exactly two crossings is a triangle genuinely cut by the level. Zero,
				# or the three a sliver lying in the plane can produce, is not a segment.
				if _cross_buf.size() != 8:
					continue
				# READ, APPEND, WRITE BACK. A PackedFloat32Array inside an Array is a
				# VALUE: `segs[j]` hands back a copy, so appending to it in place writes
				# into a temporary and the segment is silently lost. That emptied every
				# level's cross-section, the profile fell through to its last-resort
				# `max_radius * 0.5`, and the whole trunk came out as a 0.27 m pole.
				var row: PackedFloat32Array = segs[j]
				row.append_array(_cross_buf)
				segs[j] = row

	var prof := PackedFloat32Array()
	prof.resize(ny * _PROFILE_BINS)
	prof.fill(-1.0)
	_uv_tab.resize(ny * _PROFILE_BINS)
	var got := PackedByteArray()
	got.resize(ny * _PROFILE_BINS)
	got.fill(0)
	var j_skip := int(ceil((skip_below - origin.y) / cell)) if skip_below > origin.y else 0
	for j in range(ny):
		if j < j_skip:
			continue          # the flare: measured from the mesh, and its UVs are not bark
		var s: PackedFloat32Array = segs[j]
		if s.is_empty():
			continue
		for bn in range(_PROFILE_BINS):
			# The angle `_profile_at` reads bin `bn` back at — they have to agree, or
			# the whole point of sampling at a known angle is lost.
			var ang := -PI + TAU * float(bn) / float(_PROFILE_BINS)
			var dx := cos(ang)
			var dz := sin(ang)
			var best := -1.0
			var best_uv := Vector2.ZERO
			for k in range(0, s.size(), 8):
				var wx := s[k] - axis_xz.x
				var wz := s[k + 1] - axis_xz.y
				var ex := s[k + 4] - s[k]
				var ez := s[k + 5] - s[k + 1]
				var den := dx * ez - dz * ex
				if absf(den) < 1e-12:
					continue          # the segment runs along the ray
				var tt := (wx * dz - wz * dx) / den
				if tt < -0.001 or tt > 1.001:
					continue          # the ray misses this segment
				var ss := (wx * ez - wz * ex) / den
				if ss <= best:
					continue
				# The FARTHEST hit, so a hollow or a branch stub crossing the level
				# cannot report the trunk as thinner than it is. Same rule the binned
				# version used when it kept the widest crossing.
				best = ss
				best_uv = Vector2(lerpf(s[k + 2], s[k + 6], tt), lerpf(s[k + 3], s[k + 7], tt))
			if best > 0.0:
				var pi_ := j * _PROFILE_BINS + bn
				prof[pi_] = minf(best, max_radius)
				_uv_tab[pi_] = best_uv
				got[pi_] = 1
	_fill_profile_gaps(prof, got, max_radius)
	# The widest wood the band actually holds. `ring_radius` is fitted to THIS, not to the
	# trunk's representative radius: a trunk tapers, so the butt is always wider than the
	# median, and the end-grain round is a single disc on a white field with texture_repeat
	# off — anything mapped past its edge clamps to that white. A notch is a bite at the
	# PERIMETER, so mapping to the median painted almost every fresh cut face solid white.
	profile_max_radius = 0.0
	for r in prof:
		profile_max_radius = maxf(profile_max_radius, r)
	bark_uv_fitted = _fit_bark_uv(got)
	if bark_uv_fitted:
		_finish_uv_table(got)
	else:
		_uv_tab.clear()
	return prof


## Append (x, z, u, v) to `_cross_buf` where edge a-b crosses height `y`, or nothing if
## it does not. Writes to the MEMBER rather than to a parameter on purpose: a packed
## array handed to a function is a value, and appending to the parameter would mutate a
## copy the caller never sees.
func _edge_cross(y: float, a: Vector3, b: Vector3, ua: Vector2, ub: Vector2) -> void:
	var da := a.y - y
	var db := b.y - y
	if (da >= 0.0) == (db >= 0.0):
		return
	var t := da / (da - db)
	var p := a.lerp(b, t)
	var uv := ua.lerp(ub, t)
	_cross_buf.append(p.x)
	_cross_buf.append(p.z)
	_cross_buf.append(uv.x)
	_cross_buf.append(uv.y)


## A level the mesh gave nothing for (or a bin no segment covered) still has to hold
## wood — a hole in the profile would read as a hole in the trunk. Empty bins take the
## nearest measured bin around the ring; a wholly empty level takes the nearest
## measured level. `got` is updated so the UV fit only ever reads real measurements.
func _fill_profile_gaps(prof: PackedFloat32Array, got: PackedByteArray,
		max_radius: float) -> void:
	var filled := PackedByteArray()
	filled.resize(ny)
	for j in range(ny):
		var any := -1
		for b in range(_PROFILE_BINS):
			if prof[j * _PROFILE_BINS + b] > 0.0:
				any = b
				break
		filled[j] = 1 if any >= 0 else 0
		if any < 0:
			continue
		for b in range(_PROFILE_BINS):
			if prof[j * _PROFILE_BINS + b] > 0.0:
				continue
			for step in range(1, _PROFILE_BINS):
				var lo: float = prof[j * _PROFILE_BINS + posmod(b - step, _PROFILE_BINS)]
				var hi: float = prof[j * _PROFILE_BINS + posmod(b + step, _PROFILE_BINS)]
				if lo > 0.0 or hi > 0.0:
					prof[j * _PROFILE_BINS + b] = maxf(lo, hi)
					break
	for j in range(ny):
		if filled[j] != 0:
			continue
		var src := -1
		for step in range(1, ny):
			if j - step >= 0 and filled[j - step] != 0:
				src = j - step
				break
			if j + step < ny and filled[j + step] != 0:
				src = j + step
				break
		for b in range(_PROFILE_BINS):
			prof[j * _PROFILE_BINS + b] = \
				prof[src * _PROFILE_BINS + b] if src >= 0 else max_radius * 0.5


## THE BAND'S BARK, AT THE CROWN'S SIZE AND IN THE CROWN'S PLACE.
##
## The band cannot inherit the crown's UVs vertex for vertex: its geometry is
## regenerated from a voxel field after every blow and has no correspondence to the
## imported mesh's vertices at all. What it CAN wear is a cylindrical wrap at the scale
## and phase the artist actually mapped this trunk at, and that is measurable — it is
## the mapping's own derivatives, read straight off `_uv_tab`.
##
## Fitted from DIFFERENCES rather than absolute values, and by MEDIAN rather than mean,
## for one reason: u wraps somewhere round the ring and v may tile up the trunk, so one
## sample in each row is a whole period out. A median over 64 bins is untroubled by one
## outlier; an average is not.
##
## This replaces matching a single isotropic texel density (TreeTrunk._bark_density).
## A density is only right when the artist's mapping is isotropic, and a trunk's rarely
## is — tree_01's is stretched, so the band's bark came out visibly coarser than the
## crown's AND started somewhere else. That was the loudest half of the seam.
func _fit_bark_uv(got: PackedByteArray) -> bool:
	var du: Array[float] = []
	var dv: Array[float] = []
	for j in range(ny):
		for b in range(_PROFILE_BINS):
			var s := j * _PROFILE_BINS + b
			if got[s] == 0:
				continue
			var nb := s - b + posmod(b + 1, _PROFILE_BINS)
			if got[nb] != 0:
				du.append(_uv_tab[nb].x - _uv_tab[s].x)
			if j + 1 < ny and got[s + _PROFILE_BINS] != 0:
				dv.append(_uv_tab[s + _PROFILE_BINS].y - _uv_tab[s].y)
	if du.size() < _PROFILE_BINS or dv.size() < _PROFILE_BINS:
		return false
	du.sort()
	dv.sort()
	var around: float = du[du.size() / 2] * float(_PROFILE_BINS)   # u per turn
	var per_m: float = dv[dv.size() / 2] / cell                    # v per metre
	# A trunk mapped as a strip, or mirrored, gives a median step of ~0 and there is
	# nothing sensible to fit. Say so rather than collapse the texture to a smear.
	if absf(around) < 0.05 or absf(per_m) < 0.05:
		return false
	# Phase from a single measured sample. The mapping is linear, so one point fixes
	# it, and picking one sample sidesteps the wrap that averaging would trip over.
	for j in range(ny - 1, -1, -1):
		for b in range(_PROFILE_BINS):
			var s := j * _PROFILE_BINS + b
			if got[s] == 0:
				continue
			var ang := -PI + TAU * float(b) / float(_PROFILE_BINS)
			var y := origin.y + float(j) * cell
			bark_uv = Vector2(around, per_m)
			bark_uv_offset = Vector2(_uv_tab[s].x - ang / TAU * around,
				_uv_tab[s].y - y * per_m)
			return true
	return false


## Turn the measured samples into a table the band can READ ITS UVs OUT OF, rather than
## a linear approximation of them.
##
## The linear fit above gets the bark's SIZE right, which was the loud half of the seam.
## It cannot get the phase right everywhere, because these trunks are prisms and the
## artist unwrapped them facet by facet: u is piecewise linear with a kink at every
## edge, so a single straight line drifts about a tenth of a texture repeat across the
## ring and the bark still visibly fails to line up at the join. Reading the source's
## own u and v back per (level, bin) reproduces the kinks exactly.
##
## Two things have to be repaired first. Bins the ray missed have no measurement, and
## take the linear model. And u JUMPS by one full turn somewhere round every level — a
## cylindrical unwrap duplicates its seam vertices with u values a period apart, and
## which copy a given bin's ray lands on is arbitrary — so each level is unwrapped into
## a monotone run, which is what makes interpolating between adjacent bins meaningful.
func _finish_uv_table(got: PackedByteArray) -> void:
	var turn := bark_uv.x
	if absf(turn) < 0.0001:
		_uv_tab.clear()
		return
	var step := turn / float(_PROFILE_BINS)
	for j in range(ny):
		var y := origin.y + float(j) * cell
		var base := j * _PROFILE_BINS
		# Anything unmeasured falls back to the fitted line, so every bin has a value.
		for b in range(_PROFILE_BINS):
			if got[base + b] == 0:
				var ang := -PI + TAU * float(b) / float(_PROFILE_BINS)
				_uv_tab[base + b] = Vector2(ang / TAU * turn + bark_uv_offset.x,
					y * bark_uv.y + bark_uv_offset.y)
		# ...then unwrap u so it advances by about `step` per bin all the way round,
		# instead of falling off a period at the seam.
		for b in range(1, _PROFILE_BINS):
			var want: float = _uv_tab[base + b - 1].x + step
			var uv: Vector2 = _uv_tab[base + b]
			uv.x -= round((uv.x - want) / turn) * turn
			_uv_tab[base + b] = uv


## The source mesh's bark UV at a point on the trunk's surface, bilinear between the
## four table entries around it. Falls back to the fitted straight line when there is no
## table (a source with no usable trunk UVs, or an owner-supplied tiling override).
func _bark_uv_at(y: float, ang: float) -> Vector2:
	if _uv_tab.is_empty():
		return Vector2(ang / TAU * bark_uv.x + bark_uv_offset.x,
			y * bark_uv.y + bark_uv_offset.y)
	var fj := clampf((y - origin.y) / cell, 0.0, float(ny - 1))
	var j0 := int(floor(fj))
	var j1 := mini(j0 + 1, ny - 1)
	var tj := fj - float(j0)
	var fb := (ang + PI) / TAU * float(_PROFILE_BINS)
	var b0 := int(floor(fb))
	var tb := fb - float(b0)
	var w0 := posmod(b0, _PROFILE_BINS)
	var w1 := posmod(b0 + 1, _PROFILE_BINS)
	# Stepping off the end of a level's monotone run and back to its start is one whole
	# turn round the trunk, so u has to gain a turn with it.
	var wrap := bark_uv.x if w1 < w0 else 0.0
	var a0: Vector2 = _uv_tab[j0 * _PROFILE_BINS + w0]
	var a1: Vector2 = _uv_tab[j0 * _PROFILE_BINS + w1] + Vector2(wrap, 0.0)
	var b0v: Vector2 = _uv_tab[j1 * _PROFILE_BINS + w0]
	var b1v: Vector2 = _uv_tab[j1 * _PROFILE_BINS + w1] + Vector2(wrap, 0.0)
	return a0.lerp(a1, tb).lerp(b0v.lerp(b1v, tb), tj)


## Stop reading bark UVs off the source mesh and use `bark_uv`/`bark_uv_offset` as a
## plain cylindrical wrap. For an owner that has supplied its own tiling — which has no
## reason to line up with the crown's — the measured table would fight it.
func drop_bark_uv_table() -> void:
	_uv_tab.clear()


## The band's bark UV at a point on the trunk's surface. Test/dev seam: it is the only
## way to check the fitted mapping against the source mesh's own without a render, and
## a mapping that is merely the right SIZE has already shipped twice looking wrong.
func debug_bark_uv_at(y: float, ang: float) -> Vector2:
	return _bark_uv_at(y, ang)


func _profile_at(prof: PackedFloat32Array, j: int, ang: float) -> float:
	var f := (ang + PI) / TAU * float(_PROFILE_BINS)
	var b0 := int(floor(f))
	var t := f - float(b0)
	b0 = posmod(b0, _PROFILE_BINS)
	var b1 := posmod(b0 + 1, _PROFILE_BINS)
	return lerpf(prof[j * _PROFILE_BINS + b0], prof[j * _PROFILE_BINS + b1], t)


static func triangle_indices(arr: Array, vert_count: int) -> PackedInt32Array:
	var raw: Variant = arr[Mesh.ARRAY_INDEX]
	if raw is PackedInt32Array and (raw as PackedInt32Array).size() > 0:
		return raw
	var out := PackedInt32Array()
	out.resize(vert_count)
	for k in range(vert_count):
		out[k] = k
	return out


# -------------------------------------------------------------------- carve
## Subtract the convex solid `{p : every plane.distance_to(p) <= 0}` from the
## wood. `bounds` must contain that solid — it is the only part of the grid
## scanned, which is what keeps a blow cheap.
##
## Returns { "volume": m³ actually taken, "chip": ArrayMesh|null (the wood that
## came away, in local space), "centre": its local centre }. The chip is the
## REAL removed geometry, not a stand-in: what flies past the camera is exactly
## the wood that left the hole.
func carve(planes: Array[Plane], bounds: AABB, chip_mat: Material) -> Dictionary:
	var out := {"volume": 0.0, "chip": null, "centre": Vector3.ZERO}
	if planes.is_empty() or _d.is_empty():
		return out
	var i0 := maxi(int(floor((bounds.position.x - origin.x) / cell)) - 1, 0)
	var j0 := maxi(int(floor((bounds.position.y - origin.y) / cell)) - 1, 0)
	var k0 := maxi(int(floor((bounds.position.z - origin.z) / cell)) - 1, 0)
	var i1 := mini(int(ceil((bounds.end.x - origin.x) / cell)) + 1, nx - 1)
	var j1 := mini(int(ceil((bounds.end.y - origin.y) / cell)) + 1, ny - 1)
	var k1 := mini(int(ceil((bounds.end.z - origin.z) / cell)) + 1, nz - 1)
	if i0 > i1 or j0 > j1 or k0 > k1:
		return out

	var bx := i1 - i0 + 1
	var by := j1 - j0 + 1
	var bz := k1 - k0 + 1
	var chunk := PackedFloat32Array()   # the wood that came away: old solid AND region
	chunk.resize(bx * by * bz)
	var taken := 0
	var centre := Vector3.ZERO
	var plane_stride := nx * ny
	# The bounds the caller gives are deliberately generous — bounding a wedge
	# tightly is more trouble than scanning a few hundred extra samples. What
	# actually CHANGED is usually a small part of that, and everything after this
	# loop (the chip mesh, the surface refresh) only needs to look at that part.
	var ci0 := nx
	var cj0 := ny
	var ck0 := nz
	var ci1 := -1
	var cj1 := -1
	var ck1 := -1
	for k in range(k0, k1 + 1):
		var z := origin.z + float(k) * cell
		for j in range(j0, j1 + 1):
			var y := origin.y + float(j) * cell
			for i in range(i0, i1 + 1):
				var p := Vector3(origin.x + float(i) * cell, y, z)
				var rd := -INF
				for pl: Plane in planes:
					rd = maxf(rd, pl.distance_to(p))
				var s := i + nx * j + plane_stride * k
				var old: float = _d[s]
				var b := (i - i0) + bx * (j - j0) + bx * by * (k - k0)
				chunk[b] = maxf(old, rd)     # solid ∩ region
				var nd := maxf(old, -rd)     # solid \ region
				if nd > old:
					_d[s] = nd
					ci0 = mini(ci0, i); cj0 = mini(cj0, j); ck0 = mini(ck0, k)
					ci1 = maxi(ci1, i); cj1 = maxi(cj1, j); ck1 = maxi(ck1, k)
					# Wood only counts as REMOVED when it actually stops being
					# wood. A sample can be pushed nearer the surface without
					# crossing it, and counting those would have the game report
					# more timber taken than the tree ever lost.
					if old < 0.0 and nd >= 0.0:
						_cut[s] = 1
						taken += 1
						centre += p
	if taken == 0:
		return out
	out.volume = float(taken) * cell * cell * cell
	out.centre = centre / float(taken)
	_cut_lo = Vector3i(ci0, cj0, ck0)
	_cut_hi = Vector3i(ci1, cj1, ck1)
	# A section is measured from the samples at its own level and nowhere else, so
	# exactly the levels this carve wrote are the ones that need remeasuring.
	_dirty_levels(cj0, cj1)
	if chip_mat != null:
		# Copy the changed corner of the chunk out and mesh only that.
		var si0 := maxi(ci0 - 1, i0)
		var sj0 := maxi(cj0 - 1, j0)
		var sk0 := maxi(ck0 - 1, k0)
		var si1 := mini(ci1 + 1, i1)
		var sj1 := mini(cj1 + 1, j1)
		var sk1 := mini(ck1 + 1, k1)
		var sx := si1 - si0 + 1
		var sy := sj1 - sj0 + 1
		var sz := sk1 - sk0 + 1
		var sub := PackedFloat32Array()
		sub.resize(sx * sy * sz)
		for k in range(sz):
			for j in range(sy):
				for i in range(sx):
					sub[i + sx * j + sx * sy * k] = chunk[
						(si0 - i0 + i) + bx * (sj0 - j0 + j) + bx * by * (sk0 - k0 + k)]
		out.chip = _block_surface(sub, si0, sj0, sk0, sx, sy, sz, chip_mat)
	_refresh_region(ci0 - 1, cj0 - 1, ck0 - 1, ci1, cj1, ck1)
	_rebuild_active()
	return out


## Wood that nothing is holding up any more falls off. Every solid island that
## does not reach the ground (the bottom of the band) and is not the standing
## tree above (the top of the band) is removed from the field and handed back as
## its own mesh.
##
## This is the felling notch's payoff and it is not scripted: chop the roof of
## the notch, chop its floor, and on the blow that joins them the whole wedge
## between the two cuts stops being attached and pops out. It is also why
## "floating geometry" cannot happen here — geometry that would float, falls.
##
## Each entry: { "mesh": ArrayMesh (local space), "centre": local centre,
## "volume": m³ }.
func remove_floating(mat: Material) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _d.is_empty() or _cut_hi.x < _cut_lo.x:
		return out   # nothing has been carved, so nothing can have come loose
	var total := nx * ny * nz
	# -1 unknown, _HELD proven to be holding itself up, >= 0 the flood that claimed
	# it. The HELD mark is the important one: it persists across floods within this
	# call, so a flood that runs into it can stop there and knows the answer.
	var mark := PackedInt32Array()
	mark.resize(total)
	mark.fill(-1)

	# ONLY THE WOOD NEXT TO THE FRESH CUT CAN HAVE COME LOOSE. Everything else is
	# attached to exactly what it was attached to before the blow, so seeding from
	# the cut and asking "is this still connected to the ground?" answers the same
	# question as flooding the whole volume from the ground did, at a fraction of
	# the cost — the old version walked every solid sample in the band on every
	# blow, which was 20 ms of the ~45 ms a blow could afford, and it got worse in
	# step with the band's height.
	var next_tag := 0
	for k in range(maxi(_cut_lo.z - 1, 0), mini(_cut_hi.z + 1, nz - 1) + 1):
		for j in range(maxi(_cut_lo.y - 1, 0), mini(_cut_hi.y + 1, ny - 1) + 1):
			for i in range(maxi(_cut_lo.x - 1, 0), mini(_cut_hi.x + 1, nx - 1) + 1):
				var s := i + nx * j + nx * ny * k
				if _d[s] >= 0.0 or mark[s] != -1:
					continue
				var stack := PackedInt32Array()
				mark[s] = next_tag
				stack.append(s)
				var members := _flood_until_held(stack, mark, next_tag)
				if members.is_empty():
					continue   # held — the flood marked its trail so, see below
				var piece := _extract_island(members, mark, next_tag, mat)
				if not piece.is_empty():
					out.append(piece)
				next_tag += 1
	if not out.is_empty():
		_refresh_all()
	return out


## Flood one solid island, stopping the moment it turns out to be held up.
##
## Returns the island's members if it is NOT held — that is a piece of wood the
## player has cut free. Returns EMPTY if the flood reached the bottom of the band
## (it is standing on the ground), the top of it (it is the tree still standing above
## the cut, which the load model owns, not debris), or wood already PROVEN held by an
## earlier flood in this pass. Bailing out at that point is what makes this cheap: a
## flood seeded beside a cut in a whole trunk finds the ground within a few hundred
## steps, while a genuinely freed wedge is small and gets walked to the end.
##
## WHEN IT BAILS OUT IT MARKS ITS WHOLE TRAIL `_HELD`, and that is not bookkeeping —
## it is the correctness of the whole approach. A flood that stops early has only
## partly explored its component, and the samples it did claim would otherwise sit
## there as walls: the next seed in the same component gets fenced in by them, cannot
## reach the ground, and concludes that a piece of the standing trunk has come loose.
## That is exactly what happened — one cut handed back twenty-four fragments of a
## column that was still standing.
func _flood_until_held(stack: PackedInt32Array, mark: PackedInt32Array,
		tag: int) -> PackedInt32Array:
	var members := PackedInt32Array()
	var plane_stride := nx * ny
	var held := false
	while not stack.is_empty():
		var s := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		members.append(s)
		var k := s / plane_stride
		var rem := s % plane_stride
		var j := rem / nx
		var i := rem % nx
		if j <= 0 or j >= ny - 1:
			held = true
			break   # on the ground, or part of the standing tree
		for n: Vector3i in _NEIGHBOURS:
			var ni := i + n.x
			var nj := j + n.y
			var nk := k + n.z
			if ni < 0 or ni >= nx or nj < 0 or nj >= ny or nk < 0 or nk >= nz:
				continue
			var ns := ni + nx * nj + plane_stride * nk
			if _d[ns] >= 0.0:
				continue
			if mark[ns] == _HELD:
				held = true
				break   # touching wood already known to be standing on something
			if mark[ns] == -1:
				mark[ns] = tag
				stack.append(ns)
		if held:
			break
	if not held:
		return members
	# Everything this flood claimed is in the same component as whatever it just
	# found, so all of it is held. Members are the samples it popped; the stack is
	# the rest of what it claimed.
	for s in members:
		mark[s] = _HELD
	for s in stack:
		mark[s] = _HELD
	return PackedInt32Array()


## Cut a labelled island out of the field and mesh it. Returns {} for an island
## that touches the TOP of the band — that is the tree still standing above the
## cut, which the load model owns, not a chip.
func _extract_island(members: PackedInt32Array, label: PackedInt32Array, tag: int,
		mat: Material) -> Dictionary:
	if members.is_empty():
		return {}
	var plane_stride := nx * ny
	var i0 := nx
	var j0 := ny
	var k0 := nz
	var i1 := -1
	var j1 := -1
	var k1 := -1
	for s in members:
		var k := s / plane_stride
		var rem := s % plane_stride
		var j := rem / nx
		var i := rem % nx
		i0 = mini(i0, i); j0 = mini(j0, j); k0 = mini(k0, k)
		i1 = maxi(i1, i); j1 = maxi(j1, j); k1 = maxi(k1, k)
	if j1 >= ny - 1:
		return {}
	# Whichever way this island is taken out below, its samples stop being wood.
	_dirty_levels(j0, j1)

	var centre_only := Vector3.ZERO
	if mat == null:
		# Nobody is going to look at this piece's geometry (the game throws splinters
		# for it now), so do not surface it — just take it out of the field and report
		# where it was and how much of it there was.
		for s in members:
			var k := s / plane_stride
			var rem := s % plane_stride
			centre_only += origin + Vector3(float(rem % nx), float(rem / nx), float(k)) * cell
			_d[s] = cell
		return {
			"mesh": null,
			"centre": centre_only / float(members.size()),
			"volume": float(members.size()) * cell * cell * cell,
		}

	i0 = maxi(i0 - 1, 0); j0 = maxi(j0 - 1, 0); k0 = maxi(k0 - 1, 0)
	i1 = mini(i1 + 1, nx - 1); j1 = mini(j1 + 1, ny - 1); k1 = mini(k1 + 1, nz - 1)
	var bx := i1 - i0 + 1
	var by := j1 - j0 + 1
	var bz := k1 - k0 + 1
	var block := PackedFloat32Array()
	block.resize(bx * by * bz)
	for k in range(k0, k1 + 1):
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var s := i + nx * j + plane_stride * k
				var b := (i - i0) + bx * (j - j0) + bx * by * (k - k0)
				# Only THIS island is solid in the block; anything else in the
				# box (the trunk it broke off, another chip) reads as air, so the
				# freed piece is meshed on its own.
				block[b] = _d[s] if label[s] == tag else maxf(_d[s], cell)

	var centre := Vector3.ZERO
	for s in members:
		var k := s / plane_stride
		var rem := s % plane_stride
		centre += origin + Vector3(float(rem % nx), float(rem / nx), float(k)) * cell
		_d[s] = cell   # gone from the tree
	centre /= float(members.size())
	return {
		"mesh": _block_surface(block, i0, j0, k0, bx, by, bz, mat),
		"centre": centre,
		"volume": float(members.size()) * cell * cell * cell,
	}


# --------------------------------------------------------------- measuring
## The wood present at each level of the band, as the section properties a beam
## calculation needs: area, centroid, and the second moments about the trunk
## axis. Everything is in LOCAL metres, centroid offsets measured from the trunk
## centre line.
##
## Samples are weighted by how full they are (`0.5 - d/cell`, clamped) rather
## than counted, so a blow moves the measured section smoothly instead of in
## whole-voxel steps — which is what keeps the load model from lurching.
##
## Each entry: { "y", "area" (m²), "cx", "cz" (m from the axis),
## "mxx", "mzz", "mxz" (m⁴, about the axis), "sup" (PackedFloat32Array of
## SUPPORT_DIRS reaches from the axis, direction t at angle TAU*t/SUPPORT_DIRS in
## the local x/z plane) }.
## ONLY THE LEVELS THE WOOD ACTUALLY CHANGED AT ARE REMEASURED. A level's numbers
## depend on the samples at that level and nothing else (`_edge_sample` looks sideways,
## never up or down), so a blow that touches four levels of forty-three has no business
## rewalking the whole volume — which is what this did, for 10-15 ms of a ~50 ms blow,
## growing in step with the band's height. Everything that mutates the field marks the
## levels it mutated; see `_dirty_levels`.
##
## The returned array is the LIVE cache, not a copy — copying forty-three dictionaries
## per call would give back most of what this saves. Callers may add their own keys to
## the entries (TreeTrunk.sections hangs the load on them) but must re-read it after any
## carve rather than holding on to it.
func level_stats() -> Array[Dictionary]:
	if _lv.size() != ny:
		_lv.clear()
		_lv.resize(ny)
		_lv_lo = 0
		_lv_hi = ny - 1
	if _lv_hi >= _lv_lo:
		if _trig.is_empty():
			_build_trig()
		for j in range(_lv_lo, _lv_hi + 1):
			_lv[j] = _level_stat(j)
		_lv_lo = ny
		_lv_hi = -1
	return _lv


## Mark levels `j0..j1` as needing remeasuring. Called by everything that writes `_d`.
func _dirty_levels(j0: int, j1: int) -> void:
	_lv_lo = mini(_lv_lo, maxi(j0, 0))
	_lv_hi = maxi(_lv_hi, mini(j1, ny - 1))


func _build_trig() -> void:
	_trig.resize(SUPPORT_DIRS * 2)
	for t in range(SUPPORT_DIRS):
		var a := TAU * float(t) / float(SUPPORT_DIRS)
		_trig[t * 2] = cos(a)
		_trig[t * 2 + 1] = sin(a)


## One horizontal section of the band, measured off the samples at that level.
func _level_stat(j: int) -> Dictionary:
	var cell_area := cell * cell
	var plane_stride := nx * ny
	var area := 0.0
	var sx := 0.0
	var sz := 0.0
	var mxx := 0.0
	var mzz := 0.0
	var mxz := 0.0
	var sup := PackedFloat32Array()
	sup.resize(SUPPORT_DIRS)
	sup.fill(-INF)
	for k in range(nz):
		var z := origin.z + float(k) * cell - axis_xz.y
		var row := nx * j + plane_stride * k
		for i in range(nx):
			var s := row + i
			var w := 0.5 - _d[s] / cell
			if w <= 0.0:
				continue
			w = minf(w, 1.0)
			var x := origin.x + float(i) * cell - axis_xz.x
			area += w
			sx += w * x
			sz += w * z
			mxx += w * x * x
			mzz += w * z * z
			mxz += w * x * z
			# Reach: a sample barely clipping the surface does not count, so
			# a skin of nearly-empty samples cannot inflate it.
			#
			# Only samples on the EDGE of the section are tested, which is exact
			# — the furthest point of a shape in any direction lies on its
			# boundary, so a sample with solid wood on all four sides of it can
			# never be one. Four array reads to reject it against sixteen
			# multiply-adds to measure it, and the interior is most of a trunk.
			if w > 0.25 and _edge_sample(s, i, k):
				for t in range(SUPPORT_DIRS):
					var p := x * _trig[t * 2] + z * _trig[t * 2 + 1]
					if p > sup[t]:
						sup[t] = p
	if area <= 0.0:
		sup.fill(0.0)
	else:
		# A section thin enough that no sample is a quarter full still has to
		# report where it is; fall back to its own centroid rather than
		# leaving a direction unmeasured.
		var cx := sx / area
		var cz := sz / area
		for t in range(SUPPORT_DIRS):
			if sup[t] == -INF:
				sup[t] = cx * _trig[t * 2] + cz * _trig[t * 2 + 1]
	return {
		"y": origin.y + float(j) * cell,
		"area": area * cell_area,
		"cx": sx / area if area > 0.0 else 0.0,
		"cz": sz / area if area > 0.0 else 0.0,
		"mxx": mxx * cell_area,
		"mzz": mzz * cell_area,
		"mxz": mxz * cell_area,
		"sup": sup,
	}


## Is sample `s` on the edge of its own horizontal section? True when any of its
## four in-plane neighbours is not solid enough to count (matching `level_stats`'
## quarter-full threshold, so the test agrees with what it is filtering), or when it
## sits on the rim of the grid.
func _edge_sample(s: int, i: int, k: int) -> bool:
	if i <= 0 or i >= nx - 1 or k <= 0 or k >= nz - 1:
		return true
	var q := cell * 0.25   # d at which the fill weight 0.5 - d/cell falls to 0.25
	return _d[s - 1] >= q or _d[s + 1] >= q \
		or _d[s - nx * ny] >= q or _d[s + nx * ny] >= q


## Trilinear sample of the field. Outside the grid reads as air.
func sample(p: Vector3) -> float:
	var g := (p - origin) / cell
	var i := int(floor(g.x))
	var j := int(floor(g.y))
	var k := int(floor(g.z))
	if i < 0 or j < 0 or k < 0 or i >= nx - 1 or j >= ny - 1 or k >= nz - 1:
		return cell
	var tx := g.x - float(i)
	var ty := g.y - float(j)
	var tz := g.z - float(k)
	var s := i + nx * j + nx * ny * k
	var p0 := lerpf(lerpf(_d[s], _d[s + 1], tx), lerpf(_d[s + nx], _d[s + nx + 1], tx), ty)
	var s2 := s + nx * ny
	var p1 := lerpf(lerpf(_d[s2], _d[s2 + 1], tx), lerpf(_d[s2 + nx], _d[s2 + nx + 1], tx), ty)
	return lerpf(p0, p1, tz)


## March from `from` along `dir` and report where the wood starts. This is how
## the axe finds the face it is actually hitting: as the notch deepens, the same
## aim lands further in, so the cut advances on its own instead of being told to.
## Returns { "hit": bool, "point": Vector3, "dist": float }.
func first_solid(from: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var step := cell * 0.4
	var d := dir.normalized()
	var travelled := 0.0
	var prev := sample(from)
	while travelled < max_dist:
		travelled += step
		var p := from + d * travelled
		var v := sample(p)
		if v < 0.0:
			# Refine onto the surface so a bite is not quantised to the march.
			var t := prev / (prev - v) if prev != v else 1.0
			var hit := from + d * (travelled - step + step * t)
			return {"hit": true, "point": hit, "dist": travelled - step + step * t}
		prev = v
	return {"hit": false, "point": from + d * max_dist, "dist": max_dist}


## Total wood left in the band (m³).
func volume() -> float:
	var n := 0
	for s in range(_d.size()):
		if _d[s] < 0.0:
			n += 1
	return float(n) * cell * cell * cell


func level_y(j: int) -> float:
	return origin.y + float(j) * cell


func level_of(y: float) -> int:
	return clampi(int(round((y - origin.y) / cell)), 0, ny - 1)


## The end-grain round's radius at height `y` — the widest wood that level held before
## anything was cut. Falls back to the single `ring_radius` where no profile was supplied,
## and where a level measured nothing at all.
func ring_at(y: float) -> float:
	if ring_prof.is_empty():
		return ring_radius
	var r: float = ring_prof[clampi(level_of(y), 0, ring_prof.size() - 1)]
	return r if r > 0.01 else ring_radius


func band_lo() -> float:
	return origin.y


func band_hi() -> float:
	return origin.y + float(ny - 1) * cell


# --------------------------------------------------------------- surfacing
## Rebuild the band's visible geometry. Two surfaces: `bark_mat` on wood the axe
## has never touched, `cut_mat` on every face a blow opened — decided per quad
## from whether the air sample outside it was made by a cut, so the boundary is
## exact rather than a fudge factor.
##
## `clip_lo`/`clip_hi` cut the result to a height range and are how the tree is
## broken in two: the stump takes the wood below the neck, the falling tree takes
## the wood above. `tear`/`tear_noise` roughen that clip in the FIELD, so the
## break is a torn surface rather than a planed one.
func build_mesh(bark_mat: Material, cut_mat: Material, clip_lo := -INF, clip_hi := INF,
		tear := 0.0, tear_noise: FastNoiseLite = null) -> ArrayMesh:
	if _d.is_empty():
		return ArrayMesh.new()
	if clip_lo == -INF and clip_hi == INF:
		return _emit(bark_mat, cut_mat)
	# Clipping changes the field, so the cached surface does not apply. Swap the
	# clipped field in, mesh it, and put the real wood back — this only ever runs
	# twice per tree (the stump and the part that goes over).
	#
	# The measured sections are deliberately NOT invalidated: the field is restored
	# byte for byte before this returns, so every level still says what it said. The
	# stump's collider is measured off those sections and must be, since it is the wood
	# the notch left rather than the wood on either side of the break.
	var keep := _d.duplicate()
	var plane_stride := nx * ny
	for k in range(nz):
		for j in range(ny):
			var y := origin.y + float(j) * cell
			var lo_d := clip_lo - y
			var hi_d := y - clip_hi
			var row := nx * j + plane_stride * k
			for i in range(nx):
				var jag := 0.0
				if tear > 0.0 and tear_noise != null:
					var p := origin + Vector3(float(i), float(j), float(k)) * cell
					jag = tear_noise.get_noise_3d(p.x, p.y, p.z) * tear
				var c := maxf(lo_d, hi_d) + jag
				if c > _d[row + i]:
					_d[row + i] = c
	_refresh_all()
	var mesh := _emit(bark_mat, cut_mat)
	_d = keep
	_refresh_all()
	return mesh


## Re-evaluate every cell and rebuild the active list. Only used at build and
## when the whole field changed; a blow uses `_refresh_region`.
func _refresh_all() -> void:
	var total := nx * ny * nz
	_cell_on.resize(total)
	_cell_on.fill(0)
	_cell_v.resize(total)
	_cell_n.resize(total)
	_cell_uv.resize(total)
	_cell_ang.resize(total)
	_refresh_region(0, 0, 0, nx - 2, ny - 2, nz - 2)
	_rebuild_active()


func _refresh_region(i0: int, j0: int, k0: int, i1: int, j1: int, k1: int) -> void:
	i0 = maxi(i0, 0); j0 = maxi(j0, 0); k0 = maxi(k0, 0)
	i1 = mini(i1, nx - 2); j1 = mini(j1, ny - 2); k1 = mini(k1, nz - 2)
	if j1 >= j0:
		_mark_chunks(j0, j1)
	for k in range(k0, k1 + 1):
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				_eval_cell(i, j, k)


func _rebuild_active() -> void:
	var out := PackedInt32Array()
	for ci in range(_cell_on.size()):
		if _cell_on[ci] != 0:
			out.append(ci)
	_active = out


## One dual vertex for the cell whose minimum corner is sample (i,j,k): the mean
## of where the surface crosses the cell's twelve edges (naive surface nets).
## Placing the vertex on the crossings rather than at the cell centre is what
## keeps a plane cut reading as a plane instead of as voxel stairs.
func _eval_cell(i: int, j: int, k: int) -> void:
	var ci := i + nx * j + nx * ny * k
	var p := nx * ny
	var d0 := _d[ci]
	var d1 := _d[ci + 1]
	var d2 := _d[ci + nx]
	var d3 := _d[ci + nx + 1]
	var d4 := _d[ci + p]
	var d5 := _d[ci + p + 1]
	var d6 := _d[ci + p + nx]
	var d7 := _d[ci + p + nx + 1]
	var neg := 0
	if d0 < 0.0: neg += 1
	if d1 < 0.0: neg += 1
	if d2 < 0.0: neg += 1
	if d3 < 0.0: neg += 1
	if d4 < 0.0: neg += 1
	if d5 < 0.0: neg += 1
	if d6 < 0.0: neg += 1
	if d7 < 0.0: neg += 1
	if neg == 0 or neg == 8:
		_cell_on[ci] = 0
		return

	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	var n := 0
	# --- the four edges along X (the crossing slides in x; y,z sit on corners)
	if (d0 < 0.0) != (d1 < 0.0):
		sx += d0 / (d0 - d1)
		n += 1
	if (d2 < 0.0) != (d3 < 0.0):
		sx += d2 / (d2 - d3)
		sy += 1.0
		n += 1
	if (d4 < 0.0) != (d5 < 0.0):
		sx += d4 / (d4 - d5)
		sz += 1.0
		n += 1
	if (d6 < 0.0) != (d7 < 0.0):
		sx += d6 / (d6 - d7)
		sy += 1.0
		sz += 1.0
		n += 1
	# --- the four edges along Y
	if (d0 < 0.0) != (d2 < 0.0):
		sy += d0 / (d0 - d2)
		n += 1
	if (d1 < 0.0) != (d3 < 0.0):
		sx += 1.0
		sy += d1 / (d1 - d3)
		n += 1
	if (d4 < 0.0) != (d6 < 0.0):
		sy += d4 / (d4 - d6)
		sz += 1.0
		n += 1
	if (d5 < 0.0) != (d7 < 0.0):
		sx += 1.0
		sy += d5 / (d5 - d7)
		sz += 1.0
		n += 1
	# --- the four edges along Z
	if (d0 < 0.0) != (d4 < 0.0):
		sz += d0 / (d0 - d4)
		n += 1
	if (d1 < 0.0) != (d5 < 0.0):
		sx += 1.0
		sz += d1 / (d1 - d5)
		n += 1
	if (d2 < 0.0) != (d6 < 0.0):
		sy += 1.0
		sz += d2 / (d2 - d6)
		n += 1
	if (d3 < 0.0) != (d7 < 0.0):
		sx += 1.0
		sy += 1.0
		sz += d3 / (d3 - d7)
		n += 1
	if n == 0:
		_cell_on[ci] = 0
		return

	var inv := 1.0 / float(n)
	_cell_on[ci] = 1
	var pos := origin + (Vector3(float(i) + sx * inv, float(j) + sy * inv,
		float(k) + sz * inv)) * cell
	_cell_v[ci] = pos
	var ang := atan2(pos.z - axis_xz.y, pos.x - axis_xz.x)
	_cell_ang[ci] = ang
	_cell_uv[ci] = _bark_uv_at(pos.y, ang)
	# Cell-centred gradient of a trilinear field — exact, and on a plane cut it
	# comes out as the cut plane's own normal.
	_cell_n[ci] = Vector3(
		(d1 + d3 + d5 + d7) - (d0 + d2 + d4 + d6),
		(d2 + d3 + d6 + d7) - (d0 + d1 + d4 + d5),
		(d4 + d5 + d6 + d7) - (d0 + d1 + d2 + d3)).normalized()


## Walk the cached surface and stitch the quads. Every crossing edge of the grid
## owns one quad, joining the dual vertices of the four cells around it; each
## edge is visited exactly once, from the cell whose minimum corner is the edge's
## lower sample.
## How many cell levels one chunk of the band's geometry covers. Smaller chunks mean
## less to re-surface after a blow and more mesh instances to draw; 8 puts six chunks on
## tree_01's 2.3 m band. See `chunk_mesh`.
const CHUNK_CELLS := 8


## How many chunks the band's geometry is split into.
func chunk_count() -> int:
	return maxi(1, int(ceil(float(maxi(ny - 1, 1)) / float(CHUNK_CELLS))))


## Surface one chunk of the band.
##
## A BLOW CHANGES A BAND OF HEIGHTS, NOT THE WHOLE TRUNK, and re-stitching every quad in
## the band because a dozen levels moved was the single most expensive thing a blow did
## — 15-25 ms of it. An angled cut does reach a long way up and down (a 45-degree slab
## across a 0.94 m trunk spans most of a metre), so this is worth about half the cost
## headless; on real hardware it is worth more than that, because only the chunks that
## changed re-upload their vertex buffers.
##
## A quad is emitted from the cell whose minimum corner owns the edge, and it reaches
## back to the cells one level BELOW that — so a chunk's mesh legitimately contains
## vertices from the chunk beneath it. They are at identical positions, so the chunks
## meet watertight; the only cost is a row of duplicated vertices per boundary.
func chunk_mesh(c: int, bark_mat: Material, cut_mat: Material) -> ArrayMesh:
	return _emit(bark_mat, cut_mat, c * CHUNK_CELLS, (c + 1) * CHUNK_CELLS - 1)


## Which chunks have changed since this was last called, and clear the record.
func take_dirty_chunks() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in range(_dirty_chunks.size()):
		if _dirty_chunks[c] != 0:
			out.append(c)
	_dirty_chunks.fill(0)
	return out


## Mark every chunk that draws geometry from cell levels `j0..j1` as needing re-surfacing.
## A cell at level j is read by quads emitted at levels j and j + 1, hence the reach up.
func _mark_chunks(j0: int, j1: int) -> void:
	var nc := chunk_count()
	if _dirty_chunks.size() != nc:
		_dirty_chunks.resize(nc)
		_dirty_chunks.fill(1)
		return
	var c0 := clampi(maxi(j0, 0) / CHUNK_CELLS, 0, nc - 1)
	var c1 := clampi((mini(j1, ny - 2) + 1) / CHUNK_CELLS, 0, nc - 1)
	for c in range(c0, c1 + 1):
		_dirty_chunks[c] = 1


## Walk the cached surface and stitch the quads, for emitting cell levels `j_lo..j_hi`.
## The default range is the whole band, which is what `build_mesh` wants.
func _emit(bark_mat: Material, cut_mat: Material, j_lo := 0, j_hi := 1 << 30) -> ArrayMesh:
	var out := ArrayMesh.new()
	var bark := _Buf.new()
	var cutb := _Buf.new()
	var sideb := _Buf.new()
	var rootb := _Buf.new()
	var plane_stride := nx * ny
	# Vertex slots per cell, per surface. Bark carries a second slot for the
	# texture seam (see _bark_uv): a quad that straddles the back of the trunk
	# needs its far-side corners at u + one full wrap, or the texture runs
	# backwards across the whole trunk in one quad.
	#
	# Held as members and re-filled rather than reallocated: this runs on every
	# blow, and three fresh grid-sized arrays per remesh is three allocations and
	# eighty thousand writes for scratch space that is the same size every time.
	var n := _cell_on.size()
	if _slot_bark.size() != n:
		_slot_bark.resize(n)
		_slot_seam.resize(n)
		_slot_cut.resize(n)
		_slot_side.resize(n)
		_slot_root.resize(n)
	# Blanked wholesale, and MEASURED to be the right way round: clearing only the
	# ~1000 entries in `_active` instead of all 27,000 was tried on 2026-07-26 and came
	# out SLOWER. `fill` is one native memset; the active list is a GDScript loop, and
	# an interpreted iteration costs far more than the twenty-six thousand bytes it
	# saves touching.
	var bvi := _slot_bark; bvi.fill(-1)
	var bvs := _slot_seam; bvs.fill(-1)
	var cvi := _slot_cut; cvi.fill(-1)
	var svi := _slot_side; svi.fill(-1)
	var rvi := _slot_root; rvi.fill(-1)

	for ci in _active:
		var k := ci / plane_stride
		var rem := ci % plane_stride
		var j := rem / nx
		if j < j_lo or j > j_hi:
			continue   # another chunk owns the quads emitted from this cell
		var i := rem % nx
		var d0 := _d[ci]
		# +X edge: the four cells around it differ in j and k.
		if i <= nx - 2 and j >= 1 and k >= 1 and j <= ny - 2 and k <= nz - 2:
			var d1 := _d[ci + 1]
			if (d0 < 0.0) != (d1 < 0.0):
				_quad(bark, cutb, sideb, rootb, bvi, bvs, cvi, svi, rvi,
					ci - nx - plane_stride, ci - plane_stride, ci, ci - nx,
					_cut[ci + 1] if d0 < 0.0 else _cut[ci], d0 < 0.0)
		# +Y edge
		if j <= ny - 2 and i >= 1 and k >= 1 and i <= nx - 2 and k <= nz - 2:
			var d1y := _d[ci + nx]
			if (d0 < 0.0) != (d1y < 0.0):
				_quad(bark, cutb, sideb, rootb, bvi, bvs, cvi, svi, rvi,
					ci - 1 - plane_stride, ci - plane_stride, ci, ci - 1,
					_cut[ci + nx] if d0 < 0.0 else _cut[ci], d0 >= 0.0)
		# +Z edge
		if k <= nz - 2 and i >= 1 and j >= 1 and i <= nx - 2 and j <= ny - 2:
			var d1z := _d[ci + plane_stride]
			if (d0 < 0.0) != (d1z < 0.0):
				_quad(bark, cutb, sideb, rootb, bvi, bvs, cvi, svi, rvi,
					ci - 1 - nx, ci - nx, ci, ci - 1,
					_cut[ci + plane_stride] if d0 < 0.0 else _cut[ci], d0 < 0.0)

	bark.commit(out, bark_mat)
	cutb.commit(out, cut_mat)
	sideb.commit(out, side_mat if side_mat != null else cut_mat)
	rootb.commit(out, root_mat if root_mat != null else bark_mat)
	return out


## Stitch one quad from four cell vertices. `is_cut` routes it to the cut surface;
## `forward` says the AIR is on the + side of the edge being crossed.
##
## WINDING (this was backwards until 2026-07-25, and it is why you could see
## straight through the carved butt to the inside of the far wall). Godot's front
## face is the CLOCKWISE one, which means the front of a triangle is the side its
## right-hand-rule normal `(b-a)x(c-a)` points AWAY from — the engine's own
## `SurfaceTool.generate_normals` computes exactly `-(RHR)` and calls that the
## facing direction. So a face that is to be seen from the air side must be wound
## with its RHR normal pointing INTO the wood, i.e. against the outward shading
## normal this mesher hands every vertex. Measured, not assumed: every triangle of
## Godot's own BoxMesh, of tree_01.fbx and of forest_floor_a.fbx has RHR opposing
## its shading normal, and the band had 3474 out of 3474 agreeing with it.
##
## The notch did not show the bug because `_cut_mat` is CULL_DISABLED (a fresh cut
## face must never vanish when seen from behind) — only the CULL_BACK bark did.
func _quad(bark: _Buf, cutb: _Buf, sideb: _Buf, rootb: _Buf, bvi: PackedInt32Array,
		bvs: PackedInt32Array, cvi: PackedInt32Array, svi: PackedInt32Array,
		rvi: PackedInt32Array, c0: int, c1: int, c2: int, c3: int,
		is_cut: int, forward: bool) -> void:
	if _cell_on[c0] == 0 or _cell_on[c1] == 0 or _cell_on[c2] == 0 or _cell_on[c3] == 0:
		return
	var a: int
	var b: int
	var c: int
	var d: int
	var buf := bark
	if is_cut != 0:
		# WHICH WAY THE AXE MET THE WOOD, decided per quad from the face's own tilt. A
		# cross-cut (the roof and floor of a notch) shows growth rings; a wall running
		# down the length of the trunk shows long grain. Projecting both onto the
		# horizontal plane is what smeared every kerf into a bright ribbon — see
		# `side_mat`.
		# The LEAST cross-cut corner decides, not the average: a quad takes the rings only
		# if every corner of it is genuinely cross-cut. One steep corner is enough to
		# smear a quad, and long grain cannot smear at all — so a face that is ambiguous
		# belongs on the side that has no failure mode.
		var tilt := minf(minf(absf(_cell_n[c0].y), absf(_cell_n[c1].y)),
			minf(absf(_cell_n[c2].y), absf(_cell_n[c3].y)))
		var rings := side_mat == null or ring_radius <= 0.0 or tilt >= _END_GRAIN_TILT
		buf = cutb if rings else sideb
		var cs := cvi if rings else svi
		a = _cut_vertex(buf, cs, c0, rings)
		b = _cut_vertex(buf, cs, c1, rings)
		c = _cut_vertex(buf, cs, c2, rings)
		d = _cut_vertex(buf, cs, c3, rings)
	elif root_mat != null and (minf(minf(_cell_v[c0].y, _cell_v[c1].y),
			minf(_cell_v[c2].y, _cell_v[c3].y)) < root_below
			or maxf(maxf(absf(_cell_n[c0].y), absf(_cell_n[c1].y)),
				maxf(absf(_cell_n[c2].y), absf(_cell_n[c3].y))) > _BARK_TRIPLANAR_TILT):
		# THE ROOT FLARE, on its own triplanar material. No seam decision: triplanar does
		# not use the UVs at all, so there is no wrap to fall off. Routed by the WHOLE quad
		# having ANY corner under the flare top: a quad that straddles the boundary is one
		# the wrap is already degenerating on, so it goes to the side that cannot fail and
		# the material change lands a whole row higher, on clean stem...
		#
		# ...OR by the quad facing UP OR DOWN, which is the same failure the cut faces have
		# and for the same reason: the trunk's wrap takes u from the bearing round the axis
		# and v from height, so on a near-HORIZONTAL surface v barely moves and one row of
		# texels is smeared across the whole face. That is the banded ribbon that was left
		# round the shoulder of the flare after the height rule alone. The MOST horizontal
		# corner decides, because triplanar has no failure mode and the wrap does.
		buf = rootb
		a = _bark_vertex(rootb, rvi, rvi, c0, false)
		b = _bark_vertex(rootb, rvi, rvi, c1, false)
		c = _bark_vertex(rootb, rvi, rvi, c2, false)
		d = _bark_vertex(rootb, rvi, rvi, c3, false)
	else:
		# Seam decision is per quad: if the four corners span more than half the
		# trunk in angle, the ones behind the seam take the wrapped slot.
		# Read straight out of the cache rather than through `_angle_of`: this is four
		# reads on every bark quad in the band and a scripted call is not free.
		var a0 := _cell_ang[c0]
		var a1 := _cell_ang[c1]
		var a2 := _cell_ang[c2]
		var a3 := _cell_ang[c3]
		var lo := minf(minf(a0, a1), minf(a2, a3))
		var hi := maxf(maxf(a0, a1), maxf(a2, a3))
		var seam := hi - lo > PI
		a = _bark_vertex(bark, bvi, bvs, c0, seam and a0 < 0.0)
		b = _bark_vertex(bark, bvi, bvs, c1, seam and a1 < 0.0)
		c = _bark_vertex(bark, bvi, bvs, c2, seam and a2 < 0.0)
		d = _bark_vertex(bark, bvi, bvs, c3, seam and a3 < 0.0)
	# c0..c3 run counter-clockwise as seen from the + side of the edge, so a-b-c
	# would put the RHR normal out into the air. Reversed, per the note above.
	if forward:
		buf.tri(a, c, b)
		buf.tri(a, d, c)
	else:
		buf.tri(a, b, c)
		buf.tri(a, c, d)


func _angle_of(ci: int) -> float:
	return _cell_ang[ci]


## Pull a surface point in toward the trunk axis near a join, so the imported piece's
## mesh laps cleanly over the band's rim. Visual only — see `rim_inset`.
func _inset(v: Vector3) -> Vector3:
	if rim_inset <= 0.0:
		return v
	var t := 0.0
	if v.y > rim_lo:
		t = 1.0 if v.y >= rim_hi else (v.y - rim_lo) / maxf(rim_hi - rim_lo, 0.0001)
	if v.y < rim_base_hi:
		var tb := 1.0 if v.y <= rim_base_lo else 			(rim_base_hi - v.y) / maxf(rim_base_hi - rim_base_lo, 0.0001)
		t = maxf(t, tb)
	if t <= 0.0:
		return v
	var dx := v.x - axis_xz.x
	var dz := v.z - axis_xz.y
	var r := sqrt(dx * dx + dz * dz)
	if r < 0.0001:
		return v
	var k: float = maxf(r - rim_inset * t, 0.0) / r
	return Vector3(axis_xz.x + dx * k, v.y, axis_xz.y + dz * k)


## Bark UVs wrap the trunk: u goes round, v goes up. The tangent is the
## tangential direction, so a normal-mapped bark material has the basis it needs
## without a generate_tangents pass (which would have to run on every remesh).
func _bark_vertex(buf: _Buf, vi: PackedInt32Array, vs: PackedInt32Array, ci: int,
		seam: bool) -> int:
	var slot := vs if seam else vi
	if slot[ci] >= 0:
		return slot[ci]
	var v := _inset(_cell_v[ci])
	var dx := v.x - axis_xz.x
	var dz := v.z - axis_xz.y
	# Read straight out of the source mesh's own mapping, so the band's bark is the same
	# size as the crown's AND lines up with it (see _finish_uv_table). Sampled once per
	# CELL in `_eval_cell` rather than once per vertex here: a cell is only re-evaluated
	# when the field around it changed, so a blow pays for the few hundred cells it
	# touched instead of for every bark vertex in the band on every remesh.
	var uv := _cell_uv[ci]
	if seam:
		uv.x += bark_uv.x   # this quad straddles the back: one more turn round
	var tan := Vector3(-dz, 0.0, dx)
	if tan.length() < 0.0001:
		tan = Vector3.RIGHT
	var id := buf.vertex(v, _cell_n[ci], uv, tan.normalized(), Vector3.UP)
	slot[ci] = id
	return id


## Cut faces are projected flat along whichever axis their normal leans on, so a
## fresh face wears straight grain rather than a stretched wrap.
func _cut_vertex(buf: _Buf, vi: PackedInt32Array, ci: int, rings: bool) -> int:
	if vi[ci] >= 0:
		return vi[ci]
	var v := _inset(_cell_v[ci])
	var n := _cell_n[ci]
	var uv: Vector2
	var tan: Vector3
	var bitan: Vector3
	if rings and ring_radius > 0.0:
		# End grain, centred on the trunk's axis — see ring_radius, and `ring_at` for why
		# the round is sized where the cut is rather than once for the whole band.
		var k := ring_fit / ring_at(v.y)
		uv = Vector2((v.x - axis_xz.x) * k + 0.5, (v.z - axis_xz.y) * k + 0.5)
		var id_r := buf.vertex(v, n, uv, Vector3.RIGHT, Vector3.BACK)
		vi[ci] = id_r
		return id_r
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ay >= ax and ay >= az:
		uv = Vector2(v.x, v.z) * cut_uv
		tan = Vector3.RIGHT
		bitan = Vector3.BACK
	elif ax >= az:
		uv = Vector2(v.z, v.y) * cut_uv
		tan = Vector3.BACK
		bitan = Vector3.UP
	else:
		uv = Vector2(v.x, v.y) * cut_uv
		tan = Vector3.RIGHT
		bitan = Vector3.UP
	var id := buf.vertex(v, n, uv, tan, bitan)
	vi[ci] = id
	return id


## Surface-nets a standalone block of field values — the freed chips and the
## wedge that pops out of the notch. One material, flat-projected UVs; small
## enough that the cached path would not pay for itself.
func _block_surface(field: PackedFloat32Array, i0: int, j0: int, k0: int,
		bx: int, by: int, bz: int, mat: Material) -> ArrayMesh:
	var out := ArrayMesh.new()
	if bx < 2 or by < 2 or bz < 2:
		return out
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var slot := PackedInt32Array()
	slot.resize(bx * by * bz)
	slot.fill(-1)
	var bp := bx * by
	for k in range(bz - 1):
		for j in range(by - 1):
			for i in range(bx - 1):
				var ci := i + bx * j + bp * k
				var e0 := field[ci]
				var e1 := field[ci + 1]
				var e2 := field[ci + bx]
				var e3 := field[ci + bx + 1]
				var e4 := field[ci + bp]
				var e5 := field[ci + bp + 1]
				var e6 := field[ci + bp + bx]
				var e7 := field[ci + bp + bx + 1]
				var neg := 0
				if e0 < 0.0: neg += 1
				if e1 < 0.0: neg += 1
				if e2 < 0.0: neg += 1
				if e3 < 0.0: neg += 1
				if e4 < 0.0: neg += 1
				if e5 < 0.0: neg += 1
				if e6 < 0.0: neg += 1
				if e7 < 0.0: neg += 1
				if neg == 0 or neg == 8:
					continue
				# Same twelve-edge sweep as _eval_cell, unrolled for the same
				# reason: an Array literal per cell costs more than the maths.
				var sx := 0.0
				var sy := 0.0
				var sz := 0.0
				var n := 0
				if (e0 < 0.0) != (e1 < 0.0):
					sx += e0 / (e0 - e1)
					n += 1
				if (e2 < 0.0) != (e3 < 0.0):
					sx += e2 / (e2 - e3)
					sy += 1.0
					n += 1
				if (e4 < 0.0) != (e5 < 0.0):
					sx += e4 / (e4 - e5)
					sz += 1.0
					n += 1
				if (e6 < 0.0) != (e7 < 0.0):
					sx += e6 / (e6 - e7)
					sy += 1.0
					sz += 1.0
					n += 1
				if (e0 < 0.0) != (e2 < 0.0):
					sy += e0 / (e0 - e2)
					n += 1
				if (e1 < 0.0) != (e3 < 0.0):
					sx += 1.0
					sy += e1 / (e1 - e3)
					n += 1
				if (e4 < 0.0) != (e6 < 0.0):
					sy += e4 / (e4 - e6)
					sz += 1.0
					n += 1
				if (e5 < 0.0) != (e7 < 0.0):
					sx += 1.0
					sy += e5 / (e5 - e7)
					sz += 1.0
					n += 1
				if (e0 < 0.0) != (e4 < 0.0):
					sz += e0 / (e0 - e4)
					n += 1
				if (e1 < 0.0) != (e5 < 0.0):
					sx += 1.0
					sz += e1 / (e1 - e5)
					n += 1
				if (e2 < 0.0) != (e6 < 0.0):
					sy += 1.0
					sz += e2 / (e2 - e6)
					n += 1
				if (e3 < 0.0) != (e7 < 0.0):
					sx += 1.0
					sy += 1.0
					sz += e3 / (e3 - e7)
					n += 1
				if n == 0:
					continue
				var inv := 1.0 / float(n)
				slot[ci] = verts.size()
				verts.append(origin + Vector3(float(i0 + i) + sx * inv,
					float(j0 + j) + sy * inv, float(k0 + k) + sz * inv) * cell)
				norms.append(Vector3(
					(e1 + e3 + e5 + e7) - (e0 + e2 + e4 + e6),
					(e2 + e3 + e6 + e7) - (e0 + e1 + e4 + e5),
					(e4 + e5 + e6 + e7) - (e0 + e1 + e2 + e3)).normalized())

	var buf := _Buf.new()
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	for k in range(1, bz - 1):
		for j in range(1, by - 1):
			for i in range(1, bx - 1):
				var ci := i + bx * j + bp * k
				var d0 := field[ci]
				if i <= bx - 2 and (d0 < 0.0) != (field[ci + 1] < 0.0):
					_block_quad(buf, verts, norms, remap, slot,
						ci - bx - bp, ci - bp, ci, ci - bx, d0 < 0.0)
				if j <= by - 2 and (d0 < 0.0) != (field[ci + bx] < 0.0):
					_block_quad(buf, verts, norms, remap, slot,
						ci - 1 - bp, ci - bp, ci, ci - 1, d0 >= 0.0)
				if k <= bz - 2 and (d0 < 0.0) != (field[ci + bp] < 0.0):
					_block_quad(buf, verts, norms, remap, slot,
						ci - 1 - bx, ci - bx, ci, ci - 1, d0 < 0.0)
	buf.commit(out, mat)
	return out


func _block_quad(buf: _Buf, verts: PackedVector3Array, norms: PackedVector3Array,
		remap: PackedInt32Array, slot: PackedInt32Array,
		c0: int, c1: int, c2: int, c3: int, forward: bool) -> void:
	var ids: Array[int] = []
	for c in [c0, c1, c2, c3]:
		if c < 0 or c >= slot.size() or slot[c] < 0:
			return
		var v := slot[c]
		if remap[v] < 0:
			var n := norms[v]
			var p := verts[v]
			var uv: Vector2
			var tan: Vector3
			var bitan: Vector3
			var ax := absf(n.x)
			var ay := absf(n.y)
			var az := absf(n.z)
			if ay >= ax and ay >= az:
				uv = Vector2(p.x, p.z) * cut_uv
				tan = Vector3.RIGHT
				bitan = Vector3.BACK
			elif ax >= az:
				uv = Vector2(p.z, p.y) * cut_uv
				tan = Vector3.BACK
				bitan = Vector3.UP
			else:
				uv = Vector2(p.x, p.y) * cut_uv
				tan = Vector3.RIGHT
				bitan = Vector3.UP
			remap[v] = buf.vertex(p, n, uv, tan, bitan)
		ids.append(remap[v])
	# Same winding rule as _quad — see the note there. A chip is meshed with the
	# cut material (CULL_DISABLED), so this one never showed, but a chip that ever
	# wears bark would have gone see-through exactly as the band did.
	if forward:
		buf.tri(ids[0], ids[2], ids[1])
		buf.tri(ids[0], ids[3], ids[2])
	else:
		buf.tri(ids[0], ids[1], ids[2])
		buf.tri(ids[0], ids[2], ids[3])


## An indexed vertex buffer built straight into Packed arrays. SurfaceTool would
## be the obvious thing, but it costs a scripted call per attribute per vertex
## and this runs on every blow; TANGENT and COLOR are filled in because the wood
## materials are normal-mapped and use vertex colour as albedo (a surface missing
## either shades differently from its neighbour — the 2026-07-23 bug).
class _Buf extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var t := PackedFloat32Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	## `tan` points along increasing U, `bitan` along increasing V. The handedness
	## has to be DERIVED from those, not assumed: Godot reads the binormal as
	## cross(normal, tangent) * w, and getting w backwards mirrors the normal
	## map's green channel — the surface keeps its colour and loses its relief,
	## which is exactly how it reads next to an uncut neighbour that still has it.
	func vertex(pos: Vector3, nrm: Vector3, tex: Vector2, tan: Vector3, bitan: Vector3) -> int:
		var id := v.size()
		v.append(pos)
		n.append(nrm)
		uv.append(tex)
		# Orthogonalise against the normal so the basis stays square.
		var tt := (tan - nrm * nrm.dot(tan))
		if tt.length() < 0.0001:
			tt = nrm.cross(Vector3.UP)
			if tt.length() < 0.0001:
				tt = Vector3.RIGHT
		tt = tt.normalized()
		var w := -1.0 if nrm.cross(tt).dot(bitan) < 0.0 else 1.0
		t.append(tt.x); t.append(tt.y); t.append(tt.z); t.append(w)
		c.append(Color.WHITE)
		return id

	func tri(a: int, b: int, d: int) -> void:
		idx.append(a); idx.append(b); idx.append(d)

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if idx.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TANGENT] = t
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mat != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## ONE AXIS OF `_fill_from_mesh`. Lines run along `ax` (0 = X, 1 = Y, 2 = Z); each is
## intersected with the bucketed triangles, and every sample on it takes the distance to
## the nearest crossing and a vote on whether it is inside (an odd number of surfaces
## still ahead of it).
##
## Each triangle is tested in BOTH windings on purpose: `ray_intersects_triangle` reports
## only front faces, and a parity count that cannot see the far wall of a solid is not a
## parity count.
func _sweep(tri: PackedVector3Array, j_top: int, dist: PackedFloat32Array,
		votes: PackedByteArray, ax: int) -> void:
	var counts := [nx, ny, nz]
	var org := [origin.x, origin.y, origin.z]
	# The two axes a line is indexed by, and the one it runs along.
	var p: int = 1 if ax == 0 else 0
	var q: int = 2 if ax != 2 else 1
	var np: int = counts[p]
	var nq: int = counts[q]
	var na: int = counts[ax]

	# ---- bucket the triangles by the grid footprint they cover.
	var bucket: Array = []
	bucket.resize(np * nq)
	var tri_count := tri.size() / 3
	for t in range(tri_count):
		var a := tri[t * 3]
		var b := tri[t * 3 + 1]
		var c := tri[t * 3 + 2]
		var ap := [a.x, a.y, a.z]
		var bp := [b.x, b.y, b.z]
		var cp := [c.x, c.y, c.z]
		var p0 := int(floor((minf(ap[p], minf(bp[p], cp[p])) - org[p]) / cell)) - 1
		var p1 := int(ceil((maxf(ap[p], maxf(bp[p], cp[p])) - org[p]) / cell)) + 1
		var q0 := int(floor((minf(ap[q], minf(bp[q], cp[q])) - org[q]) / cell)) - 1
		var q1 := int(ceil((maxf(ap[q], maxf(bp[q], cp[q])) - org[q]) / cell)) + 1
		p0 = maxi(p0, 0)
		q0 = maxi(q0, 0)
		p1 = mini(p1, np - 1)
		q1 = mini(q1, nq - 1)
		for iq in range(q0, q1 + 1):
			for ip in range(p0, p1 + 1):
				var bi := ip + np * iq
				var lst: PackedInt32Array = bucket[bi] if bucket[bi] != null \
					else PackedInt32Array()
				lst.append(t)
				bucket[bi] = lst

	# ---- and sweep every line that touches the slab.
	var dir := Vector3(1.0 if ax == 0 else 0.0, 1.0 if ax == 1 else 0.0,
		1.0 if ax == 2 else 0.0)
	var span := float(na) * cell + 2.0
	var hits := PackedFloat32Array()
	for iq in range(nq):
		if q == 1 and iq > j_top:
			continue          # this line is entirely above the root slab
		for ip in range(np):
			if p == 1 and ip > j_top:
				continue
			var bi := ip + np * iq
			if bucket[bi] == null:
				continue
			var lst: PackedInt32Array = bucket[bi]
			# Start a long way back along the axis so every crossing is ahead of it.
			var from := Vector3(origin.x, origin.y, origin.z)
			var comp := [0.0, 0.0, 0.0]
			comp[p] = org[p] + float(ip) * cell
			comp[q] = org[q] + float(iq) * cell
			comp[ax] = org[ax] - 1.0
			from = Vector3(comp[0], comp[1], comp[2])
			hits.clear()
			for t in lst:
				var a := tri[t * 3]
				var b := tri[t * 3 + 1]
				var c := tri[t * 3 + 2]
				var h = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
				if h == null:
					h = Geometry3D.ray_intersects_triangle(from, dir, a, c, b)
				if h == null:
					continue
				var hp: Vector3 = h
				var along: float = [hp.x, hp.y, hp.z][ax]
				if along > org[ax] + span:
					continue
				hits.append(along)
			if hits.is_empty():
				continue
			hits.sort()
			for ia in range(na):
				if ax == 1 and ia > j_top:
					break
				var coord: float = org[ax] + float(ia) * cell
				var ahead := 0
				var near := INF
				for h2 in hits:
					if h2 > coord:
						ahead += 1
					near = minf(near, absf(h2 - coord))
				var s := 0
				var comp_i := [0, 0, 0]
				comp_i[p] = ip
				comp_i[q] = iq
				comp_i[ax] = ia
				if comp_i[1] > j_top:
					continue
				s = comp_i[0] + nx * comp_i[1] + nx * ny * comp_i[2]
				dist[s] = minf(dist[s], near)
				if ahead % 2 == 1:
					votes[s] += 1
