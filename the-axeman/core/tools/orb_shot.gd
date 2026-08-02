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

	for tag: Array in [["burst", 5], ["bounce", 12], ["resting", 30], ["draw", 18]]:
		for i in range(int(tag[1])):
			await get_tree().process_frame
		await _save(String(tag[0]))

	print("=== orb_shot: done ===")
	get_tree().quit()


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://orb_shot_%s.png" % tag
	img.save_png(path)
	print("  SHOT %s -> %s" % [tag, ProjectSettings.globalize_path(path)])
