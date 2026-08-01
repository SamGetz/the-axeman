extends Node
## DEV: render the firewood pile after a full chop. Run NON-headless.
const OUT := "user://poc_shot"

func _ready() -> void:
	var poc: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(poc)
	for i in range(20): await get_tree().process_frame
	# fully chop the log
	var cuts := 0
	while poc.cuttable_count() > 0 and cuts < 30:
		poc.debug_slice_world(Plane(Vector3.RIGHT, 0.12))
		cuts += 1
		for i in range(2): await get_tree().process_frame
	# let firewood settle + fly into the pile
	for i in range(220): await get_tree().process_frame
	_save("_4_pile")
	print("pile pcs=%d cuttable=%d" % [poc.get_node("Pile").get_child_count(), poc.cuttable_count()])
	get_tree().quit()

func _save(tag: String) -> void:
	get_viewport().get_texture().get_image().save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)
