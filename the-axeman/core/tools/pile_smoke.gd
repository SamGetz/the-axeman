extends Node
## DEV SMOKE TEST for the firewood pile stacking (Amendment 6, wood_pile.gd).
## Fully chops a log, then checks the firewood is gathered into the pile and a
## fresh log respawns.
## Run: godot --path . --rendering-driver opengl3 --position 3000,3000 \
##      --quit-after 600 res://core/tools/pile_smoke.tscn

func _ready() -> void:
	print("=== PILE SMOKE ===")
	var poc: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(poc)
	await get_tree().process_frame
	await get_tree().process_frame

	# Shave slivers off the on-block piece until nothing choppable is left.
	var cuts := 0
	while poc.cuttable_count() > 0 and cuts < 30:
		# Slice a thin sliver off the +X edge of the current on-block piece.
		poc.debug_slice_world(Plane(Vector3.RIGHT, 0.12))
		cuts += 1
		await get_tree().process_frame
		if poc.cuttable_count() == 0:
			break
	print("PASS: log fully chopped in %d cuts" % cuts if poc.cuttable_count() == 0 \
		else "FAIL: still cuttable after %d cuts" % cuts)

	# Let firewood settle, then the pile animate, then a fresh log spawn. These
	# systems run on Time.get_ticks_msec(), so a frame count is not a duration:
	# hidden/non-headless runs can produce 300 frames before 1.5 real seconds have
	# elapsed. Poll the outcome against a real-time DEV timeout instead.
	var deadline_ms := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline_ms:
		if poc.get_node("Pile").get_child_count() > 0 and poc.cuttable_count() == 1:
			break
		await get_tree().process_frame

	var pile_children: int = poc.get_node("Pile").get_child_count()
	print("PASS: firewood gathered into the pile (%d pcs)" % pile_children if pile_children > 0 \
		else "FAIL: pile is empty")
	print("PASS: fresh log respawned" if poc.cuttable_count() == 1 \
		else "FAIL: expected 1 cuttable fresh log, got %d" % poc.cuttable_count())

	print("=== PILE SMOKE DONE ===")
	get_tree().quit()
