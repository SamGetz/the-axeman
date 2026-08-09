extends Node
## Compatibility-render review for the four exact mixed cash representations.

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")


func _ready() -> void:
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.auto_sell = false
	add_child(game)
	for _frame in range(20):
		await get_tree().process_frame
	var pool: CoinRewardPool = game.get_node("CoinRewardPool")
	for sample: Array in [["coin", 8], ["green_note", 500],
			["blue_note", 5000], ["bundle", 50000]]:
		var origin := Vector3(0.0, 0.66, 0.0)
		pool.begin_burst(origin, 1, 0.025, 0.4, 1.15, 0.025)
		pool.queue_payout(int(sample[1]))
		var started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 280:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "/private/tmp/axeman_reward_cash_%s.png" % String(sample[0])
		get_viewport().get_texture().get_image().save_png(path)
		print("CASH REWARD SHOT: %s amount=%d -> %s" % [sample[0], sample[1], path])
		while Time.get_ticks_msec() - started < 1900:
			await get_tree().process_frame
	print("=== CASH REWARD TIER SHOT COMPLETE ===")
	get_tree().quit()
