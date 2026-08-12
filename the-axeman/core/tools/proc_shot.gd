extends Node
## FILE: res://core/tools/proc_shot.gd
## ATTACHES TO: root Node of res://core/tools/proc_shot.tscn. DEV TOOL,
## RUN NON-HEADLESS. Not shipped.
##
## Photographs M7C's named procs — RUN THIS ON ANY CHANGE TO Double Strike,
## Follow-Up, Quick Study, the proc resolver, or ProcBurst. m7c_acceptance
## proves the mechanics; only these PNGs prove each fired proc is visible and
## wears its authored branch colour in the real chopping scene.
##
## Drives the chopping scene DIRECTLY — no main.tscn/HUD needed. The
## announcement is a self-contained 3D VFX (ProcBurst) fired from inside the
## mini-game itself, not a scene-to-HUD signal, so there is nothing left to
## boot outside it.
##
## TIMED, NOT FRAME-COUNTED, for the mid-flight shot: ProcBurst frees itself
## after ~0.4s real time, so a frame-counted wait risks missing it entirely
## depending on frame pacing — the lesson orb_shot/axe_shot already paid for.
##
## Output: user://proc_shot_<tag>.png
## Run: "<godot>" --path . --quit-after 12000 res://core/tools/proc_shot.tscn

## The chopping scene's script has no class_name; a preloaded-script const is
## how this project statically types it elsewhere too (m7c_acceptance.gd).
const _ChoppingMinigame := preload("res://scenes/3d_action/chopping_minigame.gd")
const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")

const OUT := "user://proc_shot"


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var mg: _ChoppingMinigame = _SCENE.instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1      # the primary swing always cleaves — shooting the proc, not the roll
	mg.debug_force_proc = 1      # Double Strike always fires when it is rolled at all
	mg.auto_sell = false
	mg.orbs_enabled = false      # confetti in front of the thing being photographed
	add_child(mg)
	for i in range(10):
		await get_tree().process_frame

	# Grant through the complete CURRENT branch path and real public purchase API.
	# The old tool bought only the former root + proc and silently photographed
	# zero procs after the 12-node branch overhaul.
	_grant_strength_path()

	# --- A: the real Double Strike — two cuts, one swing, the Strength burst ---
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(150)   # catch ProcBurst mid-flight, well inside its ~0.4s life
	print("A double_strike: cuts=%d pieces=%d burst_color=%s"
		% [mg.debug_last_double_strike_cuts(), mg.piece_count(), mg.debug_last_proc_burst_color()])
	_save("_1_double_strike_burst_mid_flight")
	for i in range(20):
		await get_tree().process_frame
	_save("_1b_double_strike_settled")

	# --- B: invalid-chain stop — nothing useful left to continue onto ---
	mg.min_vol = 1000.0   # every piece, however large, reads as firewood
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("B no_geometry: cuts=%d cuttable=%d"
		% [mg.debug_last_double_strike_cuts(), mg.cuttable_count()])
	_save("_2_no_geometry_no_bonus_cut")
	mg.min_vol = 0.018   # restore the shipping default

	# --- C: precision suppression — owned, forced, but the player guarded ---
	mg.debug_set_precision_guard(true)
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("C precision_suppressed: cuts=%d (guard on, no modifier)" % mg.debug_last_double_strike_cuts())
	_save("_3_precision_suppressed")

	# --- D: Steady Continuation makes it safe again, guard still on ---
	SkillTree.buy(&"steady_continuation")
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(150)
	print("D precision_safe_with_modifier: cuts=%d burst_color=%s (guard on, WITH Steady Continuation)"
		% [mg.debug_last_double_strike_cuts(), mg.debug_last_proc_burst_color()])
	_save("_4_precision_safe_with_modifier")
	await _wait_ms(750)

	# --- E: Quick Study — ONE manual completed log, multiplied XP, Technique burst ---
	_grant_mastery_path()
	mg.debug_set_precision_guard(false)
	mg.min_vol = 1000.0   # one swing completes this log; no Double Strike geometry remains
	mg.auto_sell = true
	mg.orbs_enabled = true
	mg._spawn_fresh_log()
	for i in range(6):
		await get_tree().process_frame
	await _wait_ms(500)   # let the spawn smoke clear; this frame judges XP + ProcBurst
	var xp_before := GameState.get_xp()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(240)   # Mastery rises rather than punches; judge it after the cloud opens.
	print("E quick_study: xp_delta=%d bonus=%d root=%s burst_color=%s"
		% [GameState.get_xp() - xp_before, mg.debug_last_quick_study_bonus(),
			mg.debug_last_quick_study_root_id(), mg.debug_last_proc_burst_color()])
	_save("_5_quick_study_xp_burst")
	await _wait_ms(3800)   # Even the last staggered XP orb must clear before Speed's proof shot.

	# --- F: Follow-Up — a bonus SWING, not a bonus cut; Speed's own blue burst ---
	# debug_swing_world (not debug_slice_world) is used deliberately here — it is
	# the seam that goes through the real roll, and Follow-Up is called from
	# inside _resolve_strike specifically so this exact seam exercises it (see
	# _resolve_strike's doc comment).
	_grant_speed_path()
	mg.min_vol = 0.018   # restore the shipping default (E raised it)
	mg.auto_sell = false
	mg.orbs_enabled = false
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(120)   # tight opening fan, still visibly rooted between the wedges
	print("F follow_up: swings=%d pieces=%d burst_color=%s"
		% [mg.debug_last_follow_up_swings(), mg.piece_count(), mg.debug_last_proc_burst_color()])
	_save("_6_follow_up_burst_mid_flight")
	await _wait_ms(120)   # later checkpoint proves the shortened particles never tower over the wood
	_save("_6c_follow_up_burst_late")
	for i in range(20):
		await get_tree().process_frame
	_save("_6b_follow_up_settled")

	mg.queue_free()
	await get_tree().process_frame
	print("=== proc_shot: done ===")
	get_tree().quit()


func _wait_ms(ms: int) -> void:
	var t0 := float(Time.get_ticks_msec())
	while (float(Time.get_ticks_msec()) - t0) < float(ms):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)


func _grant_strength_path() -> void:
	_reset_with_points()
	_buy_ranks(&"strong_arms", 5)
	_buy_ranks(&"deep_bite", 5)
	_buy_ranks(&"hardwood_training", 5)
	_buy_ranks(&"driving_force", 1)
	_buy_ranks(&"double_strike", 1)


func _grant_mastery_path() -> void:
	_reset_with_points()
	_buy_ranks(&"lessons_learned", 5)
	_buy_ranks(&"studied_practice", 5)
	_buy_ranks(&"balanced_growth", 5)
	_buy_ranks(&"broad_experience", 1)
	_buy_ranks(&"quick_study", 1)


func _grant_speed_path() -> void:
	_reset_with_points()
	_buy_ranks(&"quick_hands", 5)
	_buy_ranks(&"ready_stance", 5)
	_buy_ranks(&"efficient_motion", 5)
	_buy_ranks(&"fast_reset", 1)
	_buy_ranks(&"work_rhythm", 1)
	_buy_ranks(&"follow_up", 1)


func _reset_with_points() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(64))


func _buy_ranks(skill_id: StringName, count: int) -> void:
	for expected_level in range(1, count + 1):
		var bought := SkillTree.buy(skill_id)
		assert(bought == expected_level,
			"proc_shot setup could not buy %s rank %d (got %d)" % [
				skill_id, expected_level, bought])
