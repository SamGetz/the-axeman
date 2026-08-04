extends Node
## Non-headless visual proof for Technique's grain opportunity. It renders the
## real chopping scene on dark and pale wood, with the always-on accessible
## dark/light/core top mark and non-colour bracket/diamond, then photographs
## cleanup after invalidation, settle and split.

const OUT := "user://grain_shot"
const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var curve := load("res://data/level_curve.tres") as LevelCurve
	GameState.add_xp(curve.total_xp_for_level(4))
	SkillTree.buy(&"quick_study")

	for species: int in [0, 2]:
		var mg: Node3D = _SCENE.instantiate()
		mg.debug_forced_species = species
		mg.debug_forced_mesh = 0
		mg.debug_split_roll = 1
		mg.debug_force_proc = 1
		mg.auto_sell = false
		mg.orbs_enabled = false
		add_child(mg)
		for i in range(3):
			await get_tree().process_frame
		mg.debug_hold_grain_cue(2000.0)
		await get_tree().process_frame
		print("grain species %d: valid=%s marks=%d overlay=%s color=%s"
			% [species, mg.debug_grain_plane_valid(), mg.debug_grain_top_mark_count(),
				mg.debug_grain_overlay_visible(), mg.debug_grain_cue_color()])
		await _save("_%d_accessible_dark_light_core" % species)

		if species == 0:
			mg.debug_invalidate_grain_candidate()
			await get_tree().process_frame
			await _save("_%d_invalid_cleanup" % species)

			mg._spawn_fresh_log()
			await get_tree().process_frame
			await _wait_ms(700)
			print("grain settle cleanup: cue=%s reason=%s"
				% [mg.debug_has_grain_cue(), mg.debug_grain_clear_reason()])
			await _save("_%d_settle_cleanup" % species)

			mg._spawn_fresh_log()
			await get_tree().process_frame
			mg.min_vol = 1000.0
			mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
			await get_tree().process_frame
			print("grain split cleanup: cue=%s reason=%s"
				% [mg.debug_has_grain_cue(), mg.debug_grain_clear_reason()])
			await _save("_%d_split_cleanup" % species)

		mg.queue_free()
		await get_tree().process_frame

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== grain_shot: done ===")
	get_tree().quit()


func _wait_ms(ms: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < ms:
		await get_tree().process_frame


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
