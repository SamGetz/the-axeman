extends Node
## DEV TOOL (not shipped). Renders the BAND/CROWN JOIN close up, so the reported
## "the voxel area and the non-voxel area look disconnected" can be looked at
## rather than guessed about. Run NON-headless:
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/seam_shot.tscn
##
## Output: %APPDATA%/Godot/app_userdata/the-axeman/seam_*.png

const OUT := "user://seam"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


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
	game.fall_timeout = 20.0
	game.fade_delay = 20.0
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await _wait(0.9)
	while game._animator.is_animating(game._trunk):
		await _wait(0.1)

	var trunk: TreeTrunk = game.trunk()
	print("band %.3f .. %.3f  crown base %.3f  radius %.3f  height %.2f" % [
		trunk.band_lo, trunk.band_hi, trunk._crown_base, trunk.radius, trunk.height])

	# Whole tree, so the band/crown boundary can be seen in context.
	game.cam_distance = 6.0
	game.cam_height = 3.2
	game.cam_focus_y = 3.0
	await _wait(0.6)
	_save("_1_whole")

	# Right at the join.
	game.cam_distance = 2.2
	game.cam_height = trunk.band_hi + 0.15
	game.cam_focus_y = trunk.band_hi
	await _wait(0.6)
	_save("_2_join_close")

	# Same framing, a little wider, so the bark run above and below is comparable.
	game.cam_distance = 3.4
	game.cam_height = trunk.band_hi
	game.cam_focus_y = trunk.band_hi
	await _wait(0.6)
	_save("_3_join_wide")

	# Lower down the band, uncut — for comparison against the join.
	game.cam_distance = 3.4
	game.cam_height = trunk.band_hi * 0.4
	game.cam_focus_y = trunk.band_hi * 0.4
	await _wait(0.6)
	_save("_4_band_only")

	# And after chopping, with the tree leaning: this is when Sam saw it worst.
	for i in range(7):
		game.debug_blow(1, 0.5)
		await _wait(0.3)
	print("after 7 blows: notch %.0f%%, stress %.2f, lean %.2f deg" % [
		game.notch_depth() * 100.0, game.last_stress(), game.lean_deg()])
	game.cam_distance = 2.2
	game.cam_height = trunk.band_hi + 0.15
	game.cam_focus_y = trunk.band_hi
	await _wait(0.8)
	_save("_5_join_leaning")

	game.cam_distance = 6.0
	game.cam_height = 3.2
	game.cam_focus_y = 3.0
	await _wait(0.6)
	_save("_6_whole_leaning")
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
