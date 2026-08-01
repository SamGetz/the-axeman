extends Node
## DEV: render a cut face to check the jaggedness. Run NON-headless.
const OUT := "user://poc_shot"

func _ready() -> void:
	var poc: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(poc)
	poc.cut_jag_amount = 0.025   # exaggerated so it's obvious in a still (default is 0.01)
	for i in range(20): await get_tree().process_frame

	# one off-centre cut, then a second so a fresh cut face points at the camera
	poc.debug_slice_world(Plane(Vector3.RIGHT, 0.06))
	for i in range(30): await get_tree().process_frame
	poc.debug_slice_world(Plane(Vector3.FORWARD, 0.0))
	for i in range(30): await get_tree().process_frame

	get_viewport().get_texture().get_image().save_png(OUT + "_5_jag.png")
	print("SHOT saved: _5_jag  (pieces=%d)" % poc.piece_count())
	get_tree().quit()
