extends Node
## DEV TOOL (not shipped). Prints the felling band's voxel field as ASCII so the
## notch, the back cut and the hinge can be READ rather than guessed at from a
## render. Run:
##
##   godot --headless --path . --quit-after 3000 res://core/tools/probe_tree.tscn
##
## Two views per stage:
##   PLAN     one horizontal slice — the section the load model is measuring.
##   PROFILE  the vertical slice through the fall line — the notch in profile,
##            which is the thing the player is supposed to be able to read.
## '#' is wood, '.' is air, '+' marks the trunk axis.

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
	add_child(game)
	await get_tree().process_frame
	var trunk: TreeTrunk = game.trunk()
	print("radius %.3f  band %.2f..%.2f  cell %.3f" % [
		trunk.radius, trunk.band_lo, trunk.band_hi, trunk.volume().cell])

	_dump(game, trunk, "UNCUT")
	for i in range(9):
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
	print("\n--- after %d face blows: notch %.0f%%, holding %.3f m2, stress %.2f" % [
		9, game.notch_depth() * 100.0, game.holding_wood(), game.last_stress()])
	_dump(game, trunk, "NOTCHED")

	var b := 0
	while b < 40 and not game.is_felling():
		game.debug_blow(1, 0.5)
		await get_tree().process_frame
		b += 1
	print("\n--- after %d more blows on the same cut: holding %.4f m2, stress %.2f, intact %s" % [
		b, game.holding_wood(), game.last_stress(), game.hinge_was_intact()])
	_dump(game, trunk, "FELLING")
	get_tree().quit()


func _dump(game: Node, trunk: TreeTrunk, tag: String) -> void:
	var v: WoodVolume = trunk.volume()
	var f: Vector3 = game.fall_direction()
	if trunk.has_broken():
		print("[%s] the tree has already broken; field is the stump" % tag)
	# PROFILE: the x/y plane through the axis, along the fall line. Rows are
	# heights (top first), columns run from the back of the trunk to the notch.
	print("\n[%s] PROFILE along the fall line (right = the way it falls)" % tag)
	var mid_k := int(round((trunk.axis_xz.y - v.origin.z) / v.cell))
	for j in range(v.ny - 1, -1, -1):
		var row := "%5.2f " % v.level_y(j)
		for i in range(v.nx):
			var p := v.origin + Vector3(float(i), float(j), float(mid_k)) * v.cell
			row += "#" if v.sample(p + Vector3(0.001, 0.001, 0.001)) < 0.0 else "."
		print(row)
	# PLAN: the section at the notch height.
	var y: float = game.notch_height()
	if y == INF:
		y = trunk.band_lo + 0.45
	var j0 := v.level_of(y)
	print("[%s] PLAN at y=%.2f (fall line runs left->right)" % [tag, v.level_y(j0)])
	for k in range(v.nz):
		var row := "      "
		for i in range(v.nx):
			var p := v.origin + Vector3(float(i), float(j0), float(k)) * v.cell
			row += "#" if v.sample(p + Vector3(0.001, 0.001, 0.001)) < 0.0 else "."
		print(row)
	print("   fall dir (%.2f, %.2f)" % [f.x, f.z])

