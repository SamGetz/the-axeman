
extends Node3D
## FILE: res://scenes/3d_action/chopping_minigame.gd
## ATTACHES TO: the root Node3D of res://scenes/3d_action/chopping_minigame.tscn
## (the live M4 mini-game, instanced under main's 3D_World_Root) AND of
## res://scenes/3d_action/chopping_minigame_harness.tscn (the standalone F6
## feel-test harness, which instances chopping_minigame.tscn inside its own
## viewport). Both need the child nodes CameraPivot/Camera3D, Fallers, and Floor.
##
## This is the shipping M4 chopping mini-game (renamed 2026-07-22 from slice_poc.gd
## once the POC was feel-approved and folded in — no reason left to carry the POC
## name on the live script). When a log is fully chopped and its firewood settles,
## each finished piece is deposited into InventoryManager as the log species'
## yield item (A7 resource_gathered — see _LOG_SPECIES and _begin_stacking).
##
## Amendment-6 SLICING PROOF-OF-CONCEPT, re-architected (2026-07-19) to match the
## reference firewood chopper's FEEL, not just its fall rules. The reference is
## an ANIMATION-DRIVEN game: only firewood thrown to the pile uses physics; every
## piece that stays on the block, and every nearby piece a strike jostles, is
## moved by a scripted pop/tilt animator (see piece_animator.gd). The earlier POC
## made everything a RigidBody, which is why it felt floaty and needed a pile of
## physics band-aids (mass-by-volume, damp tuning, a slide-off assist). Those are
## gone now — stays are script-animated.
##
## The chop loop, lifted from the reference:
##   1. Click a piece on the block. If it's too thin along the current cut axis,
##      the camera snaps 90 deg to the perpendicular (long) axis instead of cutting
##      — forcing firewood-sized chunks rather than shaving off slivers.
##   2. The axe swings from the impact point. After `anticipation_sec`, the wood
##      actually splits (the pause makes the axe visibly *connect* first).
##   3. On the split: camera shake + hit-pause fire via EventBus.action_hit_
##      registered (GameFeel owns both). Each half is judged independently:
##        * volume <= min_vol OR aspect > aspect_limit -> FIREWOOD (physics, thrown
##          toward the pile) ;  otherwise -> STAYS on the block (script-animated).
##   4. Every on-block piece pops away from the cut in a radial shockwave with
##      distance falloff + staggered delay; a hull-separation solver keeps them
##      from overlapping and inside the stump footprint.
##   5. A fresh log drops in when everything is chopped (R also forces a fresh log).
##
## Camera orbits in fixed 30-deg steps (A/D or arrows).
##
## EVERY tuning value below is a PLACEHOLDER carried over from the reference
## (converted from its internal inches via ld=0.0254 m/in). Directive 4: authored
## as @export, never a hardcoded final — tune live with Sam in F6.

const _PieceAnimator := preload("res://scenes/3d_action/piece_animator.gd")
const _WoodPile := preload("res://scenes/3d_action/wood_pile.gd")
## Mesh maths and the axe motion were lifted into shared helpers during M5 so the
## felling mini-game reuses this exact code instead of a second copy. Behaviour
## here is unchanged — every helper below is the same implementation, relocated.
const _AxeRig := preload("res://scenes/3d_action/axe_rig.gd")

# --- log species (data-driven; scales to many woods) ----------------------
## Each row is a WOOD SPECIES: the meshes a log of it can be cut from, and the
## item it yields when chopped into firewood. This is the ONLY place a wood type
## is declared — add a row to add a species, add a path to add log variety.
##
## `meshes` is a LIST, not a single path, so a species can have many authored log
## shapes without skewing which wood turns up: the species is picked first and a
## shape second. Six birch meshes as six rows would have made three quarters of
## every yard birch.
##
## `yield_item` MUST be a registered id (res://data/item_registry.tres); a
## finished log deposits it into InventoryManager once per firewood piece (see
## _begin_stacking).
##
## The log's OUTSIDE (bark and ends) comes from the FBX's own materials, so a new
## species looks like itself the moment it is imported. The CUT FACE does not —
## it is generated at runtime, so each row also names the inside look:
##
##   `inside_tex` / `inside_normal`  the exposed inside grain. These are sampled with
##       a TILING, metres-based UV mapping (see the 2026-07-27 slicer bugfix note),
##       so they MUST be tileable textures — a log-end "disc" texture repeats into
##       a grid of discs and looks wrong. Omit to fall back to the oak set.
##   `inside_tint`  albedo multiplier over that texture. PLACEHOLDER per Directive 3
##       wherever it is not Color.WHITE: it is standing in for a species' real
##       tileable inside texture until Sam authors one.
##
## log_02 is mapped to pine_firewood purely to DEMONSTRATE per-log yields — it still
## wears oak art. Remap freely.
const _LOG_SPECIES: Array[Dictionary] = [
	{"meshes": ["res://assets/models/logs_export/log_01.fbx"], "yield_item": &"oak_firewood"},
	{"meshes": ["res://assets/models/logs_export/log_02.fbx"], "yield_item": &"pine_firewood"},
	# Birch (Sam's drop, 2026-08-01): SIX authored log shapes, one species. Bark
	# and authored ends come from each FBX's own embedded materials; the CUT
	# faces use Sam's tileable birch inside grain, so a split birch log is pale
	# inside instead of oak-coloured.
	{
		"meshes": [
			"res://assets/models/logs_export/birch_log_01.fbx",
			"res://assets/models/logs_export/birch_log_02.fbx",
			"res://assets/models/logs_export/birch_log_03.fbx",
			"res://assets/models/logs_export/birch_log_04.fbx",
			"res://assets/models/logs_export/birch_log_05.fbx",
			"res://assets/models/logs_export/birch_log_06.fbx",
		],
		"yield_item": &"birch_firewood",
		"inside_tex": "res://assets/textures/wood_birch/birch_inside_tilable.png",
		"inside_normal": "res://assets/textures/wood_birch/birch_inside_tilable_normal.png",
	},
]

# --- infrastructure (unchanged geometry/material setup) -------------------
@export var log_height := 0.42            # finished height of a log standing on the block (m)
@export var stump_scale := 0.376         # scales chopping_stump_a so its top sits at the log rest height (~0.5m)
@export var camera_step_deg := 30.0
@export var orbit_time := 0.25
@export var debug_forced_species := -1   # -1 = random each log; >=0 forces a _LOG_SPECIES index (headless tests only)
@export var debug_forced_mesh := -1      # -1 = random shape within the species; >=0 forces one (tests + species_shot)

# --- fall classification (the reference rule) -----------------------------
@export_group("Classification")
@export var min_piece_size := 0.06       # sliver guard: min thickness of a cut-off piece (m)
@export var min_vol := 0.018             # volume floor (m^3): below this a piece is firewood
@export var aspect_limit := 3.0          # above this max/min extent ratio a piece is firewood
@export var width_depth_ratio := 0.35     # a cut piece's width (along the cut) is kept >= this * its depth, so chunks stay square instead of flat slabs (0 = off, click-exact cuts)

# --- chop feel (the animation-driven core; reference values) --------------
@export_group("Chop feel")
@export var anticipation_sec := 0.1      # ref: axe connects, THEN 0.1s later the wood splits
@export var jostle_radius := 0.381       # ref 15in: falloff radius for the shockwave that jostles nearby pieces
@export var half_push := 0.0254          # ref 1in: how far the two fresh halves pop apart from the cut
@export var jostle_push := 0.0127        # ref Zu=0.5in: max outward nudge on a nearby piece (x falloff)
@export var pop_height := 0.0508         # ref 2in: how high a jostled piece hops
@export var delay_ref_dist := 0.6096     # ref 24in: distance that maps to a full `stagger_ms` of delay (ripple)
@export var stagger_ms := 150.0          # ref: max stagger so the shockwave ripples outward, not all at once
@export var sep_gap := 0.0127            # ref Qu=0.5in: gap the separation solver keeps between piece hulls
@export_range(0.0, 1.5) var clamp_radius_frac := 1.0  # pieces are kept within this fraction of the stump radius
@export var fresh_yaw_deg := 2.0         # ref: small random yaw (+/-) on a freshly split half
@export var min_cut_width := 0.127       # only reorient to a long axis while it's at least this thick (m); below this the piece is small enough to just cut
@export var cross_axis_turn_deg := 90.0  # cut axis too short -> snap camera this far to the perpendicular (long) axis so cuts make firewood chunks
@export var long_axis_bias := 1.15       # snap to the perpendicular axis when it is more than this * the axis you'd cut (hysteresis; 1.0 = always cut the strictly longer axis)
@export var drop_height := 0.5           # how far above rest a fresh log drops in from

# --- cut face (roughen the split so it's cloven wood, not a laser cut) -----
@export_group("Cut face")
@export var cut_jag_amount := 0.01       # how far cut-face verts wobble along the cut normal (m); 0 = perfectly clean cut
@export var cut_jag_freq := 12.0         # spatial frequency of the jaggedness (higher = finer/rougher grain)

# --- firewood physics (the ONLY physics pieces) ---------------------------
@export_group("Firewood physics")
@export var wood_density := 700.0        # mass = density * AABB volume (floored)
@export var min_mass := 0.2              # mass floor so slivers aren't flung by heavier pieces
@export var piece_linear_damp := 0.35
@export var piece_angular_damp := 1.2
@export var firewood_out := 1.6          # outward (from cut) launch speed (m/s)
@export var firewood_up := 1.2           # upward launch speed (m/s)
@export var firewood_toward_cam := 1.0   # bias toward the viewer so the pile forms in front (m/s)
@export var firewood_tumble := 3.0       # random spin (rad/s)
@export var max_firewood := 40           # hard cap; oldest freed first
@export var firewood_settle_speed := 0.05 # firewood counts as "settled" below this speed (m/s)
@export var firewood_settle_timeout := 1.5  # force-stack after this long even if still drifting (s)

# --- pile (fully-chopped firewood is gathered into an arc pile; reference QC) --
@export_group("Pile")
@export var pile_radius := 1.524         # ref 60in: arc radius the pile sits on
@export var pile_arc_span_deg := 230.0
@export var pile_start_angle_deg := 320.0
@export var pile_slot_spacing := 0.127   # ref XC = 5in
@export var pile_tier_depth := 0.4572    # ref 18in: outward step per tier
@export var pile_max_height := 0.4572    # ref 18in
@export var pile_ground_y := 0.0         # world y the pile rests on (our floor top = 0)
@export var pile_jitter := 0.0254        # ref 1in: random slide along the arc
@export var pile_apex_extra := 0.3048    # ref 12in: arc height of a flung piece
@export var pile_fly_ms := 500.0         # travel takes this * 1.6
@export var pile_stagger_ms := 300.0     # cascade spread across the batch
## Creative Director call, 2026-08-01: the pile builds to 50 pieces and is then
## HAULED AWAY — the whole load flies off screen and the yard starts a fresh
## stack. It doubles as A12's ceiling on how many pile meshes exist at once.
@export var max_pile_pieces := 50
@export var haul_distance := 9.0         # how far a hauled piece flies before it is dropped (m)
@export var haul_rise := 2.2             # how high it arcs on the way out (m)
@export var haul_ms := 700.0             # travel time per piece
@export var haul_stagger_ms := 600.0     # spread across the load, so it leaves as a wave

## The yard buys every piece the moment it lands on the pile (Creative Director
## call, 2026-08-01 — "as soon as the pieces enter the pile, they should be
## converted to their cash value"). OFF for the M4 suite, which tests the chopping
## game's yield contract — that a finished piece deposits stock — and would
## otherwise be watching the economy sell that stock out from under it.
@export var auto_sell := true

# --- axe ------------------------------------------------------------------
@export_group("Axe")
@export var axe_scale := 1.4
@export var axe_hover := 0.45            # how far above the impact the axe starts its swing (m)
@export var axe_hidden_euler := Vector3(-1.1, 0.0, 0.15)
@export var axe_struck_euler := Vector3(0.15, 0.0, 0.1)
@export var swing_time := 0.16

# --- audio (hooks; drop a stream in to hear it) ---------------------------
@export_group("Audio")
@export var drop_sfx: AudioStream        # ref: drop.mp3 on log landing
@export var split_sfx: AudioStream       # ref: split sound on each chop

const _TEX_INSIDE := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_diffColor.jpg")
const _TEX_INSIDE_N := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_normals.jpg")
const _AXE_FBX := preload("res://assets/models/axe_basic/axe_basic.fbx")
const _STUMP_FBX := preload("res://assets/models/chopping_stump_a/chopping_stump_a.fbx")

const _PICK_LAYER := 1 << 1              # on-block pieces sit on this layer for ray-picking only

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _fallers: Node3D = $Fallers

var _animator := _PieceAnimator.new()
var _pile := _WoodPile.new()
var _pieces_root: Node3D                  # identity-transform parent so piece.position == world
var _pile_root: Node3D                    # frozen stacked firewood proxies live here
var _haul_root: Node3D                    # a load on its way out of the yard; NOT part of the pile any more
var _on_block: Array = []                 # Array[Area3D] — script-animated pieces on the block
var _firewood: Array = []                 # Array[RigidBody3D] — the only physics pieces
var _pending: Dictionary = {}             # in-flight strike waiting out anticipation_sec
var _stacking := false                    # firewood is flying into the pile
var _awaiting_stack := false              # log done; waiting for firewood to settle before stacking
var _await_since := 0.0                   # sec timestamp the wait began

var _source_mesh: Mesh
var _yaw_steps := 0
var _orbit_tween: Tween
var _axe: AxeRig
var _audio: AudioStreamPlayer3D
var _cut_mat: StandardMaterial3D          # cut-face material of the log CURRENTLY on the block
var _cut_mats: Dictionary = {}            # species index -> StandardMaterial3D (built once, reused)
var _specimens: Dictionary = {}           # species index -> Array[ArrayMesh]: stand-in firewood for a REBUILT pile
var _phys_mat: PhysicsMaterial
var _cut_noise := FastNoiseLite.new()    # drives the jagged displacement of cut faces
var _stump_top_y := 0.5
var _stump_radius := 0.4
var _current_species: Dictionary = {}   # the species row of the log currently on the block; drives the yield item


func _ready() -> void:
	GameFeel.register_camera(_camera)
	# A cut material must exist before anything can slice; _spawn_fresh_log swaps
	# in the one belonging to whichever species it puts on the block.
	_cut_mat = _cut_mat_for(0)
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.9
	_phys_mat.bounce = 0.0

	_pieces_root = Node3D.new()
	_pieces_root.name = "OnBlock"
	add_child(_pieces_root)

	_pile_root = Node3D.new()
	_pile_root.name = "Pile"
	add_child(_pile_root)
	# A hauled load is reparented out of the pile the instant it is handed over, so
	# the next stack can start building underneath it without the two ever sharing
	# a node or a slot.
	_haul_root = Node3D.new()
	_haul_root.name = "Haul"
	add_child(_haul_root)
	_configure_pile()

	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

	# _source_mesh is deliberately NOT built here: _spawn_fresh_log() below sets it
	# from the species it actually puts on the block, so building one up front only
	# loaded and scaled an FBX for a random species that was thrown away.
	_build_stump()
	$Floor.physics_material_override = _phys_mat
	_build_axe()
	_spawn_fresh_log()

	# The pile on screen is a view of GameState's yard pile, so the yard you come
	# back to is the yard you left.
	#
	# This connection is what makes a LOADED SAVE show its pile at all: a child's
	# _ready runs before its parent's, so this scene is built before main.gd has
	# read the save off disk, and the pile it builds in _spawn_fresh_log above is
	# necessarily empty. The load lands moments later and this rebuilds on it.
	GameState.yard_pile_changed.connect(_on_yard_pile_changed)


func _exit_tree() -> void:
	GameFeel.unregister_camera()


func _process(delta: float) -> void:
	_animator.update()

	if not _pending.is_empty():
		_pending.timer -= delta
		if _pending.timer <= 0.0:
			var pd := _pending
			_pending = {}
			if is_instance_valid(pd.piece) and pd.piece in _on_block:
				_perform_split(pd.piece, pd.world_point, pd.normal, pd.dir)

	if _awaiting_stack and _firewood_settled():
		_begin_stacking()

	# The load on its way out is animated independently of the stack coming in, so
	# the player can chop through a haul-away instead of waiting for it.
	if _pile.is_hauling:
		_pile.update_haul()

	if _stacking:
		_pile.update()
		if not _pile.is_animating:
			_stacking = false
			# The last piece of the load has landed and been paid for. If that
			# filled the yard, the whole pile leaves now — before the next log
			# drops, so the fresh stack starts on clear ground.
			if GameState.get_yard_pile_count() >= max_pile_pieces:
				_haul_away()
			_spawn_fresh_log(false)   # keep the pile; grow it with the next log


func _configure_pile() -> void:
	_pile.radius = pile_radius
	_pile.arc_span = deg_to_rad(pile_arc_span_deg)
	_pile.start_angle = deg_to_rad(pile_start_angle_deg)
	_pile.slot_spacing = pile_slot_spacing
	_pile.tier_depth_spacing = pile_tier_depth
	_pile.max_height = pile_max_height
	_pile.ground_y = pile_ground_y
	_pile.jitter = pile_jitter
	_pile.apex_extra = pile_apex_extra
	_pile.fly_duration = pile_fly_ms
	_pile.stagger = pile_stagger_ms
	_pile.haul_distance = haul_distance
	_pile.haul_rise = haul_rise
	_pile.haul_duration = haul_ms
	_pile.haul_stagger = haul_stagger_ms


# ------------------------------------------------- the yard's stockpile (M7A)
## The pile the player can SEE is the work they have done since the last load left
## the yard — GameState's yard pile, one mesh per piece.
##
## The firewood itself is NOT in it: the yard buys each piece the moment it lands
## (Creative Director call, 2026-08-01), so by the time a piece is stacked it has
## already been paid for. The pile is therefore a record of work, not of property,
## which is why it lives in GameState next to the lifetime counter rather than
## being derived from InventoryManager.
##
## REBUILT, not maintained. A rebuild is instant and total: the arc packing in
## wood_pile.gd is deterministic and has no notion of removing one piece from the
## middle of a stack, and faking one would leave pieces resting on nothing.
##
## Deliberately NOT called while a batch is flying in. Freshly cut pieces are the
## real sliced meshes and they animate into the pile; rebuilding on top of that
## would swap them for stand-ins mid-flight and throw away the best moment in the
## game.
func _rebuild_pile_from_yard() -> void:
	if _stacking or _awaiting_stack:
		return
	for c in _pile_root.get_children():
		_pile_root.remove_child(c)
		c.queue_free()
	_pile.reset()

	for species_index: int in _interleave(_pile_plan()):
		var meshes: Array = _specimens_for(species_index)
		if meshes.is_empty():
			continue
		var node := MeshInstance3D.new()
		node.mesh = meshes[randi() % meshes.size()]
		_pile_root.add_child(node)
		_pile.place_settled(node)


## How many pieces of each species to stack, from GameState's yard pile. Capped at
## `max_pile_pieces`, scaled down together so the mix on show still reflects the
## mix that was cut — the cap only bites on a save written before it was lowered,
## since a live pile is hauled away the moment it reaches it.
func _pile_plan() -> Dictionary:
	var yard := GameState.get_yard_pile()
	var counts: Dictionary = {}
	var total := 0
	for i in range(_LOG_SPECIES.size()):
		var item: StringName = _LOG_SPECIES[i].get("yield_item", &"")
		if item == &"":
			continue
		var n := int(yard.get(item, 0))
		if n <= 0:
			continue
		counts[i] = n
		total += n
	if total <= max_pile_pieces:
		return counts
	var scaled: Dictionary = {}
	for i: int in counts:
		scaled[i] = maxi(1, int(floor(float(counts[i]) * float(max_pile_pieces) / float(total))))
	return scaled


## Round-robin the plan into one sequence, so a yard holding two species stacks as
## a mixed pile rather than as two solid blocks. Which piece went on the pile first
## is not recoverable from a count, and a blended pile reads as wood accumulated
## over many logs, which is what it is.
func _interleave(plan: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var left := plan.duplicate()
	while not left.is_empty():
		for i: int in left.keys():
			out.append(i)
			left[i] = int(left[i]) - 1
			if int(left[i]) <= 0:
				left.erase(i)
	return out


## Stand-in firewood for a species, built once and cached.
##
## Built by SLICING that species' own log exactly the way the first two clicks on
## it would — two centre cuts into a quarter column, jagged cut faces, the
## species' own bark and inside grain. A box would have been cheaper and would
## have looked like a box next to the real pieces; this way a restored pile and a
## chopped one are made of the same thing. Lazy, so a species the player owns none
## of never loads its FBX at all.
func _specimens_for(species_index: int) -> Array:
	if _specimens.has(species_index):
		return _specimens[species_index]
	var out: Array = []
	var row: Dictionary = _LOG_SPECIES[species_index] if species_index >= 0 and species_index < _LOG_SPECIES.size() else {}
	var paths: Array = row.get("meshes", [])
	var mat := _cut_mat_for(species_index)
	# Two shapes is enough variety for a pile; six would be six FBX loads for
	# pieces that are mostly buried in the stack.
	for p_idx in range(mini(2, paths.size())):
		var whole := MeshUtils.centered(_build_split_log(paths[p_idx]))
		var billet := _quarter(whole, mat)
		if billet != null:
			out.append(billet)
	_specimens[species_index] = out
	return out


## Two centre cuts through a standing log -> a quarter column, which is what the
## chopping game's own early splits produce. Returns null if either cut degenerates
## (a mesh the plane misses), rather than a half-cut lump.
## NOTE it calls MeshUtils.jag_cut with the SPECIMEN'S material rather than going
## through _jag_cut(): that helper roughens whatever surface matches `_cut_mat`, the
## material of the log currently ON THE BLOCK, and a specimen for any other species
## would come back perfectly smooth (see the caching note on _cut_mat_for).
func _quarter(whole: ArrayMesh, mat: StandardMaterial3D) -> ArrayMesh:
	_cut_noise.frequency = cut_jag_freq
	var plane_x := Plane(Vector3.RIGHT, 0.0)
	var first := MeshSlicer.slice(whole, plane_x, mat)
	if first.below == null:
		return null
	var half := MeshUtils.jag_cut(first.below, plane_x, mat, cut_jag_amount, _cut_noise)
	var plane_z := Plane(Vector3.FORWARD, 0.0)
	var second := MeshSlicer.slice(half, plane_z, mat)
	if second.below == null:
		return null
	return MeshUtils.centered(
		MeshUtils.jag_cut(second.below, plane_z, mat, cut_jag_amount, _cut_noise))


## The yard pile changed under us — a save loaded, or a haul-away emptied it.
##
## The pieces THIS scene adds one at a time as they land also come through here,
## and must not trigger anything: the count check below is what tells the two
## apart. If the pile on screen already shows what GameState says it holds, there
## is nothing to rebuild, and a landing piece is by definition already shown.
func _on_yard_pile_changed(total: int) -> void:
	if _stacking or _awaiting_stack:
		return
	if _pile_root.get_child_count() == mini(total, max_pile_pieces):
		return
	_rebuild_pile_from_yard()


## A piece has come to rest on the pile. This is the moment the yard pays for it
## (Sam's call: converted to cash on entering the pile, never sold by hand), and
## the moment it starts counting toward the load that gets hauled away.
##
## The sale goes through Market like any other, so the price table stays the one
## place a piece's worth is decided and Directive 6 still holds — the stock leaves
## through InventoryManager and the cash arrives through GameState.
func _on_piece_landed(item_id: StringName) -> void:
	GameState.add_to_yard_pile(item_id, 1)
	if not auto_sell:
		return
	if Market.sell(item_id, 1) <= 0:
		# Priced at nothing, or nothing in stock to sell: the piece still stacks,
		# so the yard never eats wood it did not pay for.
		push_warning("chopping_minigame: '%s' landed on the pile but could not be sold." % item_id)


## The load is full: the whole pile leaves the yard in a staggered wave while the
## player carries on chopping into the empty space it left.
func _haul_away() -> void:
	if _pile.is_hauling:
		return
	var load_out: Array = []
	for c in _pile_root.get_children():
		_pile_root.remove_child(c)
		_haul_root.add_child(c)
		load_out.append(c)
	_pile.reset()
	GameState.clear_yard_pile()
	_pile.start_hauling(load_out)


## True once every live firewood body has (nearly) stopped, or the wait times out.
func _firewood_settled() -> bool:
	if Time.get_ticks_msec() / 1000.0 - _await_since >= firewood_settle_timeout:
		return true
	for f in _firewood:
		if is_instance_valid(f) and (f as RigidBody3D).linear_velocity.length() > firewood_settle_speed:
			return false
	return true


## Gather the settled firewood into script-animated proxies and fly them into the
## pile (reference _startStacking): each physics body is baked to a frozen proxy at
## its landed transform, then the pile animates it into its arc slot.
func _begin_stacking() -> void:
	_awaiting_stack = false
	var proxies: Array = []
	for f in _firewood:
		if not is_instance_valid(f):
			continue
		var body := f as RigidBody3D
		var src: MeshInstance3D = body.get_node_or_null("Mesh")
		if src == null or src.mesh == null:
			body.queue_free()
			continue
		var proxy := MeshInstance3D.new()
		proxy.mesh = src.mesh
		_pile_root.add_child(proxy)
		proxy.global_transform = body.global_transform
		proxies.append(proxy)
		body.queue_free()
	_firewood.clear()

	if proxies.is_empty():
		_spawn_fresh_log(false)
		return

	# COLLECT (A7): the log is fully chopped and its firewood has settled, so
	# each finished piece deposits one unit of the log's species into inventory.
	# This is the single batch-collect point (it mirrors the retired authored
	# block's collect semantics); unregistered ids are errored+ignored by
	# InventoryManager, so an empty/typo yield is safe.
	var yield_item: StringName = _current_species.get("yield_item", &"")
	if yield_item != &"":
		for _p in proxies:
			EventBus.resource_gathered.emit(yield_item, 1)

	_stacking = true
	# Each piece pays out as it comes to rest, so the cash ticks up in the same
	# cascade the player is watching land.
	_pile.start_stacking(proxies, Callable(), _on_piece_landed.bind(yield_item))


# --------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT: _orbit(-1)
			KEY_D, KEY_RIGHT: _orbit(1)
			KEY_R: _spawn_fresh_log()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(event.position)


func _on_click(screen_pos: Vector2) -> void:
	if not _pending.is_empty():
		return   # one strike resolves at a time (matches reference _pendingSplit gate)
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = _PICK_LAYER
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not (hit.collider in _on_block):
		return
	var piece: Area3D = hit.collider
	var normal := _camera.global_transform.basis.x
	normal.y = 0.0
	if normal.length() < 0.0001:
		return
	normal = normal.normalized()
	# Always cut the LONGER horizontal axis. Cutting the short axis of a piece
	# whose depth is bigger only shaves it into a flat slab (which then flies off);
	# cutting the long axis is what squares it up. So if the perpendicular axis is
	# meaningfully longer than the one we'd cut here, snap the camera 90 deg to face
	# it instead. The bias adds hysteresis so near-square pieces don't ping-pong,
	# and we only reorient while the long axis is still big enough to be worth it.
	var cross := _camera.global_transform.basis.z
	cross.y = 0.0
	if not piece.get_meta("is_whole_log", false) and cross.length() > 0.0001:
		cross = cross.normalized()
		var along := _piece_extent_along(piece, normal)
		var across := _piece_extent_along(piece, cross)
		if across > along * long_axis_bias and across >= min_cut_width:
			var half_w := get_viewport().get_visible_rect().size.x * 0.5
			_turn_cross_axis(-1 if screen_pos.x < half_w else 1)
			return
	var world_point: Vector3 = hit.position
	_swing_axe(world_point, normal)
	_pending = {
		"piece": piece, "world_point": world_point, "normal": normal,
		"dir": _dir_from_normal(normal), "timer": anticipation_sec,
	}


func _orbit(dir: int) -> void:
	_yaw_steps += dir
	_tween_pivot(deg_to_rad(_yaw_steps * camera_step_deg), orbit_time)


## Snap the camera ~90 deg (rounded to whole `camera_step_deg` steps so it stays on
## the orbit grid) so the swing crosses the piece's long axis. Forces firewood-
## sized chopping once a chunk is thin along the current cut direction.
func _turn_cross_axis(sign_dir: int) -> void:
	var steps := int(round(cross_axis_turn_deg / camera_step_deg))
	if steps == 0:
		steps = 1
	_yaw_steps += steps * sign_dir
	_tween_pivot(deg_to_rad(_yaw_steps * camera_step_deg), orbit_time)


func _tween_pivot(target_y: float, t: float) -> void:
	if _orbit_tween != null and _orbit_tween.is_valid():
		_orbit_tween.kill()
	_orbit_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_orbit_tween.tween_property(_pivot, "rotation:y", target_y, t)


# --------------------------------------------------------------- slicing
## Split the given on-block piece by a world plane through `world_point` with the
## given cut `normal`. Fires shake/pause/SFX, realises the two halves (firewood ->
## physics, chunky -> stays), and runs the radial shockwave over the block.
func _perform_split(piece: Area3D, world_point: Vector3, normal: Vector3, dir_enum: int) -> bool:
	# A slice must run on a settled mesh — snap any in-flight hop first.
	_animator.finish_for([piece])
	var mesh: Mesh = piece.get_meta("mesh_ref")
	var xform := piece.global_transform
	var world_plane := Plane(normal, normal.dot(world_point))
	world_plane = _square_bias(mesh, xform, world_plane)   # keep footprints square, not flat slabs
	var local_plane := _plane_to_local(world_plane, xform)
	local_plane = _sliver_guard(mesh, local_plane)

	var res := MeshSlicer.slice(mesh, local_plane, _cut_mat)
	if res.above == null or res.below == null:
		return false
	# Roughen the fresh cut faces so the split reads as cloven wood, not a laser cut.
	res.above = _jag_cut(res.above, local_plane)
	res.below = _jag_cut(res.below, local_plane)

	# A7: this is the ONLY hit path — GameFeel turns it into shake + hit-pause.
	# (Reference fires triggerShake right here, inside performSplit.)
	EventBus.action_hit_registered.emit(
		world_point, GameState.get_tool_tier(Enums.ToolType.AXE), dir_enum)
	_play_sfx(split_sfx)

	_on_block.erase(piece)
	piece.queue_free()

	var new_stays: Array = []
	for half: ArrayMesh in [res.above, res.below]:
		var out_sgn := 1.0 if half == res.above else -1.0
		var node := _realise_half(half, xform, normal * out_sgn)
		if node != null:
			new_stays.append(node)

	_apply_shockwave(world_point, new_stays)

	# Log fully chopped (nothing choppable left): wait for the firewood to settle,
	# then gather it into the pile and spawn a fresh log.
	if _on_block.is_empty():
		_awaiting_stack = true
		_await_since = Time.get_ticks_msec() / 1000.0
	return true


## Classify a freshly-sliced half and realise it. Returns the stay node, or null
## if it became firewood (physics).
func _realise_half(half: ArrayMesh, parent_xform: Transform3D, out_dir: Vector3) -> Area3D:
	var aabb := half.get_aabb()
	var c := aabb.position + aabb.size * 0.5
	var centered := _translate_mesh(half, -c)
	var world_pos := parent_xform * c

	var s := centered.get_aabb().size
	var vol := s.x * s.y * s.z
	# Fly-off (firewood) is judged on the HORIZONTAL footprint only — the un-cut
	# height (Y) is ignored, so a tall-but-still-wide piece doesn't fly off just for
	# being tall. It detaches when it's small (volume) or its footprint is a flat
	# slab (x:z aspect). With long-axis-forced cuts the footprint stays square, so
	# in practice pieces fly off by volume once they're a proper small chunk.
	var horiz_mx := maxf(s.x, s.z)
	var horiz_mn := maxf(minf(s.x, s.z), 0.0001)
	var is_firewood := vol <= min_vol or (horiz_mx / horiz_mn) > aspect_limit

	if is_firewood:
		_spawn_firewood(centered, world_pos, out_dir)
		return null
	var yaw := deg_to_rad(randf_range(-fresh_yaw_deg, fresh_yaw_deg))
	return _make_stay_piece(centered, world_pos, yaw)


## The radial "shockwave": every on-block piece pops away from the cut point, with
## distance falloff (near = big hop, far = none) and a staggered delay so it
## ripples outward. A hull-separation solver then de-overlaps the desired resting
## spots and keeps them inside the stump footprint before the hops are dispatched.
func _apply_shockwave(cut_point: Vector3, new_stays: Array) -> void:
	var cut2 := Vector2(cut_point.x, cut_point.z)
	var entries: Array = []
	for p: Area3D in _on_block:
		var pc := Vector2(p.position.x, p.position.z)
		var radial := pc - cut2
		var dist := radial.length()
		var dir2: Vector2
		if dist < 0.0001:
			var ang := randf() * TAU
			dir2 = Vector2(cos(ang), sin(ang))
		else:
			dir2 = radial / dist

		var push: float
		var pop: float
		var tilt: float
		var delay: float
		if p in new_stays:
			push = half_push; pop = pop_height; tilt = 1.0; delay = 0.0
		else:
			var u := maxf(0.0, 1.0 - dist / jostle_radius)
			push = jostle_push * u
			if push < 0.0005:
				continue   # too far to feel the strike — leave it resting
			pop = pop_height * u
			tilt = u
			delay = clampf(dist / delay_ref_dist, 0.0, 1.0) * stagger_ms

		entries.append({
			"piece": p, "hull": _hull2d(p.get_meta("mesh_ref"), p.quaternion),
			"dx": pc.x + dir2.x * push, "dz": pc.y + dir2.y * push,
			"pop": pop, "tilt": tilt, "delay": delay, "yaw": p.rotation.y,
		})

	_separate(entries, _stump_radius * clamp_radius_frac, sep_gap)

	for e: Dictionary in entries:
		var p: Area3D = e.piece
		var cur := Vector2(p.position.x, p.position.z)
		var d := Vector2(e.dx, e.dz) - cur
		_animator.animate(p, Vector3(d.x, 0.0, d.y), d.length(), e.pop, e.delay, e.tilt, e.yaw)


## Slice the first on-block piece by a WORLD plane, synchronously (no anticipation
## delay). Used by dev shots / poc_smoke.
func debug_slice_world(world_plane: Plane) -> bool:
	if _on_block.is_empty():
		return false
	var piece: Area3D = _on_block[0]
	var wp := world_plane.project(piece.global_position)
	return _perform_split(piece, wp, world_plane.normal, _dir_from_normal(world_plane.normal))


# ------------------------------------------------------- piece factories
func _make_stay_piece(centered_mesh: Mesh, world_pos: Vector3, yaw: float, is_whole_log := false) -> Area3D:
	var piece := Area3D.new()
	piece.collision_layer = _PICK_LAYER
	piece.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	piece.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = centered_mesh.create_convex_shape()
	piece.add_child(cs)
	_pieces_root.add_child(piece)
	piece.position = world_pos
	piece.quaternion = Quaternion(Vector3.UP, yaw)
	piece.set_meta("mesh_ref", centered_mesh)
	piece.set_meta("is_whole_log", is_whole_log)
	_on_block.append(piece)
	return piece


func _spawn_firewood(centered_mesh: Mesh, world_pos: Vector3, out_dir: Vector3) -> void:
	var body := RigidBody3D.new()
	body.physics_material_override = _phys_mat
	body.linear_damp = piece_linear_damp
	body.angular_damp = piece_angular_damp
	body.continuous_cd = true
	var vs := centered_mesh.get_aabb().size
	body.mass = maxf(wood_density * vs.x * vs.y * vs.z, min_mass)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = centered_mesh.create_convex_shape()
	body.add_child(cs)
	_fallers.add_child(body)
	body.global_position = world_pos

	var out := Vector3(out_dir.x, 0.0, out_dir.z)
	if out.length() > 0.0001:
		out = out.normalized()
	var to_cam := _camera.global_transform.basis.z   # points from scene toward the viewer
	to_cam.y = 0.0
	if to_cam.length() > 0.0001:
		to_cam = to_cam.normalized()
	body.linear_velocity = out * firewood_out + Vector3.UP * firewood_up + to_cam * firewood_toward_cam
	body.angular_velocity = Vector3(
		randf_range(-firewood_tumble, firewood_tumble),
		randf_range(-firewood_tumble, firewood_tumble),
		randf_range(-firewood_tumble, firewood_tumble))

	_firewood.append(body)
	while _firewood.size() > max_firewood:
		var old = _firewood.pop_front()
		if is_instance_valid(old):
			old.queue_free()


# --------------------------------------------------- separation solver (qC)
## Port of the reference's qC: 5 relaxation passes that (a) pull each piece's
## desired centre back inside the stump radius and (b) push overlapping piece
## hulls apart, using 2D convex-hull SAT in the ground plane.
func _separate(entries: Array, radius: float, gap: float) -> void:
	for _iter in range(5):
		var moved := false
		for e: Dictionary in entries:
			var k := _clamp_to_radius(e.hull, e.dx, e.dz, radius)
			if k.hit:
				e.dx += k.v.x; e.dz += k.v.y; moved = true
		for i in range(entries.size()):
			for j in range(i + 1, entries.size()):
				var a: Dictionary = entries[i]
				var b: Dictionary = entries[j]
				var g := _overlap(a.hull, a.dx, a.dz, b.hull, b.dx, b.dz, gap)
				if g.hit:
					a.dx -= g.v.x * 0.5; a.dz -= g.v.y * 0.5
					b.dx += g.v.x * 0.5; b.dz += g.v.y * 0.5
					moved = true
		if not moved:
			break


func _clamp_to_radius(hull: PackedVector2Array, dx: float, dz: float, r: float) -> Dictionary:
	var max_u := 0.0
	var ax := 0.0
	var az := 0.0
	for p in hull:
		var ex := p.x + dx
		var ez := p.y + dz
		var l := sqrt(ex * ex + ez * ez)
		var u := l - r
		if u > max_u and l > 1e-6:
			max_u = u; ax = ex / l; az = ez / l
	if max_u > 0.0:
		return {"hit": true, "v": Vector2(-ax * max_u, -az * max_u)}
	return {"hit": false, "v": Vector2.ZERO}


func _overlap(ha: PackedVector2Array, ax: float, az: float,
		hb: PackedVector2Array, bx: float, bz: float, gap: float) -> Dictionary:
	var axes := _edge_normals(ha)
	axes.append_array(_edge_normals(hb))
	var best := INF
	var best_axis := Vector2.ZERO
	var found := false
	for u: Vector2 in axes:
		var sa := _project(ha, ax, az, u)
		var db := _project(hb, bx, bz, u)
		var smin := sa.x - gap * 0.5
		var smax := sa.y + gap * 0.5
		var overlap := minf(smax - db.x, db.y - smin)
		if overlap <= 0.0:
			return {"hit": false, "v": Vector2.ZERO}   # a separating axis exists -> no overlap
		if overlap < best:
			best = overlap; best_axis = u; found = true
	if not found:
		return {"hit": false, "v": Vector2.ZERO}
	if best_axis.x * (bx - ax) + best_axis.y * (bz - az) < 0.0:
		best_axis = -best_axis
	return {"hit": true, "v": best_axis * best}


func _edge_normals(hull: PackedVector2Array) -> Array:
	var out: Array = []
	var n := hull.size()
	for i in range(n):
		var a := hull[i]
		var b := hull[(i + 1) % n]
		var dx := b.x - a.x
		var dz := b.y - a.y
		var l := sqrt(dx * dx + dz * dz)
		if l > 1e-8:
			out.append(Vector2(-dz / l, dx / l))
	return out


func _project(hull: PackedVector2Array, ox: float, oz: float, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in hull:
		var e := (p.x + ox) * axis.x + (p.y + oz) * axis.y
		lo = minf(lo, e)
		hi = maxf(hi, e)
	return Vector2(lo, hi)


# --------------------------------------------------------------- geometry
## 2D convex hull (ground plane) of a piece's mesh, rotated by its current
## orientation and centred on its origin. Reference VC().
func _hull2d(mesh: Mesh, q: Quaternion) -> PackedVector2Array:
	return MeshUtils.hull2d(mesh, q)


## World-space extent of a piece measured along `world_normal`. Reference pT().
func _piece_extent_along(piece: Area3D, world_normal: Vector3) -> float:
	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null:
		return INF   # unmeasurable -> never reorient the camera for it
	var e := MeshUtils.extent_along(mesh, world_normal, piece.global_transform)
	return e.y - e.x


func _dir_from_normal(normal: Vector3) -> int:
	return Enums.ChopDirection.RIGHT if normal.x >= 0.0 else Enums.ChopDirection.LEFT


# ----------------------------------------------------------------- setup
## Spawn a fresh log. `reset_pile` = true clears the accumulated pile too (the R
## debug key); the auto-respawn after stacking keeps the pile so it grows.
func _spawn_fresh_log(reset_pile := true) -> void:
	for p in _on_block:
		if is_instance_valid(p):
			p.queue_free()
	_on_block.clear()
	for f in _firewood:
		if is_instance_valid(f):
			f.queue_free()
	_firewood.clear()
	_animator.clear()
	_pending = {}
	_awaiting_stack = false
	_stacking = false

	if reset_pile:
		for c in _pile_root.get_children():
			c.queue_free()
		_pile.reset()
		# The pile is a view of the yard, not of the log on the block (see
		# _rebuild_pile_from_yard), so clearing it means rebuilding it — otherwise
		# an R-key reset would look like the yard had been robbed.
		_rebuild_pile_from_yard()

	# Select the next log's species — the species is what this log will yield,
	# and what its exposed end-grain looks like when it is cut.
	var species_index := _pick_species_index()
	_current_species = _LOG_SPECIES[species_index]
	_cut_mat = _cut_mat_for(species_index)
	_source_mesh = _center_mesh(_build_split_log(_pick_mesh(_current_species)))

	var half_h := _source_mesh.get_aabb().size.y * 0.5
	var rest_y := _stump_top_y + half_h
	var node := _make_stay_piece(_source_mesh, Vector3(0.0, rest_y, 0.0), 0.0, true)
	_animator.animate_drop(node, rest_y + drop_height, rest_y, Callable(self, "_play_drop_sfx"))


func _build_stump() -> void:
	var raw := _load_stump_mesh()
	var aabb := raw.get_aabb()
	var s := stump_scale
	var scaled := _scaled_mesh(raw, s)
	var mi := MeshInstance3D.new()
	mi.name = "StumpMesh"
	mi.mesh = scaled
	var cx := (aabb.position.x + aabb.size.x * 0.5) * s
	var cz := (aabb.position.z + aabb.size.z * 0.5) * s
	mi.position = Vector3(-cx, -aabb.position.y * s, -cz)
	add_child(mi)

	_stump_top_y = aabb.size.y * s
	_stump_radius = maxf(aabb.size.x, aabb.size.z) * 0.5 * s

	var body := StaticBody3D.new()
	body.physics_material_override = _phys_mat
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = _stump_radius
	cyl.height = _stump_top_y
	cs.shape = cyl
	cs.position = Vector3(0, _stump_top_y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------------- axe
func _build_axe() -> void:
	_axe = _AxeRig.new()
	_axe.hidden_euler = axe_hidden_euler
	_axe.struck_euler = axe_struck_euler
	_axe.hover = axe_hover
	_axe.swing_time = swing_time
	add_child(_axe)
	_axe.setup(_AXE_FBX, axe_scale)


## Swing the axe from the impact point (reference playFromImpact). Defaults let
## dev tools call _swing_axe() with no args.
func _swing_axe(world_point := Vector3(0.0, _stump_top_y, 0.0), _normal := Vector3.RIGHT) -> void:
	if _axe != null:
		_axe.swing(world_point)


# --------------------------------------------------------------- audio
func _play_drop_sfx() -> void:
	_play_sfx(drop_sfx)


func _play_sfx(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()


# --------------------------------------------------------------- materials
func _make_planar(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The cut-face material for a species, built once and cached.
##
## Cached rather than rebuilt per log for a reason beyond speed: MeshUtils.jag_cut
## identifies which surface of a freshly sliced piece is the CUT one by comparing
## `material == _cut_mat` by reference. Handing out a fresh instance per log would
## leave any piece cut before the swap unroughenable.
func _cut_mat_for(species_index: int) -> StandardMaterial3D:
	if _cut_mats.has(species_index):
		return _cut_mats[species_index]
	var row: Dictionary = _LOG_SPECIES[species_index] if species_index >= 0 and species_index < _LOG_SPECIES.size() else {}
	# Paths, not preloaded Textures, so a row reads the same way as its "mesh".
	var albedo := _tex_or(row.get("inside_tex", ""), _TEX_INSIDE)
	var normal := _tex_or(row.get("inside_normal", ""), _TEX_INSIDE_N)
	var mat := _make_planar(albedo)
	mat.normal_enabled = true
	mat.normal_texture = normal
	mat.normal_scale = 1.0
	mat.albedo_color = row.get("inside_tint", Color.WHITE)
	_cut_mats[species_index] = mat
	return mat


## Load a texture path, falling back to `fallback` when the row omits it or the
## path does not resolve (a typo must not leave a piece with an untextured cut).
func _tex_or(path: String, fallback: Texture2D) -> Texture2D:
	if path.is_empty():
		return fallback
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("chopping_minigame: inside texture '%s' did not load; using the default." % path)
		return fallback
	return tex


func _build_split_log(variant_path := "") -> ArrayMesh:
	var mesh := _load_log_mesh(variant_path)
	return _scaled_mesh(mesh, _fit_scale(mesh))


## Scale factor that brings ANY authored log mesh to `log_height`.
##
## This used to be a bare `log_scale` multiplier (13.0), which only meant
## anything against the raw units the FBX happened to be modelled in — log_01
## imports at 0.032 m tall, so 13x gave the ~0.42 m round the block, the cut
## thresholds and the pile spacing are all sized for. Then MeshUtils.mesh_from_
## scene started BAKING the transform authored on the FBX's MeshInstance3D
## (2026-07-27, for tree_02's 180x node scale) — and these logs carry ~33.9x
## (log_01) and ~31.6x (log_02) of their own. The same 13.0 then produced a
## 14 m log standing on the block with the camera inside it: no log appeared to
## spawn at all, and nothing errored.
##
## Deriving the scale from the mesh's own measured height cannot drift that way
## again, whatever an artist exports at, and it sizes both species alike.
func _fit_scale(mesh: Mesh) -> float:
	var h := mesh.get_aabb().size.y
	if h <= 0.0001:
		push_warning("chopping_minigame: log mesh has no height; leaving it unscaled")
		return 1.0
	return log_height / h


# --------------------------------------------------------------- helpers
func _plane_to_local(world_plane: Plane, xform: Transform3D) -> Plane:
	return MeshUtils.plane_to_local(world_plane, xform)


## Bias the cut so neither resulting piece is a flat slab. The cut plane is pushed
## in from the clicked edge until the thinner side's width (along the cut normal)
## is at least `width_depth_ratio` of the piece's depth (its extent perpendicular
## to the cut). If the piece is too small to split that squarely, this falls back
## to a centre cut (even halves) — the same trick the reference uses to keep
## firewood chunks roughly square rather than thin planks. `width_depth_ratio` = 0
## disables it (cuts land exactly where clicked).
func _square_bias(mesh: Mesh, xform: Transform3D, world_plane: Plane) -> Plane:
	if width_depth_ratio <= 0.0:
		return world_plane
	var n := world_plane.normal
	var cross := Vector3(-n.z, 0.0, n.x)      # perpendicular horizontal axis (the "depth" direction)
	if cross.length() < 0.0001:
		return world_plane
	cross = cross.normalized()
	var n_lo := INF
	var n_hi := -INF
	var c_lo := INF
	var c_hi := -INF
	for si in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for p in v:
			var w := xform * p
			var dn := w.dot(n)
			var dc := w.dot(cross)
			n_lo = minf(n_lo, dn); n_hi = maxf(n_hi, dn)
			c_lo = minf(c_lo, dc); c_hi = maxf(c_hi, dc)
	var width := n_hi - n_lo
	var depth := c_hi - c_lo
	var min_w := maxf(min_piece_size, depth * width_depth_ratio)
	min_w = minf(min_w, width * 0.5)          # too small to split squarely -> centre cut
	var o := clampf(world_plane.d, n_lo + min_w, n_hi - min_w)
	return Plane(n, o)


## Roughen a fresh cut face. Every vertex lying ON the cut plane is pushed along
## the normal by value noise, so the flat cut becomes cloven wood. The cap face and
## the side-wall rim share exact vertex positions and get the SAME displacement, so
## no cracks open between them. The cut surface (material == _cut_mat) is rebuilt as
## a soup with fresh flat normals so the bumps actually shade; the bark/end surfaces
## keep their normals (only their rim vertices nudge).
func _jag_cut(mesh: ArrayMesh, plane: Plane) -> ArrayMesh:
	_cut_noise.frequency = cut_jag_freq
	return MeshUtils.jag_cut(mesh, plane, _cut_mat, cut_jag_amount, _cut_noise)


func _sliver_guard(mesh: Mesh, local_plane: Plane) -> Plane:
	var aabb := mesh.get_aabb()
	var n := local_plane.normal
	var lo := INF
	var hi := -INF
	for cx in [aabb.position.x, aabb.position.x + aabb.size.x]:
		for cy in [aabb.position.y, aabb.position.y + aabb.size.y]:
			for cz in [aabb.position.z, aabb.position.z + aabb.size.z]:
				var d := n.dot(Vector3(cx, cy, cz))
				lo = minf(lo, d)
				hi = maxf(hi, d)
	var o := local_plane.d
	if hi - o < min_piece_size:
		o = hi - min_piece_size
	elif o - lo < min_piece_size:
		o = lo + min_piece_size
	return Plane(n, o)


func _center_mesh(src: Mesh) -> ArrayMesh:
	return MeshUtils.centered(src)


func _scaled_mesh(src: Mesh, s: float) -> ArrayMesh:
	return MeshUtils.scaled(src, s)


func _translate_mesh(src: Mesh, offset: Vector3) -> ArrayMesh:
	return MeshUtils.translated(src, offset)


## Which species the next log will be: forced index for headless tests,
## otherwise a random pick. The species row drives both the mesh and the yield.
func _pick_species_index() -> int:
	if debug_forced_species >= 0 and debug_forced_species < _LOG_SPECIES.size():
		return debug_forced_species
	return randi() % _LOG_SPECIES.size()


## Which authored log SHAPE of that species turns up. Picked separately from the
## species so log variety never changes how often a wood appears.
func _pick_mesh(species_row: Dictionary) -> String:
	var meshes: Array = species_row.get("meshes", [])
	if meshes.is_empty():
		push_error("chopping_minigame: species '%s' lists no meshes." % species_row.get("yield_item", "?"))
		return ""
	if debug_forced_mesh >= 0 and debug_forced_mesh < meshes.size():
		return meshes[debug_forced_mesh]
	return meshes[randi() % meshes.size()]


func _load_log_mesh(variant_path := "") -> Mesh:
	if variant_path.is_empty():
		variant_path = _pick_mesh(_LOG_SPECIES[_pick_species_index()])
	return MeshUtils.mesh_from_path(variant_path)


func _load_stump_mesh() -> Mesh:
	return MeshUtils.mesh_from_scene(_STUMP_FBX)


# ------------------------------------------------------- test/shot seams
func piece_count() -> int:
	return _on_block.size() + _firewood.size()


func cuttable_count() -> int:
	return _on_block.size()
