extends Node
## FILE: res://core/tools/scar_shot.gd
## ATTACHES TO: root Node of res://core/tools/scar_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS. Renders the mark a FAILED swing leaves, on each wood, because
## a scar is a purely visual promise: numeric checks can be green
## on a gouge that is invisible, floating off the bark, or the wrong colour.
##
## `debug_split_roll = 0` forces every swing to fail. The final capture then cuts
## beside those marks to prove their normal-map projections are rebuilt on the
## surviving descendant top geometry rather than queue-freed with the old mesh.

const OUT := "user://scar_shot"
const WIDTH_OPTIONS := [0.020, 0.025, 0.030]


func _ready() -> void:
	# Same species, mesh, camera, hit point and shader for every choice: only the
	# visible wound width changes, so side-by-side review is honest.
	for width_m: float in WIDTH_OPTIONS:
		var option: Node3D = load(
			"res://scenes/3d_action/chopping_minigame.tscn").instantiate()
		option.debug_forced_species = 0
		option.debug_forced_mesh = 0
		option.debug_split_roll = 0
		option.scar_width = width_m
		add_child(option)
		for i in range(90):
			await get_tree().process_frame
		option.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
		for i in range(3):
			await get_tree().process_frame
		_save("_pick_%dmm" % int(round(width_m * 1000.0)))
		option.queue_free()
		await get_tree().process_frame

	for species in [0, 2]:                     # oak (dark inside) and birch (pale)
		var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
		mg.debug_forced_species = species
		mg.debug_forced_mesh = 0
		mg.debug_split_roll = 0                # every swing bites, none go through
		add_child(mg)
		for i in range(90):
			await get_tree().process_frame
		_save("_%d_a_clean" % species)

		# One failed swing at the ordinary centre hit. A multi-scar capture made the
		# old review look more legible than the first failure actually is in play.
		mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
		for i in range(3):
			await get_tree().process_frame
		_save("_%d_b_single_scar" % species)
		print("  species %d: %d scars, next swing %.2f"
			% [species, mg.debug_scar_count(), mg.debug_split_chance()])
		var cam: Camera3D = mg.get_node("CameraPivot/Camera3D")
		print("    camera at %s, log aabb %s" % [cam.global_position, (mg._source_mesh as Mesh).get_aabb()])
		var log_piece: Node3D = mg.get_node("OnBlock").get_child(0)
		print("    log at %s" % log_piece.global_position)
		for c in log_piece.get_children():
			if c is MeshInstance3D and c.name != "Mesh":
				print("      scar at %s (local %s)" % [(c as Node3D).global_position, (c as Node3D).position])

		# ...and then one that goes through BESIDE the scar line. The projection
		# must remain on the descendant which still owns that part of the top.
		mg.debug_split_roll = 1
		mg.debug_swing_world(Plane(Vector3.RIGHT, 0.12))
		for i in range(30):
			await get_tree().process_frame
		_save("_%d_c_adjacent_split_persistent" % species)
		print("    after adjacent split: %d projections, %d pity scars"
			% [mg.debug_total_scar_projection_count(), mg.debug_total_scar_pity_count()])

		mg.queue_free()
		await get_tree().process_frame

	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
