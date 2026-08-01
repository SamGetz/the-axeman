extends Node
## DEV TOOL (not shipped). AUDIT THE SPECIES TABLE AGAINST THE FBX THAT IS ON DISK.
##
##   godot --headless --path . --quit-after 3000 res://core/tools/tree_surfaces.tscn
##
## Prints every surface of every declared tree type — material name, vertex count,
## height range — and marks each one TRUNK, canopy, or UNDECLARED.
##
## RUN THIS AFTER ANY TREE IS RE-EXPORTED. `_TREE_SPECIES` in tree_felling.gd names
## surfaces BY INDEX, and nothing infers them — an FBX that gains or reorders a surface
## silently invalidates its row. That has now bitten twice, the same way both times: an
## UNDECLARED surface is treated as WOOD, so it is copied into `WoodyCrown`, stays bolted
## to the felled trunk for good instead of despawning on landing, is measured as
## structural crown mass by the load model, and goes through the bucking slicer.
##   - tree_02 gained a third surface while its row still said `[1]`: its leaves were
##     counted as load and it failed on the opening blow.
##   - tree_01 was re-exported with a separate leaf material on 2026-07-29 and its row
##     still said `[1]`: 6,208 leaf vertices stayed on the felled trunk, which is Sam's
##     "when the leaves touch the ground they arent despawning".
## Both were one row of the table, and neither is findable by looking at the game.

func _ready() -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.player_controlled = false
	game.tree_count = 1
	add_child(game)
	await get_tree().process_frame
	var undeclared := 0
	for row in game.debug_species_catalog():
		var mesh := MeshUtils.mesh_from_path(row.model)
		print("\n=== %s  (%s)" % [row.id, row.model])
		print("  declared trunk_surface %s  canopy_surfaces %s" % [
			str(row.get("trunk_surface", -1)), str(row.get("canopy_surfaces", []))])
		if mesh == null:
			print("  MESH FAILED TO LOAD")
			continue
		for si in range(mesh.get_surface_count()):
			var mat := mesh.surface_get_material(si)
			var verts: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			var lo := INF
			var hi := -INF
			for v in verts:
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			var role := "TRUNK"
			if si != int(row.get("trunk_surface", -1)):
				if si in row.get("canopy_surfaces", []):
					role = "canopy"
				else:
					role = "*** UNDECLARED — will be treated as WOOD ***"
					undeclared += 1
			print("  surf %d  %-28s verts %6d  y %6.2f..%6.2f   %s" % [
				si, (mat.resource_name if mat != null else "<none>"), verts.size(),
				lo, hi, role])
	print("\n%s" % ("EVERY SURFACE IS DECLARED" if undeclared == 0
		else "*** %d UNDECLARED SURFACE(S) — fix _TREE_SPECIES in tree_felling.gd ***"
			% undeclared))
	get_tree().quit()
