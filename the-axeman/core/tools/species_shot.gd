extends Node
## FILE: res://core/tools/species_shot.gd
## ATTACHES TO: the root Node of res://core/tools/species_shot.tscn.
##
## DEV TOOL — RUN NON-HEADLESS. Renders every row of res://data/species_table.tres:
## the log standing fresh on the block, and again after two cuts so the CUT FACE
## (which is generated at runtime, not authored on the FBX) can be judged too.
##
## SINCE 2026-08-02 THIS IS ALSO THE ONLY WAY TO JUDGE `bark_tint`. 22 of the 25
## woods have no art of their own and wear tinted oak, and whether a tint reads as
## "a different wood" or as "oak with a filter on it" is not a thing any number
## can answer. Run it on any tint change, not only on an art drop.
##
## This exists because a new log mesh can pass every numeric check and still be
## wrong on screen — the 14 m log, the wrongly-rotated cut plane and the
## see-through geometry were all invisible to the suites and obvious in a PNG.
## A species drop is exactly that class of change: the mesh normalises to
## `log_height` whatever it was exported at, so a bad import looks fine in
## numbers.
##
## Output: user://species_shot_<index>_<stage>.png
## (Windows: %APPDATA%\Godot\app_userdata\<project>\)

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")

## Ladder indices to shoot, or an empty array for the whole table. 25 woods across
## their authored shapes is 124 PNGs, which is a fine thing to have after an art
## drop and a poor thing to sit through after a tint tweak.
const _ONLY_SPECIES: Array[int] = []
## Shoot only each species' FIRST authored shape. The right setting when the
## question is "does this wood read as its own wood" (one shape answers that);
## turn it off when the question is "did this import land", which is per mesh.
const _FIRST_MESH_ONLY := false


func _ready() -> void:
	# The table is a Resource now (res://data/species_table.tres), so it is read
	# straight off SpeciesTable — no probe instance needed. It used to have to be
	# lifted off a never-added-to-the-tree scene instance, because a const is not
	# readable off the GDScript resource.
	var species := SpeciesTable.all()
	print("=== species_shot: %d species in the table ===" % species.size())

	for i in range(species.size()):
		if not _ONLY_SPECIES.is_empty() and not _ONLY_SPECIES.has(i):
			continue
		var row := species[i]
		var meshes := row.meshes
		var shapes := 1 if _FIRST_MESH_ONLY else meshes.size()
		for m in range(shapes):
			var game: Node = _SCENE.instantiate()
			game.debug_forced_species = i
			game.debug_forced_mesh = m
			add_child(game)
			for f in range(30):
				await get_tree().process_frame

			var mesh: Mesh = game._source_mesh
			var size: Vector3 = mesh.get_aabb().size if mesh != null else Vector3.ZERO
			print("[%d.%d] %s | %s -> %s | on-block log aabb=%s" % [
				i, m, String(meshes[m]).get_file(), row.display_name, row.yield_item, size,
			])
			await _save("%d_%d_fresh" % [i, m])

			# Two cuts, so both a fresh cut face and a re-cut piece are on screen.
			game.debug_slice_world(Plane(Vector3.RIGHT, 0.05))
			for f in range(8):
				await get_tree().process_frame
			game.debug_slice_world(Plane(Vector3.FORWARD, 0.04))
			for f in range(45):
				await get_tree().process_frame
			await _save("%d_%d_cut" % [i, m])

			game.queue_free()
			for f in range(5):
				await get_tree().process_frame

	print("=== species_shot: done ===")
	get_tree().quit()


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://species_shot_%s.png" % tag
	img.save_png(path)
	print("  SHOT %s -> %s" % [tag, ProjectSettings.globalize_path(path)])
