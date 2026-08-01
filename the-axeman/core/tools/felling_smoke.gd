extends Node
## DEV SMOKE TEST for the M5 tree-felling mini-game (Amendment 13 voxel wood).
## Fast, chatty version of the acceptance suite — use it while iterating.
## Run: godot --headless --path . --quit-after 4000 res://core/tools/felling_smoke.tscn
##
## NOTE: waits are REAL-TIME timers, never frame counts. Headless runs uncapped,
## so a few hundred process frames can pass in well under a second of the game
## clock the fall and the physics settle actually run on.

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	print("=== FELLING SMOKE ===")
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
	# a new tree per round has to ask.
	game.auto_respawn = true
	# Pinned exactly as m5_acceptance pins them, and for the same reason: this reports on
	# the MECHANIC, not on whatever Sam currently has dialled into the .tscn. Without this
	# a live `cut_span` narrower than the trunk makes the tree unfellable and the smoke
	# test reads as a pile of regressions.
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.trunk()
	if trunk == null or not trunk.is_built():
		print("FAIL: no trunk was built")
		get_tree().quit()
		return
	var vol: WoodVolume = trunk.volume()
	print("trunk: height=%.2f radius=%.3f diameter=%.2f band=%.2f..%.2f" % [
		trunk.height, trunk.radius, trunk.diameter, trunk.band_lo, trunk.band_hi])
	print("voxels: %dx%dx%d cell=%.3f  full section=%.3f m2  wood=%.3f m3" % [
		vol.nx, vol.ny, vol.nz, vol.cell, trunk.full_area(), vol.volume()])
	print("PASS: tree stands whole" if not trunk.has_cut() else "FAIL: pre-carved")

	# --- the face notch -----------------------------------------------------
	var t0 := Time.get_ticks_msec()
	game.debug_blow(1, 0.5)
	var blow_ms := Time.get_ticks_msec() - t0
	await get_tree().process_frame
	print("PASS: the first blow bit (%d chips, %d ms for carve+remesh)" % [
		game.chip_count(), blow_ms] if trunk.has_cut() else "FAIL: nothing was cut")
	print("notch after 1 blow: %.1f%% of the diameter, holding %.3f m2, stress %.3f" % [
		game.notch_depth() * 100.0, game.holding_wood(), game.last_stress()])

	var n := 1
	while n < 30 and game.notch_depth() < 0.6 and not game.is_felling():
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
		n += 1
	print("PASS: the notch reached %.0f%% of the diameter in %d blows" % [
		game.notch_depth() * 100.0, n] if game.notch_depth() >= 0.55 \
		else "FAIL: the notch stalled at %.0f%% after %d blows" % [game.notch_depth() * 100.0, n])
	print("after the notch: holding %.3f m2 (of %.3f), stress %.3f, felling=%s" % [
		game.holding_wood(), trunk.full_area(), game.last_stress(), game.is_felling()])
	print("PASS: a notch this deep does NOT fell it yet" if not game.is_felling() 		else "FAIL: it came down too early")

	# --- keep chopping the same cut ----------------------------------------
	# Every blow is head-on, on the side the player can see; there is no back cut.
	var b := 0
	while b < 40 and not game.is_felling():
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
		b += 1
		print("  blow %d: notch in %.0f%%, hinge %.3f m, holding %.3f m2, stress %.2f" % [
			b, game.notch_depth() * 100.0, game.hinge_thickness(), game.holding_wood(),
			game.last_stress()])
	print("PASS: chopping on fells it (%d + %d = %d blows)" % [n, b, n + b] 		if game.is_felling() else "FAIL: it never came down (%d blows)" % (n + b))
	print("hinge intact at the fell: %s   cracks: %d" % [
		game.hinge_was_intact(), game.crack_count()])

	# --- did it go the right way? ------------------------------------------
	var cam: Camera3D = game.camera()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	var dot: float = game.fall_direction().dot(right.normalized())
	print("PASS: it goes over toward the notch (dot %.2f)" % dot if dot > 0.3 \
		else "FAIL: it went the wrong way (dot %.2f) — notch side was %d" % [dot, game.face_side()])

	# --- the fall -----------------------------------------------------------
	var hinged := false
	var physical := false
	for i in range(120):
		await _wait(0.05)
		hinged = hinged or game.is_hinging()
		physical = physical or game.is_falling_physically()
		if physical:
			break
	print("PASS: it hangs off the hinge before it goes free" if hinged \
		else "FAIL: it never rotated on the hinge")
	print("PASS: the fall is handed to physics (%.0f deg)" % game.fall_tilt_deg() if physical \
		else "FAIL: no rigid body took the fall over")

	var landed := false
	var collected := false
	for i in range(80):
		await _wait(0.25)
		landed = landed or game.has_landed()
		collected = collected or game.has_collected()
		if collected:
			break
	print("PASS: the felled tree landed" if landed else "FAIL: it never landed")
	print("PASS: yields collected" if collected else "FAIL: yields never collected")
	print("pine_log in inventory: %d" % InventoryManager.get_count(&"pine_log"))

	for i in range(40):
		await _wait(0.25)
		var fresh: TreeTrunk = game.trunk()
		if fresh != null and is_instance_valid(fresh) and not fresh.has_cut():
			break
	var t2: TreeTrunk = game.trunk()
	print("PASS: a fresh tree respawned" if t2 != null and is_instance_valid(t2) and not t2.has_cut() \
		else "FAIL: no fresh tree after the fell")
	print("=== FELLING SMOKE DONE ===")
	get_tree().quit()
