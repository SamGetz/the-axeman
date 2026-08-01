extends Node
## DEV TOOL (not shipped). Renders the STAND to PNGs so the forest can be LOOKED at —
## spacing, the tiled ground, the horizon, and whether 25 trees read as a forest or as one
## tree stamped 25 times. Run NON-headless:
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/forest_shot.tscn
##
## Output: %APPDATA%/Godot/app_userdata/the-axeman/forest_shot_*.png

const OUT := "user://forest_shot"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	# Match the shipping forest: show every registered visual tree type.
	game.debug_forced_species = -1
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	# Match the shipping forest: the clean trunk remains on the ground for bucking.
	game.trunk_persists = true
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	game.tree_count = 25
	game.forest_radius = 25.0
	add_child(game)
	await _wait(1.5)

	# EYE LEVEL, standing where the player spawns. This is the shot that answers "does it
	# read as a forest", and it is the only one that matters at first.
	# LEVEL, not pitched down: the dev camera aims at `cam_focus_y`, so an eye-level look has
	# to focus at eye height. Focusing lower points it at the dirt, which is what the first
	# version of this shot did.
	game.cam_distance = 0.6
	game.cam_height = 1.65
	game.cam_focus_y = 1.65
	await _save("_1_from_the_spawn")
	game.dev_camera_yaw_deg = 90.0
	await _save("_2_looking_across")
	game.dev_camera_yaw_deg = 200.0
	await _save("_3_the_other_way")

	# Backed off and raised: the stand's shape, the spacing, and how far the tiled ground
	# actually reaches before the horizon.
	game.dev_camera_yaw_deg = 0.0
	game.cam_distance = 34.0
	game.cam_height = 9.0
	game.cam_focus_y = 4.0
	await _save("_4_the_whole_stand")

	# Down at a trunk, to confirm a tree in a forest still looks like the tree M5 shipped.
	var t: TreeTrunk = game.debug_nearest_tree()
	game.debug_stand_at_tree(t, 3.0, 0.7)
	await _save("_5_at_a_trunk")
	var landed := 0
	for i in range(8):
		if game.debug_chop_tree(t, 1, 0.5):
			landed += 1
		await _wait(0.25)
	print("chopped the nearest tree: %d of 8 blows landed, notch %.0f%% of the diameter, holding %.3f m2" % [
		landed, game.notch_depth() * 100.0, game.holding_wood()])
	# Framed on the CUT, not on the tree: a notch 0.5 m up a 7.7 m trunk seen from 3 m away
	# is a few pixels, which is how the first version of this shot managed to look identical
	# to the one before the chopping.
	game.debug_stand_at_tree(t, 1.7, 0.5)
	game.cam_height = 0.9
	await _save("_6_notched_in_the_forest")

	# FELL IT AND BUCK IT, in the forest, and look at what is on the ground. This is the shot
	# for the min-log-size rule: bucked lengths have to read as LOGS, not coins.
	for i in range(40):
		if game.is_felling():
			break
		game.debug_chop_tree(t, 1, 0.5)
		await _wait(0.2)
	# The canopy is now its own fading leaf mesh while the branch-free timber
	# starts over on the hinge. Frame the whole tree so this transition can be
	# visually regression-checked under the Compatibility renderer.
	game.debug_stand_at_tree(t, 12.0, 4.0)
	game.cam_height = 4.0
	game.cam_focus_y = 4.0
	await _save("_6b_canopy_shedding")
	for i in range(80):
		await _wait(0.25)
		if game.is_bucking():
			break
	print("felled in the forest; bucking=%s" % game.is_bucking())
	game.debug_stand_at_tree(t, 5.0, 0.6)
	game.cam_height = 2.2
	await _save("_7_felled_in_the_forest")
	if game.is_bucking():
		var cuts := 0
		while cuts < 20:
			var idx: int = game.debug_next_bucking_log()
			if idx < 0:
				break
			for b2 in range(game.buck_blows):
				game.debug_buck(idx)
				await _wait(0.05)
			cuts += 1
			await _wait(0.2)
		var lens: Array = game.debug_log_lengths()
		var shortest := INF
		for l in lens:
			shortest = minf(shortest, l as float)
		print("bucked into %d lengths in %d cuts; shortest %.2f m (minimum %.2f, target %d logs)" % [
			lens.size(), cuts, shortest, game.min_log_length(), game.buck_target_logs])
		game.debug_stand_at_tree(t, 4.0, 0.4)
		game.cam_height = 1.8
		await _save("_8_bucked_into_logs")

	# THE LOGS FLYING TO THE PLAYER, and the STUMP left behind. Sam, 2026-07-27. A scripted
	# animation is exactly the sort of thing a headless check cannot judge, so it gets shots.
	game.debug_stand_at_tree(t, 6.0, 0.8)
	game.cam_height = 1.7
	game.cam_focus_y = 1.4
	var launched := false
	for i in range(40):
		var idx2: int = game.debug_next_bucking_log()
		if idx2 < 0:
			break
		for b3 in range(game.buck_blows):
			game.debug_buck(idx2)
			await _wait(0.03)
		await _wait(0.1)
	# Catch them mid-air: three frames spread across the flight.
	for shot in range(3):
		if game.logs_in_flight() > 0:
			launched = true
			await _save("_8b_logs_in_flight_%d" % shot)
		await _wait(0.16)
	print("logs launched=%s; still in flight %d" % [launched, game.logs_in_flight()])
	for i in range(60):
		await _wait(0.1)
		if game.logs_in_flight() == 0:
			break
	for i in range(60):
		await _wait(0.1)
		if game.stump_count() > 0:
			break
	print("stumps standing: %d" % game.stump_count())
	game.debug_stand_at(0.0, 3.4, 0.5)
	game.cam_height = 1.5
	await _save("_8c_the_stump_remains")

	# THE SETTLED-DEBRIS PILES, drawn. Their transforms cannot be read back headlessly (the
	# storage lives in a stubbed RenderingServer), so this render IS the check that the
	# MultiMesh actually puts the splinters where they fell rather than in a heap at the origin.
	game.max_debris = 8
	var others: Array = game.debug_trees()
	var did := 0
	var last_chopped: TreeTrunk = null
	for other in others:
		var ot: TreeTrunk = other
		if ot == null or not is_instance_valid(ot) or ot.has_broken() or did >= 3:
			continue
		did += 1
		last_chopped = ot
		for i in range(3):
			game.debug_chop_tree(ot, 1, 0.5)
			await _wait(0.2)
		await _wait(1.2)
	var gpu: Array = game.debug_pile_gpu()
	print("baked %d splinters into %d pile(s) | in the MultiMesh: %d instances, %d visible, %d placed away from the origin, furthest %.1f m" % [
		game.settled_debris_count(), game.settled_pile_count(), gpu[0], gpu[1], gpu[2], gpu[3]])
	# Framed low and close on the LAST tree chopped, because splinters are 2 cm sticks and a
	# wide shot of a forest cannot show whether they are in the right place.
	if last_chopped != null:
		game.debug_stand_at_tree(last_chopped, 2.4, 0.15)
		game.cam_height = 1.1
		await _save("_9_debris_piles")

	print("=== FOREST SHOT DONE ===")
	get_tree().quit()


func _save(tag: String) -> void:
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("saved " + tag)
