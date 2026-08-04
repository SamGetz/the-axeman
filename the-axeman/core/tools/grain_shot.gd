extends Node
## Non-headless visual proof for Technique's grain opportunity.
##
## REWORKED 2026-08-04 (Creative Director call): the cue is no longer an
## ephemeral bracket/diamond overlay that pops for ~150ms and forces a camera
## turn on exactly the pieces most likely to need one. It is now a PERMANENT
## glowing gold line on the wood itself — three raised world-space layers, no
## screen-space UI at all — occasionally offered, that cuts without a forced
## turn and pays a big XP bonus plus a Technique-green ProcBurst when taken.
## This tool renders: the mark on dark and pale bark, its glow at both ends of
## its pulse, cleanup after an invalidated candidate, and the reward moment.

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
		mg.debug_hold_grain_cue()
		await get_tree().process_frame
		print("grain species %d: valid=%s marks=%d color=%s"
			% [species, mg.debug_grain_plane_valid(), mg.debug_grain_top_mark_count(),
				mg.debug_grain_cue_color()])
		await _save("_%d_gold_glow_dark_core" % species)

		# The glow breathes — one shot near each end of its pulse so the tuning
		# pass can actually see the range, not just a single frozen frame.
		var grain_cfg: GrainCueDef = load("res://data/grain_cue.tres")
		await _wait_ms(int(round(float(grain_cfg.glow_pulse_period_sec) * 500.0)))
		await _save("_%d_gold_glow_pulsed" % species)

		if species == 0:
			mg.debug_invalidate_grain_candidate()
			await get_tree().process_frame
			await _save("_%d_invalid_cleanup" % species)

			# THE REWARD: force a fresh mark, take it, and shoot the moment right
			# after — the Technique-green ProcBurst plus the XP orb eruption from
			# the cut point. Orbs are switched on only for this shot; every other
			# pass in this tool keeps them off like the rest of the render tools.
			mg._spawn_fresh_log()
			await get_tree().process_frame
			mg.debug_hold_grain_cue()
			await get_tree().process_frame
			mg.orbs_enabled = true
			var target: Area3D = mg._grain_target
			if target != null:
				mg._resolve_strike(target, target.global_position, Vector3.RIGHT,
					Enums.ChopDirection.RIGHT, mg._grain_local_plane)
			await get_tree().process_frame
			print("grain reward: bonus=%d burst_color=%s clear_reason=%s"
				% [mg.debug_last_grain_bonus(), mg.debug_last_proc_burst_color(),
					mg.debug_grain_clear_reason()])
			await _save("_%d_reward_burst_and_orbs" % species)

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
