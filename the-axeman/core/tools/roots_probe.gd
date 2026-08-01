extends Node
## res://core/tools/roots_probe.gd — attaches to the root Node of roots_probe.tscn.
##
## DEV DIAGNOSTIC for "I want to be able to cut all the way down to the roots"
## (Sam, 2026-07-31) — i.e. for `voxel_roots`, handoff/09 §2.
##
## Runs each species with the switch OFF and then ON, and reports the things that
## differ between them: where the band starts, what the flare does to the level
## stats the load model reads, how low the player may aim, and — after felling —
## the holding wood, the hinge, the break height and the stump's collider.
##
## Run: godot --headless --path . --quit-after 400000 \
##   res://core/tools/roots_probe.tscn

## Where to chop. -1 = as low as the game allows (Sam's ask); a height = that height
## (m5_acceptance uses 0.5, which on tree_01 is inside the flare).
const AIM_AT := -1.0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	print("=== ROOTS PROBE ===")
	for species in [0, 1]:
		for roots in [false, true]:
			await _probe(species, roots)
	print("=== ROOTS PROBE DONE ===")
	get_tree().quit()


func _probe(species: int, roots: bool) -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = species
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.tree_count = 1
	game.trunk_persists = true
	game.auto_respawn = false
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.voxel_roots = roots
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.trunk()
	if trunk == null or not trunk.is_built():
		print("FAIL: no trunk for species %d" % species)
		game.queue_free()
		return
	print("\n--- species %d (%s) — voxel_roots %s ---" % [
		species, trunk.species_id, "ON" if roots else "off"])
	var vol: WoodVolume = trunk.volume()
	print("band %.3f .. %.3f (ground %.3f, flare top %.3f, crown base %.3f)" % [
		trunk.band_lo, trunk.band_hi, trunk.ground_y, trunk.debug_flare_top(),
		trunk.crown_base()])
	print("grid %dx%dx%d cell %.3f  radius %.3f  band_max_radius %.3f  wood %.3f m3" % [
		vol.nx, vol.ny, vol.nz, vol.cell, trunk.radius, trunk.band_max_radius, vol.volume()])
	print("aim allowed: %.3f .. %.3f" % [
		game.debug_min_cut_height(trunk), game.debug_max_cut_height(trunk)])

	# THE LEVELS THE LOAD MODEL READS. With the flare in the field the bottom of the band
	# is a buttressed section several times the stem's, and every yardstick in the model is
	# per-level — so what matters is whether the profile is monotonic and sane, not its size.
	var s: Array[Dictionary] = trunk.sections()
	print("levels: %d   (y, uncut area m2, reach m)" % s.size())
	var step := maxi(s.size() / 10, 1)
	for j in range(0, s.size(), step):
		var reach := 0.0
		var sup: PackedFloat32Array = trunk.base_reach(j)
		for r in sup:
			reach = maxf(reach, r)
		print("  %5.2f | %6.3f | %5.3f" % [s[j].y, trunk.debug_base_area(j), reach])

	# --- fell it. `AIM_AT` picks between the thing Sam asked for (as low as the game
	# allows) and the height m5_acceptance uses, which is what the suite is failing on.
	var aim: float = (game.debug_min_cut_height(trunk) + 0.05) if AIM_AT < 0.0 else AIM_AT
	aim = clampf(aim, game.debug_min_cut_height(trunk), game.debug_max_cut_height(trunk))
	print("chopping at y = %.3f  (flare top %.3f — %s)" % [
		aim, trunk.debug_flare_top(),
		"IN THE FLARE" if aim < trunk.debug_flare_top() else "on the clear stem"])
	var blows := 0
	while blows < 60 and not game.is_felling():
		game.debug_blow(1, aim)
		await get_tree().process_frame
		blows += 1
		var v: Dictionary = game.debug_evaluate()
		if blows % 3 == 0 or (not v.is_empty() and not bool(v.get("controlled", false))):
			print("  blow %2d: notch %3.0f%%, holding %.4f, worst level y=%.2f area=%.4f"
				% [blows, game.notch_depth() * 100.0, game.holding_wood(),
					v.get("y", -1.0), v.get("area", -1.0)]
				+ "  stress %.2f  %s" % [game.last_stress(),
					"HINGE" if bool(v.get("controlled", false)) else "COLLAPSE (severed/crushed)"])
	if not game.is_felling():
		print(">>> NEVER FELL in %d blows (notch %.0f%%, stress %.2f)" % [
			blows, game.notch_depth() * 100.0, game.last_stress()])
		game.queue_free()
		await get_tree().process_frame
		return
	print(">>> felled in %d blows: holding %.4f m2, hinge %.3f m, intact %s, stress %.2f" % [
		blows, game.holding_wood(), game.hinge_thickness(), game.hinge_was_intact(),
		game.last_stress()])
	print(">>> break at y = %.3f, timber %.3f m" % [
		trunk.break_height(), game.debug_fallen_length()])

	for i in range(400):
		await _wait(0.05)
		if game.is_bucking():
			break
	print(">>> bucking: %s, min log %.3f m, next cuttable %d" % [
		game.is_bucking(), game.min_log_length(), game.debug_next_bucking_log()])
	# BUCK IT RIGHT OUT, exactly as m5_acceptance's _test_17 does — that is the check
	# reporting "1 cut for a target of 5".
	var cuts := 0
	while cuts < 40:
		var idx: int = game.debug_next_bucking_log()
		if idx < 0:
			break
		var span_before: Vector2 = game.debug_log_span(idx)
		for b in range(game.buck_blows):
			game.debug_buck(idx)
			await get_tree().process_frame
		cuts += 1
		print("   cut %d on log %d (span %.2f..%.2f, %.2f m) -> lengths %s" % [
			cuts, idx, span_before.x, span_before.y, span_before.y - span_before.x,
			str(game.debug_log_lengths())])
		await _wait(0.05)
	print(">>> %d cuts, %d lengths, target %d" % [
		cuts, game.log_count(), game.buck_target_logs])

	# --- the stump, which is what is left where the roots were ---------------
	for i in range(200):
		await _wait(0.05)
		if game.stump_count() > 0:
			break
	_report_stump(game, trunk)
	game.queue_free()
	await get_tree().process_frame


## Is the stump solid at ankle height? That is the check `_test_17` makes, and with the
## band starting at the ground the stump is built over the flare rather than above it.
func _report_stump(game: Node, trunk: TreeTrunk) -> void:
	var body: StaticBody3D = null
	for child in trunk.get_children():
		if child is StaticBody3D:
			body = child
	if body == null:
		print(">>> STUMP: no StaticBody3D on the trunk at all")
	else:
		for child in body.get_children():
			var cs := child as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			if cs.shape is CylinderShape3D:
				var c: CylinderShape3D = cs.shape
				print(">>> STUMP cyl h=%.3f r=%.3f at (%.2f, %.3f, %.2f) -> y %.3f .. %.3f" % [
					c.height, c.radius, cs.position.x, cs.position.y, cs.position.z,
					cs.position.y - c.height * 0.5, cs.position.y + c.height * 0.5])
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for h in [0.1, 0.2, 0.4, 0.8]:
		var q := PhysicsRayQueryParameters3D.create(
			trunk.global_position + Vector3(3.0, h, 0.0),
			trunk.global_position + Vector3(-3.0, h, 0.0))
		q.collision_mask = TreeTrunk.TIMBER_LAYER
		var hit := space.intersect_ray(q)
		print("    ray at y=%.2f: %s" % [h, "SOLID" if not hit.is_empty() else "THROUGH"])
