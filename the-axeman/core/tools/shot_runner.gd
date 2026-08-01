extends Node
## DEV: render the rebuilt slice POC to PNGs (run NON-headless) so we can see it.

const OUT := "user://poc_shot"

func _ready() -> void:
	var poc: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(poc)
	for i in range(20):
		await get_tree().process_frame
	_save("_1_fresh")

	# a few cuts: shave thin sticks off (should become firewood + fall/pile),
	# leaving a chunky remainder on the stump.
	poc.debug_slice_world(Plane(Vector3.RIGHT, 0.14))
	for i in range(4): await get_tree().process_frame
	poc.debug_slice_world(Plane(Vector3.RIGHT, 0.06))
	for i in range(4): await get_tree().process_frame
	poc.debug_slice_world(Plane(Vector3.FORWARD, 0.10))
	for i in range(90):     # let firewood fall + settle
		await get_tree().process_frame
	_save("_2_cut")
	print("pieces=%d cuttable=%d" % [poc.piece_count(), poc.cuttable_count()])
	# catch the axe mid-swing
	poc._swing_axe()
	for i in range(3):
		await get_tree().process_frame
	_save("_3_axe")
	get_tree().quit()

func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
