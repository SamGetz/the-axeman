extends Node
## DEV TOOL. Simulates SPAM CLICKING — blows at the fastest rate the input path allows,
## across several trees back to back — and reports whether the cost per blow, the amount
## of debris and the physics frame stay flat or creep up.
##
## This is the measurement for the thing Sam actually reported: "the simulation tends to
## get a little heavy when the user is spam clicking the tree". A single blow being fast
## is not the same as the hundredth blow being fast.
##
## Run: godot --headless --path . --quit-after 400000 res://core/tools/felling_spam.tscn

const _TREES := 4


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	print("=== FELLING SPAM ===")
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
	# ...and a FRESH TREE each round, which this tool needs and the game does not: nothing
	# regrows in the stand (Sam's call), so `auto_respawn` ships OFF and anything that wants
	# a new tree per round has to ask. The `_fell_cost` helper below deliberately leaves it
	# off — it fells exactly one tree per instance.
	game.auto_respawn = true
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await _wait(1.2)

	print("max_debris = %d" % game.max_debris)
	print("")
	# NOTE ON WHAT IS NOT MEASURED HERE. Physics cost is deliberately absent: awaiting
	# physics_frame measures WALL CLOCK, which headless ticks at the project rate
	# whatever the load, and `Performance.TIME_PHYSICS_PROCESS` comes back wildly
	# inconsistent on a headless run that is free-wheeling. Node and body counts are
	# solid and are what actually drives the physics cost, so those are reported and
	# the millisecond judgement is left to real hardware.
	print(" tree | blow | blow ms | debris | budget active | nodes")
	print("------+------+---------+--------+---------------+------")

	var first_ms := 0.0
	var last_ms := 0.0
	var worst_debris := 0
	var worst_frame := 0.0
	for tree in range(_TREES):
		# Wait for a tree to be standing and finished bouncing in.
		for i in range(120):
			var t: TreeTrunk = game.trunk()
			if t != null and is_instance_valid(t) and t.is_built() \
					and not game._animator.is_animating(t) and not game.is_felling():
				break
			await _wait(0.1)
		if game.trunk() == null or not is_instance_valid(game.trunk()):
			print("  (no tree %d)" % tree)
			continue
		var blow := 0
		while blow < 40 and not game.is_felling() and _standing(game):
			var t0 := Time.get_ticks_usec()
			game.debug_blow(1, 0.5)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			blow += 1
			# A frame between blows, exactly as the click path guarantees.
			await get_tree().process_frame
			for r in range(10):
				await get_tree().physics_frame
			worst_debris = maxi(worst_debris, game.chip_count())
			worst_frame = maxf(worst_frame,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if blow == 1:
				# Like for like across trees: the first chop into fresh wood.
				if tree == 0:
					first_ms = ms
				last_ms = ms
			if blow % 4 == 0 or blow == 1:
				print(" %4d | %4d | %7.1f | %6d | %13d | %5d" % [
					tree, blow, ms, game.chip_count(), game._budget.active_count(),
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		# Let it fall, fade and respawn.
		for i in range(200):
			await _wait(0.25)
			var t2: TreeTrunk = game.trunk()
			if t2 != null and is_instance_valid(t2) and not t2.has_cut():
				break

	print("")
	print("first chop into fresh wood: %.1f ms on tree 0 -> %.1f ms on tree %d" % [
		first_ms, last_ms, _TREES - 1])
	print("worst debris on the ground: %d (cap %d)" % [worst_debris, game.max_debris])
	print("peak node count: %d" % int(worst_frame))
	print("pine_log banked: %d" % InventoryManager.get_count(&"pine_log"))
	game.queue_free()
	await get_tree().process_frame
	await _walk_re_measure()
	print("=== FELLING SPAM DONE ===")
	get_tree().quit()


## WALK RE-MEASURE — the plan's §6 ask, and the answer to §2's open question.
##
## M5 PASS 5 measured `cut_span` against a camera that orbited a tree it could not
## approach, and concluded that below about 0.6 m a tree "cannot be felled from one
## viewpoint at all" — which is why `_warn_cut_span` shouted about it. Sam's live value
## is 0.50. A player on foot can WALK ROUND THE TRUNK, so that premise no longer holds
## and the number had to be re-measured before the warning could be reworded.
##
## `debug_stand_at` is the walk: it moves the player round the tree between blows,
## which is exactly what a narrow span asks of them. The comparison is against staying
## put, so the difference is attributable to the walking and nothing else.
func _walk_re_measure() -> void:
	print("")
	print("--- WALK RE-MEASURE: can a narrow cut_span be felled on foot? ---")
	print(" cut_span | standing still     | walking round the tree")
	print("----------+--------------------+-----------------------")
	for span in [1.6, 0.8, 0.5, 0.35]:
		var fixed := await _fell_cost(span, false)
		var walked := await _fell_cost(span, true)
		print("   %5.2f m | %-18s | %s" % [span, fixed, walked])


## Fell one tree at `span`, either from one spot or walking round it, and report what
## it cost. `_TREES`-independent: its own game instance, dropped afterwards.
func _fell_cost(span: float, walk: bool) -> String:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	# ONE TREE, at the origin, unrotated — this tool is about one tree's geometry and it frames
	# its work with the dev camera, which orbits the scene origin. The shipping scene is a
	# scattered stand of 25 with a random yaw each, so without this the tool would be measuring
	# a tree ten metres away from the camera it is aiming with.
	game.tree_count = 1
	game.trunk_persists = false
	game.auto_respawn = false
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.cut_span = span
	add_child(game)
	await _wait(1.2)
	var trunk: TreeTrunk = game.trunk()
	if trunk == null or not is_instance_valid(trunk):
		game.queue_free()
		return "(no tree)"
	game._animator.finish_for([trunk])

	# The walk is a quarter turn either side of head-on, stepped every few blows —
	# a player working their way round the trunk rather than standing in one place.
	const _STEPS := [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 160.0]
	var blows := 0
	# Generous, because the question is "can it be done at all", not "how fast".
	while blows < 150 and not game.is_felling():
		if walk:
			game.debug_stand_at(_STEPS[(blows / 3) % _STEPS.size()] as float, 3.0, 0.5)
		game.debug_blow(1, 0.5)
		blows += 1
		await get_tree().process_frame
	var out := ""
	if game.is_felling():
		out = "%d blows, notch %.0f%%" % [blows, game.notch_depth() * 100.0]
	else:
		out = "NEVER FELL (%d blows, notch %.0f%%)" % [blows, game.notch_depth() * 100.0]
	game.queue_free()
	await get_tree().process_frame
	return out


func _standing(game: Node) -> bool:
	var t: TreeTrunk = game.trunk()
	return t != null and is_instance_valid(t) and t.is_built() and not t.has_broken()
