extends Node
## Compares the production depth pass disabled and enabled. The fullscreen pass
## draws first in the transparent phase so sign text and VFX can draw afterward;
## the normal 3-pixel CanvasItem pass remains on top of both.

const OUT := "/private/tmp/axeman_distance_pixels"


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _frame in range(4):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.get_node("UI_Overlay/YardHUD").show()
	main.call("_enter_3d_mode")
	for _frame in range(16):
		await get_tree().process_frame

	main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
	).process_mode = Node.PROCESS_MODE_DISABLED
	var distance_pass: MeshInstance3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/"
		+ "Chopping_Minigame/CameraPivot/Camera3D/DistancePixelGrade")
	distance_pass.hide()
	for _frame in range(4):
		await get_tree().process_frame
	_save("_uniform")

	distance_pass.show()
	for _frame in range(20):
		await get_tree().process_frame
	_save("_depth_gradient")
	get_tree().quit()


func _save(suffix: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + suffix + ".png"
	var error := image.save_png(path)
	print("distance_pixel_shot: %s (%s)" % [path, error_string(error)])
