extends Node
## DEV PROFILER for the M5 tree-felling blow. Breaks one blow into its parts so
## the cost can be attributed rather than guessed at.
## Run: godot --headless --path . --quit-after 20000 res://core/tools/felling_profile.tscn
##
## Times the WHOLE blow (debug_blow), then re-times the individual WoodVolume
## operations that blow performed, on the same live field, so the remainder can be
## attributed to the carve and the load model.

const _RUNS := 3


func _ready() -> void:
	print("=== FELLING PROFILE ===")
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
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.auto_respawn = false
	add_child(game)
	await get_tree().process_frame

	var trunk: TreeTrunk = game.trunk()
	var vol: WoodVolume = trunk.volume()
	print("grid %dx%dx%d = %d samples, cell %.3f, band %.2f..%.2f of %.2f m" % [
		vol.nx, vol.ny, vol.nz, vol.nx * vol.ny * vol.nz, vol.cell,
		trunk.band_lo, trunk.band_hi, trunk.height])
	# BASELINE, before any debris exists: is a spawn inherently ~1 ms, or is it the
	# A12 budget's O(n) rescan? Time the same 50 spawns with the budget in the loop
	# and with it bypassed.
	var t_a := Time.get_ticks_usec()
	var cold: Array = []
	for r in range(50):
		cold.append(game._spawn_chip(game._stick_mesh(0.018, 0.16),
			trunk.global_position + Vector3(0.0, 3.0, 0.0), 1.2))
	print("cold spawn (empty budget):   %.2f ms each" % (
		float(Time.get_ticks_usec() - t_a) / 50.0 / 1000.0))
	var t_b := Time.get_ticks_usec()
	for r in range(50):
		game._budget.track(cold[r])
	print("budget.track() alone at n=%d: %.2f ms each" % [
		game._budget.tracked_count(), float(Time.get_ticks_usec() - t_b) / 50.0 / 1000.0])
	var t_c := Time.get_ticks_usec()
	for r in range(50):
		var b = load("res://scenes/3d_action/fragment_piece.tscn").instantiate()
		b.queue_free()
	print("instantiate() alone:         %.2f ms each" % (
		float(Time.get_ticks_usec() - t_c) / 50.0 / 1000.0))
	for b in cold:
		if is_instance_valid(b):
			b.queue_free()
	await get_tree().process_frame

	print("")
	print("blow |  total | remesh(chunk/whole) | stats(full/inc) | floating | remainder")
	print("-----+--------+---------------------+-----------------+----------+----------")

	var n := 0
	while n < 14 and not game.is_felling():
		var t0 := Time.get_ticks_usec()
		game.debug_blow(1, 0.5)
		var total := Time.get_ticks_usec() - t0
		n += 1
		if game.is_felling():
			print("%4d | %6.1f | (felled)" % [n, total / 1000.0])
			break

		# Re-time the individual operations the blow just did, on the same field.
		# The remesh is the CHUNKED one the game actually does — re-dirtying exactly the
		# levels this carve touched and re-surfacing the chunks that cover them.
		var mats := _mats(trunk)
		var t1 := Time.get_ticks_usec()
		for r in range(_RUNS):
			vol._mark_chunks(vol._cut_lo.y, vol._cut_hi.y)
			trunk._remesh()
		var remesh := float(Time.get_ticks_usec() - t1) / float(_RUNS)
		var t1b := Time.get_ticks_usec()
		for r in range(_RUNS):
			vol.build_mesh(mats[0], mats[1])
		var whole := float(Time.get_ticks_usec() - t1b) / float(_RUNS)

		# Two numbers now that the measurement is incremental: what a FULL remeasure of
		# the band costs (what every blow used to pay), and what the four-ish levels a
		# blow actually touches cost (what it pays now).
		var t2 := Time.get_ticks_usec()
		for r in range(_RUNS):
			vol._dirty_levels(0, vol.ny - 1)
			vol.level_stats()
		var stats := float(Time.get_ticks_usec() - t2) / float(_RUNS)
		var t2b := Time.get_ticks_usec()
		for r in range(_RUNS):
			vol._dirty_levels(vol._cut_lo.y, vol._cut_hi.y)
			vol.level_stats()
		var stats_inc := float(Time.get_ticks_usec() - t2b) / float(_RUNS)

		var t3 := Time.get_ticks_usec()
		for r in range(_RUNS):
			vol.remove_floating(null)
		var floating := float(Time.get_ticks_usec() - t3) / float(_RUNS)

		var c := trunk.global_transform * Vector3(trunk.axis_xz.x, 0.5, trunk.axis_xz.y)
		var t4 := Time.get_ticks_usec()
		for r in range(_RUNS):
			trunk.surface_along(c + Vector3.RIGHT * trunk.radius * 2.5,
				Vector3.LEFT, trunk.radius * 3.5)
		var march := float(Time.get_ticks_usec() - t4) / float(_RUNS)

		var known := remesh + stats_inc + floating + march
		print("%4d | %6.1f | %8.2f / %8.1f | %6.1f / %6.2f | %8.1f | %8.1f" % [
			n, total / 1000.0, remesh / 1000.0, whole / 1000.0, stats / 1000.0,
			stats_inc / 1000.0, floating / 1000.0, (float(total) - known) / 1000.0])
		await get_tree().process_frame

	print("")
	print("--- what the remainder is made of (100 reps each) ---")
	if _has(trunk):
		var t5 := Time.get_ticks_usec()
		for r in range(100):
			game._evaluate()
			trunk._sections_fresh = false
		var ev := float(Time.get_ticks_usec() - t5) / 100.0
		var t6 := Time.get_ticks_usec()
		for r in range(100):
			trunk._sections_fresh = false
			trunk.sections()
		var sec := float(Time.get_ticks_usec() - t6) / 100.0
		print("  _evaluate (incl. sections)     %6.2f ms" % (ev / 1000.0))
		print("  sections() alone               %6.2f ms" % (sec / 1000.0))
		print("  => load model minus sections   %6.2f ms" % ((ev - sec) / 1000.0))

		var t7 := Time.get_ticks_usec()
		for r in range(100):
			game._stick_mesh(0.018, 0.16)
		print("  _stick_mesh (one splinter mesh)%6.2f ms" % (
			float(Time.get_ticks_usec() - t7) / 100.0 / 1000.0))

		var t8 := Time.get_ticks_usec()
		var made: Array = []
		for r in range(100):
			made.append(game._spawn_chip(game._stick_mesh(0.018, 0.16),
				trunk.global_position + Vector3(0.0, 3.0, 0.0), 1.2))
		# INSIDE THE REMESH, which is now the dominant cost of a blow.
		var mats2 := _mats(trunk)
		var ta := Time.get_ticks_usec()
		for r in range(50):
			vol._rebuild_active()
		print("  _rebuild_active                %6.2f ms" % (
			float(Time.get_ticks_usec() - ta) / 50.0 / 1000.0))
		var tb := Time.get_ticks_usec()
		for r in range(50):
			vol._refresh_all()
		print("  _refresh_all (whole grid)      %6.2f ms" % (
			float(Time.get_ticks_usec() - tb) / 50.0 / 1000.0))
		var tc := Time.get_ticks_usec()
		for r in range(50):
			vol._emit(mats2[0], mats2[1])
		print("  _emit (walk + stitch + upload) %6.2f ms" % (
			float(Time.get_ticks_usec() - tc) / 50.0 / 1000.0))
		print("  active cells: %d" % vol._active.size())

		print("  _spawn_chip (mesh + body + hull)%5.2f ms  x ~12/blow = %.1f ms" % [
			float(Time.get_ticks_usec() - t8) / 100.0 / 1000.0,
			float(Time.get_ticks_usec() - t8) / 100.0 / 1000.0 * 12.0])
		# DOES IT GET WORSE AS DEBRIS PILES UP? The A12 budget is O(n) per spawn and
		# every settled piece stays tracked and stays in the scene, so this is the
		# "heavy when spam clicking" hypothesis, measured.
		print("")
		print("--- spawn cost vs. accumulated debris ---")
		print("  tracked | ms/spawn | physics frame ms")
		for batch in range(6):
			var t9 := Time.get_ticks_usec()
			for r in range(100):
				made.append(game._spawn_chip(game._stick_mesh(0.018, 0.16),
					trunk.global_position + Vector3(randf(), 3.0, randf()), 1.2))
			var per := float(Time.get_ticks_usec() - t9) / 100.0 / 1000.0
			var tf := Time.get_ticks_usec()
			for r in range(10):
				await get_tree().physics_frame
			var frame := float(Time.get_ticks_usec() - tf) / 10.0 / 1000.0
			print("  %7d | %8.2f | %8.2f" % [game._budget.tracked_count(), per, frame])

	print("")
	print("--- mesh size ---")
	var m: Mesh = trunk.band_mesh()
	var tris := 0
	var verts := 0
	for si in range(m.get_surface_count()):
		var arr := m.surface_get_arrays(si)
		verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("band mesh: %d verts, %d tris, %d surfaces" % [verts, tris, m.get_surface_count()])

	print("")
	print("--- what a WHOLE-TREE voxel grid would cost ---")
	var aabb: AABB = load("res://assets/models/trees_export/tree_01.fbx").get_aabb() \
		if false else _tree_aabb()
	for cell in [0.055, 0.07, 0.09, 0.12]:
		var half: float = maxf(aabb.size.x, aabb.size.z) * 0.5 + cell * 2.0
		var gx := int(ceil(half * 2.0 / cell)) + 1
		var gy := int(ceil(aabb.size.y / cell)) + 1
		print("  cell %.3f -> %dx%dx%d = %d samples (%.1fx the band's %d)" % [
			cell, gx, gy, gx, gx * gy * gx, float(gx * gy * gx) / float(vol.nx * vol.ny * vol.nz),
			vol.nx * vol.ny * vol.nz])
	print("  tree aabb: %.2f x %.2f x %.2f" % [aabb.size.x, aabb.size.y, aabb.size.z])
	print("=== FELLING PROFILE DONE ===")
	get_tree().quit()


func _has(trunk: TreeTrunk) -> bool:
	return trunk != null and is_instance_valid(trunk) and trunk.is_built()


func _tree_aabb() -> AABB:
	var scene: PackedScene = load("res://assets/models/trees_export/tree_01.fbx")
	var inst := scene.instantiate()
	var out := AABB()
	var first := true
	for mi in _meshes(inst):
		var a := mi.mesh.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	inst.queue_free()
	return out


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out


## The two materials TreeTrunk._remesh uses, pulled back off the meshed band.
func _mats(trunk: TreeTrunk) -> Array:
	var m: Mesh = trunk.band_mesh()
	var bark: Material = m.surface_get_material(0) if m.get_surface_count() > 0 else null
	var cut: Material = m.surface_get_material(1) if m.get_surface_count() > 1 else bark
	return [bark, cut]
