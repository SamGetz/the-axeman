extends Node
## DEV SMOKE TEST for the M4 chopping mini-game (Amendment 6 slicer).
## Run: godot --headless --path . --quit-after 120 res://core/tools/chopping_smoke.tscn

func _ready() -> void:
	print("=== CHOPPING SMOKE ===")
	var game: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var p0: int = game.piece_count()
	print("PASS: fresh log is a single piece" if p0 == 1 else "FAIL: expected 1 piece, got %d" % p0)
	print("PASS: fresh log is cuttable (on the block)" if game.cuttable_count() == 1 else "FAIL: fresh log not cuttable")

	var ok: bool = game.debug_slice_world(Plane(Vector3.RIGHT, 0.05))
	print("PASS: centre slice succeeded" if ok else "FAIL: slice returned false")

	await get_tree().process_frame
	print("PASS: slice produced two pieces" if game.piece_count() >= 2 else "FAIL: expected >=2 pieces, got %d" % game.piece_count())

	print("=== CHOPPING SMOKE DONE ===")
