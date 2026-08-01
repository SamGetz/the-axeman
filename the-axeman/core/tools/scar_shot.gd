extends Node
## FILE: res://core/tools/scar_shot.gd
## ATTACHES TO: root Node of res://core/tools/scar_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS. Renders the mark a FAILED swing leaves, on each wood, because
## a scar is a purely visual promise: every check in m7a_acceptance can be green
## on a gouge that is invisible, floating off the bark, or the wrong colour.
##
## `debug_split_roll = 0` forces every swing to fail, so the log wears its scars
## instead of falling apart.

const OUT := "user://scar_shot"


func _ready() -> void:
	for species in [0, 2]:                     # oak (dark inside) and birch (pale)
		var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
		mg.debug_forced_species = species
		mg.debug_forced_mesh = 0
		mg.debug_split_roll = 0                # every swing bites, none go through
		add_child(mg)
		for i in range(20):
			await get_tree().process_frame
		_save("_%d_a_clean" % species)

		# Four swings around the face the camera is looking at.
		for k in range(4):
			mg.debug_swing_world(Plane(Vector3.BACK, 0.0), Vector3(0.0, -0.12 + 0.08 * k, 0.0))
			for i in range(3):
				await get_tree().process_frame
		_save("_%d_b_scarred" % species)
		print("  species %d: %d scars, next swing %.2f"
			% [species, mg.debug_scar_count(), mg.debug_split_chance()])
		var cam: Camera3D = mg.get_node("CameraPivot/Camera3D")
		print("    camera at %s, log aabb %s" % [cam.global_position, (mg._source_mesh as Mesh).get_aabb()])
		var log_piece: Node3D = mg.get_node("OnBlock").get_child(0)
		print("    log at %s" % log_piece.global_position)
		for c in log_piece.get_children():
			if c is MeshInstance3D and c.name != "Mesh":
				print("      scar at %s (local %s)" % [(c as Node3D).global_position, (c as Node3D).position])

		# ...and then one that goes through, so the cleave and the marks can be
		# compared side by side.
		mg.debug_split_roll = 1
		mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
		for i in range(30):
			await get_tree().process_frame
		_save("_%d_c_split" % species)

		mg.queue_free()
		await get_tree().process_frame

	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
