extends Node
## FILE: res://core/tools/orb_shot.gd
## ATTACHES TO: root Node of res://core/tools/orb_shot.tscn. DEV TOOL, RUN
## NON-HEADLESS. Not shipped.
##
## Catches the XP orb burst MID-FLIGHT. A count of orbs proves nothing about an
## effect whose entire job is to feel like being paid — the three worst bugs in
## this project's history were invisible to every numeric check and obvious in one
## PNG, and a cosmetic burst is exactly that class of thing.
##
## Shoots all four phases — the burst off the block, the bounce on the floor, the
## beat the orbs spend lying there, and the rush into the player — because the
## middle two are the whole 2026-08-02 revision and a still of the last one would
## look identical before and after it.
## Output: user://orb_shot_<tag>.png

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")


func _ready() -> void:
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.auto_sell = false          # no economy needed; the burst is driven directly
	add_child(game)
	for i in range(20):
		await get_tree().process_frame

	# Straight at the burst, rather than chopping a whole log down first: this
	# tool is about the orbs, and driving the log adds a minute of settle time
	# and a pile animation in front of the thing being photographed.
	game._burst_xp_orbs(120)

	# TIMED, NOT FRAME-COUNTED, and that is not fussiness. Writing a PNG costs tens
	# of milliseconds, so a shot list counted in frames drifts further out of step
	# with the orbs after every save — the first version of this walked its later
	# shots past the end of the whole effect and photographed an empty yard, which
	# reads exactly like an orb bug that is not there. The images are held in memory
	# and written after the run for the same reason.
	var shots: Array = []
	var t0 := float(Time.get_ticks_msec())
	for tag: Array in [["burst", 0.10], ["bounce", 0.35], ["resting", 0.70],
			["draw", 1.00], ["closing", 1.15], ["passing", 1.28], ["arriving", 1.40]]:
		while (float(Time.get_ticks_msec()) - t0) / 1000.0 < float(tag[1]):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		shots.append([String(tag[0]), get_viewport().get_texture().get_image(),
			(float(Time.get_ticks_msec()) - t0) / 1000.0])

	for s: Array in shots:
		var path := "user://orb_shot_%s.png" % s[0]
		(s[1] as Image).save_png(path)
		print("  SHOT %s (t=%.2fs) -> %s" % [s[0], s[2], ProjectSettings.globalize_path(path)])

	print("=== orb_shot: done ===")
	get_tree().quit()
