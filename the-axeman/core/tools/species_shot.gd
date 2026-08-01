extends Node
## FILE: res://core/tools/species_shot.gd
## ATTACHES TO: the root Node of res://core/tools/species_shot.tscn.
##
## DEV TOOL — RUN NON-HEADLESS. Renders every row of chopping_minigame's
## _LOG_SPECIES table: the log standing fresh on the block, and again after two
## cuts so the CUT FACE (which is generated at runtime, not authored on the FBX)
## can be judged too.
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


func _ready() -> void:
	# Read the table off a probe instance that is never added to the tree, so its
	# _ready never runs and nothing is built. Constants are not readable off the
	# GDScript resource directly.
	var probe: Node = _SCENE.instantiate()
	var species: Array = probe._LOG_SPECIES
	probe.free()
	print("=== species_shot: %d species in the table ===" % species.size())

	for i in range(species.size()):
		var row: Dictionary = species[i]
		var game: Node = _SCENE.instantiate()
		game.debug_forced_species = i
		add_child(game)
		for f in range(30):
			await get_tree().process_frame

		var mesh: Mesh = game._source_mesh
		var size: Vector3 = mesh.get_aabb().size if mesh != null else Vector3.ZERO
		print("[%d] %s -> %s | on-block log aabb=%s" % [
			i, String(row.get("mesh", "?")).get_file(), row.get("yield_item", "?"), size,
		])
		await _save("%d_fresh" % i)

		# Two cuts, so both a fresh cut face and a re-cut piece are on screen.
		game.debug_slice_world(Plane(Vector3.RIGHT, 0.05))
		for f in range(8):
			await get_tree().process_frame
		game.debug_slice_world(Plane(Vector3.FORWARD, 0.04))
		for f in range(45):
			await get_tree().process_frame
		await _save("%d_cut" % i)

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
