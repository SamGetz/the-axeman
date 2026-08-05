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

	# Grant Double Strike through the REAL GameState.add_xp + SkillTree.buy path
	# — never a direct state poke — so this shoots exactly what a player could
	# actually earn.
	var curve := load("res://data/level_curve.tres") as LevelCurve
	GameState.add_xp(curve.total_xp_for_level(7))
	SkillTree.buy(&"strong_arms")
	SkillTree.buy(&"double_strike")

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

	# --- E: Quick Study — ONE manual completed log, multiplied XP, Technique burst ---
	var curve2 := load("res://data/level_curve.tres") as LevelCurve
	var quick_target := curve2.total_xp_for_level(10)
	if GameState.get_xp() < quick_target:
		GameState.add_xp(quick_target - GameState.get_xp())
	SkillTree.buy(&"quick_study")
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
	await _wait_ms(150)
	print("E quick_study: xp_delta=%d bonus=%d root=%s burst_color=%s"
		% [GameState.get_xp() - xp_before, mg.debug_last_quick_study_bonus(),
			mg.debug_last_quick_study_root_id(), mg.debug_last_proc_burst_color()])
	_save("_5_quick_study_xp_burst")

	# --- F: Follow-Up — a bonus SWING, not a bonus cut; Speed's own blue burst ---
	# debug_swing_world (not debug_slice_world) is used deliberately here — it is
	# the seam that goes through the real roll, and Follow-Up is called from
	# inside _resolve_strike specifically so this exact seam exercises it (see
	# _resolve_strike's doc comment).
	var curve3 := load("res://data/level_curve.tres") as LevelCurve
	var follow_target := curve3.total_xp_for_level(15)
	if GameState.get_xp() < follow_target:
		GameState.add_xp(follow_target - GameState.get_xp())
	SkillTree.buy(&"quick_hands")
	SkillTree.buy(&"follow_up")
	mg.min_vol = 0.018   # restore the shipping default (E raised it)
	mg.auto_sell = false
	mg.orbs_enabled = false
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(150)   # catch ProcBurst mid-flight, well inside its ~0.4s life
	print("F follow_up: swings=%d pieces=%d burst_color=%s"
		% [mg.debug_last_follow_up_swings(), mg.piece_count(), mg.debug_last_proc_burst_color()])
	_save("_6_follow_up_burst_mid_flight")
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
