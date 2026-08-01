extends Node
## DEV TOOL (not shipped). The FOOT of a tree, before and after the voxel band
## replaces it, and after cuts at two heights. This is the tool for "the roots
## disappear" and "the bark tears" — both are things you can only see.
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/butt_shot.tscn
##
## Output: %APPDATA%/Godot/app_userdata/the-axeman/butt_*.png

const OUT := "user://butt"

@export var species := 1     # 0 = tree_02, 1 = tree_01


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	var forced := species
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("species="):
			forced = int(arg.split("=")[1])
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = forced
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.tree_count = 1
	game.trunk_persists = false
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await _wait(0.9)
	var guard := 0
	while game._animator.is_animating(game._trunk) and guard < 60:
		guard += 1
		await _wait(0.1)

	var t: TreeTrunk = game.debug_nearest_tree()
	print("species %d  radius %.3f  band %.3f..%.3f  crown_base %.3f  preview=%s" % [
		forced, t.radius, t.band_lo, t.band_hi, t.crown_base(), str(t.is_preview())])

	# The butt, framed tight, while the tree is still its imported mesh.
	game.cam_distance = 5.0
	game.cam_height = 1.6
	game.cam_focus_y = 1.4
	await _wait(0.6)
	_save("_1_preview_imported")

	# One blow builds the voxel band. Aim LOW so the shot is about the swap, not the cut.
	game.debug_blow(1, 0.15)
	await _wait(0.6)
	_save("_2_built_lowcut")
	print("  after build: preview=%s  band %.3f..%.3f  crown_base %.3f" % [
		str(t.is_preview()), t.band_lo, t.band_hi, t.crown_base()])

	# Cuts at eye height — where the player actually aims (absolute local metres).
	for i in range(6):
		game.debug_blow(1, 1.65)
		await _wait(0.25)
	_save("_3_eye_height_cuts")

	# ...and high up, where Sam reports it will not cut.
	var high: float = game.debug_max_cut_height(t) - 0.1
	print("  high cut at %.2f m (max %.2f)" % [high, game.debug_max_cut_height(t)])
	for i in range(6):
		game.debug_blow(1, high)
		await _wait(0.25)
	_save("_4_high_cuts")
	print("  notch %.0f%%  removed %.4f m3  cuts %d" % [
		game.notch_depth() * 100.0, t.removed_volume(), t.cut_count()])

	# Right in on the bark, for the tearing.
	game.cam_distance = 1.6
	game.cam_height = 0.55
	game.cam_focus_y = 0.45
	await _wait(0.8)
	_save("_5_bark_closeup")
	game.cam_focus_y = 0.12
	game.cam_height = 0.35
	await _wait(0.6)
	_save("_6_roots_closeup")
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
