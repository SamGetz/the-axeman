extends Node
## DEV TOOL. THE STAND, as a stand — the things that only go wrong when there is more than
## one tree.
##
## `m5_acceptance` pins `tree_count = 1` on purpose: every check in it measures one tree's
## wood against a known camera. So none of it covers the forest, and the forest's failure
## modes are all about identity — tree B inheriting tree A's notch, the aim ray picking the
## wrong trunk, the whole stand's voxels being built at load.
##
## Run: godot --headless --path . --quit-after 200000 res://core/tools/forest_smoke.tscn

var _passes := 0
var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	print("=== FOREST SMOKE ===")
	var t0 := Time.get_ticks_usec()
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.trunk_persists = false
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.tree_count = 25
	game.forest_radius = 25.0
	# This suite's setup deliberately chops several trees "a little" before its
	# dedicated felling phase. Different authored crowns carry different loads,
	# so a fixed number of setup blows is not a promise that every species stays
	# standing. Hold failure out of the setup; restore the real threshold for the
	# lifecycle check below.
	var gameplay_fail_stress: float = game.fail_stress
	game.fail_stress = 1000000.0
	add_child(game)
	await _wait(1.5)
	var load_ms := float(Time.get_ticks_usec() - t0) / 1000.0

	var trees: Array = game.debug_trees()
	print("stand of %d trees, scene up in %.0f ms" % [trees.size(), load_ms])
	_check(trees.size() >= 20, "the stand stood up (%d trees of 25 asked for)" % trees.size())

	# NO TREE EVER CHANGES UNDER THE PLAYER (2026-07-30). This used to assert the opposite —
	# that exactly ONE tree is voxelised at load and the rest are cheap imported meshes
	# until their first blow (plan §3a). That is cheaper, and it is what Sam saw as "a
	# small lag, then the texture of the tree rotates": a previewed tree and a built one
	# are two different surfaces of the same trunk, and swapping them at the moment of the
	# first strike is a stall followed by a pop.
	#
	# The lazy path is still there behind `prebuild_stand` and still tested below, because
	# building the stand costs ~4.5 s and ~58 MB and that may yet be the wrong trade. What
	# is asserted here is that whichever way the switch is set, the game is CONSISTENT: no
	# tree the player can walk up to is one thing before it is struck and another after.
	var built := 0
	var previews := 0
	for t in trees:
		if (t as TreeTrunk).is_built():
			built += 1
		if (t as TreeTrunk).is_preview():
			previews += 1
	_check(built == trees.size() and previews == 0,
		"every tree is voxelised at spawn, so none of them changes on its first blow (%d built, %d still previews)" % [
			built, previews])

	# SPACING. Nothing interpenetrates and nothing is on top of the player.
	var closest := INF
	for i in range(trees.size()):
		for j in range(i + 1, trees.size()):
			closest = minf(closest, (trees[i] as Node3D).global_position.distance_to(
				(trees[j] as Node3D).global_position))
	_check(closest >= game.min_tree_spacing - 0.01,
		"no two trees stand closer than min_tree_spacing (%.2f m of %.2f)" % [
			closest, game.min_tree_spacing])
	var nearest_to_spawn := INF
	var spawn: Vector3 = (game.player() as Node3D).global_position
	for t in trees:
		var d := Vector2((t as Node3D).global_position.x - spawn.x,
			(t as Node3D).global_position.z - spawn.z).length()
		nearest_to_spawn = minf(nearest_to_spawn, d)
	_check(nearest_to_spawn >= game.spawn_clear_radius - 0.01,
		"the player does not spawn inside a tree (%.2f m clear of %.2f)" % [
			nearest_to_spawn, game.spawn_clear_radius])

	# THE SEED. The same seed has to give the same forest, or no measurement here or in any
	# render shot is comparable with the last.
	var game2: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game2.debug_forced_species = 0
	game2.player_controlled = false
	game2.tree_count = 25
	game2.forest_radius = 25.0
	add_child(game2)
	await _wait(1.5)
	var trees2: Array = game2.debug_trees()
	var same := trees2.size() == trees.size()
	if same:
		for i in range(trees.size()):
			if (trees[i] as Node3D).position.distance_to((trees2[i] as Node3D).position) > 0.001:
				same = false
				break
	_check(same, "the same forest_seed lays out the same stand")
	game2.queue_free()
	await get_tree().process_frame

	# PER-TREE STATE (§3b) — the item the plan calls the most error-prone in it. Chop tree A,
	# then chop tree B, and tree B must know nothing about tree A's notch or its fall line.
	var a: TreeTrunk = game.debug_nearest_tree()
	game.debug_stand_at_tree(a)
	await get_tree().process_frame
	for i in range(4):
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
	var a_sites: int = a.cut.sites.size()
	var a_side: int = a.cut.face_side
	var a_deep: float = a.cut.deepest()
	_check(a_sites > 0 and a_side != 0 and a_deep > 0.0,
		"tree A takes a notch (%d cut(s), side %d, %.2f m deep)" % [a_sites, a_side, a_deep])

	var b: TreeTrunk = null
	for t in trees:
		if t != a:
			b = t
			break
	_check(b != null, "there is a second tree to chop")
	if b != null:
		_check(b.cut.is_untouched(),
			"tree B is untouched while tree A is half-notched (%d cuts, side %d)" % [
				b.cut.sites.size(), b.cut.face_side])
		# ...and no WOOD has come out of it either. This used to assert `not b.is_built()`,
		# which was a proxy for the lazy build and stopped meaning anything once the stand
		# is voxelised at spawn (2026-07-30). Measured wood is the property that actually
		# matters — a tree nobody has struck must be whole — and it holds either way.
		_check(b.removed_volume() <= 0.0,
			"...and no wood has come out of it, because nothing has struck it (%.4f m3)"
				% b.removed_volume())
		game.debug_stand_at_tree(b)
		await get_tree().process_frame
		var aim: Dictionary = game.debug_aim()
		_check(aim.ok and aim.trunk == b,
			"the crosshair picks the tree it is actually pointed at, not the one being chopped")
		# Measured BEFORE the tree is built, so it has to be taken after the build. Engage it
		# without striking it, exactly as the aim would.
		game.debug_engage(b)
		var wood_before: float = b.volume().volume()
		# A blow on B builds B's wood and opens B's OWN first cut.
		var landed_on_b: bool = game.debug_chop_tree(b, 1, 0.5)
		await get_tree().process_frame
		_check(b.is_built(), "the first blow on tree B builds its wood (lazy build, §3a)")
		# THE BLOW HAS TO ACTUALLY TAKE WOOD, and this is asserted on the MEASURED VOLUME
		# because everything cheaper to measure lies.
		#
		# A cut site's `depth` counter climbs whether or not the slab found any wood, so cut
		# count and notch depth are bookkeeping and prove nothing. And `holding_area() <
		# full_area()` — the obvious check, and the first one written here — passes on an
		# UNTOUCHED tree, because `full_area` is the median section, `holding_area` the
		# minimum, and tree_01 tapers 3%.
		#
		# What this catches: every scattered tree carries a random yaw, and
		# `MeshUtils.plane_to_local` rotated cut-plane normals the wrong way round (R instead
		# of R^T), so on a yawed tree the axe's solid missed the trunk entirely while the notch
		# reported itself getting deeper and the tree never fell. See test_slicer for the
		# maths, which is now pinned there directly.
		_check(landed_on_b, "...and the blow REPORTS that it took wood")
		var vol_before: float = wood_before
		var vol_after: float = b.volume().volume()
		_check(vol_after < vol_before - 0.0001,
			"...and the wood is MEASURABLY gone: %.4f -> %.4f m3 (removed %.4f)" % [
				vol_before, vol_after, vol_before - vol_after])
		_check(b.cut.sites.size() == 1,
			"...and opens ONE cut on it, not tree A's (%d)" % b.cut.sites.size())
		_check(a.cut.sites.size() == a_sites and is_equal_approx(a.cut.deepest(), a_deep),
			"...and tree A's notch is exactly as it was left (%d cuts, %.2f m)" % [
				a.cut.sites.size(), a.cut.deepest()])
		_check(a.cut.face_side == a_side,
			"...including the way it is committed to falling")

	# THE GROUND REACHES THE TREES (§4). `forest_floor_a` is one ~16 m patch and the stand is
	# 50 m across, so the floor is tiled. A tree standing over nothing is not a subtle bug
	# but it is an invisible one from the spawn point, so every trunk gets a ray under it.
	var unsupported := 0
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for t in trees:
		var above: Vector3 = (t as Node3D).global_position + Vector3.UP * 3.0
		var q := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 8.0)
		q.collision_mask = TreeTrunk.GROUND_LAYER
		if space.intersect_ray(q).is_empty():
			unsupported += 1
	_check(unsupported == 0, "every tree in the stand has ground under it (%d without)" % unsupported)
	# ...and so does the far edge of the stand, which is where the tiling actually has to
	# reach and where a player will walk.
	var edge_ok := 0
	for i in range(8):
		var a2 := TAU * float(i) / 8.0
		var radius: float = game.forest_radius
		var p := Vector3(cos(a2), 0.0, sin(a2)) * radius + Vector3.UP * 3.0
		var q2 := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 8.0)
		q2.collision_mask = TreeTrunk.GROUND_LAYER
		if not space.intersect_ray(q2).is_empty():
			edge_ok += 1
	_check(edge_ok == 8, "the tiled ground reaches the edge of the stand all the way round (%d of 8)" % edge_ok)

	# DEBRIS PERSISTS AS PILES (the A12 answer, Sam's call 2026-07-26). Settled splinters are
	# BAKED into a MultiMesh rather than deleted, so a pile stays where it was made — and the
	# number of piles is bounded by how many splinter MESHES the game has (three), not by how
	# many trees have come down.
	#
	# `max_debris` is dropped low ON PURPOSE. At the shipping 120 a few blows never reach the
	# cap, so consolidation never runs and a check written against it passes on nothing —
	# which is exactly what the first version of this did (0 baked into 0 piles, asserted
	# "<= 4", green).
	#
	# And the debris comes from SEVERAL TREES, a few blows each, rather than one tree chopped
	# hard. One tree chopped hard FELLS, and a felling fades the whole clearing and takes its
	# splinters with it — so the first version of this measured a board that had just been
	# swept, which is the opposite of the thing being tested.
	game.max_debris = 16
	var chopped := 0
	for t in trees:
		if chopped >= 6:
			break
		var tt: TreeTrunk = t
		if tt == null or not is_instance_valid(tt) or tt.has_broken():
			continue
		chopped += 1
		for i in range(3):
			game.debug_chop_tree(tt, 1, 0.5)
			await get_tree().process_frame
			for f in range(6):
				await get_tree().physics_frame
		# Let this tree's splinters land and fall asleep before moving on: only a SETTLED
		# piece is ever baked, which is the whole point — a pile is debris that has come to
		# rest, not debris in flight.
		await _wait(1.5)
	print("chopped %d trees a little, without felling any" % chopped)
	var baked: int = game.settled_debris_count()
	var piles: int = game.settled_pile_count()
	print("baked splinters: %d in %d pile(s); live debris %d (cap %d)" % [
		baked, piles, game.chip_count(), game.max_debris])
	_check(baked > 0, "settled splinters are BAKED into a pile, not deleted (%d baked)" % baked)
	_check(piles > 0 and piles <= 4,
		"...into a handful of MultiMesh piles, not one per splinter (%d)" % piles)
	# THE TRANSFORMS HAVE TO BE REAL, and this is asserted separately because counting
	# instances is not enough. Growing a MultiMesh reallocates and wipes every transform in it,
	# and the repair-by-buffer that looked right is rejected by Godot for a size mismatch — so
	# the pile kept its COUNT while every earlier splinter collapsed to identity, in a heap at
	# the scene origin. A count-only check saw nothing wrong.
	var xforms: Array = game.debug_pile_transforms()
	var at_origin := 0
	var spread := 0.0
	for x: Transform3D in xforms:
		if x.origin.length() < 0.01:
			at_origin += 1
		spread = maxf(spread, x.origin.length())
	_check(xforms.size() == baked,
		"...every baked splinter has a transform (%d of %d)" % [xforms.size(), baked])
	_check(at_origin == 0,
		"...and none of them collapsed to the origin (%d at origin)" % at_origin)
	_check(spread > 1.0,
		"...they are spread across the stand where they fell (furthest %.1f m out)" % spread)
	# THE REAL BOUND, and it is not "never more than max_debris". Two things make the cap
	# soft, both on purpose:
	#   - `_retire_old_debris` only ever retires a SETTLED piece, so nothing is pulled out of
	#     the air in front of the player;
	#   - and it runs when debris is SPAWNED, so after the last blow nothing prunes.
	# So the live count can sit at the cap plus the burst that pushed it over, and stays there
	# until the next blow. That is bounded, which is all A12 needs — and it is worth asserting
	# tightly rather than loosely, because a leak would show up here as growth.
	await _wait(3.0)
	var bound: int = (game.max_debris as int) + (game.splinter_burst_cap as int)
	_check(game.chip_count() <= bound,
		"live debris is bounded by max_debris + one burst (%d of %d = %d + %d)" % [
			game.chip_count(), bound, game.max_debris, game.splinter_burst_cap])
	# The pile only ever GROWS: nothing that has been baked is thrown away later, which is
	# the whole difference from the old behaviour.
	var before_more: int = baked
	for t in trees:
		var tt: TreeTrunk = t
		if tt == null or not is_instance_valid(tt) or tt.has_broken() or tt == a:
			continue
		for i in range(3):
			game.debug_chop_tree(tt, 1, 0.5)
			await get_tree().process_frame
			for f in range(6):
				await get_tree().physics_frame
		break
	await _wait(2.0)
	_check(game.settled_debris_count() >= before_more,
		"a pile never shrinks: %d baked, was %d" % [game.settled_debris_count(), before_more])

	# ==========================================================================
	# FELL ONE TREE, THEN CHOP ANOTHER. Sam, 2026-07-27: *"when you cut / fell one tree, you
	# can no longer cut any of the others."*
	#
	# `_felling` means "a tree is going over right now" and it was only ever cleared by
	# spawning a fresh board — correct while the board always replaced its one tree, and dead
	# wrong in a stand where nothing regrows: the flag stayed set for the rest of the session
	# and `_on_click` refuses every blow while it is. The axe died after the first tree.
	#
	# NOTHING COVERED THIS, which is why it reached Sam. Every check above chops without
	# felling; m5_acceptance fells constantly but with `tree_count = 1` and `auto_respawn`, so
	# a fresh board always came along and cleared the flag. It took a stand AND a felling AND
	# no respawn together.
	game.fail_stress = gameplay_fail_stress
	game.max_debris = 120
	var victim: TreeTrunk = null
	for t in trees:
		var tt: TreeTrunk = t
		if tt != null and is_instance_valid(tt) and not tt.has_broken():
			victim = tt
			break
	if victim == null:
		_check(false, "there is a tree left standing to fell")
	else:
		game.debug_stand_at_tree(victim, 2.6, 0.5)
		var blows := 0
		while blows < 60 and not game.is_felling():
			game.debug_chop_tree(victim, 1, 0.5)
			blows += 1
			await get_tree().process_frame
		_check(game.is_felling(), "a tree in the stand fells (%d blows)" % blows)
		var falling_canopies := game.find_children(
			"ShedCanopy", "MeshInstance3D", true, false)
		var canopy_attached := falling_canopies.size() == 1
		if canopy_attached:
			var canopy_parent := falling_canopies[0].get_parent()
			canopy_attached = canopy_parent != null and canopy_parent.name in [
				"FallingTree", "FallenTrunk"]
		_check(canopy_attached,
			"its canopy remains attached to the timber while the tree falls")
		for i in range(240):
			await _wait(0.25)
			if game.is_bucking() or not game.is_felling():
				break
		_check(not game.is_felling(),
			"...and once it is down the axe is FREE again, not stuck felling")
		_check(game.is_bucking(), "...with the trunk lying there to be bucked")
		_check(game.find_children("ShedCanopy", "MeshInstance3D", true, false).is_empty(),
			"...and its branches and leaves despawn when the trunk lands")
		var fallen: RigidBody3D = game.fallen_trunk()
		var fallen_names: Array[String] = []
		var canopy_materials := 0
		if fallen != null:
			for child in fallen.get_children():
				var mi := child as MeshInstance3D
				if mi == null or mi.mesh == null:
					continue
				fallen_names.append(mi.name)
				for si in range(mi.mesh.get_surface_count()):
					var mat := mi.mesh.surface_get_material(si)
					var material_name := mat.resource_name.to_lower() if mat != null else ""
					if ("canopy" in material_name or "leaf" in material_name
							or "lefs" in material_name):
						canopy_materials += 1
		_check(fallen_names.has("WoodyCrown"),
			"...and the bucking body keeps its authored upper trunk")
		_check(not fallen_names.has("Crown") and canopy_materials == 0,
			"...without any canopy-bark or leaf materials")

		# THE WHOLE POINT: another tree can now be chopped.
		var next_tree: TreeTrunk = null
		for t in trees:
			var tt2: TreeTrunk = t
			if tt2 != null and is_instance_valid(tt2) and tt2 != victim and not tt2.has_broken():
				next_tree = tt2
				break
		# NOTHING REGROWS, so the slot the felled tree left stays EMPTY and the stand gets
		# smaller. Sam's call, and it shipped broken: `auto_respawn` defaulted to true, so a
		# felled trunk faded and another tree popped straight into its place —
		# *"the trees respawn instantly after they despawn"* — and the stand could never be
		# cleared at all. The DECISION was written down and the DEFAULT was not changed to match.
		_check(not game.auto_respawn,
			"the shipping stand does not regrow (auto_respawn is off by default)")
		var standing_now := 0
		for t in game.debug_trees():
			var tt3: TreeTrunk = t
			if tt3 != null and is_instance_valid(tt3) and not tt3.has_broken():
				standing_now += 1
		_check(standing_now == trees.size() - 1,
			"...so felling one leaves the stand one tree smaller (%d standing of %d)" % [
				standing_now, trees.size()])
		var slot_free := true
		for t in game.debug_trees():
			var tt4: TreeTrunk = t
			if tt4 != null and is_instance_valid(tt4) and not tt4.has_broken() \
					and tt4.global_position.distance_to(victim.global_position) < 0.5:
				slot_free = false
		_check(slot_free, "...and nothing has grown back where it stood")

		_check(next_tree != null, "there is another tree standing after the first came down")
		if next_tree != null:
			# This assertion is about the axe accepting another blow, not about
			# immediately starting a second fall (which would intentionally
			# finalise the first trunk's single-instance bucking state). Keep the
			# second tree standing until the first one's bucking checks finish.
			game.fail_stress = 1000000.0
			game.debug_stand_at_tree(next_tree, 2.6, 0.5)
			await get_tree().process_frame
			game.debug_engage(next_tree)
			var w0: float = next_tree.volume().volume()
			var ok2: bool = game.debug_chop_tree(next_tree, 1, 0.5)
			await get_tree().process_frame
			_check(ok2, "A TREE FELLED DOES NOT STOP THE NEXT ONE BEING CHOPPED")
			_check(next_tree.volume().volume() < w0 - 0.0001,
				"...and the blow really takes wood (%.4f -> %.4f m3)" % [
					w0, next_tree.volume().volume()])

			# ROUGHLY buck_target_logs LOGS. Sam, 2026-07-27: "the log sizes are soo small.
			# It should be roughly 5 logs per tree."
			var cuts := 0
			while cuts < 20:
				var idx: int = game.debug_next_bucking_log()
				if idx < 0:
					break
				for b3 in range(game.buck_blows):
					game.debug_buck(idx)
					await get_tree().process_frame
				cuts += 1
				await _wait(0.1)
			var lens: Array = game.debug_log_lengths()
			var shortest_log := INF
			for l in lens:
				shortest_log = minf(shortest_log, l as float)
			print("bucked into %d lengths, shortest %.2f m, minimum %.2f m (target %d logs)" % [
				lens.size(), shortest_log, game.min_log_length(), game.buck_target_logs])
			_check(cuts >= (game.buck_target_logs as int) - 2 and cuts <= game.buck_target_logs,
				"a felled trunk bucks into about %d logs, not a pile of coins (%d cuts)" % [
					game.buck_target_logs, cuts])
			_check(shortest_log >= (game.min_log_length() as float) - 0.001 or lens.is_empty(),
				"...and none of them is under the minimum (%.2f m of %.2f)" % [
					shortest_log, game.min_log_length()])
			game.fail_stress = gameplay_fail_stress

	await _second_felling_sheds_too(gameplay_fail_stress)

	print("nodes: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("=== FOREST SMOKE: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== FOREST SMOKE OK ===")
	get_tree().quit()


## FELL TWO TREES AND LEAVE THE FIRST ONE LYING THERE — which is what a player does.
##
## THE SECOND TREE OF A SESSION KEPT ITS LEAVES, and nothing above could catch it. The
## landing bookkeeping (`_landed`, `_settled`) was only ever reset by a fresh board or by
## the fade that follows a trunk being BUCKED OUT, and the shipping stand ships
## `trunk_persists` on with nothing regrowing. So a player who fells a tree, walks off and
## fells the next one without bucking the first reached neither: `_on_trunk_contact` bailed
## on the stale `_landed` and never removed the canopy, and `_watch_fallen` bailed on the
## stale `_settled` so the trunk was never frozen and bucking never began. Reported by Sam
## as leaves that do not despawn when the tree is on the ground.
##
## IT NEEDS ITS OWN GAME, and that is the third time that lesson has come up here: the
## phase above buckes its victim out, which resets the very state this is about, so
## appending to it would measure a board that had just been swept.
func _second_felling_sheds_too(gameplay_fail_stress: float) -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	# THE SHIPPING SETTING, and the whole point of this check: the first trunk stays on
	# the ground unbucked while the second tree is felled on top of it.
	game.trunk_persists = true
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.tree_count = 6
	game.forest_radius = 14.0
	game.fail_stress = gameplay_fail_stress
	add_child(game)
	await _wait(1.5)

	for round_index in range(2):
		var victim: TreeTrunk = null
		for t in game.debug_trees():
			var tt: TreeTrunk = t
			if tt != null and is_instance_valid(tt) and not tt.has_broken():
				victim = tt
				break
		if victim == null:
			_check(false, "felling round %d has a tree to fell" % (round_index + 1))
			break
		game.debug_stand_at_tree(victim, 2.6, 0.5)
		await get_tree().process_frame
		var blows := 0
		while blows < 80 and not victim.has_broken():
			game.debug_chop_tree(victim, 1, 0.5)
			blows += 1
			await get_tree().process_frame
		_check(victim.has_broken(), "felling round %d: the tree goes over (%d blows)" % [
			round_index + 1, blows])
		for i in range(240):
			await _wait(0.25)
			if game.is_bucking() or not game.is_felling():
				break
		# BOTH of these were false for round 2 before the fix, and both come from the same
		# stale flag — a landing that was never registered runs none of the landing.
		_check(game.find_children("ShedCanopy", "MeshInstance3D", true, false).is_empty(),
			"felling round %d: its canopy despawns when the trunk lands" % (round_index + 1))
		_check(game.is_bucking(),
			"felling round %d: ...and the trunk lies there ready to be bucked" % (
				round_index + 1))
	game.queue_free()
	await get_tree().process_frame
