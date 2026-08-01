extends Node
## DEV TOOL. Renders the band and the crown SEPARATELY at the same camera, so the
## seam line can be attributed to one of them instead of guessed at.
## Run NON-headless:
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/seam_layers.tscn

const OUT := "user://layers"


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
	game.fade_delay = 30.0
	game.voxel_cell = 0.055
	add_child(game)
	await _wait(0.9)
	while game._animator.is_animating(game._trunk):
		await _wait(0.1)

	var trunk: TreeTrunk = game.trunk()
	var band: Node3D = trunk._band_mi
	var crown: MeshInstance3D = trunk._upper_mi
	print("band_lo %.4f  band_hi %.4f  crown_base %.4f  overlap %.4f (%.1f cells)" % [
		trunk.band_lo, trunk.band_hi, trunk._crown_base,
		trunk.band_hi - trunk._crown_base,
		(trunk.band_hi - trunk._crown_base) / trunk.volume().cell])
	print("band mesh aabb:  %s" % str(trunk.band_mesh().get_aabb()))
	print("crown mesh aabb: %s" % str(crown.mesh.get_aabb()))

	game.cam_distance = 2.2
	game.cam_height = trunk.band_hi + 0.15
	game.cam_focus_y = trunk.band_hi
	await _wait(0.6)
	_save("_a_both")

	crown.visible = false
	await _wait(0.3)
	_save("_b_band_only")

	crown.visible = true
	band.visible = false
	await _wait(0.3)
	_save("_c_crown_only")

	band.visible = true
	await _wait(0.3)
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
