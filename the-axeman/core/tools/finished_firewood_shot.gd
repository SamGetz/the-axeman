extends Node
## DEV visual QA for the stack-free completed-piece farewell. Run non-headless.
## Captures the real sliced bodies as their immediate sink begins, farther down
## through the floor, and after removal without a real-time wait.

const _MINIGAME := preload("res://scenes/3d_action/chopping_minigame.tscn")
const _TUNING := preload("res://data/survival_run_tuning_placeholder.tres")
const _OUT := "/private/tmp/axeman_finished_firewood"


func _ready() -> void:
	var game := _MINIGAME.instantiate()
	game.auto_sell = false
	game.debug_split_roll = 1
	add_child(game)
	for _frame: int in range(12):
		await get_tree().process_frame

	var cuts := 0
	while game.cuttable_count() > 0 and cuts < 60:
		var normal := Vector3.RIGHT if cuts % 2 == 0 else Vector3.FORWARD
		game.debug_slice_world(Plane(normal, 0.0))
		cuts += 1
		await get_tree().process_frame
	if game.cuttable_count() > 0:
		push_error("finished_firewood_shot: chop did not complete")
		get_tree().quit(1)
		return

	# Wait for the production settle backstop and one rendered sink frame.
	await get_tree().create_timer(1.7, true, false, true).timeout
	await RenderingServer.frame_post_draw
	_save("_start")

	var state: Dictionary = game.debug_finished_piece_state()
	var age := float(state.get("max_age", 0.0))
	var sink_target := float(_TUNING.finished_piece_hold_seconds) + 0.8
	game.call("_update_finished_piece_sink", maxf(0.0, sink_target - age))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("_sink")

	for _step: int in range(30):
		if int((game.debug_finished_piece_state() as Dictionary).get(
				"count", 0)) == 0:
			break
		game.call("_update_finished_piece_sink", 1.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("_gone")
	print("FINISHED FIREWOOD SHOT: cuts=%d state=%s" % [
		cuts, game.debug_finished_piece_state()])
	get_tree().quit()


func _save(suffix: String) -> void:
	var error := get_viewport().get_texture().get_image().save_png(_OUT + suffix + ".png")
	if error != OK:
		push_error("finished_firewood_shot: could not save %s (%d)" % [suffix, error])
	else:
		print("SHOT saved: %s%s.png" % [_OUT, suffix])
