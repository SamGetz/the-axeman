extends Node
## DEV TOOL (not shipped). Renders the M5 felling mini-game to PNGs so the
## geometry and the fall can be LOOKED at instead of guessed about. Run
## NON-headless:
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/tree_shot.tscn
##
## Output: %APPDATA%/Godot/app_userdata/the-axeman/tree_shot_*.png

const OUT := "user://tree_shot"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0   # pin: the shots are about the geometry, not the dice
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
	# The live scene clears the fall fast (fall_timeout/fade tuned for the game
	# loop); for the shots, let the trunk actually settle and lie there.
	game.fall_timeout = 20.0
	game.fade_delay = 5.0
	# PINNED exactly as m5_acceptance and felling_smoke pin them, and for the same
	# reason: these shots are about the MECHANIC, not about whatever Sam currently has
	# dialled into the .tscn. Sam's live `cut_span` is 0.50, which cannot fell a 0.94 m
	# trunk from one viewpoint at all (see the warning `_warn_cut_span` prints), so
	# without this the fall shots are of a tree that never comes down.
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await _wait(0.9)          # let the fresh tree finish bouncing in
	while game._animator.is_animating(game._trunk):
		await _wait(0.1)
	_save("_1_standing")

	# --- the face notch. Every blow on this side alternates roof/floor, so the
	# shots should show one continuous V opening in the fall side of the trunk.
	game.debug_blow(1, 0.5)
	await _wait(0.03)
	_save("_2a_first_blow")    # caught mid-spray, with the chip in the air
	await _wait(0.4)
	for i in range(3):
		game.debug_blow(1, 0.5)
		await _wait(0.35)
	_save("_2b_notch_started")
	while game.notch_depth() < 0.6 and not game.is_felling():
		game.debug_blow(1, 0.5)
		await _wait(0.3)
	_save("_3_notch")
	print("notch %.0f%% of the diameter, holding %.3f m2, stress %.2f" % [
		game.notch_depth() * 100.0, game.holding_wood(), game.last_stress()])

	# Close in on the notch in profile: it has to read as a real drop-notch —
	# a steep top cut, a flat bottom cut, meeting at an apex past the middle.
	var d0: float = game.cam_distance
	var h0: float = game.cam_height
	var f0: float = game.cam_focus_y
	game.cam_distance = 1.9
	game.cam_height = 0.55
	game.cam_focus_y = 0.42
	await _wait(1.2)
	_save("_3b_notch_profile")

	game.debug_swing_axe(1)
	await _wait(0.06)
	_save("_3c_axe")
	await _wait(0.5)

	# --- keep chopping the SAME cut until it goes.
	#
	# This drove blows at `side = -1` until 2026-07-30, which is stale by five days: PASS 6
	# (2026-07-25) removed the back cut, so a blow on the far side is no longer a back cut
	# eating toward the notch — it opens a SECOND independent notch on a face of its own.
	# Thirty of them left the tree standing with two half-notches, and every shot from here
	# down was quietly a picture of an upright tree (_5 through _9 came out byte-identical).
	# The tag is kept so these shots still line up with older ones.
	var blows := 0
	while not game.is_felling() and blows < 40:
		game.debug_blow(1, 0.5)
		blows += 1
		await _wait(0.3)
	_save("_4_back_cut")       # the hinge, in profile, right before it goes
	print("felled after %d back-cut blows: hinge %.3f m, holding %.4f m2, intact %s" % [
		blows, game.hinge_thickness(), game.holding_wood(), game.hinge_was_intact()])
	game.cam_distance = d0
	game.cam_height = h0
	game.cam_focus_y = f0

	# --- the fall. Attached and rotating on the hinge first, then free.
	await _wait(0.5)
	_save("_5_hinging")
	await _wait(1.0)
	_save("_6_going")
	await _wait(0.9)
	_save("_7_over")
	await _wait(1.4)
	_save("_8_down")
	print("tilt %.0f deg, hinging=%s physical=%s landed=%s chips=%d" % [
		game.fall_tilt_deg(), game.is_hinging(), game.is_falling_physically(),
		game.has_landed(), game.chip_count()])

	# The STUMP: it must end cleanly at the break, carved notch still visible,
	# no remnant plate standing on it.
	game.cam_distance = 1.9
	game.cam_height = 0.7
	game.cam_focus_y = 0.35
	await _wait(0.3)
	_save("_8b_stump")
	game.cam_distance = d0
	game.cam_height = h0
	game.cam_focus_y = f0
	await _wait(3.0)
	_save("_9_settled")
	print("landed=%s settled=%s" % [game.has_landed(), game.has_settled()])
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
