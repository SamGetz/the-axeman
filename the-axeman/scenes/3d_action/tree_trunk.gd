class_name TreeTrunk
extends Node3D
## FILE: res://scenes/3d_action/tree_trunk.gd
## ATTACHES TO: nothing in a .tscn — tree_felling.gd creates one per tree
## (`TreeTrunk.new()`, `add_child`, `build(...)`).
##
## ONE STANDING TREE. The bottom `band_height` metres — everywhere a felling cut
## can land — is a VOXEL VOLUME (`WoodVolume`, Amendment 13); everything above it
## keeps the imported mesh, clipped off at the band top once, at build. So the
## part the axe touches is real, carveable wood and the crown is cheap geometry
## riding on top of it.
##
## WHAT CHANGED AND WHY (Amendment 13). This used to hold the tree as a stack of
## thin horizontal SLABS and take a convex plane bite out of one per blow, because
## a plane cut removes a half-space and cannot carve a concave pocket. Everything
## that made the old felling feel wrong came out of that workaround: bites landed
## in whichever slab the click snapped to rather than where the wood was, remnant
## bands stood between slabs as floating disks, "thickness" had to be inferred
## from cross-section probes, and the fall had to be shoved because there was no
## real hinge to pivot on. None of it survives here. A blow subtracts a solid from
## a single continuous volume; the notch is one pocket; the hinge is the wood that
## is actually left between the notch and the back cut; and wood the player has
## cut free simply falls out, because nothing is holding it up.
##
## Nothing here is a hit-point budget and nothing here knows about input, feel or
## scoring — `sections()` reports what the wood is doing and tree_felling.gd
## decides what that means.

## THE COLLISION LAYERS, defined here because the stump is a tree body and used from
## tree_felling.gd for the rest. Splinters deliberately do NOT collide with big timber
## — Creative Director's call, 2026-07-25: debris is there to make small piles on the
## ground, and 150 splinters shoving a falling tree about (or being flicked across the
## clearing by it) is all cost and no benefit. They clip through it and pile on each
## other instead.
const GROUND_LAYER := 1 << 0                        ## the floor, and only the floor
const TIMBER_LAYER := 1 << 2                        ## stump, falling trunk, bucked logs
const TIMBER_MASK := GROUND_LAYER | TIMBER_LAYER    ## ...which hit the ground and each other
const DEBRIS_LAYER := 1 << 3                        ## splinters
const DEBRIS_MASK := GROUND_LAYER | DEBRIS_LAYER    ## ...which hit the ground and each other

## Pickable by ray, collides with nothing — matches M4, so one ray query serves both
## mini-games. PUBLIC because it is now the AIM: the first-person crosshair ray is cast
## against this layer to find which tree is being looked at and where on it (plan §2).
## It was private and unused while `_aim_point` shortcutted to the one trunk's axis.
const PICK_LAYER := 1 << 1
const _PICK_RADIUS_PAD := 1.15    # how much wider than the trunk the click volume is
## How tall one slab of the stump's collider is (m) — a discretisation, like `_BRANCH_BIN`,
## not a tuning value. It is the scale at which a root flare's width actually changes, and
## it doubles as the clearance the falling butt needs: too coarse and a trunk that has been
## handed to physics can catch on a slab wider than the wood it was cut from.
##
## REPLACED `_NECK_BAND` (2026-07-31), which was the MINIMUM height of a single measured
## neck cylinder — and on a stump shorter than it, the neck became the whole stump and the
## base collider was never built. See `_build_stump_body`.
const _STUMP_SLAB := 0.2
## Branches crossing the felling band are clamped back to the trunk rather than
## modelled — a felling cut has no business being routed around a twig.
const _PROFILE_CLAMP := 1.15
## How much wider than the bare trunk a height has to measure before it counts as
## the CROWN starting rather than a bit of bark relief. The ORIGINAL tree_01 flared
## to only 1.14x radius at the butt and its first branch cluster jumped to 1.51x, so
## this line sat comfortably between the two and the root flare was simply under it.
##
## THE CURRENT ART FLARES FAR HARDER THAN THAT — 1.56x on tree_01 and 1.77x on
## tree_02, both at the very first bin — so the flare is no longer under this line
## and cannot be handled by moving it: raising the tolerance past 1.8 would also walk
## straight past a real branch cluster. It is handled structurally instead, by
## skipping the flare where it is (see `_clear_trunk_height`).
const _BRANCH_TOL := 1.25
## How far apart the two heights a swelling is judged over are, in `_BRANCH_BIN`s. Both
## scans ask "is this wider than the wood 0.2 m away?" rather than "is this wider than
## the trunk?" — see `_root_flare_height` for why that distinction is the whole game.
const _TAPER_LOOK := 2
## The band never comes out shorter than this (m), whatever the profile says — a
## tree whose branches start at the ground still has to be choppable.
const _MIN_BAND := 0.9
## Height bin used to find where the branches start (m). Coarser than the voxel
## cell on purpose: it is looking for a branch, not measuring one.
const _BRANCH_BIN := 0.1
## How far the crown's mesh is clipped BELOW the band top, in cells, so the two
## overlap instead of merely meeting.
##
## THIS IS THE FIX FOR THE RING ROUND AN UNCUT TRUNK. Surface nets puts a cell's dual
## vertex at the average of where the surface crosses that cell's edges, and the top
## row of cells can only be the one below the grid's last sample row — so the band's
## geometry stops about half a cell short of `band_hi` (17 mm at cell 0.055) even
## though the field is solid all the way up. Clipping the crown exactly at `band_hi`
## therefore left a slit of daylight right round the trunk, which is what Sam saw as
## "a slice that comes in by default". Overlapping instead means the crown's bark
## covers the band's open rim, and the cap the slicer puts on the crown's underside
## ends up buried inside the band's wood where it was always supposed to be.
const _CROWN_OVERLAP := 2.5
## How far the band's RENDERED surface ducks in under the crown over that lap, in
## cells. It only has to beat the disagreement between the two surfaces, which after
## the 2026-07-26 profile fix measures a few millimetres — half a cell is comfortable
## and is still far too little to see as a waist, since the crown covers all of it.
const _RIM_INSET_CELLS := 0.5

## WHAT THE PLAYER HAS DONE TO THIS TREE — cut sites, committed fall direction, stress,
## cracks, lean. Owned by `tree_felling.gd` and NEVER READ HERE: this file holds wood and
## reports what the wood is doing; what a notch MEANS is the game's business.
##
## It lives on the trunk so that it travels with the tree. Every one of these was a bare
## variable on the game node, which was correct for exactly as long as there was one tree —
## with a forest, chopping tree B would inherit tree A's notch, fall line and crack
## progression, silently. See tree_cut_state.gd.
var cut := TreeCutState.new()

## THIS TREE'S IDENTITY, so that everything about one tree lives on the one object — which
## is the whole point of §3b. `source_mesh` is genuinely the trunk's own geometry;
## `def` is its TreeDef (A8: hardness, yields), stored here and NEVER READ HERE, for the
## same reason `cut` is. `species_id` / `species_index` identify the visual table row
## that supplied them, so a mixed stand never has to infer type from geometry.
var source_mesh: Mesh
var def: TreeDef
var species_id: StringName
var species_index := -1
## Which source-mesh surface is the trunk/bark. Explicit species metadata beats
## guessing from triangle count: tree_01 deliberately has more leaf triangles
## than bark triangles, so "largest surface" selects foliage.
var trunk_surface := -1
## Authored crown surfaces that separate from the timber when the tree falls.
## The indices come from the species table. Everything NOT listed here remains
## byte-for-byte authored wood and goes through bucking unchanged.
var canopy_surfaces: Array[int] = []
## Local Y where the visible trunk meets the ground. Imported root geometry may
## extend below this without becoming the voxel band or standing collider.
var trunk_base_y := -INF
## Longest carveable band to build, in metres; 0 is uncapped. A cost knob, set by the
## owner (`tree_felling.band_height_max`) — the band's grid is nx*ny*nz and ny grows
## straight out of this, so it is the one number standing between "the trunk is
## choppable as high as the player can reach" and voxelising a whole tree.
var band_height_max := 0.0

## The TEAR (set by the owner before the break; placeholders per Directive 3). A
## felled break is fibres letting go, not a saw cut, so both faces are roughened
## in the FIELD — the break surface is genuinely ragged geometry rather than a
## displaced plane.
var tear_amount := 0.0
var tear_noise: FastNoiseLite

## Measured at build — read-only for the owner.
var radius := 0.5             ## bare trunk radius (m)
var diameter := 1.0           ## ...and the width the holding wood is judged against
var band_max_radius := 0.5    ## how far the band's grid must reach — see `_band_max_radius`
var height := 1.0             ## full tree height (m)
var axis_xz := Vector2.ZERO   ## trunk centre line in the ground plane (local)
var band_lo := 0.0            ## bottom of the voxel band (local Y)
var band_hi := 0.0            ## ...and its top
var ground_y := 0.0           ## where the tree meets the dirt (local Y) — the butt, roots and all
var _crown_base := 0.0        ## where the crown's mesh actually starts (it laps down)
var _root_top := 0.0          ## ...and where the authored root flare is clipped (it laps up)
var _flare_top := 0.0         ## ...and where the root flare stops and the clear stem starts
## VOXELISE THE ROOTS FROM THE MESH rather than leaving them as an imported piece below the
## band. Set by the owner; see `_measure` for what it changes and why.
var voxel_roots := false

var _vol: WoodVolume
var _band_mi: Node3D              ## parent of the band's chunk meshes
var _chunks: Array[MeshInstance3D] = []
var _stump_mi: MeshInstance3D     ## replaces them once the tree has broken
var _upper_mi: MeshInstance3D
var _root_mi: MeshInstance3D      ## the authored root flare, below the band, never carved
## Which surfaces of the COMPOSED crown mesh are canopy. Not the same numbers as
## `canopy_surfaces`, which index the SOURCE: the crown is assembled here (sliced stem,
## its cut cap, then the canopy surfaces whole), so the indices move. Relying on them
## coinciding is exactly the kind of unstated assumption that has already cost this
## project two rounds of stale-surface bugs.
var _crown_canopy: Array[int] = []
var _bark_mat: Material
var _cut_mat: Material
var _picker: Area3D
var _standing_body: StaticBody3D   ## the tree, solid, while it is still standing
var _preview_mi: MeshInstance3D     ## the whole imported mesh, before the voxels exist
var _aabb: AABB
var _upper_volume := 0.0        # m³ of tree above the band
var _upper_centroid := Vector3.ZERO
var _full_area := 0.0           # section area of the untouched trunk (m²)
## ...and the untouched area of EVERY level, taken once at build. The yardstick a level's
## remaining wood is quoted against — see `holding_area`.
var _base_area := PackedFloat32Array()
## ...and how far the untouched wood reached in each of the SUPPORT_DIRS directions at
## every level. The load model's "has this side been opened up?" test is quoted against
## it, for the same reason — see `base_reach`.
var _base_sup: Array[PackedFloat32Array] = []
var _cuts := 0
var _removed := 0.0             # m³ the axe has taken out of the band
var _break_y := -1.0            # local height the tree snapped at, once felled
var _lean_angle := 0.0
var _lean_dir := Vector3.RIGHT
var _sections: Array[Dictionary] = []
var _sections_fresh := false
## Where the stem's centre sits at each `_BRANCH_BIN` of height, relative to `axis_xz`.
## The colliders read it, so a leaning trunk's stump is under its own butt.
var _centre_off := PackedVector2Array()
## How wide the stem is at each `_BRANCH_BIN`, measured from THAT bin's own centre.
## Kept from the same single cross-section scan `_centre_off` comes from, because the
## FELLED trunk's collider has to follow the wood up its whole length and a taper is
## half of that story — the wander is the other half.
var _bin_radius := PackedFloat32Array()


# ------------------------------------------------------------------ build
## Stand the tree up. `source_mesh` sits with its base at local y = 0. Nothing is
## carved yet — the first blow does that, wherever the player aims it.
##
## `band_height` is how much of the trunk becomes carveable wood, in metres, or
## **0 to take the whole clear trunk** — every bit of bare stem from the butt up to
## where the branches start. 0 is what the game ships with: a band that stops at an
## arbitrary height leaves the player clicking on trunk that does not respond, and
## the line where it stopped is visible. What the band must NOT do is reach up into
## the crown, because the field clamps anything wider than the trunk back to the
## trunk (`_PROFILE_CLAMP`) — so a band that covered the branches would replace them
## with a smooth cylinder and the tree would come out a bare pole.
func build(source_mesh: Mesh, cut_mat: Material, band_height: float, cell: float,
		cut_tile := 3.0, bark_tile := Vector2.ZERO, side_mat: Material = null) -> bool:
	if source_mesh == null:
		return false
	if not _measure(source_mesh, band_height, cell):
		return false
	_cut_mat = cut_mat
	# A previewed tree is showing its whole imported mesh (see `preview`); the band and the
	# clipped crown replace it. Freed AFTER the field is built, so a build that bails leaves
	# a tree standing rather than an invisible one.
	var was_previewing := _preview_mi

	_vol = WoodVolume.new()
	# ONLY THE DECLARED TRUNK SURFACE is measured. Everything else in the mesh — leaf
	# cards drooping past the stem, branches, and now the roots, which the band starts
	# above — is geometry a ray cast round the trunk would otherwise land on. See
	# WoodVolume._build_profile.
	if not _vol.build(source_mesh, band_lo, band_hi, axis_xz, band_max_radius,
			cell, _trunk_surfaces(source_mesh),
			_flare_top if voxel_roots else 0.0):
		return false
	_vol.cut_uv = cut_tile
	# LONG GRAIN on the near-vertical walls a chop leaves. Without it every cut face takes
	# the end-grain ring projection, which is a projection onto the horizontal plane and so
	# smears one row of texels the whole height of a kerf wall — the bright streaky ribbon
	# across the trunk Sam reported (2026-07-30). See `WoodVolume.side_mat`.
	_vol.side_mat = side_mat
	# THE ROOT FLARE'S BARK, on its own TRIPLANAR material — see `WoodVolume.root_mat`. The
	# band's cylindrical wrap is exact on a stem and degenerates into contour banding on a
	# buttress, because a root spreads through a huge range of bearings at almost no change
	# of height. Triplanar has no axis and so no such failure.
	#
	# Built HERE, from this trunk's own bark material and its own FITTED density, so the
	# roots' bark comes out the same size as the stem's without anybody supplying a number.
	if voxel_roots and _bark_mat is StandardMaterial3D:
		var rm := (_bark_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		rm.uv1_triplanar = true
		# `bark_uv.y` is the fitted repeats-per-metre up the trunk; triplanar works in the
		# same local metres, so this is the density the artist mapped, reused.
		var dens: float = absf(_vol.bark_uv.y)
		if dens < 0.01:
			dens = 1.0
		rm.uv1_scale = Vector3(dens, dens, dens)
		_vol.root_mat = rm
		_vol.root_below = _flare_top
	# END GRAIN: cut faces are mapped as one log round centred on this trunk's own axis,
	# so the growth rings line up with where the tree's centre actually is and the bark
	# ring in the texture lands on the bark.
	#
	# FITTED TO THE WIDEST WOOD IN THE BAND, not to the representative radius. The ring
	# texture is a single round on a WHITE field with texture_repeat off, so anything
	# mapped past its edge clamps to that white — and a notch is a bite at the PERIMETER,
	# which is precisely the part that overflowed. Every fresh cut face was coming out
	# blank white for the outer third of its area. Same bug, and the same fix, as the
	# slicer's `cap_fit_round` (2026-07-27); this path was simply never measured.
	#
	# This is the FALLBACK now; the round is fitted per level in `ring_prof` below.
	_vol.ring_radius = maxf(_vol.profile_max_radius, radius)
	if bark_tile != Vector2.ZERO:
		# An explicit override wins, and takes the fitted phase off with it: a hand-set
		# tiling has no reason to line up with the crown's.
		_vol.bark_uv = bark_tile
		_vol.bark_uv_offset = Vector2.ZERO
		_vol.drop_bark_uv_table()
	elif not _vol.bark_uv_fitted:
		# The source carries no usable trunk UVs to fit against. Fall back to matching
		# its average texel DENSITY, which is all the band could do before the fit
		# existed — the right scale only if the artist's mapping is isotropic, but far
		# better than an arbitrary number.
		var density := _bark_density(source_mesh, trunk_surface)
		_vol.bark_uv = Vector2(density * TAU * radius, density)
	# ...otherwise WoodVolume.build already measured the crown's own bark scale AND
	# phase off the source mesh, which is what makes the band's bark run continuously
	# into the crown's instead of restarting at the join.

	# The crown keeps its imported geometry: clip the source just BELOW the band top
	# (see _CROWN_OVERLAP) and hang the remainder off its own node, so it laps over
	# the band's rim rather than leaving a slit of daylight at the join.
	var clip_y := band_hi - cell * _CROWN_OVERLAP
	_crown_base = clip_y
	# THE BAND DUCKS UNDER THE CROWN over the lap. The two surfaces can never agree
	# exactly — one is an imported mesh, the other is surface-netted off a voxel field —
	# so the band's radius lands within about a quarter of a cell of the crown's and on
	# EITHER side of it around the ring. Where it landed outside, the band poked out
	# through the crown's bark and the crown's clip plane read as a hard ledge, with the
	# band's own ragged top row of cells showing below it. That is what Sam saw as the
	# two parts looking disconnected. Pulling the band in over the lap makes the crown
	# win everywhere, so the join is bark over bark with nothing showing through.
	# Rendering only: the FIELD is untouched, so the load model still measures the wood
	# that is really there.
	_vol.rim_lo = clip_y
	_vol.rim_hi = clip_y + cell
	# ...and the SAME at the bottom, where the tree's own root flare laps up over the
	# band's lower rim. The band no longer starts at the ground (see `_root_flare_height`),
	# so it has two open ends now and both want covering.
	# ...and NOTHING at the bottom when the roots are in the field: there is no imported
	# piece down there to lap over the band, so an inset would just pinch the foot of every
	# trunk for no reason.
	if not voxel_roots:
		_vol.rim_base_lo = _root_top - cell
		_vol.rim_base_hi = _root_top
	_vol.rim_inset = cell * _RIM_INSET_CELLS

	# THE STEM IS THE ONLY THING THAT GETS CUT UP. Slicing the whole source at the band
	# top threw away every triangle below it — which, now that the band starts above the
	# flare, is the roots — and it would also lop the bottom off any foliage hanging past
	# the clip. Canopy surfaces pass through whole; only the declared trunk surface is
	# divided, into the roots below the band and the crown above it.
	var stem := _surfaces_mesh(source_mesh, true)
	# Fitted round on the cut faces, like every other end-grain face in M5 — `_cut_mat` is one
	# growth-ring disc on a white field, so a cap mapped in metres clamps to white as soon as the
	# trunk is wider than a metre. Both caps are buried inside the band by design, but it costs
	# nothing to map them correctly and `tree_size_variation` makes trunks vary.
	var stem_above: Mesh = stem
	var top_cut := MeshSlicer.slice(stem, Plane(Vector3.UP, clip_y), _cut_mat, true)
	if top_cut.above != null:
		stem_above = top_cut.above
	_upper_mi = MeshInstance3D.new()
	_upper_mi.name = "Crown"
	_upper_mi.mesh = _compose_crown(stem_above, source_mesh)
	add_child(_upper_mi)

	# THE ROOTS, exactly as authored, never carved and never measured as load-bearing
	# section. They are the part of a tree a radial voxel field cannot describe.
	# CAPPED IN BARK, not end grain. Every other cut face in M5 is a fresh axe cut and
	# wants growth rings; this one is a seam between two halves of the same standing tree
	# and is never meant to be read as a cut at all. It is also the ONE cap that is not
	# fully buried — the band is deliberately tucked inside it at the rim (see the ramp
	# above), so a millimetre or two of it stands proud right where the player is looking.
	# In `_cut_mat` that sliver is a bright ring on a white field and reads as a slice;
	# in bark it reads as bark.
	# NO ROOTS PIECE when they are voxelised: they are part of the band's field and come out
	# of the same mesher, so there is nothing to hand over to and no rim to see.
	var bot_cut: Dictionary = {"above": null, "below": null}
	if not voxel_roots:
		bot_cut = MeshSlicer.slice(stem, Plane(Vector3.UP, _root_top), _bark_mat, true)
	if bot_cut.below != null:
		_root_mi = MeshInstance3D.new()
		_root_mi.name = "Roots"
		_root_mi.mesh = bot_cut.below
		add_child(_root_mi)

	# The band's geometry is split into vertical CHUNKS so a blow only re-surfaces the
	# heights it changed (see WoodVolume.chunk_mesh). This node is their parent and is
	# what `base_offset` measures, so the "the butt never moves" test still means the
	# same thing.
	_band_mi = Node3D.new()
	_band_mi.name = "Butt"
	add_child(_band_mi)
	for c in range(_vol.chunk_count()):
		var mi := MeshInstance3D.new()
		mi.name = "BandChunk%d" % c
		_band_mi.add_child(mi)
		_chunks.append(mi)
	# THE END-GRAIN ROUND IS FITTED PER LEVEL, to the wood that level actually holds.
	#
	# One radius for the whole band cannot serve this trunk any more. `_cut_mat` is a SINGLE
	# growth-ring disc on a WHITE field with `texture_repeat` off, so a face mapped past its
	# edge clamps to white — tinted by `cut_wood_tint` that is a flat grey patch, which is
	# what a chopped root flare rendered as. Widening the one radius to cover the buttresses
	# fixes that and breaks the other end: on tree_01 the flare reaches 1.81 m against a stem
	# of 0.74, so a stem cut would then use only the inner 41% of the disc and come out dark
	# and ringless. MEASURED both ways in render before this was written.
	#
	# So it is fitted where each cut actually is. Taken from `level_stats` HERE, before the
	# first remesh and before any blow, so it is the UNCUT wood — a profile that followed the
	# carve would make the rings breathe as the player chops.
	#
	# (A per-height fit was tried and reverted on 2026-07-30 as "no visible change". That was
	# true then: without `voxel_roots` the band is clear stem tapering ~1.3x. With the flare in
	# it the range is 2.4x, and it is the difference between wood and a grey patch.)
	var ring := PackedFloat32Array()
	for e in _vol.level_stats():
		var widest := 0.0
		for r in (e.sup as PackedFloat32Array):
			widest = maxf(widest, r)
		ring.append(widest)
	_vol.ring_prof = ring
	_remesh()
	_measure_upper(_upper_mi.mesh, clip_y)
	_full_area = _median_area()
	_base_area.resize(0)
	_base_sup.clear()
	for e in _vol.level_stats():
		_base_area.append(e.area)
		_base_sup.append((e.sup as PackedFloat32Array).duplicate())
	if was_previewing != null and is_instance_valid(was_previewing):
		was_previewing.queue_free()
		_preview_mi = null
	# A previewed tree already has both of these, fitted to the same measurements.
	if _picker == null:
		_build_picker()
	if _standing_body == null:
		_build_standing_body()
	return true


## STAND THE TREE UP CHEAPLY: the imported mesh as one MeshInstance3D, a pick volume, a
## collider, and every measurement `build()` would have taken. No voxel field.
##
## THIS IS WHAT MAKES A FOREST POSSIBLE (plan §3a, "this is the whole ballgame"). A tree's
## voxel field is ~27,000 samples plus a profile build — measured at 9.8x that for a
## whole-tree grid — and paying it for every tree in a stand at load is the thing that
## would make the forest unshippable. So a tree is cheap geometry until the player's first
## blow lands on it, and `build()` upgrades it in place.
##
## Everything a tree needs in order to be LOOKED AT, WALKED INTO and AIMED AT works here;
## only chopping needs the field. `is_built()` stays false, which is how the game knows.
func preview(mesh: Mesh, band_height: float, cell: float) -> bool:
	if mesh == null or not _measure(mesh, band_height, cell):
		return false
	source_mesh = mesh
	_preview_mi = MeshInstance3D.new()
	_preview_mi.name = "Whole"
	_preview_mi.mesh = mesh
	add_child(_preview_mi)
	_build_picker()
	_build_standing_body()
	return true


## True for a tree that is standing there as cheap geometry, waiting for its first blow.
func is_preview() -> bool:
	return _preview_mi != null and is_instance_valid(_preview_mi)


## A POINT ON THIS TRUNK'S CENTRE LINE, IN WORLD SPACE, at `local_y` up it.
##
## `axis_xz` is the trunk's centre line in the tree's OWN space and tree_01's is not at its
## mesh origin — so it has to go through the node's transform, not simply be added to
## `global_position`. That distinction did not exist while every tree stood unrotated at the
## world origin; the moment the stand gave each tree a random YAW, adding an unrotated local
## offset to a global position aimed the axe at a point beside the tree. The cut then missed
## the wood entirely while the site's depth counter went up regardless, so a tree could be
## "chopped" indefinitely with nothing happening to it.
##
## Anything that needs to know where the trunk IS goes through here.
func axis_point(local_y := 0.0) -> Vector3:
	return global_transform * Vector3(axis_xz.x, local_y, axis_xz.y)


## The measurements both paths need, taken off the source mesh alone. Split out of `build`
## so a previewed tree is measured EXACTLY as a built one is — a preview whose radius or
## band disagreed with what the voxel build would produce would move the tree's collider
## and its pick volume the instant it was first struck.
func _measure(mesh: Mesh, band_height: float, cell: float) -> bool:
	_aabb = mesh.get_aabb()
	ground_y = maxf(_aabb.position.y, trunk_base_y)
	height = _aabb.end.y - ground_y
	_bark_mat = _surface_material(mesh, trunk_surface)
	var stem_top := _trunk_surface_top(mesh)
	axis_xz = _base_axis(mesh, stem_top, trunk_surface, ground_y)
	var cap: float = band_height_max if band_height_max > 0.0 else INF
	# ONE cross-section scan of the whole trunk surface. Everything below reads it.
	var bins := _width_bins(mesh, ground_y)
	# THE BAND STARTS ABOVE THE ROOT FLARE (2026-07-29). See `_root_flare_height` — it
	# reads the taper, so it needs no radius and there is no ordering problem here.
	# THE FLARE TOP, which is where the trunk stops being roots and starts being a stem.
	_flare_top = minf(ground_y + _root_flare_height(bins), stem_top - cell * 8.0)
	# THE BAND STARTS AT THE GROUND when the roots are voxelised from the mesh, and above
	# the flare when they are not.
	#
	# It used to always start above the flare, because the field is a RADIAL PROFILE — one
	# radius per (level, angle) about the trunk axis — which cannot describe a buttress you
	# can see daylight under, so everything below was left as imported mesh. That imported
	# piece's cut rim IS the ring round the butt of every tree (Sam, 2026-07-30: "worth
	# doing to remove those seams"), and no arrangement of the hand-over could hide it —
	# whichever surface is outermost there shows its own rim. So there is no hand-over any
	# more: the roots are part of the same field, filled from the mesh instead of from the
	# profile, and the whole trunk is one surface off one mesher.
	band_lo = _flare_top if not voxel_roots else ground_y
	radius = _trunk_radius(bins, _flare_top, minf(_flare_top + cap, stem_top))
	var want: float = band_height if band_height > 0.0 else _clear_trunk_height(bins)
	# Measured from the FLARE TOP, not from the band's floor: how much clear stem there is
	# and how thick it is are properties of the stem, and letting the roots into either
	# would drag the radius out and shorten the reach for no reason.
	band_hi = minf(_flare_top + maxf(minf(want, cap), cell * 4.0), stem_top - cell)
	radius = _trunk_radius(bins, _flare_top, band_hi)
	diameter = radius * 2.0
	# THE AXIS IS RE-CENTRED ON THE BAND, and that is not cosmetic. `_base_axis` gives the
	# centre line at the BUTT, and the generator leans and wanders every trunk it makes, so
	# by the top of a 3 m band the stem has moved 0.4 m sideways on a 0.5 m radius — far
	# enough that the butt's axis is OUTSIDE the wood up there. The voxel field is a radial
	# profile cast FROM that axis, so rays pointing the other way miss the trunk entirely,
	# `_fill_profile_gaps` fills what they missed from their neighbours, and the top of the
	# band comes out as a swollen blob: tree_02's section jumped from 0.455 m² to 1.011 m²
	# in one step. That is the rest of Sam's "geom deformation that looks kinda buggy".
	# Centring on the band's own middle also shrinks the grid it needs — nx 40 back to 26,
	# which is 2.4x fewer samples for the same wood.
	_recentre_on_band(bins)
	_centre_off = bins.offset
	_bin_radius = bins.radius
	band_max_radius = _band_max_radius(bins)
	# THE GRID HAS TO REACH THE ROOTS when they are part of the field. `_band_max_radius`
	# measures the band's own levels, and with `voxel_roots` those now include the flare —
	# but the flare spreads further than anything above it, so this is the one measurement
	# that must NOT be clamped to the stem's width or the buttresses fall off the edge of
	# the grid.
	if voxel_roots:
		band_max_radius = maxf(band_max_radius, _flare_max_radius(bins))
	# The crown's base is only known once the band top is, and the standing collider is
	# sized from it — so a preview and a build agree on the trunk's solid height too.
	_crown_base = band_hi - cell * _CROWN_OVERLAP
	_root_top = band_lo + cell * _CROWN_OVERLAP
	return band_hi > band_lo


## The load the band carries: volume and centre of mass of everything above it.
## An open or inside-out mesh reads ~zero by the divergence theorem, so a
## cylinder from the measured trunk radius backstops it — wrong-ish for a very
## branchy crown, never absurd.
##
## `clip_y` is where the crown's mesh was actually cut, which is a little BELOW the
## band top (see _CROWN_OVERLAP). The wood in that overlap is in the crown mesh AND in
## the band's own levels, so it is taken back out here — measured off the band rather
## than assumed, so it is exact — or the tree would weigh more than it is and press
## down on its own hinge with wood that is already holding it up.
func _measure_upper(upper: Mesh, clip_y: float) -> void:
	# Leaf cards are open planes, not cubic metres of load-bearing timber. Feeding
	# them through the divergence-theorem volume can produce a huge fictitious
	# crown mass, which made a newly-authored tree fail on its opening axe blow.
	# Measure the exact authored WOODY surfaces plus the slicer's closing cap.
	var vc := MeshUtils.mesh_volume_centroid(_wood_mesh(upper))
	_upper_volume = vc.volume
	_upper_centroid = vc.centroid
	if _upper_volume <= 0.005:
		_upper_volume = PI * radius * radius * maxf(_aabb.end.y - clip_y, 0.01)
		_upper_centroid = Vector3(axis_xz.x, (clip_y + _aabb.end.y) * 0.5, axis_xz.y)
	var slab := 0.0
	var moment := Vector3.ZERO
	for e in _vol.level_stats():
		if e.y > clip_y:
			var dv: float = e.area * _vol.cell
			slab += dv
			moment += Vector3(axis_xz.x + e.cx, e.y, axis_xz.y + e.cz) * dv
	if slab > 0.0 and slab < _upper_volume:
		var m := _upper_centroid * _upper_volume - moment
		_upper_volume -= slab
		_upper_centroid = m / _upper_volume


## The click volume: a cylinder around the WHOLE trunk, on the pick layer and
## colliding with nothing, exactly like M4's on-block pieces so one ray query
## serves both mini-games.
func _build_picker() -> void:
	_picker = Area3D.new()
	_picker.name = "TreePicker"
	_picker.collision_layer = PICK_LAYER
	_picker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	# NOT padded for the lean, deliberately. The axis is the band's centre line and the
	# band's ends sit a little off it, so a hair of the silhouette at the very top and
	# bottom of the band is not pickable — which is much the better trade: `_decompose`
	# reads BOTH the side and the angle of entry off how far the hit sits from the axis,
	# so a fat pick volume does not merely add reach, it reports every click as further
	# round the trunk than it was and quietly skews every cut.
	cyl.radius = radius * _PICK_RADIUS_PAD
	cyl.height = height
	cs.shape = cyl
	cs.position = Vector3(axis_xz.x, ground_y + height * 0.5, axis_xz.y)
	_picker.add_child(cs)
	add_child(_picker)


## Re-surface only the chunks of the band whose wood actually changed.
func _remesh() -> void:
	for c in _vol.take_dirty_chunks():
		if c >= 0 and c < _chunks.size() and is_instance_valid(_chunks[c]):
			_chunks[c].mesh = _vol.chunk_mesh(c, _bark_mat, _cut_mat)
	_sections_fresh = false


# ------------------------------------------------------------------ strike
## Take a bite. `world_planes` bound a convex solid (inside = every plane's
## distance <= 0) — the wood the axe displaces — and `world_bounds` must contain
## it. Everything is given in world space and converted here, so the caller can
## think in swing directions instead of grid indices.
##
## Returns { "ok", "volume": m³ taken, "chip": ArrayMesh|null, "chip_pos": world,
## "freed": Array of { mesh, world_pos, volume } }. `freed` is the payoff: any
## wood the blow left unsupported comes away on its own — which is how the notch
## wedge pops out on the blow that joins its roof cut to its floor cut, and why
## no piece of this tree can ever be left floating.
##
## `want_meshes` is false in the game: the debris a blow throws is splinters now, not
## the carved geometry (Sam, 2026-07-25 — a bite is a thin flake and flakes read as
## flat discs on the ground), so surfacing the removed voxels is work nobody looks at.
## The volumes and positions are reported either way. Tests pass true to inspect the
## geometry that came out.
## `defer_remesh` leaves the band's geometry stale so the caller can land SEVERAL carves
## and pay for surfacing them once. The opening blow on a fresh cut lays in two slabs at
## once (the manual's notch angles), and it was rebuilding the whole band between them —
## which is why the first blow on every cut cost half as much again as the ones after it.
## A caller that defers MUST call `finish_chop()` before reading anything back.
func chop(world_planes: Array[Plane], world_bounds: AABB, want_meshes := false,
		defer_remesh := false) -> Dictionary:
	var out := {"ok": false, "volume": 0.0, "chip": null, "chip_pos": Vector3.ZERO,
		"freed": []}
	if _vol == null or has_broken():
		return out
	var inv := global_transform.affine_inverse()
	var local: Array[Plane] = []
	for p in world_planes:
		local.append(MeshUtils.plane_to_local(p, global_transform))
	var lb := inv * world_bounds

	var cut := _vol.carve(local, lb, _cut_mat if want_meshes else null)
	if cut.volume <= 0.0:
		return out
	_cuts += 1
	_removed += cut.volume
	out.ok = true
	out.volume = cut.volume
	out.chip = cut.chip
	out.chip_pos = global_transform * (cut.centre as Vector3)

	var freed: Array = []
	for piece in _vol.remove_floating(_cut_mat if want_meshes else null):
		freed.append({
			"mesh": piece.mesh,
			"world_pos": global_transform * (piece.centre as Vector3),
			"volume": piece.volume,
		})
	out.freed = freed
	if not defer_remesh:
		_remesh()
	return out


## Surface whatever the deferred carves left. Safe to call when nothing was deferred,
## and safe on a tree that has already broken or failed to build.
func finish_chop() -> void:
	if is_built() and not has_broken():
		_remesh()


# ---------------------------------------------------------------- metrics
## Every horizontal section of the band, with the load it is carrying. This is
## the whole of what the tree tells the game: area and second moments of the wood
## actually left at each height (measured off the voxels, air between remnants
## counting for nothing), and the weight standing on it.
##
## Each entry: { "y", "area" (m²), "cx","cz" (centroid offset from the axis, m),
## "mxx","mzz","mxz" (second moments about the axis, m⁴), "load_volume" (m³ above),
## "load_cx","load_cz" (that load's horizontal centre, from the axis),
## "load_cy" (its height) }.
func sections() -> Array[Dictionary]:
	if _sections_fresh:
		return _sections
	var lv := _vol.level_stats()
	var v := _upper_volume
	# The crown carries the lean, and a leaning crown hangs its weight further
	# out — which is the arm the load model bends the tree with, so it has to be
	# the LEANED position, not the one it was measured in.
	var crown := _upper_centroid
	if _upper_mi != null and is_instance_valid(_upper_mi):
		crown = _upper_mi.transform * crown
	var m := Vector3(crown.x - axis_xz.x, crown.y, crown.z - axis_xz.y) * _upper_volume
	for j in range(lv.size() - 1, -1, -1):
		var e: Dictionary = lv[j]
		e["load_volume"] = v
		if v > 0.0001:
			e["load_cx"] = m.x / v
			e["load_cy"] = m.y / v
			e["load_cz"] = m.z / v
		else:
			e["load_cx"] = 0.0
			e["load_cy"] = e.y
			e["load_cz"] = 0.0
		var dv: float = e.area * _vol.cell
		v += dv
		m += Vector3(e.cx, e.y, e.cz) * dv
	_sections = lv
	_sections_fresh = true
	return _sections


## Section area of the untouched trunk (m²) — the yardstick every "how much wood
## is left" number is quoted against. Taken as the median over the band so a root
## flare at the bottom or the clipped top level cannot skew it.
func _median_area() -> float:
	var areas: Array[float] = []
	for e in _vol.level_stats():
		if e.area > 0.0:
			areas.append(e.area)
	if areas.is_empty():
		return PI * radius * radius
	areas.sort()
	return areas[areas.size() / 2]


func full_area() -> float:
	return _full_area


## HOW FAR THE UNTOUCHED WOOD REACHED at level `j`, per SUPPORT_DIRS direction (m).
##
## The yardstick for "has the axe opened this side up?", and it has to be PER LEVEL for
## the same reason `holding_area` does. The load model used to test the measured reach
## against `radius * a fraction` — one number for the whole band, which was fine while the
## band was a metre of near-parallel trunk. Over a three-metre band these trees taper by a
## factor of three, so a single threshold is above the trunk's real width at the top of the
## band (every level reads as already open, in every direction, on a tree nobody has
## touched) and below it at the butt (no cut, however deep, ever reads as open — the tree
## simply refuses to hinge and has to be crushed instead).
##
## Empty for a level with no record, which callers must treat as "no opinion".
func base_reach(j: int) -> PackedFloat32Array:
	if j < 0 or j >= _base_sup.size():
		return PackedFloat32Array()
	return _base_sup[j]


## A level's own UNCUT area (m²) — the yardstick `holding_area` and the load model quote
## against. Test/diagnostic seam: without it a caller can only see the CURRENT area, which
## says nothing about how much of that level the axe has taken.
func debug_base_area(j: int) -> float:
	return _base_area[j] if j >= 0 and j < _base_area.size() else 0.0


## Where the root flare stops and the clear stem starts (local Y). Diagnostic seam: with
## `voxel_roots` the band starts at the dirt and this is the only thing that still says
## which part of it is buttress.
func debug_flare_top() -> float:
	return _flare_top


## Wood left at the MOST-CUT height in the band (m²) — the holding wood. This is the
## honest answer to "how much is still keeping it up", and unlike the old thickness probe
## it cannot be fooled by two remnants with air between them.
##
## "Most cut" is measured against each level's OWN UNCUT AREA, not against the band as a
## whole, and that distinction became load-bearing on 2026-07-29 when the band grew from
## under a metre to three. These trunks taper hard — tree_01 runs 1.32 m² at the butt down
## to 0.45 m² three metres up — so the plain minimum over the band is the TOP OF THE BAND
## on a tree nobody has touched. Everything quoted against it inherited that: an untouched
## tree reported a notch two thirds of the way through, so `_notch_to` stopped before it
## had cut anything and the tree could never be felled. The same mistake, in the same
## shape, as the "one continuous notch" check fixed on 2026-07-25.
func holding_area() -> float:
	var s := sections()
	var best := INF
	var area := _full_area
	for j in range(1, s.size() - 1):
		var base: float = _base_area[j] if j < _base_area.size() else 0.0
		if base <= 0.0:
			continue
		var frac: float = s[j].area / base
		if frac < best:
			best = frac
			area = s[j].area
	return area


## Normalised chopping progress, 0 = untouched .. 1 = cut clean through. Derived from the
## wood rather than tracked, so it always agrees with what is there — and per level
## against its own uncut section, so a tapering trunk does not read as pre-notched.
func notch_depth_frac() -> float:
	var s := sections()
	var best := 1.0
	for j in range(1, s.size() - 1):
		var base: float = _base_area[j] if j < _base_area.size() else 0.0
		if base > 0.0:
			best = minf(best, s[j].area / base)
	return clampf(1.0 - best, 0.0, 1.0)


## Wood taken out of the band so far (m³).
func removed_volume() -> float:
	return _removed


## False if build() bailed (or the tree has already been cleared away).
func is_built() -> bool:
	return _vol != null and _band_mi != null and is_instance_valid(_band_mi)


func has_cut() -> bool:
	return _cuts > 0


func cut_count() -> int:
	return _cuts


func picker() -> Area3D:
	return _picker


## THE HIGHEST CARVED WOOD THE PLAYER CAN ACTUALLY SEE (local Y).
##
## The band's own field runs all the way to `band_hi`, but the crown's imported mesh is
## clipped `_CROWN_OVERLAP` cells BELOW that and laps down over the band's rim (which is
## itself pulled in under it by `rim_inset`) — so the top 14 cm of the band is behind the
## crown by construction, and a notch carved up there is invisible however much wood it
## takes out. Anything AIMING at this tree wants this height, not `band_hi`.
func crown_base() -> float:
	return _crown_base


func volume() -> WoodVolume:
	return _vol


## The band as ONE mesh — a test and dev-tool seam, not something the game draws. The
## live band is drawn as chunks (see `_remesh`), so this rebuilds the whole thing; do not
## call it per frame. After the break it hands back the stump, which really is one mesh.
func band_mesh() -> Mesh:
	if _stump_mi != null and is_instance_valid(_stump_mi):
		return _stump_mi.mesh
	if _vol == null or not is_built():
		return null
	return _vol.build_mesh(_bark_mat, _cut_mat)


func break_height() -> float:
	return _break_y


func has_broken() -> bool:
	return _break_y >= 0.0


## Where the wood starts along a swing: march into the band and report the face
## the axe will actually meet. As the notch deepens the same aim lands further
## in, which is what makes a cut advance without anything telling it to.
func surface_along(world_from: Vector3, world_dir: Vector3, max_dist: float) -> Dictionary:
	var inv := global_transform.affine_inverse()
	var hit := _vol.first_solid(inv * world_from, inv.basis * world_dir, max_dist)
	return {"hit": hit.hit, "point": global_transform * (hit.point as Vector3),
		"dist": hit.dist}


# ------------------------------------------------------------------- fall
## Lean the tree `angle` radians toward `dir` — the holding wood bending under a load
## it can no longer carry.
##
## Only the CROWN swings. The butt is voxels and stays exactly where it is, so the base
## can never lift out of the dirt (the old whole-tree pivot did, and it read as a tree
## that was not rooted).
##
## IT PIVOTS ON THE CROWN'S OWN BASE, and it has to. This used to pivot on the cut —
## the height the wood was failing at, which is where a real tree bends — and that
## swings the crown's base sideways by (crown base - cut) x sin(angle). With the old
## 1.3 m band and a cut low down that was a couple of centimetres and passed for bark
## relief. Now that the band is the whole clear trunk the crown starts at 2.16 m, and
## the same five degrees moved its base 14.5 cm across a trunk 0.47 m in radius: the
## crown visibly slid off the top of the carved butt, part way through chopping, which
## is what Sam saw as the part above the voxels not connecting and sliding off before
## the cut was finished. Pivoting on the joint keeps the two halves attached and still
## tips the tree the way it is going, which is the whole job of the tell.
func set_lean(angle: float, dir: Vector3) -> void:
	if has_broken() or _upper_mi == null or not is_instance_valid(_upper_mi):
		return
	_lean_angle = angle
	var horiz := Vector3(dir.x, 0.0, dir.z)
	if horiz.length() > 0.0001:
		_lean_dir = horiz.normalized()
	if is_zero_approx(angle):
		_upper_mi.transform = Transform3D.IDENTITY
		return
	var rot := lean_basis()
	var pivot := Vector3(axis_xz.x, _crown_base, axis_xz.y)
	_upper_mi.transform = Transform3D(rot, pivot - rot * pivot)


## The current lean as a rotation basis (identity at zero angle).
func lean_basis() -> Basis:
	if is_zero_approx(_lean_angle) or _lean_dir.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(Vector3.UP.cross(_lean_dir).normalized(), _lean_angle)


## How far the base has shifted from rest — the test seam for "the base stays
## planted". The butt is voxels and is never transformed, so this is always 0.
func base_offset() -> float:
	if _band_mi == null or not is_instance_valid(_band_mi):
		return 0.0
	return _band_mi.transform.origin.length()


## Break the tree at local height `break_y`, pivoting on `pivot_local` — the
## holding wood's own centre, which is what the tree actually hangs off.
##
## The band is meshed twice against the same field, clipped either side of the
## break: the stump keeps the wood below (carved notch and all), the tree takes
## the wood above plus the crown, and the two faces meet exactly. The clip is
## roughened in the FIELD by `tear_amount`, so the break is genuinely ragged
## geometry — fibres letting go, not a planed cut.
##
## Returns { "meshes": Array[MeshInstance3D] (to be re-parented by the caller),
## "canopy": the authored branch/foliage MeshInstance3D that stays attached
## through the fall and despawns on landing,
## "offset": the local offset to give each of them under the pivot,
## "pivot_world": where the hinge is, "length": how much tree is coming down,
## "volume": its m³ }. `meshes` is empty if the tree cannot break there.
##
## The imported crown is split by its AUTHORED surface boundaries: declared
## canopy surfaces are handed back separately, and every other triangle remains
## exact authored timber. No generated replacement geometry is used here.
func detach_above(break_y: float, pivot_local: Vector3) -> Dictionary:
	var freed: Array[MeshInstance3D] = []
	var out := {"meshes": freed, "offset": Vector3.ZERO, "pivot_world": Vector3.ZERO,
		"length": 0.0, "volume": 0.0, "canopy": null, "slices": [] as Array[Dictionary]}
	if not is_built() or has_broken():
		return out
	var y := clampf(break_y, band_lo + _vol.cell, band_hi - _vol.cell)
	_break_y = y

	var falling := MeshInstance3D.new()
	falling.name = "BrokenButt"
	falling.mesh = _vol.build_mesh(_bark_mat, _cut_mat, y, INF, tear_amount, tear_noise)
	freed.append(falling)
	var above := 0.0
	for e in sections():
		if e.y > y:
			above += e.area * _vol.cell
	out.volume = above + _upper_volume

	if _upper_mi != null and is_instance_valid(_upper_mi):
		# Separate only the explicitly-authored canopy surfaces. The caller
		# keeps this mesh attached through the fall and removes it on landing.
		var foliage := _foliage_mesh(_upper_mi.mesh)
		if foliage.get_surface_count() > 0:
			var leaves := MeshInstance3D.new()
			leaves.name = "ShedCanopy"
			leaves.mesh = foliage
			# Its lean transform is KEPT: the canopy is already bent the way the
			# tree was about to go, so separating it must not snap it upright.
			leaves.transform = _upper_mi.transform
			out.canopy = leaves

		# Everything else is the original authored trunk mesh, with its vertex
		# payload and materials copied exactly. Older assets that still combine
		# trunk and branches on one surface keep those branches until re-exported
		# with the generator's separate canopy-bark material.
		var woody := _wood_mesh(_upper_mi.mesh)
		if woody.get_surface_count() > 0:
			var crown := MeshInstance3D.new()
			crown.name = "WoodyCrown"
			crown.mesh = woody
			crown.transform = _upper_mi.transform
			freed.append(crown)
		remove_child(_upper_mi)
		_upper_mi.queue_free()
		_upper_mi = null
		_upper_volume = 0.0
	# HOW LONG THE TIMBER IS — measured off the WOOD that is actually coming down, which is
	# what `freed` holds, and not off the source mesh's AABB.
	#
	# The AABB is the whole tree, foliage included, and that was fine for exactly as long as
	# every tree's leaves stopped where its wood did. tree_01's authored trunk tops out at
	# 8.82 m while its leaf cards reach 13.59 m, so the AABB reported a 12.8 m trunk coming
	# off a 7.4 m piece of wood. Everything sized off this length was then sized off leaves:
	# the falling trunk's collision cylinder, the tip speed the landing impact is scaled by,
	# the line of debris the landing kicks up, the A3 size tier — and `_min_log`, which
	# divides it by `buck_target_logs`, so the "about five logs, never coins" rule Sam asked
	# for produced two logs and a remainder BELOW its own stated minimum.
	#
	# It only became visible when the leaves were correctly declared as canopy and left the
	# bucked mesh; before that they were being cut up as timber, which is its own problem.
	var top := y
	for mi in freed:
		if mi.mesh == null:
			continue
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	out.length = maxf(top - y, 0.01)

	var pivot := Vector3(pivot_local.x, y, pivot_local.z)
	out.offset = -pivot
	out.pivot_world = global_transform * pivot
	# THE SHAPE OF WHAT IS COMING DOWN, in the frame the meshes are about to be moved
	# into — reported here rather than at the caller precisely because the meshes are
	# re-origined on `out.offset` and two frames is one too many to keep straight. See
	# `timber_slices`, and handoff/09 §1 for the bug this replaces.
	var slices := timber_slices(y, top)
	var placed: Array[Dictionary] = []
	for s in slices:
		placed.append({
			"y": (s.y as float) - pivot.y,
			"height": s.height,
			"centre": (s.centre as Vector2) - Vector2(pivot.x, pivot.z),
			"radius": s.radius})
	out["slices"] = placed

	# The stump keeps the wood below the break and gains a collider. The chunks go: a
	# stump is surfaced once and never again, so it is one mesh, and leaving the chunks
	# would draw the whole uncut band straight through it.
	for mi in _chunks:
		if is_instance_valid(mi):
			mi.queue_free()
	_chunks.clear()
	_stump_mi = MeshInstance3D.new()
	_stump_mi.name = "Stump"
	_stump_mi.mesh = _vol.build_mesh(_bark_mat, _cut_mat, -INF, y, tear_amount, tear_noise)
	_band_mi.add_child(_stump_mi)
	if _picker != null:
		_picker.queue_free()
		_picker = null
	# The STANDING trunk's collider goes with the standing trunk. It must not outlive
	# it: it is TIMBER, and the trunk now coming down is TIMBER too, so a leftover would
	# be an invisible pillar for the fall to jam against.
	if _standing_body != null and is_instance_valid(_standing_body):
		_standing_body.queue_free()
		_standing_body = null
	_build_stump_body(y)
	_sections_fresh = false
	return out


## Copy the crown surfaces that are canopy — branches and foliage, which separate from
## the timber on landing.
func _foliage_mesh(mesh: Mesh) -> ArrayMesh:
	return _copy_surfaces(mesh, _crown_canopy, true)


## Copy every crown surface that is NOT canopy. This is deliberately a surface copy, not
## a reconstruction: positions, normals, tangents, UVs, colours, indices and materials
## all stay exactly as exported.
func _wood_mesh(mesh: Mesh) -> ArrayMesh:
	return _copy_surfaces(mesh, _crown_canopy, false)


## Surfaces of `mesh` whose index is (or is not) in `which`.
func _copy_surfaces(mesh: Mesh, which: Array[int], keep: bool) -> ArrayMesh:
	var out := ArrayMesh.new()
	if mesh == null:
		return out
	for si in range(mesh.get_surface_count()):
		if which.has(si) != keep:
			continue
		var mat := mesh.surface_get_material(si)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(si))
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## The source's surfaces that ARE the trunk (`keep` true) or are not (`keep` false).
## A mesh with no declared trunk surface — a test cylinder, legacy art — is all trunk,
## which keeps the old whole-mesh behaviour exactly.
func _surfaces_mesh(mesh: Mesh, keep: bool) -> ArrayMesh:
	if mesh == null:
		return ArrayMesh.new()
	var trunk_only: Array[int] = _trunk_surface_list(mesh)
	return _copy_surfaces(mesh, trunk_only, keep)


func _trunk_surface_list(mesh: Mesh) -> Array[int]:
	var out: Array[int] = []
	if mesh == null:
		return out
	if trunk_surface >= 0 and trunk_surface < mesh.get_surface_count():
		out.append(trunk_surface)
		return out
	for si in range(mesh.get_surface_count()):
		out.append(si)
	return out


## ...and the same list as the packed form WoodVolume.build takes.
func _trunk_surfaces(mesh: Mesh) -> PackedInt32Array:
	var out := PackedInt32Array()
	if mesh == null or trunk_surface < 0 or trunk_surface >= mesh.get_surface_count():
		return out          # empty means "all of them" — a bare test cylinder
	out.append(trunk_surface)
	return out


## Assemble the crown: the stem above the band (with its cut cap), then every canopy
## surface of the source, whole and untouched. Records which of the RESULT's surfaces are
## canopy, because the indices do not survive the assembly — the slicer drops surfaces
## that end up empty on a side and appends its cap at the end, so nothing about the
## source's numbering carries over.
func _compose_crown(stem_above: Mesh, source: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	_crown_canopy.clear()
	if stem_above != null:
		for si in range(stem_above.get_surface_count()):
			var mat := stem_above.surface_get_material(si)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				stem_above.surface_get_arrays(si))
			if mat != null:
				out.surface_set_material(out.get_surface_count() - 1, mat)
	for si in range(source.get_surface_count()):
		if not canopy_surfaces.has(si):
			continue
		var mat := source.surface_get_material(si)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(si))
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
		_crown_canopy.append(out.get_surface_count() - 1)
	return out


## A static collider for the STANDING trunk, so the player cannot walk through the tree
## they are chopping.
##
## New with first person (2026-07-26). A standing tree never had one and never needed
## one: nothing in the game could move, so nothing could walk into it. Only the STUMP
## got a collider, and only once the tree had already come down. `handoff/08_FPS_FOREST.md`
## §1 asks for the player to be stopped by "the stump, a standing trunk or a felled log",
## and two of those three were already true.
##
## One cylinder on the bare stem, not a fitted hull: the crown is branches, and a player
## walking into the outer twigs of a tree and stopping dead reads far worse than walking
## through them. It is deliberately NOT re-fitted as the trunk is carved — a notch is a
## bite out of one face, and shrinking the collider to follow it would let the player
## stand inside the tree they are felling.
func _build_standing_body() -> void:
	# From the DIRT, not from the band. The band starts above the root flare now, and a
	# collider that started with it would leave the bottom half-metre of every tree open
	# for the player to walk into.
	var h := maxf(_crown_base - ground_y, _MIN_BAND)
	var body := StaticBody3D.new()
	body.name = "TrunkBody"
	# Timber, exactly like the stump it becomes: splinters pass straight through it.
	body.collision_layer = TIMBER_LAYER
	body.collision_mask = TIMBER_MASK
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = h
	cs.shape = cyl
	var mid := centre_offset(ground_y + h * 0.5)
	cs.position = Vector3(axis_xz.x + mid.x, ground_y + h * 0.5, axis_xz.y + mid.y)
	body.add_child(cs)
	add_child(body)
	_standing_body = body


## A static collider for the stump so chips and the landing trunk rest on it rather than
## through it, and so a player walks into it rather than through it.
##
## A STACK OF SLABS FOLLOWING THE WOOD, measured level by level — not a neck cylinder on
## top of a full-width base one, which is what it was until 2026-07-31.
##
## WHY IT CHANGED. That arrangement had two failures and `voxel_roots` triggered both at
## once, because the roots being carveable is exactly what lets the player cut LOW:
##   - the neck's height had a MINIMUM of `_NECK_BAND`, so on a stump shorter than that
##     the neck was the whole stump and the base cylinder was never built at all. The base
##     is the part that is actually under the tree, so the stump became one small disc
##     sized off the notch's remnant and sitting at that remnant's centre — MEASURED:
##     0.5 m off the trunk's axis on both species, with a ray at ankle height passing
##     straight THROUGH the stump at 0.1, 0.2 and 0.4 m.
##   - the base cylinder used `radius`, the STEM's. A stump that is mostly root flare is
##     far wider than the stem it holds up (tree_01: 2.433 m² at the dirt against the
##     stem's 0.82 m², i.e. 0.88 m equivalent radius against 0.51).
##
## Slabs fix both without a special case: they cannot vanish, and each one is sized where
## it sits. The wood is measured from `sections()`, which is the CARVED field — so the
## notch is still honoured and a trunk that ends up back on the stump still sits on the
## holding wood rather than on a full-width disc that was never there. That was the whole
## point of the neck, and it survives as a property of the measurement instead of as a
## special case. Below the band (the authored roots, when they are not voxelised) there is
## no field to read, so `timber_slices` measures the source mesh there instead.
func _build_stump_body(top_y: float) -> void:
	# ...down to the dirt, for the same reason the standing body is: the roots below
	# `band_lo` are authored mesh and still want a collider under them.
	var base := ground_y
	var body := StaticBody3D.new()
	body.name = "StumpBody"
	# Timber, not world: splinters pass straight through it (see TIMBER_LAYER).
	body.collision_layer = TIMBER_LAYER
	body.collision_mask = TIMBER_MASK

	# THE CARVED PART, off the field's own levels. Grouped into slabs rather than one per
	# level because a level is one voxel cell tall and a stump would collect dozens.
	var lo := maxf(base, band_lo)
	if top_y > lo + 0.02:
		var n := maxi(int(ceil((top_y - lo) / _STUMP_SLAB)), 1)
		var h := (top_y - lo) / float(n)
		for i in range(n):
			var y0 := lo + h * float(i)
			var y1 := y0 + h
			# The THINNEST section the slab spans, at that section's own centre. A slab is
			# a solid, so it must not claim wood the axe has taken out of any part of it.
			var best := INF
			var centre := Vector2.ZERO
			for e in sections():
				var y: float = e.y
				if y < y0 - _vol.cell or y > y1 + _vol.cell:
					continue
				if e.area < best:
					best = e.area
					centre = Vector2(e.cx, e.cz)
			if is_inf(best) or best <= 0.005:
				continue
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(sqrt(best / PI), 0.03)
			cyl.height = h
			cs.shape = cyl
			cs.position = Vector3(axis_xz.x + centre.x, (y0 + y1) * 0.5, axis_xz.y + centre.y)
			body.add_child(cs)

	# ...AND THE AUTHORED ROOTS UNDER IT, when they are not in the field. No level stats
	# exist down there, so this is the source mesh's own measured shape.
	if lo > base + 0.02:
		for s in timber_slices(base, minf(lo, top_y), _STUMP_SLAB):
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(s.radius, 0.03)
			cyl.height = maxf(s.height, 0.02)
			cs.shape = cyl
			var c: Vector2 = s.centre
			cs.position = Vector3(c.x, s.y, c.y)
			body.add_child(cs)
	add_child(body)


func _section_at(y: float) -> Dictionary:
	var s := sections()
	if s.is_empty():
		return {}
	return s[clampi(_vol.level_of(y), 0, s.size() - 1)]


# --------------------------------------------------------------- measuring
## Trunk centre line, taken from the butt of the tree (the lowest 5%) so branches higher
## up cannot drag it sideways.
##
## 5% OF THE STEM, not of the whole tree. The AABB is the FOLIAGE's, which on tree_01
## reaches 12.2 m against an 8.8 m stem, so the "butt" this averaged over was the lowest
## 0.61 m — the entire root flare, root spurs and all.
func _base_axis(mesh: Mesh, top_y: float, surface := -1, base_y := -INF) -> Vector2:
	var base := maxf(_aabb.position.y, base_y)
	var cut := base + (top_y - base) * 0.05
	var sum := Vector2.ZERO
	var n := 0
	for v in _surface_vertices(mesh, surface):
		if v.y >= base and v.y <= cut:
			sum += Vector2(v.x, v.z)
			n += 1
	return sum / n if n > 0 else Vector2(_aabb.get_center().x, _aabb.get_center().z)


## How much bare stem there is ABOVE `band_lo`: from the top of the root flare up to the
## first thing that sticks out further than a trunk does.
##
## This is what makes the trunk choppable where the player is looking rather than in an
## arbitrary slice of it. Scanning up from the flare, the band ends at the first height
## that measures more than `_BRANCH_TOL` times the bare radius.
##
## On the current art it usually finds nothing at all, and that is correct rather than
## broken: the branches are on the declared CANOPY surfaces and the stem is 6.7 m of
## clear wood. What bounds the band then is the owner's cost cap, not the geometry — see
## `band_height_max`. It still matters for older art that carries branches on the trunk
## surface, and for the point where a trunk splits into its leaders.
func _clear_trunk_height(bins: Dictionary) -> float:
	var widest: PackedFloat32Array = bins.radius
	var first := maxi(int(round((band_lo - ground_y) / _BRANCH_BIN)), 0)
	# Against the LOCAL TAPER, for the reason spelled out in `_root_flare_height`: a stem
	# narrows on the way up, so anything that gets WIDER than the wood below it is a limb
	# leaving or a fork opening, whatever the trunk's overall radius happens to be.
	for b in range(first + _TAPER_LOOK, widest.size()):
		var below := widest[b - _TAPER_LOOK]
		if below > 0.0 and widest[b] > below * _BRANCH_TOL:
			# Stop short of the offending height: the limb's own geometry starts
			# somewhere inside it, and the band wants to end below that.
			return maxf(float(b - _TAPER_LOOK - first) * _BRANCH_BIN, _MIN_BAND)
	# No branches anywhere: the whole stem is choppable, subject to the cost cap.
	return height


## HOW FAR UP THE ROOT FLARE REACHES, measured from the butt (m).
##
## THE BAND STARTS ABOVE IT, and everything below stays the tree's own authored mesh
## (see `build`). This is the 2026-07-29 fix for Sam's "the roots disappear when I start
## cutting" and for the torn bark that came with it, and both were the same cause: the
## voxel field is a RADIAL PROFILE — one radius per (level, angle) about the trunk axis —
## and a root is not a radial thing. Four or five limbs arching out of the butt cannot be
## expressed as one radius per angle, so `_PROFILE_CLAMP` flattened them into a smooth
## skirt (the roots, gone), while the profile's own ray-cast landed on root surfaces and
## carried ROOT UVs into `_fit_bark_uv` (the bark, torn — measured at u sweeping 0.33 to
## 3.08 round one ring where a turn is 0.82, against a clean 0.16 of drift higher up).
##
## Clamping harder or measuring more carefully cannot fix either: a radial field has no
## representation for the shape. The band therefore stops where the shape stops being
## radial, exactly as it already stops below the branches at the other end — and a faller
## cuts above the butt swell anyway.
##
## The flare is the contiguous over-limit run STARTING AT THE BUTT. Contiguous-from-bin-0
## is what makes it a flare rather than a branch: a branch has bare stem under it, by
## definition. An EMPTY bin continues the run rather than ending it, because these trunks
## are prisms with vertices only at their ring heights. The scan is bounded by the trunk's
## own radius above the butt — a root flare reaches up about as far as it reaches out —
## so it scales with the tree instead of being another number to tune.
## MEASURED AGAINST THE LOCAL TAPER, not against the trunk's radius. These trees taper
## hard and continuously — tree_01 runs 2.76x its band radius at the butt down to 1.0x
## with no step anywhere — so "wider than `_BRANCH_TOL` times the radius" has no fixed
## answer: measure the radius over the band and the flare swallows the taper below it;
## measure it lower and the flare disappears. Chasing that with a two-pass estimate just
## made the two definitions converge on each other, and put the band's floor at 1.1 m.
##
## What actually distinguishes a flare is that it SWELLS FASTER THAN THE TAPER: a trunk
## widens gently on the way down and a buttress does not. So a height is flare when it is
## `_BRANCH_TOL` times wider than the wood `_TAPER_LOOK` bins ABOVE it, and the flare top
## is the highest such height. That needs no radius at all, which also removes the
## circular dependency it used to have with one.
##
## Taken as the HIGHEST such bin plus one, not the first clear one: an isolated narrow
## reading in the middle of the flare must not end it.
func _root_flare_height(bins: Dictionary) -> float:
	var widest: PackedFloat32Array = bins.radius
	if widest.size() <= _TAPER_LOOK:
		return 0.0
	# A root flare reaches up about as far as it reaches out, so the search is bounded by
	# the butt's own spread and needs no number of its own. A swelling well above that is
	# a branch or a fork, and `_clear_trunk_height` is what handles those.
	var window := mini(int(ceil(widest[0] / _BRANCH_BIN)), widest.size() - _TAPER_LOOK)
	var last := -1
	for b in range(window):
		var above := widest[b + _TAPER_LOOK]
		if above > 0.0 and widest[b] > above * _BRANCH_TOL:
			last = b
	return float(last + 1) * _BRANCH_BIN


## How wide the trunk is at every `_BRANCH_BIN` of height above `from_y`, and how far its
## centre has wandered off the butt's axis by then. Over the DECLARED TRUNK SURFACE only.
##
## Returns { "radius": PackedFloat32Array (0 where the plane misses the mesh entirely),
## "offset": PackedVector2Array (that height's centre, relative to `axis_xz`) }.
##
## MEASURED AS REAL CROSS-SECTIONS, not by binning vertices. These trunks are lofted
## prisms with rings a metre or more apart, so a vertex histogram has a value at the ring
## heights and NOTHING in between — on tree_01, thirteen of the first twenty bins were
## empty, and the ones that were not held a passing root TIP as often as a trunk ring.
## Every scan built on it inherited that: the flare read as ending at 0.5 m where the
## buttresses ran to 0.7, the band's top read off a ring that happened to be wide, and
## the radius was a median of whatever vertices existed rather than of the trunk. Cutting
## the mesh at each height instead gives an answer at every height, which is what both
## callers are actually asking for.
##
## THE SURFACE RESTRICTION is half of the 2026-07-29 fix. This used to read the whole
## mesh, so a leaf card counted as a branch: tree_01's foliage droops to 1.88 m and
## tree_02's to 1.11 m, and the scan duly stopped the band there — a 1.1 m band on a 14 m
## tree, with the crown's mesh clipped 0.14 m below its top and drawn over the rest of it.
## That is Sam's "I cant cut them properly higher up", and the reason it read as nothing
## happening at all: `_max_local_y_of` clamps the crosshair to `crown_base()`, so every
## blow aimed anywhere above 0.96 m landed at 0.96 m, behind the crown.
##
## MEASURING FROM EACH BIN'S OWN CENTRE is the other half, and it is what makes the
## numbers mean anything on these trees. `axis_xz` is one vertical line taken at the butt,
## and the generator gives every trunk a lean and a wander — so on tree_01 a perfectly
## ordinary stem ring at 1.3 m sat 0.35 m off that line and measured 1.67x the trunk
## radius, indistinguishable from a branch. Both scans below are "is this wider than a
## trunk?", and a leaning trunk is not.
##
## The MAXIMUM in each bin, not the median: one limb leaving the stem is enough, and a
## median would happily average it away.
func _width_bins(mesh: Mesh, from_y: float) -> Dictionary:
	var bins := maxi(int(ceil(maxf(_aabb.end.y - from_y, 0.0) / _BRANCH_BIN)) + 1, 1)
	var sum := PackedVector2Array()
	var count := PackedInt32Array()
	var pts: Array = []          # one PackedVector2Array of crossings per bin
	sum.resize(bins)
	count.resize(bins)
	pts.resize(bins)
	for b in range(bins):
		pts[b] = PackedVector2Array()
	for si in _trunk_surface_list(mesh):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := WoodVolume.triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var a := verts[idx[t]]
			var b0 := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var lo := minf(a.y, minf(b0.y, c.y))
			var hi := maxf(a.y, maxf(b0.y, c.y))
			var j0 := maxi(int(ceil((lo - from_y) / _BRANCH_BIN)), 0)
			var j1 := mini(int(floor((hi - from_y) / _BRANCH_BIN)), bins - 1)
			for j in range(j0, j1 + 1):
				var y := from_y + float(j) * _BRANCH_BIN
				var row: PackedVector2Array = pts[j]
				_cross_at(y, a, b0, row)
				_cross_at(y, b0, c, row)
				_cross_at(y, c, a, row)
				pts[j] = row     # a Packed* inside an Array is a VALUE, not a reference
	var centre := PackedVector2Array()
	var offset := PackedVector2Array()
	var widest := PackedFloat32Array()
	centre.resize(bins)
	offset.resize(bins)
	widest.resize(bins)
	widest.fill(0.0)
	var last_seen := -1
	for b in range(bins):
		var row: PackedVector2Array = pts[b]
		if row.is_empty():
			# Above the top of the stem, or a gap in it. Carry the last centre forward
			# rather than snapping back to the axis, which would read as the trunk
			# lurching sideways to anything asking where its centre is.
			centre[b] = centre[last_seen] if last_seen >= 0 else axis_xz
			offset[b] = centre[b] - axis_xz
			continue
		last_seen = b
		var mid := Vector2.ZERO
		for p in row:
			mid += p
		mid /= float(row.size())
		centre[b] = mid
		offset[b] = mid - axis_xz
		for p in row:
			widest[b] = maxf(widest[b], p.distance_to(mid))
	return {"radius": widest, "offset": offset}


## Append where edge a-b crosses height `y`, in the ground plane.
func _cross_at(y: float, a: Vector3, b: Vector3, out: PackedVector2Array) -> void:
	var da := a.y - y
	var db := b.y - y
	if (da >= 0.0) == (db >= 0.0):
		return
	var p := a.lerp(b, da / (da - db))
	out.append(Vector2(p.x, p.z))


## Move `axis_xz` onto the stem's own centre at the middle of the band, and rebase the
## scan's offsets onto it so everything downstream measures from the same place.
func _recentre_on_band(bins: Dictionary) -> void:
	var offset: PackedVector2Array = bins.offset
	if offset.is_empty():
		return
	var mid := clampi(int(round((band_lo + band_hi) * 0.5 - ground_y) / _BRANCH_BIN),
		0, offset.size() - 1)
	var shift := offset[mid]
	axis_xz += shift
	for b in range(offset.size()):
		offset[b] -= shift
	bins.offset = offset


## Where the stem's centre is at local height `y`, relative to `axis_xz`. Zero at the
## middle of the band by construction; the butt and the band's top lean off it.
func centre_offset(y: float) -> Vector2:
	if _centre_off.is_empty():
		return Vector2.ZERO
	var b := clampi(int(round((y - ground_y) / _BRANCH_BIN)), 0, _centre_off.size() - 1)
	return _centre_off[b]


## THE SHAPE OF A LENGTH OF TIMBER, as a stack of slices a collider can be built from.
##
## `from_y`..`to_y` are local heights; each entry is `{"y", "height", "centre", "radius"}`
## with `centre` an x/z point in the trunk's own frame (`axis_xz` included, so a caller
## needs no second lookup) and `radius` sized to cover every slice the entry spans.
##
## WHY THIS EXISTS. A felled trunk used to get ONE cylinder on the body's local Y axis
## through its origin, which is only the right shape if the timber is a straight column
## standing on that origin. It is neither. Two things push it off:
##
##   - the body's origin is the HINGE — the failing section's centroid, which a deep notch
##     drags to the back of the remaining wood, so the wood is off the axis from the butt up
##     (MEASURED: 0.46 m on tree_02, against a trunk radius of 0.49);
##   - the generator leans and wanders every trunk it makes, so it keeps going — 3.08 m off
##     that axis by the top of tree_02's timber.
##
## So at every height the wood reached outside the cylinder, by 0.58 m at the butt and
## 2.72 m at the tip, and the woody crown had no collider under it at all: it settled at
## world y -2.76..0.19, i.e. entirely below the floor. That is Sam's report of 2026-07-30,
## "when a tree falls, the top half penetrates through the floor".
##
## The radius is conservative on purpose — for each slice it spans, the entry covers that
## slice's own centre plus that slice's own width. A collider slightly fatter than the wood
## makes a felled trunk rest a little high; one that misses the wood drops it through the
## world, and only one of those two is a bug you can see.
func timber_slices(from_y: float, to_y: float, step := 0.5) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _bin_radius.is_empty() or to_y <= from_y:
		return out
	var n := maxi(int(ceil((to_y - from_y) / maxf(step, _BRANCH_BIN))), 1)
	var h := (to_y - from_y) / float(n)
	for i in range(n):
		var y0 := from_y + h * float(i)
		var y1 := y0 + h
		# The bins this slab covers. Inclusive of both ends: a slab has to be solid
		# across its whole height, not just at the middle.
		var b0 := clampi(int(floor((y0 - ground_y) / _BRANCH_BIN)), 0, _bin_radius.size() - 1)
		var b1 := clampi(int(ceil((y1 - ground_y) / _BRANCH_BIN)), 0, _bin_radius.size() - 1)
		var mid := Vector2.ZERO
		var count := 0
		for b in range(b0, b1 + 1):
			mid += _centre_off[b]
			count += 1
		mid = (mid / float(count)) if count > 0 else Vector2.ZERO
		var r := 0.0
		for b in range(b0, b1 + 1):
			# ...plus how far this bin's centre has drifted from the slab's, or a slab
			# taken across a leaning stem would sit beside the wood rather than round it.
			r = maxf(r, _centre_off[b].distance_to(mid) + _bin_radius[b])
		if r <= 0.0:
			continue
		out.append({"y": (y0 + y1) * 0.5, "height": h,
			"centre": axis_xz + mid, "radius": r})
	return out


## HOW FAR THE BAND'S GRID HAS TO REACH FROM THE TRUNK'S AXIS (m).
##
## This is what `WoodVolume`'s profile is clamped to, and it is NOT `radius * something`.
## `axis_xz` is one vertical line taken at the butt, and the generator leans and wanders
## every trunk it makes — so by the top of a 3 m band the stem's centre has moved off that
## line, and a clamp set from the radius alone cuts the far side of the trunk off. MEASURED
## on tree_01: the band's own sections stopped tapering at 3.8 m and grew back to exactly
## the clamp area, which is the trunk turning into a smooth fat cylinder. That is the
## "geom deformation that looks kinda buggy" higher up the tree.
##
## So it is the worst, over the band's own height bins, of "how far this bin's centre has
## drifted, plus how wide this bin is" — with the width itself clamped to a trunk's worth,
## so a branch stub cannot inflate the whole grid.
func _band_max_radius(bins: Dictionary) -> float:
	var widest: PackedFloat32Array = bins.radius
	var offset: PackedVector2Array = bins.offset
	var limit := radius * _PROFILE_CLAMP
	var worst := limit
	var b0 := maxi(int(round((band_lo - ground_y) / _BRANCH_BIN)), 0)
	var b1 := mini(int(round((band_hi - ground_y) / _BRANCH_BIN)), widest.size() - 1)
	for b in range(b0, b1 + 1):
		if widest[b] <= 0.0:
			continue
		worst = maxf(worst, offset[b].length() + minf(widest[b], limit))
	return worst


## The top of the DECLARED TRUNK SURFACE (local Y). The band must never reach past it:
## above there the stem is not modelled at all and the profile would have nothing to
## measure but whatever canopy happens to cross the level.
func _trunk_surface_top(mesh: Mesh) -> float:
	if mesh == null or trunk_surface < 0 or trunk_surface >= mesh.get_surface_count():
		return _aabb.end.y
	var top := -INF
	for v in _surface_vertices(mesh, trunk_surface):
		top = maxf(top, v.y)
	return top if top > -INF else _aabb.end.y


## Radius of bare trunk: the MEDIAN of the cross-section radii between `lo` and `hi`.
## Roots and branches are the minority of the heights in a well-chosen range, so the
## median lands on the trunk while a max would land on a limb.
##
## The range MATTERS, which is why it is a parameter and why `_measure` narrows it twice.
## These trunks taper hard — tree_01 loses a third of its radius over the first 1.8 m —
## so a radius taken over the whole lower half of the tree describes wood the axe never
## touches, and this number is the profile clamp, the pick volume, the standing collider,
## the branch and flare limits and the end-grain ring scale.
func _trunk_radius(bins: Dictionary, lo: float, hi: float) -> float:
	var widest: PackedFloat32Array = bins.radius
	var b0 := maxi(int(round((lo - ground_y) / _BRANCH_BIN)), 0)
	var b1 := mini(int(round((hi - ground_y) / _BRANCH_BIN)), widest.size() - 1)
	var radii: Array[float] = []
	for b in range(b0, b1 + 1):
		if widest[b] > 0.0:
			radii.append(widest[b])
	if radii.is_empty():
		return maxf(_aabb.size.x, _aabb.size.z) * 0.5
	radii.sort()
	return maxf(radii[radii.size() / 2], 0.01)


## Texels per metre on the trunk's authored bark, so the voxel band can wear the
## bark texture at the SAME size as the crown standing on top of it. Without
## this the band and the crown tile the same texture at different scales and the
## band top reads as a hard line right across the tree.
##
## Taken as the median of sqrt(UV area / world area) over the triangles in the
## band's own height range: a median rather than a mean because a couple of
## degenerate or badly-mapped triangles are normal in an imported tree and would
## drag an average anywhere.
func _bark_density(mesh: Mesh, surface := -1) -> float:
	var ratios: Array[float] = []
	var surfaces: Array[int] = []
	if surface >= 0 and surface < mesh.get_surface_count():
		surfaces.append(surface)
	else:
		for si in range(mesh.get_surface_count()):
			surfaces.append(si)
	for si in surfaces:
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		if not (raw_uv is PackedVector2Array) or (raw_uv as PackedVector2Array).size() != verts.size():
			continue
		var uvs: PackedVector2Array = raw_uv
		var idx := WoodVolume.triangle_indices(arr, verts.size())
		for t in range(0, idx.size() - 2, 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var mid := (a.y + b.y + c.y) / 3.0
			if mid < band_lo or mid > band_hi + (band_hi - band_lo):
				continue
			var world := (b - a).cross(c - a).length() * 0.5
			if world < 1e-7:
				continue
			var ua := uvs[idx[t + 1]] - uvs[idx[t]]
			var ub := uvs[idx[t + 2]] - uvs[idx[t]]
			var tex: float = absf(ua.x * ub.y - ua.y * ub.x) * 0.5
			if tex < 1e-9:
				continue
			ratios.append(sqrt(tex / world))
	if ratios.is_empty():
		return 1.0
	ratios.sort()
	return maxf(ratios[ratios.size() / 2], 0.01)


## Vertices from the explicitly declared trunk surface, or the whole mesh for
## legacy/test geometry that has no species metadata.
func _surface_vertices(mesh: Mesh, surface: int) -> PackedVector3Array:
	if mesh != null and surface >= 0 and surface < mesh.get_surface_count():
		return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	return MeshUtils.vertices(mesh)


## The bark material declared by the tree type. Legacy/test meshes without an
## explicit surface keep the old widest-surface fallback.
func _surface_material(mesh: Mesh, surface: int) -> Material:
	if mesh != null and surface >= 0 and surface < mesh.get_surface_count():
		return mesh.surface_get_material(surface)
	var best: Material = null
	var most := -1
	for si in range(mesh.get_surface_count()):
		var n: int = (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if n > most:
			most = n
			best = mesh.surface_get_material(si)
	return best


## How far the ROOT FLARE reaches out, unclamped (local metres from the trunk axis).
##
## `_band_max_radius` deliberately clamps every level to `_PROFILE_CLAMP` times the stem's
## radius, because a branch crossing the band must not drag the grid out to the width of
## the crown. The flare is the one thing that legitimately IS wider than the stem, and with
## `voxel_roots` it is inside the field — so it gets its own measurement, taken only over
## the levels below the flare top so a branch still cannot reach this.
func _flare_max_radius(bins: Dictionary) -> float:
	var widest: PackedFloat32Array = bins.radius
	var offset: PackedVector2Array = bins.offset
	var worst := 0.0
	var b1 := mini(int(round((_flare_top - ground_y) / _BRANCH_BIN)), widest.size() - 1)
	for b in range(0, b1 + 1):
		if widest[b] <= 0.0:
			continue
		worst = maxf(worst, offset[b].length() + widest[b])
	return worst
