extends Node
## FILE: res://core/tests/m5_acceptance.gd
## ATTACHES TO: root Node of res://core/tests/m5_acceptance.tscn. Run (F6).
## Not shipped.
##
## Verifies M5 — the tree-felling mini-game (tree_felling.tscn / tree_felling.gd,
## Amendment 13: the wood is a voxel volume and the tree is felled by the book).
##
##   1. The wood is REAL. The felling band is a signed-distance field carved off
##      the tree's own shape; a blow subtracts the solid the axe displaces; the
##      chip that flies is the wood that left the hole; and anything the player
##      cuts free falls off, so no piece of this tree can ever be left floating.
##   2. The FACE NOTCH. Clicking one side of the trunk opens a notch there and
##      commits the tree to falling that way. Blows alternate between a steep
##      roof cut and a flatter floor cut on their own, and the notch reads as one
##      continuous V that deepens — not as scattered bites.
##   3. A notch ALONE does not fell a tree, however deep. That is the whole point
##      of the manual's method and it falls out of the load model, not a rule.
##   4. The BACK CUT. Clicking the far side cuts in level, automatically placed
##      the manual's two inches above the notch, and what is left in front of it
##      is the HOLDING WOOD.
##   5. The FELL CONDITION is a loaded beam and nothing else: the weight above
##      each height crushing and bending the wood left there, in every direction,
##      with the tree only able to go where the notch has opened room. It cracks
##      in warning on the way, leans the way it means to go, and breaks at the
##      back cut's height.
##   6. It goes over TOWARD THE NOTCH. Cut through the holding wood instead and
##      it goes at once with nothing steering it — the manual's cardinal sin.
##   7. THE FALL is simulated in both halves: attached and accelerating about the
##      real hinge under nothing but its own weight, then a rigid body that lands
##      and settles. It deposits the TreeDef yields, holds A12 throughout, and a
##      fresh tree stands up behind it.
##   8. Gear gate: an under-tier axe changes nothing until it is upgraded through
##      the real EventBus -> GameState path.
##
## Drives debug_blow() directly (no mouse), so it is fully headless — the actual
## click layer is NOT headless-verifiable; eyeball that in F5/F6. Waits are
## REAL-TIME timers, never frame counts: headless runs uncapped, so hundreds of
## frames can pass in a fraction of the game-clock second a fall needs.
## Calls get_tree().quit() when done — run with a generous --quit-after.

var _passes := 0
var _fails := 0
var _hit_count := 0
var _last_hit_tier := -1
var _last_hit_dir := -1
var _gathered: Dictionary = {}   # item_id -> total gathered since the last clear

const _FELLING := preload("res://scenes/3d_action/tree_felling.tscn")
const _BUDGET_SCRIPT := preload("res://scenes/3d_action/fragment_physics_budget.gd")


func _ready() -> void:
	print("=== M5 ACCEPTANCE — tree felling ===")
	EventBus.action_hit_registered.connect(_on_hit)
	EventBus.resource_gathered.connect(_on_gathered)
	_test_0_the_wood_itself()
	await _test_1_tree_data()
	await _test_2_the_face_notch()
	await _test_3_a_blow_takes_real_wood()
	await _test_4_the_back_cut_and_the_hinge()
	await _test_5_it_falls_toward_the_notch()
	await _test_6_gear_gate()
	await _test_7_fall_stocks_and_clears()
	await _test_8_debris_comes_to_rest()
	await _test_9_the_landing_hits()
	await _test_10_bucking_the_felled_trunk()
	await _test_11_cut_wherever_you_like()
	await _test_12_debris_ignores_the_timber()
	await _test_13_entry_angle_and_end_grain()
	await _test_14_first_person_aim()
	await _test_15_the_felled_trunk_persists()
	await _test_16_bucked_lengths_are_logs()
	await _test_17_stump_remains_and_logs_fly()
	print("=== M5 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M5 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _on_hit(_pos: Vector3, tool_tier: int, dir: Enums.ChopDirection) -> void:
	_hit_count += 1
	_last_hit_tier = tool_tier
	_last_hit_dir = dir


func _on_gathered(item: StringName, amount: int) -> void:
	_gathered[item] = int(_gathered.get(item, 0)) + amount


# --------------------------------------------------------------- helpers
## Instance the mini-game with a forced species (set BEFORE _ready so the first
## tree uses it) and let _ready() stand the trunk up.
##
## The load model's gravity, the CARVE settings and the natural lean are pinned
## to script defaults, so how many blows fell a tree and which way it goes are
## deterministic no matter what Sam has dialled the live scene to — the .tscn
## carries his feel tuning, which the acceptance run must not depend on.
## The legacy M5 geometry assertions were authored against tree_01. Keep that
## visual row pinned explicitly now that row 0 is tree_02 and the shipping
## forest is mixed.
func _make_game(forced_species := 1, auto_respawn := false) -> Node3D:
	var g: Node3D = _FELLING.instantiate()
	g.debug_forced_species = forced_species
	g.auto_respawn = auto_respawn
	g.gravity = 9.8
	g.natural_lean_deg = 0.0
	g.voxel_cell = 0.055
	g.bite_depth = 0.065
	# The CUT SHAPE is pinned for the same reason as the bite: how many blows fell a tree
	# depends on it completely, and Sam tunes these live in the .tscn. `cut_span` in
	# particular changes the mechanic rather than just the pace — narrower than the trunk
	# and a blow cuts a channel rather than the whole face, which has to be swept round
	# the trunk with the angle of entry.
	g.cut_span = 1.6
	g.cut_reach = 0.3
	g.entry_angle_deg = 30.0
	# THE DEV CAMERA, for the same reason everything above is pinned. The game is
	# first person now (2026-07-26) and the player walks, but almost every check here
	# measures which way a tree went against the camera's own right-vector — so the
	# suite needs to know where the eye is, not discover it. `player_controlled = false`
	# poses the player as a puppet at the fixed polar camera M5 was built and
	# render-verified with. The first-person aim itself is checked deliberately, on its
	# own, in _test_14.
	g.player_controlled = false
	# ...and the FELLED TRUNK clears itself. Persisting until bucked is what the game
	# ships with, and _test_15 is where that is checked; the rest of this suite is about
	# the fall, and wants the board to clear so it can watch the yields land.
	g.trunk_persists = false
	# ...and the timber is BOOKED IN AS THE BOARD CLEARS rather than flying to the player and
	# banking itself as it lands. Both are shipping behaviour (`logs_fly_to_player`), but the
	# flight defers the EMISSION by its travel time, and most checks here read the inventory the
	# moment they see the tree collect. The flight is checked on its own, in _test_17.
	g.logs_fly_to_player = false
	# ONE TREE. Every check in this suite is about one tree's wood, and it measures which
	# way that tree went against a known camera — so the stand is pinned to a single trunk
	# at the origin, exactly where M5 has always put it. The FOREST is checked on its own,
	# in _test_17.
	g.tree_count = 1
	add_child(g)
	await get_tree().process_frame
	return g


func _drop(g: Node) -> void:
	g.queue_free()
	await get_tree().process_frame   # let _exit_tree() hand the camera back first


## Chop the face notch until it is `frac` of the way through the trunk.
## Which level the axe has taken the largest FRACTION of, against what that level started
## as. Never the plain smallest section: these trunks taper by a factor of three over the
## band, so the plain smallest is the top of the band on a tree nobody has touched.
func _most_cut(lv: Array[Dictionary], base: PackedFloat32Array) -> int:
	var worst := 0
	var best := INF
	for j in range(1, lv.size() - 1):
		if j >= base.size() or base[j] <= 0.0:
			continue
		var frac: float = lv[j].area / base[j]
		if frac < best:
			best = frac
			worst = j
	return worst


## WHERE THIS SUITE PUTS ITS NOTCH — just above the root flare, on the clear stem.
##
## It was a bare 0.5 m, which is where a faller's notch goes on THESE trees and was
## unambiguous while the flare was not carveable: `band_lo` sat on top of it, so 0.5 was
## clamped up onto the stem anyway on both species. `voxel_roots` (2026-07-31) drops the
## band's floor to the dirt so the axe can reach the roots — Sam's ask — and 0.5 is then
## INSIDE tree_01's flare, which is a different cut with a different answer: a buttressed
## section carries the tree at a stress a stem would have failed at, so the player chops on
## past it and severs the trunk instead of hinging it over. Real, and the manual's own
## reason for notching above the flare — but not what the checks below are about.
##
## Derived rather than moved to another bare number, because the flare is a property of
## each asset and Sam re-exports these trees.
func _stem_y(g: Node) -> float:
	var trunk: TreeTrunk = g.trunk()
	if trunk == null or not is_instance_valid(trunk) or not trunk.is_built():
		return 0.5
	return clampf(trunk.debug_flare_top() + 0.1,
		g.debug_min_cut_height(trunk), g.debug_max_cut_height(trunk))


func _notch_to(g: Node, frac: float, y := -1.0, limit := 30) -> int:
	var n := 0
	var at: float = _stem_y(g) if y < 0.0 else y
	while n < limit and g.notch_depth() < frac and not g.is_felling():
		if not g.debug_blow(1, at) and not g.is_felling():
			break
		n += 1
		await get_tree().process_frame
	return n


## Keep chopping the notch until the tree gives way. There is no back cut any more —
## every blow is a head-on cut on the side you can see (Sam, 2026-07-25), so felling is
## simply a matter of taking the notch far enough through the trunk.
func _chop_until_fell(g: Node, y := -1.0, limit := 40) -> int:
	var n := 0
	var at: float = _stem_y(g) if y < 0.0 else y
	while n < limit and not g.is_felling():
		g.debug_blow(1, at)
		n += 1
		await get_tree().process_frame
	return n


# ---------------------------------------------------- the wood, on its own
## WoodVolume with no game around it: the field has to carve honestly and it has
## to let go of wood that nothing is holding up.
func _test_0_the_wood_itself() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 2.0
	cyl.radial_segments = 24
	var mesh := MeshUtils.translated(cyl, Vector3(0.0, 1.0, 0.0))   # base at y = 0
	var vol := WoodVolume.new()
	_check(vol.build(mesh, 0.0, 1.0, Vector2.ZERO, 0.5, 0.05),
		"a wood volume builds from a mesh")
	var whole := vol.volume()
	var want := PI * 0.16 * 1.0
	_check(absf(whole - want) < want * 0.15,
		"it measures the wood that is actually there (%.3f m3 of a %.3f m3 column)" % [whole, want])

	# A blow takes what it displaces and hands back that exact wood as a chip.
	var slab: Array[Plane] = [
		Plane(Vector3.UP, 0.62), Plane(Vector3.DOWN, -0.52),
		Plane(Vector3.RIGHT, 0.5), Plane(Vector3.LEFT, 0.5),
		Plane(Vector3.BACK, 0.5), Plane(Vector3.FORWARD, 0.5),
	]
	var cut := vol.carve(slab, AABB(Vector3(-0.6, 0.45, -0.6), Vector3(1.2, 0.3, 1.2)), null)
	_check(cut.volume > 0.02, "a carve removes real volume (%.3f m3)" % cut.volume)
	_check(absf(vol.volume() - (whole - cut.volume)) < 0.005,
		"...exactly the volume it says it removed")

	# The top is now standing on nothing. It reaches the top of the band, so it
	# is the standing tree and NOT a chip — that call belongs to the load model.
	_check(vol.remove_floating(null).is_empty(),
		"the part still reaching the top of the band is not treated as debris")

	# Cut a second slot lower down and the block between them is holding on to
	# nothing at all. That block must fall off on its own.
	var slab2: Array[Plane] = [
		Plane(Vector3.UP, 0.32), Plane(Vector3.DOWN, -0.22),
		Plane(Vector3.RIGHT, 0.5), Plane(Vector3.LEFT, 0.5),
		Plane(Vector3.BACK, 0.5), Plane(Vector3.FORWARD, 0.5),
	]
	vol.carve(slab2, AABB(Vector3(-0.6, 0.15, -0.6), Vector3(1.2, 0.3, 1.2)), null)
	var freed := vol.remove_floating(null)
	_check(freed.size() == 1, "wood that nothing is holding up comes away (%d pieces)" % freed.size())
	if freed.size() == 1:
		_check(freed[0].volume > 0.02, "...and it is the block between the two cuts (%.3f m3)" % freed[0].volume)
		_check(absf((freed[0].centre as Vector3).y - 0.42) < 0.12,
			"...taken from between them (y = %.2f)" % (freed[0].centre as Vector3).y)
	else:
		_fails += 2
	_check(vol.remove_floating(null).is_empty(),
		"nothing is left floating once it has let go — the field cannot hold air up")

	# Sections count the WOOD, never the air between two remnants. This is the
	# whole fell condition: a trunk chopped through with slivers left either side
	# has to read as the slivers, not as a full-width trunk.
	var v2 := WoodVolume.new()
	v2.build(mesh, 0.0, 1.0, Vector2.ZERO, 0.5, 0.05)
	var mid: Array[Plane] = [
		Plane(Vector3.RIGHT, 0.22), Plane(Vector3.LEFT, 0.22),
		Plane(Vector3.UP, 2.0), Plane(Vector3.DOWN, 2.0),
		Plane(Vector3.BACK, 1.0), Plane(Vector3.FORWARD, 1.0),
	]
	v2.carve(mid, AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.3, 1.2)), null)
	var lv: Array[Dictionary] = v2.level_stats()
	var e: Dictionary = lv[lv.size() / 2]
	var span := (e.sup as PackedFloat32Array)[0] + (e.sup as PackedFloat32Array)[8]
	_check(e.area > 0.05 and e.area < 0.45,
		"a section counts the wood, not the air between remnants (%.3f m2 over a %.2f m span)" % [
			e.area, span])
	_check(span > 0.7, "...even though the remnants still span the full width (%.2f m)" % span)

	# THE BAND MUST NOT BE SEE-THROUGH. Godot's front face is the clockwise one, so
	# a triangle is seen from the side its right-hand-rule normal points AWAY from;
	# the mesher hands every vertex an outward shading normal, so correct geometry
	# has RHR OPPOSING it. The mesher had this backwards until 2026-07-25 and the
	# carved butt's CULL_BACK bark was culled from outside — you could see through
	# the choppable part of the tree to the inside of its far wall. It survived a
	# render-to-PNG check because a hollow trunk still has a trunk's silhouette.
	var bark := StandardMaterial3D.new()
	var band := vol.build_mesh(bark, bark)
	var w := MeshUtils.winding_report(band)
	_check(w.oppose > 0 and w.agree == 0,
		"the carved band faces outward, not inside out (%d agree, %d oppose)" % [w.agree, w.oppose])
	# The chips a blow throws are meshed by the same code down a different path.
	var v3 := WoodVolume.new()
	v3.build(mesh, 0.0, 1.0, Vector2.ZERO, 0.5, 0.05)
	var chip := v3.carve(slab, AABB(Vector3(-0.6, 0.45, -0.6), Vector3(1.2, 0.3, 1.2)), bark)
	var cw := MeshUtils.winding_report(chip.chip)
	_check(cw.oppose > 0 and cw.agree == 0,
		"...and so does the chip it threw (%d agree, %d oppose)" % [cw.agree, cw.oppose])


# ----------------------------------------------------------------- tests
func _test_1_tree_data() -> void:
	var g := await _make_game()
	var td: TreeDef = g.tree_def()
	_check(td != null, "the species table loads a TreeDef")
	_check(td.hardness_level >= 1, "TreeDef carries a hardness_level (%d)" % td.hardness_level)
	var leaves := 0
	for f: FragmentDef in td.yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			leaves += 1
	_check(leaves > 0, "TreeDef carries at least one leaf yield")

	var trunk: TreeTrunk = g.trunk()
	_check(trunk != null and trunk.is_built(), "the tree is built and standing")
	_check(not trunk.has_cut(), "an unstruck tree is whole — nothing is pre-cut")
	_check(trunk.picker() != null, "the whole tree is clickable (one pick volume)")
	var vol: WoodVolume = trunk.volume()
	_check(vol.nx >= 12 and vol.nz >= 12 and vol.ny >= 12,
		"the felling band is voxelised at a usable resolution (%dx%dx%d)" % [vol.nx, vol.ny, vol.nz])
	_check(vol.nx * vol.cell > trunk.diameter,
		"the grid covers the whole trunk (%.2f m across a %.2f m trunk)" % [
			vol.nx * vol.cell, trunk.diameter])
	_check(absf(trunk.full_area() - PI * trunk.radius * trunk.radius) < trunk.full_area() * 0.2,
		"an uncut section measures about a full round trunk (%.3f m2)" % trunk.full_area())
	_check(trunk.band_hi > trunk.band_lo and trunk.band_hi < trunk.height * 0.5,
		"the carveable band is the bottom of the trunk only (%.2f..%.2f of %.1f m)" % [
			trunk.band_lo, trunk.band_hi, trunk.height])
	_check(is_zero_approx(g.notch_depth()), "a fresh tree has no notch")
	_check(g.face_side() == 0, "...and has not been committed to a direction")
	_check(g.fallen_trunk() == null, "nothing is falling yet")
	_check(is_zero_approx(g.last_stress()),
		"an untouched tree carries no stress (%.3f)" % g.last_stress())
	await _drop(g)


func _test_2_the_face_notch() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	var vol: WoodVolume = trunk.volume()
	# Every level's area BEFORE a single blow. "Has this height been cut" has to be
	# judged against what the height started as, not against the trunk's average:
	# tree_01 tapers, and by 1.9 m up its own untouched section is 3% under the
	# median, which a median-based test reads as a chop that was never made. That
	# went unnoticed while the carveable band was a 1.3 m stub where the taper never
	# amounted to anything.
	var base := PackedFloat32Array()
	for e in trunk.sections():
		base.append(e.area)

	# The first blow picks the side, and that is the direction of fall.
	var cam: Camera3D = g.camera()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	_check(g.debug_blow(1, 0.55), "the first blow bites")
	await get_tree().process_frame
	_check(g.face_side() == 1, "the side that was struck is now the face notch's side")
	_check(g.fall_direction().dot(right) > 0.7,
		"...and the tree is committed to falling that way (dot %.2f)" % g.fall_direction().dot(right))
	_check(g.notch_depth() > 0.0, "the notch has been opened (%.0f%%)" % (g.notch_depth() * 100.0))

	# It lands where it was aimed: the wood at that height is what thinned. Which
	# height thinned MOST is judged against each level's own starting area — the same
	# point the comment above `base` makes, and it is not optional now that the band
	# spans three metres of a trunk that tapers by a factor of three over it. The plain
	# smallest section on an untouched tree is the TOP of the band.
	var lv: Array[Dictionary] = trunk.sections()
	var full := trunk.full_area()
	var worst_j := _most_cut(lv, base)
	_check(absf(lv[worst_j].y - 0.55) < 0.25,
		"the blow landed where it was aimed (%.2f m, aimed at 0.55)" % lv[worst_j].y)

	# Blows alternate roof/floor on their own, so a run of clicks on one side
	# carves the manual's drop-notch rather than one repeated slot.
	var blows := await _notch_to(g, 0.5, 0.55)
	_check(g.notch_depth() >= 0.45,
		"clicking the same side deepens ONE notch to %.0f%% in %d blows" % [
			g.notch_depth() * 100.0, blows + 1])
	_check(not g.is_felling(),
		"a face notch on its own does NOT fell the tree — the manual's whole point")

	# The notch is a real V: the wood removed at the apex is far more than at the
	# heights above and below it, and it is one continuous pocket.
	lv = trunk.sections()
	worst_j = _most_cut(lv, base)
	_check(lv[worst_j].area < base[worst_j] * 0.65,
		"the notch has taken most of one side at the apex (%.3f of the %.3f m2 that was there)" % [
			lv[worst_j].area, base[worst_j]])
	var above_j: int = mini(worst_j + 4, lv.size() - 1)
	var below_j: int = maxi(worst_j - 4, 0)
	# ...as FRACTIONS of what each height started as. Comparing raw areas up a tapering
	# trunk asks whether the trunk is narrower higher up, which it always is.
	var cut_at: float = lv[worst_j].area / base[worst_j]
	var cut_above: float = lv[above_j].area / base[above_j]
	var cut_below: float = lv[below_j].area / base[below_j]
	_check(cut_above > cut_at and cut_below > cut_at,
		"...and tapers away above and below it — a wedge, not a slot (%.2f / %.2f / %.2f of full)" % [
			cut_below, cut_at, cut_above])
	# Continuous: no untouched band stranded inside the carve. Each level against
	# its own starting area, so the trunk's natural taper is not read as a cut.
	var cut_lo := -1
	var cut_hi := -1
	for j in range(mini(lv.size(), base.size())):
		if lv[j].area < base[j] * 0.97:
			if cut_lo < 0:
				cut_lo = j
			cut_hi = j
	var stranded := 0
	for j in range(cut_lo, cut_hi + 1):
		if lv[j].area >= base[j] * 0.99:
			stranded += 1
	_check(cut_lo >= 0 and stranded == 0,
		"the carve is ONE continuous notch — no untouched band stranded inside it (levels %d..%d)" % [
			cut_lo, cut_hi])
	# And the notch is on the fall side: the wood that is left has moved away
	# from it, which is what gives gravity something to work with.
	var fl: Vector3 = trunk.global_transform.basis.inverse() * g.fall_direction()
	var cf: float = lv[worst_j].cx * fl.x + lv[worst_j].cz * fl.z
	_check(cf < -0.05,
		"the wood left at the notch sits back from the fall side (%.3f m)" % cf)

	# Nothing is ever left hanging in the air.
	_check(vol.remove_floating(null).is_empty(),
		"no piece of the carved trunk is left floating")
	await _drop(g)


func _test_3_a_blow_takes_real_wood() -> void:
	var g := await _make_game()
	# Count chips exactly, so silence the crack debris (a deep notch can cross a
	# crack threshold and the extra splinters would foul the count).
	g.crack_chips = 0
	var trunk: TreeTrunk = g.trunk()
	var vol: WoodVolume = trunk.volume()
	var hits0 := _hit_count
	var wood0 := vol.volume()

	# The OPENING blow sets both faces of the notch at once, so it lifts out two
	# pieces; every blow after it takes one.
	_check(g.debug_blow(1, 0.5), "a blow on the tree lands")
	await get_tree().process_frame
	_check(g.chip_count() > g.chop_splinters,
		"the opening blow throws the wood it took on top of its %d splinters (%d bodies)" % [
			g.chop_splinters, g.chip_count()])
	_check(vol.volume() < wood0 - 0.002,
		"the tree is that much lighter (%.4f m3 gone)" % (wood0 - vol.volume()))
	_check(_hit_count - hits0 == 1, "exactly one action_hit_registered per blow")
	_check(_last_hit_tier == GameState.get_tool_tier(Enums.ToolType.AXE),
		"the hit carries the acting axe tier (%d)" % GameState.get_tool_tier(Enums.ToolType.AXE))
	_check(_last_hit_dir == Enums.ChopDirection.RIGHT,
		"the hit reports the side the axe came from")

	# EVERY PIECE OF DEBRIS IS A SPLINTER. The wood a blow removes used to be thrown
	# as the carved geometry itself, which is honest and looked wrong: a bite is a
	# thin flake off the face of a cut, so the ground filled up with flat discs.
	# Sam's call, 2026-07-25 — the debris is splinters, and the volume removed only
	# decides how many.
	var stick := Vector3(g.splinter_stick_thick, g.splinter_stick_len, g.splinter_stick_thick)
	var odd := 0
	var counted := 0
	for b in g.get_node("Fallers").get_children():
		if not (b is RigidBody3D):
			continue
		var m: Mesh = b.get_node("MeshInstance3D").mesh
		if m == null:
			continue
		counted += 1
		# A splinter is a long thin stick, whatever size the exports say.
		var size := m.get_aabb().size
		var dims: Array[float] = [size.x, size.y, size.z]
		dims.sort()
		if dims[2] < dims[0] * 3.0 or dims[2] > stick.y * 2.0:
			odd += 1
	_check(counted > 0 and odd == 0,
		"every piece of debris a blow throws is a splinter, not a flat flake (%d of %d odd)" % [
			odd, counted])

	# ...and MORE wood removed means MORE splinters, so a big bite still reads bigger
	# than a small one.
	var few: int = g._splinters_for(0.001)
	var many: int = g._splinters_for(0.02)
	_check(many > few,
		"a bigger bite of wood throws more of them (%d splinters vs %d)" % [many, few])

	# Blow after blow keeps eating in — the cut advances because the axe finds
	# the wood where it now is, not because anything told it to.
	var before := vol.volume()
	var chips_before: int = g.chip_count()
	g.debug_blow(1, 0.5)
	await get_tree().process_frame
	_check(vol.volume() < before - 0.001, "the next blow eats further in")
	_check(g.chip_count() - chips_before > g.chop_splinters,
		"...and throws the wood it took along with its splinters (%d bodies)" % (
			g.chip_count() - chips_before))
	await _drop(g)


func _test_4_the_back_cut_and_the_hinge() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	var blows := await _notch_to(g, 0.6)
	_check(g.notch_depth() >= 0.55,
		"the notch is cut past the middle of the trunk (%.0f%% in %d blows)" % [
			g.notch_depth() * 100.0, blows])
	var hold_after_notch: float = g.holding_wood()
	var stress_after_notch: float = g.last_stress()
	_check(not g.is_felling(), "and it is still standing")

	# Keep driving the SAME cut in. There is no back cut and nothing is struck from behind
	# the tree (Sam, 2026-07-25) — the holding wood is simply what is left behind the notch,
	# and the tree comes over when that cannot carry it any more.
	# THE SAME height the notch was cut at — see `_stem_y`. A blow at a different height is
	# a different cut, and this whole test is about driving ONE of them in.
	var at := _stem_y(g)
	_check(g.debug_blow(1, at), "another blow on the same cut lands")
	await get_tree().process_frame
	_check(g.holding_wood() < hold_after_notch,
		"the holding wood thins (%.3f -> %.3f m2)" % [hold_after_notch, g.holding_wood()])

	# Stress climbs as the wood behind the cut narrows, and the tree announces it.
	var stresses: Array[float] = [stress_after_notch]
	var more := 1
	while more < 40 and not g.is_felling():
		g.debug_blow(1, at)
		await get_tree().process_frame
		stresses.append(g.last_stress())
		more += 1
	_check(g.is_felling(), "chopping on fells it (%d + %d = %d blows)" % [blows, more, blows + more])
	var rising := true
	for i in range(1, stresses.size()):
		if stresses[i] < stresses[i - 1] - 0.001:
			rising = false
	_check(rising, "stress climbed with every blow, never lurched back (%.2f -> %.2f)" % [
		stresses[0], stresses[stresses.size() - 1]])
	_check(stresses[stresses.size() - 1] >= g.fail_stress,
		"it was the LOAD that won, not a budget (stress %.2f)" % stresses[stresses.size() - 1])
	_check(g.crack_count() >= 2,
		"the wood cracked in warning as the load climbed (%d cracks)" % g.crack_count())
	_check(g.hinge_was_intact(),
		"there was still holding wood when it went — the cut did not go clean through")
	_check(g.hinge_thickness() > 0.02 and g.hinge_thickness() < trunk.diameter * 0.4,
		"...and it was a hinge, not a plank (%.3f m of a %.2f m trunk)" % [
			g.hinge_thickness(), trunk.diameter])
	_check(absf(trunk.break_height() - g.notch_height()) < 0.12,
		"it broke at the cut (%.2f m, cut at %.2f)" % [
			trunk.break_height(), g.notch_height()])

	# Blows are refused once it is going over, and change nothing.
	var hits0 := _hit_count
	var hold0: float = g.holding_wood()
	_check(not g.debug_blow(1), "blows are refused once the tree is going over")
	_check(_hit_count == hits0 and is_equal_approx(g.holding_wood(), hold0),
		"a refused blow fires no hit and changes no wood")
	await _drop(g)


func _test_5_it_falls_toward_the_notch() -> void:
	# Cut by the book and it goes where the notch points — and it can only go
	# where the notch has opened room, which is the manual's reason for putting
	# the back cut higher than the notch.
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	var cam: Camera3D = g.camera()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	await _notch_to(g, 0.6)
	var room_notch: float = g.topple_room(g.dir_index_of(right))
	var room_back: float = g.topple_room(g.dir_index_of(-right))
	_check(room_notch > room_back + 0.1,
		"the notch is the only side with room to fall into (%.2f m vs %.2f m behind)" % [
			room_notch, room_back])
	# It leans the way it means to go, well before it goes — that lean is the
	# only warning the player gets, so it has to be there and it has to point
	# somewhere. (Real time, because the lean eases in over `lean_time`.)
	_check(g.last_stress() > g.lean_start_stress,
		"a notched tree is already visibly loaded (stress %.2f)" % g.last_stress())
	await _wait(g.lean_time + 0.3)
	_check(g.lean_deg() > 0.05,
		"...so it leans the way it is going before it goes (%.2f deg)" % g.lean_deg())
	_check(trunk.base_offset() < 0.001,
		"...and the base stays planted in the ground while it does (moved %.4f m)" % trunk.base_offset())
	# ...AND THE TWO HALVES OF THE TREE STAY JOINED WHILE IT LEANS. Only the crown
	# swings (the butt is voxels and never moves), so the crown has to pivot on its own
	# base or its base swings sideways off the top of the carved butt — by (crown base -
	# pivot) x sin(lean), which with the band now covering the whole clear trunk was
	# 14.5 cm across a trunk 0.47 m in radius. That is what Sam saw as the part above the
	# voxels not connecting and sliding off part way through chopping.
	var crown: MeshInstance3D = trunk.get_node_or_null("Crown")
	if crown == null or crown.mesh == null:
		_check(false, "the tree has a crown to check the join on")
	else:
		var base_y: float = crown.mesh.get_aabb().position.y
		var on_axis := Vector3(trunk.axis_xz.x, base_y, trunk.axis_xz.y)
		var moved: float = (crown.transform * on_axis - on_axis).length()
		_check(g.lean_deg() > 0.05 and moved < 0.01,
			"...while the crown stays joined to the carved butt (its base moved %.4f m at %.2f deg)" % [
				moved, g.lean_deg()])

	var proper_blows := await _chop_until_fell(g)
	_check(g.is_felling(), "it fells")
	# Kept for the under-notched comparison further down, while this tree still exists.
	var proper_deep: float = g.notch_depth()
	# Toward the NOTCH, which is not the same as "toward screen-right" any more: the first
	# cut's angle of entry sets the fall line, and at the default 30 degrees that line runs
	# diagonally toward the viewer rather than straight across the frame.
	_check(g.fall_direction().dot(g.notch_direction()) > 0.6,
		"it goes over toward the notch (dot %.2f)" % g.fall_direction().dot(g.notch_direction()))
	_check(g.notch_direction().dot(right) > 0.2,
		"...and the notch is on the side that was struck (dot %.2f)" % g.notch_direction().dot(right))

	# THE FALL, first half: still attached, turning about the real hinge, driven
	# by nothing but the weight hanging past it — so it starts slow and builds.
	var tilts: Array[float] = []
	var hinged := false
	for i in range(240):
		await _wait(0.05)
		if g.is_hinging():
			hinged = true
			tilts.append(g.fall_tilt_deg())
		if g.is_falling_physically():
			break
	_check(hinged, "the tree hangs off its hinge before it is a free body")
	_check(tilts.size() >= 3, "...for long enough to read (%d samples)" % tilts.size())
	if tilts.size() >= 3:
		var first: float = tilts[1] - tilts[0]
		var last: float = tilts[tilts.size() - 1] - tilts[tilts.size() - 2]
		_check(last > first,
			"...and it ACCELERATES — slow at first, then it is going (%.2f -> %.2f deg/step)" % [
				first, last])
		_check(tilts[0] < 25.0, "...starting from where it stood, with no shove (%.1f deg)" % tilts[0])
	else:
		_fails += 2

	# Second half: a real rigid body, which lands and comes to rest on its own.
	var body: RigidBody3D = g.fallen_trunk()
	_check(body != null and is_instance_valid(body), "past committing it is handed to physics")
	if body != null and is_instance_valid(body):
		_check(not body.freeze, "the falling trunk is a live rigid body, not an animation")
		_check(body.mass > 100.0, "it has the mass of a tree (%.0f kg)" % body.mass)
		_check(_has_shape(body), "it has a collider to land on")
		# ...AND THE COLLIDER IS ROUND THE WOOD, which is a different question and the one
		# that was never asked. A single cylinder on the body's local Y axis SPANNED the
		# whole trunk and still sat beside it: the body's origin is the hinge, which a deep
		# notch drags off the trunk's centre, and the generator leans and wanders every
		# trunk on top of that. MEASURED on tree_02 before the fix: 74% of the timber's
		# vertices outside the collider, the worst by 2.72 m, and the woody crown with
		# nothing under it at all. Sam: "when a tree falls, the top half penetrates through
		# the floor." See `TreeTrunk.timber_slices`.
		var fit := _wood_outside_collider(body)
		_check(fit.total > 100, "...and there is timber to measure it against (%d verts)" % fit.total)
		_check(fit.outside < fit.total * 0.05,
			"...and the collider is round the wood, not beside it (%.1f%% of it outside)" % [
				100.0 * float(fit.outside) / maxf(float(fit.total), 1.0)])
		_check(fit.worst < 0.10,
			"...with no part of the timber hanging out of it (worst %.3f m)" % fit.worst)
		_check(body.angular_velocity.length() > 0.05,
			"it carries the spin it already had (%.2f rad/s) — no reset at the hand-over" % \
			body.angular_velocity.length())
	else:
		_fails += 7
	for i in range(80):
		await _wait(0.1)
		if g.has_settled():
			break
	_check(g.has_landed(), "it hits the ground (GameFeel impact fires on contact)")
	_check(g.has_settled(), "and comes to rest on its own")
	_check(g.fall_tilt_deg() > 60.0, "it ends up down, not propped on its stump (%.0f deg)" % g.fall_tilt_deg())
	# ...ON the dirt rather than through it. The floor sits a few mm above y = 0, so a
	# vertex below it is timber inside the ground. The other half of the same bug: with
	# one cylinder this measured -0.35 m on tree_01 and -2.64 m on tree_02.
	if body != null and is_instance_valid(body):
		_check(_lowest_wood(body) > -0.10,
			"...and lying ON the ground, not sunk into it (lowest wood at y %.3f)" % _lowest_wood(body))
	else:
		_fails += 1
	await _drop(g)

	# ...and the other way round. UNDER-NOTCH the tree — a token notch, nowhere near the
	# middle of the trunk — and keep cutting the back anyway. There is no room for it to
	# hinge over, so it stands there while the back cut eats the wood out from under it:
	# the manual's cardinal sin, and it is not scripted anywhere. What it COSTS is the
	# measure of it, and the cost is enormous — the properly notched tree above went over
	# after a back cut a fifth of the way in, leaving a real hinge.
	var g2 := await _make_game()
	for i in range(2):
		g2.debug_blow(1, 0.5)
		await get_tree().process_frame
	_check(g2.notch_depth() < 0.3,
		"a token notch is only %.0f%% of the diameter" % (g2.notch_depth() * 100.0))
	_check(g2.topple_room(g2.dir_index_of(g2.fall_direction())) < g2.topple_min_open,
		"...which is not enough room for the tree to go that way")
	var n := 0
	var deep := 0.0
	while n < 40 and not g2.is_felling():
		g2.debug_blow(-1)
		await get_tree().process_frame
		deep = maxf(deep, g2.notch_depth())
		n += 1
	_check(g2.is_felling(), "cutting the back regardless does bring it down (%d more blows)" % n)
	_check(deep > 0.6,
		"...but only after the back cut has gone most of the way through (%.0f%%)" % (deep * 100.0))
	# THE POINT, and it is the manual's: the back cut has had to be driven through what
	# should have been the hinge. It is no longer true that NOTHING steers it — once the
	# holding wood is a sliver there is genuinely nothing left sticking out toward the
	# fall side, so the load model honestly allows it a little. The sin is still the sin,
	# and what it costs is the measure of it.
	_check(deep > 0.6,
		"...only once the cut is well past the middle of the trunk (%.0f%%, a proper one went at %.0f%%)" % [
			deep * 100.0, proper_deep * 100.0])
	_check(n > proper_blows * 2,
		"...and taking far more blows to do it (%d against %d)" % [n, proper_blows])
	await _drop(g2)


func _has_shape(body: Node) -> bool:
	for c in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			return true
	return false


## Every vertex of the TIMBER a body carries, in the body's own frame. The shed canopy
## is left out: it is visual only and goes on the landing frame.
##
## NOTE it samples VERTICES, never `xform * mesh.get_aabb()`. Transforming an AABB gives
## the box bounding the ROTATED BOX, not the rotated mesh, so a felled trunk reads as
## metres deeper than it is — that mismeasurement is what first made this bug look like
## a length problem.
func _wood_points(body: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in body.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or mi.name == "ShedCanopy":
			continue
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				out.append(mi.transform * v)
	return out


## How much of a body's timber falls outside its own collider — `{total, outside, worst}`,
## `worst` in metres. A point above or below every slab is scored on its horizontal miss
## from the nearest by height, so an end poking out past the stack is not called covered.
func _wood_outside_collider(body: Node) -> Dictionary:
	var slabs: Array = []
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs != null and cs.shape is CylinderShape3D:
			var c: CylinderShape3D = cs.shape
			slabs.append({"y": cs.position.y, "h": c.height, "r": c.radius,
				"c": Vector2(cs.position.x, cs.position.z)})
	var out := {"total": 0, "outside": 0, "worst": 0.0}
	if slabs.is_empty():
		return out
	for p in _wood_points(body):
		out.total += 1
		var best := INF
		for s in slabs:
			var dy: float = absf(p.y - (s.y as float)) - (s.h as float) * 0.5
			var dr: float = Vector2(p.x, p.z).distance_to(s.c) - (s.r as float)
			best = minf(best, maxf(maxf(dy, dr), 0.0))
		if not is_inf(best) and best > 0.0005:
			out.outside += 1
			out.worst = maxf(out.worst, best)
	return out


## The world height of the lowest bit of timber a body carries.
func _lowest_wood(body: Node3D) -> float:
	var lowest := INF
	var gx := body.global_transform
	for p in _wood_points(body):
		lowest = minf(lowest, (gx * p).y)
	return 0.0 if is_inf(lowest) else lowest


func _test_6_gear_gate() -> void:
	# NOTE: load() hands back the one cached TreeDef, so this raise is visible to
	# every later tree in the session — it is restored at the end of this test.
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	var td: TreeDef = g.tree_def()
	var axe_tier := GameState.get_tool_tier(Enums.ToolType.AXE)
	var authored_hardness := td.hardness_level
	td.hardness_level = axe_tier + 1
	# This test drives `_begin_strike` directly, so it skips the click path's "still
	# bouncing into place" guard — and its second blow lands about 0.45 s in, right on
	# the edge of the 420 ms spawn drop. A blow is aimed in WORLD space, so one that
	# resolves while the trunk is still falling into position carves at a height the
	# trunk has already left, and the test intermittently sees no cut. `debug_blow`
	# settles the animator first for exactly this reason; so does this.
	g._animator.finish_for([trunk])
	await get_tree().process_frame

	g._begin_strike(1, 0.5)
	await _wait(0.35)   # longer than anticipation_sec: a permitted blow would have landed
	_check(not trunk.has_cut(), "gear gate: an under-tier axe cannot mark the tree at all")
	_check(is_zero_approx(g.notch_depth()), "gear gate: it opens no notch")
	_check(g.chip_count() == 0, "gear gate: it throws no chip")
	_check(not g.is_felling(), "gear gate: it cannot fell the tree")

	# Upgrade through the REAL path (A7 -> GameState), then the same blow lands.
	EventBus.gear_upgraded.emit(Enums.ToolType.AXE, td.hardness_level)
	await get_tree().process_frame
	_check(GameState.get_tool_tier(Enums.ToolType.AXE) == td.hardness_level,
		"gear_upgraded raised the axe tier through GameState (%d)" % td.hardness_level)
	g._begin_strike(1, 0.5)
	await _wait(0.35)
	_check(trunk.has_cut() and g.notch_depth() > 0.0,
		"the same blow lands once the axe is up to tier")
	td.hardness_level = authored_hardness
	await _drop(g)


func _test_7_fall_stocks_and_clears() -> void:
	var g := await _make_game(1, true)   # auto_respawn ON: the board must clear itself
	var td: TreeDef = g.tree_def()
	var yield_item: StringName = &""
	var yield_amount := 0
	for f: FragmentDef in td.yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			yield_item = f.yield_item
			yield_amount += f.yield_amount
	var before := InventoryManager.get_count(yield_item)
	_gathered.clear()

	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	_check(g.is_felling(), "the tree fells")

	# Latch as we go: the respawn resets these for the NEXT tree, so reading them
	# afterwards would report the fresh tree's state instead of the felled one's.
	var budget_peak := 0
	var landed := false
	var collected := false
	for i in range(80):
		await _wait(0.25)
		budget_peak = maxi(budget_peak, _active_bodies(g))
		landed = landed or g.has_landed()
		collected = collected or g.has_collected()
		if collected:
			break

	_check(landed, "the felled tree reaches the ground")
	_check(collected, "the tree dissolves and its timber is booked in")
	_check(InventoryManager.get_count(yield_item) - before == yield_amount,
		"felling deposits the TreeDef yield (%s x%d)" % [yield_item, yield_amount])
	_check(int(_gathered.get(yield_item, 0)) == yield_amount,
		"resource_gathered fired for exactly the authored yield")
	_check(budget_peak <= _BUDGET_SCRIPT.MAX_ACTIVE,
		"A12: the budget holds chips to %d active even under the splinter load (peak %d, trunk excluded)" % [
			_BUDGET_SCRIPT.MAX_ACTIVE, budget_peak])

	# The clearing dissolves and a fresh tree stands itself up.
	var fresh: TreeTrunk = null
	for i in range(40):
		await _wait(0.25)
		fresh = g.trunk()
		if fresh != null and is_instance_valid(fresh) and not fresh.has_cut():
			break
	_check(fresh != null and is_instance_valid(fresh) and not fresh.has_cut(),
		"the board clears and a fresh tree stands up")
	_check(g.chip_count() == 0, "the felled tree's chips are cleared with it")
	_check(g.face_side() == 0, "...and the fresh tree is uncommitted again")
	var after := InventoryManager.get_count(yield_item)
	_check(after - before == yield_amount, "the yields were collected exactly once")
	await _drop(g)


# -------------------------------------------------- debris that has settled
## A SETTLED PIECE IS RESTING ON SOMETHING. Freezing is how a body is retired
## here, and it used to freeze the piece exactly where it was — fine when the
## piece had gone to sleep on the ground, wrong the two other times it happens.
## The settle timeout runs on a clock whether or not the piece has landed, and
## A12's budget force-settles the oldest ACTIVE body whenever a new one would
## break the 24-body cap, which M5 does constantly (five bodies a blow, and the
## hinge tear spits fourteen a second). Splinters were being frozen in mid-flight
## and left hanging in the air around the stump.
##
## Also checks the ground: the scene's authored collider is a flat box topped at
## y = 0 while the forest floor art sits between y = 0.005 and y = 0.034, so
## everything was coming to rest up to 34 mm under the visible dirt — deeper than
## a splinter is thick. The collider is taken off the floor mesh at build now.
func _test_8_debris_comes_to_rest() -> void:
	var g := await _make_game(1, false)
	# The live scene clears the board half a second after the trunk settles and
	# dissolves it in another 0.3 s, which is long before the last splinter has
	# stopped rolling — hold the felled clearing on screen long enough to measure.
	g.fade_delay = 8.0

	# --- the ground the debris lands on is the ground that is drawn
	var floor_body: StaticBody3D = g.get_node("Floor")
	var surface: ConcavePolygonShape3D = null
	for c in floor_body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is ConcavePolygonShape3D:
			surface = (c as CollisionShape3D).shape
	_check(surface != null and surface.get_faces().size() >= 3,
		"the ground collider is built from the visible floor mesh (%d faces)" % [
			0 if surface == null else surface.get_faces().size() / 3])

	# --- the mechanism, on its own: three pieces retired by the budget in mid-air
	var stick := BoxMesh.new()
	stick.size = Vector3(0.02, 0.16, 0.02)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stick.surface_get_arrays(0))
	# Untyped on purpose: fragment_piece.gd has no class_name, so a RigidBody3D
	# annotation would not know about force_settle().
	var upright = _loose_piece(g, mesh, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0)))
	var tumbling = _loose_piece(g, mesh,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.2, 3.0, 0.0)))
	var over_void = _loose_piece(g, mesh, Transform3D(Basis.IDENTITY, Vector3(400.0, 5.0, 0.0)))
	await _wait(0.1)
	var spin_before: Basis = tumbling.global_transform.basis
	upright.force_settle()
	tumbling.force_settle()
	over_void.force_settle()
	await _wait(0.1)

	_check(upright.global_position.y < 0.2,
		"a piece the A12 budget retires in mid-air comes down to the ground (y %.3f from 5.0)" % \
			upright.global_position.y)
	_check(tumbling.global_position.y < 0.2,
		"...however it happened to be tumbling (y %.3f from 3.0)" % tumbling.global_position.y)
	# The tumbling one was already on its side, so its pose is left alone.
	_check(tumbling.global_transform.basis.is_equal_approx(spin_before),
		"...keeping the pose it was in, if that pose was believable")
	# The upright one was standing on its end, which a stick does not do — laid flat.
	var stood: Vector3 = (upright.global_transform.basis * Vector3.UP).normalized()
	_check(absf(stood.dot(Vector3.UP)) < 0.8,
		"...but one left standing on its end is laid over, not stood up in the dirt (%.2f)" % \
			absf(stood.dot(Vector3.UP)))
	# Nothing at all under this one (it is parked off the end of the ground), so it
	# must be left where it was rather than dropped to some guessed floor. Checked
	# loosely: it is a live body until the freeze lands, so it is still falling.
	_check(over_void.global_position.y > 4.0,
		"...and one with nothing underneath it is left alone rather than guessed at (y %.3f)" % \
			over_void.global_position.y)
	# Off the board before the real debris is counted — the void piece is floating
	# by construction and would poison the tally below.
	upright.queue_free()
	tumbling.queue_free()
	over_void.queue_free()
	await _wait(0.1)

	# --- and the real thing: fell a tree and measure where its debris ended up
	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	for i in range(80):
		await _wait(0.25)
		if g.has_settled():
			break
	_check(g.has_settled(), "the felled tree settles")
	# Long enough for the last of the debris to come down AND for fragment_piece's
	# rest-confirm window to have run its course on any piece whose support moved.
	await _wait(7.0)

	# "Resting" means TOUCHING something, tested with the piece's own collider and a
	# 2 cm skin. A ray down from the centre is not good enough: a splinter wedged
	# against the side of the felled trunk, or lying across the edge of another
	# chip, is properly supported with nothing directly under its middle.
	var floating := 0
	var counted := 0
	var space := get_viewport().world_3d.direct_space_state
	for b in g.get_node("Fallers").get_children():
		if not (b is RigidBody3D):
			continue
		var body: RigidBody3D = b
		var cs: CollisionShape3D = body.get_node_or_null("CollisionShape3D")
		if cs == null or cs.shape == null or not body.freeze:
			continue
		counted += 1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.margin = 0.02
		q.exclude = [body.get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			floating += 1
			# Printed rather than just counted: this is a rare one and the details are
			# what a future run needs to diagnose it without a bespoke tool.
			var sweep := PhysicsShapeQueryParameters3D.new()
			sweep.shape = cs.shape
			sweep.transform = cs.global_transform
			sweep.motion = Vector3.DOWN * 20.0
			sweep.exclude = [body.get_rid()]
			var m := space.cast_motion(sweep)
			print("   floater: %s at %v, shape %s size %v, sweep safe %.4f" % [
				body.name, body.global_position, cs.shape.get_class(),
				cs.shape.get_debug_mesh().get_aabb().size,
				m[0] if m.size() > 0 else -1.0])
	_check(counted > 4, "there is debris on the ground to check (%d pieces)" % counted)
	_check(floating == 0,
		"every settled piece of debris is resting on something (%d of %d in mid-air)" % [
			floating, counted])
	await _drop(g)


# ------------------------------------------------------------- the landing
## THE LANDING IS THE PAYOFF and it has to hit like one. Two things were wrong:
## the impact was a flat authored strength however hard the tree actually arrived,
## and the trunk had its damping slammed to the settling values on the very frame
## it touched down — so it stopped dead at the exact moment the player was waiting
## to see, which is what made a felled tree land like a prop being set down rather
## than a tonne of timber hitting dirt.
func _test_9_the_landing_hits() -> void:
	var g := await _make_game(1, false)
	g.fade_delay = 8.0
	await _notch_to(g, 0.6)
	await _chop_until_fell(g)

	var trauma_peak := 0.0
	var damp_at_touchdown := -1.0
	for i in range(400):
		await _wait(0.05)
		trauma_peak = maxf(trauma_peak, GameFeel.get_trauma())
		if g.has_landed():
			var body: RigidBody3D = g.fallen_trunk()
			if body != null and is_instance_valid(body) and damp_at_touchdown < 0.0:
				damp_at_touchdown = body.angular_damp
			break
	_check(g.has_landed(), "the felled tree reaches the ground")

	# It arrived at a real speed, and that speed is what the impact was sized by.
	var speed: float = g.debug_impact_speed()
	_check(speed > 4.0,
		"the landing is measured off how fast the trunk's tip was really moving (%.1f m/s)" % speed)
	_check(trauma_peak > 0.5,
		"...and a full-height fall registers as a heavy hit (peak trauma %.2f)" % trauma_peak)

	# The slam is allowed to happen: the settling damping arrives LATER, not on the
	# frame of contact.
	_check(damp_at_touchdown >= 0.0 and damp_at_touchdown < g.trunk_land_angular_damp,
		"the trunk is not damped to a standstill the instant it touches (damp %.2f, settles to %.2f)" % [
			damp_at_touchdown, g.trunk_land_angular_damp])
	var damped := false
	for i in range(200):
		await _wait(0.05)
		var body: RigidBody3D = g.fallen_trunk()
		if body == null or not is_instance_valid(body):
			break
		if is_equal_approx(body.angular_damp, g.trunk_land_angular_damp):
			damped = true
			break
	_check(damped,
		"...but it does arrive, so a cylinder cannot roll for ever on flat ground")
	await _drop(g)


# ------------------------------------------------------------------ bucking
## THE TREE IS DOWN AND IT IS STILL A TREE. Bucking is the job after felling: cut the
## trunk across where it lies into logs, one length coming free per cut and booked
## into the inventory as it does. Cut with the plane slicer (Amendment 10) rather than
## the voxel field — a cross-cut IS a plane cut, and voxelising the crown would clamp
## the branches away the moment the tree landed.
##
## The invariant that matters is the LAST one: a tree pays exactly what it is authored
## to pay however the player cuts it up. Bucking sets the pace of the reward, never
## its size.
func _test_10_bucking_the_felled_trunk() -> void:
	var g := await _make_game(1, false)
	var leaf: FragmentDef = null
	for f: FragmentDef in (g.tree_def() as TreeDef).yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			leaf = f
	if leaf == null:
		_check(false, "the tree has a yield to buck into")
		await _drop(g)
		return
	var before := InventoryManager.get_count(leaf.yield_item)

	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	for i in range(200):
		await _wait(0.25)
		if g.is_bucking():
			break
	_check(g.is_bucking(), "the felled trunk lies there to be bucked instead of dissolving")
	_check(g.log_count() == 1, "...as one uncut length (%d)" % g.log_count())
	_check(g.logs_paid() == 0, "...and nothing is booked in until a log comes off")

	# One run of blows in one place cuts through, and that length comes away.
	var partial := true
	for b in range(g.buck_blows - 1):
		partial = g.debug_buck(0) and partial
		await get_tree().process_frame
	_check(partial and g.log_count() == 1,
		"blows short of the whole cut leave it in one piece (%d)" % g.log_count())
	_check(g.debug_buck(0), "the blow that goes right through lands")
	await _wait(0.3)
	_check(g.log_count() == 2, "...and the trunk is in two lengths (%d)" % g.log_count())
	_check(g.logs_paid() == 1, "...with exactly one log booked in (%d)" % g.logs_paid())
	_check(InventoryManager.get_count(leaf.yield_item) - before == 1,
		"...through resource_gathered into the inventory")

	# Cut again somewhere else: another length, another log.
	for b in range(g.buck_blows):
		g.debug_buck(0)
		await get_tree().process_frame
	await _wait(0.3)
	_check(g.log_count() == 3, "a second cut makes a third length (%d)" % g.log_count())
	_check(g.logs_paid() == 2, "...and books a second log (%d)" % g.logs_paid())

	# A length cannot be cut down for ever. Every section is an untracked rigid body,
	# so without a floor on how short one may be, a patient player could make as many
	# as they liked — which is the thing A12's cap exists to stop.
	g.buck_min_length = 99.0
	var refused := true
	for b in range(g.buck_blows + 2):
		refused = refused and not g.debug_buck(0)
		await get_tree().process_frame
	_check(refused and g.log_count() == 3,
		"a length already down to size refuses to be cut again (%d)" % g.log_count())
	g.buck_min_length = 0.6

	# THE INVARIANT: leave it half-bucked and the fade pays the difference, so the
	# tree is worth exactly its authored yield either way.
	g.buck_idle_clear = 0.05
	for i in range(120):
		await _wait(0.25)
		if g.has_collected():
			break
	_check(g.has_collected(), "leaving it alone clears the board and books the rest")
	_check(InventoryManager.get_count(leaf.yield_item) - before == leaf.yield_amount,
		"a half-bucked tree still yields exactly what it is authored to (%d of %d)" % [
			InventoryManager.get_count(leaf.yield_item) - before, leaf.yield_amount])
	await _drop(g)


# ------------------------------------------------- cutting where you like
## THE PLAYER PICKS WHERE THE AXE GOES, every blow. The first click used to fix the
## notch height for the whole tree and every later blow was dragged back to it, however
## far up or down the trunk the player actually clicked. Sam's call, 2026-07-25: *"when
## the user cuts one point along the Y axis, they can no longer cut from any other
## point, the user should be allowed to cut however they want."*
func _test_11_cut_wherever_you_like() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()

	# Every level's area BEFORE a single blow. "Has this height been cut" is judged
	# against what that height started as, never against the band's median: the band is
	# three metres of a trunk that tapers by a factor of three over it, so the median is
	# above the real section for the top half of the band and below it for the bottom.
	var base_lv := PackedFloat32Array()
	for e in trunk.sections():
		base_lv.append(e.area)

	# Three blows low down: one cut, deepening. Aimed off the BAND rather than at an
	# absolute 0.5 m — the band starts above the tree's root flare now (it has to; a
	# radial voxel field cannot hold a root), so 0.5 m is not necessarily inside it.
	var low_aim: float = trunk.band_lo + 0.45
	for i in range(3):
		g.debug_blow(1, low_aim)
		await get_tree().process_frame
	_check(g.cut_count() == 1, "a run of blows in one place is ONE cut (%d)" % g.cut_count())
	var low: float = g.notch_height()
	_check(absf(low - low_aim) < 0.3,
		"...at the height it was aimed (%.2f m, aimed %.2f)" % [low, low_aim])
	var deep_low: float = g.notch_depth()

	# Now well above it. That must open a SECOND cut where it was aimed, not deepen
	# the first one.
	var high_aim: float = minf(trunk.band_lo + 1.1, trunk.band_hi - 0.2)
	for i in range(3):
		g.debug_blow(1, high_aim)
		await get_tree().process_frame
	_check(g.cut_count() == 2,
		"a blow well away from it opens a SECOND cut (%d cuts)" % g.cut_count())
	var lv: Array[Dictionary] = trunk.sections()
	# Both heights have wood taken out of them, which is the whole claim — each measured
	# against its OWN uncut section.
	var j_low := trunk.volume().level_of(low)
	var j_high := trunk.volume().level_of(high_aim)
	_check(lv[j_low].area < base_lv[j_low] * 0.97,
		"the low cut is still there (%.3f of the %.3f m2 that was there)" % [
			lv[j_low].area, base_lv[j_low]])
	_check(lv[j_high].area < base_lv[j_high] * 0.97,
		"...and the high one is cut too (%.3f of the %.3f m2 that was there)" % [
			lv[j_high].area, base_lv[j_high]])
	_check(g.notch_depth() >= deep_low,
		"...and the deepest notch is still reported (%.0f%%)" % (g.notch_depth() * 100.0))

	# A blow on the other half of the trunk's face opens its own cut there, and does not
	# disturb the ones already going. It is a head-on cut like every other one — there is
	# no cutting from behind the tree.
	var cuts_before: int = g.cut_count()
	g.debug_blow(-1, 1.0)
	await get_tree().process_frame
	_check(g.cut_count() == cuts_before + 1,
		"a blow on the other half of the face opens its own cut (%d cuts)" % g.cut_count())
	var cam11: Camera3D = g.camera()
	var to_cam: Vector3 = cam11.global_position - trunk.global_position
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	_check(g.notch_direction().dot(to_cam) > 0.0,
		"...and every cut opens toward the camera, never round the back (%.2f)" % \
			g.notch_direction().dot(to_cam))
	await _drop(g)


# ------------------------------------------ debris versus the big timber
## SPLINTERS DO NOT SHOVE THE TREE ABOUT. Sam's call, 2026-07-25: the debris is there
## to make small piles on the ground, so it collides with the ground and with other
## debris and passes straight through the trunk, the stump and the bucked logs. A
## hundred and fifty splinters fighting a falling tree is all cost and no benefit, and
## Sam is explicitly happy for them to clip.
func _test_12_debris_ignores_the_timber() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()

	# The layer scheme itself, so the masks cannot drift apart unnoticed.
	_check(TreeTrunk.DEBRIS_MASK & TreeTrunk.TIMBER_LAYER == 0,
		"debris does not collide with timber")
	_check(TreeTrunk.DEBRIS_MASK & TreeTrunk.GROUND_LAYER != 0,
		"...but it does collide with the ground")
	_check(TreeTrunk.DEBRIS_MASK & TreeTrunk.DEBRIS_LAYER != 0,
		"...and with other debris, so it piles up")
	_check(TreeTrunk.TIMBER_MASK & TreeTrunk.GROUND_LAYER != 0,
		"timber collides with the ground")
	var floor_body: StaticBody3D = g.get_node("Floor")
	_check(floor_body.collision_layer == TreeTrunk.GROUND_LAYER,
		"the ground is on the ground layer and nothing else")

	# And what actually gets spawned wears those layers.
	g.debug_blow(1, 0.5)
	await get_tree().process_frame
	var debris := 0
	var wrong := 0
	for b in g.get_node("Fallers").get_children():
		if not (b is RigidBody3D):
			continue
		debris += 1
		var body: RigidBody3D = b
		if body.collision_layer != TreeTrunk.DEBRIS_LAYER \
				or body.collision_mask != TreeTrunk.DEBRIS_MASK:
			wrong += 1
	_check(debris > 0 and wrong == 0,
		"every splinter a blow throws is on the debris layer (%d of %d wrong)" % [wrong, debris])

	# The stump gets a collider when the tree breaks, and it is timber.
	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	await _wait(0.2)
	var stump: StaticBody3D = trunk.get_node_or_null("StumpBody")
	_check(stump != null and stump.collision_layer == TreeTrunk.TIMBER_LAYER,
		"the stump is timber, so splinters pass through it")
	for i in range(200):
		await _wait(0.25)
		if g.is_falling_physically():
			break
	var fallen: RigidBody3D = g.fallen_trunk()
	_check(fallen != null and fallen.collision_layer == TreeTrunk.TIMBER_LAYER \
			and fallen.collision_mask == TreeTrunk.TIMBER_MASK,
		"...and so is the falling trunk")
	await _drop(g)


# ------------------------------------------- angle of entry, and end grain
## THE CUT NO LONGER COMES IN ONLY FROM DEAD LEFT OR DEAD RIGHT. Sam, 2026-07-25: *"I want
## the cut to not happen on just the full left or full right (which is happening now) I
## want to control the original angle of entry as well (we can set it by default as 30
## degrees to whichever side is being cut)"*. The angle is `entry_angle_deg` by default and
## the player varies it above that by where across the trunk's face they click.
##
## And the faces the axe opens show END GRAIN — growth rings, centred on the trunk's own
## axis: *"use the oak log top texture as the internal wood texture, since we'd see rings
## if thats how we were really cutting it."*
func _test_13_entry_angle_and_end_grain() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	var cam: Camera3D = g.camera()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var toward_cam := cam.global_position - trunk.global_position
	toward_cam.y = 0.0
	toward_cam = toward_cam.normalized()

	# The default entry angle: 30 degrees round from head-on, NOT square-on to the side.
	g.debug_blow(1, 0.5)
	await get_tree().process_frame
	var dir: Vector3 = g.notch_direction()
	_check(dir.dot(right) > 0.1, "the cut opens toward the side that was struck (%.2f)" % dir.dot(right))
	_check(dir.dot(toward_cam) > 0.5,
		"...but well round toward the front, not square-on to the side (%.2f toward the camera)" % 			dir.dot(toward_cam))
	var want := sin(deg_to_rad(g.entry_angle_deg))
	_check(absf(dir.dot(right) - want) < 0.1,
		"...at the angle of entry it was given (%.0f deg -> %.2f, wanted %.2f)" % [
			g.entry_angle_deg, dir.dot(right), want])
	await _drop(g)

	# ...and the player controls it: a click out at the silhouette edge cuts square from
	# the side, one in toward the centre line comes round the front.
	var g2 := await _make_game()
	g2.debug_blow(1, 0.5, 1.0)          # edge = the trunk's silhouette
	await get_tree().process_frame
	var square: Vector3 = g2.notch_direction()
	await _drop(g2)
	var g3 := await _make_game()
	g3.debug_blow(1, 0.5, 0.0)          # edge = the centre line
	await get_tree().process_frame
	var frontal: Vector3 = g3.notch_direction()
	_check(square.dot(right) > frontal.dot(right) + 0.2,
		"where across the trunk the click lands sets the angle (%.2f square vs %.2f frontal)" % [
			square.dot(right), frontal.dot(right)])
	_check(absf(square.dot(right)) > 0.95,
		"...clicking the silhouette edge still cuts square from the side (%.2f)" % square.dot(right))

	# END GRAIN: the cut faces are mapped as one log round on the trunk's axis, so the
	# rings sit where the tree's centre is. Not tiled — the texture is a single disc.
	# The round is fitted to the WIDEST wood in the band, not to the trunk's
	# representative radius. `_cut_mat` is a single growth-ring disc on a WHITE field with
	# texture_repeat off, so anything mapped past its edge clamps to that white — and a
	# notch is a bite at the PERIMETER, which is exactly the part that overflowed. Every
	# fresh cut face was blank white over its outer third until 2026-07-29. Asserting it
	# equals `radius` was asserting the bug.
	var vol: WoodVolume = g3.trunk().volume()
	_check(vol.ring_radius >= vol.profile_max_radius - 0.0001
			and vol.ring_radius <= vol.profile_max_radius * 1.05,
		"the end-grain round covers the widest wood in the band, so no cut face clamps to white (ring %.3f m, widest wood %.3f m)" % [
			vol.ring_radius, vol.profile_max_radius])
	var mat := StandardMaterial3D.new()
	var side := StandardMaterial3D.new()
	var was_side: Material = vol.side_mat
	vol.side_mat = side
	var band := vol.build_mesh(null, mat)
	vol.side_mat = was_side
	# BY MATERIAL, not by index. A cut face is routed to one of TWO surfaces since
	# 2026-07-30 — growth rings for the cross-cut faces, long grain for the near-vertical
	# walls a chop leaves down the side of a trunk — so "the last surface" no longer means
	# "the ring surface", and asking for it silently measured the wrong one.
	var ring_si := -1
	var side_si := -1
	for si in range(band.get_surface_count()):
		if band.surface_get_material(si) == mat:
			ring_si = si
		elif band.surface_get_material(si) == side:
			side_si = si
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	if ring_si >= 0:
		var arr := band.surface_get_arrays(ring_si)
		verts = arr[Mesh.ARRAY_VERTEX]
		uvs = arr[Mesh.ARRAY_TEX_UV]
	var worst := 0.0
	for i in range(verts.size()):
		# The UV must be the vertex's own offset from the trunk axis, scaled to ring_fit.
		# Scaled by the round fitted at THAT VERTEX'S HEIGHT — the round is per level since
		# 2026-07-31 (`WoodVolume.ring_at`), because with the root flare in the field the
		# band spans a 2.4x range of widths and one radius for all of it either clamps a
		# flare cut to white or leaves a stem cut on the inner third of the disc. Reading
		# the scalar here measured a scale no vertex was actually mapped with.
		var k: float = vol.ring_fit / vol.ring_at(verts[i].y)
		var want_uv := Vector2((verts[i].x - vol.axis_xz.x) * k + 0.5,
			(verts[i].z - vol.axis_xz.y) * k + 0.5)
		worst = maxf(worst, (uvs[i] - want_uv).length())
	_check(verts.size() > 0 and worst < 0.001,
		"...centred on the trunk's axis, so the rings are where its centre is (worst %.4f off)" % worst)

	# ...AND THE WALLS OF THE CUT ARE NOT ON THAT PROJECTION AT ALL, which is the whole of
	# the 2026-07-30 fix. A ring projection is a projection onto the HORIZONTAL plane, so
	# on a near-vertical kerf wall one row of texels is smeared its whole height — the
	# bright streaky ribbon across a chopped trunk Sam reported. Those faces go to their
	# own surface with an axis-aligned planar mapping in metres.
	#
	# Asserted as a POSITIVE QUANTITY (there ARE such faces, and they ARE mapped in
	# metres), because "no wall is smeared" is satisfied by a tree nobody has chopped.
	var side_v := PackedVector3Array()
	var side_n := PackedVector3Array()
	var side_uv := PackedVector2Array()
	var flat := 0
	if side_si >= 0:
		var sarr := band.surface_get_arrays(side_si)
		side_v = sarr[Mesh.ARRAY_VERTEX]
		side_n = sarr[Mesh.ARRAY_NORMAL]
		side_uv = sarr[Mesh.ARRAY_TEX_UV]
	for i in range(side_v.size()):
		# Projected flat onto whichever of the three axis-aligned planes the vertex's OWN
		# normal leans on — the choice is per vertex, not per face, which is what keeps a
		# corner between a floor and a wall from stretching either of them.
		var p := side_v[i]
		var n := side_n[i]
		var flat_uv := Vector2(p.x, p.z)
		if absf(n.x) >= absf(n.y) and absf(n.x) >= absf(n.z):
			flat_uv = Vector2(p.z, p.y)
		elif absf(n.z) > absf(n.y):
			flat_uv = Vector2(p.x, p.y)
		if (side_uv[i] - flat_uv * vol.cut_uv).length() < 0.001:
			flat += 1
	_check(side_v.size() > 0 and flat == side_v.size(),
		"...while the walls of the cut wear LONG GRAIN, projected flat onto their own axis and mapped in metres (%d of %d wall verts)" % [
			flat, side_v.size()])

	# ...AND NOTHING NEAR-VERTICAL IS LEFT ON THE RING PROJECTION, which is the property
	# the smear actually violated. Measured off the normals the mesher itself emitted, so
	# it cannot pass by measuring nothing: the ring surface has to be non-empty too.
	var upright := 0
	var rn: PackedVector3Array = band.surface_get_arrays(ring_si)[Mesh.ARRAY_NORMAL] \
		if ring_si >= 0 else PackedVector3Array()
	for n in rn:
		if absf(n.y) < 0.4:
			upright += 1
	_check(rn.size() > 0 and upright == 0,
		"...and no near-vertical face is left on the horizontal ring projection, which is what smeared them (%d of %d)" % [
			upright, rn.size()])
	await _drop(g3)


# ------------------------------------------------- first person: the aim
## THE AXE GOES WHERE YOU LOOK. Creative Director direction, 2026-07-26: *"I want this
## to be an fps game now, where you walk through a forest and chop down trees."*
##
## THIS TEST EXISTS BECAUSE OF ONE SPECIFIC HAZARD, and it is the hazard the FPS plan
## (handoff/08_FPS_FOREST.md §2) says would sink the naive port. Aiming used to be
## screen-space: `_side_from_screen` compared the click's x against the trunk's
## unprojected x, calling anything inside 2 px a tie and falling back to the side
## already being cut. At a CROSSHAIR pointed at a trunk those two numbers are always
## within a pixel or two of each other — so passing the viewport centre to the old code
## would have collapsed BOTH the choice of side and the angle of entry into their
## tie-break, silently, with everything still appearing to work. The angle of entry is
## the whole of what PASS 5 gave the player.
##
## So everything now comes off the 3D point the ray actually hits, and what is checked
## here is that the two controls survive: which side of the trunk you look at, and how
## far across its face. The click layer itself is still not headless-verifiable — this
## drives `debug_aim()`, which is `_aim()` with no mouse in front of it.
func _test_14_first_person_aim() -> void:
	var g := await _make_game()
	var trunk: TreeTrunk = g.trunk()
	g._animator.finish_for([trunk])
	await get_tree().process_frame

	# Standing in front of the tree, looking at it.
	g.debug_stand_at(0.0, 2.5, 0.6)
	var aim: Dictionary = g.debug_aim()
	_check(aim.ok, "looking at a trunk from %.1f m finds wood" % 2.5)
	_check(aim.ok and absf(aim.local_y - 0.6) < 0.4,
		"...at the height that was looked at (%.2f m, looking at 0.60)" % aim.local_y)
	# On the SURFACE. The old aim returned the closest point on the trunk's centre
	# LINE, which is exactly why the side and the angle had to be recovered from the
	# screen — a point on the axis has no horizontal offset to read them off. Measured
	# horizontally, because the hit sits partway up the trunk.
	#
	# Measured from the stem's centre AT THAT HEIGHT, not from the axis. The axis is one
	# vertical line through the middle of the band and the generator leans every trunk it
	# makes, so on a real tree the surface at the butt is legitimately further from the
	# axis than the radius — and the pick volume is padded by that lean, or the crosshair
	# on a leaning trunk's edge would find nothing at all.
	var centre := trunk.centre_offset(aim.local_y)
	var hit_off := (aim.point as Vector3) - trunk.global_position \
		- Vector3(trunk.axis_xz.x + centre.x, 0.0, trunk.axis_xz.y + centre.y)
	var hit_r := Vector2(hit_off.x, hit_off.z).length()
	_check(aim.ok and hit_r > trunk.radius * 0.5 and hit_r < trunk.radius * 1.25,
		"...on the trunk's surface, not on its centre line (%.2f m out, radius %.2f)" % [
			hit_r, trunk.radius])

	# THE ANGLE OF ENTRY SURVIVES THE CROSSHAIR. Looking at the centre line comes in at
	# the floor `entry_angle_deg`; looking across toward the silhouette comes in square.
	g.debug_stand_at(0.0, 2.5, 0.6, 0.0)
	var centred: Dictionary = g.debug_aim()
	g.debug_stand_at(0.0, 2.5, 0.6, trunk.radius * 0.85)
	var out_right: Dictionary = g.debug_aim()
	g.debug_stand_at(0.0, 2.5, 0.6, -trunk.radius * 0.85)
	var out_left: Dictionary = g.debug_aim()
	_check(centred.ok and out_right.ok and out_left.ok,
		"looking across the trunk's face still finds wood either side")
	_check(centred.ok and absf(rad_to_deg(centred.azimuth) - g.entry_angle_deg) < 1.0,
		"aiming down the centre line enters at entry_angle_deg (%.1f deg)" % \
			rad_to_deg(centred.azimuth))
	_check(out_right.ok and out_right.azimuth > centred.azimuth + deg_to_rad(10.0),
		"aiming across toward the edge enters squarer (%.1f deg vs %.1f)" % [
			rad_to_deg(out_right.azimuth), rad_to_deg(centred.azimuth)])

	# ...AND SO DOES THE CHOICE OF SIDE. This is the other half of what would have
	# collapsed: with a screen-space tie-break every crosshair blow lands on the side
	# already being cut, so a tree could only ever be worked from one face.
	_check(out_right.ok and out_right.side == 1, "looking right of centre picks the right side")
	_check(out_left.ok and out_left.side == -1, "looking left of centre picks the left side")

	# THE CUT IS ALWAYS ON THE FACE YOU CAN SEE (Sam, PASS 6). It is not enforced any
	# more — the ray strikes the trunk's NEAR surface, so it cannot be otherwise.
	var to_cam: Vector3 = g.camera().global_position - trunk.global_position
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	var near_off: Vector3 = (out_right.point as Vector3) - trunk.global_position \
		- Vector3(trunk.axis_xz.x, 0.0, trunk.axis_xz.y)
	near_off.y = 0.0
	_check(near_off.normalized().dot(to_cam) > 0.0,
		"the crosshair can only ever land on the near face of the trunk (%.2f)" % \
			near_off.normalized().dot(to_cam))

	# REACH. You have to walk up to a tree to fell it; you cannot drop one across the
	# clearing. This is new with first person and there was nothing to bound it before.
	g.debug_stand_at(0.0, g.chop_reach + 4.0, 0.6)
	_check(not (g.debug_aim() as Dictionary).ok,
		"standing beyond chop_reach (%.1f m) finds nothing to swing at" % g.chop_reach)
	g.debug_stand_at(0.0, 2.5, 0.6)
	_check((g.debug_aim() as Dictionary).ok, "...and walking back in finds it again")

	# The blow the aim describes lands where it was aimed, which is the whole claim.
	# Measured as WOOD VOLUME before and after, which is the only guard that cannot
	# pass vacuously: `holding_area` reports the area at whichever height is most cut,
	# so a blow that opens a NEW cut somewhere else legitimately hands back a bigger
	# number. This is the same lesson as the 2026-07-27 `plane_to_local` find, where
	# every check was about cut counts and depths and the trunk was never touched.
	var before := trunk.volume().volume()
	var live: Dictionary = g.debug_aim()
	_check(g.debug_blow(live.side, live.local_y, sin(live.azimuth)),
		"a blow driven from the crosshair's own aim lands")
	await get_tree().process_frame
	_check(trunk.volume().volume() < before,
		"...and takes real wood out of the trunk (%.4f -> %.4f m3)" % [
			before, trunk.volume().volume()])
	_check(g.notch_direction().dot(to_cam) > 0.0,
		"...opening toward the player, never round the back (%.2f)" % \
			g.notch_direction().dot(to_cam))

	# A STANDING TREE IS SOLID. New with first person and easy to miss: only the STUMP
	# had a collider, and only once the tree was already down — a standing trunk never
	# needed one, because nothing in the game could move. The player walked straight
	# through the tree they were chopping. Caught by `core/tools/fps_smoke.gd`, which
	# exists because this suite runs the player as a puppet and so can never catch it.
	var solid: StaticBody3D = trunk.get_node_or_null("TrunkBody")
	_check(solid != null, "a standing tree has a collider")
	_check(solid != null and solid.collision_layer == TreeTrunk.TIMBER_LAYER,
		"...on TIMBER_LAYER, so the player is stopped by it and splinters pass through")
	_check(solid != null and solid.get_child_count() > 0, "...with a shape on it")

	# GAMEFEEL STILL READS. A11's hit-pause plus M3's trauma shake is most of what a
	# chop feels like, and the plan flags it as the thing to verify before moving on:
	# GameFeel writes h_offset/v_offset, which are FRUSTUM shifts, so they have to
	# compose with mouse look rather than fight it. If it ever wrote the transform
	# instead, the camera would be yanked off the player's head every blow.
	var cam: Camera3D = g.camera()
	var pose: Transform3D = cam.global_transform
	GameFeel.register_impact(0.8)
	var shook := false
	for i in range(30):
		await get_tree().process_frame
		shook = shook or absf(cam.h_offset) > 0.0001 or absf(cam.v_offset) > 0.0001
	_check(shook, "an impact shakes the first-person camera")
	_check(cam.global_transform.is_equal_approx(pose),
		"...as a frustum offset, leaving the player's own head transform alone")
	await _drop(g)


# ------------------------------------------ first person: the felled trunk
## THE TREE YOU DROPPED IS STILL THERE WHEN YOU COME BACK. Creative Director's call,
## 2026-07-26, with the move to first person: a felled trunk used to dissolve into the
## inventory `buck_idle_clear` seconds after the player stopped touching it, which is
## fine for a mini-game you are pinned in front of and wrong the moment you can walk
## away from it and look at something else.
##
## What ends a persisting trunk is BUCKING IT OUT — nothing left long enough to cut —
## or leaving the forest. Never a timer.
##
## The yield invariant from PASS 2 is unchanged and is re-checked here: a tree is worth
## exactly its authored TreeDef yield however it was cut up. Bucking sets the pace of
## the reward, never its size.
func _test_15_the_felled_trunk_persists() -> void:
	var g := await _make_game()
	g.trunk_persists = true
	g.buck_idle_clear = 0.2   # short, so "the timer does not fire" means something
	var leaf: FragmentDef = null
	for f: FragmentDef in (g.tree_def() as TreeDef).yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			leaf = f
	if leaf == null:
		_check(false, "the tree has a yield to buck into")
		await _drop(g)
		return
	var before := InventoryManager.get_count(leaf.yield_item)

	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	for i in range(200):
		await _wait(0.25)
		if g.is_bucking():
			break
	_check(g.is_bucking(), "the felled trunk lies there to be bucked")

	# Walk away and leave it. Several times the idle timeout, and it is still lying
	# where it fell with nothing booked in.
	await _wait(g.buck_idle_clear * 8.0)
	_check(g.is_bucking() and not g.has_collected(),
		"...and it is still there long after buck_idle_clear would have taken it")
	_check(g.log_count() >= 1, "...as timber on the ground (%d length(s))" % g.log_count())

	# Buck it right out. Every cut halves a length, so a 7.7 m trunk comes apart in a
	# dozen or so; the cap is a runaway guard, not an expectation.
	var cuts := 0
	while cuts < 40:
		var idx: int = g.debug_next_bucking_log()
		if idx < 0:
			break
		var cut := false
		for b in range(g.buck_blows):
			cut = g.debug_buck(idx)
			await get_tree().process_frame
		if not cut:
			break   # nothing there would cut; let the checks below report it
		cuts += 1
		await _wait(0.05)
	_check(g.debug_next_bucking_log() < 0 or g.has_collected(),
		"bucking it out leaves nothing long enough to cut (%d cuts)" % cuts)

	for i in range(120):
		await _wait(0.1)
		if g.has_collected():
			break
	_check(g.has_collected(), "...and THAT is what clears it, not a timer")
	_check(InventoryManager.get_count(leaf.yield_item) - before == leaf.yield_amount,
		"a fully bucked tree yields exactly what it is authored to (%d of %d)" % [
			InventoryManager.get_count(leaf.yield_item) - before, leaf.yield_amount])
	await _drop(g)

	# The other way out: walking out of the forest books in the timber left lying
	# there, so leaving can never cost the player a tree they felled.
	var g2 := await _make_game()
	g2.trunk_persists = true
	var before2 := InventoryManager.get_count(leaf.yield_item)
	await _notch_to(g2, 0.6)
	await _chop_until_fell(g2)
	for i in range(200):
		await _wait(0.25)
		if g2.is_bucking():
			break
	_check(g2.is_bucking(), "a second tree is felled and lying there")
	EventBus.minigame_exited.emit()
	for i in range(120):
		await _wait(0.1)
		if g2.has_collected():
			break
	_check(g2.has_collected(), "leaving the forest books in the trunk left lying in it")
	_check(InventoryManager.get_count(leaf.yield_item) - before2 == leaf.yield_amount,
		"...for exactly its authored yield (%d of %d)" % [
			InventoryManager.get_count(leaf.yield_item) - before2, leaf.yield_amount])
	await _drop(g2)


# --------------------------------------------------- bucking: no coins
## A BUCKED LENGTH IS A LOG, NEVER A COIN. Creative Director's call, 2026-07-26: *"when a
## player chops a felled tree in to logs, it should only ever split in to logs roughly the
## size of the ones we chop in the game, so there is a min log size (right now you can cut
## tiny disks and that's just not accurate)."*
##
## `buck_min_length` already existed — and was tested against the length going IN, never
## against the two lengths coming OUT. So any section over the minimum could be cut a
## centimetre from its end and hand back a disc. The floor belongs on the RESULT.
##
## Its own test with its own game deliberately: it fells and cuts up a whole tree, and
## folding that into _test_10 put a second tree's yields inside the window _test_10 measures
## its yield invariant across — which is exactly how it went red the first time it ran.
func _test_16_bucked_lengths_are_logs() -> void:
	var g := await _make_game()
	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	for i in range(200):
		await _wait(0.25)
		if g.is_bucking():
			break
	_check(g.is_bucking(), "a tree is felled and lying there to be bucked")
	if not g.is_bucking():
		await _drop(g)
		return

	# A cut aimed RIGHT AT THE END of a log is moved inboard to the nearest legal place
	# rather than refused — the same way M4's chopping block clamps its own sliver guard,
	# because a click that does nothing reads as a broken game.
	var span: Vector2 = g.debug_log_span(0)
	for b in range(g.buck_blows):
		g.debug_buck(0, span.y - 0.01)
		await get_tree().process_frame
	await _wait(0.3)
	var lens: Array = g.debug_log_lengths()
	var min_len := INF
	for l in lens:
		min_len = minf(min_len, l as float)
	_check(lens.size() == 2, "a cut aimed at the very end of a log still cuts (%d lengths)" % lens.size())
	_check(min_len >= (g.min_log_length() as float) - 0.001,
		"...moved inboard, so the short end is a log not a coin (%.2f m, minimum %.2f)" % [
			min_len, g.min_log_length()])

	# Now buck the whole trunk out, and watch every length it ever produces. Measured as it
	# goes rather than at the end: bucking it right out CLEARS the board, so a check that
	# read the lengths afterwards would find an empty list and pass on nothing — which is
	# what the first version of this check did.
	var shortest := INF
	var seen := 0
	var cuts_made := 0
	var logs_made := 0
	for i in range(40):
		var idx: int = g.debug_next_bucking_log()
		if idx < 0:
			break
		# A LOG OFF THE END EACH TIME, which is how a faller bucks a trunk and is the only
		# way the "about `buck_target_logs` logs" spec can be MEASURED.
		#
		# This used to take `debug_buck`'s default, which cuts a length in HALF — and
		# repeated halving cannot reach the target by construction: with the minimum at
		# L/`target`, L gives two L/2 and each of those gives two L/4, and L/4 is already
		# under twice the minimum. Four pieces, maximum, for a target of five. It passed
		# only because the last halving landed a hair the right side of `2 x min_log`, and
		# anything that moved the trunk's length by a few percent tipped it — which is what
		# `voxel_roots` did (6.32 m against 5.72 m) and why this read as a roots regression
		# when the bucking code is provably identical either way.
		var seg: Vector2 = g.debug_log_span(idx)
		for b in range(g.buck_blows):
			g.debug_buck(idx, seg.x + (g.min_log_length() as float))
			await get_tree().process_frame
		cuts_made += 1
		var cut_lens: Array = g.debug_log_lengths()
		logs_made = maxi(logs_made, cut_lens.size())
		for l in cut_lens:
			shortest = minf(shortest, l as float)
			seen += 1
		await _wait(0.05)
	_check(seen > 0 and shortest < INF, "bucking a trunk right out produces measurable lengths")
	_check(shortest >= (g.min_log_length() as float) - 0.001,
		"NO COINS: the shortest length ever cut is %.2f m (minimum %.2f)" % [
			shortest, g.min_log_length()])
	# ...and the trunk comes apart into about as many logs as it is worth. Sam's spec,
	# 2026-07-27: "It should be roughly 5 logs per tree." The count is not tracked anywhere —
	# it falls out of the minimum being the trunk's length divided by the target, so no piece
	# can be shorter and there is no room for more of them.
	#
	# Asserted on the LOGS, not on the cuts. The trunk has already had one length taken off
	# its far end above, so the cuts here are one short of the pieces on the ground, and
	# counting cuts made that off-by-one look like tolerance.
	_check(logs_made >= g.buck_target_logs - 1 and logs_made <= g.buck_target_logs + 1,
		"a trunk bucks out into about buck_target_logs logs (%d logs, %d cuts, target %d)" % [
			logs_made, cuts_made, g.buck_target_logs])
	# And a section under two minimums cannot be cut at all, which is what stops the
	# player making unbounded rigid bodies (A12).
	_check(g.debug_next_bucking_log() < 0,
		"...and nothing under two minimums can be cut again")
	await _drop(g)


# ------------------------------ the stump stays, the logs come to you
## THE STUMP REMAINS AND THE LOGS FLY TO THE PLAYER. Creative Director's direction,
## 2026-07-27: *"I want the stump to remain - the logs can fly towards the character (in a
## similar way to the log chopping game) and then be added to their inventory."*
##
## THE YIELD INVARIANT IS THE THING TO GUARD. The flight settles the accounting at LAUNCH and
## defers only the EMISSION, so a tree must still be worth exactly its authored `TreeDef.yields`
## — the flight is a receipt, not a promise, and it cannot pay twice or lose a log because a
## second tree came down or the player walked out while a log was in the air.
##
## Its own game, and that matters: this is a whole felling-and-bucking lifecycle, and folding it
## into a test that had already bucked the same trunk measured a half-consumed tree and went red
## on a correct game.
func _test_17_stump_remains_and_logs_fly() -> void:
	var g := await _make_game()
	g.logs_fly_to_player = true
	var leaf: FragmentDef = null
	for f: FragmentDef in (g.tree_def() as TreeDef).yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			leaf = f
	if leaf == null:
		_check(false, "the tree has a yield to fly")
		await _drop(g)
		return
	var before := InventoryManager.get_count(leaf.yield_item)
	_check(g.stump_count() == 0, "nothing is a stump before anything is felled")

	await _notch_to(g, 0.6)
	await _chop_until_fell(g)
	for i in range(200):
		await _wait(0.25)
		if g.is_bucking():
			break
	_check(g.is_bucking(), "the tree is felled and lying there")

	# Buck it right out — that is what gives the timber up and launches it.
	var cuts := 0
	var seen_flying := 0
	while cuts < 40:
		var idx: int = g.debug_next_bucking_log()
		if idx < 0:
			break
		for b in range(g.buck_blows):
			g.debug_buck(idx)
			await get_tree().process_frame
		cuts += 1
		seen_flying = maxi(seen_flying, g.logs_in_flight() as int)
		await _wait(0.05)
	# The launch happens the moment the trunk is bucked out, so catch it in the air.
	for i in range(60):
		seen_flying = maxi(seen_flying, g.logs_in_flight() as int)
		if seen_flying > 0:
			break
		await _wait(0.05)
	_check(seen_flying > 0,
		"the logs FLY when the trunk is given up (%d in the air at once)" % seen_flying)

	for i in range(200):
		await _wait(0.1)
		if g.logs_in_flight() == 0:
			break
	_check(g.logs_in_flight() == 0, "...and every one of them arrives")
	_check(InventoryManager.get_count(leaf.yield_item) - before == leaf.yield_amount,
		"...banking EXACTLY the tree's authored yield (%d of %d)" % [
			InventoryManager.get_count(leaf.yield_item) - before, leaf.yield_amount])

	# THE STUMP REMAINS. The board clears round it — trunk, logs, splinters — and it stays.
	for i in range(120):
		await _wait(0.1)
		if g.stump_count() > 0:
			break
	_check(g.stump_count() == 1, "the felled tree leaves its stump standing (%d)" % g.stump_count())
	# ...and it is still SOLID, so a player walks into it rather than through it.
	#
	# ASKED WITH THE PLAYER'S OWN CAPSULE, not with a ray at one height. It was a ray across
	# the trunk's axis at 0.2 m until 2026-07-31, and that stopped meaning what it meant the
	# moment `voxel_roots` made the root flare carveable: the notch that fells the tree now
	# genuinely removes the wood at ankle height, so the ray passed through a stump that was
	# solid from the dirt to 0.165 m and would stop a walking player dead. A ray at a single
	# height cannot tell "you can walk through this" from "there is a notch at exactly that
	# height" — and the player is a 1.8 m capsule, not a horizontal line.
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var player: ForestPlayer = g.player()
	var shape := CapsuleShape3D.new()
	shape.radius = player.body_radius if player != null else 0.35
	shape.height = player.body_height if player != null else 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY,
		g.global_position + Vector3(0.0, shape.height * 0.5, 0.0))
	q.collision_mask = TreeTrunk.TIMBER_LAYER
	_check(not space.intersect_shape(q, 1).is_empty(),
		"...and it is solid timber, not scenery you can walk through")
	# The tree itself is GONE from the stand — a stump is not something to chop.
	_check((g.debug_trees() as Array).is_empty() or g.trunk() == null or not g.trunk().has_broken(),
		"...and the stump is not offered up as a choppable tree")
	await _drop(g)


## A fragment_piece dropped into the mini-game's own Fallers node and budget,
## exactly as a chop splinter arrives.
func _loose_piece(g: Node, mesh: Mesh, xform: Transform3D):
	var piece = load("res://scenes/3d_action/fragment_piece.tscn").instantiate()
	g.get_node("Fallers").add_child(piece)
	piece.setup_mesh(mesh, 999.0)   # never times out; the test settles it by hand
	piece.freeze = true             # held still so it is measured where it was put
	piece.global_transform = xform
	piece.freeze = false
	return piece


## Active (unfrozen) rigid bodies the A12 budget is responsible for — the chips.
## The falling trunk is a RigidBody in the same parent but is deliberately NOT
## budget-tracked (Amendment 11: there is only ever one), so it is excluded here,
## exactly as the budget excludes it.
func _active_bodies(g: Node) -> int:
	var n := 0
	var trunk_body: Node = g.fallen_trunk()
	for b in g.get_node("Fallers").get_children():
		if b is RigidBody3D and b != trunk_body and not (b as RigidBody3D).freeze:
			n += 1
	return n
