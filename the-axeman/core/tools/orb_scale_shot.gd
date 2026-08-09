extends Node
## Compatibility-render review for the shared logarithmic XP burst: routine,
## medium, large and capped/jackpot use one count function and one warmed pool.

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")


func _ready() -> void:
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.auto_sell = false
	add_child(game)
	for _frame in range(20):
		await get_tree().process_frame
	for sample: Array in [["small", 5], ["medium", 500], ["large", 3325],
			["capped_jackpot", 250000]]:
		game._burst_xp_orbs(int(sample[1]))
		var started := Time.get_ticks_msec()
		# After the authored stagger has released even the 32nd pooled orb, while
		# the wave is still bouncing around the stump rather than already drawing.
		while Time.get_ticks_msec() - started < 480:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "user://orb_scale_%s.png" % String(sample[0])
		get_viewport().get_texture().get_image().save_png(path)
		print("ORB SCALE SHOT: %s XP=%d count=%d -> %s" % [
			sample[0], sample[1], game.xp_pacing_config.orb_count_for_xp(sample[1]),
			ProjectSettings.globalize_path(path)])
		while Time.get_ticks_msec() - started < 1900:
			await get_tree().process_frame
	game.present_level_gain(2)
	var level_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - level_started < 320:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var level_path := "/private/tmp/axeman_level_up_no_ground_halo.png"
	get_viewport().get_texture().get_image().save_png(level_path)
	print("LEVEL-UP SHOT: rays/sparks without ground halo -> %s" % level_path)
	print("=== orb_scale_shot: done ===")
	get_tree().quit()
