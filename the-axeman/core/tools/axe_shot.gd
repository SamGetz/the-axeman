extends Node
## FILE: res://core/tools/axe_shot.gd
## ATTACHES TO: root Node of res://core/tools/axe_shot.tscn. DEV TOOL,
## RUN NON-HEADLESS. Not shipped.
##
## Photographs the overhead axe swing beat by beat. RUN THIS ON ANY CHANGE TO
## res://data/axe_swing_lib.tres — a swing is a picture, and no counter in any
## suite can tell you whether the axe read as a swing or as a stick sliding across
## the screen. m4_acceptance proves the contact key still fires; only these PNGs
## prove the pose it fires on looks like an axe hitting wood.
##
## What to look for, in order:
##   1. offscreen / gone: the axe is NOT THERE. There is no windup in frame by
##      design (Sam, 2026-08-02), so anything visible in these two is a viewmodel
##      parked in the middle of the yard.
##   2. entering: the head crossing the right edge, already on its way down.
##   3. dropping: head between the edge and the wood; the handle butt must be off
##      the bottom of the frame, not floating in it.
##   4. contact: the head is ON the log, centre frame, and the log has just come
##      apart. If the wood breaks in any other shot, the contact key and the pose
##      have drifted apart, which is the entire bug this rig was built to kill.
##   5. follow: head below the wood, still travelling.
##
## The shots after contact are spaced generously because the hit-pause fires there
## (A11: Engine.time_scale 0.05), and the animation crawls through it while this
## tool's clock keeps real time.
##
## Output: user://axe_shot_<tag>.png, or user://axe_bounce_shot_<tag>.png
##
## Run: "<godot>" --path . --quit-after 12000 res://core/tools/axe_shot.tscn
## Failed-strike branch: append `-- --bounce` to that command.

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")

## Where the click lands. Centre of a 1280x720 frame is the top of the log.
const _CLICK := Vector2(640.0, 360.0)


func _ready() -> void:
	var show_bounce := "--bounce" in OS.get_cmdline_user_args()
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.debug_forced_mesh = 0
	game.auto_sell = false          # no economy in shot of an animation
	game.debug_split_roll = 0 if show_bounce else 1
	game.orbs_enabled = false       # confetti in front of the thing being photographed
	add_child(game)
	for i in range(30):
		await get_tree().process_frame

	var axe: Node = game.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	if axe == null:
		printerr("axe_shot: no AxeViewmodelAnchor under the camera — nothing to shoot.")
		get_tree().quit()
		return
	var shot_name := "axe_bounce_shot" if show_bounce else "axe_shot"
	print("=== %s: swing %.3fs, contact key at %.3fs ==="
		% [shot_name, axe.swing_duration(), axe.contact_time()])

	# The real click path, not _swing_axe(): this tool has to see the wood break on
	# the contact frame, and only a real strike is pending when that key fires.
	game._on_click(_CLICK)

	# TIMED, NOT FRAME-COUNTED (the lesson orb_shot paid for): saving a PNG costs
	# tens of milliseconds, so a frame-counted shot list drifts further behind a
	# real-time animation with every save. Images are held and written after the run.
	var shots: Array = []
	var t0 := float(Time.get_ticks_msec())
	# The first shot is DELIBERATELY at the very first frame of the swing: the axe
	# enters within about a twentieth of a second, so a shot 0.05s in has already
	# missed the empty frame it exists to prove.
	var beats: Array = [
		["1_offscreen", 0.0], ["2_entering", 0.08], ["3_dropping", 0.14],
		["4_contact", 0.19], ["5_recoil", 0.24], ["6_overhead", 0.31],
		["7_gone", 0.55],
	] if show_bounce else [
		["1_offscreen", 0.0], ["2_entering", 0.08], ["3_dropping", 0.14],
		["4_contact", 0.20], ["5_follow", 0.30], ["6_recovery", 0.42],
		["7_gone", 0.62],
	]
	for tag: Array in beats:
		while (float(Time.get_ticks_msec()) - t0) / 1000.0 < float(tag[1]):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		shots.append([String(tag[0]), get_viewport().get_texture().get_image(),
			(float(Time.get_ticks_msec()) - t0) / 1000.0, game.piece_count()])

	for s: Array in shots:
		var path := "user://%s_%s.png" % [shot_name, s[0]]
		(s[1] as Image).save_png(path)
		print("  SHOT %s (t=%.2fs, pieces=%d) -> %s"
			% [s[0], s[2], s[3], ProjectSettings.globalize_path(path)])

	print("=== %s: done ===" % shot_name)
	get_tree().quit()
