extends Node
## FILE: res://core/tools/proc_shot.gd
## ATTACHES TO: root Node of res://core/tools/proc_shot.tscn. DEV TOOL,
## RUN NON-HEADLESS. Not shipped.
##
## Photographs M7C's Strength proc — RUN THIS ON ANY CHANGE TO Double Strike,
## the proc resolver, or the announcement banner. m7c_acceptance proves the
## mechanic (exact cut counts, caps, fairness state); only these PNGs prove a
## fired proc actually LOOKS like a second real cut with a readable banner, and
## that a suppressed or geometry-refused proc stays invisible rather than
## silently doing nothing while a banner still fires (or vice versa).
##
## Drives the REAL main.tscn so the shot is the real signal path end to end:
## chopping_minigame.bonus_proc_announced -> main.gd -> YardHUD.show_proc_banner
## — never a synthetic call into the HUD.
##
## SAFETY: main.tscn autosaves, so this moves any existing save aside for the
## run and puts it back afterwards, the same as hud_shot/m7a_catalogue_shot.
##
## TIMED, NOT FRAME-COUNTED, for the banner's own auto-hide wait — the lesson
## orb_shot/axe_shot already paid for: a real-time timer does not care how many
## engine frames have ticked.
##
## Output: user://proc_shot_<tag>.png
## Run: "<godot>" --path . --quit-after 12000 res://core/tools/proc_shot.tscn

## The chopping scene's script has no class_name; a preloaded-script const is
## how main.gd itself statically types the same node — see main.gd's
## _ChoppingMinigame for the identical reasoning.
const _ChoppingMinigame := preload("res://scenes/3d_action/chopping_minigame.gd")

const OUT := "user://proc_shot"
const _BACKUP := "user://the_axeman_save.procshotbackup"


func _ready() -> void:
	_stash_save()

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in range(10):
		await get_tree().process_frame

	var hud: Control = main.get_node("UI_Overlay/YardHUD")
	var banner: Control = hud.get_node("ProcBanner")
	var mg: _ChoppingMinigame = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")

	# Grant Double Strike through the REAL GameState.add_xp + SkillTree.buy path
	# — never a direct state poke — so this shoots exactly what a player could
	# actually earn. Enough points for Strong Arms (1) + Double Strike (3) +
	# Steady Continuation (2), bought later for the precision-safe shot.
	var curve := load("res://data/level_curve.tres") as LevelCurve
	GameState.add_xp(curve.total_xp_for_level(7))
	SkillTree.buy(&"strong_arms")
	SkillTree.buy(&"double_strike")

	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1      # the primary swing always cleaves — shooting the proc, not the roll
	mg.debug_force_proc = 1      # Double Strike always fires when it is rolled at all
	mg.orbs_enabled = false      # confetti in front of the thing being photographed

	# _spawn_fresh_log is private-by-convention, reached into directly the same
	# way m7a_acceptance.gd's swing tests already do (bounce_game._on_click) —
	# there is no dedicated public reset seam and this tool needs a clean log
	# between shots without tearing down the one signal-connected scene.
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	_save("_1_fresh_log")

	# --- A: the real Double Strike — two cuts, one swing, banner up ---
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("A double_strike: cuts=%d pieces=%d banner_visible=%s"
		% [mg.debug_last_double_strike_cuts(), mg.piece_count(), banner.visible])
	_save("_2_double_strike_cuts_and_banner")

	await get_tree().create_timer(2.3, true, false, true).timeout   # past _PROC_BANNER_SECONDS
	_save("_2b_banner_auto_hidden")

	# --- B: invalid-chain stop — the primary split leaves nothing useful to
	# continue onto, so the chain must stop BEFORE rolling (no banner). ---
	mg.min_vol = 1000.0   # every piece, however large, reads as firewood
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("B no_geometry: cuts=%d cuttable=%d banner_visible=%s"
		% [mg.debug_last_double_strike_cuts(), mg.cuttable_count(), banner.visible])
	_save("_3_no_geometry_no_bonus_cut")
	mg.min_vol = 0.018   # restore the shipping default before the next shot
	await get_tree().create_timer(2.3, true, false, true).timeout

	# --- C: precision suppression — owned, forced, but the player guarded — no
	# banner, no fairness spend, base swing unaffected. ---
	mg.debug_set_precision_guard(true)
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("C precision_suppressed: cuts=%d banner_visible=%s (guard on, no modifier)"
		% [mg.debug_last_double_strike_cuts(), banner.visible])
	_save("_4_precision_suppressed")
	await get_tree().create_timer(2.3, true, false, true).timeout

	# --- D: Steady Continuation makes it safe again, guard still on. ---
	SkillTree.buy(&"steady_continuation")
	mg._spawn_fresh_log()
	for i in range(10):
		await get_tree().process_frame
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	for i in range(20):
		await get_tree().process_frame
	print("D precision_safe_with_modifier: cuts=%d banner_visible=%s (guard on, WITH Steady Continuation)"
		% [mg.debug_last_double_strike_cuts(), banner.visible])
	_save("_5_precision_safe_with_modifier")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()
	print("=== proc_shot: done ===")
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveSystem.SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP)


func _restore_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.remove(SaveSystem.SAVE_PATH)
	if FileAccess.file_exists(_BACKUP):
		dir.rename(_BACKUP, SaveSystem.SAVE_PATH)
